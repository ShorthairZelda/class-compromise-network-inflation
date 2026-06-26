library(ggplot2)
library(dplyr)
library(tidyr)

# 加载数据
cpi_panel <- read.csv("data/processed/cpi_panel_analysis.csv")
network <- read.csv("data/processed/network_exposure.csv")

# 创建图形目录
dir.create("figures", showWarnings = FALSE)

# Figure 1: Import Shock vs Downstream Network Centrality (Scatter Plot)
network <- network %>%
  mutate(
    Sector_Type = ifelse(row_number() <= 35, "Tradable (Manufacturing etc.)", "Non-Tradable (Services etc.)"),
    Import_Shock_Billion = Direct_Shock / 1000, # 百万美金转换为十亿美金
    Label = ifelse(Import_Shock_Billion > 40 | Downstream_Centrality > 3.0, Industry, "")
  )

p1 <- ggplot(network, aes(x = Import_Shock_Billion, y = Downstream_Centrality, color = Sector_Type)) +
  geom_point(size = 3.5, alpha = 0.8) +
  geom_text(aes(label = Label), hjust = -0.15, vjust = 0.5, size = 2.8, check_overlap = TRUE, show.legend = FALSE) +
  theme_minimal() +
  labs(title = "Figure 1: Import Shock vs Downstream Network Centrality",
       x = "Direct Import Shock Exposure (Billion USD)",
       y = "Downstream Network Centrality (Leontief Inverse Row Sum)",
       color = "Sector Type") +
  theme(legend.position = "bottom",
        plot.title = element_text(face = "bold", size = 12)) +
  scale_color_manual(values = c("Tradable (Manufacturing etc.)" = "#FF6666", "Non-Tradable (Services etc.)" = "#3399FF"))

ggsave("figures/fig1_network_centrality.png", p1, width = 7, height = 5)

# Figure 2: Inflation Trends over Time
p2 <- cpi_panel %>%
  group_by(Year, Sector_Type) %>%
  summarize(Avg_Inflation = mean(Inflation, na.rm=TRUE)) %>%
  ggplot(aes(x = Year, y = Avg_Inflation, color = Sector_Type)) +
  geom_line(linewidth=1) +
  geom_point(size=2) +
  theme_minimal() +
  labs(title = "Figure 2: Inflation Trends (Tradable vs Non-Tradable)",
       y = "Average Annual Inflation Rate (%)",
       x = "Year") +
  scale_x_continuous(breaks = seq(2015, 2025, 2))

ggsave("figures/fig2_inflation_trend.png", p2, width = 6, height = 4)

cat("Figures generated successfully.\n")
