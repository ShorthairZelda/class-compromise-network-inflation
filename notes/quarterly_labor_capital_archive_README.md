# Quarterly Labor/Capital Heterogeneity Archive

Archived from `proj_class_compromise_quarterly/代码` into the original project.

## Purpose

This archive preserves the useful quarterly empirical extension and the labor/capital intensity heterogeneity results. The key finding is that network tariff shocks compress real weekly wages more strongly in labor-intensive industries.

## Key Result

The preferred interaction model is:

`RealWage_it = beta NetworkShock_it + gamma NetworkShock_it x HighLabor_i + industry FE + year-quarter FE + error_it`

Using 2019 labor share, where high-labor industries are above the median:

- Capital-intensive / low labor-share effect: about `-0.052`, not statistically significant.
- Labor-intensive / high labor-share total effect: about `-0.153`, significant at the 5% level in the common year-quarter FE specification.
- Difference between labor-intensive and capital-intensive industries: about `-0.101`, significant at the 10% level.

The result is directionally consistent across alternative checks, but its interpretation should be cautious: the strongest evidence is the total effect for high-labor industries, while the difference between groups is weaker and depends on the fixed-effect specification.

## Archived Contents

- `Data/analysis/analysis_panel_bea_summary_2016_2025_quarterly.csv`: quarterly BEA summary industry analysis panel.
- `Data/cleaned/*quarterly*.csv`: cleaned quarterly price, wage, and PCE data used to build the panel.
- `Data/scripts/01_build_analysis_panel.R`: quarterly panel construction script.
- `Data/scripts/02_run_twfe_models.R`: main quarterly TWFE and heterogeneity script.
- `Data/scripts/10_check_labor_capital_heterogeneity.R`: reproducibility script for split regressions, interaction linear combinations, and alternative labor-share checks.
- `Output/tables/twfe_heterogeneity_etable.txt`: original heterogeneity table.
- `Output/tables/twfe_heterogeneity_coefficients.csv`: original heterogeneity coefficients.
- `Output/tables/twfe_heterogeneity_lincom_realwage.csv`: linear-combination results showing the total real-wage effect for labor-intensive industries.
- `Output/tables/twfe_heterogeneity_check_split_and_lincom.txt`: split regression and linear-combination diagnostics.
- `Output/tables/twfe_heterogeneity_check_alternative_fe_labor_share.txt`: alternative checks using group-time FE and value-added labor share.

## Important Caveats

1. The saved table in `twfe_heterogeneity_etable.txt` is an interaction model, not simply two separate subsample regressions. The high-labor total effect must be computed as `network_tariff_shock_cum01 + network_x_high_labor`.
2. The group definition uses 2019 labor share. This is fixed and predetermined relative to much of the shock period, but the paper should describe it explicitly.
3. If using the `update_labor_share.py` script, verify the project path before rerunning. The archived quarterly panel already contains `labor_share_2019`.
4. The result should be framed as heterogeneity evidence supporting the mechanism, not as the sole main result.
