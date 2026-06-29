#!/usr/bin/env python3
"""Build annual Section 301 tariff exposure by NAICS and BEA summary industry.

The script uses cleaned USTR core-list HTS8 codes and a 2017 China-import
HS8-to-NAICS crosswalk from the RTP replication data. Outputs are intended as a
cleaner annual replacement for the earlier static RTP NAICS tariff exposure.
"""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd


YEARS = range(2016, 2026)


def normalize_code(value: object, width: int) -> str | None:
    if pd.isna(value):
        return None
    if isinstance(value, str):
        digits = "".join(ch for ch in value if ch.isdigit())
    else:
        try:
            digits = str(int(value))
        except Exception:
            digits = "".join(ch for ch in str(value) if ch.isdigit())
    if not digits:
        return None
    return digits.zfill(width)[:width]


def hts8_digits(value: object) -> str | None:
    return normalize_code(value, 8)


def hts8_dotted(value: object) -> str | None:
    digits = hts8_digits(value)
    if digits is None:
        return None
    return f"{digits[:4]}.{digits[4:6]}.{digits[6:8]}"


def annual_rate(list_id: str, year: int) -> float:
    """Annual-average additional tariff rate, approximated by active months."""
    if year <= 2017:
        return 0.0
    if list_id in {"list1", "list2"}:
        if year == 2018:
            months = 6 if list_id == "list1" else 5
            return 0.25 * months / 12
        return 0.25
    if list_id == "list3":
        if year == 2018:
            return 0.10 * 4 / 12
        if year == 2019:
            return (0.10 * 4 + 0.25 * 8) / 12
        return 0.25
    if list_id == "list4a":
        if year == 2019:
            return 0.15 * 4 / 12
        return 0.075
    if list_id == "list4b":
        return 0.0
    return 0.0


def build_hs8_naics_weights(m_flow_path: Path, chunksize: int = 250_000) -> pd.DataFrame:
    accum: dict[tuple[str, str], float] = defaultdict(float)
    total_rows = 0
    china_rows = 0

    columns = ["cty_name", "year", "hs8", "m_val", "naics_str"]
    for chunk in pd.read_stata(m_flow_path, columns=columns, chunksize=chunksize):
        total_rows += len(chunk)
        chunk = chunk[
            (chunk["year"] == 2017)
            & (chunk["cty_name"].astype(str).str.upper() == "CHINA")
            & chunk["m_val"].notna()
            & chunk["naics_str"].notna()
        ].copy()
        china_rows += len(chunk)
        if chunk.empty:
            continue
        chunk["hs8_dotted"] = chunk["hs8"].map(hts8_dotted)
        chunk["naics_str"] = chunk["naics_str"].astype(str).str.replace(r"\.0$", "", regex=True)
        chunk = chunk[
            chunk["hs8_dotted"].notna()
            & chunk["naics_str"].str.match(r"^[0-9]+$", na=False)
            & (chunk["m_val"] > 0)
        ]
        grouped = chunk.groupby(["hs8_dotted", "naics_str"], as_index=False)["m_val"].sum()
        for row in grouped.itertuples(index=False):
            accum[(row.hs8_dotted, row.naics_str)] += float(row.m_val)

    weights = pd.DataFrame(
        [{"hts8": k[0], "naics_str": k[1], "import_value_2017_china": v} for k, v in accum.items()]
    )
    if weights.empty:
        raise RuntimeError("No 2017 China import HS8-NAICS weights were built.")
    weights["naics_import_total_2017_china"] = weights.groupby("naics_str")[
        "import_value_2017_china"
    ].transform("sum")
    weights["hs8_naics_weight"] = (
        weights["import_value_2017_china"] / weights["naics_import_total_2017_china"]
    )
    weights.attrs["total_rows_scanned"] = total_rows
    weights.attrs["china_2017_rows_used_before_filters"] = china_rows
    return weights


def build_tariff_panel(core_lists: pd.DataFrame) -> pd.DataFrame:
    core = core_lists.copy()
    core["hts8"] = core["hts8"].map(hts8_dotted)
    core = core.dropna(subset=["hts8", "list_id"]).drop_duplicates(["list_id", "hts8"])
    rows = []
    for row in core.itertuples(index=False):
        for year in YEARS:
            rows.append(
                {
                    "list_id": row.list_id,
                    "hts8": row.hts8,
                    "year": year,
                    "active_301_rate": annual_rate(str(row.list_id), int(year)),
                }
            )
    return pd.DataFrame(rows)


def weighted_mean(values: pd.Series, weights: pd.Series) -> float:
    mask = values.notna() & weights.notna() & (weights > 0)
    if not mask.any():
        return np.nan
    return float(np.average(values[mask], weights=weights[mask]))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument("--chunksize", type=int, default=250_000)
    args = parser.parse_args()

    root = args.project_root.expanduser().resolve()
    clean_dir = root / "Data" / "cleaned"
    analysis_dir = root / "Data" / "analysis"
    processed_dir = root / "Data" / "tariffs" / "ustr_301" / "processed"
    for path in [clean_dir, analysis_dir, processed_dir]:
        path.mkdir(parents=True, exist_ok=True)

    core_path = clean_dir / "ustr_301_core_hts_lists_from_pdfs.csv"
    m_flow_path = root / "Data" / "dataverse_files" / "rtp" / "data" / "analysis" / "m_flow_hs10_fm_new.dta"
    concordance_path = clean_dir / "bea_naics_concordance_clean.csv"

    core_lists = pd.read_csv(core_path)
    weights = build_hs8_naics_weights(m_flow_path, chunksize=args.chunksize)
    tariff_panel = build_tariff_panel(core_lists)

    hts_naics_tariff = weights.merge(tariff_panel, on="hts8", how="left")
    hts_naics_tariff["targeted_import_value_2017_china"] = np.where(
        hts_naics_tariff["active_301_rate"].notna(),
        hts_naics_tariff["import_value_2017_china"],
        0.0,
    )
    hts_naics_tariff["active_301_rate"] = hts_naics_tariff["active_301_rate"].fillna(0.0)

    naics_exposure = (
        hts_naics_tariff.groupby(["naics_str", "year"], as_index=False)
        .apply(
            lambda g: pd.Series(
                {
                    "tariff_301_direct": float((g["hs8_naics_weight"] * g["active_301_rate"]).sum()),
                    "targeted_import_share_2017_china": float(
                        g["targeted_import_value_2017_china"].sum()
                        / g["naics_import_total_2017_china"].iloc[0]
                    ),
                    "china_import_value_2017": float(g["naics_import_total_2017_china"].iloc[0]),
                    "n_hs8_total": int(g["hts8"].nunique()),
                    "n_hs8_targeted": int(g.loc[g["active_301_rate"] > 0, "hts8"].nunique()),
                }
            )
        )
        .reset_index(drop=True)
    )

    concordance = pd.read_csv(concordance_path, dtype=str)
    concordance = (
        concordance.dropna(subset=["summary_code", "naics_2017"])
        .assign(naics_2017=lambda d: d["naics_2017"].astype(str))
    )
    concordance = concordance[concordance["naics_2017"].str.match(r"^[0-9]+$", na=False)]
    ambiguous = (
        concordance[["summary_code", "naics_2017"]]
        .drop_duplicates()
        .groupby("naics_2017", as_index=False)
        .size()
        .query("size > 1")
    )
    concordance = concordance[~concordance["naics_2017"].isin(ambiguous["naics_2017"])]

    bea_join = concordance.merge(
        naics_exposure, left_on="naics_2017", right_on="naics_str", how="left"
    )
    bea_exposure = (
        bea_join.groupby(["summary_code", "summary_name", "year"], as_index=False)
        .apply(
            lambda g: pd.Series(
                {
                    "tariff_301_direct": weighted_mean(
                        g["tariff_301_direct"], g["china_import_value_2017"]
                    ),
                    "targeted_import_share_2017_china": weighted_mean(
                        g["targeted_import_share_2017_china"], g["china_import_value_2017"]
                    ),
                    "china_import_value_2017": float(g["china_import_value_2017"].sum(skipna=True)),
                    "n_naics_with_import_weights": int(g["china_import_value_2017"].notna().sum()),
                    "n_naics_in_concordance": int(g["naics_2017"].nunique()),
                }
            )
        )
        .reset_index(drop=True)
        .rename(columns={"summary_code": "industry_code"})
    )
    bea_exposure["tariff_301_direct"] = bea_exposure["tariff_301_direct"].fillna(0.0)
    bea_exposure["targeted_import_share_2017_china"] = bea_exposure[
        "targeted_import_share_2017_china"
    ].fillna(0.0)

    weights.to_csv(clean_dir / "hs8_naics_import_weights_2017_china.csv", index=False)
    tariff_panel.to_csv(clean_dir / "ustr_301_hts8_annual_active_rates.csv", index=False)
    naics_exposure.to_csv(clean_dir / "ustr_301_naics_exposure_annual.csv", index=False)
    bea_exposure.to_csv(analysis_dir / "bea_summary_tariff_exposure_301_clean.csv", index=False)

    manifest = {
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "inputs": {
            "core_lists": str(core_path.relative_to(root)),
            "m_flow": str(m_flow_path.relative_to(root)),
            "bea_concordance": str(concordance_path.relative_to(root)),
        },
        "outputs": [
            "Data/cleaned/hs8_naics_import_weights_2017_china.csv",
            "Data/cleaned/ustr_301_hts8_annual_active_rates.csv",
            "Data/cleaned/ustr_301_naics_exposure_annual.csv",
            "Data/analysis/bea_summary_tariff_exposure_301_clean.csv",
        ],
        "rate_assumptions": {
            "list1": "25%, annualized as 6/12 of 2018 and full rate from 2019 onward.",
            "list2": "25%, annualized as 5/12 of 2018 and full rate from 2019 onward.",
            "list3": "10% from Sep 24 2018; 25% from May 10 2019; annualized by active months.",
            "list4a": "15% from Sep 1 2019; 7.5% from 2020 onward.",
            "list4b": "0 active rate because duties were suspended before taking effect.",
        },
        "rows_scanned": {
            "m_flow_total_rows": weights.attrs.get("total_rows_scanned"),
            "m_flow_china_2017_rows_before_filters": weights.attrs.get(
                "china_2017_rows_used_before_filters"
            ),
        },
        "caveats": [
            "Uses 2017 China import values as fixed HS8-to-NAICS weights.",
            "Uses HTS8-level core lists; product-level exclusions and firm-specific exclusions are not yet incorporated.",
            "Annual rates are approximated by active months, not exact daily exposure.",
        ],
    }
    (analysis_dir / "ustr_301_exposure_manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    print(json.dumps(manifest, indent=2, ensure_ascii=False))
    print("NAICS exposure rows:", len(naics_exposure))
    print("BEA exposure rows:", len(bea_exposure))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
