#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(fixest)
})

args <- commandArgs(trailingOnly = TRUE)
project_root <- ifelse(length(args) >= 1, args[[1]], getwd())
clean_dir <- file.path(project_root, "Data", "cleaned")
analysis_dir <- file.path(project_root, "Data", "analysis")
output_dir <- file.path(project_root, "Output", "tables")
dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

years <- 2016:2025

message("Reading QCEW wages, Section 301 NAICS exposure, and PCE deflator...")
qcew <- read_csv(
  file.path(clean_dir, "bls_qcew_private_industry_wages_annual_2016_2025.csv"),
  col_types = cols(.default = col_guess(), naics_code = col_character())
) |>
  mutate(
    naics_code = str_trim(as.character(naics_code)),
    year = as.integer(year)
  ) |>
  filter(
    year %in% years,
    str_detect(naics_code, "^[0-9]{6}$"),
    !is.na(avg_annual_pay),
    avg_annual_pay > 0,
    !is.na(annual_avg_wkly_wage),
    annual_avg_wkly_wage > 0
  )

exposure <- read_csv(
  file.path(clean_dir, "ustr_301_naics_exposure_annual.csv"),
  col_types = cols(.default = col_guess(), naics_str = col_character())
) |>
  mutate(
    naics_str = str_trim(as.character(naics_str)),
    year = as.integer(year)
  ) |>
  filter(year %in% years, str_detect(naics_str, "^[0-9]{6}$")) |>
  group_by(naics_str, year) |>
  summarise(
    tariff_301_direct = weighted.mean(tariff_301_direct, w = pmax(china_import_value_2017, 0), na.rm = TRUE),
    targeted_import_share_2017_china = weighted.mean(targeted_import_share_2017_china, w = pmax(china_import_value_2017, 0), na.rm = TRUE),
    china_import_value_2017 = sum(china_import_value_2017, na.rm = TRUE),
    n_hs8_total = sum(n_hs8_total, na.rm = TRUE),
    n_hs8_targeted = sum(n_hs8_targeted, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    tariff_301_direct = if_else(is.nan(tariff_301_direct), 0, tariff_301_direct),
    targeted_import_share_2017_china = if_else(is.nan(targeted_import_share_2017_china), 0, targeted_import_share_2017_china)
  )

pce <- read_csv(file.path(clean_dir, "pce_price_index_annual_2016_2025.csv"), show_col_types = FALSE) |>
  select(year, pce_price_index_2017_100)

message("Building all-QCEW six-digit NAICS panel...")
panel_all <- qcew |>
  left_join(exposure, by = c("naics_code" = "naics_str", "year")) |>
  left_join(pce, by = "year") |>
  mutate(
    has_301_import_weight = as.integer(!is.na(china_import_value_2017)),
    tariff_301_direct = coalesce(tariff_301_direct, 0),
    targeted_import_share_2017_china = coalesce(targeted_import_share_2017_china, 0),
    china_import_value_2017 = coalesce(china_import_value_2017, 0),
    n_hs8_total = coalesce(n_hs8_total, 0),
    n_hs8_targeted = coalesce(n_hs8_targeted, 0),
    naics_fe = naics_code
  ) |>
  arrange(naics_code, year) |>
  group_by(naics_code) |>
  mutate(
    ln_avg_annual_pay = log(avg_annual_pay),
    dln_avg_annual_pay = ln_avg_annual_pay - lag(ln_avg_annual_pay),
    ln_avg_weekly_wage = log(annual_avg_wkly_wage),
    dln_avg_weekly_wage = ln_avg_weekly_wage - lag(ln_avg_weekly_wage),
    real_annual_pay_pce = avg_annual_pay / (pce_price_index_2017_100 / 100),
    ln_real_annual_pay_pce = log(real_annual_pay_pce),
    dln_real_annual_pay_pce = ln_real_annual_pay_pce - lag(ln_real_annual_pay_pce),
    real_weekly_wage_pce = annual_avg_wkly_wage / (pce_price_index_2017_100 / 100),
    ln_real_weekly_wage_pce = log(real_weekly_wage_pce),
    dln_real_weekly_wage_pce = ln_real_weekly_wage_pce - lag(ln_real_weekly_wage_pce),
    lag1_tariff_301_direct = lag(tariff_301_direct),
    lag2_tariff_301_direct = lag(tariff_301_direct, 2),
    tariff_301_direct_cum01 = tariff_301_direct + coalesce(lag1_tariff_301_direct, 0),
    tariff_301_direct_cum02 = tariff_301_direct + coalesce(lag1_tariff_301_direct, 0) + coalesce(lag2_tariff_301_direct, 0),
    d_tariff_301_direct = tariff_301_direct - lag1_tariff_301_direct
  ) |>
  ungroup()

panel_matched <- panel_all |>
  group_by(naics_code) |>
  filter(any(has_301_import_weight == 1)) |>
  ungroup()

write_csv(panel_all, file.path(analysis_dir, "analysis_panel_naics6_qcew_2016_2025.csv"))
write_csv(panel_matched, file.path(analysis_dir, "analysis_panel_naics6_qcew_import_matched_2016_2025.csv"))

model_data_all <- panel_all |>
  filter(year >= 2017, !is.na(dln_avg_annual_pay), !is.na(dln_avg_weekly_wage))

model_data_matched <- panel_matched |>
  filter(year >= 2017, !is.na(dln_avg_annual_pay), !is.na(dln_avg_weekly_wage))

message(
  "All QCEW6 sample rows: ", nrow(model_data_all),
  "; industries: ", n_distinct(model_data_all$naics_code),
  "; ever matched industries: ", n_distinct(panel_all$naics_code[panel_all$has_301_import_weight == 1])
)
message(
  "Import-weight matched sample rows: ", nrow(model_data_matched),
  "; industries: ", n_distinct(model_data_matched$naics_code)
)

run_model <- function(outcome, rhs, data) {
  feols(
    as.formula(paste0(outcome, " ~ ", rhs, " | naics_fe + year")),
    cluster = ~naics_fe,
    data = data
  )
}

models_all <- list(
  "All QCEW6: annual pay, current" = run_model("dln_avg_annual_pay", "tariff_301_direct", model_data_all),
  "All QCEW6: annual pay, cum. 0-1" = run_model("dln_avg_annual_pay", "tariff_301_direct_cum01", model_data_all),
  "All QCEW6: weekly wage, cum. 0-1" = run_model("dln_avg_weekly_wage", "tariff_301_direct_cum01", model_data_all),
  "All QCEW6: PCE real annual pay, cum. 0-1" = run_model("dln_real_annual_pay_pce", "tariff_301_direct_cum01", model_data_all),
  "All QCEW6: PCE real weekly wage, cum. 0-1" = run_model("dln_real_weekly_wage_pce", "tariff_301_direct_cum01", model_data_all)
)

models_matched <- list(
  "Matched QCEW6: annual pay, current" = run_model("dln_avg_annual_pay", "tariff_301_direct", model_data_matched),
  "Matched QCEW6: annual pay, cum. 0-1" = run_model("dln_avg_annual_pay", "tariff_301_direct_cum01", model_data_matched),
  "Matched QCEW6: weekly wage, cum. 0-1" = run_model("dln_avg_weekly_wage", "tariff_301_direct_cum01", model_data_matched),
  "Matched QCEW6: PCE real annual pay, cum. 0-1" = run_model("dln_real_annual_pay_pce", "tariff_301_direct_cum01", model_data_matched),
  "Matched QCEW6: PCE real weekly wage, cum. 0-1" = run_model("dln_real_weekly_wage_pce", "tariff_301_direct_cum01", model_data_matched)
)

run_weighted_model <- function(outcome, rhs, data) {
  feols(
    as.formula(paste0(outcome, " ~ ", rhs, " | naics_fe + year")),
    cluster = ~naics_fe,
    weights = ~annual_avg_emplvl,
    data = data
  )
}

weighted_models <- list(
  "All QCEW6 weighted: annual pay, cum. 0-1" = run_weighted_model("dln_avg_annual_pay", "tariff_301_direct_cum01", model_data_all),
  "All QCEW6 weighted: annual pay, cum. 0-2" = run_weighted_model("dln_avg_annual_pay", "tariff_301_direct_cum02", model_data_all),
  "Matched QCEW6 weighted: annual pay, cum. 0-1" = run_weighted_model("dln_avg_annual_pay", "tariff_301_direct_cum01", model_data_matched),
  "Matched QCEW6 weighted: annual pay, cum. 0-2" = run_weighted_model("dln_avg_annual_pay", "tariff_301_direct_cum02", model_data_matched)
)

sink(file.path(output_dir, "naics6_wage_twfe_etable.txt"))
cat("NAICS 6-digit wage TWFE models\n")
cat("Generated by Data/scripts/03_run_naics_wage_models.R\n")
cat("All models include six-digit NAICS fixed effects and year fixed effects. Standard errors are clustered by NAICS.\n")
cat("Note: PCE real wage uses a national annual deflator; with year fixed effects, tariff coefficients match nominal wage coefficients when samples match.\n\n")
cat("Panel diagnostics\n")
cat("All QCEW6 model rows: ", nrow(model_data_all), "\n", sep = "")
cat("All QCEW6 industries: ", n_distinct(model_data_all$naics_code), "\n", sep = "")
cat("All QCEW6 industries with Section 301 import weights: ", n_distinct(panel_all$naics_code[panel_all$has_301_import_weight == 1]), "\n", sep = "")
cat("Matched QCEW6 model rows: ", nrow(model_data_matched), "\n", sep = "")
cat("Matched QCEW6 industries: ", n_distinct(model_data_matched$naics_code), "\n\n", sep = "")
cat("A. All QCEW six-digit industries; unmatched exposure set to zero\n")
print(etable(models_all, fitstat = ~ n + r2 + wr2))
cat("\nB. Six-digit industries with HS8-to-NAICS import weights only\n")
print(etable(models_matched, fitstat = ~ n + r2 + wr2))
cat("\nC. Employment-weighted wage models\n")
print(etable(weighted_models, fitstat = ~ n + r2 + wr2))
sink()

extract_coefs <- function(model_list, sample_name) {
  bind_rows(lapply(names(model_list), function(model_name) {
    ct <- coeftable(model_list[[model_name]])
    tibble(
      sample = sample_name,
      model = model_name,
      term = rownames(ct),
      estimate = ct[, "Estimate"],
      std_error = ct[, "Std. Error"],
      t_value = ct[, "t value"],
      p_value = ct[, "Pr(>|t|)"],
      nobs = nobs(model_list[[model_name]])
    )
  }))
}

coef_out <- bind_rows(
  extract_coefs(models_all, "all_qcew6_zero_unmatched"),
  extract_coefs(models_matched, "import_weight_matched_qcew6"),
  extract_coefs(weighted_models, "employment_weighted_qcew6")
)

write_csv(coef_out, file.path(output_dir, "naics6_wage_twfe_coefficients.csv"))

diagnostics <- tibble(
  sample = c("all_qcew6_zero_unmatched", "import_weight_matched_qcew6"),
  model_rows = c(nrow(model_data_all), nrow(model_data_matched)),
  industries = c(n_distinct(model_data_all$naics_code), n_distinct(model_data_matched$naics_code)),
  exposed_industry_years_nonzero = c(
    sum(model_data_all$tariff_301_direct > 0, na.rm = TRUE),
    sum(model_data_matched$tariff_301_direct > 0, na.rm = TRUE)
  )
)

write_csv(diagnostics, file.path(output_dir, "naics6_wage_twfe_diagnostics.csv"))

message("Wrote NAICS wage panels and TWFE outputs.")
