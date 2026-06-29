#!/usr/bin/env python3
import json
from datetime import datetime

import pandas as pd
import requests

from importlib import import_module

cfg = import_module("00_config")


def log(message: str) -> None:
    print(f"[01_download_data] {message}", flush=True)


def download_bls_cpi() -> None:
    url = "https://api.bls.gov/publicAPI/v2/timeseries/data/"
    series_ids = list(cfg.BLS_CPI_SERIES.values())
    out_json = cfg.DATA_RAW / "bls_cpi_raw.json"
    all_series = {}
    try:
        for start in range(cfg.START_YEAR, cfg.END_YEAR + 1, 10):
            end = min(start + 9, cfg.END_YEAR)
            payload = {
                "seriesid": series_ids,
                "startyear": str(start),
                "endyear": str(end),
            }
            response = requests.post(url, json=payload, timeout=60)
            response.raise_for_status()
            payload_json = response.json()
            for item in payload_json.get("Results", {}).get("series", []):
                sid = item.get("seriesID")
                all_series.setdefault(sid, {"seriesID": sid, "data": []})
                all_series[sid]["data"].extend(item.get("data", []))
            log(f"Downloaded BLS CPI window {start}-{end}.")
        merged = {
            "status": "REQUEST_SUCCEEDED",
            "source": "BLS public API; merged 10-year windows",
            "Results": {"series": list(all_series.values())},
        }
        out_json.write_text(json.dumps(merged, indent=2), encoding="utf-8")
        log(f"Saved BLS CPI raw data: {out_json}")
    except Exception as exc:
        log(f"BLS CPI download failed: {exc}")
        (cfg.DATA_RAW / "DOWNLOAD_ERRORS.txt").write_text(
            f"BLS CPI download failed at {datetime.now()}: {exc}\n",
            encoding="utf-8",
        )


def download_fred_series() -> None:
    for name, series_id in cfg.FRED_SERIES.items():
        url = f"https://fred.stlouisfed.org/graph/fredgraph.csv?id={series_id}"
        out_csv = cfg.DATA_RAW / f"fred_{name}_{series_id}.csv"
        try:
            df = pd.read_csv(url)
            df.to_csv(out_csv, index=False)
            log(f"Saved FRED series {name}: {out_csv}")
        except Exception as exc:
            log(f"FRED download failed for {name}/{series_id}: {exc}")


def download_nyfed_gscpi() -> None:
    url = "https://www.newyorkfed.org/medialibrary/research/interactives/gscpi/downloads/gscpi_data.xlsx"
    out_xls = cfg.DATA_RAW / "nyfed_gscpi_data.xls"
    try:
        response = requests.get(url, timeout=60)
        response.raise_for_status()
        out_xls.write_bytes(response.content)
        log(f"Saved NY Fed GSCPI data: {out_xls}")
    except Exception as exc:
        log(f"NY Fed GSCPI download failed: {exc}")


def create_manual_templates() -> None:
    tariff = pd.DataFrame(
        {
            "category": list(cfg.TARIFF_EXPOSURE_DEFAULT.keys()),
            "tariff_exposure": list(cfg.TARIFF_EXPOSURE_DEFAULT.values()),
            "notes": "baseline heuristic; replace with product-level exposure when available",
        }
    )
    tariff.to_csv(cfg.DATA_MANUAL / "tariff_exposure.csv", index=False)

    import_dep = pd.DataFrame(
        {
            "category": list(cfg.TRADABLE_DEFAULT.keys()),
            "import_dependence": list(cfg.TRADABLE_DEFAULT.values()),
            "tradable": list(cfg.TRADABLE_DEFAULT.values()),
            "notes": "baseline tradable dummy; replace with import-share measure when available",
        }
    )
    import_dep.to_csv(cfg.DATA_MANUAL / "import_dependence.csv", index=False)

    labor_conflict = pd.DataFrame(
        {
            "year": list(range(cfg.START_YEAR, cfg.END_YEAR + 1)),
            "work_stoppages": pd.NA,
            "workers_involved": pd.NA,
            "union_petitions": pd.NA,
            "notes": "optional manual supplement",
        }
    )
    labor_conflict.to_csv(cfg.DATA_MANUAL / "labor_conflict_manual.csv", index=False)
    log("Manual templates written to data/manual.")


def main() -> None:
    cfg.ensure_dirs()
    create_manual_templates()
    download_bls_cpi()
    download_nyfed_gscpi()
    download_fred_series()


if __name__ == "__main__":
    main()
