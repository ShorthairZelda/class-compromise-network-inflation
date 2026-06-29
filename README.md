# 价格型阶级妥协实证项目

本仓库用于与导师共同查看和编辑实证项目：

**价格型阶级妥协的脆弱性：低价商品供给、关税战、供应链冲击与美国劳动者再生产压力**

## 主要入口

- 正式实证章节 PDF：`price_compromise_project/Output/rebuild/reports/formal_empirical_chapter.pdf`
- 正式实证章节 LaTeX：`price_compromise_project/Output/rebuild/reports/formal_empirical_chapter.tex`
- 论文引用 BibTeX：`price_compromise_project/Output/rebuild/reports/empirical_references.bib`
- 最新中文实证报告 Markdown：`price_compromise_project/Output/rebuild/reports/rebuilt_empirical_report.md`

## 最新实证路线

当前版本不再把“再生产成本平减后的实际工资回归”作为主因果识别，而是采用两层证据：

1. CPI 分类价格描述事实：低价供给主要集中在可贸易消费品和全球供应链商品，住房、医疗、教育等本地化再生产成本没有被同样压低。
2. Section 301 关税与 BEA 投入产出网络主实证：当低价供给渠道受到关税战和供应链冲击时，价格压力会通过产业网络进入行业总产出价格和中间投入价格。

工资图作为背景事实保留在正式稿中，并明确标注平减口径：

- 名义工资指数：FRED 生产和非管理工人平均小时工资，1984=100。
- CPI 平减实际工资：名义工资指数除以 BLS CPI-U All Items。
- 再生产成本平减实际工资：名义工资指数除以本文构造的基本再生产成本指数。该指数由住房、食品、能源、交通、医疗、教育与通信等 CPI 子项标准化后等权平均得到，不是官方统计指标。

## 重要代码

- 数据和表格重建：`price_compromise_project/src/10_rebuild_empirical_pipeline.py`
- R/fixest 网络回归表：`price_compromise_project/src/11_rebuild_network_regressions.R`
- R/ggplot 图形：`price_compromise_project/src/12_rebuild_figures.R`

## 复现最新结果

从仓库根目录进入项目：

```bash
cd price_compromise_project
```

重建数据和汇总表：

```bash
/Users/linian/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 src/10_rebuild_empirical_pipeline.py
```

生成图形：

```bash
Rscript src/12_rebuild_figures.R /Users/linian/Documents/论文初稿/price_compromise_project
```

生成标准 R 回归表：

```bash
Rscript src/11_rebuild_network_regressions.R /Users/linian/Documents/论文初稿/price_compromise_project
```

编译正式实证章节：

```bash
cd Output/rebuild/reports
xelatex -interaction=nonstopmode formal_empirical_chapter.tex
bibtex formal_empirical_chapter
xelatex -interaction=nonstopmode formal_empirical_chapter.tex
xelatex -interaction=nonstopmode formal_empirical_chapter.tex
```

## 数据说明

仓库保留了项目内已清洗和重建的数据，便于导师直接复核表格和图形。根目录 `data/bea/raw/*.zip` 等较大的原始下载文件默认不纳入 Git，可根据需要重新下载或通过云盘单独共享。
