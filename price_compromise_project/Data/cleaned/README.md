# Cleaned data

Generated at 2026-06-27T17:02:56.500866+00:00

Notes:
- BEA IO cells marked `...` are coded as 0 in the cleaned use matrix.
- `bea_input_coefficients_2019.csv` uses commodity-by-industry use values divided by each industry's total intermediate inputs.
- `link_5pct` equals 1 when the input share is greater than 0.05.
- QCEW wage data use national private ownership (`own_code=5`).
- RTP tariff data are pre-existing Dataverse/Stata exposure variables, not a full 2018-2025 HTS tariff panel.

Files:
- `bea_gross_output_price_index_annual_2016_2025.csv`: 999 rows
- `bea_industry_output_2019.csv`: 71 rows
- `bea_input_coefficients_2019.csv`: 5183 rows
- `bea_intermediate_inputs_price_index_annual_2016_2025.csv`: 999 rows
- `bea_naics_concordance_clean.csv`: 505 rows
- `bea_use_summary_2019_long.csv`: 5183 rows
- `bls_ces_wages_annual_2016_2025.csv`: 380 rows
- `bls_ces_wages_monthly_clean.csv`: 4560 rows
- `bls_qcew_private_industry_wages_annual_2016_2025.csv`: 21275 rows
- `rtp_tariffs_naics_clean.csv`: 686 rows
- `ustr_301_links_clean.csv`: 156 rows
