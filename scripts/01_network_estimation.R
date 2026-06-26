# 01_network_estimation.R
# 价格型阶级妥协与网络通胀实证分析

library(dplyr)
library(tidyr)

# 1. 加载数据
cat("Loading data...\n")
dom_use <- read.csv("data/raw/BEA_2023_Domestic_Use.csv")
imp_use <- read.csv("data/raw/BEA_2023_Import_Use.csv")
cpi_data <- read.csv("data/raw/bls_cpi_real_raw.csv")
tariff <- read.csv("data/raw/tariff_section301_raw.csv")

# 2. 构建投入产出矩阵 (I-O Matrix)
# 转换为 71x71 宽格式矩阵
dom_mat <- dom_use %>%
  pivot_wider(names_from = Col_Industry, values_from = Value, values_fill = 0) %>%
  select(-Row_Industry) %>%
  as.matrix()

# 提取行业名称列表
ind_names <- unique(dom_use$Row_Industry)
rownames(dom_mat) <- ind_names

# 计算总投入 (利用 BEA 2023 提取的真实总产出 Total Output 进行标准化)
total_out_df <- read.csv("data/raw/BEA_2023_Total_Output.csv")
total_output <- total_out_df$Total_Output[match(ind_names, total_out_df$Row_Industry)]
total_output[is.na(total_output) | total_output == 0] <- 1e-6

# 计算直接消耗系数矩阵 A
A <- scale(dom_mat, center = FALSE, scale = total_output)

# 计算 Leontief 逆矩阵 L = (I - A)^(-1)
I <- diag(nrow(A))
L <- solve(I - A)

# 3. 计算网络中心度与直接冲击暴露 (Network & Direct Exposures)
# 使用进口表 (Import Use) 的行总和作为行业的直接外部冲击暴露度 (Direct Shock Proxy)
imp_sums <- imp_use %>%
  group_by(Row_Industry) %>%
  summarize(Direct_Shock = sum(Value))

# 计算 Downstream Network Centrality (下游传导)：行业 i 的成本变动对其他所有下游行业价格的影响
# 根据价格传导方程 p = A'p + e，价格冲击的传导乘数为 L = (I - A)^(-1)
# 行业 i 对整体经济的下游传导力应为其所在行的和，即 rowSums(L)
downstream_shock <- rowSums(L)

# 合并网络指标
network_exposure <- data.frame(
  Industry = ind_names,
  Downstream_Centrality = downstream_shock
) %>%
  left_join(imp_sums, by = c("Industry" = "Row_Industry"))

# 划分可贸易与非可贸易行业（基于真实进出口密集度，门槛值为10%）
total_out_df <- total_out_df %>%
  mutate(Sector_Type = ifelse(Import_Ratio >= 0.10, "Tradable", "Non-Tradable"))

tradable_inds <- total_out_df$Row_Industry[total_out_df$Sector_Type == "Tradable"]
nontradable_inds <- total_out_df$Row_Industry[total_out_df$Sector_Type == "Non-Tradable"]

avg_tradable_shock <- mean(network_exposure$Direct_Shock[network_exposure$Industry %in% tradable_inds], na.rm=TRUE)
avg_nontradable_shock <- mean(network_exposure$Direct_Shock[network_exposure$Industry %in% nontradable_inds], na.rm=TRUE)

avg_tradable_network <- mean(network_exposure$Downstream_Centrality[network_exposure$Industry %in% tradable_inds], na.rm=TRUE)
avg_nontradable_network <- mean(network_exposure$Downstream_Centrality[network_exposure$Industry %in% nontradable_inds], na.rm=TRUE)

cat("Average Tradable Direct Shock:", avg_tradable_shock, "\n")
cat("Average Non-Tradable Direct Shock:", avg_nontradable_shock, "\n")

# 4. 构建面板回归数据 (Panel Data for Econometrics)
# 将 4 个 CPI 序列映射到 可贸易 vs 非可贸易
cpi_panel <- cpi_data %>%
  mutate(
    Sector_Type = case_when(
      Series_ID %in% c("CUUR0000SAA", "CUUR0000SAD") ~ "Tradable",
      Series_ID %in% c("CUUR0000SEHA", "CUUR0000SAM") ~ "Non-Tradable"
    )
  ) %>%
  arrange(Series_ID, Year, Month) %>%
  group_by(Series_ID) %>%
  # 计算同比通胀率 (Year-over-Year Inflation)，即相较于12个月前
  mutate(Inflation = (Value - lag(Value, 12)) / lag(Value, 12) * 100) %>%
  filter(!is.na(Inflation))

# 定义 301 关税加征所带来的实际关税变化 (宏观 Shift 冲击向量)
# 以 2017 年为基准（加征关税前夜，净关税冲击为0），2018年因年中加征为 12%，2019年起升至 17.5%，2020年后稳定在 19.3%
tariff_shock_vector <- c(
  "2015" = 3.1, "2016" = 3.1, "2017" = 3.1,
  "2018" = 12.0, "2019" = 17.5, "2020" = 19.3,
  "2021" = 19.3, "2022" = 19.3, "2023" = 19.3,
  "2024" = 19.3, "2025" = 19.3
)

cpi_panel <- cpi_panel %>%
  mutate(
    Direct_Shock_Index = ifelse(Sector_Type == "Tradable", avg_tradable_shock, avg_nontradable_shock),
    Network_Centrality = ifelse(Sector_Type == "Tradable", avg_tradable_network, avg_nontradable_network),
    Tariff_Intensity = tariff_shock_vector[as.character(Year)] - 3.1, # 扣除基期，代表净关税增幅
    Labor_Reproduction_Shock = Network_Centrality * Tariff_Intensity
  )

# 5. 运行固定效应面板回归 (Fixed Effects Panel Regression)
cat("\nRunning Econometric Regression (Shift-Share + Network Control)...\n")
model <- lm(Inflation ~ Direct_Shock_Index + Labor_Reproduction_Shock + as.factor(Year) + as.factor(Month), data = cpi_panel)

# 输出标准 OLS 结果
cat("\n--- Standard OLS Regression Results ---\n")
print(summary(model))

# 引入 Newey-West 异方差与自相关稳健标准误 (HAC Standard Errors) 以应对时间序列自相关
cat("\n--- Newey-West HAC Robust Regression Results ---\n")
library(sandwich)
library(lmtest)
hac_results <- coeftest(model, vcov = NeweyWest(model))
print(hac_results)

# 写入处理后的结果数据以供可视化
dir.create("data/processed", showWarnings = FALSE)
write.csv(cpi_panel, "data/processed/cpi_panel_analysis.csv", row.names=FALSE)
write.csv(network_exposure, "data/processed/network_exposure.csv", row.names=FALSE)
cat("Data processed and saved to data/processed/\n")
