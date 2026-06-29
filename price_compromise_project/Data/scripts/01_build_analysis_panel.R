#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(stringr)
})

args <- commandArgs(trailingOnly = TRUE)
project_root <- ifelse(length(args) >= 1, args[[1]], getwd())
clean_dir <- file.path(project_root, "Data", "cleaned")
analysis_dir <- file.path(project_root, "Data", "analysis")
dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)

years <- 2016:2025

clean_name <- function(x) {
  x |>
    str_to_lower() |>
    str_replace_all("&", "and") |>
    str_replace_all("[[:punct:]]+", " ") |>
    str_squish()
}

message("Reading cleaned inputs...")
io_ind <- read_csv(file.path(clean_dir, "bea_industry_output_2019.csv"), show_col_types = FALSE) |>
  rename(io_year = year) |>
  mutate(industry_name_clean = clean_name(industry_name))

price <- read_csv(file.path(clean_dir, "bea_gross_output_price_index_annual_2016_2025.csv"), show_col_types = FALSE) |>
  mutate(industry_name_clean = clean_name(industry_name))

intermediate_price <- read_csv(file.path(clean_dir, "bea_intermediate_inputs_price_index_annual_2016_2025.csv"), show_col_types = FALSE) |>
  mutate(industry_name_clean = clean_name(industry_name)) |>
  select(industry_name_clean, year, intermediate_inputs_price_index_2017_100 = price_index_2017_100)

pce_price <- read_csv(file.path(clean_dir, "pce_price_index_annual_2016_2025.csv"), show_col_types = FALSE) |>
  select(year, pce_price_index_2017_100)

io_coef <- read_csv(file.path(clean_dir, "bea_input_coefficients_2019.csv"), show_col_types = FALSE)

concordance_raw <- read_csv(file.path(clean_dir, "bea_naics_concordance_clean.csv"), show_col_types = FALSE)

concordance <- concordance_raw |>
  filter(!is.na(summary_code), !is.na(naics_2017)) |>
  mutate(naics_2017 = as.character(naics_2017)) |>
  filter(str_detect(naics_2017, "^[0-9]+$")) |>
  distinct(summary_code, summary_name, naics_2017)

ambiguous_naics <- concordance |>
  distinct(summary_code, naics_2017) |>
  count(naics_2017, name = "n_bea_summaries") |>
  filter(n_bea_summaries > 1)

if (nrow(ambiguous_naics) > 0) {
  message("Dropping ambiguous NAICS codes mapped to multiple BEA summary industries: ",
          paste(ambiguous_naics$naics_2017, collapse = ", "))
}

concordance_unique <- concordance |>
  anti_join(ambiguous_naics, by = "naics_2017")

qcew <- read_csv(file.path(clean_dir, "bls_qcew_private_industry_wages_annual_2016_2025.csv"), show_col_types = FALSE) |>
  mutate(naics_code = as.character(naics_code))

tariffs_naics <- read_csv(file.path(clean_dir, "rtp_tariffs_naics_clean.csv"), show_col_types = FALSE) |>
  mutate(naics_str = as.character(naics_str))

clean_301_exposure_path <- file.path(analysis_dir, "bea_summary_tariff_exposure_301_clean.csv")

message("Building BEA industry-price panel...")
industry_price_panel <- io_ind |>
  filter(!str_starts(industry_code, "G")) |>
  left_join(
    price |> select(industry_name_clean, year, gross_output_price_index_2017_100 = price_index_2017_100),
    by = "industry_name_clean"
  ) |>
  left_join(intermediate_price, by = c("industry_name_clean", "year")) |>
  left_join(pce_price, by = "year") |>
  filter(year %in% years) |>
  arrange(industry_code, year)

message("Aggregating QCEW wages from NAICS to BEA summary industries...")
qcew_bea <- concordance_unique |>
  left_join(qcew, by = c("naics_2017" = "naics_code")) |>
  filter(year %in% years) |>
  group_by(summary_code, summary_name, year) |>
  summarise(
    qcew_employment = sum(annual_avg_emplvl, na.rm = TRUE),
    qcew_total_annual_wages = sum(total_annual_wages, na.rm = TRUE),
    qcew_avg_annual_pay = if_else(qcew_employment > 0, qcew_total_annual_wages / qcew_employment, NA_real_),
    qcew_avg_weekly_wage = weighted.mean(annual_avg_wkly_wage, annual_avg_emplvl, na.rm = TRUE),
    n_naics_wage_matches = sum(!is.na(annual_avg_emplvl)),
    .groups = "drop"
  ) |>
  rename(industry_code = summary_code)

if (file.exists(clean_301_exposure_path)) {
  message("Using cleaned annual Section 301 exposure from: ", clean_301_exposure_path)
  tariff_bea <- read_csv(clean_301_exposure_path, show_col_types = FALSE) |>
    mutate(
      industry_code = as.character(industry_code),
      year = as.integer(year),
      tariff_source = "clean_301_hts8_import_weighted"
    )

  tariff_panel <- expand_grid(industry_code = unique(io_ind$industry_code), year = years) |>
    left_join(tariff_bea, by = c("industry_code", "year")) |>
    mutate(
      tariff_301_direct = coalesce(tariff_301_direct, 0),
      tariff_direct_prelim = tariff_301_direct,
      tariff_direct_post_prelim = tariff_301_direct,
      targeted_import_share_2017_china = coalesce(targeted_import_share_2017_china, 0),
      china_import_value_2017 = coalesce(china_import_value_2017, 0),
      n_naics_with_import_weights = coalesce(n_naics_with_import_weights, 0),
      n_naics_in_concordance = coalesce(n_naics_in_concordance, 0),
      n_naics_tariff_matches = n_naics_with_import_weights,
      tariff_source = coalesce(tariff_source, "clean_301_no_direct_exposure")
    )
} else {
  message("Clean annual Section 301 exposure not found; falling back to RTP NAICS exposure.")
  message("Aggregating tariff exposure from NAICS to BEA summary industries...")
  tariff_bea <- concordance_unique |>
    left_join(tariffs_naics, by = c("naics_2017" = "naics_str")) |>
    group_by(summary_code, summary_name) |>
    summarise(
      tariff_T0_2017 = mean(T0_2017, na.rm = TRUE),
      tariff_T0_2018 = mean(T0_2018, na.rm = TRUE),
      tariff_T0_post = mean(T0, na.rm = TRUE),
      tariff_R0_2018 = mean(R0_2018, na.rm = TRUE),
      tariff_S0_2018 = mean(S0_2018, na.rm = TRUE),
      tariff_E0_2018 = mean(E0_2018, na.rm = TRUE),
      n_naics_tariff_matches = sum(!is.na(T0_2018)),
      .groups = "drop"
    ) |>
    mutate(across(starts_with("tariff_"), ~ ifelse(is.nan(.x), NA_real_, .x))) |>
    rename(industry_code = summary_code)

  message("Expanding tariff exposure to an annual preliminary shock...")
  tariff_panel <- expand_grid(industry_code = unique(io_ind$industry_code), year = years) |>
    left_join(tariff_bea, by = "industry_code") |>
    mutate(
      tariff_direct_prelim = case_when(
        year <= 2017 ~ 0,
        year >= 2018 ~ coalesce(tariff_T0_2018, 0)
      ),
      tariff_direct_post_prelim = case_when(
        year <= 2017 ~ 0,
        year >= 2018 ~ coalesce(tariff_T0_post, tariff_T0_2018, 0)
      ),
      tariff_source = "rtp_naics_prelim"
    )
}

message("Constructing IO network tariff exposure...")
network_tariff <- io_coef |>
  select(industry_code, commodity_code, input_share, link_5pct) |>
  crossing(year = years) |>
  left_join(
    tariff_panel |> select(commodity_code = industry_code, year, supplier_tariff_direct = tariff_direct_prelim),
    by = c("commodity_code", "year")
  ) |>
  mutate(supplier_tariff_direct = coalesce(supplier_tariff_direct, 0)) |>
  group_by(industry_code, year) |>
  summarise(
    network_tariff_shock = sum(input_share * supplier_tariff_direct, na.rm = TRUE),
    network_tariff_shock_5pct = sum(if_else(link_5pct == 1, input_share, 0) * supplier_tariff_direct, na.rm = TRUE),
    network_tariff_shock_excl_own = sum(if_else(commodity_code != industry_code, input_share, 0) * supplier_tariff_direct, na.rm = TRUE),
    .groups = "drop"
  )

message("Assembling analysis panel...")
panel <- industry_price_panel |>
  left_join(qcew_bea, by = c("industry_code", "year")) |>
  left_join(tariff_panel |> select(industry_code, year, starts_with("tariff_"), n_naics_tariff_matches), by = c("industry_code", "year")) |>
  left_join(network_tariff, by = c("industry_code", "year")) |>
  arrange(industry_code, year) |>
  group_by(industry_code) |>
  mutate(
    ln_gross_output_price = log(gross_output_price_index_2017_100),
    dln_gross_output_price = ln_gross_output_price - lag(ln_gross_output_price),
    ln_intermediate_inputs_price = log(intermediate_inputs_price_index_2017_100),
    dln_intermediate_inputs_price = ln_intermediate_inputs_price - lag(ln_intermediate_inputs_price),
    ln_avg_annual_pay = log(qcew_avg_annual_pay),
    dln_avg_annual_pay = ln_avg_annual_pay - lag(ln_avg_annual_pay),
    real_annual_pay_go_price = qcew_avg_annual_pay / (gross_output_price_index_2017_100 / 100),
    ln_real_annual_pay_go_price = log(real_annual_pay_go_price),
    dln_real_annual_pay_go_price = ln_real_annual_pay_go_price - lag(ln_real_annual_pay_go_price),
    real_annual_pay_pce = qcew_avg_annual_pay / (pce_price_index_2017_100 / 100),
    ln_real_annual_pay_pce = log(real_annual_pay_pce),
    dln_real_annual_pay_pce = ln_real_annual_pay_pce - lag(ln_real_annual_pay_pce),
    post2021 = as.integer(year >= 2021),
    lag1_network_tariff_shock = lag(network_tariff_shock),
    lag2_network_tariff_shock = lag(network_tariff_shock, 2),
    lag1_network_tariff_shock_5pct = lag(network_tariff_shock_5pct),
    lag2_network_tariff_shock_5pct = lag(network_tariff_shock_5pct, 2),
    lag1_network_tariff_shock_excl_own = lag(network_tariff_shock_excl_own),
    lag2_network_tariff_shock_excl_own = lag(network_tariff_shock_excl_own, 2),
    lag1_tariff_direct_prelim = lag(tariff_direct_prelim),
    lag2_tariff_direct_prelim = lag(tariff_direct_prelim, 2),
    d_network_tariff_shock = network_tariff_shock - lag1_network_tariff_shock,
    d_network_tariff_shock_5pct = network_tariff_shock_5pct - lag1_network_tariff_shock_5pct,
    d_network_tariff_shock_excl_own = network_tariff_shock_excl_own - lag1_network_tariff_shock_excl_own,
    network_tariff_shock_cum01 = network_tariff_shock + coalesce(lag1_network_tariff_shock, 0),
    network_tariff_shock_cum02 = network_tariff_shock + coalesce(lag1_network_tariff_shock, 0) + coalesce(lag2_network_tariff_shock, 0),
    network_tariff_shock_5pct_cum01 = network_tariff_shock_5pct + coalesce(lag1_network_tariff_shock_5pct, 0),
    network_tariff_shock_5pct_cum02 = network_tariff_shock_5pct + coalesce(lag1_network_tariff_shock_5pct, 0) + coalesce(lag2_network_tariff_shock_5pct, 0),
    network_tariff_shock_excl_own_cum01 = network_tariff_shock_excl_own + coalesce(lag1_network_tariff_shock_excl_own, 0),
    network_tariff_shock_excl_own_cum02 = network_tariff_shock_excl_own + coalesce(lag1_network_tariff_shock_excl_own, 0) + coalesce(lag2_network_tariff_shock_excl_own, 0),
    tariff_direct_prelim_cum01 = tariff_direct_prelim + coalesce(lag1_tariff_direct_prelim, 0),
    tariff_direct_prelim_cum02 = tariff_direct_prelim + coalesce(lag1_tariff_direct_prelim, 0) + coalesce(lag2_tariff_direct_prelim, 0)
  ) |>
  ungroup()

write_csv(tariff_bea, file.path(analysis_dir, "bea_summary_tariff_exposure_prelim.csv"))
write_csv(network_tariff, file.path(analysis_dir, "bea_summary_network_tariff_shock_prelim.csv"))
write_csv(panel, file.path(analysis_dir, "analysis_panel_bea_summary_2016_2025_prelim.csv"))

readme <- c(
  "# Analysis data",
  "",
  "Generated by `Data/scripts/01_build_analysis_panel.R`.",
  "",
  "Main output:",
  "- `analysis_panel_bea_summary_2016_2025_prelim.csv`",
  "",
  "Important caveat:",
  "- If `bea_summary_tariff_exposure_301_clean.csv` exists, tariff variables use the cleaned annual HTS8 Section 301 exposure built from USTR core lists and 2017 China import weights.",
  "- Otherwise, the script falls back to `rtp_tariffs_naics_clean.csv`, the earlier static NAICS-level exposure file.",
  "- `tariff_direct_prelim` is retained as a stable column name for the main direct tariff shock.",
  "",
  "Network variables:",
  "- `network_tariff_shock`: sum_j input_share_ij * tariff_jt",
  "- `network_tariff_shock_excl_own`: same but excluding j = i",
  "- `network_tariff_shock_5pct`: keeps only links with input_share > 0.05",
  "- `network_tariff_shock_cum01` and `network_tariff_shock_cum02`: current plus one- and two-year lagged network exposure",
  "- `network_tariff_shock_5pct_cum01` and `network_tariff_shock_excl_own_cum01`: robustness definitions using strong links and excluding own industry.",
  "- `d_network_tariff_shock`: annual change in network exposure",
  "",
  "Wage outcomes:",
  "- `dln_real_annual_pay_go_price`: QCEW annual pay deflated by BEA industry gross output price index.",
  "- `dln_real_annual_pay_pce`: QCEW annual pay deflated by annual PCEPI, FRED/BEA, 2017=100."
)
write_lines(readme, file.path(analysis_dir, "README.md"))

message("Done.")
message("Rows in panel: ", nrow(panel))
message("Industries in panel: ", n_distinct(panel$industry_code))
message("Output: ", file.path(analysis_dir, "analysis_panel_bea_summary_2016_2025_prelim.csv"))
