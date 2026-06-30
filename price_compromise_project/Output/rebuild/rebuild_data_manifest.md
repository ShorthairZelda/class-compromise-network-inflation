# Rebuilt Empirical Data Manifest

This rebuild keeps the CPI descriptive evidence separate from the industry network price-transmission evidence.

## Inputs

- CPI category panel: `/Users/linian/Documents/论文初稿/price_compromise_project/data/processed/cpi_annual_normalized.csv`
- Constructed CPI indexes: `/Users/linian/Documents/论文初稿/price_compromise_project/data/processed/constructed_price_indices.csv`
- CPI Section 301 exposure: `/Users/linian/Documents/论文初稿/price_compromise_project/data/processed/cpi_category_301_tariff_exposure.csv`
- BEA annual industry panel: `/Users/linian/Desktop/PROJ_completed/proj_class_compromise/Data/analysis/analysis_panel_bea_summary_2016_2025_prelim.csv`
- Luo-style own/upstream/downstream shocks: `/Users/linian/Desktop/PROJ_completed/proj_class_compromise/Data/analysis/luo_style_own_up_down_tariff_shocks_2016_2025.csv`
- BEA 2019 input coefficients: `/Users/linian/Desktop/PROJ_completed/proj_class_compromise/Data/cleaned/bea_input_coefficients_2019.csv`
- Tradable/nontradable CPI inflation proxy: `/Users/linian/Documents/论文初稿/price_compromise_project/Data/analysis/us_tradable_nontradable_inflation_annual_2015_2025.csv`

## Methodological choices

- CPI indexes are used as descriptive boundary evidence, not as the main causal design.
- Industry price regressions use BEA gross-output and intermediate-input price indexes as PPI-like industry price outcomes.
- The preferred shock is an exposure-share design: 2019 tradable-goods input exposure interacted with annual tradable-goods inflation.
- Section 301 tariff exposure is retained as a policy-shock robustness design rather than the only explanation for the 2021-2022 inflation surge.
- Reproduction-cost real wage regressions are deliberately excluded from the rebuilt main empirical design.