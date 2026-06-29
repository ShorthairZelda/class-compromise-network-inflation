#!/usr/bin/env python3
import pandas as pd
import numpy as np
from math import erfc, sqrt

try:
    import statsmodels.formula.api as smf
except Exception:
    smf = None

from importlib import import_module

cfg = import_module("00_config")


def log(message: str) -> None:
    print(f"[05_regression_analysis] {message}", flush=True)


def normal_pvalue(t_value: float) -> float:
    return erfc(abs(t_value) / sqrt(2))


def fit_ols_fallback(data: pd.DataFrame, y_col: str, x_cols: list[str], fe_cols: list[str]) -> pd.DataFrame:
    use = data[[y_col] + x_cols + fe_cols].dropna().copy()
    x = use[x_cols].astype(float)
    for fe in fe_cols:
        dummies = pd.get_dummies(use[fe].astype(str), prefix=fe, drop_first=True, dtype=float)
        x = pd.concat([x, dummies], axis=1)
    x.insert(0, "Intercept", 1.0)
    y = use[y_col].astype(float).to_numpy()
    x_mat = x.to_numpy(dtype=float)
    beta, _, _, _ = np.linalg.lstsq(x_mat, y, rcond=None)
    resid = y - x_mat @ beta
    n, k = x_mat.shape
    sigma2 = float((resid @ resid) / max(n - k, 1))
    xtx_inv = np.linalg.pinv(x_mat.T @ x_mat)
    se = np.sqrt(np.diag(sigma2 * xtx_inv))
    t_values = beta / se
    out = pd.DataFrame(
        {
            "term": x.columns,
            "estimate": beta,
            "std_error": se,
            "t_value": t_values,
            "p_value": [normal_pvalue(t) for t in t_values],
        }
    )
    return out[out["term"].isin(["Intercept"] + x_cols)].reset_index(drop=True)


def save_fallback(params: pd.DataFrame, name: str, note: str) -> None:
    txt_path = cfg.OUTPUT_REGRESSIONS / f"{name}.txt"
    tex_path = cfg.OUTPUT_REGRESSIONS / f"{name}.tex"
    csv_path = cfg.OUTPUT_REGRESSIONS / f"{name}.csv"
    params.to_csv(csv_path, index=False)
    txt_path.write_text(note + "\n\n" + params.to_string(index=False), encoding="utf-8")
    tex_path.write_text(params.to_latex(index=False, float_format="%.4f"), encoding="utf-8")
    log(f"Saved fallback regression outputs for {name}.")


def save_model(model, name: str) -> None:
    txt_path = cfg.OUTPUT_REGRESSIONS / f"{name}.txt"
    tex_path = cfg.OUTPUT_REGRESSIONS / f"{name}.tex"
    csv_path = cfg.OUTPUT_REGRESSIONS / f"{name}.csv"
    txt_path.write_text(model.summary().as_text(), encoding="utf-8")
    tex_path.write_text(model.summary().as_latex(), encoding="utf-8")
    params = pd.DataFrame(
        {
            "term": model.params.index,
            "estimate": model.params.values,
            "std_error": model.bse.values,
            "t_value": model.tvalues.values,
            "p_value": model.pvalues.values,
        }
    )
    params.to_csv(csv_path, index=False)
    log(f"Saved regression outputs for {name}.")


def category_panel() -> pd.DataFrame:
    cpi = pd.read_csv(cfg.DATA_PROCESSED / "cpi_annual_normalized.csv")
    cpi = cpi.sort_values(["category", "year"])
    cpi["delta_price"] = cpi.groupby("category")["price_index_1984_100"].pct_change(fill_method=None) * 100
    tariff = pd.read_csv(cfg.DATA_MANUAL / "tariff_exposure.csv")
    imports = pd.read_csv(cfg.DATA_MANUAL / "import_dependence.csv")
    panel = cpi.merge(tariff[["category", "tariff_exposure"]], on="category", how="left")
    panel = panel.merge(imports[["category", "import_dependence", "tradable"]], on="category", how="left")
    exposure_path = cfg.DATA_PROCESSED / "cpi_category_301_tariff_exposure.csv"
    if exposure_path.exists():
        exposure = pd.read_csv(exposure_path)
        panel = panel.merge(
            exposure[["category", "year", "tariff_301_rate", "tariff_301_rate_post2018", "matched_industries"]],
            on=["category", "year"],
            how="left",
        )
    else:
        panel["tariff_301_rate"] = pd.NA
        panel["tariff_301_rate_post2018"] = pd.NA
        panel["matched_industries"] = pd.NA
    panel["post2018"] = (panel["year"] >= 2018).astype(int)
    return panel


def regression_tariff_exposure(panel: pd.DataFrame) -> None:
    if panel["tariff_301_rate"].notna().any():
        data = panel.loc[panel["year"] >= 2016].dropna(subset=["delta_price", "tariff_301_rate"]).copy()
        treatment = "tariff_301_rate"
        note = "Section 301 exposure imported from old BEA/NAICS/HTS8 project, mapped to CPI categories."
    else:
        data = panel.dropna(subset=["delta_price", "tariff_exposure"]).copy()
        data = data.assign(tariff_x_post2018=data["tariff_exposure"] * data["post2018"])
        treatment = "tariff_x_post2018"
        note = "Fallback heuristic tariff exposure dummy interacted with post-2018."
    if smf is not None:
        model = smf.ols(
            f"delta_price ~ {treatment} + C(category) + C(year)",
            data=data,
        ).fit(cov_type="HC1")
        save_model(model, "regression_tariff_exposure")
    else:
        params = fit_ols_fallback(data, "delta_price", [treatment], ["category", "year"])
        save_fallback(params, "regression_tariff_exposure", f"Fallback OLS with category and year fixed effects. {note}")


def regression_supply_chain(panel: pd.DataFrame) -> None:
    fred = pd.read_csv(cfg.DATA_PROCESSED / "fred_series_annual_clean.csv")
    shock = pd.DataFrame()
    for candidate in [
        "global_supply_chain_pressure",
        "import_price_index_all",
        "transportation_warehousing_ppi",
    ]:
        shock = fred[fred["series"] == candidate][["year", "value"]].rename(
            columns={"value": "supply_chain_shock"}
        )
        if not shock.empty:
            log(f"Using {candidate} as supply-chain/import-cost proxy.")
            break
    data = panel.merge(shock, on="year", how="inner").dropna(subset=["delta_price", "tradable", "supply_chain_shock"])
    if data.empty:
        log("Supply chain shock data missing; skipping regression_supply_chain.")
        return
    data = data.assign(tradable_x_supply_chain=data["tradable"] * data["supply_chain_shock"])
    if smf is not None:
        model = smf.ols(
            "delta_price ~ tradable_x_supply_chain + C(category) + C(year)",
            data=data,
        ).fit(cov_type="HC1")
        save_model(model, "regression_supply_chain")
    else:
        params = fit_ols_fallback(data, "delta_price", ["tradable_x_supply_chain"], ["category", "year"])
        save_fallback(params, "regression_supply_chain", "Fallback OLS with category and year fixed effects.")


def regression_real_wage() -> None:
    indices = pd.read_csv(cfg.DATA_PROCESSED / "constructed_price_indices.csv")
    wage_path = cfg.DATA_PROCESSED / "real_wage_indices.csv"
    if not wage_path.exists():
        log("Real wage indices missing; skipping regression_real_wage.")
        return
    wide = indices.pivot_table(index="year", columns="index_name", values="inflation").reset_index()
    wide = wide.rename(
        columns={
            "BasicReproductionCostIndex": "basic_reproduction_inflation",
            "CheapGoodsIndex": "cheap_goods_inflation",
        }
    )
    wages = pd.read_csv(wage_path).sort_values("year")
    wages["delta_reproduction_real_wage"] = wages["ReproductionRealWage"].pct_change() * 100
    data = wages.merge(wide, on="year", how="inner").dropna(
        subset=["delta_reproduction_real_wage", "basic_reproduction_inflation", "cheap_goods_inflation"]
    )
    if smf is not None:
        model = smf.ols(
            "delta_reproduction_real_wage ~ basic_reproduction_inflation + cheap_goods_inflation",
            data=data,
        ).fit(cov_type="HC1")
        save_model(model, "regression_real_wage")
    else:
        params = fit_ols_fallback(
            data,
            "delta_reproduction_real_wage",
            ["basic_reproduction_inflation", "cheap_goods_inflation"],
            [],
        )
        save_fallback(params, "regression_real_wage", "Fallback OLS without additional controls.")


def main() -> None:
    cfg.ensure_dirs()
    panel = category_panel()
    panel.to_csv(cfg.DATA_PROCESSED / "category_price_regression_panel.csv", index=False)
    regression_tariff_exposure(panel)
    regression_supply_chain(panel)
    regression_real_wage()


if __name__ == "__main__":
    main()
