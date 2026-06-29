#!/usr/bin/env python3

import csv
import json
import math
import statistics
import urllib.request
from collections import defaultdict
from pathlib import Path


SERIES = {
    "CUSR0000SACL1E": {
        "category": "tradable_proxy_core_commodities",
        "label": "CPI-U commodities less food and energy commodities, seasonally adjusted",
    },
    "CUSR0000SASLE": {
        "category": "nontradable_proxy_core_services",
        "label": "CPI-U services less energy services, seasonally adjusted",
    },
}


def post_bls(series_ids, start_year, end_year):
    payload = json.dumps(
        {
            "seriesid": series_ids,
            "startyear": str(start_year),
            "endyear": str(end_year),
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        "https://api.bls.gov/publicAPI/v2/timeseries/data/",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def parse_series(api_payload):
    rows = []
    if api_payload.get("status") != "REQUEST_SUCCEEDED":
        raise RuntimeError(f"BLS API request failed: {api_payload}")
    for series in api_payload["Results"]["series"]:
        series_id = series["seriesID"]
        meta = SERIES[series_id]
        for obs in series["data"]:
            period = obs["period"]
            if not period.startswith("M"):
                continue
            try:
                cpi_index = float(obs["value"])
            except ValueError:
                continue
            year = int(obs["year"])
            month = int(period[1:])
            rows.append(
                {
                    "series_id": series_id,
                    "category": meta["category"],
                    "label": meta["label"],
                    "year": year,
                    "month": month,
                    "date": f"{year:04d}-{month:02d}-01",
                    "cpi_index": cpi_index,
                }
            )
    return rows


def main():
    project_root = Path(__file__).resolve().parents[2]
    raw_dir = project_root / "Data" / "bls" / "raw"
    analysis_dir = project_root / "Data" / "analysis"
    output_dir = project_root / "Output" / "tables"
    figure_dir = project_root / "Output" / "figures"
    raw_dir.mkdir(parents=True, exist_ok=True)
    analysis_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)
    figure_dir.mkdir(parents=True, exist_ok=True)

    series_ids = list(SERIES.keys())
    payloads = [
        ("2014_2023", post_bls(series_ids, 2014, 2023)),
        ("2024_2025", post_bls(series_ids, 2024, 2025)),
    ]

    all_rows = []
    for suffix, payload in payloads:
        with (raw_dir / f"bls_cpi_tradable_nontradable_{suffix}.json").open("w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        all_rows.extend(parse_series(payload))

    # Deduplicate in case ranges overlap in future edits.
    keyed = {
        (row["series_id"], row["year"], row["month"]): row
        for row in all_rows
    }
    monthly = sorted(keyed.values(), key=lambda r: (r["series_id"], r["year"], r["month"]))

    by_series_month = {(r["series_id"], r["year"], r["month"]): r["cpi_index"] for r in monthly}
    for row in monthly:
        prev = by_series_month.get((row["series_id"], row["year"] - 1, row["month"]))
        row["inflation_yoy"] = 100 * (row["cpi_index"] / prev - 1) if prev else None

    monthly_path = analysis_dir / "us_tradable_nontradable_cpi_monthly_2014_2025.csv"
    with monthly_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "series_id",
                "category",
                "label",
                "year",
                "month",
                "date",
                "cpi_index",
                "inflation_yoy",
            ],
        )
        writer.writeheader()
        writer.writerows(monthly)

    grouped = defaultdict(list)
    for row in monthly:
        grouped[(row["series_id"], row["category"], row["label"], row["year"])].append(row)

    annual = []
    for (series_id, category, label, year), rows in grouped.items():
        if year < 2014 or year > 2025:
            continue
        avg_index = statistics.mean(r["cpi_index"] for r in rows)
        avg_yoy_values = [r["inflation_yoy"] for r in rows if r["inflation_yoy"] is not None]
        annual.append(
            {
                "series_id": series_id,
                "category": category,
                "label": label,
                "year": year,
                "months_observed": len(rows),
                "annual_avg_cpi_index": avg_index,
                "annual_avg_yoy_inflation": statistics.mean(avg_yoy_values) if avg_yoy_values else None,
            }
        )

    index_by_series_year = {
        (r["series_id"], r["year"]): r["annual_avg_cpi_index"]
        for r in annual
    }
    for row in annual:
        prev = index_by_series_year.get((row["series_id"], row["year"] - 1))
        row["annual_avg_index_inflation"] = (
            100 * (row["annual_avg_cpi_index"] / prev - 1) if prev else None
        )

    annual = [r for r in annual if 2015 <= r["year"] <= 2025]
    annual = sorted(annual, key=lambda r: (r["year"], r["category"]))

    annual_path = analysis_dir / "us_tradable_nontradable_inflation_annual_2015_2025.csv"
    with annual_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "series_id",
                "category",
                "label",
                "year",
                "months_observed",
                "annual_avg_cpi_index",
                "annual_avg_index_inflation",
                "annual_avg_yoy_inflation",
            ],
        )
        writer.writeheader()
        writer.writerows(annual)

    tradable = {r["year"]: r for r in annual if r["category"].startswith("tradable")}
    nontradable = {r["year"]: r for r in annual if r["category"].startswith("nontradable")}
    comparison = []
    for year in sorted(set(tradable) & set(nontradable)):
        t = tradable[year]["annual_avg_index_inflation"]
        n = nontradable[year]["annual_avg_index_inflation"]
        comparison.append(
            {
                "year": year,
                "tradable_proxy_core_commodities_inflation": t,
                "nontradable_proxy_core_services_inflation": n,
                "tradable_minus_nontradable": t - n if t is not None and n is not None else None,
                "tradable_months_observed": tradable[year]["months_observed"],
                "nontradable_months_observed": nontradable[year]["months_observed"],
            }
        )

    comparison_path = output_dir / "tradable_nontradable_inflation_comparison_2015_2025.csv"
    with comparison_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "year",
                "tradable_proxy_core_commodities_inflation",
                "nontradable_proxy_core_services_inflation",
                "tradable_minus_nontradable",
                "tradable_months_observed",
                "nontradable_months_observed",
            ],
        )
        writer.writeheader()
        writer.writerows(comparison)

    note_path = output_dir / "tradable_nontradable_inflation_notes.md"
    with note_path.open("w", encoding="utf-8") as f:
        f.write("# US Tradable/Nontradable Inflation Proxy, 2015-2025\n\n")
        f.write("Source: BLS Public Data API, CPI-U seasonally adjusted series.\n\n")
        f.write("- Tradable proxy: CUSR0000SACL1E, commodities less food and energy commodities.\n")
        f.write("- Nontradable proxy: CUSR0000SASLE, services less energy services.\n")
        f.write("- Annual inflation is calculated from annual average CPI indexes.\n")
        f.write("- 2025 is included as available monthly data from BLS API; check months_observed before treating it as a full year.\n\n")
        f.write("| year | tradable | nontradable | tradable - nontradable |\n")
        f.write("|---:|---:|---:|---:|\n")
        for row in comparison:
            def fmt(x):
                return "" if x is None or math.isnan(x) else f"{x:.3f}"
            f.write(
                f"| {row['year']} | {fmt(row['tradable_proxy_core_commodities_inflation'])} | "
                f"{fmt(row['nontradable_proxy_core_services_inflation'])} | "
                f"{fmt(row['tradable_minus_nontradable'])} |\n"
            )

    try:
        import matplotlib.pyplot as plt

        years = [r["year"] for r in comparison]
        tradable_rates = [r["tradable_proxy_core_commodities_inflation"] for r in comparison]
        nontradable_rates = [r["nontradable_proxy_core_services_inflation"] for r in comparison]
        gaps = [r["tradable_minus_nontradable"] for r in comparison]

        fig, ax = plt.subplots(figsize=(9, 5.2))
        ax.plot(years, tradable_rates, marker="o", linewidth=2, label="Tradable proxy: core commodities")
        ax.plot(years, nontradable_rates, marker="o", linewidth=2, label="Nontradable proxy: core services")
        ax.axhline(0, color="#333333", linewidth=0.8)
        ax.axvspan(2021, 2022, color="#d9a441", alpha=0.18, label="Tradable inflation spike")
        ax.set_title("US Tradable vs. Nontradable Inflation Proxies, 2015-2025")
        ax.set_ylabel("Annual inflation from average CPI index (%)")
        ax.set_xlabel("Year")
        ax.set_xticks(years)
        ax.grid(axis="y", alpha=0.25)
        ax.legend(frameon=False, loc="upper left")
        fig.tight_layout()
        figure_path = figure_dir / "tradable_nontradable_inflation_2015_2025.png"
        fig.savefig(figure_path, dpi=180)
        plt.close(fig)

        fig, ax = plt.subplots(figsize=(9, 4.2))
        colors = ["#b94e48" if g and g > 0 else "#4e79a7" for g in gaps]
        ax.bar(years, gaps, color=colors)
        ax.axhline(0, color="#333333", linewidth=0.8)
        ax.set_title("Tradable Minus Nontradable Inflation Gap")
        ax.set_ylabel("Percentage points")
        ax.set_xlabel("Year")
        ax.set_xticks(years)
        ax.grid(axis="y", alpha=0.25)
        fig.tight_layout()
        gap_figure_path = figure_dir / "tradable_minus_nontradable_inflation_gap_2015_2025.png"
        fig.savefig(gap_figure_path, dpi=180)
        plt.close(fig)
        print(f"Wrote {figure_path}")
        print(f"Wrote {gap_figure_path}")
    except Exception as exc:
        print(f"Skipping figures because matplotlib plotting failed: {exc}")

    print(f"Wrote {monthly_path}")
    print(f"Wrote {annual_path}")
    print(f"Wrote {comparison_path}")
    print(f"Wrote {note_path}")


if __name__ == "__main__":
    main()
