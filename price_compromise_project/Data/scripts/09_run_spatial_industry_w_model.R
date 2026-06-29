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

row_standardize <- function(mat) {
  rs <- rowSums(mat, na.rm = TRUE)
  out <- mat
  positive <- rs > 0
  out[positive, ] <- out[positive, , drop = FALSE] / rs[positive]
  out[!positive, ] <- 0
  out
}

shortest_path_weights <- function(adj) {
  n <- nrow(adj)
  dist <- matrix(Inf, n, n, dimnames = dimnames(adj))
  dist[adj > 0] <- 1
  diag(dist) <- 0

  for (k in seq_len(n)) {
    for (i in seq_len(n)) {
      via_k <- dist[i, k] + dist[k, ]
      better <- via_k < dist[i, ]
      dist[i, better] <- via_k[better]
    }
  }

  w <- 1 / dist
  w[!is.finite(w)] <- 0
  diag(w) <- 0
  row_standardize(w)
}

matrix_to_long <- function(w, name) {
  as.data.frame(as.table(w), stringsAsFactors = FALSE) |>
    transmute(
      matrix = name,
      industry_code = as.character(Var1),
      neighbor_code = as.character(Var2),
      weight = as.numeric(Freq)
    ) |>
    filter(weight != 0)
}

message("Reading panel and IO data...")
panel_base <- read_csv(
  file.path(analysis_dir, "analysis_panel_bea_summary_2016_2025_prelim.csv"),
  show_col_types = FALSE
) |>
  filter(year %in% years)

industries <- panel_base |>
  distinct(industry_code, industry_name) |>
  arrange(industry_code)

codes <- industries$industry_code
n <- length(codes)

io <- read_csv(file.path(clean_dir, "bea_input_coefficients_2019.csv"), show_col_types = FALSE) |>
  filter(industry_code %in% codes, commodity_code %in% codes) |>
  mutate(input_share_pos = pmax(input_share, 0))

message("Building spatial-style industry W matrices...")
a_input <- matrix(0, n, n, dimnames = list(codes, codes))
for (idx in seq_len(nrow(io))) {
  a_input[io$industry_code[idx], io$commodity_code[idx]] <- io$input_share_pos[idx]
}
diag(a_input) <- 0

w_input_share <- row_standardize(a_input)
w_binary_5pct <- row_standardize((a_input >= 0.05) * 1)
w_symmetric <- row_standardize((a_input + t(a_input)) / 2)
w_distance_5pct <- shortest_path_weights(((a_input >= 0.05) | (t(a_input) >= 0.05)) * 1)

w_mats <- list(
  input_share = w_input_share,
  binary_5pct = w_binary_5pct,
  symmetric_input_output = w_symmetric,
  inverse_network_distance_5pct = w_distance_5pct
)

w_long <- bind_rows(lapply(names(w_mats), function(name) matrix_to_long(w_mats[[name]], name))) |>
  left_join(industries |> rename(neighbor_name = industry_name), by = c("neighbor_code" = "industry_code")) |>
  left_join(industries |> rename(industry_name = industry_name), by = "industry_code")

write_csv(w_long, file.path(analysis_dir, "spatial_industry_w_matrices_long.csv"))

w_summary <- bind_rows(lapply(names(w_mats), function(name) {
  w <- w_mats[[name]]
  tibble(
    matrix = name,
    industries = nrow(w),
    nonzero_links = sum(w > 0),
    mean_neighbors = mean(rowSums(w > 0)),
    median_neighbors = median(rowSums(w > 0)),
    isolated_rows = sum(rowSums(w > 0) == 0),
    row_sum_min = min(rowSums(w)),
    row_sum_max = max(rowSums(w))
  )
}))
write_csv(w_summary, file.path(analysis_dir, "spatial_industry_w_matrix_summary.csv"))

tariff_wide <- panel_base |>
  distinct(industry_code, year, tariff_direct_prelim) |>
  mutate(tariff_direct_prelim = coalesce(tariff_direct_prelim, 0)) |>
  complete(industry_code = codes, year = years, fill = list(tariff_direct_prelim = 0)) |>
  arrange(year, industry_code)

message("Creating W-shock variables...")
spatial_shocks <- bind_rows(lapply(years, function(yr) {
  shock_vec <- tariff_wide |>
    filter(year == yr) |>
    arrange(match(industry_code, codes)) |>
    pull(tariff_direct_prelim)
  names(shock_vec) <- codes

  tibble(industry_code = codes, year = yr) |>
    mutate(
      direct_tariff_shock = shock_vec,
      w_input_share_shock = as.numeric(w_input_share %*% shock_vec),
      w_binary_5pct_shock = as.numeric(w_binary_5pct %*% shock_vec),
      w_symmetric_shock = as.numeric(w_symmetric %*% shock_vec),
      w_distance_5pct_shock = as.numeric(w_distance_5pct %*% shock_vec)
    )
})) |>
  arrange(industry_code, year) |>
  group_by(industry_code) |>
  mutate(
    lag1_direct_tariff_shock = lag(direct_tariff_shock),
    lag1_w_input_share_shock = lag(w_input_share_shock),
    lag1_w_binary_5pct_shock = lag(w_binary_5pct_shock),
    lag1_w_symmetric_shock = lag(w_symmetric_shock),
    lag1_w_distance_5pct_shock = lag(w_distance_5pct_shock),
    direct_tariff_shock_cum01 = direct_tariff_shock + coalesce(lag1_direct_tariff_shock, 0),
    w_input_share_shock_cum01 = w_input_share_shock + coalesce(lag1_w_input_share_shock, 0),
    w_binary_5pct_shock_cum01 = w_binary_5pct_shock + coalesce(lag1_w_binary_5pct_shock, 0),
    w_symmetric_shock_cum01 = w_symmetric_shock + coalesce(lag1_w_symmetric_shock, 0),
    w_distance_5pct_shock_cum01 = w_distance_5pct_shock + coalesce(lag1_w_distance_5pct_shock, 0)
  ) |>
  ungroup()

write_csv(spatial_shocks, file.path(analysis_dir, "spatial_industry_w_shocks_2016_2025.csv"))

panel <- panel_base |>
  left_join(spatial_shocks, by = c("industry_code", "year")) |>
  filter(year >= 2017, !is.na(dln_gross_output_price)) |>
  mutate(
    industry_fe = industry_code,
    price_wage_gap = dln_gross_output_price - dln_avg_annual_pay,
    input_price_wage_gap = dln_intermediate_inputs_price - dln_avg_annual_pay
  )

message("Rows: ", nrow(panel), "; industries: ", n_distinct(panel$industry_code))

run_spatial_x <- function(outcome, wshock) {
  feols(
    as.formula(paste0(outcome, " ~ direct_tariff_shock_cum01 + ", wshock, " | industry_fe + year")),
    cluster = ~industry_fe,
    data = panel
  )
}

price_models <- list(
  "Input-share W" = run_spatial_x("dln_gross_output_price", "w_input_share_shock_cum01"),
  "Binary 5pct W" = run_spatial_x("dln_gross_output_price", "w_binary_5pct_shock_cum01"),
  "Symmetric W" = run_spatial_x("dln_gross_output_price", "w_symmetric_shock_cum01"),
  "Network-distance W" = run_spatial_x("dln_gross_output_price", "w_distance_5pct_shock_cum01")
)

input_price_models <- list(
  "Input-share W" = run_spatial_x("dln_intermediate_inputs_price", "w_input_share_shock_cum01"),
  "Binary 5pct W" = run_spatial_x("dln_intermediate_inputs_price", "w_binary_5pct_shock_cum01"),
  "Symmetric W" = run_spatial_x("dln_intermediate_inputs_price", "w_symmetric_shock_cum01"),
  "Network-distance W" = run_spatial_x("dln_intermediate_inputs_price", "w_distance_5pct_shock_cum01")
)

real_wage_models <- list(
  "Input-share W" = run_spatial_x("dln_real_annual_pay_go_price", "w_input_share_shock_cum01"),
  "Binary 5pct W" = run_spatial_x("dln_real_annual_pay_go_price", "w_binary_5pct_shock_cum01"),
  "Symmetric W" = run_spatial_x("dln_real_annual_pay_go_price", "w_symmetric_shock_cum01"),
  "Network-distance W" = run_spatial_x("dln_real_annual_pay_go_price", "w_distance_5pct_shock_cum01")
)

gap_models <- list(
  "Input-share W" = run_spatial_x("price_wage_gap", "w_input_share_shock_cum01"),
  "Binary 5pct W" = run_spatial_x("price_wage_gap", "w_binary_5pct_shock_cum01"),
  "Symmetric W" = run_spatial_x("price_wage_gap", "w_symmetric_shock_cum01"),
  "Network-distance W" = run_spatial_x("price_wage_gap", "w_distance_5pct_shock_cum01")
)

dict <- c(
  "dln_gross_output_price" = "Output price growth",
  "dln_intermediate_inputs_price" = "Input price growth",
  "dln_real_annual_pay_go_price" = "Industry-price real wage growth",
  "price_wage_gap" = "Output price minus wage growth",
  "direct_tariff_shock_cum01" = "Direct tariff shock, t plus t-1",
  "w_input_share_shock_cum01" = "W shock: input-share matrix",
  "w_binary_5pct_shock_cum01" = "W shock: binary 5pct matrix",
  "w_symmetric_shock_cum01" = "W shock: symmetric matrix",
  "w_distance_5pct_shock_cum01" = "W shock: inverse network-distance matrix"
)

write_table <- function(models, stem, title) {
  sink(file.path(output_dir, paste0(stem, ".txt")))
  cat(title, "\n")
  cat("Spatial-econometric style industry W model. All models include BEA summary industry fixed effects and year fixed effects. Standard errors are clustered by industry.\n\n")
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

write_table(price_models, "spatial_w_output_price_etable", "Table. Spatial W model: output price")
write_table(input_price_models, "spatial_w_input_price_etable", "Table. Spatial W model: input price")
write_table(real_wage_models, "spatial_w_real_wage_etable", "Table. Spatial W model: industry-price real wage")
write_table(gap_models, "spatial_w_price_wage_gap_etable", "Table. Spatial W model: price-wage gap")

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
  extract_coefs(price_models, "output_price"),
  extract_coefs(input_price_models, "input_price"),
  extract_coefs(real_wage_models, "real_wage"),
  extract_coefs(gap_models, "price_wage_gap")
)
write_csv(coef_out, file.path(output_dir, "spatial_w_model_coefficients.csv"))

note <- c(
  "# 空间计量式产业 W 矩阵模型结果备忘",
  "",
  "本模型不采用 Luo and Villar 的结构分解，而是借鉴空间计量经济学中的权重矩阵思想，重新构建产业网络 W 矩阵。",
  "",
  "模型形式：",
  "",
  "`Y_it = beta DirectShock_it + theta WShock_it + industry FE + year FE + error_it`",
  "",
  "W 矩阵版本：",
  "",
  "- `input_share`：基于 2019 年 BEA 投入份额的有向行标准化矩阵，去除对角线。",
  "- `binary_5pct`：投入份额超过 5% 的强连接邻接矩阵，行标准化。",
  "- `symmetric_input_output`：将投入关系对称化后行标准化，表示一般产业邻近性。",
  "- `inverse_network_distance_5pct`：基于 5% 强连接网络的最短路径距离，使用距离倒数作为权重并行标准化。",
  "",
  "解释：`WShock` 是空间计量意义上的 spatial lag of X，即相邻产业冲击，而不是 spatial lag of Y。因此它避免了同时期 `WY` 带来的反射问题，更适合作为本文主检验。",
  "",
  "输出文件：",
  "",
  "- `Data/analysis/spatial_industry_w_matrices_long.csv`",
  "- `Data/analysis/spatial_industry_w_matrix_summary.csv`",
  "- `Data/analysis/spatial_industry_w_shocks_2016_2025.csv`",
  "- `Output/tables/spatial_w_output_price_etable.txt`",
  "- `Output/tables/spatial_w_input_price_etable.txt`",
  "- `Output/tables/spatial_w_real_wage_etable.txt`",
  "- `Output/tables/spatial_w_price_wage_gap_etable.txt`",
  "- `Output/tables/spatial_w_model_coefficients.csv`"
)
writeLines(note, file.path(notes_dir, "spatial_industry_w_model_note.md"))

message("Wrote spatial industry W model outputs.")
