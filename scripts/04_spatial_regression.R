# 04_spatial_regression.R
# 基于投入产出网络空间权重矩阵的面板空间自回归模型 (SAR)

library(dplyr)
library(tidyr)
library(spatialreg)
library(spdep)
library(ggplot2)

set.ZeroPolicyOption(TRUE)

cat("1. Loading BEA, BLS, and FEDFUNDS raw data...\n")
dom_use <- read.csv("data/raw/BEA_2023_Domestic_Use.csv")
total_out_df <- read.csv("data/raw/BEA_2023_Total_Output.csv")
cpi_data <- read.csv("data/raw/bls_cpi_real_raw.csv")
imp_use <- read.csv("data/raw/BEA_2023_Import_Use.csv")
fedfunds <- read.csv("data/raw/fedfunds.csv")
pctr <- read.csv("data/raw/pctr.csv")
dspi <- read.csv("data/raw/dspi.csv")

# 转换美联储基金利率日期
fedfunds <- fedfunds %>%
  mutate(
    Date = as.Date(observation_date),
    Year = as.integer(format(Date, "%Y")),
    Month = as.integer(format(Date, "%m")),
    FEDFUNDS = as.numeric(FEDFUNDS)
  ) %>%
  select(Year, Month, FEDFUNDS)

# 转换财政转移支付（YoY 增长率）
pctr <- pctr %>%
  mutate(
    Date = as.Date(observation_date),
    Year = as.integer(format(Date, "%Y")),
    Month = as.integer(format(Date, "%m")),
    PCTR = as.numeric(PCTR)
  ) %>%
  arrange(Date) %>%
  mutate(PCTR_growth = (PCTR - lag(PCTR, 12)) / lag(PCTR, 12) * 100) %>%
  select(Year, Month, PCTR_growth)

# 转换个人可支配收入（YoY 增长率）
dspi <- dspi %>%
  mutate(
    Date = as.Date(observation_date),
    Year = as.integer(format(Date, "%Y")),
    Month = as.integer(format(Date, "%m")),
    DSPI = as.numeric(DSPI)
  ) %>%
  arrange(Date) %>%
  mutate(DSPI_growth = (DSPI - lag(DSPI, 12)) / lag(DSPI, 12) * 100) %>%
  select(Year, Month, DSPI_growth)

ind_names <- unique(dom_use$Row_Industry)

dom_mat <- dom_use %>%
  pivot_wider(names_from = Col_Industry, values_from = Value, values_fill = 0) %>%
  select(-Row_Industry) %>%
  as.matrix()
rownames(dom_mat) <- ind_names

total_output <- total_out_df$Total_Output[match(ind_names, total_out_df$Row_Industry)]
names(total_output) <- ind_names
total_output[is.na(total_output) | total_output == 0] <- 1e-6

# 计算 Leontief 逆矩阵
A <- scale(dom_mat, center = FALSE, scale = total_output)
I <- diag(nrow(A))
L <- solve(I - A)

# 定义 4 类 CPI 的行业映射组
g1_inds <- c("Ind_21")
g2_inds <- paste0("Ind_", 8:18)
g3_inds <- c("Ind_48")
g4_inds <- c("Ind_58", "Ind_59", "Ind_60")

group_list <- list(
  "Apparel" = g1_inds,
  "Durables" = g2_inds,
  "Rent" = g3_inds,
  "Medical" = g4_inds
)

# 2. 聚合 Leontief 逆矩阵到 4x4 并构建空间权重矩阵 W
L_agg <- matrix(0, nrow=4, ncol=4, dimnames=list(names(group_list), names(group_list)))
for (i in 1:4) {
  for (j in 1:4) {
    row_g <- names(group_list)[i]
    col_g <- names(group_list)[j]
    L_agg[row_g, col_g] <- mean(L[group_list[[row_g]], group_list[[col_g]]], na.rm=TRUE)
  }
}

# 构建对角线为0、带有微小扰动以防止孤立行的行归一化空间矩阵 W
W <- L_agg
W <- W + 1e-4  # 引入极小扰动项，以保证非零行和数值稳定性
diag(W) <- 0   # 强制对角线为0，避免空间模型中自回归自反馈
row_sums <- rowSums(W)
W <- W / row_sums

cat("\nAggregated Spatial Weight Matrix (W):\n")
print(W)

# 3. 绘制空间权重矩阵 W 的热力图
cat("\nGenerating Spatial Weight Matrix Heatmap...\n")
W_melted <- as.data.frame(W) %>%
  mutate(Source = rownames(W)) %>%
  pivot_longer(-Source, names_to = "Destination", values_to = "Weight")

ggplot(W_melted, aes(x = Destination, y = Source, fill = Weight)) +
  geom_tile(color = "white", lwd = 0.5, linetype = 1) +
  geom_text(aes(label = sprintf("%.4f", Weight)), color = "white", size = 5) +
  scale_fill_gradient(low = "#1e3c72", high = "#ff6584") +
  theme_minimal() +
  labs(
    title = "Aggregated Input-Output Spatial Weights (W)",
    subtitle = "Based on BEA 2023 Leontief Inverse (strictly zero diagonal)",
    x = "Downstream / Destination Sector",
    y = "Upstream / Source Sector"
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 10, hjust = 0.5),
    axis.text = element_text(size = 11, face = "bold"),
    axis.title = element_text(size = 12)
  )

dir.create("figures", showWarnings = FALSE)
ggsave("figures/fig4_spatial_weights.png", width = 8, height = 6.5, dpi = 300)
cat("Saved weight matrix heatmap to figures/fig4_spatial_weights.png\n")

# 4. 面板回归数据对齐与整理
cpi_panel <- cpi_data %>%
  mutate(
    Sector_Type = case_when(
      Series_ID %in% c("CUUR0000SAA") ~ "Apparel",
      Series_ID %in% c("CUUR0000SAD") ~ "Durables",
      Series_ID %in% c("CUUR0000SEHA") ~ "Rent",
      Series_ID %in% c("CUUR0000SAM") ~ "Medical"
    )
  ) %>%
  filter(!is.na(Sector_Type)) %>%
  arrange(Sector_Type, Year, Month) %>%
  group_by(Sector_Type) %>%
  mutate(Inflation = (Value - lag(Value, 12)) / lag(Value, 12) * 100) %>%
  filter(!is.na(Inflation))

tariff_shock_vector <- c(
  "2015" = 3.1, "2016" = 3.1, "2017" = 3.1,
  "2018" = 12.0, "2019" = 17.5, "2020" = 19.3,
  "2021" = 19.3, "2022" = 19.3, "2023" = 19.3,
  "2024" = 19.3, "2025" = 19.3
)

imp_sums <- imp_use %>%
  group_by(Row_Industry) %>%
  summarize(Direct_Shock = sum(Value))

downstream_shock <- rowSums(L)

avg_direct_shocks <- numeric(4)
names(avg_direct_shocks) <- names(group_list)
avg_network_centrality <- numeric(4)
names(avg_network_centrality) <- names(group_list)
for (g_name in names(group_list)) {
  avg_direct_shocks[g_name] <- mean(imp_sums$Direct_Shock[imp_sums$Row_Industry %in% group_list[[g_name]]], na.rm=TRUE)
  avg_network_centrality[g_name] <- mean(downstream_shock[ind_names %in% group_list[[g_name]]], na.rm=TRUE)
}

cpi_panel <- cpi_panel %>%
  ungroup() %>%
  mutate(
    Direct_Shock_Index = avg_direct_shocks[Sector_Type],
    Network_Centrality = avg_network_centrality[Sector_Type],
    Tariff_Intensity = tariff_shock_vector[as.character(Year)] - 3.1,
    Labor_Reproduction_Shock = Network_Centrality * Tariff_Intensity,
    Time_Index = (Year - 2015) * 12 + Month
  ) %>%
  left_join(fedfunds, by = c("Year", "Month")) %>%
  left_join(pctr, by = c("Year", "Month")) %>%
  left_join(dspi, by = c("Year", "Month"))

cpi_panel_sorted <- cpi_panel %>%
  arrange(Time_Index, Sector_Type)

time_counts <- cpi_panel_sorted %>%
  group_by(Time_Index) %>%
  summarize(n = n())
valid_times <- time_counts$Time_Index[time_counts$n == 4]

cpi_panel_final <- cpi_panel_sorted %>%
  filter(Time_Index %in% valid_times)

# 构建 Kronecker 积以扩张空间权重矩阵到面板维度 (NT x NT)
num_t <- length(valid_times)
W_panel <- kronecker(diag(num_t), W)
listw_panel <- mat2listw(W_panel, style="W")

# 5. 面板自回归估计 (SAR) - 控制 FEDFUNDS, PCTR_growth 并修正固定效应共线性
cat("\nRunning stacked Panel Spatial Lag (SAR) Model with FFR + PCTR_growth Control...\n")
sar_model <- lagsarlm(
  Inflation ~ Labor_Reproduction_Shock + FEDFUNDS + PCTR_growth + as.factor(Sector_Type) + as.factor(Year) + as.factor(Month),
  data = cpi_panel_final,
  listw = listw_panel,
  zero.policy = TRUE
)
print(summary(sar_model))

# 6. 计算分布滞后空间溢出模型 (Lag 6 & Lag 12)
cat("\nCalculating Lagged Spatial Spillover Models...\n")
cpi_wide <- cpi_panel_final %>%
  select(Time_Index, Sector_Type, Inflation) %>%
  pivot_wider(names_from = Sector_Type, values_from = Inflation) %>%
  arrange(Time_Index)

sectors_order <- c("Apparel", "Durables", "Rent", "Medical")
W_ordered <- W[sectors_order, sectors_order]

spatial_lag_matrix <- matrix(0, nrow=nrow(cpi_wide), ncol=4, dimnames=list(NULL, paste0("W_Inflation_", sectors_order)))
for (t in 1:nrow(cpi_wide)) {
  P_t <- as.numeric(cpi_wide[t, sectors_order])
  if (!any(is.na(P_t))) {
    spatial_lag_matrix[t, ] <- as.numeric(W_ordered %*% P_t)
  } else {
    spatial_lag_matrix[t, ] <- NA
  }
}

cpi_wide_with_lags <- cbind(cpi_wide, spatial_lag_matrix)

cpi_long_lags <- cpi_wide_with_lags %>%
  pivot_longer(
    cols = all_of(sectors_order),
    names_to = "Sector_Type",
    values_to = "Inflation"
  ) %>%
  mutate(
    W_Inflation = case_when(
      Sector_Type == "Apparel" ~ W_Inflation_Apparel,
      Sector_Type == "Durables" ~ W_Inflation_Durables,
      Sector_Type == "Rent" ~ W_Inflation_Rent,
      Sector_Type == "Medical" ~ W_Inflation_Medical
    )
  ) %>%
  select(Time_Index, Sector_Type, Inflation, W_Inflation)

cpi_final_lags <- cpi_panel_final %>%
  select(Time_Index, Sector_Type, Year, Month, Direct_Shock_Index, Network_Centrality, Tariff_Intensity, Labor_Reproduction_Shock, FEDFUNDS) %>%
  inner_join(cpi_long_lags, by = c("Time_Index", "Sector_Type")) %>%
  arrange(Sector_Type, Time_Index) %>%
  group_by(Sector_Type) %>%
  mutate(
    W_Inflation_lag6 = lag(W_Inflation, 6),
    W_Inflation_lag12 = lag(W_Inflation, 12)
  ) %>%
  filter(!is.na(W_Inflation_lag12))

cat("\n--- Running Lagged Spatial Regression (Lag 6) ---\n")
sar_lag6_model <- lm(
  Inflation ~ W_Inflation_lag6 + Labor_Reproduction_Shock + FEDFUNDS + as.factor(Sector_Type) + as.factor(Year) + as.factor(Month),
  data = cpi_final_lags
)
print(summary(sar_lag6_model))

cat("\n--- Running Lagged Spatial Regression (Lag 12) ---\n")
sar_lag12_model <- lm(
  Inflation ~ W_Inflation_lag12 + Labor_Reproduction_Shock + FEDFUNDS + as.factor(Sector_Type) + as.factor(Year) + as.factor(Month),
  data = cpi_final_lags
)
print(summary(sar_lag12_model))

# 7. 保存分析数据与 RData
dir.create("data/processed", showWarnings = FALSE)
write.csv(cpi_panel_final, "data/processed/cpi_spatial_panel.csv", row.names=FALSE)
write.csv(cpi_final_lags, "data/processed/cpi_spatial_panel_lags.csv", row.names=FALSE)
save(W, sar_model, sar_lag6_model, sar_lag12_model, file = "data/processed/spatial_regression_results.RData")
cat("Saved analysis results and spatial panel to data/processed/\n")


