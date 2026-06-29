#!/usr/bin/env python3
import argparse
from pathlib import Path

import pandas as pd

from importlib import import_module

cfg = import_module("00_config")


DEFAULT_OLD_PROJECT = Path("/Users/linian/Desktop/PROJ_completed/proj_class_compromise")


def log(message: str) -> None:
    print(f"[08_import_section301_to_cpi] {message}", flush=True)


def default_mapping() -> pd.DataFrame:
    rows = [
        ("durables", "321", "Wood products"),
        ("durables", "327", "Nonmetallic mineral products"),
        ("durables", "331", "Primary metals"),
        ("durables", "332", "Fabricated metal products"),
        ("durables", "333", "Machinery"),
        ("durables", "334", "Computer and electronic products"),
        ("durables", "335", "Electrical equipment, appliances, and components"),
        ("durables", "3361MV", "Motor vehicles, bodies and trailers, and parts"),
        ("durables", "3364OT", "Other transportation equipment"),
        ("durables", "337", "Furniture and related products"),
        ("durables", "339", "Miscellaneous manufacturing"),
        ("apparel", "313TT", "Textile mills and textile product mills"),
        ("apparel", "315AL", "Apparel and leather and allied products"),
        ("household_furnishings", "321", "Wood products"),
        ("household_furnishings", "335", "Electrical equipment, appliances, and components"),
        ("household_furnishings", "337", "Furniture and related products"),
        ("new_vehicles", "3361MV", "Motor vehicles, bodies and trailers, and parts"),
        ("used_cars_trucks", "3361MV", "Motor vehicles, bodies and trailers, and parts"),
        ("recreation", "334", "Computer and electronic products"),
        ("recreation", "3364OT", "Other transportation equipment"),
        ("recreation", "339", "Miscellaneous manufacturing"),
        ("food", "311FT", "Food and beverage and tobacco products"),
        ("energy", "324", "Petroleum and coal products"),
        ("transportation", "3361MV", "Motor vehicles, bodies and trailers, and parts"),
        ("transportation", "3364OT", "Other transportation equipment"),
    ]
    return pd.DataFrame(rows, columns=["category", "industry_code", "mapping_note"])


def default_naics_mapping() -> pd.DataFrame:
    rows = [
        ("apparel", "313", "Textile mills"),
        ("apparel", "314", "Textile product mills"),
        ("apparel", "315", "Apparel manufacturing"),
        ("apparel", "316", "Leather and allied product manufacturing"),
    ]
    return pd.DataFrame(rows, columns=["category", "naics_prefix", "mapping_note"])


def weighted_mean(group: pd.DataFrame) -> float:
    weights = pd.to_numeric(group["china_import_value_2017"], errors="coerce").fillna(0)
    values = pd.to_numeric(group["tariff_301_direct"], errors="coerce")
    if weights.sum() > 0:
        return float((values * weights).sum() / weights.sum())
    return float(values.mean())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--old-project",
        default=str(DEFAULT_OLD_PROJECT),
        help="Path to the old proj_class_compromise project with cleaned Section 301 exposure data.",
    )
    args = parser.parse_args()

    cfg.ensure_dirs()
    mapping_path = cfg.DATA_MANUAL / "cpi_to_bea_tariff_mapping.csv"
    if mapping_path.exists():
        mapping = pd.read_csv(mapping_path)
        log(f"Using existing mapping: {mapping_path}")
    else:
        mapping = default_mapping()
        mapping.to_csv(mapping_path, index=False)
        log(f"Wrote default mapping: {mapping_path}")

    old_project = Path(args.old_project)
    exposure_path = old_project / "Data" / "analysis" / "bea_summary_tariff_exposure_301_clean.csv"
    naics_exposure_path = old_project / "Data" / "cleaned" / "ustr_301_naics_exposure_annual.csv"
    if not exposure_path.exists():
        raise FileNotFoundError(f"Missing old exposure file: {exposure_path}")

    exposure = pd.read_csv(exposure_path)
    exposure["year"] = exposure["year"].astype(int)
    merged = mapping.merge(exposure, on="industry_code", how="left")
    matched = merged.dropna(subset=["year", "tariff_301_direct"]).copy()
    records = []
    for (category, year), group in matched.groupby(["category", "year"]):
        records.append({
            "category": category,
            "year": year,
            "tariff_301_rate": weighted_mean(group),
            "matched_industries": int(group["industry_code"].nunique()),
            "china_import_value_2017": pd.to_numeric(group["china_import_value_2017"], errors="coerce").fillna(0).sum(),
            "exposure_source": "BEA summary industry mapping",
        })
    category_year = pd.DataFrame(records)

    naics_mapping_path = cfg.DATA_MANUAL / "cpi_to_naics_tariff_mapping.csv"
    if naics_mapping_path.exists():
        naics_mapping = pd.read_csv(naics_mapping_path, dtype={"naics_prefix": str})
    else:
        naics_mapping = default_naics_mapping()
        naics_mapping.to_csv(naics_mapping_path, index=False)
        log(f"Wrote default NAICS fallback mapping: {naics_mapping_path}")

    naics_category_year = pd.DataFrame()
    if naics_exposure_path.exists() and not naics_mapping.empty:
        naics = pd.read_csv(naics_exposure_path, dtype={"naics_str": str})
        naics["year"] = naics["year"].astype(int)
        fallback_rows = []
        for _, row in naics_mapping.iterrows():
            sub = naics[naics["naics_str"].str.startswith(str(row["naics_prefix"]), na=False)].copy()
            if sub.empty:
                continue
            sub["category"] = row["category"]
            fallback_rows.append(sub)
        if fallback_rows:
            fallback = pd.concat(fallback_rows, ignore_index=True)
            records = []
            for (category, year), group in fallback.groupby(["category", "year"]):
                records.append({
                    "category": category,
                    "year": year,
                    "tariff_301_rate": weighted_mean(group),
                    "matched_industries": int(group["naics_str"].nunique()),
                    "china_import_value_2017": pd.to_numeric(group["china_import_value_2017"], errors="coerce").fillna(0).sum(),
                    "exposure_source": "NAICS6 fallback mapping",
                })
            naics_category_year = pd.DataFrame(records)

    all_categories = sorted(set(cfg.BLS_CPI_SERIES.keys()) - {"cpi_all"})
    years = range(cfg.START_YEAR, cfg.END_YEAR + 1)
    full = pd.MultiIndex.from_product([all_categories, years], names=["category", "year"]).to_frame(index=False)
    full = full.merge(category_year, on=["category", "year"], how="left")
    if not naics_category_year.empty:
        full = full.merge(
            naics_category_year,
            on=["category", "year"],
            how="left",
            suffixes=("", "_naics"),
        )
        use_naics = full["tariff_301_rate"].isna() | ((full["tariff_301_rate"].fillna(0) == 0) & (full["tariff_301_rate_naics"].fillna(0) > 0))
        for col in ["tariff_301_rate", "matched_industries", "china_import_value_2017", "exposure_source"]:
            naics_col = f"{col}_naics"
            if naics_col in full:
                full.loc[use_naics, col] = full.loc[use_naics, naics_col]
                full = full.drop(columns=[naics_col])
    full["tariff_301_rate"] = full["tariff_301_rate"].fillna(0.0)
    full["matched_industries"] = full["matched_industries"].fillna(0).astype(int)
    full["china_import_value_2017"] = full["china_import_value_2017"].fillna(0.0)
    full["exposure_source"] = full["exposure_source"].fillna("No matched tariff-exposed goods")
    full["post2018"] = (full["year"] >= 2018).astype(int)
    full["tariff_301_rate_post2018"] = full["tariff_301_rate"] * full["post2018"]

    out = cfg.DATA_PROCESSED / "cpi_category_301_tariff_exposure.csv"
    full.to_csv(out, index=False)
    log(f"Wrote CPI category Section 301 exposure: {out}")

    summary = (
        full[full["year"].between(2018, cfg.END_YEAR)]
        .groupby("category", as_index=False)
        .agg(
            mean_tariff_301_rate=("tariff_301_rate", "mean"),
            max_tariff_301_rate=("tariff_301_rate", "max"),
            matched_industries=("matched_industries", "max"),
            china_import_value_2017=("china_import_value_2017", "max"),
        )
    )
    summary.to_csv(cfg.OUTPUT_TABLES / "cpi_category_301_tariff_exposure_summary.csv", index=False)
    log("Wrote exposure summary table.")


if __name__ == "__main__":
    main()
