#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(fixest)
})

args <- commandArgs(trailingOnly = TRUE)
project_root <- ifelse(length(args) >= 1, args[[1]], getwd())
clean_dir <- file.path(project_root, "Data", "cleaned")
analysis_dir <- file.path(project_root, "Data", "analysis")
output_dir <- file.path(project_root, "Output", "tables")
notes_dir <- file.path(project_root, "Output", "empirical_notes")
dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(notes_dir, recursive = TRUE, showWarnings = FALSE)

years <- 2016:2025

message("Reading analysis panel and IO network...")
panel_base <- read_csv(
  file.path(analysis_dir, "analysis_panel_bea_summary_2016_2025_prelim.csv"),
  show_col_types = FALSE
) |>
  filter(year %in% years)

io_coef <- read_csv(file.path(clean_dir, "bea_input_coefficients_2019.csv"), show_col_types = FALSE) |>
  mutate(value_musd_pos = pmax(value_musd, 0))

industry_output <- read_csv(file.path(clean_dir, "bea_industry_output_2019.csv"), show_col_types = FALSE) |>
  select(industry_code, total_industry_output_basic_musd)

tariff_panel <- panel_base |>
  distinct(industry_code, year, tariff_direct_prelim) |>
  mutate(tariff_direct_prelim = coalesce(tariff_direct_prelim, 0))

message("Constructing Luo-style own/upstream/downstream shocks...")
own_shock <- tariff_panel |>
  transmute(industry_code, year, own_tariff_shock = tariff_direct_prelim)

upstream_shock <- io_coef |>
  select(industry_code, commodity_code, input_share, link_5pct) |>
  crossing(year = years) |>
  left_join(
    tariff_panel |> select(commodity_code = industry_code, year, supplier_tariff_shock = tariff_direct_prelim),
    by = c("commodity_code", "year")
  ) |>
  mutate(supplier_tariff_shock = coalesce(supplier_tariff_shock, 0)) |>
  group_by(industry_code, year) |>
  summarise(
    upstream_tariff_shock = sum(input_share * supplier_tariff_shock, na.rm = TRUE),
    upstream_tariff_shock_5pct = sum(if_else(link_5pct == 1, input_share, 0) * supplier_tariff_shock, na.rm = TRUE),
    .groups = "drop"
  )

downstream_weights <- io_coef |>
  select(customer_code = industry_code, supplier_code = commodity_code, value_musd_pos) |>
  left_join(
    industry_output |> select(supplier_code = industry_code, supplier_output_musd = total_industry_output_basic_musd),
    by = "supplier_code"
  ) |>
  mutate(
    output_share = if_else(supplier_output_musd > 0, value_musd_pos / supplier_output_musd, 0),
    output_link_5pct = as.integer(output_share >= 0.05)
  )

downstream_shock <- downstream_weights |>
  crossing(year = years) |>
  left_join(
    tariff_panel |> select(customer_code = industry_code, year, customer_tariff_shock = tariff_direct_prelim),
    by = c("customer_code", "year")
  ) |>
  mutate(customer_tariff_shock = coalesce(customer_tariff_shock, 0)) |>
  group_by(industry_code = supplier_code, year) |>
  summarise(
    downstream_tariff_shock = sum(output_share * customer_tariff_shock, na.rm = TRUE),
    downstream_tariff_shock_5pct = sum(if_else(output_link_5pct == 1, output_share, 0) * customer_tariff_shock, na.rm = TRUE),
    .groups = "drop"
  )

network_panel <- expand_grid(industry_code = unique(panel_base$industry_code), year = years) |>
  left_join(own_shock, by = c("industry_code", "year")) |>
  left_join(upstream_shock, by = c("industry_code", "year")) |>
  left_join(downstream_shock, by = c("industry_code", "year")) |>
  arrange(industry_code, year) |>
  group_by(industry_code) |>
  mutate(
    across(
      c(own_tariff_shock, upstream_tariff_shock, upstream_tariff_shock_5pct,
        downstream_tariff_shock, downstream_tariff_shock_5pct),
      ~ coalesce(.x, 0)
    ),
    lag1_own_tariff_shock = lag(own_tariff_shock),
    lag1_upstream_tariff_shock = lag(upstream_tariff_shock),
    lag1_upstream_tariff_shock_5pct = lag(upstream_tariff_shock_5pct),
    lag1_downstream_tariff_shock = lag(downstream_tariff_shock),
    lag1_downstream_tariff_shock_5pct = lag(downstream_tariff_shock_5pct),
    own_tariff_shock_cum01 = own_tariff_shock + coalesce(lag1_own_tariff_shock, 0),
    upstream_tariff_shock_cum01 = upstream_tariff_shock + coalesce(lag1_upstream_tariff_shock, 0),
    upstream_tariff_shock_5pct_cum01 = upstream_tariff_shock_5pct + coalesce(lag1_upstream_tariff_shock_5pct, 0),
    downstream_tariff_shock_cum01 = downstream_tariff_shock + coalesce(lag1_downstream_tariff_shock, 0),
    downstream_tariff_shock_5pct_cum01 = downstream_tariff_shock_5pct + coalesce(lag1_downstream_tariff_shock_5pct, 0)
  ) |>
  ungroup()

write_csv(network_panel, file.path(analysis_dir, "luo_style_own_up_down_tariff_shocks_2016_2025.csv"))

panel <- panel_base |>
  left_join(network_panel, by = c("industry_code", "year")) |>
  mutate(
    industry_fe = industry_code,
    price_wage_gap = dln_gross_output_price - dln_avg_annual_pay,
    intermediate_wage_gap = dln_intermediate_inputs_price - dln_avg_annual_pay
  ) |>
  filter(year >= 2017, !is.na(dln_real_annual_pay_go_price))

message("Rows: ", nrow(panel), "; industries: ", n_distinct(panel$industry_code))

real_wage_models <- list(
  "Own shock" = feols(
    dln_real_annual_pay_go_price ~ own_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Upstream shock" = feols(
    dln_real_annual_pay_go_price ~ upstream_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Downstream shock" = feols(
    dln_real_annual_pay_go_price ~ downstream_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Own + upstream + downstream" = feols(
    dln_real_annual_pay_go_price ~ own_tariff_shock_cum01 + upstream_tariff_shock_cum01 + downstream_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Strong upstream" = feols(
    dln_real_annual_pay_go_price ~ upstream_tariff_shock_5pct_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Strong own + up + down" = feols(
    dln_real_annual_pay_go_price ~ own_tariff_shock_cum01 + upstream_tariff_shock_5pct_cum01 + downstream_tariff_shock_5pct_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  )
)

gap_models <- list(
  "Price-wage gap: own" = feols(
    price_wage_gap ~ own_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Price-wage gap: upstream" = feols(
    price_wage_gap ~ upstream_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Price-wage gap: own + up + down" = feols(
    price_wage_gap ~ own_tariff_shock_cum01 + upstream_tariff_shock_cum01 + downstream_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Price-wage gap: strong upstream" = feols(
    price_wage_gap ~ upstream_tariff_shock_5pct_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  )
)

input_gap_models <- list(
  "Input price-wage gap: upstream" = feols(
    intermediate_wage_gap ~ upstream_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Input price-wage gap: strong upstream" = feols(
    intermediate_wage_gap ~ upstream_tariff_shock_5pct_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Input price-wage gap: own + up + down" = feols(
    intermediate_wage_gap ~ own_tariff_shock_cum01 + upstream_tariff_shock_cum01 + downstream_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  )
)

price_models <- list(
  "Price: own" = feols(
    dln_gross_output_price ~ own_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Price: upstream" = feols(
    dln_gross_output_price ~ upstream_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Price: own + up + down" = feols(
    dln_gross_output_price ~ own_tariff_shock_cum01 + upstream_tariff_shock_cum01 + downstream_tariff_shock_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  ),
  "Price: strong upstream" = feols(
    dln_gross_output_price ~ upstream_tariff_shock_5pct_cum01 | industry_fe + year,
    cluster = ~industry_fe,
    data = panel
  )
)

sink(file.path(output_dir, "luo_style_real_wage_etable.txt"))
cat("Luo-style own/upstream/downstream network models: real wage\n")
cat("Generated by Data/scripts/07_run_luo_style_network_wage_models.R\n")
cat("All models include BEA summary industry fixed effects and year fixed effects. Standard errors are clustered by industry.\n")
cat("Upstream shock uses input shares; downstream shock uses supplier sales to customer industries divided by supplier total output.\n\n")
print(etable(real_wage_models, fitstat = ~ n + r2 + wr2))
sink()

sink(file.path(output_dir, "luo_style_price_wage_gap_etable.txt"))
cat("Luo-style own/upstream/downstream network models: price-wage gap\n")
cat("Generated by Data/scripts/07_run_luo_style_network_wage_models.R\n")
cat("All models include BEA summary industry fixed effects and year fixed effects. Standard errors are clustered by industry.\n\n")
print(etable(gap_models, fitstat = ~ n + r2 + wr2))
sink()

sink(file.path(output_dir, "luo_style_input_price_wage_gap_etable.txt"))
cat("Luo-style own/upstream/downstream network models: input price-wage gap\n")
cat("Generated by Data/scripts/07_run_luo_style_network_wage_models.R\n")
cat("All models include BEA summary industry fixed effects and year fixed effects. Standard errors are clustered by industry.\n\n")
print(etable(input_gap_models, fitstat = ~ n + r2 + wr2))
sink()

sink(file.path(output_dir, "luo_style_price_etable.txt"))
cat("Luo-style own/upstream/downstream network models: output price\n")
cat("Generated by Data/scripts/07_run_luo_style_network_wage_models.R\n")
cat("All models include BEA summary industry fixed effects and year fixed effects. Standard errors are clustered by industry.\n\n")
print(etable(price_models, fitstat = ~ n + r2 + wr2))
sink()

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
  extract_coefs(real_wage_models, "real_wage"),
  extract_coefs(gap_models, "price_wage_gap"),
  extract_coefs(input_gap_models, "input_price_wage_gap"),
  extract_coefs(price_models, "output_price")
)
write_csv(coef_out, file.path(output_dir, "luo_style_network_coefficients.csv"))

note <- c(
  "# Luo-style 网络传导模型：实际工资检验",
  "",
  "模型将关税冲击拆成 own shock、upstream shock 和 downstream shock。Upstream shock 使用本行业投入品供应商的关税暴露，Downstream shock 使用本行业客户行业的关税暴露。",
  "",
  "该设定借鉴 Luo and Villar (2023) 中 own / upstream / downstream shock 的思路，但不估计传统空间 SAR 模型；它更接近产业网络版 SLX 模型。",
  "",
  "主要输出：",
  "",
  "- `Output/tables/luo_style_real_wage_etable.txt`：实际工资结果。",
  "- `Output/tables/luo_style_price_wage_gap_etable.txt`：价格-工资缺口结果。",
  "- `Output/tables/luo_style_input_price_wage_gap_etable.txt`：中间品投入价格-工资缺口结果。",
  "- `Output/tables/luo_style_price_etable.txt`：总产出价格结果。",
  "- `Output/tables/luo_style_network_coefficients.csv`：所有系数和 p 值。"
)
writeLines(note, file.path(notes_dir, "luo_style_network_wage_note.md"))

message("Wrote Luo-style network wage outputs.")
