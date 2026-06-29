#!/usr/bin/env python3
"""Convert FRED PCEPI monthly data into an annual PCE deflator.

Input series:
- PCEPI, Personal Consumption Expenditures: Chain-type Price Index
- Source: FRED, underlying source BEA
- Units on FRED: Index 2017=100
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument("--start-year", type=int, default=2016)
    parser.add_argument("--end-year", type=int, default=2025)
    args = parser.parse_args()

    root = args.project_root.expanduser().resolve()
    raw_path = root / "Data" / "fred" / "raw" / "PCEPI.csv"
    processed_dir = root / "Data" / "fred" / "processed"
    cleaned_dir = root / "Data" / "cleaned"
    processed_dir.mkdir(parents=True, exist_ok=True)
    cleaned_dir.mkdir(parents=True, exist_ok=True)

    monthly = pd.read_csv(raw_path, parse_dates=["observation_date"])
    monthly = monthly.rename(columns={"PCEPI": "pce_price_index_2017_100"})
    monthly["year"] = monthly["observation_date"].dt.year
    monthly = monthly[
        (monthly["year"] >= args.start_year)
        & (monthly["year"] <= args.end_year)
        & monthly["pce_price_index_2017_100"].notna()
    ].copy()

    annual = (
        monthly.groupby("year", as_index=False)
        .agg(
            pce_price_index_2017_100=("pce_price_index_2017_100", "mean"),
            n_months=("pce_price_index_2017_100", "size"),
            first_month=("observation_date", "min"),
            last_month=("observation_date", "max"),
        )
        .sort_values("year")
    )

    out_path = processed_dir / "pce_price_index_annual_2016_2025.csv"
    clean_path = cleaned_dir / "pce_price_index_annual_2016_2025.csv"
    annual.to_csv(out_path, index=False)
    annual.to_csv(clean_path, index=False)

    manifest = {
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "source": {
            "series": "PCEPI",
            "name": "Personal Consumption Expenditures: Chain-type Price Index",
            "provider": "FRED",
            "underlying_source": "U.S. Bureau of Economic Analysis",
            "url": "https://fred.stlouisfed.org/series/PCEPI",
            "units": "Index 2017=100",
        },
        "input": str(raw_path.relative_to(root)),
        "outputs": [str(out_path.relative_to(root)), str(clean_path.relative_to(root))],
        "method": "Annual arithmetic average of monthly PCEPI values.",
        "years": [args.start_year, args.end_year],
    }
    manifest_path = processed_dir / "pce_price_index_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print(annual.to_string(index=False))
    print(f"Wrote {out_path}")
    print(f"Wrote {clean_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
