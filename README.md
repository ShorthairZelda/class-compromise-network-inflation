# 价格型阶级妥协的脆弱性

低价商品供给、关税战、供应链冲击与美国劳动者再生产成本压力

## 项目概述

本仓库提供一项关于美国价格型阶级妥协脆弱性的实证研究。项目关注的问题是：全球低成本生产和流通体系是否主要压低了可贸易消费品价格，而难以同样压低住房、医疗、教育、护理、养老和育儿等高度依赖本地制度安排、资产价格结构、公共服务体系和本地劳动投入的再生产成本。研究进一步考察，当贸易品价格和供应链成本在 2021-2022 年快速上升时，价格压力是否通过投入产出网络进入更广泛的美国行业价格体系。

本文不把“进口扩张降低美国部分消费品价格”或“贸易战关税由美国企业和消费者承担”作为需要重新证明的结论。相关事实已经由 Jaravel and Sager (2019)、Amiti, Redding, and Weinstein (2020) 以及 Cavallo et al. (2021) 等研究提供了较充分证据。本项目在这些文献基础上提出进一步问题：低价商品供给的缓冲边界在哪里，且当该渠道受到关税、供应链和贸易品通胀冲击时，价格压力是否会沿产业网络传导到本地再生产相关行业。

## 主要文件

- [实证报告 PDF](empirical_report.pdf)
- [技术附录 PDF](empirical_technical_document.pdf)
- [实证报告 LaTeX](price_compromise_project/Output/rebuild/reports/formal_empirical_chapter.tex)
- [技术附录 LaTeX](price_compromise_project/Output/rebuild/reports/empirical_technical_document.tex)
- [BibTeX 文献库](price_compromise_project/Output/rebuild/reports/empirical_references.bib)

## 理论命题

研究的核心命题是：价格型阶级妥协是一种局部、阶段性的稳定机制，而不是完整的劳动者再生产保障机制。全球低成本生产和流通体系能够压低服装、耐用品、家居用品、部分汽车和娱乐商品等可贸易或全球供应链商品价格；但住房、医疗、教育、护理、养老和育儿等再生产成本高度嵌入本地制度、资产价格和服务劳动结构，难以通过进口和外包被同样压低。

因此，低价商品供给能够在一定时期内缓和名义工资增长不足与消费成本上升之间的矛盾，但其稳定作用具有明显边界。当贸易品价格、物流成本和供应链压力上升时，原本承担缓冲功能的低价商品部门会转化为价格压力来源，并通过产业投入产出网络影响其他行业。

## 文献定位

本项目吸收四组文献。

第一，贸易与消费者价格文献表明，中国进口扩张和全球低价供给降低了美国消费者价格，尤其集中在可贸易商品领域。代表性研究包括 Jaravel and Sager (2019)。

第二，贸易战关税传导文献表明，2018 年后的美国 Section 301 关税主要由美国进口商、企业和消费者承担，并逐步向零售端传导。代表性研究包括 Amiti, Redding, and Weinstein (2020) 与 Cavallo et al. (2021)。

第三，生产网络文献说明，部门冲击可以通过投入产出联系被放大，并形成更广泛的价格和产出波动。本文特别参考 Acemoglu et al. (2012) 的网络冲击思想，以及 Luo and Villar (2023) 对上游供应商冲击和下游购买方冲击的区分。

第四，疫情后通胀文献强调，2021-2022 年通胀不能仅从总需求解释，而需要考察部门供给约束、供应链压力和投入联系。相关研究包括 Baqaee and Farhi (2022)、di Giovanni et al. (2022) 和 Pasten, Schoenle, and Weber (2020)。

## 数据来源

项目使用以下数据。

- BLS CPI-U 分类价格数据：用于构造低价商品、本地再生产成本和再生产成本平减指数。
- BLS CPI-U core commodities 与 core services 代理：用于衡量贸易品和非贸易品通胀。
- BEA 年度行业价格数据：包括行业总产出价格指数和中间投入价格指数。
- BEA 2019 年投入产出矩阵：用于构造行业贸易品投入暴露、商品供应链暴露和下游网络暴露。
- Section 301 关税暴露数据：用于构造行业直接关税暴露和投入产出网络关税暴露。
- QCEW 行业就业和工资数据：用于补充价格-工资压力缺口分析。

主回归样本覆盖 2017-2025 年、66 个 BEA summary 行业，共 594 个行业-年份观测。扩展样本覆盖 2010-2025 年、66 个行业，共 1056 个行业-年份观测，作为稳健性检验使用。

## 变量构造

行业价格结果变量为 BEA 行业总产出价格增长率和中间投入价格增长率：

```text
Delta log P_it = log(P_it) - log(P_i,t-1)
```

贸易品投入暴露由 2019 年 BEA 投入产出矩阵构造。设 `W_ij` 为行业 `i` 从部门 `j` 采购中间投入的份额，`G` 为农业、采矿和制造业等可贸易商品部门集合，则：

```text
TradableInputExposure_i = sum_{j in G} W_ij
TradableInputShock_it = TradableInputExposure_i * TradableGoodsInflation_t
```

主回归使用当期与一期滞后累计冲击：

```text
TradableInputShock_i,t:t-1 = TradableInputShock_it + TradableInputShock_i,t-1
```

本地再生产核心部门包括住房、其他房地产、教育、门诊医疗、医院、护理与居住照护、社会援助。项目还构造下游贸易品网络暴露，用于借鉴 Luo and Villar (2023) 的上游/下游分解。

## 计量模型

主模型为行业和年份双向固定效应模型：

```text
Delta log P_it = beta TradableInputShock_i,t:t-1 + alpha_i + delta_t + epsilon_it
```

其中，年份固定效应吸收全国共同通胀、宏观政策和总需求变化；行业固定效应吸收行业长期不变的技术、价格水平和市场结构差异。识别来自同一年份内不同行业对贸易品投入的预定暴露差异。

本地再生产部门异质性模型为：

```text
Delta log P_it =
  beta TradableInputShock_i,t:t-1
  + theta Local_i * TradableInputShock_i,t:t-1
  + alpha_i + delta_t + epsilon_it
```

Luo 式上游/下游分解模型区分贸易品投入冲击和贸易品下游暴露冲击，用于判断本地再生产部门的价格压力是否主要来自普通上游商品投入，还是来自网络位置、制度性成本和价格-工资调整错配。

Section 301 关税模型作为补充政策冲击设计，用于检验关税是否通过投入产出网络进入行业价格体系。该模型不把关税解释为 2021-2022 年通胀爆发的唯一来源。

## 主要发现

第一，CPI 分类价格显示，1984-2025 年间，低价可贸易商品价格显著低于住房、医疗、教育等本地再生产成本。低价商品渠道真实存在，但其缓冲范围有限。

第二，贸易品通胀在 2021-2022 年快速上升。行业网络回归显示，越依赖贸易品投入的行业，其总产出价格和中间投入价格增长越快。主样本中，贸易品投入通胀冲击对总产出价格增长的系数约为 0.0073，对中间投入价格增长的系数约为 0.0055，均在 1% 水平显著。

第三，扩展样本稳健性检验表明，主结果不依赖于 2017-2025 年短窗口。在 2010-2025 年扩展样本中，贸易品投入通胀冲击对总产出价格增长和中间投入价格增长仍显著为正。

第四，本地再生产部门并不是通过普通上游商品投入渠道表现出更强反应。相关显著性更多出现在下游网络暴露和价格-工资压力缺口中。这一结果支持本文的理论解释：本地再生产部门价格压力不能简单归因于进口商品投入涨价，而更多体现为本地制度成本、行业网络位置和工资调整错配。

第五，Section 301 关税补充检验显示，直接关税暴露本身不总是稳定显著，但投入产出网络关税暴露更稳定为正，说明政策冲击也可以通过生产网络进入行业价格体系。

## 仓库结构

```text
.
├── README.md
├── empirical_report.pdf
├── empirical_technical_document.pdf
├── price_compromise_project/
│   ├── Data/
│   │   ├── processed/
│   │   ├── rebuild/
│   │   └── extended/
│   ├── Output/
│   │   ├── rebuild/figures/
│   │   ├── rebuild/regressions/
│   │   └── rebuild/reports/
│   ├── Refs/
│   └── src/
└── notes/
```

## 复现流程

进入项目目录：

```bash
cd price_compromise_project
```

重建主样本数据、表格和变量：

```bash
python3 src/10_rebuild_empirical_pipeline.py
```

生成主回归表：

```bash
Rscript src/11_rebuild_network_regressions.R /Users/linian/Documents/论文初稿/price_compromise_project
```

生成图形：

```bash
Rscript src/12_rebuild_figures.R /Users/linian/Documents/论文初稿/price_compromise_project
```

构造并估计扩展样本稳健性：

```bash
python3 src/13_build_extended_sample.py
Rscript src/14_extended_sample_regressions.R /Users/linian/Documents/论文初稿/price_compromise_project
```

编译实证报告和技术附录：

```bash
cd Output/rebuild/reports
xelatex -interaction=nonstopmode formal_empirical_chapter.tex
bibtex formal_empirical_chapter
xelatex -interaction=nonstopmode formal_empirical_chapter.tex
xelatex -interaction=nonstopmode formal_empirical_chapter.tex

xelatex -interaction=nonstopmode empirical_technical_document.tex
bibtex empirical_technical_document
xelatex -interaction=nonstopmode empirical_technical_document.tex
xelatex -interaction=nonstopmode empirical_technical_document.tex
```

## 结果文件

- `price_compromise_project/Output/rebuild/regressions/rebuild_table1_tradable_inflation_main.tex`
- `price_compromise_project/Output/rebuild/regressions/rebuild_table2_tradable_inflation_upstream_downstream.tex`
- `price_compromise_project/Output/rebuild/regressions/rebuild_table3_tradable_inflation_robustness.tex`
- `price_compromise_project/Output/rebuild/regressions/rebuild_table4_tradable_pressure_gap.tex`
- `price_compromise_project/Output/rebuild/regressions/rebuild_table7_extended_sample_robustness.tex`
- `price_compromise_project/Output/rebuild/reports/formal_empirical_chapter.pdf`
- `price_compromise_project/Output/rebuild/reports/empirical_technical_document.pdf`

## 解释边界

本项目识别的是行业层面的价格传导和投入产出网络机制，不是家庭层面福利损失的完整估计。再生产成本指数是根据理论构造的研究性指标，不是官方生活成本指数。扩展样本仍使用 2019 年投入产出矩阵，因此应理解为稳健性检验，而不是对整个 2010 年代网络结构的完全历史重建。后续研究应进一步引入 CEX 或 PCE 权重、地区住房价格、医疗保险成本、育儿和养老服务价格，以及更细分的家庭支出结构。

## 参考文献

Acemoglu, D., Carvalho, V. M., Ozdaglar, A., & Tahbaz-Salehi, A. (2012). The network origins of aggregate fluctuations. *Econometrica, 80*(5), 1977-2016.

Amiti, M., Redding, S. J., & Weinstein, D. E. (2020). Who's paying for the US tariffs? A longer-term perspective. *AEA Papers and Proceedings, 110*, 541-546.

Baqaee, D. R., & Farhi, E. (2022). Supply and demand in disaggregated Keynesian economies with an application to the COVID-19 crisis. *American Economic Review, 112*(5), 1397-1436.

Cavallo, A., Gopinath, G., Neiman, B., & Tang, J. (2021). Tariff pass-through at the border and at the store: Evidence from US trade policy. *American Economic Review: Insights, 3*(1), 19-34.

di Giovanni, J., Kalemli-Ozcan, S., Silva, A., & Yildirim, M. A. (2022). Global supply chain pressures, international trade, and inflation. NBER Working Paper No. 30240.

Jaravel, X., & Sager, E. (2019). What are the price effects of trade? Evidence from the US and implications for quantitative trade models. NBER Working Paper No. 25868.

Luo, S., & Villar, D. (2023). Propagation of shocks in an input-output economy: Evidence from disaggregated prices. Working paper.

Pasten, E., Schoenle, R., & Weber, M. (2020). The propagation of monetary policy shocks in a heterogeneous production economy. *Journal of Monetary Economics, 116*, 1-22.
