#!/usr/bin/env python3
import numpy as np
import pandas as pd

from importlib import import_module

cfg = import_module("00_config")


def log(message: str) -> None:
    print(f"[03_construct_indices] {message}", flush=True)


def normalize_index(df: pd.DataFrame, value_col: str, base_year: int = cfg.BASE_YEAR) -> pd.DataFrame:
    base = (
        df.loc[df["year"] == base_year]
        .groupby("category", as_index=False)[value_col]
        .mean()
        .rename(columns={value_col: "base_value"})
    )
    out = df.merge(base, on="category", how="left")
    out["price_index_1984_100"] = out[value_col] / out["base_value"] * 100
    return out


def equal_weight_index(df: pd.DataFrame, categories: list[str], name: str) -> pd.DataFrame:
    return (
        df[df["category"].isin(categories)]
        .groupby("year", as_index=False)["price_index_1984_100"]
        .mean()
        .assign(index_name=name, weighting="equal")
        .rename(columns={"price_index_1984_100": "index_value"})
    )


def annual_inflation(df: pd.DataFrame, group_cols: list[str], value_col: str) -> pd.DataFrame:
    out = df.sort_values(group_cols + ["year"]).copy()
    if group_cols:
        out["inflation"] = out.groupby(group_cols)[value_col].pct_change() * 100
    else:
        out["inflation"] = out[value_col].pct_change() * 100
    return out


def construct_real_wages(indices: pd.DataFrame) -> pd.DataFrame:
    wage_path = cfg.DATA_PROCESSED / "fred_series_annual_clean.csv"
    if not wage_path.exists():
        log("FRED annual wage data missing; real wage file not produced.")
        return pd.DataFrame()
    fred = pd.read_csv(wage_path)
    wage = fred[fred["series"] == "avg_hourly_earnings_prod_nonsup"].copy()
    if wage.empty:
        log("Average hourly earnings series missing.")
        return pd.DataFrame()
    base = wage.loc[wage["year"] == cfg.BASE_YEAR, "value"].mean()
    wage["nominal_wage_index"] = wage["value"] / base * 100
    wide = indices.pivot_table(index="year", columns="index_name", values="index_value").reset_index()
    out = wage[["year", "nominal_wage_index"]].merge(wide, on="year", how="inner")
    if "CPIAllItems" in out:
        out["CPIRealWage"] = out["nominal_wage_index"] / out["CPIAllItems"] * 100
    if "CheapGoodsIndex" in out:
        out["CheapGoodsRealWage"] = out["nominal_wage_index"] / out["CheapGoodsIndex"] * 100
    if "BasicReproductionCostIndex" in out:
        out["ReproductionRealWage"] = out["nominal_wage_index"] / out["BasicReproductionCostIndex"] * 100
    return annual_inflation(out, [], "ReproductionRealWage") if "ReproductionRealWage" in out else out


def main() -> None:
    cfg.ensure_dirs()
    cpi_path = cfg.DATA_PROCESSED / "cpi_annual_clean.csv"
    if not cpi_path.exists():
        raise FileNotFoundError("Missing cpi_annual_clean.csv. Run 01 and 02 first.")

    cpi = pd.read_csv(cpi_path)
    cpi = normalize_index(cpi, "value", cfg.BASE_YEAR)
    cpi["label"] = cpi["category"].map(cfg.CATEGORY_LABELS).fillna(cpi["category"])
    cpi.to_csv(cfg.DATA_PROCESSED / "cpi_annual_normalized.csv", index=False)

    indices = pd.concat(
        [
            equal_weight_index(cpi, ["cpi_all"], "CPIAllItems"),
            equal_weight_index(cpi, cfg.CHEAP_GOODS_CATEGORIES, "CheapGoodsIndex"),
            equal_weight_index(cpi, cfg.LOCAL_REPRODUCTION_CATEGORIES, "LocalReproductionCostIndex"),
            equal_weight_index(cpi, cfg.BASIC_REPRODUCTION_CATEGORIES, "BasicReproductionCostIndex"),
        ],
        ignore_index=True,
    )
    indices = annual_inflation(indices, ["index_name", "weighting"], "index_value")
    indices.to_csv(cfg.DATA_PROCESSED / "constructed_price_indices.csv", index=False)

    real_wage = construct_real_wages(indices)
    if not real_wage.empty:
        real_wage.to_csv(cfg.DATA_PROCESSED / "real_wage_indices.csv", index=False)

    desc = indices.groupby("index_name").agg(
        first_year=("year", "min"),
        last_year=("year", "max"),
        mean_index=("index_value", "mean"),
        last_index=("index_value", "last"),
        mean_inflation=("inflation", "mean"),
    )
    desc.to_csv(cfg.OUTPUT_TABLES / "descriptive_statistics.csv")
    log("Constructed normalized CPI indices and descriptive statistics.")


if __name__ == "__main__":
    main()
