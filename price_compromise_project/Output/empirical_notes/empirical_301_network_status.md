# 301 tariff network empirical status

Updated: 2026-06-28

## Research question

The current empirical design tests whether Section 301 tariff shocks propagate through the 2019 BEA input-output network and weaken the price-based class compromise mechanism. The intended chain is:

1. Tariff shock raises upstream/input price pressure.
2. Input-output linkages transmit the shock beyond directly tariffed industries.
3. Nominal wages do not fully offset the price increase.
4. Real wages/social reproduction conditions deteriorate, especially after the post-2021 inflation regime shift.

## Data construction

- Industry network: 2019 BEA input-output table.
- Panel years: 2016-2025.
- Direct tariff shock: cleaned USTR Section 301 HTS8 core lists, annualized to industry-year exposure.
- HTS8-to-NAICS weights: 2017 China import values from the RTP replication import-flow file.
- BEA aggregation: NAICS exposure is import-weighted into BEA summary industries.
- Network shock: `network_tariff_shock_i,t = sum_j input_share_ij,2019 * tariff_301_j,t`.
- PCE real wage: QCEW annual pay deflated by annual-average FRED/BEA PCEPI, 2017=100.

Key outputs:

- `Data/cleaned/ustr_301_naics_exposure_annual.csv`
- `Data/analysis/bea_summary_tariff_exposure_301_clean.csv`
- `Data/analysis/analysis_panel_bea_summary_2016_2025_prelim.csv`
- `Output/tables/twfe_main_etable.txt`
- `Output/tables/twfe_main_coefficients.csv`
- `Output/tables/twfe_mechanism_etable.txt`
- `Output/tables/twfe_robustness_price_etable.txt`
- `Output/tables/twfe_robustness_realwage_etable.txt`

## Current main TWFE results

All models include BEA summary industry fixed effects and year fixed effects. Standard errors are clustered by industry.

- Price mechanism: current network shock is positive and marginally significant.
  - `network_tariff_shock`: coefficient about 0.111, p about 0.080.
- Price mechanism with persistence: current plus one-year lag network shock is positive and significant.
  - `network_tariff_shock_cum01`: coefficient about 0.064, p about 0.024.
- Intermediate input prices show an even stronger mechanism result.
  - `network_tariff_shock_cum01`: coefficient about 0.072, p about 0.004.
- Nominal wages: cumulative network shock is small and not significant.
  - This supports the interpretation that wages do not fully compensate for the price shock.
- Real wages: coefficients are negative, but not yet conventionally significant.
  - Current shock: coefficient about -0.120, p about 0.116.
  - Current plus one-year lag: coefficient about -0.057, p about 0.101.
- PCE real wages: coefficients are not larger in absolute value under the current TWFE specification.
  - Current shock: coefficient about 0.009, p about 0.829.
  - Current plus one-year lag: coefficient about 0.017, p about 0.428.
  - Because PCEPI varies only by year, year fixed effects absorb the national inflation component; PCE-deflated wage coefficients are algebraically equivalent to nominal wage coefficients when samples match.
- Post-2021 interaction: currently not statistically clear.

## Robustness results

- Direct tariff exposure is not significant for prices or real wages.
  - This suggests that the empirical signal is not simply a direct tariffed-industry effect.
- Full IO network exposure is significant for gross output prices.
  - Price coefficient about 0.064, p about 0.024.
- 5 percent IO-link exposure is also significant for gross output prices.
  - Price coefficient about 0.064, p about 0.021.
- Excluding own-industry links weakens the price result but keeps the coefficient positive.
  - Coefficient about 0.089, p about 0.110.
- Real wage effects remain weaker, but the 5 percent IO-link specification is negative and marginally significant.
  - Coefficient about -0.063, p about 0.069.

## Interpretation for the paper

The strongest current evidence is for the price-transmission mechanism: network tariff exposure predicts higher BEA gross output price growth and higher intermediate input price growth, especially when allowing one-year persistence. The fact that direct tariff exposure is weak while network exposure is stronger supports the IO propagation interpretation. The wage results are directionally consistent with the theory but weaker statistically. This suggests the empirical section should present price transmission and lack of wage compensation as the main empirical findings, with real wage compression as suggestive evidence.

## Current limitations

- Product exclusions and firm-specific tariff exclusions are not yet incorporated.
- Annual rates are approximated by active months rather than exact daily exposure.
- HTS8-to-NAICS weights use 2017 China import values as fixed pre-shock weights.
- BEA summary industry panel is small: 66 industries over 10 years.
- QCEW wage mapping drops ambiguous NAICS code `531`, creating some wage missingness.

## Next steps

1. Convert the mechanism and robustness outputs into paper-ready tables.
2. Test cumulative effects with alternative windows.
3. Consider outcome alternatives: CPI/PCE-relevant consumption sectors or lower-level NAICS wage panels.
4. Decide whether product exclusions need to be incorporated before treating this as final main empirical evidence.
