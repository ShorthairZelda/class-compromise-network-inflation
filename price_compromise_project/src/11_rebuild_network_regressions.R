#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(fixest)
})

args <- commandArgs(trailingOnly = TRUE)
project_root <- ifelse(length(args) >= 1, args[[1]], normalizePath(file.path(getwd(), "..")))

data_dir <- file.path(project_root, "data", "rebuild")
output_dir <- file.path(project_root, "output", "rebuild")
table_dir <- file.path(output_dir, "regressions")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

panel_path <- file.path(data_dir, "rebuild_industry_network_panel.csv")
if (!file.exists(panel_path)) {
  stop("Missing rebuilt industry panel. Run src/10_rebuild_empirical_pipeline.py first.")
}

panel <- read.csv(panel_path, stringsAsFactors = FALSE) |>
  mutate(
    industry_fe = industry_code,
    year_fe = as.factor(year),
    output_weight = ifelse(is.na(total_industry_output_basic_musd), 1, total_industry_output_basic_musd),
    tariff_direct_cum01_alt = coalesce(tariff_direct_prelim_cum01, own_tariff_shock_cum01),
    shock_period = year >= 2018
  ) |>
  filter(year >= 2017, !is.na(dln_gross_output_price), !is.na(dln_intermediate_inputs_price))

message("Rebuilt industry panel rows: ", nrow(panel), "; industries: ", n_distinct(panel$industry_code))

run_fe <- function(outcome, rhs, data = panel) {
  feols(
    as.formula(paste0(outcome, " ~ ", rhs, " | industry_fe + year")),
    cluster = ~industry_fe,
    weights = ~output_weight,
    data = data
  )
}

run_unweighted <- function(outcome, rhs, data = panel) {
  feols(
    as.formula(paste0(outcome, " ~ ", rhs, " | industry_fe + year")),
    cluster = ~industry_fe,
    data = data
  )
}

main_models <- list(
  "Output: direct" = run_fe("dln_gross_output_price", "tariff_direct_cum01_alt"),
  "Output: IO network" = run_fe("dln_gross_output_price", "network_tariff_shock_cum01"),
  "Output: Luo decomposition" = run_fe(
    "dln_gross_output_price",
    "own_tariff_shock_cum01 + upstream_tariff_shock_cum01 + downstream_tariff_shock_cum01"
  ),
  "Input: direct" = run_fe("dln_intermediate_inputs_price", "tariff_direct_cum01_alt"),
  "Input: IO network" = run_fe("dln_intermediate_inputs_price", "network_tariff_shock_cum01"),
  "Input: Luo decomposition" = run_fe(
    "dln_intermediate_inputs_price",
    "own_tariff_shock_cum01 + upstream_tariff_shock_cum01 + downstream_tariff_shock_cum01"
  )
)

strong_link_models <- list(
  "Output: full network" = run_fe("dln_gross_output_price", "network_tariff_shock_cum01"),
  "Output: 5pct network" = run_fe("dln_gross_output_price", "network_tariff_shock_5pct_cum01"),
  "Output: excl. own" = run_fe("dln_gross_output_price", "network_tariff_shock_excl_own_cum01"),
  "Input: full network" = run_fe("dln_intermediate_inputs_price", "network_tariff_shock_cum01"),
  "Input: 5pct network" = run_fe("dln_intermediate_inputs_price", "network_tariff_shock_5pct_cum01"),
  "Input: excl. own" = run_fe("dln_intermediate_inputs_price", "network_tariff_shock_excl_own_cum01")
)

robust_models <- list(
  "Output weighted" = run_fe("dln_gross_output_price", "network_tariff_shock_cum01"),
  "Output unweighted" = run_unweighted("dln_gross_output_price", "network_tariff_shock_cum01"),
  "Input weighted" = run_fe("dln_intermediate_inputs_price", "network_tariff_shock_cum01"),
  "Input unweighted" = run_unweighted("dln_intermediate_inputs_price", "network_tariff_shock_cum01")
)

event_models <- list(
  "Output event" = feols(
    dln_gross_output_price ~ i(year, direct_exposure_max, ref = 2017) | industry_fe + year,
    cluster = ~industry_fe,
    weights = ~output_weight,
    data = panel |>
      group_by(industry_code) |>
      mutate(direct_exposure_max = max(tariff_301_direct, na.rm = TRUE)) |>
      ungroup()
  ),
  "Input event" = feols(
    dln_intermediate_inputs_price ~ i(year, direct_exposure_max, ref = 2017) | industry_fe + year,
    cluster = ~industry_fe,
    weights = ~output_weight,
    data = panel |>
      group_by(industry_code) |>
      mutate(direct_exposure_max = max(tariff_301_direct, na.rm = TRUE)) |>
      ungroup()
  )
)

dict <- c(
  "dln_gross_output_price" = "Gross output price growth",
  "dln_intermediate_inputs_price" = "Intermediate input price growth",
  "tariff_direct_cum01_alt" = "Direct Section 301 exposure, t plus t-1",
  "network_tariff_shock_cum01" = "I-O network tariff exposure, t plus t-1",
  "network_tariff_shock_5pct_cum01" = "5pct strong-link network exposure, t plus t-1",
  "network_tariff_shock_excl_own_cum01" = "Network exposure excluding own industry, t plus t-1",
  "own_tariff_shock_cum01" = "Own tariff shock, t plus t-1",
  "upstream_tariff_shock_cum01" = "Supplier/upstream shock, t plus t-1",
  "downstream_tariff_shock_cum01" = "Buyer/downstream shock, t plus t-1"
)

write_etable <- function(models, stem, title) {
  txt <- capture.output(
    etable(
      models,
      dict = dict,
      fitstat = ~ n + r2 + wr2,
      signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10)
    )
  )
  writeLines(c(title, "", txt), file.path(table_dir, paste0(stem, ".txt")))

  tex <- etable(
    models,
    dict = dict,
    tex = TRUE,
    fitstat = ~ n + r2 + wr2,
    signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10)
  )
  writeLines(as.character(tex), file.path(table_dir, paste0(stem, ".tex")))
}

extract_coefs <- function(model_list, model_set) {
  bind_rows(lapply(names(model_list), function(model_name) {
    ct <- coeftable(model_list[[model_name]])
    data.frame(
      model_set = model_set,
      model = model_name,
      term = rownames(ct),
      estimate = ct[, "Estimate"],
      std_error = ct[, "Std. Error"],
      t_value = ct[, "t value"],
      p_value = ct[, "Pr(>|t|)"],
      nobs = nobs(model_list[[model_name]]),
      row.names = NULL
    )
  }))
}

write_etable(
  main_models,
  "rebuild_table1_industry_price_network_main",
  "Table 1. Tariff shocks, input-output exposure, and industry price growth"
)
write_etable(
  strong_link_models,
  "rebuild_table2_industry_price_network_robustness",
  "Table 2. Alternative input-output network exposure measures"
)
write_etable(
  robust_models,
  "rebuild_table3_weighting_robustness",
  "Table 3. Weighted and unweighted network tariff exposure estimates"
)
write_etable(
  event_models,
  "rebuild_table4_event_study",
  "Table 4. Event-study estimates by pre/post Section 301 exposure"
)

coef_out <- bind_rows(
  extract_coefs(main_models, "main"),
  extract_coefs(strong_link_models, "network_robustness"),
  extract_coefs(robust_models, "weighting_robustness"),
  extract_coefs(event_models, "event_study")
)
write.csv(coef_out, file.path(table_dir, "rebuild_network_regression_coefficients.csv"), row.names = FALSE)

key_findings <- coef_out |>
  filter(
    term %in% c(
      "tariff_direct_cum01_alt",
      "network_tariff_shock_cum01",
      "network_tariff_shock_5pct_cum01",
      "network_tariff_shock_excl_own_cum01",
      "upstream_tariff_shock_cum01",
      "downstream_tariff_shock_cum01"
    )
  ) |>
  arrange(model_set, model, term)
write.csv(key_findings, file.path(table_dir, "rebuild_key_network_coefficients.csv"), row.names = FALSE)

note <- c(
  "# Rebuilt Network Regression Notes",
  "",
  "The rebuilt regressions deliberately exclude the previous real-wage outcome. The main outcomes are BEA gross-output price growth and intermediate-input price growth.",
  "",
  "All main models include BEA summary industry fixed effects and year fixed effects. Standard errors are clustered by industry. Main specifications use industry output weights.",
  "",
  "The identifying variation comes from cross-industry differences in direct Section 301 exposure and input-output-network exposure after absorbing aggregate year shocks.",
  "",
  "Core interpretation: a positive network coefficient means that tariff exposure among an industry's input suppliers is associated with higher industry price growth, consistent with production-network propagation of the weakening low-price supply channel."
)
writeLines(note, file.path(table_dir, "rebuild_network_regression_notes.md"))

message("Wrote rebuilt network regression outputs to ", table_dir)
