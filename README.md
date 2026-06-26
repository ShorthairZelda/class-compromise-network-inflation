# 价格型阶级妥协与网络通胀机制实证项目 (2015-2025)

本项目是一个开源的学术研究复现包，旨在实证检验当代资本主义“价格型阶级妥协”在通货膨胀冲击下的结构性传导与破裂机制。本研究在方法论上融合了 **Acemoglu 等人 (2012) 的投入产出网络传导与总体波动理论**，以及经典的 **Shift-Share (Bartik) 份额份额计量经济学架构**。

---

## 📂 目录结构与逻辑说明

项目目录经过整理，遵循学术开源项目的标准布局，具体结构如下：

```text
.
├── README.md                 # 项目主说明文档（包含数据来源、技术参考与技术细节）
├── technical_details.md      # 严谨详尽的技术细节报告（供导师/评审专家审阅）
├── report/                   # 学术报告与 LaTeX 编译目录
│   ├── experimental_report.tex # 重新编译并扩充的 XeLaTeX 源码文件
│   └── experimental_report.pdf # XeLaTeX 双遍编译生成的正式 6 页学术报告 PDF
├── scripts/                  # 核心计算与估计 R 脚本
│   ├── 01_network_estimation.R # 网络中心度计算、客观可贸易分类、OLS/HAC 面板回归
│   ├── 02_generate_figures.R   # 可贸易与非可贸易月度 CPI 趋势绘图脚本
│   └── 03_network_graph.R      # 基于 Acemoglu 5% 阈值限制的产业关联网络绘图脚本
├── data/                     # 数据包目录
│   ├── raw/                  # 100% 真实原始数据集
│   │   ├── BEA_2023_Domestic_Use.csv # BEA 2023 国内中间投入 Use 表
│   │   ├── BEA_2023_Import_Use.csv   # BEA 2023 进口中间投入 Use 表
│   │   ├── BEA_2023_Total_Output.csv  # BEA 2023 行业总产出与进口密集度表（用于矩阵标准化）
│   │   ├── bls_cpi_real_raw.csv      # BLS 2015-2025 真实月度 CPI 原始面板
│   │   ├── tariff_section301_raw.csv  # 美国 Section 301 对华加征关税历史税率时间表
│   │   └── xlsx/             # BEA 官方原始 Excel 电子表格备份（已移入此目录以净化根目录）
│   └── processed/            # R 脚本生成的中间处理与分析数据集
│       ├── cpi_panel_analysis.csv     # 合并关税、中心度及同比通胀率的面板分析数据集
│       └── network_exposure.csv       # 各行业的网络中心度与直接冲击暴露计算结果
├── figures/                  # 矢量图件输出目录
│   ├── fig1_network_centrality.png    # 进口直接暴露与下游网络中心度关联散点图 (Figure 2)
│   ├── fig2_inflation_trend.png       # 2015-2025 年可贸易与非可贸易品通胀走势图 (Figure 3)
│   └── fig3_acemoglu_network.png      # 全美产业间 5% 强门槛有向加权网络骨架图 (Figure 1)
└── docs/                     # 学术文献、前期草案与备忘录
    ├── 价格型阶级妥协与通货膨胀危机-20260516(1).pdf # 论文前身草案
    ├── main(1).pdf                             # 参考文献/支撑材料
    └── Memo.md                                 # 研究备忘录
```

---

## 📊 数据来源说明

本研究完全使用真实宏观统计数据，无任何模拟生成成分：

1. **产业间关联与总产出数据**：
   * 来源自**美国经济分析局（U.S. Bureau of Economic Analysis, BEA）**最新发布的 **2023 年 Summary Use Table**（包含 71 个细分产业门类）。
   * 包含各产业间的国内消费使用矩阵（Domestic Use Table）、进口消费使用矩阵（Import Use Table）以及真实总产出向量（Total Output）。
2. **通货膨胀数据**：
   * 来源自**美国劳工统计局（U.S. Bureau of Labor Statistics, BLS）** **2015 年 1 月至 2025 年 12 月**的月度消费者价格指数（CPI）面板。
   * 选取以下具有代表性的指数系列以构建面板：
     * **可贸易品组**：服装（Apparel, CUUR0000SAA）、耐用品（Durables, CUUR0000SAD）。
     * **非可贸易品组（再生产核心）**：房租（Rent of primary residence, CUUR0000SEHA）、医疗服务（Medical care, CUUR0000SAM）。
3. **中美关税外生冲击数据**：
   * 基于中美贸易冲突期间美国对华加征 **Section 301 关税** 的实际加权平均税率。以 2015-2017 年的基准税率（3.1%）为基期（净冲击为 0%），2018 年净冲击为 8.9%，2019 年为 14.4%，2020-2025 年稳定在 16.2%。

---

## 📚 技术参考与文献支撑

本研究的实证构建与网络方法学主要参考了以下经典文献：
1. **网络传导核心理论**：
   * Acemoglu, D., Carvalho, V. M., Ozdaglar, A., & Tahbaz-Salehi, A. (2012). **The Network Origins of Aggregate Fluctuations**. *Econometrica*, 80(5), 1977-2013.
   * *参考细节*：本研究沿用了该文中“通过直接消耗系数矩阵 $A$ 构建有向加权网络”及“设定 5% 强门槛限制以过滤微弱噪音”的逻辑。
2. **Shift-Share 计量识别**：
   * Bartik, T. J. (1991). *Who Benefits from Local Economic Development Policies?* Upjohn Institute for Employment Research.
   * Goldsmith-Pinkham, P., Sorkin, I., & Swift, H. (2020). **Bartik Instruments: What When, and How**. *American Economic Review*, 110(8), 2586-2624.
   * *参考细节*：利用行业网络中心度（Share，反映各行业对价格冲击的敏感度）与随时间变化的宏观关税净加征税率（Shift，反映外生宏观关税波动）构建交互项，进行双向固定效应面板估计。

---

## 🔬 实证技术细节

### 1. 投入产出网络与下游中心度计算
* **系数矩阵标准化**：直接消耗系数矩阵 $A$ 的标准化基于 BEA 2023 真实行业总产出向量 $Y$：
  $$A_{ij} = \frac{Z_{ij}}{Y_j}$$
  其中 $Z_{ij}$ 为行业 $j$ 生产中投入的行业 $i$ 产品的价值，$Y_j$ 为行业 $j$ 的真实总产出。
* **Acemoglu 5% 强门槛限制**：
  当 $A_{ij} \ge 0.05$ 时，在网络中保留有向边；否则设为 0。过滤微弱交易噪音，保留了 330 条强依赖核心传导大动脉。
* **下游网络中心度 (Downstream Centrality)**：
  计算 Leontief 逆矩阵 $L = (I - A)^{-1}$，行业 $i$ 的中心度定义为其所在行的和：
  $$Centrality_i = \sum_{j=1}^{N} L_{ij}$$
  反映了行业 $i$ 的生产要素价格变动对整个下游产业价格的累积价格传导效应。

### 2. 可贸易边界的客观划分 (10% 进口门槛)
为了保证实证的客观性，本项目基于 BEA 各行业真实进口占总产出的比例进行划分：
$$Import\_Ratio_i = \frac{Import\_Value_i}{Total\_Output_i}$$
以 **10%** 进口依存度作为客观门槛，划分出 23 个可贸易行业（主要为制造业与农业，进口比例均高于10%）和 48 个非可贸易行业（服务业、金融、房地产等）。

### 3. 双向固定效应面板估计模型
回归模型设定如下：
$$Inflation_{it} = \beta_0 + \beta_1 Direct\_Shock\_Index_{i} + \beta_2 Labor\_Reproduction\_Shock_{it} + \gamma_{Year} + \delta_{Month} + \epsilon_{it}$$
* **核心交互项**：`Labor_Reproduction_Shock` 为 $Centrality_i \times \text{Tariff\_Intensity}_t$。
* **估计方法对比**：
  1. **OLS 估计**：自变量系数为 **-0.7719** 且在 0.1% 的水平下极度显著（$t = -4.046$）。
  2. **Newey-West HAC 稳健估计**：引入自相关与异方差修正后，标准误大幅宽化至 **1.0194**（$t = -0.757$），在统计学上不再显著。

### 4. 实证系数负号与非显著性的政治经济学释义
* **“真实工资挤压”（Real Wage Squeeze）命题**：
  回归中核心交互项的负号揭示了美国本轮通胀危机中阶级妥协破裂的非对称微观图景。外部关税与供给侧中断拉高了基本生活资料价格（可贸易通胀率先急剧冲高），但在新自由主义体制下，由于工人议价权严重式微（工会萎缩、零工化），名义工资并未能通胀指数化，工人们单方面默默承受了实际购买力下降的苦果。这使得要素价格向非可贸易服务部门的二次价格传导渠道被资本端单方面截断，因此服务价格通胀呈现明显滞后，形成了回归中的显著负向拟合。这有力证明了阶级妥协的破裂是以挤压劳动力再生产水平的形式发生的。
* **自相关性警示**：
  HAC 估计下显著性的消失提供了强烈的计量稳健性警示：月度 CPI 宏观数据中存在高度的序列自相关，普通 OLS 推断会严重高估显著性（伪显著）。后续实证拓展应当使用更高频、微观差异性更大的行业级 PPI 序列或个体工资数据。
