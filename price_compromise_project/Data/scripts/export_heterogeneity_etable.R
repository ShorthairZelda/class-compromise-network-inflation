#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(fixest)
})

args <- commandArgs(trailingOnly = TRUE)
project_dir <- if (length(args) >= 1) args[[1]] else "/Users/linian/Desktop/PROJ_completed/proj_class_compromise"

archive_dir <- file.path(project_dir, "Archive", "quarterly_labor_capital_heterogeneity_2026-06-29")
panel_path <- file.path(archive_dir, "Data", "analysis", "analysis_panel_bea_summary_2016_2025_quarterly.csv")
out_dir <- file.path(project_dir, "Output", "tables")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

panel <- read_csv(panel_path, show_col_types = FALSE) |>
  filter(!is.na(dln_gross_output_price)) |>
  mutate(
    industry_fe = industry_code,
    time_fe = paste0(year, "_Q", quarter),
    high_labor_share = as.integer(labor_share_2019 > median(labor_share_2019, na.rm = TRUE)),
    group_time_fe = paste0(high_labor_share, "_", time_fe),
    network_x_high_labor = network_tariff_shock_cum01 * high_labor_share,
    labor_share_va_2019 = compensation_employees_2019_musd / value_added_basic_musd,
    high_labor_share_va = as.integer(labor_share_va_2019 > median(labor_share_va_2019, na.rm = TRUE)),
    group_time_fe_va = paste0(high_labor_share_va, "_", time_fe),
    network_x_high_labor_va = network_tariff_shock_cum01 * high_labor_share_va
  )

models <- list(
  "Price" = feols(
    dln_gross_output_price ~ network_tariff_shock_cum01 | industry_fe + time_fe,
    cluster = ~industry_fe,
    data = panel
  ),
  "Nominal wage" = feols(
    dln_avg_weekly_wage ~ network_tariff_shock_cum01 | industry_fe + time_fe,
    cluster = ~industry_fe,
    data = panel
  ),
  "Real wage" = feols(
    dln_real_weekly_wage_go_price ~ network_tariff_shock_cum01 | industry_fe + time_fe,
    cluster = ~industry_fe,
    data = panel
  ),
  "Real wage x labor share" = feols(
    dln_real_weekly_wage_go_price ~ network_tariff_shock_cum01 + network_x_high_labor | industry_fe + time_fe,
    cluster = ~industry_fe,
    data = panel
  ),
  "Real wage x labor share, group time FE" = feols(
    dln_real_weekly_wage_go_price ~ network_tariff_shock_cum01 + network_x_high_labor | industry_fe + group_time_fe,
    cluster = ~industry_fe,
    data = panel
  ),
  "Real wage x VA labor share" = feols(
    dln_real_weekly_wage_go_price ~ network_tariff_shock_cum01 + network_x_high_labor_va | industry_fe + time_fe,
    cluster = ~industry_fe,
    data = panel
  )
)

dict <- c(
  network_tariff_shock_cum01 = "Network tariff shock, t plus t-1",
  network_x_high_labor = "Network shock x high labor-share industry",
  network_x_high_labor_va = "Network shock x high VA labor-share industry",
  industry_fe = "Industry FE",
  time_fe = "Year-quarter FE",
  group_time_fe = "Labor group x year-quarter FE"
)

etable(
  models,
  tex = TRUE,
  file = file.path(out_dir, "quarterly_labor_share_heterogeneity_etable.tex"),
  title = "Quarterly TWFE Heterogeneity by Labor Share",
  dict = dict,
  fitstat = ~ n + r2 + wr2,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  replace = TRUE
)

etable(
  models,
  file = file.path(out_dir, "quarterly_labor_share_heterogeneity_etable.txt"),
  title = "Quarterly TWFE Heterogeneity by Labor Share",
  dict = dict,
  fitstat = ~ n + r2 + wr2,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  replace = TRUE
)

message("Wrote heterogeneity etable to: ", out_dir)
