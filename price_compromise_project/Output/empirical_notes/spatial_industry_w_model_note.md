# 空间计量式产业 W 矩阵模型结果备忘

本模型不采用 Luo and Villar 的结构分解，而是借鉴空间计量经济学中的权重矩阵思想，重新构建产业网络 W 矩阵。

模型形式：

`Y_it = beta DirectShock_it + theta WShock_it + industry FE + year FE + error_it`

W 矩阵版本：

- `input_share`：基于 2019 年 BEA 投入份额的有向行标准化矩阵，去除对角线。
- `binary_5pct`：投入份额超过 5% 的强连接邻接矩阵，行标准化。
- `symmetric_input_output`：将投入关系对称化后行标准化，表示一般产业邻近性。
- `inverse_network_distance_5pct`：基于 5% 强连接网络的最短路径距离，使用距离倒数作为权重并行标准化。

解释：`WShock` 是空间计量意义上的 spatial lag of X，即相邻产业冲击，而不是 spatial lag of Y。因此它避免了同时期 `WY` 带来的反射问题，更适合作为本文主检验。

输出文件：

- `Data/analysis/spatial_industry_w_matrices_long.csv`
- `Data/analysis/spatial_industry_w_matrix_summary.csv`
- `Data/analysis/spatial_industry_w_shocks_2016_2025.csv`
- `Output/tables/spatial_w_output_price_etable.txt`
- `Output/tables/spatial_w_input_price_etable.txt`
- `Output/tables/spatial_w_real_wage_etable.txt`
- `Output/tables/spatial_w_price_wage_gap_etable.txt`
- `Output/tables/spatial_w_model_coefficients.csv`
