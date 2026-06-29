#!/usr/bin/env python3
import json

import pandas as pd

from importlib import import_module

cfg = import_module("00_config")


def log(message: str) -> None:
    print(f"[02_clean_price_data] {message}", flush=True)


def parse_bls_cpi() -> pd.DataFrame:
    raw_path = cfg.DATA_RAW / "bls_cpi_raw.json"
    if not raw_path.exists():
        log("BLS CPI raw JSON not found. Run 01_download_data.py first.")
        return pd.DataFrame()

    payload = json.loads(raw_path.read_text(encoding="utf-8"))
    reverse = {v: k for k, v in cfg.BLS_CPI_SERIES.items()}
    records = []
    for item in payload.get("Results", {}).get("series", []):
        category = reverse.get(item.get("seriesID"), item.get("seriesID"))
        for obs in item.get("data", []):
            period = obs.get("period")
            if not period or not period.startswith("M"):
                continue
            value = pd.to_numeric(obs.get("value"), errors="coerce")
            if pd.isna(value):
                continue
            records.append(
                {
                    "year": int(obs["year"]),
                    "month": int(period.replace("M", "")),
                    "date": f"{obs['year']}-{period.replace('M', '')}-01",
                    "category": category,
                    "value": float(value),
                    "source": "BLS CPI-U",
                    "series_id": item.get("seriesID"),
                }
            )
    df = pd.DataFrame(records)
    if not df.empty:
        df["date"] = pd.to_datetime(df["date"])
    return df


def clean_fred_series() -> pd.DataFrame:
    frames = []
    for name, series_id in cfg.FRED_SERIES.items():
        path = cfg.DATA_RAW / f"fred_{name}_{series_id}.csv"
        if not path.exists():
            continue
        df = pd.read_csv(path)
        value_col = [c for c in df.columns if c != "observation_date"][0]
        df = df.rename(columns={"observation_date": "date", value_col: "value"})
        df["date"] = pd.to_datetime(df["date"])
        df["series"] = name
        df["series_id"] = series_id
        df["value"] = pd.to_numeric(df["value"], errors="coerce")
        frames.append(df[["date", "series", "series_id", "value"]])
    return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()


def clean_nyfed_gscpi() -> pd.DataFrame:
    path = cfg.DATA_RAW / "nyfed_gscpi_data.xls"
    if not path.exists():
        log("NY Fed GSCPI file not found.")
        return pd.DataFrame()
    df = pd.read_excel(path, sheet_name="GSCPI Monthly Data")
    df = df[["Date", "GSCPI"]].copy()
    df["date"] = pd.to_datetime(df["Date"], errors="coerce")
    df["value"] = pd.to_numeric(df["GSCPI"], errors="coerce")
    df = df.dropna(subset=["date", "value"])
    df["series"] = "global_supply_chain_pressure"
    df["series_id"] = "NYFED_GSCPI"
    return df[["date", "series", "series_id", "value"]]


def main() -> None:
    cfg.ensure_dirs()
    cpi_monthly = parse_bls_cpi()
    if not cpi_monthly.empty:
        cpi_monthly.to_csv(cfg.DATA_PROCESSED / "cpi_monthly_clean.csv", index=False)
        cpi_annual = (
            cpi_monthly.assign(year=lambda x: x["date"].dt.year)
            .groupby(["year", "category", "source", "series_id"], as_index=False)["value"]
            .mean()
        )
        cpi_annual.to_csv(cfg.DATA_PROCESSED / "cpi_annual_clean.csv", index=False)
        log("Saved cleaned CPI monthly and annual files.")

    fred = clean_fred_series()
    gscpi = clean_nyfed_gscpi()
    if not gscpi.empty:
        fred = pd.concat([fred, gscpi], ignore_index=True) if not fred.empty else gscpi
    if not fred.empty:
        fred.to_csv(cfg.DATA_PROCESSED / "fred_series_clean.csv", index=False)
        annual = fred.assign(year=lambda x: x["date"].dt.year).groupby(
            ["year", "series", "series_id"], as_index=False
        )["value"].mean()
        annual.to_csv(cfg.DATA_PROCESSED / "fred_series_annual_clean.csv", index=False)
        log("Saved cleaned FRED files.")


if __name__ == "__main__":
    main()
