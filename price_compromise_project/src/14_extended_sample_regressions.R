#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(fixest)
})

args <- commandArgs(trailingOnly = TRUE)
project_root <- ifelse(length(args) >= 1, args[[1]], normalizePath(file.path(getwd(), "..")))

data_dir <- file.path(project_root, "Data", "extended")
output_dir <- file.path(project_root, "Output", "rebuild")
table_dir <- file.path(output_dir, "regressions")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

panel_path <- file.path(data_dir, "extended_industry_network_panel_2010_2025.csv")
if (!file.exists(panel_path)) {
  stop("Missing extended panel. Run src/13_build_extended_sample.py first.")
}

local_reproduction_core_codes <- c(
  "HS",
  "ORE",
  "61",
  "621",
  "622",
  "623",
  "624"
)

panel_all <- read.csv(panel_path, stringsAsFactors = FALSE) |>
  mutate(
    industry_fe = industry_code,
    year = as.integer(year),
    output_weight = ifelse(is.na(total_industry_output_basic_musd), 1, total_industry_output_basic_musd),
    local_reproduction_core = as.integer(industry_code %in% local_reproduction_core_codes),
    post2021 = as.integer(year >= 2021)
  ) |>
  filter(
    year >= 2010,
    year <= 2025,
    !is.na(dln_gross_output_price),
    !is.na(dln_intermediate_inputs_price),
    !is.na(tradable_input_inflation_shock_cum01)
  )

message("Extended panel rows: ", nrow(panel_all), "; industries: ", n_distinct(panel_all$industry_code))

sample_summary <- panel_all |>
  summarise(
    sample_start = min(year, na.rm = TRUE),
    sample_end = max(year, na.rm = TRUE),
    rows = n(),
    industries = n_distinct(industry_code),
    mean_tradable_input_exposure = mean(tradable_goods_input_exposure, na.rm = TRUE),
    mean_tradable_input_shock = mean(tradable_input_inflation_shock_cum01, na.rm = TRUE),
    mean_output_price_growth = mean(dln_gross_output_price, na.rm = TRUE),
    mean_input_price_growth = mean(dln_intermediate_inputs_price, na.rm = TRUE)
  )
write.csv(
  sample_summary,
  file.path(output_dir, "tables", "rebuild_extended_sample_summary.csv"),
  row.names = FALSE
)

run_fe <- function(outcome, rhs, data) {
  feols(
    as.formula(paste0(outcome, " ~ ", rhs, " | industry_fe + year")),
    cluster = ~industry_fe,
    weights = ~output_weight,
    data = data
  )
}

data_main <- panel_all |> filter(year >= 2017)
data_extended <- panel_all
data_precovid <- panel_all |> filter(year <= 2019)

extended_models <- list(
  "Output: 2017-2025" = run_fe(
    "dln_gross_output_price",
    "tradable_input_inflation_shock_cum01",
    data_main
  ),
  "Output: 2010-2025" = run_fe(
    "dln_gross_output_price",
    "tradable_input_inflation_shock_cum01",
    data_extended
  ),
  "Output: 2010-2019" = run_fe(
    "dln_gross_output_price",
    "tradable_input_inflation_shock_cum01",
    data_precovid
  ),
  "Input: 2017-2025" = run_fe(
    "dln_intermediate_inputs_price",
    "tradable_input_inflation_shock_cum01",
    data_main
  ),
  "Input: 2010-2025" = run_fe(
    "dln_intermediate_inputs_price",
    "tradable_input_inflation_shock_cum01",
    data_extended
  ),
  "Input: 2010-2019" = run_fe(
    "dln_intermediate_inputs_price",
    "tradable_input_inflation_shock_cum01",
    data_precovid
  )
)

heterogeneity_models <- list(
  "Output: local, 2017-2025" = run_fe(
    "dln_gross_output_price",
    "tradable_input_inflation_shock_cum01 + tradable_input_inflation_shock_cum01:local_reproduction_core",
    data_main
  ),
  "Output: local, 2010-2025" = run_fe(
    "dln_gross_output_price",
    "tradable_input_inflation_shock_cum01 + tradable_input_inflation_shock_cum01:local_reproduction_core",
    data_extended
  ),
  "Input: local, 2017-2025" = run_fe(
    "dln_intermediate_inputs_price",
    "tradable_input_inflation_shock_cum01 + tradable_input_inflation_shock_cum01:local_reproduction_core",
    data_main
  ),
  "Input: local, 2010-2025" = run_fe(
    "dln_intermediate_inputs_price",
    "tradable_input_inflation_shock_cum01 + tradable_input_inflation_shock_cum01:local_reproduction_core",
    data_extended
  )
)

post_interaction_models <- list(
  "Output: post-2021 amplification" = run_fe(
    "dln_gross_output_price",
    "tradable_input_inflation_shock_cum01 + tradable_input_inflation_shock_cum01:post2021",
    data_extended
  ),
  "Input: post-2021 amplification" = run_fe(
    "dln_intermediate_inputs_price",
    "tradable_input_inflation_shock_cum01 + tradable_input_inflation_shock_cum01:post2021",
    data_extended
  ),
  "Output: local post-2021 amplification" = run_fe(
    "dln_gross_output_price",
    paste(
      "tradable_input_inflation_shock_cum01",
      "+ tradable_input_inflation_shock_cum01:post2021",
      "+ tradable_input_inflation_shock_cum01:local_reproduction_core",
      "+ tradable_input_inflation_shock_cum01:post2021:local_reproduction_core"
    ),
    data_extended
  ),
  "Input: local post-2021 amplification" = run_fe(
    "dln_intermediate_inputs_price",
    paste(
      "tradable_input_inflation_shock_cum01",
      "+ tradable_input_inflation_shock_cum01:post2021",
      "+ tradable_input_inflation_shock_cum01:local_reproduction_core",
      "+ tradable_input_inflation_shock_cum01:post2021:local_reproduction_core"
    ),
    data_extended
  )
)

dict <- c(
  "dln_gross_output_price" = "Gross output price growth",
  "dln_intermediate_inputs_price" = "Intermediate input price growth",
  "tradable_input_inflation_shock_cum01" = "Tradable-goods input inflation shock, t plus t-1",
  "tradable_input_inflation_shock_cum01:local_reproduction_core" = "Tradable input shock x core local reproduction",
  "tradable_input_inflation_shock_cum01:post2021" = "Tradable input shock x post-2021",
  "tradable_input_inflation_shock_cum01:post2021:local_reproduction_core" = "Tradable input shock x post-2021 x core local reproduction"
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
  extended_models,
  "rebuild_table7_extended_sample_robustness",
  "Table 7. Extended-sample robustness: tradable-goods inflation exposure"
)
write_etable(
  heterogeneity_models,
  "rebuild_table8_extended_local_reproduction_heterogeneity",
  "Table 8. Extended-sample local reproduction-sector heterogeneity"
)
write_etable(
  post_interaction_models,
  "rebuild_table9_extended_post2021_amplification",
  "Table 9. Extended-sample post-2021 amplification tests"
)

coef_out <- bind_rows(
  extract_coefs(extended_models, "extended_sample_robustness"),
  extract_coefs(heterogeneity_models, "extended_local_reproduction"),
  extract_coefs(post_interaction_models, "extended_post2021_amplification")
)
write.csv(
  coef_out,
  file.path(table_dir, "rebuild_extended_sample_coefficients.csv"),
  row.names = FALSE
)

notes <- c(
  "# Extended-Sample Robustness Notes",
  "",
  "These models use the separate extended panel generated by `src/13_build_extended_sample.py`.",
  "",
  "The main empirical tables remain based on the preferred 2017-2025 window. The extended tables test whether the tradable-input inflation result is sensitive to the short sample.",
  "",
  "The 2010-2025 panel uses BEA annual gross-output and intermediate-input price indexes, QCEW private-industry annual wages, 2019 BEA input-output exposure, and BLS CPI-U core commodities/services proxies.",
  "",
  "Because the I-O exposure is fixed at 2019, the extended sample should be interpreted as a robustness check rather than the preferred historical design for the full 2010s.",
  "",
  "The 2010-2019 placebo columns ask whether the same exposure structure predicts price growth before the pandemic-era tradable-goods inflation spike.",
  "",
  "The post-2021 interaction columns test whether the tradable-input exposure effect is amplified during the high-inflation period."
)
writeLines(notes, file.path(table_dir, "rebuild_extended_sample_notes.md"))

message("Wrote extended-sample regression outputs to ", table_dir)
