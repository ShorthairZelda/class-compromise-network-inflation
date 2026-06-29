# Variable Dictionary

| Variable | Meaning | Source | Frequency | Unit | Processing |
|---|---|---|---|---|---|
| `category` | CPI category name used in this project | BLS CPI-U | Monthly/annual | Text | Mapped from BLS series IDs |
| `value` | Raw price or economic indicator value | BLS/FRED | Monthly/quarterly/annual | Index or rate | Parsed as numeric |
| `price_index_1984_100` | Category price index normalized to 1984 | BLS CPI-U | Annual | 1984=100 | Annual mean divided by 1984 annual mean |
| `CheapGoodsIndex` | Low-price tradable goods composite index | BLS CPI-U | Annual | 1984=100 | Equal-weighted mean of cheap-goods categories |
| `LocalReproductionCostIndex` | Locally embedded reproduction-cost index | BLS CPI-U | Annual | 1984=100 | Equal-weighted mean of shelter, rent, medical, education |
| `BasicReproductionCostIndex` | Rigid reproduction-cost index | BLS CPI-U | Annual | 1984=100 | Equal-weighted mean of shelter, food, energy, transport, medical, education |
| `inflation` | Annual inflation rate | Constructed | Annual | Percent | Percent change in index |
| `nominal_wage_index` | Nominal wage index | FRED/BLS | Annual | 1984=100 | Average hourly earnings normalized to 1984 |
| `CPIRealWage` | CPI-deflated real wage | FRED/BLS + BLS CPI | Annual | Index | Nominal wage index divided by CPI index |
| `CheapGoodsRealWage` | Cheap-goods deflated wage | Constructed | Annual | Index | Nominal wage index divided by CheapGoodsIndex |
| `ReproductionRealWage` | Reproduction-cost deflated wage | Constructed | Annual | Index | Nominal wage index divided by BasicReproductionCostIndex |
| `tariff_exposure` | Category-level tariff-war exposure | Manual template | Category | 0/1 or continuous | Baseline heuristic; replace with product-level exposure |
| `tariff_301_rate` | CPI-category annual Section 301 tariff exposure | Old 301 project + CPI-BEA/NAICS mapping | Annual | Ad valorem rate | Import-weighted BEA industry exposure, with NAICS fallback for apparel |
| `matched_industries` | Number of BEA industries or NAICS6 industries used in CPI-category tariff mapping | Constructed | Annual | Count | Used to diagnose mapping coverage |
| `exposure_source` | Source of CPI-category tariff exposure | Constructed | Annual | Text | BEA summary mapping, NAICS6 fallback, or no match |
| `post2018` | Tariff-war period indicator | Constructed | Annual | 0/1 | 1 for year >= 2018 |
| `import_dependence` | Category-level import dependence | Manual template | Category | 0/1 or share | Baseline tradable dummy; replace with import share |
| `tradable` | Tradable-goods category dummy | Manual template | Category | 0/1 | 1 for cheap-goods categories |
| `supply_chain_shock` | Supply-chain pressure | FRED GSCPI | Monthly/annual | Index | Annual mean of monthly GSCPI |
| `quits_rate` | Labor market quits rate | FRED JTSQUR | Monthly/annual | Percent | Annual mean |
| `consumer_sentiment` | Consumer sentiment | FRED UMCSENT | Monthly/annual | Index | Annual mean |
| `delinquency_rate` | Household financial stress proxy | FRED | Quarterly/annual | Percent | Annual mean |
| `work_stoppages` | Strike/work-stoppage count | Manual/BLS | Annual | Count | Optional manual supplement |
