#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(fixest)
})

args <- commandArgs(trailingOnly = TRUE)
project_root <- ifelse(length(args) >= 1, args[[1]], getwd())
analysis_dir <- file.path(project_root, "Data", "analysis")
output_dir <- file.path(project_root, "Output", "tables")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

panel_path <- file.path(analysis_dir, "analysis_panel_bea_summary_2016_2025_prelim.csv")
panel <- read_csv(panel_path, show_col_types = FALSE) |>
  filter(year >= 2017, !is.na(dln_gross_output_price)) |>
  mutate(
    industry_fe = industry_code,
    network_x_post2021 = network_tariff_shock * post2021,
    network_excl_own_x_post2021 = network_tariff_shock_excl_own * post2021,
    network_cum01_x_post2021 = network_tariff_shock_cum01 * post2021,
    network_excl_own_cum01_x_post2021 = network_tariff_shock_excl_own_cum01 * post2021
  )

message("Rows: ", nrow(panel), "; industries: ", dplyr::n_distinct(panel$industry_code))

m_price_1 <- feols(
  dln_gross_output_price ~ network_tariff_shock | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_price_2 <- feols(
  dln_gross_output_price ~ network_tariff_shock + lag1_network_tariff_shock + lag2_network_tariff_shock | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_price_3 <- feols(
  dln_gross_output_price ~ network_tariff_shock_excl_own | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_price_cum01 <- feols(
  dln_gross_output_price ~ network_tariff_shock_cum01 | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_price_change <- feols(
  dln_gross_output_price ~ d_network_tariff_shock | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_price_direct_cum01 <- feols(
  dln_gross_output_price ~ tariff_direct_prelim_cum01 | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_price_excl_own_cum01 <- feols(
  dln_gross_output_price ~ network_tariff_shock_excl_own_cum01 | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_price_5pct_cum01 <- feols(
  dln_gross_output_price ~ network_tariff_shock_5pct_cum01 | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_intermediate_price_cum01 <- feols(
  dln_intermediate_inputs_price ~ network_tariff_shock_cum01 | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_wage_1 <- feols(
  dln_avg_annual_pay ~ network_tariff_shock | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_wage_cum01 <- feols(
  dln_avg_annual_pay ~ network_tariff_shock_cum01 | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_realwage_1 <- feols(
  dln_real_annual_pay_go_price ~ network_tariff_shock | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_realwage_cum01 <- feols(
  dln_real_annual_pay_go_price ~ network_tariff_shock_cum01 | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_realwage_cum02 <- feols(
  dln_real_annual_pay_go_price ~ network_tariff_shock_cum02 | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_realwage_direct_cum01 <- feols(
  dln_real_annual_pay_go_price ~ tariff_direct_prelim_cum01 | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_realwage_excl_own_cum01 <- feols(
  dln_real_annual_pay_go_price ~ network_tariff_shock_excl_own_cum01 | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_realwage_5pct_cum01 <- feols(
  dln_real_annual_pay_go_price ~ network_tariff_shock_5pct_cum01 | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_realwage_pce_1 <- feols(
  dln_real_annual_pay_pce ~ network_tariff_shock | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_realwage_pce_cum01 <- feols(
  dln_real_annual_pay_pce ~ network_tariff_shock_cum01 | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_realwage_pce_cum02 <- feols(
  dln_real_annual_pay_pce ~ network_tariff_shock_cum02 | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_realwage_2 <- feols(
  dln_real_annual_pay_go_price ~ network_tariff_shock + network_x_post2021 | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_realwage_cum01_post <- feols(
  dln_real_annual_pay_go_price ~ network_tariff_shock_cum01 + network_cum01_x_post2021 | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

m_realwage_3 <- feols(
  dln_real_annual_pay_go_price ~ network_tariff_shock_excl_own + network_excl_own_x_post2021 | industry_fe + year,
  cluster = ~industry_fe,
  data = panel
)

models <- list(
  "Price: network" = m_price_1,
  "Price: lags" = m_price_2,
  "Price: excl own" = m_price_3,
  "Nominal wage" = m_wage_1,
  "Real wage" = m_realwage_1,
  "Real wage x post2021" = m_realwage_2,
  "Real wage excl own x post2021" = m_realwage_3
)

main_models <- list(
  "Price: current network" = m_price_1,
  "Price: cumulative 0-1" = m_price_cum01,
  "Price: change in network" = m_price_change,
  "Nominal wage: cumulative 0-1" = m_wage_cum01,
  "Real wage: current network" = m_realwage_1,
  "Real wage: cumulative 0-1" = m_realwage_cum01,
  "Real wage: cumulative 0-2" = m_realwage_cum02,
  "PCE real wage: current network" = m_realwage_pce_1,
  "PCE real wage: cumulative 0-1" = m_realwage_pce_cum01,
  "PCE real wage: cumulative 0-2" = m_realwage_pce_cum02,
  "Real wage: cum. 0-1 x post2021" = m_realwage_cum01_post
)

mechanism_models <- list(
  "Gross output price" = m_price_cum01,
  "Intermediate input price" = m_intermediate_price_cum01,
  "Nominal wage" = m_wage_cum01,
  "Industry-price real wage" = m_realwage_cum01,
  "PCE real wage" = m_realwage_pce_cum01
)

robustness_price_models <- list(
  "Direct shock" = m_price_direct_cum01,
  "Full IO network" = m_price_cum01,
  "Excluding own industry" = m_price_excl_own_cum01,
  "Only IO links > 5%" = m_price_5pct_cum01
)

robustness_realwage_models <- list(
  "Direct shock" = m_realwage_direct_cum01,
  "Full IO network" = m_realwage_cum01,
  "Excluding own industry" = m_realwage_excl_own_cum01,
  "Only IO links > 5%" = m_realwage_5pct_cum01
)

sink(file.path(output_dir, "twfe_prelim_etable.txt"))
cat("Preliminary TWFE models\n")
cat("Generated by Data/scripts/02_run_twfe_models.R\n")
cat("Caveat: tariff variables use cleaned USTR HTS8 Section 301 lists and 2017 China-import HS8-to-NAICS weights; product exclusions and exact daily exposure are not yet incorporated.\n\n")
print(etable(models, fitstat = ~ n + r2 + wr2))
sink()

sink(file.path(output_dir, "twfe_main_etable.txt"))
cat("Main TWFE models\n")
cat("Generated by Data/scripts/02_run_twfe_models.R\n")
cat("Caveat: tariff variables use cleaned USTR HTS8 Section 301 lists and 2017 China-import HS8-to-NAICS weights; product exclusions and exact daily exposure are not yet incorporated.\n\n")
cat("All models include BEA summary industry fixed effects and year fixed effects. Standard errors are clustered by industry.\n")
cat("Note: PCE real wage uses a national annual deflator; with year fixed effects, its tariff coefficients are algebraically equivalent to nominal wage coefficients when samples match.\n\n")
print(etable(main_models, fitstat = ~ n + r2 + wr2))
sink()

sink(file.path(output_dir, "twfe_mechanism_etable.txt"))
cat("Mechanism TWFE table\n")
cat("Generated by Data/scripts/02_run_twfe_models.R\n")
cat("Main regressor: `network_tariff_shock_cum01`, current plus one-year lagged IO network Section 301 exposure.\n")
cat("All models include BEA summary industry fixed effects and year fixed effects. Standard errors are clustered by industry.\n")
cat("Note: PCE real wage uses a national annual deflator; with year fixed effects, its tariff coefficients are algebraically equivalent to nominal wage coefficients when samples match.\n\n")
print(etable(mechanism_models, fitstat = ~ n + r2 + wr2))
sink()

sink(file.path(output_dir, "twfe_robustness_price_etable.txt"))
cat("Price robustness TWFE table\n")
cat("Generated by Data/scripts/02_run_twfe_models.R\n")
cat("Outcome: `dln_gross_output_price`. Regressors use current plus one-year lagged exposure.\n")
cat("All models include BEA summary industry fixed effects and year fixed effects. Standard errors are clustered by industry.\n\n")
print(etable(robustness_price_models, fitstat = ~ n + r2 + wr2))
sink()

sink(file.path(output_dir, "twfe_robustness_realwage_etable.txt"))
cat("Real-wage robustness TWFE table\n")
cat("Generated by Data/scripts/02_run_twfe_models.R\n")
cat("Outcome: `dln_real_annual_pay_go_price`. Regressors use current plus one-year lagged exposure.\n")
cat("All models include BEA summary industry fixed effects and year fixed effects. Standard errors are clustered by industry.\n\n")
print(etable(robustness_realwage_models, fitstat = ~ n + r2 + wr2))
sink()

extract_coefs <- function(model_list, model_set) {
  lapply(names(model_list), function(nm) {
    ct <- coeftable(model_list[[nm]])
    data.frame(
      model_set = model_set,
      model = nm,
      term = rownames(ct),
      estimate = ct[, "Estimate"],
      std_error = ct[, "Std. Error"],
      t_value = ct[, "t value"],
      p_value = ct[, "Pr(>|t|)"],
      row.names = NULL
    )
  }) |>
    bind_rows()
}

coef_rows <- extract_coefs(models, "prelim")
main_coef_rows <- extract_coefs(main_models, "main")
mechanism_coef_rows <- extract_coefs(mechanism_models, "mechanism")
robustness_coef_rows <- bind_rows(
  extract_coefs(robustness_price_models, "robustness_price"),
  extract_coefs(robustness_realwage_models, "robustness_realwage")
)

write_csv(coef_rows, file.path(output_dir, "twfe_prelim_coefficients.csv"))
write_csv(main_coef_rows, file.path(output_dir, "twfe_main_coefficients.csv"))
write_csv(mechanism_coef_rows, file.path(output_dir, "twfe_mechanism_coefficients.csv"))
write_csv(robustness_coef_rows, file.path(output_dir, "twfe_robustness_coefficients.csv"))

message("Wrote:")
message(" - ", file.path(output_dir, "twfe_prelim_etable.txt"))
message(" - ", file.path(output_dir, "twfe_prelim_coefficients.csv"))
message(" - ", file.path(output_dir, "twfe_main_etable.txt"))
message(" - ", file.path(output_dir, "twfe_main_coefficients.csv"))
message(" - ", file.path(output_dir, "twfe_mechanism_etable.txt"))
message(" - ", file.path(output_dir, "twfe_mechanism_coefficients.csv"))
message(" - ", file.path(output_dir, "twfe_robustness_price_etable.txt"))
message(" - ", file.path(output_dir, "twfe_robustness_realwage_etable.txt"))
message(" - ", file.path(output_dir, "twfe_robustness_coefficients.csv"))
