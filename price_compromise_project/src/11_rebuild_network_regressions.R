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
summary_dir <- file.path(output_dir, "tables")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)

panel_path <- file.path(data_dir, "rebuild_industry_network_panel.csv")
if (!file.exists(panel_path)) {
  stop("Missing rebuilt industry panel. Run src/10_rebuild_empirical_pipeline.py first.")
}

local_reproduction_core_codes <- c(
  "HS",   # Housing
  "ORE",  # Other real estate
  "61",   # Educational services
  "621",  # Ambulatory health care
  "622",  # Hospitals
  "623",  # Nursing and residential care
  "624"   # Social assistance
)

local_reproduction_extended_codes <- c(
  local_reproduction_core_codes,
  "485",  # Transit and ground passenger transportation
  "721",  # Accommodation
  "722"   # Food services and drinking places
)

panel <- read.csv(panel_path, stringsAsFactors = FALSE) |>
  mutate(
    industry_fe = industry_code,
    year_fe = as.factor(year),
    output_weight = ifelse(is.na(total_industry_output_basic_musd), 1, total_industry_output_basic_musd),
    tariff_direct_cum01_alt = coalesce(tariff_direct_prelim_cum01, own_tariff_shock_cum01),
    shock_period = year >= 2018,
    local_reproduction_core = as.integer(industry_code %in% local_reproduction_core_codes),
    local_reproduction_extended = as.integer(industry_code %in% local_reproduction_extended_codes),
    local_reproduction_group = case_when(
      local_reproduction_core == 1 ~ "Core local reproduction",
      local_reproduction_extended == 1 ~ "Extended local services",
      TRUE ~ "Other industries"
    )
  ) |>
  filter(year >= 2017, !is.na(dln_gross_output_price), !is.na(dln_intermediate_inputs_price))

message("Rebuilt industry panel rows: ", nrow(panel), "; industries: ", n_distinct(panel$industry_code))

industry_classification <- panel |>
  distinct(
    industry_code,
    industry_name,
    local_reproduction_core,
    local_reproduction_extended,
    local_reproduction_group
  ) |>
  arrange(desc(local_reproduction_core), desc(local_reproduction_extended), industry_code)

write.csv(
  industry_classification,
  file.path(summary_dir, "rebuild_local_reproduction_industry_classification.csv"),
  row.names = FALSE
)

exposure_summary <- panel |>
  filter(year >= 2018) |>
  group_by(local_reproduction_group) |>
  summarise(
    n_industries = n_distinct(industry_code),
    mean_direct_tariff = mean(tariff_direct_cum01_alt, na.rm = TRUE),
    mean_network_tariff = mean(network_tariff_shock_cum01, na.rm = TRUE),
    mean_upstream_tariff = mean(upstream_tariff_shock_cum01, na.rm = TRUE),
    mean_downstream_tariff = mean(downstream_tariff_shock_cum01, na.rm = TRUE),
    mean_tradable_input_exposure = mean(tradable_goods_input_exposure, na.rm = TRUE),
    mean_goods_supply_chain_exposure = mean(goods_supply_chain_input_exposure, na.rm = TRUE),
    mean_tradable_downstream_exposure = mean(tradable_goods_downstream_exposure, na.rm = TRUE),
    mean_tradable_input_inflation_shock = mean(tradable_input_inflation_shock_cum01, na.rm = TRUE),
    mean_goods_supply_chain_inflation_shock = mean(goods_supply_chain_inflation_shock_cum01, na.rm = TRUE),
    mean_output_price_growth = mean(dln_gross_output_price, na.rm = TRUE),
    mean_input_price_growth = mean(dln_intermediate_inputs_price, na.rm = TRUE),
    .groups = "drop"
  )

write.csv(
  exposure_summary,
  file.path(summary_dir, "rebuild_local_reproduction_exposure_summary.csv"),
  row.names = FALSE
)

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

tradable_inflation_models <- list(
  "Output: tradable input shock" = run_fe(
    "dln_gross_output_price",
    "tradable_input_inflation_shock_cum01"
  ),
  "Input: tradable input shock" = run_fe(
    "dln_intermediate_inputs_price",
    "tradable_input_inflation_shock_cum01"
  ),
  "Output: core local x tradable input shock" = run_fe(
    "dln_gross_output_price",
    "tradable_input_inflation_shock_cum01 + tradable_input_inflation_shock_cum01:local_reproduction_core"
  ),
  "Input: core local x tradable input shock" = run_fe(
    "dln_intermediate_inputs_price",
    "tradable_input_inflation_shock_cum01 + tradable_input_inflation_shock_cum01:local_reproduction_core"
  )
)

tradable_luo_models <- list(
  "Output: upstream/downstream" = run_fe(
    "dln_gross_output_price",
    "tradable_input_inflation_shock_cum01 + tradable_downstream_inflation_shock_cum01"
  ),
  "Input: upstream/downstream" = run_fe(
    "dln_intermediate_inputs_price",
    "tradable_input_inflation_shock_cum01 + tradable_downstream_inflation_shock_cum01"
  ),
  "Output: core local up/down" = run_fe(
    "dln_gross_output_price",
    paste(
      "tradable_input_inflation_shock_cum01 + tradable_downstream_inflation_shock_cum01",
      "+ tradable_input_inflation_shock_cum01:local_reproduction_core",
      "+ tradable_downstream_inflation_shock_cum01:local_reproduction_core"
    )
  ),
  "Input: core local up/down" = run_fe(
    "dln_intermediate_inputs_price",
    paste(
      "tradable_input_inflation_shock_cum01 + tradable_downstream_inflation_shock_cum01",
      "+ tradable_input_inflation_shock_cum01:local_reproduction_core",
      "+ tradable_downstream_inflation_shock_cum01:local_reproduction_core"
    )
  )
)

tradable_inflation_robust_models <- list(
  "Output: narrow tradable inputs" = run_fe(
    "dln_gross_output_price",
    "tradable_input_inflation_shock_cum01 + tradable_input_inflation_shock_cum01:local_reproduction_core"
  ),
  "Output: broad supply-chain inputs" = run_fe(
    "dln_gross_output_price",
    "goods_supply_chain_inflation_shock_cum01 + goods_supply_chain_inflation_shock_cum01:local_reproduction_core"
  ),
  "Input: narrow tradable inputs" = run_fe(
    "dln_intermediate_inputs_price",
    "tradable_input_inflation_shock_cum01 + tradable_input_inflation_shock_cum01:local_reproduction_core"
  ),
  "Input: broad supply-chain inputs" = run_fe(
    "dln_intermediate_inputs_price",
    "goods_supply_chain_inflation_shock_cum01 + goods_supply_chain_inflation_shock_cum01:local_reproduction_core"
  )
)

tradable_pressure_gap_models <- list(
  "Output price-wage gap: core local" = run_fe(
    "price_pressure_gap",
    "tradable_input_inflation_shock_cum01 + tradable_input_inflation_shock_cum01:local_reproduction_core",
    data = panel |> filter(!is.na(price_pressure_gap))
  ),
  "Input price-wage gap: core local" = run_fe(
    "input_price_pressure_gap",
    "tradable_input_inflation_shock_cum01 + tradable_input_inflation_shock_cum01:local_reproduction_core",
    data = panel |> filter(!is.na(input_price_pressure_gap))
  ),
  "Input price-wage gap: up/down" = run_fe(
    "input_price_pressure_gap",
    paste(
      "tradable_input_inflation_shock_cum01 + tradable_downstream_inflation_shock_cum01",
      "+ tradable_input_inflation_shock_cum01:local_reproduction_core",
      "+ tradable_downstream_inflation_shock_cum01:local_reproduction_core"
    ),
    data = panel |> filter(!is.na(input_price_pressure_gap))
  )
)

local_network_models <- list(
  "Output: core local x network" = run_fe(
    "dln_gross_output_price",
    "tariff_direct_cum01_alt + network_tariff_shock_cum01 + network_tariff_shock_cum01:local_reproduction_core"
  ),
  "Output: extended local x network" = run_fe(
    "dln_gross_output_price",
    "tariff_direct_cum01_alt + network_tariff_shock_cum01 + network_tariff_shock_cum01:local_reproduction_extended"
  ),
  "Input: core local x network" = run_fe(
    "dln_intermediate_inputs_price",
    "tariff_direct_cum01_alt + network_tariff_shock_cum01 + network_tariff_shock_cum01:local_reproduction_core"
  ),
  "Input: extended local x network" = run_fe(
    "dln_intermediate_inputs_price",
    "tariff_direct_cum01_alt + network_tariff_shock_cum01 + network_tariff_shock_cum01:local_reproduction_extended"
  )
)

luo_local_models <- list(
  "Output: core up/down" = run_fe(
    "dln_gross_output_price",
    paste(
      "own_tariff_shock_cum01",
      "+ upstream_tariff_shock_cum01 + downstream_tariff_shock_cum01",
      "+ upstream_tariff_shock_cum01:local_reproduction_core",
      "+ downstream_tariff_shock_cum01:local_reproduction_core"
    )
  ),
  "Output: extended up/down" = run_fe(
    "dln_gross_output_price",
    paste(
      "own_tariff_shock_cum01",
      "+ upstream_tariff_shock_cum01 + downstream_tariff_shock_cum01",
      "+ upstream_tariff_shock_cum01:local_reproduction_extended",
      "+ downstream_tariff_shock_cum01:local_reproduction_extended"
    )
  ),
  "Input: core up/down" = run_fe(
    "dln_intermediate_inputs_price",
    paste(
      "own_tariff_shock_cum01",
      "+ upstream_tariff_shock_cum01 + downstream_tariff_shock_cum01",
      "+ upstream_tariff_shock_cum01:local_reproduction_core",
      "+ downstream_tariff_shock_cum01:local_reproduction_core"
    )
  ),
  "Input: extended up/down" = run_fe(
    "dln_intermediate_inputs_price",
    paste(
      "own_tariff_shock_cum01",
      "+ upstream_tariff_shock_cum01 + downstream_tariff_shock_cum01",
      "+ upstream_tariff_shock_cum01:local_reproduction_extended",
      "+ downstream_tariff_shock_cum01:local_reproduction_extended"
    )
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
  "downstream_tariff_shock_cum01" = "Buyer/downstream shock, t plus t-1",
  "tradable_input_inflation_shock_cum01" = "Tradable-goods input inflation shock, t plus t-1",
  "goods_supply_chain_inflation_shock_cum01" = "Broad goods supply-chain inflation shock, t plus t-1",
  "tradable_downstream_inflation_shock_cum01" = "Tradable-goods downstream inflation shock, t plus t-1",
  "tradable_input_inflation_shock_cum01:local_reproduction_core" = "Tradable input inflation shock x core local reproduction",
  "goods_supply_chain_inflation_shock_cum01:local_reproduction_core" = "Broad supply-chain inflation shock x core local reproduction",
  "tradable_downstream_inflation_shock_cum01:local_reproduction_core" = "Tradable downstream inflation shock x core local reproduction",
  "price_pressure_gap" = "Output price-wage pressure gap",
  "input_price_pressure_gap" = "Input price-wage pressure gap",
  "network_tariff_shock_cum01:local_reproduction_core" = "I-O network exposure x core local reproduction",
  "network_tariff_shock_cum01:local_reproduction_extended" = "I-O network exposure x extended local reproduction",
  "upstream_tariff_shock_cum01:local_reproduction_core" = "Supplier shock x core local reproduction",
  "downstream_tariff_shock_cum01:local_reproduction_core" = "Buyer shock x core local reproduction",
  "upstream_tariff_shock_cum01:local_reproduction_extended" = "Supplier shock x extended local reproduction",
  "downstream_tariff_shock_cum01:local_reproduction_extended" = "Buyer shock x extended local reproduction"
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
  tradable_inflation_models,
  "rebuild_table1_tradable_inflation_main",
  "Table 1. Tradable-goods inflation exposure and industry price growth"
)
write_etable(
  tradable_luo_models,
  "rebuild_table2_tradable_inflation_upstream_downstream",
  "Table 2. Luo-style upstream/downstream tradable-inflation propagation"
)
write_etable(
  tradable_inflation_robust_models,
  "rebuild_table3_tradable_inflation_robustness",
  "Table 3. Alternative tradable-goods input exposure measures"
)
write_etable(
  tradable_pressure_gap_models,
  "rebuild_table4_tradable_pressure_gap",
  "Table 4. Tradable inflation exposure and industry price-wage pressure gaps"
)
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
write_etable(
  local_network_models,
  "rebuild_table5_local_reproduction_network_heterogeneity",
  "Table 5. Network tariff exposure and local reproduction-sector heterogeneity"
)
write_etable(
  luo_local_models,
  "rebuild_table6_luo_upstream_downstream_local_reproduction",
  "Table 6. Luo-style upstream/downstream propagation into local reproduction sectors"
)

coef_out <- bind_rows(
  extract_coefs(tradable_inflation_models, "tradable_inflation_main"),
  extract_coefs(tradable_luo_models, "tradable_inflation_upstream_downstream"),
  extract_coefs(tradable_inflation_robust_models, "tradable_inflation_robustness"),
  extract_coefs(tradable_pressure_gap_models, "tradable_pressure_gap"),
  extract_coefs(main_models, "main"),
  extract_coefs(strong_link_models, "network_robustness"),
  extract_coefs(robust_models, "weighting_robustness"),
  extract_coefs(event_models, "event_study"),
  extract_coefs(local_network_models, "local_reproduction_network"),
  extract_coefs(luo_local_models, "luo_upstream_downstream_local")
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
      "downstream_tariff_shock_cum01",
      "tradable_input_inflation_shock_cum01",
      "goods_supply_chain_inflation_shock_cum01",
      "tradable_downstream_inflation_shock_cum01",
      "tradable_input_inflation_shock_cum01:local_reproduction_core",
      "goods_supply_chain_inflation_shock_cum01:local_reproduction_core",
      "tradable_downstream_inflation_shock_cum01:local_reproduction_core",
      "network_tariff_shock_cum01:local_reproduction_core",
      "network_tariff_shock_cum01:local_reproduction_extended",
      "upstream_tariff_shock_cum01:local_reproduction_core",
      "downstream_tariff_shock_cum01:local_reproduction_core",
      "upstream_tariff_shock_cum01:local_reproduction_extended",
      "downstream_tariff_shock_cum01:local_reproduction_extended"
    )
  ) |>
  arrange(model_set, model, term)
write.csv(key_findings, file.path(table_dir, "rebuild_key_network_coefficients.csv"), row.names = FALSE)

note <- c(
  "# Rebuilt Network Regression Notes",
  "",
  "The rebuilt regressions deliberately exclude the previous real-wage outcome. The main outcomes are BEA gross-output price growth and intermediate-input price growth.",
  "",
  "The preferred shock is now the interaction between 2019 tradable-goods input exposure and annual tradable-goods inflation. This treats the 2021-2022 inflation surge as a tradable-goods price shock whose industry incidence depends on predetermined input-output exposure.",
  "",
  "All main models include BEA summary industry fixed effects and year fixed effects. Standard errors are clustered by industry. Main specifications use industry output weights.",
  "",
  "The identifying variation comes from cross-industry differences in 2019 tradable-goods input exposure interacted with annual tradable-goods inflation after absorbing aggregate year shocks.",
  "",
  "Section 301 tariff exposure is retained as a supplementary policy-shock design rather than treated as the sole explanation for the 2021-2022 inflation surge.",
  "",
  "The local-reproduction heterogeneity tables extend this design by interacting tradable-input inflation exposure and tariff-network exposure with indicators for housing, real estate, education, health care, hospitals, nursing/residential care, and social assistance. This is the project's main theoretical extension beyond a generic network-transmission test.",
  "",
  "The Luo-style upstream/downstream tables separate supplier-side cost propagation from buyer-side demand propagation, then ask whether either channel is stronger for local reproduction sectors."
)
writeLines(note, file.path(table_dir, "rebuild_network_regression_notes.md"))

message("Wrote rebuilt network regression outputs to ", table_dir)
