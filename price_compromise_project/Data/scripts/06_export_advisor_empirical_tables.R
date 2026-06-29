#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(fixest)
})

args <- commandArgs(trailingOnly = TRUE)
project_root <- ifelse(length(args) >= 1, args[[1]], getwd())
analysis_dir <- file.path(project_root, "Data", "analysis")
table_dir <- file.path(project_root, "Output", "tables")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

panel <- read_csv(
  file.path(analysis_dir, "analysis_panel_bea_summary_2016_2025_prelim.csv"),
  show_col_types = FALSE
) |>
  filter(year >= 2017, !is.na(dln_gross_output_price)) |>
  mutate(
    industry_fe = industry_code,
    shock_period = as.integer(year %in% 2021:2022),
    price_wage_gap = dln_gross_output_price - dln_avg_annual_pay
  )

naics_panel <- read_csv(
  file.path(analysis_dir, "analysis_panel_naics6_qcew_2016_2025.csv"),
  show_col_types = FALSE
) |>
  filter(year >= 2017, !is.na(dln_avg_annual_pay), annual_avg_emplvl > 0) |>
  mutate(naics_fe = naics_code)

naics_matched <- naics_panel |>
  group_by(naics_code) |>
  filter(any(has_301_import_weight == 1)) |>
  ungroup()

models_main <- list(
  "Output price" = feols(
    dln_gross_output_price ~ network_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Input price" = feols(
    dln_intermediate_inputs_price ~ network_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Nominal wage" = feols(
    dln_avg_annual_pay ~ network_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Real wage" = feols(
    dln_real_annual_pay_go_price ~ network_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  )
)

models_strong <- list(
  "Output price" = feols(
    dln_gross_output_price ~ network_tariff_shock_5pct_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Input price" = feols(
    dln_intermediate_inputs_price ~ network_tariff_shock_5pct_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Price-wage gap" = feols(
    price_wage_gap ~ network_tariff_shock_5pct_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Real wage" = feols(
    dln_real_annual_pay_go_price ~ network_tariff_shock_5pct_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Output price, 2021-22" = feols(
    dln_gross_output_price ~ network_tariff_shock_cum01 * shock_period | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  )
)

models_price_robust <- list(
  "Direct shock" = feols(
    dln_gross_output_price ~ tariff_direct_prelim_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Full IO network" = feols(
    dln_gross_output_price ~ network_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Excl. own industry" = feols(
    dln_gross_output_price ~ network_tariff_shock_excl_own_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Strong IO links" = feols(
    dln_gross_output_price ~ network_tariff_shock_5pct_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  )
)

models_naics_wage <- list(
  "All NAICS6" = feols(
    dln_avg_annual_pay ~ tariff_301_direct_cum01 | naics_fe + year,
    cluster = ~naics_fe,
    data = naics_panel
  ),
  "Matched NAICS6" = feols(
    dln_avg_annual_pay ~ tariff_301_direct_cum01 | naics_fe + year,
    cluster = ~naics_fe,
    data = naics_matched
  ),
  "All NAICS6 weighted" = feols(
    dln_avg_annual_pay ~ tariff_301_direct_cum01 | naics_fe + year,
    cluster = ~naics_fe,
    weights = ~annual_avg_emplvl,
    data = naics_panel
  ),
  "Matched NAICS6 weighted" = feols(
    dln_avg_annual_pay ~ tariff_301_direct_cum01 | naics_fe + year,
    cluster = ~naics_fe,
    weights = ~annual_avg_emplvl,
    data = naics_matched
  )
)

dict <- c(
  "dln_gross_output_price" = "Output price growth",
  "dln_intermediate_inputs_price" = "Input price growth",
  "dln_avg_annual_pay" = "Nominal wage growth",
  "dln_real_annual_pay_go_price" = "Industry-price real wage growth",
  "price_wage_gap" = "Output price minus wage growth",
  "network_tariff_shock_cum01" = "Network tariff shock, t plus t-1",
  "network_tariff_shock_5pct_cum01" = "Strong-link network tariff shock, t plus t-1",
  "tariff_direct_prelim_cum01" = "Direct tariff shock, t plus t-1",
  "network_tariff_shock_excl_own_cum01" = "Network tariff shock excluding own industry",
  "tariff_301_direct_cum01" = "Direct Section 301 exposure, t plus t-1",
  "network_tariff_shock_cum01:shock_period" = "Network shock x 2021-2022"
)

write_table <- function(models, stem, title) {
  txt_path <- file.path(table_dir, paste0(stem, ".txt"))
  tex_path <- file.path(table_dir, paste0(stem, ".tex"))

  sink(txt_path)
  cat(title, "\n")
  cat("All models include industry/NAICS fixed effects and year fixed effects. Standard errors are clustered by industry/NAICS.\n\n")
  print(etable(
    models,
    dict = dict,
    fitstat = ~ n + r2 + wr2,
    signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10)
  ))
  sink()

  tex <- etable(
    models,
    dict = dict,
    tex = TRUE,
    fitstat = ~ n + r2 + wr2,
    signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10)
  )
  writeLines(as.character(tex), tex_path)
}

write_table(models_main, "advisor_table1_main_mechanism", "Table 1. Main mechanism: network tariff shocks, prices, and wages")
write_table(models_strong, "advisor_table2_strong_links_gap", "Table 2. Strong IO links and price-wage gap")
write_table(models_price_robust, "advisor_table3_price_robustness", "Table 3. Price robustness across tariff exposure measures")
write_table(models_naics_wage, "advisor_appendix_table_naics_wage", "Appendix Table. NAICS six-digit wage checks")

message("Advisor empirical tables exported to: ", table_dir)
