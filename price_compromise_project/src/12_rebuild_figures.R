#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = TRUE)
project_root <- ifelse(length(args) >= 1, args[[1]], normalizePath(file.path(getwd(), "..")))

data_dir <- file.path(project_root, "data", "rebuild")
processed_dir <- file.path(project_root, "data", "processed")
output_dir <- file.path(project_root, "output", "rebuild")
table_dir <- file.path(output_dir, "tables")
figure_dir <- file.path(output_dir, "figures")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

theme_rebuild <- function() {
  theme_bw(base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", size = 12),
      plot.subtitle = element_text(size = 10, color = "grey30"),
      legend.position = "bottom",
      panel.grid.minor = element_blank()
    )
}

save_plot <- function(plot, filename, width = 8.2, height = 5.2) {
  ggsave(
    filename = file.path(figure_dir, filename),
    plot = plot,
    width = width,
    height = height,
    dpi = 320
  )
}

index_labels <- c(
  CheapGoodsIndex = "Low-price tradable goods",
  CPIAllItems = "CPI all items",
  BasicReproductionCostIndex = "Basic reproduction necessities",
  LocalReproductionCostIndex = "Local institutional reproduction costs"
)

index_colors <- c(
  CheapGoodsIndex = "#2f6f8f",
  CPIAllItems = "#595959",
  BasicReproductionCostIndex = "#7a6a38",
  LocalReproductionCostIndex = "#9a3d2f"
)

class_colors <- c(
  low_price_global = "#2f6f8f",
  local_reproduction = "#9a3d2f",
  basic_reproduction = "#7a6a38",
  official_cpi = "#595959",
  other = "#8a8a8a"
)

class_labels <- c(
  low_price_global = "Low-price tradable/global goods",
  local_reproduction = "Local institutional reproduction costs",
  basic_reproduction = "Basic reproduction necessities",
  official_cpi = "Official CPI baseline",
  other = "Other"
)

indices <- read.csv(file.path(processed_dir, "constructed_price_indices.csv"), stringsAsFactors = FALSE)
category_summary <- read.csv(file.path(table_dir, "rebuild_cpi_category_summary.csv"), stringsAsFactors = FALSE)
gap <- read.csv(file.path(table_dir, "rebuild_reproduction_to_cheap_goods_gap.csv"), stringsAsFactors = FALSE)
tariff_category <- read.csv(file.path(table_dir, "rebuild_cpi_301_exposure_by_class.csv"), stringsAsFactors = FALSE)
industry_summary <- read.csv(file.path(table_dir, "rebuild_industry_tariff_network_summary.csv"), stringsAsFactors = FALSE)
tradable_inflation <- read.csv(
  file.path(data_dir, "rebuild_tradable_nontradable_inflation_panel.csv"),
  stringsAsFactors = FALSE
)
local_exposure <- read.csv(
  file.path(table_dir, "rebuild_local_reproduction_exposure_summary.csv"),
  stringsAsFactors = FALSE
)

indices_main <- indices |>
  filter(index_name %in% names(index_labels)) |>
  mutate(index_label = factor(index_labels[index_name], levels = index_labels))

fig1 <- ggplot(indices_main, aes(x = year, y = index_value, color = index_name)) +
  annotate("rect", xmin = 2018, xmax = 2020, ymin = -Inf, ymax = Inf, fill = "grey70", alpha = 0.12) +
  annotate("rect", xmin = 2021, xmax = 2022, ymin = -Inf, ymax = Inf, fill = "#d8b365", alpha = 0.15) +
  geom_line(linewidth = 0.9) +
  scale_color_manual(values = index_colors, labels = index_labels, name = NULL) +
  labs(
    title = "Low-price goods and reproduction-cost divergence",
    subtitle = "CPI category indexes normalized to 1984 = 100; shaded windows mark tariff-war and inflation episodes.",
    x = NULL,
    y = "Price index, 1984 = 100"
  ) +
  theme_rebuild()
save_plot(fig1, "rebuild_fig1_index_divergence.png", width = 8.5, height = 5.4)

gap_long <- bind_rows(
  data.frame(year = gap$year, ratio = gap$local_to_cheap_ratio, series = "Local reproduction costs / low-price goods"),
  data.frame(year = gap$year, ratio = gap$basic_to_cheap_ratio, series = "Basic necessities / low-price goods")
)

fig1b <- ggplot(gap_long, aes(x = year, y = ratio, color = series)) +
  geom_hline(yintercept = 1, color = "grey45", linewidth = 0.35) +
  annotate("rect", xmin = 2021, xmax = 2022, ymin = -Inf, ymax = Inf, fill = "#d8b365", alpha = 0.15) +
  geom_line(linewidth = 0.9) +
  scale_color_manual(values = c("#9a3d2f", "#7a6a38"), name = NULL) +
  labs(
    title = "Reproduction-cost pressure relative to the low-price goods channel",
    subtitle = "A rising ratio means reproduction costs outrun tradable low-price goods.",
    x = NULL,
    y = "Relative price ratio"
  ) +
  theme_rebuild()
save_plot(fig1b, "rebuild_fig1b_reproduction_to_cheap_gap.png", width = 8.5, height = 5.2)

category_2025 <- category_summary |>
  filter(!is.na(price_index_2025)) |>
  mutate(
    label = factor(label, levels = label[order(price_index_2025)]),
    class = ifelse(is.na(class), "other", class)
  )

fig2 <- ggplot(category_2025, aes(x = price_index_2025, y = label, fill = class)) +
  geom_col(width = 0.72) +
  scale_fill_manual(values = class_colors, labels = class_labels, name = NULL) +
  labs(
    title = "CPI category price levels by reproduction role, 2025",
    subtitle = "Local/institutional reproduction categories sit above most tradable low-price goods categories.",
    x = "Price index, 1984 = 100",
    y = NULL
  ) +
  theme_rebuild()
save_plot(fig2, "rebuild_fig2_2025_category_levels.png", width = 8.4, height = 5.8)

inflation_window <- indices_main |>
  filter(year >= 2016, year <= 2025, !is.na(inflation))

fig3 <- ggplot(inflation_window, aes(x = year, y = inflation, color = index_name)) +
  geom_hline(yintercept = 0, color = "grey45", linewidth = 0.35) +
  annotate("rect", xmin = 2021, xmax = 2022, ymin = -Inf, ymax = Inf, fill = "#d8b365", alpha = 0.15) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.8) +
  scale_x_continuous(breaks = 2016:2025) +
  scale_color_manual(values = index_colors, labels = index_labels, name = NULL) +
  labs(
    title = "Inflation shock and the weakening of the low-price buffer",
    subtitle = "The post-2020 episode shows whether tradable goods prices still offset reproduction-cost inflation.",
    x = NULL,
    y = "Annual inflation, percent"
  ) +
  theme_rebuild()
save_plot(fig3, "rebuild_fig3_inflation_shock_window.png", width = 8.5, height = 5.3)

tradable_inflation_long <- bind_rows(
  data.frame(
    year = tradable_inflation$year,
    inflation = tradable_inflation$tradable_goods_inflation,
    series = "Tradable goods proxy: core commodities"
  ),
  data.frame(
    year = tradable_inflation$year,
    inflation = tradable_inflation$nontradable_services_inflation,
    series = "Nontradable proxy: core services"
  )
)

fig3b <- ggplot(tradable_inflation_long, aes(x = year, y = inflation, color = series)) +
  geom_hline(yintercept = 0, color = "grey45", linewidth = 0.35) +
  annotate("rect", xmin = 2021, xmax = 2022, ymin = -Inf, ymax = Inf, fill = "#d8b365", alpha = 0.15) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.8) +
  scale_x_continuous(breaks = 2015:2025) +
  scale_color_manual(values = c("#2f6f8f", "#9a3d2f"), name = NULL) +
  labs(
    title = "Tradable goods inflation breaks the pre-2020 low-price pattern",
    subtitle = "Core commodities inflation turns sharply positive in 2021-2022, motivating the exposure-share shock design.",
    x = NULL,
    y = "Annual CPI inflation, percent"
  ) +
  theme_rebuild()
save_plot(fig3b, "rebuild_fig3b_tradable_nontradable_inflation.png", width = 8.5, height = 5.3)

exposure_long <- bind_rows(
  data.frame(
    local_reproduction_group = local_exposure$local_reproduction_group,
    exposure = local_exposure$mean_tradable_input_exposure * 100,
    series = "Tradable input exposure"
  ),
  data.frame(
    local_reproduction_group = local_exposure$local_reproduction_group,
    exposure = local_exposure$mean_goods_supply_chain_exposure * 100,
    series = "Broad goods supply-chain exposure"
  ),
  data.frame(
    local_reproduction_group = local_exposure$local_reproduction_group,
    exposure = local_exposure$mean_tradable_downstream_exposure * 100,
    series = "Tradable downstream exposure"
  )
) |>
  mutate(
    local_reproduction_group = factor(
      local_reproduction_group,
      levels = c("Core local reproduction", "Extended local services", "Other industries")
    ),
    series = factor(
      series,
      levels = c("Tradable input exposure", "Broad goods supply-chain exposure", "Tradable downstream exposure")
    )
  )

fig3c <- ggplot(exposure_long, aes(x = local_reproduction_group, y = exposure, fill = series)) +
  geom_col(position = position_dodge(width = 0.72), width = 0.62) +
  scale_fill_manual(values = c("#2f6f8f", "#7a6a38", "#9a3d2f"), name = NULL) +
  labs(
    title = "Local reproduction sectors are not highly exposed through ordinary tradable inputs",
    subtitle = "This motivates separating upstream input exposure from downstream network exposure.",
    x = NULL,
    y = "Mean exposure, percent"
  ) +
  theme_rebuild() +
  theme(axis.text.x = element_text(angle = 12, hjust = 1))
save_plot(fig3c, "rebuild_fig3c_local_reproduction_exposure.png", width = 8.5, height = 5.3)

tariff_plot <- tariff_category |>
  filter(!is.na(mean_tariff_301_rate_2018_2025)) |>
  mutate(
    exposure_pct = mean_tariff_301_rate_2018_2025 * 100,
    label = factor(label, levels = label[order(exposure_pct)]),
    class = ifelse(is.na(class), "other", class)
  )

fig4 <- ggplot(tariff_plot, aes(x = exposure_pct, y = label, fill = class)) +
  geom_col(width = 0.72) +
  geom_text(
    aes(x = ifelse(exposure_pct > 0, exposure_pct + 0.35, 0.35), label = sprintf("%.1f", exposure_pct)),
    hjust = 0,
    size = 3
  ) +
  scale_fill_manual(values = class_colors, labels = class_labels, name = NULL) +
  coord_cartesian(xlim = c(0, max(tariff_plot$exposure_pct, na.rm = TRUE) + 2.2)) +
  labs(
    title = "Section 301 exposure is concentrated in goods categories",
    subtitle = "Direct tariff exposure is measured at the CPI-category level, 2018-2025 average.",
    x = "Mean Section 301 tariff exposure, percent",
    y = NULL
  ) +
  theme_rebuild()
save_plot(fig4, "rebuild_fig4_cpi_301_exposure_by_class.png", width = 8.4, height = 5.8)

industry_plot <- industry_summary |>
  mutate(
    direct_pct = direct_tariff_max * 100,
    network_pct = network_tariff_max * 100,
    output_size = ifelse(is.na(output_2025), median(output_2025, na.rm = TRUE), output_2025)
  ) |>
  filter(!is.na(direct_pct), !is.na(network_pct))

fig5 <- ggplot(industry_plot, aes(x = direct_pct, y = network_pct)) +
  geom_point(
    aes(size = output_size),
    alpha = 0.62,
    color = "#2f6f8f"
  ) +
  scale_size_continuous(range = c(1.5, 8), guide = "none") +
  labs(
    title = "Direct tariff exposure and input-output network exposure",
    subtitle = "Industries can be indirectly exposed even when their own direct tariff exposure is limited.",
    x = "Maximum direct Section 301 exposure, percent",
    y = "Maximum I-O network exposure, percent"
  ) +
  theme_rebuild()
save_plot(fig5, "rebuild_fig5_industry_direct_vs_network_exposure.png", width = 7.6, height = 5.8)

message("Wrote rebuilt figures to ", figure_dir)
