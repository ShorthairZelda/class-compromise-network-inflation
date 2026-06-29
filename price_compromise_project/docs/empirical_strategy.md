# Empirical Strategy

## 1. Research Question

This project asks whether the neoliberal stabilization of US labor reproduction relied partly on a price-based class compromise: stagnant wages and weakened welfare provision were buffered by cheap tradable goods, low-cost logistics, and global supply chains. It then asks whether tariff war and supply-chain disruption exposed the fragility of this compromise.

## 2. Theoretical Mechanism

The argument has four steps.

First, low-cost global production and retail distribution held down prices for many tradable consumer goods. Second, this cheap-goods channel partially compensated for weak wage growth and declining collective bargaining power. Third, the mechanism was partial because core reproduction costs such as housing, medical care, education, childcare, energy, and transportation are locally embedded or institutionally mediated. Fourth, tariff war and pandemic-era supply-chain disruptions weakened the cheap-goods channel and made the underlying reproduction-cost crisis more visible.

## 3. Hypotheses

H1: Since the 1980s, prices of tradable cheap goods have grown more slowly than CPI/PCE and local reproduction costs.

H2: Tariff war and supply-chain disruptions increased prices in tariff-exposed or tradable/import-dependent categories after 2018 and 2020.

H3: Reproduction-cost real wages decline more sharply than CPI real wages when basic reproduction costs rise.

H4: Higher reproduction-cost inflation and weaker reproduction real wages are associated with labor-market or labor-conflict stress indicators.

## 4. Data Sources

The baseline project uses:

- BLS CPI-U category price indices.
- FRED wage, supply-chain, sentiment, quits, and delinquency series.
- Manual templates for tariff exposure, import dependence, and labor-conflict supplements.

Future extensions should add BEA detailed PCE price indices and consumption weights.

## 5. Variable Definitions

`CheapGoodsIndex` is an equal-weighted index of durable goods, apparel, household furnishings, vehicles, and recreation-related goods.

`LocalReproductionCostIndex` is an equal-weighted index of shelter, rent, medical care, and education/communication.

`BasicReproductionCostIndex` is an equal-weighted index of shelter, food, energy, transportation, medical care, and education/communication.

`ReproductionRealWage` is the nominal wage index divided by `BasicReproductionCostIndex`.

## 6. Index Construction

All CPI category series are annualized by taking the mean of monthly observations. Each category is normalized to 1984 = 100:

```text
Index_it = Price_it / Price_i,1984 * 100
```

Composite indices are initially constructed using equal weights:

```text
CompositeIndex_t = average(Index_it for i in category group)
```

The next version should add PCE-consumption-weighted indices.

## 7. Identification Strategy

Regression 1 estimates whether tariff-exposed categories had higher inflation after 2018:

```text
DeltaPrice_it = beta * TariffExposure_i * Post2018_t + category FE + year FE + error_it
```

Regression 2 estimates whether tradable or import-dependent categories responded more strongly to supply-chain pressure:

```text
DeltaPrice_it = beta * Tradable_i * SupplyChainShock_t + category FE + year FE + error_it
```

Regression 3 estimates whether reproduction-cost inflation erodes reproduction real wages:

```text
DeltaReproductionRealWage_t =
    beta1 * BasicReproductionCostInflation_t
  + beta2 * CheapGoodsInflation_t
  + error_t
```

Regression 4 explores labor conflict or stress:

```text
LaborConflict_t =
    beta1 * BasicReproductionCostInflation_t
  + beta2 * ReproductionRealWageGrowth_t
  + error_t
```

## 8. Potential Problems and Robustness

The baseline tariff exposure variable is heuristic until product-level exposure is imported. Equal weights are a first approximation and should be replaced or supplemented with PCE weights. Some labor-conflict outcomes are annual and sparse, so they should be interpreted as exploratory.

Planned robustness checks:

- CPI versus PCE price indices.
- Equal weights versus consumption weights.
- Base year 1984 versus 1990.
- Excluding energy.
- Excluding housing.
- Separate 2018 tariff and 2020 pandemic shock windows.
- Long-run 1984-2019 and crisis-period 2016-2025 samples.
- Monthly versus annual estimates.
