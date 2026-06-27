# 01_network_estimation.R
# 价格型阶级妥协与网络通胀实证分析

library(dplyr)
library(tidyr)
library(sandwich)
library(lmtest)

# 1. 加载数据
cat("Loading data...\n")
dom_use <- read.csv("data/raw/BEA_2023_Domestic_Use.csv")
imp_use <- read.csv("data/raw/BEA_2023_Import_Use.csv")
cpi_data <- read.csv("data/raw/bls_cpi_real_raw.csv")
fedfunds <- read.csv("data/raw/fedfunds.csv")
pctr <- read.csv("data/raw/pctr.csv")
dspi <- read.csv("data/raw/dspi.csv")

# 转换并对齐美联储基金利率
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

# 2. 构建投入产出矩阵 (I-O Matrix)
dom_mat <- dom_use %>%
  pivot_wider(names_from = Col_Industry, values_from = Value, values_fill = 0) %>%
  select(-Row_Industry) %>%
  as.matrix()

ind_names <- unique(dom_use$Row_Industry)
rownames(dom_mat) <- ind_names

total_out_df <- read.csv("data/raw/BEA_2023_Total_Output.csv")
total_output <- total_out_df$Total_Output[match(ind_names, total_out_df$Row_Industry)]
total_output[is.na(total_output) | total_output == 0] <- 1e-6

A <- scale(dom_mat, center = FALSE, scale = total_output)
I <- diag(nrow(A))
L <- solve(I - A)

# 3. 计算网络中心度与直接冲击暴露
imp_sums <- imp_use %>%
  group_by(Row_Industry) %>%
  summarize(Direct_Shock = sum(Value))

downstream_shock <- rowSums(L)
network_exposure <- data.frame(
  Industry = ind_names,
  Downstream_Centrality = downstream_shock
) %>%
  left_join(imp_sums, by = c("Industry" = "Row_Industry"))

total_out_df <- total_out_df %>%
  mutate(Sector_Type = ifelse(Import_Ratio >= 0.10, "Tradable", "Non-Tradable"))

tradable_inds <- total_out_df$Row_Industry[total_out_df$Sector_Type == "Tradable"]
nontradable_inds <- total_out_df$Row_Industry[total_out_df$Sector_Type == "Non-Tradable"]

avg_tradable_shock <- mean(network_exposure$Direct_Shock[network_exposure$Industry %in% tradable_inds], na.rm=TRUE)
avg_nontradable_shock <- mean(network_exposure$Direct_Shock[network_exposure$Industry %in% nontradable_inds], na.rm=TRUE)
avg_tradable_network <- mean(network_exposure$Downstream_Centrality[network_exposure$Industry %in% tradable_inds], na.rm=TRUE)
avg_nontradable_network <- mean(network_exposure$Downstream_Centrality[network_exposure$Industry %in% nontradable_inds], na.rm=TRUE)

# 4. 构建面板回归数据
cpi_panel <- cpi_data %>%
  mutate(
    Sector_Type = case_when(
      Series_ID %in% c("CUUR0000SAA", "CUUR0000SAD") ~ "Tradable",
      Series_ID %in% c("CUUR0000SEHA", "CUUR0000SAM") ~ "Non-Tradable"
    )
  ) %>%
  arrange(Series_ID, Year, Month) %>%
  group_by(Series_ID) %>%
  mutate(Inflation = (Value - lag(Value, 12)) / lag(Value, 12) * 100) %>%
  filter(!is.na(Inflation))

tariff_shock_vector <- c(
  "2015" = 3.1, "2016" = 3.1, "2017" = 3.1,
  "2018" = 12.0, "2019" = 17.5, "2020" = 19.3,
  "2021" = 19.3, "2022" = 19.3, "2023" = 19.3,
  "2024" = 19.3, "2025" = 19.3
)

cpi_panel <- cpi_panel %>%
  ungroup() %>%
  mutate(
    Direct_Shock_Index = ifelse(Sector_Type == "Tradable", avg_tradable_shock, avg_nontradable_shock),
    Network_Centrality = ifelse(Sector_Type == "Tradable", avg_tradable_network, avg_nontradable_network),
    Tariff_Intensity = tariff_shock_vector[as.character(Year)] - 3.1,
    Labor_Reproduction_Shock = Network_Centrality * Tariff_Intensity
  ) %>%
  left_join(fedfunds, by = c("Year", "Month")) %>%
  left_join(pctr, by = c("Year", "Month")) %>%
  left_join(dspi, by = c("Year", "Month"))

# 5. 运行固定效应面板回归 (控制美联储有效联邦基金利率 FEDFUNDS 与财政刺激 PCTR_growth)
cat("\nRunning Econometric Regression (Shift-Share + Network Control + FEDFUNDS + PCTR_growth)...\n")
model <- lm(Inflation ~ Direct_Shock_Index + Labor_Reproduction_Shock + FEDFUNDS + PCTR_growth + as.factor(Year) + as.factor(Month), data = cpi_panel)

cat("\n--- Standard OLS Regression Results ---\n")
print(summary(model))

cat("\n--- Newey-West HAC Robust Regression Results ---\n")
hac_results <- coeftest(model, vcov = NeweyWest(model))
print(hac_results)

# 6. 写入处理后的结果数据
dir.create("data/processed", showWarnings = FALSE)
write.csv(cpi_panel, "data/processed/cpi_panel_analysis.csv", row.names=FALSE)
write.csv(network_exposure, "data/processed/network_exposure.csv", row.names=FALSE)
cat("Data processed and saved to data/processed/\n")
