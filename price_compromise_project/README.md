# Price Compromise Project

This project studies the fragility of the price-based class compromise in the United States: low-price tradable goods partly buffered labor reproduction, but tariff war, supply-chain disruption, and rising local reproduction costs exposed the limits of this arrangement.

## Current Research Design

The current empirical strategy has two layers.

First, the project uses BLS CPI-U category prices to show the boundary of the cheap-goods channel:

- `CheapGoodsIndex`: tradable or globally organized consumer goods.
- `LocalReproductionCostIndex`: locally embedded reproduction costs such as shelter, rent, medical care, and education.
- `BasicReproductionCostIndex`: everyday reproduction costs such as shelter, food, energy, transportation, medical care, and education.

Second, the project uses Section 301 tariff exposure and the BEA 2019 input-output matrix to test whether tariff shocks propagate through industry networks into BEA gross-output and intermediate-input prices.

Real-wage figures are retained as background evidence only. The reproduction-cost real wage is defined as nominal wages deflated by the constructed `BasicReproductionCostIndex`; it is not treated as the main causal outcome.

## Main Draft

- Formal empirical chapter PDF: `Output/rebuild/reports/formal_empirical_chapter.pdf`
- Formal empirical chapter LaTeX: `Output/rebuild/reports/formal_empirical_chapter.tex`
- BibTeX references: `Output/rebuild/reports/empirical_references.bib`
- Rebuilt empirical report: `Output/rebuild/reports/rebuilt_empirical_report.md`

## Install

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

The scripts also work with an existing Anaconda/Python environment if the packages in `requirements.txt` are available.

On this machine, the tested interpreter was:

```bash
/opt/anaconda3/bin/python3
```

## Rebuild Current Results

From the project root:

```bash
/Users/linian/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 src/10_rebuild_empirical_pipeline.py
Rscript src/12_rebuild_figures.R /Users/linian/Documents/论文初稿/price_compromise_project
Rscript src/11_rebuild_network_regressions.R /Users/linian/Documents/论文初稿/price_compromise_project
```

Compile the formal empirical chapter:

```bash
cd Output/rebuild/reports
xelatex -interaction=nonstopmode formal_empirical_chapter.tex
bibtex formal_empirical_chapter
xelatex -interaction=nonstopmode formal_empirical_chapter.tex
xelatex -interaction=nonstopmode formal_empirical_chapter.tex
```

## Outputs

Current rebuilt figures:

- `Output/rebuild/figures/rebuild_fig1_index_divergence.png`
- `Output/rebuild/figures/rebuild_fig1b_reproduction_to_cheap_gap.png`
- `Output/rebuild/figures/rebuild_fig2_2025_category_levels.png`
- `Output/rebuild/figures/rebuild_fig3_inflation_shock_window.png`
- `Output/rebuild/figures/rebuild_fig4_cpi_301_exposure_by_class.png`
- `Output/rebuild/figures/rebuild_fig5_industry_direct_vs_network_exposure.png`

Current standard R regression tables:

- `Output/rebuild/regressions/rebuild_table1_industry_price_network_main.tex`
- `Output/rebuild/regressions/rebuild_table2_industry_price_network_robustness.tex`
- `Output/rebuild/regressions/rebuild_table3_weighting_robustness.tex`
- `Output/rebuild/regressions/rebuild_table4_event_study.tex`

## Manual Data

The first download script creates templates in `data/manual/`:

- `tariff_exposure.csv`: baseline category-level tariff exposure. Replace with product-level or import-weighted exposure when available.
- `cpi_to_bea_tariff_mapping.csv`: transparent mapping from CPI categories to BEA industry codes for importing Section 301 exposure from the old project.
- `cpi_to_naics_tariff_mapping.csv`: NAICS6 fallback mapping, currently used for apparel/textile categories not covered in the BEA summary exposure file.
- `import_dependence.csv`: baseline import-dependence or tradable dummy. Replace with category-level import shares if available.
- `labor_conflict_manual.csv`: optional manual labor-conflict supplement.

## Current Limitations

The CPI category indexes are equal-weighted research indexes rather than official statistical indicators. PCE or CEX weights, childcare/eldercare series, and BLS PPI industry prices should be added in the next empirical iteration. Section 301 exposure is imported from the old HTS8/NAICS/BEA project and mapped to CPI and BEA categories; these mappings should be manually reviewed before being treated as final publication-quality exposure measures.
