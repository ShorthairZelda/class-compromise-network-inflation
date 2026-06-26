# Price-Driven Class Compromise and Network Inflation (2015-2025)

This repository contains the empirical code, data, and reports for the research project investigating **"Price-Driven Class Compromise and Network Inflation"**.

## Project Overview

The project models and empirically tests how external trade tariff shocks (Shift) propagate through the U.S. inter-industry network (Share) to affect labor reproduction costs (non-tradable services) under a wage-squeeze regime. We employ **Acemoglu's (2012) network theory** and a **Shift-Share (Bartik) panel regression design** using 100% real U.S. economic data from 2015 to 2025.

### Key Data Sources:
- **BEA 2023 Summary Use Table** (71 sectors) for network structure.
- **BLS CPI Monthly Data (2015-2025)** for inflation trends.
- **U.S. Section 301 Tariff Schedule** for time-varying macroeconomic shocks.

---

## Repository Structure

- `代码/` (Code and Report Source):
  - `scripts/`:
    - `01_network_estimation.R`: Network centrality calculation, tradability classification, OLS & Newey-West HAC regressions.
    - `02_generate_figures.R`: Monthly CPI inflation trend visualization.
    - `03_network_graph.R`: Network visualization based on Acemoglu's 5% threshold.
  - `data/`: Raw and processed BEA & BLS data.
  - `figures/`: Output vector graphics of figures.
  - `experimental_report.tex`: XeLaTeX source code of the report.
  - `experimental_report.pdf`: Compiled XeLaTeX report document.
- `experimental_report.md`: Markdown version of the empirical report.
- `technical_details.md`: Rigorous technical documentation explaining every variable, mathematical definition, and econometric result.

---

## Empirical Findings

Our panel regression identifies a negative coefficient of **-0.7719** ($t = -4.046$, highly significant under OLS) for the interaction term `Labor_Reproduction_Shock` (Downstream Centrality $\times$ Tariff Shift). 

This negative sign reveals the **"Real Wage Squeeze"** phenomenon in the neo-liberal era:
1. **Inflation Lag**: Commodity (tradable) price inflation surged rapidly in 2021-2022, while non-tradable services (rent, medical care) lagged behind due to contract stickiness.
2. **Wage-Squeeze Blockage**: Although external shocks increased labor reproduction costs, workers lacked the bargaining power to index wages. Consequently, the cost-push transmission channel from wages to service prices was blocked, leading to a squeeze on real wages rather than a domestic cost-push wage-price spiral.
3. **Autocorrelation Warning**: Correcting for autocorrelation using **Newey-West HAC robust standard errors** expands the standard error to $1.0194$ ($t = -0.757$, not statistically significant), signaling strong serial correlation in monthly macroeconomic CPI time-series.

---

## How to Run

### Prerequisites
- **R** with libraries: `dplyr`, `tidyr`, `sandwich`, `lmtest`, `igraph`, `ggplot2`
- **XeLaTeX** for report compilation.

### Steps
1. Navigate to the `代码/` directory.
2. Execute the network estimation and regression script:
   ```bash
   Rscript scripts/01_network_estimation.R
   ```
3. Generate network and trend visualizations:
   ```bash
   Rscript scripts/02_generate_figures.R
   Rscript scripts/03_network_graph.R
   ```
4. Compile the LaTeX report:
   ```bash
   xelatex -interaction=nonstopmode experimental_report.tex
   ```
