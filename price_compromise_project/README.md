# 价格型阶级妥协实证项目目录

本目录包含“价格型阶级妥协的脆弱性”项目的核心数据、代码、图表、回归表和 LaTeX 报告。仓库根目录的 `README.md` 提供完整研究概述；本文件说明项目目录内部结构和复现流程。

## 核心产出

- `Output/rebuild/reports/formal_empirical_chapter.pdf`：标准实证报告。
- `Output/rebuild/reports/empirical_technical_document.pdf`：技术附录。
- `Output/rebuild/reports/empirical_references.bib`：BibTeX 文献库。
- `Output/rebuild/regressions/`：由 R `fixest::etable()` 直接导出的标准回归表。
- `Output/rebuild/figures/`：正式报告使用的图形。

## 数据目录

- `Data/processed/`：CPI、FRED 和其他价格/工资序列的清洗结果。
- `Data/rebuild/`：主样本实证面板和重建后的中间数据。
- `Data/extended/`：2010-2025 年扩展样本稳健性数据。
- `Data/analysis/`：早期分析面板和辅助数据。
- `Data/cleaned/`：BEA、BLS、Section 301 等基础清洗数据。

## 代码目录

- `src/10_rebuild_empirical_pipeline.py`：构造主样本数据、贸易品通胀暴露、产业网络暴露和汇总表。
- `src/11_rebuild_network_regressions.R`：估计主回归、Luo 式上游/下游模型、关税网络模型和价格-工资压力缺口模型。
- `src/12_rebuild_figures.R`：生成正式报告图形。
- `src/13_build_extended_sample.py`：构造 2010-2025 年扩展样本。
- `src/14_extended_sample_regressions.R`：估计扩展样本稳健性回归。

## 复现流程

从本目录运行：

```bash
python3 src/10_rebuild_empirical_pipeline.py
Rscript src/11_rebuild_network_regressions.R /Users/linian/Documents/论文初稿/price_compromise_project
Rscript src/12_rebuild_figures.R /Users/linian/Documents/论文初稿/price_compromise_project
python3 src/13_build_extended_sample.py
Rscript src/14_extended_sample_regressions.R /Users/linian/Documents/论文初稿/price_compromise_project
```

编译报告：

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

## 主要识别设计

主回归使用 BEA summary 行业年度面板，样本为 2017-2025 年、66 个行业。核心解释变量为 2019 年贸易品投入暴露与年度贸易品通胀率的交互项，并使用当期加一期滞后累计冲击。所有主模型包含行业固定效应和年份固定效应，标准误按行业聚类，基准规格使用行业总产出权重。

扩展样本覆盖 2010-2025 年，用于检验主结果是否依赖短样本窗口。该扩展样本仍使用 2019 年投入产出矩阵，因此定位为稳健性检验，而不是对整个 2010 年代网络结构的完整历史重建。
