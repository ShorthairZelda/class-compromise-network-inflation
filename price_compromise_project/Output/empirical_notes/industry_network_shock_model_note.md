# 产业网络冲击模型结果备忘

模型形式：

`Y_it = beta1 OwnShock_it + beta2 UpstreamShock_it + beta3 DownstreamShock_it + industry FE + year FE + error_it`

其中 OwnShock 为本行业直接 Section 301 关税暴露；UpstreamShock 为本行业投入品供应商的关税暴露，按 2019 年 BEA 投入份额加权；DownstreamShock 为客户行业关税暴露，按本行业销售给客户行业的产出份额加权。

主要发现：

- 上游网络冲击对总产出价格显著为正，说明价格效应主要来自供应链上游，而非本行业直接暴露。
- 上游网络冲击对中间品投入价格也显著为正，说明生产/再生产成本压力沿投入网络传导。
- 实际工资和价格-工资缺口方向符合理论，但通常只在 10% 水平边际显著，适合作为辅助证据。
- 同时放入 own、upstream、downstream 时，由于三类网络冲击相关性较高，单个系数显著性会下降；因此 upstream-only 和 strong-link upstream 是更清晰的机制检验。

输出文件：

- `Output/tables/industry_network_shock_main_etable.txt`
- `Output/tables/industry_network_shock_strong_links_etable.txt`
- `Output/tables/industry_network_shock_upstream_only_etable.txt`
- `Output/tables/industry_network_shock_coefficients.csv`
