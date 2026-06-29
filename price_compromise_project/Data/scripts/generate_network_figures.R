#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(igraph)
  library(scales)
})

args <- commandArgs(trailingOnly = TRUE)
project_dir <- if (length(args) >= 1) args[[1]] else "/Users/linian/Desktop/PROJ_completed/proj_class_compromise"

input_coeff_path <- file.path(project_dir, "Data", "cleaned", "bea_input_coefficients_2019.csv")
w_matrix_path <- file.path(project_dir, "Data", "analysis", "spatial_industry_w_matrices_long.csv")
figure_dir <- file.path(project_dir, "Output", "figures")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

input_coeff <- read_csv(input_coeff_path, show_col_types = FALSE)
w_long <- read_csv(w_matrix_path, show_col_types = FALSE)

strong_edges <- input_coeff %>%
  filter(link_5pct == 1, industry_code != commodity_code) %>%
  transmute(
    from = commodity_code,
    to = industry_code,
    from_name = commodity_name,
    to_name = industry_name,
    input_share = input_share
  )

nodes <- bind_rows(
  strong_edges %>% transmute(name = from, label = from_name),
  strong_edges %>% transmute(name = to, label = to_name)
) %>%
  distinct(name, .keep_all = TRUE) %>%
  mutate(
    sector = case_when(
      grepl("^[0-9]", name) ~ substr(name, 1, 1),
      TRUE ~ "Other"
    ),
    tradability = case_when(
      grepl("^(111|113|21|31|32|33)", name) ~ "Tradable goods / global supply-chain sector",
      TRUE ~ "Nontradable or local-service sector"
    )
  )

graph <- graph_from_data_frame(
  strong_edges %>% select(from, to, input_share),
  directed = TRUE,
  vertices = nodes
)

set.seed(301)
layout <- layout_with_fr(graph, weights = E(graph)$input_share)
node_strength <- strength(graph, mode = "all", weights = E(graph)$input_share)
node_degree <- degree(graph, mode = "all")
label_cutoff <- quantile(node_degree, 0.78, na.rm = TRUE)
V(graph)$plot_label <- ifelse(node_degree >= label_cutoff, V(graph)$name, NA)
V(graph)$size <- rescale(node_strength, to = c(4.5, 14))
V(graph)$color <- ifelse(
  V(graph)$tradability == "Tradable goods / global supply-chain sector",
  "#D55E00",
  "#0072B2"
)
E(graph)$width <- rescale(E(graph)$input_share, to = c(0.35, 3.2))
E(graph)$arrow.size <- 0.18

png(file.path(figure_dir, "industry_network_5pct_strong_links.png"),
    width = 2600, height = 1900, res = 220)
par(mar = c(0.6, 0.6, 2.7, 0.6), bg = "white")
plot(
  graph,
  layout = layout,
  vertex.color = alpha(V(graph)$color, 0.85),
  vertex.frame.color = "white",
  vertex.label = V(graph)$plot_label,
  vertex.label.cex = 0.62,
  vertex.label.color = "#202020",
  vertex.size = V(graph)$size,
  edge.color = alpha("#636363", 0.38),
  edge.width = E(graph)$width,
  edge.arrow.size = E(graph)$arrow.size,
  main = "5% Strong Input-Output Links in the BEA Industry Network"
)
legend(
  "topleft",
  legend = c("Tradable goods / global supply-chain sector", "Nontradable or local-service sector"),
  col = c("#D55E00", "#0072B2"),
  pch = 19,
  pt.cex = 1.5,
  bty = "n",
  cex = 0.78
)
mtext("Directed edges run from supplying commodity/industry to using industry; node size reflects weighted network strength.",
      side = 1, line = -1, cex = 0.72, col = "#555555")
dev.off()

node_order <- w_long %>%
  distinct(industry_code, industry_name) %>%
  arrange(industry_code) %>%
  mutate(order_id = row_number())

heat_data <- w_long %>%
  filter(matrix %in% c("input_share", "binary_5pct", "symmetric_input_output", "inverse_network_distance_5pct")) %>%
  left_join(node_order %>% select(industry_code, row = order_id), by = "industry_code") %>%
  left_join(node_order %>% select(neighbor_code = industry_code, col = order_id), by = "neighbor_code") %>%
  mutate(
    matrix = recode(
      matrix,
      input_share = "Input-share W",
      binary_5pct = "5% strong-link W",
      symmetric_input_output = "Symmetric IO W",
      inverse_network_distance_5pct = "Inverse-distance W"
    ),
    weight_plot = if_else(weight > 0, weight, NA_real_)
  )

heatmap_plot <- ggplot(heat_data, aes(x = col, y = row, fill = weight_plot)) +
  geom_tile(color = NA) +
  facet_wrap(~ matrix, ncol = 2) +
  scale_y_reverse(expand = c(0, 0)) +
  scale_x_continuous(expand = c(0, 0)) +
  scale_fill_gradient(
    low = "#F1F7EC",
    high = "#1B7837",
    na.value = "#F6F6F6",
    labels = label_number(accuracy = 0.01)
  ) +
  coord_equal() +
  labs(
    title = "Spatial Industry W Matrices Used in Network Regressions",
    subtitle = "Rows are affected industries; columns are neighboring or supplying industries. Darker cells indicate larger row-normalized weights.",
    x = "Neighbor industry index",
    y = "Affected industry index",
    fill = "Weight"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(size = 10, color = "#555555"),
    panel.grid = element_blank(),
    strip.text = element_text(face = "bold"),
    axis.text = element_text(size = 7, color = "#555555"),
    legend.position = "right"
  )

ggsave(
  file.path(figure_dir, "spatial_w_matrices_heatmap.png"),
  heatmap_plot,
  width = 10.5,
  height = 8.2,
  dpi = 300
)

binary_heat_data <- heat_data %>% filter(matrix == "5% strong-link W")
binary_heatmap <- ggplot(binary_heat_data, aes(x = col, y = row, fill = weight_plot)) +
  geom_tile(color = NA) +
  scale_y_reverse(expand = c(0, 0)) +
  scale_x_continuous(expand = c(0, 0)) +
  scale_fill_gradient(
    low = "#F4EFEA",
    high = "#B2182B",
    na.value = "#F7F7F7",
    labels = label_number(accuracy = 0.01)
  ) +
  coord_equal() +
  labs(
    title = "5% Strong-Link Spatial W Matrix",
    subtitle = "This is the W matrix with the strongest input-price result in the spatial specification.",
    x = "Neighbor/supplying industry index",
    y = "Affected/using industry index",
    fill = "Weight"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 16),
    plot.subtitle = element_text(size = 10.5, color = "#555555"),
    panel.grid = element_blank(),
    axis.text = element_text(size = 7, color = "#555555")
  )

ggsave(
  file.path(figure_dir, "spatial_w_binary_5pct_heatmap.png"),
  binary_heatmap,
  width = 8.2,
  height = 7.2,
  dpi = 300
)

make_single_heatmap <- function(matrix_label, filename, high_color) {
  plot_data <- heat_data %>% filter(matrix == matrix_label)

  p <- ggplot(plot_data, aes(x = col, y = row, fill = weight_plot)) +
    geom_tile(color = NA) +
    scale_y_reverse(expand = c(0, 0)) +
    scale_x_continuous(expand = c(0, 0)) +
    scale_fill_gradient(
      low = "#F7F7F7",
      high = high_color,
      na.value = "#FAFAFA",
      labels = label_number(accuracy = 0.01)
    ) +
    coord_equal() +
    labs(
      title = matrix_label,
      subtitle = "Rows are affected industries; columns are neighboring or supplying industries.",
      x = "Neighbor/supplying industry index",
      y = "Affected/using industry index",
      fill = "Weight"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(face = "bold", size = 18),
      plot.subtitle = element_text(size = 11, color = "#555555"),
      panel.grid = element_blank(),
      axis.text = element_text(size = 8, color = "#555555"),
      legend.position = "right"
    )

  ggsave(
    file.path(figure_dir, filename),
    p,
    width = 9.2,
    height = 8.0,
    dpi = 300
  )
}

make_single_heatmap("Input-share W", "spatial_w_input_share_heatmap.png", "#1B7837")
make_single_heatmap("5% strong-link W", "spatial_w_binary_5pct_heatmap_large.png", "#B2182B")
make_single_heatmap("Symmetric IO W", "spatial_w_symmetric_io_heatmap.png", "#2166AC")
make_single_heatmap("Inverse-distance W", "spatial_w_inverse_distance_heatmap.png", "#762A83")

write_csv(
  tibble(
    figure = c(
      "industry_network_5pct_strong_links.png",
      "spatial_w_matrices_heatmap.png",
      "spatial_w_binary_5pct_heatmap.png",
      "spatial_w_input_share_heatmap.png",
      "spatial_w_binary_5pct_heatmap_large.png",
      "spatial_w_symmetric_io_heatmap.png",
      "spatial_w_inverse_distance_heatmap.png"
    ),
    source = c(
      input_coeff_path,
      w_matrix_path,
      w_matrix_path,
      w_matrix_path,
      w_matrix_path,
      w_matrix_path,
      w_matrix_path
    ),
    note = c(
      "5% strong directed input-output links from BEA 2019 coefficients. Nodes are colored by heuristic tradable/nontradable classification.",
      "Four row-normalized spatial industry W matrices used in spatial/network regressions.",
      "The 5% strong-link W matrix used for the strongest input-price spatial result.",
      "Input-share W matrix shown as a standalone large heatmap.",
      "5% strong-link W matrix shown as a standalone large heatmap.",
      "Symmetric IO W matrix shown as a standalone large heatmap.",
      "Inverse-distance W matrix shown as a standalone large heatmap."
    )
  ),
  file.path(figure_dir, "network_figure_manifest.csv")
)

message("Saved figures to: ", figure_dir)
