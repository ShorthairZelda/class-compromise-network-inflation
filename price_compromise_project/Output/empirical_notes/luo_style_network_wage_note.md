# Luo-style 网络传导模型：实际工资检验

模型将关税冲击拆成 own shock、upstream shock 和 downstream shock。Upstream shock 使用本行业投入品供应商的关税暴露，Downstream shock 使用本行业客户行业的关税暴露。

该设定借鉴 Luo and Villar (2023) 中 own / upstream / downstream shock 的思路，但不估计传统空间 SAR 模型；它更接近产业网络版 SLX 模型。

主要输出：

- `Output/tables/luo_style_real_wage_etable.txt`：实际工资结果。
- `Output/tables/luo_style_price_wage_gap_etable.txt`：价格-工资缺口结果。
- `Output/tables/luo_style_input_price_wage_gap_etable.txt`：中间品投入价格-工资缺口结果。
- `Output/tables/luo_style_price_etable.txt`：总产出价格结果。
- `Output/tables/luo_style_network_coefficients.csv`：所有系数和 p 值。
