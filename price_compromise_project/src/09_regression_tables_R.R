#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(fixest)
})

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

script_path <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% "src/09_regression_tables_R.R"), mustWork = FALSE)
project_root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(project_root, "data"))) {
  project_root <- normalizePath(getwd(), mustWork = TRUE)
}

data_dir <- file.path(project_root, "data", "processed")
out_dir <- file.path(project_root, "output", "regressions")
table_dir <- file.path(project_root, "output", "tables")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

panel <- read.csv(file.path(data_dir, "category_price_regression_panel.csv"))
indices <- read.csv(file.path(data_dir, "constructed_price_indices.csv"))
wages <- read.csv(file.path(data_dir, "real_wage_indices.csv"))
fred <- read.csv(file.path(data_dir, "fred_series_annual_clean.csv"))

write_booktabs_table <- function(df, file, align = NULL) {
  if (is.null(align)) {
    align <- paste0("l", paste(rep("r", ncol(df) - 1), collapse = ""))
  }
  lines <- c(
    "\\begingroup",
    "\\centering",
    paste0("\\begin{tabular}{", align, "}"),
    "\\toprule",
    paste(names(df), collapse = " & "),
    "\\\\",
    "\\midrule"
  )
  body <- apply(df, 1, function(row) paste(row, collapse = " & "))
  lines <- c(lines, paste0(body, "\\\\"), "\\bottomrule", "\\end{tabular}", "\\par\\endgroup")
  writeLines(lines, file, useBytes = TRUE)
}

desc <- read.csv(file.path(project_root, "output", "tables", "descriptive_statistics.csv"))
desc_out <- data.frame(
  Index = desc$index_name,
  `Sample` = paste0(desc$first_year, "--", desc$last_year),
  `Mean index` = sprintf("%.2f", desc$mean_index),
  `2025 index` = sprintf("%.2f", desc$last_index),
  `Mean inflation` = paste0(sprintf("%.2f", desc$mean_inflation), "\\%"),
  check.names = FALSE
)
write_booktabs_table(desc_out, file.path(table_dir, "r_table_descriptive_indices.tex"), align = "lrrrr")

tariff_summary <- read.csv(file.path(project_root, "output", "tables", "cpi_category_301_tariff_exposure_summary.csv"))
tariff_summary <- tariff_summary[order(-tariff_summary$mean_tariff_301_rate), ]
tariff_out <- data.frame(
  Category = gsub("_", "-", tariff_summary$category, fixed = TRUE),
  `Mean 301 exposure` = paste0(sprintf("%.2f", 100 * tariff_summary$mean_tariff_301_rate), "\\%"),
  `Max 301 exposure` = paste0(sprintf("%.2f", 100 * tariff_summary$max_tariff_301_rate), "\\%"),
  `Matched industries` = tariff_summary$matched_industries,
  check.names = FALSE
)
write_booktabs_table(tariff_out, file.path(table_dir, "r_table_tariff_mapping_summary.tex"), align = "lrrr")

panel$category <- factor(panel$category)
panel$year_fe <- factor(panel$year)

tariff_data <- subset(panel, year >= 2016 & !is.na(delta_price) & !is.na(tariff_301_rate))
m_tariff <- feols(
  delta_price ~ tariff_301_rate | category + year_fe,
  data = tariff_data,
  vcov = "hetero"
)

shock <- subset(
  fred,
  series %in% c("global_supply_chain_pressure", "import_price_index_all", "transportation_warehousing_ppi")
)
shock_priority <- c("global_supply_chain_pressure", "import_price_index_all", "transportation_warehousing_ppi")
shock_series <- shock_priority[shock_priority %in% unique(shock$series)][1]
shock <- subset(shock, series == shock_series, select = c("year", "value"))
names(shock)[names(shock) == "value"] <- "supply_chain_shock"
supply_data <- merge(panel, shock, by = "year")
supply_data <- subset(supply_data, !is.na(delta_price) & !is.na(tradable) & !is.na(supply_chain_shock))
supply_data$tradable_x_supply_chain <- supply_data$tradable * supply_data$supply_chain_shock
m_supply <- feols(
  delta_price ~ tradable_x_supply_chain | category + year_fe,
  data = supply_data,
  vcov = "hetero"
)

wide <- reshape(
  indices[, c("year", "index_name", "inflation")],
  idvar = "year",
  timevar = "index_name",
  direction = "wide"
)
names(wide) <- sub("^inflation\\.", "", names(wide))
names(wide)[names(wide) == "BasicReproductionCostIndex"] <- "basic_reproduction_inflation"
names(wide)[names(wide) == "CheapGoodsIndex"] <- "cheap_goods_inflation"
wages <- wages[order(wages$year), ]
wages$delta_reproduction_real_wage <- c(NA, diff(wages$ReproductionRealWage) / head(wages$ReproductionRealWage, -1) * 100)
wage_data <- merge(wages, wide, by = "year")
wage_data <- subset(
  wage_data,
  !is.na(delta_reproduction_real_wage) &
    !is.na(basic_reproduction_inflation) &
    !is.na(cheap_goods_inflation)
)
m_wage <- feols(
  delta_reproduction_real_wage ~ basic_reproduction_inflation + cheap_goods_inflation,
  data = wage_data,
  vcov = "hetero"
)

etable(
  m_tariff,
  m_supply,
  m_wage,
  tex = TRUE,
  file = file.path(out_dir, "r_table_core_results.tex"),
  replace = TRUE,
  dict = c(
    tariff_301_rate = "Section 301 tariff exposure",
    tradable_x_supply_chain = "Tradable $\\times$ GSCPI",
    basic_reproduction_inflation = "Basic reproduction inflation",
    cheap_goods_inflation = "Cheap goods inflation",
    delta_price = "Category price inflation",
    delta_reproduction_real_wage = "Reproduction real wage growth"
  ),
  headers = c("Tariff shock", "Supply-chain shock", "Real wage"),
  fitstat = ~ n + r2 + wr2
)

etable(
  m_tariff,
  tex = TRUE,
  file = file.path(out_dir, "r_table_tariff_exposure.tex"),
  replace = TRUE,
  dict = c(tariff_301_rate = "Section 301 tariff exposure"),
  fitstat = ~ n + r2 + wr2
)

etable(
  m_supply,
  tex = TRUE,
  file = file.path(out_dir, "r_table_supply_chain.tex"),
  replace = TRUE,
  dict = c(tradable_x_supply_chain = "Tradable $\\times$ GSCPI"),
  fitstat = ~ n + r2 + wr2
)

etable(
  m_wage,
  tex = TRUE,
  file = file.path(out_dir, "r_table_real_wage.tex"),
  replace = TRUE,
  dict = c(
    basic_reproduction_inflation = "Basic reproduction inflation",
    cheap_goods_inflation = "Cheap goods inflation"
  ),
  fitstat = ~ n + r2
)

message("Saved R/fixest regression tables to: ", out_dir)
