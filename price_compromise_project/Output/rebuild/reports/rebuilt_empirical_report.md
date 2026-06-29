# 价格型阶级妥协脆弱性的实证重建报告

## 一、研究命题与实证定位

本文要检验的不是“再生产成本上升会使以再生产成本平减的实际工资下降”。这一关系接近定义式，不宜作为主实证贡献。本文新的实证目标是说明：低价供给主要集中在可贸易消费品和可由全球供应链组织生产的商品上；而住房、医疗、教育、养老和育儿等高度依赖本地制度安排、公共服务体系、资产价格结构和本地劳动投入的再生产成本，难以被全球低价商品供给机制同等压低。

因此，实证部分分为两层。第一层用 CPI 分类价格展示低价商品渠道的边界：可贸易低价商品长期价格涨幅显著低于本地化再生产成本。第二层用 Section 301 关税暴露和 BEA 投入产出网络检验冲击传导：当低价供给渠道受到关税战和供应链冲击时，价格压力会通过产业网络进入国内生产价格体系。

## 二、数据来源与清洗规则

1. CPI 分类价格数据来自 BLS CPI-U 年度序列，已整理为 `data/processed/cpi_annual_normalized.csv`。所有 CPI 分类指数统一标准化为 1984=100。

2. 本文构造四组描述性价格指数：`CheapGoodsIndex`、`CPIAllItems`、`BasicReproductionCostIndex`、`LocalReproductionCostIndex`。其中低价商品组包括耐用品、服装、家居用品、汽车、娱乐商品和服务等；本地化再生产成本组包括住房、租金、医疗、教育与通信。该指数是本文构造的分析指标，不是官方统计指标。

3. Section 301 关税暴露来自既有项目中已整理的关税匹配数据，并分别映射到 CPI 分类和 BEA 行业层面。CPI 分类暴露用于说明关税冲击集中在商品部门；BEA 行业暴露用于构造主回归中的直接冲击和 I-O 网络冲击。

4. 产业网络使用 BEA 2019 投入产出矩阵。主网络变量为行业供应链上游暴露，即行业所使用投入品部门的关税暴露加权平均。稳健性检验使用 5% 强连接网络、剔除自身行业后的网络暴露，以及直接、上游、下游冲击分解。

5. 行业价格结果变量使用 BEA 行业总产出价格增长率和中间投入价格增长率。回归样本为 2017-2025 年、66 个 BEA 行业，共 594 个行业-年份观测。

## 三、描述性事实：低价供给的边界

**Figure 1. 低价商品与再生产成本的长期分化**

![Figure 1](/Users/linian/Documents/论文初稿/price_compromise_project/output/rebuild/figures/rebuild_fig1_index_divergence.png)

图 1 显示，1984-2025 年间低价可贸易商品指数仅从 100 上升至 146.7，而本地化再生产成本指数上升至 451.7，基本再生产成本指数上升至 362.0，CPI 总指数为 309.9。这说明全球低价生产和流通确实压低了部分商品价格，但这种缓冲并没有覆盖住房、医疗、教育等本地制度性再生产成本。

**Figure 2. 再生产成本相对低价商品的价格缺口**

![Figure 2](/Users/linian/Documents/论文初稿/price_compromise_project/output/rebuild/figures/rebuild_fig1b_reproduction_to_cheap_gap.png)

图 2 进一步把再生产成本指数除以低价商品指数。到 2025 年，本地化再生产成本与低价商品的相对价格比达到 3.08，基本再生产成本与低价商品的相对价格比达到 2.47。该结果支持本文的核心判断：价格型阶级妥协不是完整的再生产保障机制，而是建立在部分商品低价化之上的局部稳定机制。

**Figure 3. 2025 年 CPI 分类价格水平**

![Figure 3](/Users/linian/Documents/论文初稿/price_compromise_project/output/rebuild/figures/rebuild_fig2_2025_category_levels.png)

图 3 显示，医疗、租金、住房等本地化再生产成本位于价格指数最高组；耐用品、服装、家居用品和汽车等可贸易或全球供应链商品位于较低价格组。这一排序与理论机制一致：可以通过进口竞争和全球供应链压价的部门，与高度本地化、制度化和资产化的再生产部门之间存在系统性差异。

## 四、冲击期事实：低价缓冲机制的失效

**Figure 4. 通胀冲击窗口中的不同价格指数**

![Figure 4](/Users/linian/Documents/论文初稿/price_compromise_project/output/rebuild/figures/rebuild_fig3_inflation_shock_window.png)

2016-2020 年，低价商品价格增长较弱，体现出其平抑消费价格的作用。但在 2021-2022 年，低价商品通胀分别达到 10.1% 和 9.6%，高于 CPI 总指数。这不是对本文命题的反驳，而是本文要解释的冲击情形：当关税战、供应链瓶颈和全球生产条件变化削弱低价供给渠道时，原本承担缓冲功能的商品部门本身也转为价格压力来源。

**Figure 5. Section 301 关税暴露的 CPI 分类分布**

![Figure 5](/Users/linian/Documents/论文初稿/price_compromise_project/output/rebuild/figures/rebuild_fig4_cpi_301_exposure_by_class.png)

图 5 显示，2018-2025 年平均 Section 301 暴露主要集中在汽车、家居用品、耐用品、娱乐和服装等商品类别。住房、租金、医疗、教育与通信的直接关税暴露为 0。这一结果非常关键：关税战直接打击的是低价商品和商品化基本生活资料渠道，而不是本地化再生产成本本身。这恰好说明价格型阶级妥协的双重限度：一方面，它没有能力压低本地化再生产成本；另一方面，它依赖的低价商品渠道又容易被贸易和供应链冲击破坏。

## 五、主实证模型：关税冲击的产业网络传导

主模型为行业-年份双向固定效应模型：

```text
Delta log Price_it = alpha_i + delta_t
                   + beta NetworkTariffShock_i,t:t-1
                   + epsilon_it
```

其中 `alpha_i` 为行业固定效应，`delta_t` 为年份固定效应，标准误按行业聚类。被解释变量分别为 BEA 总产出价格增长率和中间投入价格增长率。核心解释变量为行业通过投入产出网络承受的 Section 301 关税暴露，使用当期与一期滞后累计值。

标准 R 回归表由 `fixest::etable()` 直接导出，存放在：

- `/Users/linian/Documents/论文初稿/price_compromise_project/output/rebuild/regressions/rebuild_table1_industry_price_network_main.txt`
- `/Users/linian/Documents/论文初稿/price_compromise_project/output/rebuild/regressions/rebuild_table1_industry_price_network_main.tex`

**Table 1. 关税冲击、I-O 网络暴露与行业价格增长**

主回归结果显示，直接关税暴露对行业价格增长不显著；但 I-O 网络关税暴露显著为正。对于总产出价格增长，网络暴露系数为 0.0608，标准误为 0.0248，在 5% 水平显著。对于中间投入价格增长，网络暴露系数为 0.0689，标准误为 0.0210，在 1% 水平显著。

这说明 Section 301 关税冲击并不只是停留在被直接加税的商品或行业，而是通过投入产出网络进入生产成本结构。这个结果支撑本文的核心机制：当低价供给渠道受到外部冲击时，价格压力会沿产业网络扩散，从而削弱价格型阶级妥协赖以成立的低价环境。

**Table 2. 网络冲击变量的稳健性检验**

稳健性表存放在：

- `/Users/linian/Documents/论文初稿/price_compromise_project/output/rebuild/regressions/rebuild_table2_industry_price_network_robustness.txt`
- `/Users/linian/Documents/论文初稿/price_compromise_project/output/rebuild/regressions/rebuild_table2_industry_price_network_robustness.tex`

结果显示，使用完整 I-O 网络、5% 强连接网络和剔除自身行业后的网络暴露，系数均为正且在 5% 或 1% 水平显著。总产出价格中，5% 强连接网络系数为 0.0600，剔除自身行业后的网络系数为 0.0893；中间投入价格中，对应系数分别为 0.0705 和 0.0951。说明本文结果不是由某一种网络口径机械驱动。

**Table 3. 加权与非加权稳健性**

表格存放在：

- `/Users/linian/Documents/论文初稿/price_compromise_project/output/rebuild/regressions/rebuild_table3_weighting_robustness.txt`
- `/Users/linian/Documents/论文初稿/price_compromise_project/output/rebuild/regressions/rebuild_table3_weighting_robustness.tex`

加权与非加权回归均得到正且显著的网络暴露系数。总产出价格的非加权系数为 0.0642，在 5% 水平显著；中间投入价格的非加权系数为 0.0724，在 1% 水平显著。说明结果不完全依赖行业规模权重。

**Table 4. 事件研究**

表格存放在：

- `/Users/linian/Documents/论文初稿/price_compromise_project/output/rebuild/regressions/rebuild_table4_event_study.txt`
- `/Users/linian/Documents/论文初稿/price_compromise_project/output/rebuild/regressions/rebuild_table4_event_study.tex`

事件研究以 2017 年为基准，考察高直接关税暴露行业在 2018 年后的相对价格变化。结果显示，2021 年和 2022 年高暴露行业的总产出价格和中间投入价格增长显著更高。这与描述性 CPI 图中的 2021-2022 年低价商品通胀跳升相互呼应，说明冲击效应在疫情后供应链紧张与通胀环境下进一步显现。

**Figure 6. 直接暴露与 I-O 网络暴露**

![Figure 6](/Users/linian/Documents/论文初稿/price_compromise_project/output/rebuild/figures/rebuild_fig5_industry_direct_vs_network_exposure.png)

图 6 显示，部分行业即使自身直接关税暴露较低，也可能由于上游投入部门受到冲击而面临较高网络暴露。这正是普通双向固定效应模型无法自动捕捉的内容：网络传导必须通过投入产出矩阵构造出来。

## 六、目前可以主张的结论

第一，描述性 CPI 证据表明，低价供给渠道主要覆盖可贸易商品和全球供应链商品。1984-2025 年，低价商品价格指数远低于本地化再生产成本指数，说明价格型阶级妥协具有明确的部门边界。

第二，Section 301 暴露分布显示，贸易战冲击集中在商品部门，尤其是汽车、家居用品、耐用品、服装和娱乐等类别；住房、租金、医疗、教育等本地化再生产成本没有直接关税暴露。这说明低价商品机制可以被关税冲击破坏，但它本来就无法覆盖本地制度性再生产成本。

第三，行业网络回归显示，I-O 网络关税暴露显著推高 BEA 行业总产出价格和中间投入价格。该结果把前人关于进口降价、关税传导和供应链冲击的研究推进到本文自己的政治经济学命题：低价供给渠道一旦受到冲击，价格压力会通过国内生产网络扩散，使局部价格妥协的脆弱性在通胀条件下集中显现。

## 七、下一步需要补强的部分

1. 将 BEA 行业价格替换或补充为 BLS PPI 行业价格，并保留当前 BEA 结果作为可复现实证版本。

2. 增加 GSCPI 与行业进口依赖度、上游进口暴露度的交互模型。该模型应使用行业异质性暴露识别，而不是单独用总量 GSCPI 做时间序列回归。

3. 对 CPI 端分类进一步细化，若能取得 childcare、eldercare、tuition、health services 等更细分类别，应把“本地化再生产成本”从 shelter/medical/education 扩展到照护和教育服务。

4. 在正文写作中明确区分三类证据：前人文献已经证明的事实、本文描述性展示的事实、本文回归识别得到的网络传导结果。
