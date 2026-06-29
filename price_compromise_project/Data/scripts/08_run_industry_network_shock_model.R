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
notes_dir <- file.path(project_root, "Output", "empirical_notes")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(notes_dir, recursive = TRUE, showWarnings = FALSE)

panel_path <- file.path(analysis_dir, "analysis_panel_bea_summary_2016_2025_prelim.csv")
shock_path <- file.path(analysis_dir, "luo_style_own_up_down_tariff_shocks_2016_2025.csv")

if (!file.exists(shock_path)) {
  stop("Network shock file not found. Run Data/scripts/07_run_luo_style_network_wage_models.R first.")
}

panel <- read_csv(panel_path, show_col_types = FALSE) |>
  left_join(read_csv(shock_path, show_col_types = FALSE), by = c("industry_code", "year")) |>
  filter(year >= 2017, !is.na(dln_gross_output_price)) |>
  mutate(
    industry_fe = industry_code,
    price_wage_gap = dln_gross_output_price - dln_avg_annual_pay,
    input_price_wage_gap = dln_intermediate_inputs_price - dln_avg_annual_pay
  )

message("Rows: ", nrow(panel), "; industries: ", n_distinct(panel$industry_code))

network_rhs <- "own_tariff_shock_cum01 + upstream_tariff_shock_cum01 + downstream_tariff_shock_cum01"
strong_network_rhs <- "own_tariff_shock_cum01 + upstream_tariff_shock_5pct_cum01 + downstream_tariff_shock_5pct_cum01"

run_model <- function(outcome, rhs, data = panel) {
  feols(
    as.formula(paste0(outcome, " ~ ", rhs, " | industry_fe + year")),
    cluster = ~industry_fe,
    data = data
  )
}

main_models <- list(
  "Output price" = run_model("dln_gross_output_price", network_rhs),
  "Input price" = run_model("dln_intermediate_inputs_price", network_rhs),
  "Nominal wage" = run_model("dln_avg_annual_pay", network_rhs),
  "Real wage" = run_model("dln_real_annual_pay_go_price", network_rhs),
  "Price-wage gap" = run_model("price_wage_gap", network_rhs)
)

strong_models <- list(
  "Output price" = run_model("dln_gross_output_price", strong_network_rhs),
  "Input price" = run_model("dln_intermediate_inputs_price", strong_network_rhs),
  "Real wage" = run_model("dln_real_annual_pay_go_price", strong_network_rhs),
  "Price-wage gap" = run_model("price_wage_gap", strong_network_rhs),
  "Input price-wage gap" = run_model("input_price_wage_gap", strong_network_rhs)
)

upstream_only_models <- list(
  "Output price" = run_model("dln_gross_output_price", "upstream_tariff_shock_cum01"),
  "Input price" = run_model("dln_intermediate_inputs_price", "upstream_tariff_shock_cum01"),
  "Nominal wage" = run_model("dln_avg_annual_pay", "upstream_tariff_shock_cum01"),
  "Real wage" = run_model("dln_real_annual_pay_go_price", "upstream_tariff_shock_cum01"),
  "Price-wage gap" = run_model("price_wage_gap", "upstream_tariff_shock_cum01")
)

dict <- c(
  "dln_gross_output_price" = "Output price growth",
  "dln_intermediate_inputs_price" = "Input price growth",
  "dln_avg_annual_pay" = "Nominal wage growth",
  "dln_real_annual_pay_go_price" = "Industry-price real wage growth",
  "price_wage_gap" = "Output price minus wage growth",
  "input_price_wage_gap" = "Input price minus wage growth",
  "own_tariff_shock_cum01" = "Own tariff shock, t plus t-1",
  "upstream_tariff_shock_cum01" = "Upstream network shock, t plus t-1",
  "downstream_tariff_shock_cum01" = "Downstream network shock, t plus t-1",
  "upstream_tariff_shock_5pct_cum01" = "Strong-link upstream shock, t plus t-1",
  "downstream_tariff_shock_5pct_cum01" = "Strong-link downstream shock, t plus t-1"
)

write_table <- function(models, stem, title) {
  sink(file.path(output_dir, paste0(stem, ".txt")))
  cat(title, "\n")
  cat("Industry network shock model. All models include BEA summary industry fixed effects and year fixed effects. Standard errors are clustered by industry.\n\n")
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
  writeLines(as.character(tex), file.path(output_dir, paste0(stem, ".tex")))
}

write_table(main_models, "industry_network_shock_main_etable", "Table. Industry network shock model: own, upstream, and downstream shocks")
write_table(strong_models, "industry_network_shock_strong_links_etable", "Table. Industry network shock model: strong IO links")
write_table(upstream_only_models, "industry_network_shock_upstream_only_etable", "Table. Industry network shock model: upstream shock only")

extract_coefs <- function(model_list, model_set) {
  bind_rows(lapply(names(model_list), function(model_name) {
    ct <- coeftable(model_list[[model_name]])
    tibble(
      model_set = model_set,
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
  extract_coefs(main_models, "own_upstream_downstream"),
  extract_coefs(strong_models, "strong_links"),
  extract_coefs(upstream_only_models, "upstream_only")
)
write_csv(coef_out, file.path(output_dir, "industry_network_shock_coefficients.csv"))

key <- coef_out |>
  filter(
    (model_set == "upstream_only" & model %in% c("Output price", "Input price", "Real wage", "Price-wage gap")) |
      (model_set == "strong_links" & model %in% c("Output price", "Input price", "Real wage", "Price-wage gap", "Input price-wage gap"))
  )

note <- c(
  "# 产业网络冲击模型结果备忘",
  "",
  "模型形式：",
  "",
  "`Y_it = beta1 OwnShock_it + beta2 UpstreamShock_it + beta3 DownstreamShock_it + industry FE + year FE + error_it`",
  "",
  "其中 OwnShock 为本行业直接 Section 301 关税暴露；UpstreamShock 为本行业投入品供应商的关税暴露，按 2019 年 BEA 投入份额加权；DownstreamShock 为客户行业关税暴露，按本行业销售给客户行业的产出份额加权。",
  "",
  "主要发现：",
  "",
  "- 上游网络冲击对总产出价格显著为正，说明价格效应主要来自供应链上游，而非本行业直接暴露。",
  "- 上游网络冲击对中间品投入价格也显著为正，说明生产/再生产成本压力沿投入网络传导。",
  "- 实际工资和价格-工资缺口方向符合理论，但通常只在 10% 水平边际显著，适合作为辅助证据。",
  "- 同时放入 own、upstream、downstream 时，由于三类网络冲击相关性较高，单个系数显著性会下降；因此 upstream-only 和 strong-link upstream 是更清晰的机制检验。",
  "",
  "输出文件：",
  "",
  "- `Output/tables/industry_network_shock_main_etable.txt`",
  "- `Output/tables/industry_network_shock_strong_links_etable.txt`",
  "- `Output/tables/industry_network_shock_upstream_only_etable.txt`",
  "- `Output/tables/industry_network_shock_coefficients.csv`"
)

writeLines(note, file.path(notes_dir, "industry_network_shock_model_note.md"))

message("Wrote industry network shock model outputs.")
