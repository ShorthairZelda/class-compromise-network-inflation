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
    print(f"[06_labor_conflict_analysis] {message}", flush=True)


def normal_pvalue(t_value: float) -> float:
    return erfc(abs(t_value) / sqrt(2))


def fallback_ols(data: pd.DataFrame, y_col: str, x_cols: list[str]) -> pd.DataFrame:
    use = data[[y_col] + x_cols].dropna().copy()
    x = use[x_cols].astype(float)
    x.insert(0, "Intercept", 1.0)
    y = use[y_col].astype(float).to_numpy()
    x_mat = x.to_numpy(dtype=float)
    beta, _, _, _ = np.linalg.lstsq(x_mat, y, rcond=None)
    resid = y - x_mat @ beta
    n, k = x_mat.shape
    sigma2 = float((resid @ resid) / max(n - k, 1))
    se = np.sqrt(np.diag(sigma2 * np.linalg.pinv(x_mat.T @ x_mat)))
    t_values = beta / se
    return pd.DataFrame(
        {
            "term": x.columns,
            "estimate": beta,
            "std_error": se,
            "t_value": t_values,
            "p_value": [normal_pvalue(t) for t in t_values],
        }
    )


def main() -> None:
    cfg.ensure_dirs()
    out = cfg.OUTPUT_REGRESSIONS / "regression_labor_conflict.txt"
    if out.exists():
        out.unlink()
    indices_path = cfg.DATA_PROCESSED / "constructed_price_indices.csv"
    wage_path = cfg.DATA_PROCESSED / "real_wage_indices.csv"
    if not indices_path.exists() or not wage_path.exists():
        log("Required indices missing; skipping labor conflict analysis.")
        return

    indices = pd.read_csv(indices_path)
    basic = indices[indices["index_name"] == "BasicReproductionCostIndex"][
        ["year", "inflation"]
    ].rename(columns={"inflation": "basic_reproduction_inflation"})
    wage = pd.read_csv(wage_path).sort_values("year")
    wage["reproduction_real_wage_growth"] = wage["ReproductionRealWage"].pct_change() * 100

    fred_path = cfg.DATA_PROCESSED / "fred_series_annual_clean.csv"
    frames = []
    if fred_path.exists():
        fred = pd.read_csv(fred_path)
        for series in ["quits_rate", "consumer_sentiment", "delinquency_rate"]:
            temp = fred[fred["series"] == series][["year", "value"]].rename(columns={"value": series})
            frames.append(temp)

    manual = cfg.DATA_MANUAL / "labor_conflict_manual.csv"
    if manual.exists():
        frames.append(pd.read_csv(manual))

    if not frames:
        log("No labor conflict data available.")
        return

    data = basic.merge(wage[["year", "reproduction_real_wage_growth"]], on="year", how="left")
    for frame in frames:
        data = data.merge(frame, on="year", how="left")
    data.to_csv(cfg.DATA_PROCESSED / "labor_conflict_panel.csv", index=False)

    for outcome in ["quits_rate", "consumer_sentiment", "delinquency_rate", "work_stoppages"]:
        if outcome not in data or data[outcome].dropna().shape[0] < 10:
            continue
        reg = data.dropna(subset=[outcome, "basic_reproduction_inflation", "reproduction_real_wage_growth"])
        if reg.shape[0] < 10:
            continue
        with out.open("a", encoding="utf-8") as handle:
            handle.write(f"\n\nOutcome: {outcome}\n")
            if smf is not None:
                model = smf.ols(
                    f"{outcome} ~ basic_reproduction_inflation + reproduction_real_wage_growth",
                    data=reg,
                ).fit(cov_type="HC1")
                handle.write(model.summary().as_text())
            else:
                params = fallback_ols(
                    reg,
                    outcome,
                    ["basic_reproduction_inflation", "reproduction_real_wage_growth"],
                )
                handle.write("Fallback OLS without HC robust covariance.\n")
                handle.write(params.to_string(index=False))
        log(f"Saved labor conflict regression for {outcome}.")


if __name__ == "__main__":
    main()
