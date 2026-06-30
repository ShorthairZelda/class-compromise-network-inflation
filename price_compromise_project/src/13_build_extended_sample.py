from __future__ import annotations

import csv
import json
import re
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OLD_PROJECT = Path("/Users/linian/Desktop/PROJ_completed/proj_class_compromise")

DATA_DIR = PROJECT_ROOT / "Data"
EXTENDED_DIR = DATA_DIR / "extended"
OUTPUT_DIR = PROJECT_ROOT / "Output" / "rebuild"
TABLE_DIR = OUTPUT_DIR / "tables"

PRICE_LAG_START = 2009
SAMPLE_START = 2010
END_YEAR = 2025
YEARS_WITH_LAG = list(range(PRICE_LAG_START, END_YEAR + 1))
SAMPLE_YEARS = list(range(SAMPLE_START, END_YEAR + 1))

BLS_API_URL = "https://api.bls.gov/publicAPI/v2/timeseries/data/"

TRADABLE_SERIES = {
    "CUSR0000SACL1E": {
        "category": "tradable_proxy_core_commodities",
        "label": "CPI-U commodities less food and energy commodities, seasonally adjusted",
    },
    "CUSR0000SASLE": {
        "category": "nontradable_proxy_core_services",
        "label": "CPI-U services less energy services, seasonally adjusted",
    },
}

TRADABLE_GOODS_COMMODITY_CODES = {
    "111CA",
    "113FF",
    "211",
    "212",
    "213",
    "311FT",
    "313TT",
    "315AL",
    "321",
    "322",
    "323",
    "324",
    "325",
    "326",
    "327",
    "331",
    "332",
    "333",
    "334",
    "335",
    "3361MV",
    "3364OT",
    "337",
    "339",
}

GOODS_SUPPLY_CHAIN_COMMODITY_CODES = TRADABLE_GOODS_COMMODITY_CODES | {
    "22",
    "42",
    "481",
    "482",
    "483",
    "484",
    "486",
    "487OS",
    "493",
}


def clean_name(value: object) -> str:
    cleaned = str(value).strip().lower().replace("&", "and")
    cleaned = re.sub(r"[^\w\s]+", " ", cleaned)
    return re.sub(r"\s+", " ", cleaned).strip()


def ensure_dirs() -> None:
    for path in [EXTENDED_DIR, TABLE_DIR]:
        path.mkdir(parents=True, exist_ok=True)


def first_existing(paths: list[Path]) -> Path:
    for path in paths:
        if path.exists():
            return path
    raise FileNotFoundError("None of these paths exists: " + "; ".join(map(str, paths)))


def post_bls(series_ids: list[str], start_year: int, end_year: int) -> dict:
    payload = json.dumps(
        {
            "seriesid": series_ids,
            "startyear": str(start_year),
            "endyear": str(end_year),
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        BLS_API_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=90) as resp:
        return json.loads(resp.read().decode("utf-8"))


def download_qcew_year(year: int, raw_dir: Path) -> Path | None:
    raw_dir.mkdir(parents=True, exist_ok=True)
    raw_path = raw_dir / f"qcew_us_annual_{year}.csv"
    if raw_path.exists() and raw_path.stat().st_size > 0:
        return raw_path
    url = f"https://data.bls.gov/cew/data/api/{year}/a/area/US000.csv"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 academic research downloader"})
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            raw_path.write_bytes(resp.read())
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            print(f"Skipping QCEW {year}: annual area API returned 404.")
            return None
        raise
    time.sleep(0.15)
    return raw_path


def build_qcew_private_panel() -> pd.DataFrame:
    raw_dir = DATA_DIR / "bls" / "qcew" / "raw"
    rows: list[dict] = []
    for year in YEARS_WITH_LAG:
        raw_path = download_qcew_year(year, raw_dir)
        if raw_path is None:
            continue
        with raw_path.open("r", encoding="utf-8-sig", newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                if row.get("size_code") == "0" and row.get("own_code") == "5":
                    rows.append(row)

    qcew = pd.DataFrame(rows)
    numeric_cols = [
        "annual_avg_estabs",
        "annual_avg_emplvl",
        "total_annual_wages",
        "annual_avg_wkly_wage",
        "avg_annual_pay",
    ]
    for col in numeric_cols:
        qcew[col] = pd.to_numeric(qcew[col], errors="coerce")
    qcew["year"] = pd.to_numeric(qcew["year"], errors="coerce").astype("Int64")
    qcew["naics_code"] = qcew["industry_code"].astype(str)
    keep_cols = [
        "area_fips",
        "own_code",
        "naics_code",
        "agglvl_code",
        "year",
        "annual_avg_estabs",
        "annual_avg_emplvl",
        "total_annual_wages",
        "annual_avg_wkly_wage",
        "avg_annual_pay",
    ]
    out = qcew[keep_cols].sort_values(["naics_code", "year"]).copy()
    out.to_csv(EXTENDED_DIR / "qcew_us_annual_private_industries_2009_2025.csv", index=False)
    return out


def clean_bea_price_sheet(src: Path, sheet: str, value_name: str) -> pd.DataFrame:
    raw = pd.read_excel(src, sheet_name=sheet, header=None, engine="openpyxl")
    header_row = raw.index[raw.iloc[:, 0].astype(str).str.strip().eq("Line")][0]
    year_cols = {}
    for col in raw.columns:
        val = raw.iat[header_row, col]
        try:
            year = int(val)
        except Exception:
            continue
        if year in YEARS_WITH_LAG:
            year_cols[col] = year

    rows = []
    for row in range(header_row + 1, len(raw)):
        line = raw.iat[row, 0]
        name = raw.iat[row, 1]
        if pd.isna(line) or pd.isna(name):
            continue
        for col, year in year_cols.items():
            value = pd.to_numeric(raw.iat[row, col], errors="coerce")
            if pd.isna(value):
                continue
            rows.append(
                {
                    "line": str(line).strip(),
                    "industry_name": str(name).strip(),
                    "industry_name_clean": clean_name(name),
                    "year": year,
                    value_name: float(value),
                }
            )
    return pd.DataFrame(rows)


def build_bea_price_inputs() -> tuple[pd.DataFrame, pd.DataFrame]:
    gross_src = first_existing(
        [
            DATA_DIR / "bea" / "raw" / "GrossOutput.xlsx",
            OLD_PROJECT / "Data" / "bea" / "raw" / "GrossOutput.xlsx",
        ]
    )
    input_src = first_existing(
        [
            DATA_DIR / "bea" / "raw" / "IntermediateInputs.xlsx",
            OLD_PROJECT / "Data" / "bea" / "raw" / "IntermediateInputs.xlsx",
        ]
    )
    gross = clean_bea_price_sheet(gross_src, "TGO104-A", "gross_output_price_index_2017_100")
    intermediate = clean_bea_price_sheet(
        input_src,
        "TII104-A",
        "intermediate_inputs_price_index_2017_100",
    )
    gross.to_csv(EXTENDED_DIR / "bea_gross_output_price_index_annual_2009_2025.csv", index=False)
    intermediate.to_csv(EXTENDED_DIR / "bea_intermediate_inputs_price_index_annual_2009_2025.csv", index=False)
    return gross, intermediate


def build_tradable_inflation() -> pd.DataFrame:
    raw_path = EXTENDED_DIR / "bls_cpi_tradable_nontradable_2009_2025.json"
    chunks = [(PRICE_LAG_START, 2018), (2019, END_YEAR)]
    payloads = []
    for start_year, end_year in chunks:
        payload = post_bls(list(TRADABLE_SERIES.keys()), start_year, end_year)
        if payload.get("status") != "REQUEST_SUCCEEDED":
            raise RuntimeError(f"BLS API request failed: {payload}")
        payloads.append({"start_year": start_year, "end_year": end_year, "payload": payload})
        time.sleep(0.25)
    raw_path.write_text(json.dumps(payloads, indent=2, ensure_ascii=False), encoding="utf-8")

    rows = []
    for item in payloads:
        for series in item["payload"]["Results"]["series"]:
            series_id = series["seriesID"]
            meta = TRADABLE_SERIES[series_id]
            for obs in series["data"]:
                period = obs.get("period", "")
                if not period.startswith("M"):
                    continue
                try:
                    cpi_index = float(obs["value"])
                except (TypeError, ValueError):
                    continue
                rows.append(
                    {
                        "series_id": series_id,
                        "category": meta["category"],
                        "label": meta["label"],
                        "year": int(obs["year"]),
                        "month": int(period[1:]),
                        "date": f"{int(obs['year']):04d}-{int(period[1:]):02d}-01",
                        "cpi_index": cpi_index,
                    }
                )

    monthly = (
        pd.DataFrame(rows)
        .drop_duplicates(subset=["series_id", "year", "month"])
        .sort_values(["series_id", "year", "month"])
        .copy()
    )
    monthly["inflation_yoy"] = monthly.groupby(["series_id", "month"])["cpi_index"].pct_change(fill_method=None) * 100
    monthly.to_csv(EXTENDED_DIR / "us_tradable_nontradable_cpi_monthly_2009_2025.csv", index=False)

    annual_rows = []
    for (series_id, category, label, year), group in monthly.groupby(["series_id", "category", "label", "year"]):
        avg_yoy = group["inflation_yoy"].dropna()
        annual_rows.append(
            {
                "series_id": series_id,
                "category": category,
                "label": label,
                "year": year,
                "months_observed": int(group["month"].nunique()),
                "annual_avg_cpi_index": float(group["cpi_index"].mean()),
                "annual_avg_yoy_inflation": float(avg_yoy.mean()) if len(avg_yoy) else np.nan,
            }
        )

    annual = pd.DataFrame(annual_rows).sort_values(["series_id", "year"]).copy()
    annual["annual_avg_index_inflation"] = annual.groupby("series_id")["annual_avg_cpi_index"].pct_change(fill_method=None) * 100
    annual = annual[annual["year"].between(SAMPLE_START, END_YEAR)].sort_values(["year", "category"]).copy()
    annual.to_csv(EXTENDED_DIR / "us_tradable_nontradable_inflation_annual_2010_2025.csv", index=False)

    tradable = annual[annual["category"].eq("tradable_proxy_core_commodities")][
        ["year", "annual_avg_yoy_inflation"]
    ].rename(columns={"annual_avg_yoy_inflation": "tradable_goods_inflation"})
    nontradable = annual[annual["category"].eq("nontradable_proxy_core_services")][
        ["year", "annual_avg_yoy_inflation"]
    ].rename(columns={"annual_avg_yoy_inflation": "nontradable_services_inflation"})
    inflation_panel = tradable.merge(nontradable, on="year", how="outer")
    inflation_panel["tradable_minus_nontradable_inflation"] = (
        inflation_panel["tradable_goods_inflation"] - inflation_panel["nontradable_services_inflation"]
    )
    inflation_panel.to_csv(EXTENDED_DIR / "extended_tradable_nontradable_inflation_panel_2010_2025.csv", index=False)
    return inflation_panel


def build_io_exposures(io: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    io = io.copy()
    io["tradable_goods_supplier"] = io["commodity_code"].isin(TRADABLE_GOODS_COMMODITY_CODES).astype(int)
    io["goods_supply_chain_supplier"] = io["commodity_code"].isin(GOODS_SUPPLY_CHAIN_COMMODITY_CODES).astype(int)
    io["tradable_goods_buyer"] = io["industry_code"].isin(TRADABLE_GOODS_COMMODITY_CODES).astype(int)
    io["goods_supply_chain_buyer"] = io["industry_code"].isin(GOODS_SUPPLY_CHAIN_COMMODITY_CODES).astype(int)

    upstream = (
        io.groupby(["industry_code", "industry_name"], as_index=False)
        .agg(
            tradable_goods_input_exposure=(
                "input_share",
                lambda s: s[io.loc[s.index, "tradable_goods_supplier"].eq(1)].sum(),
            ),
            goods_supply_chain_input_exposure=(
                "input_share",
                lambda s: s[io.loc[s.index, "goods_supply_chain_supplier"].eq(1)].sum(),
            ),
        )
        .drop(columns=["industry_name"])
    )

    sales = (
        io.groupby("commodity_code", as_index=False)
        .agg(total_intermediate_sales_musd=("value_musd", "sum"))
        .rename(columns={"commodity_code": "industry_code"})
    )
    downstream = (
        io.groupby("commodity_code", as_index=False)
        .agg(
            tradable_goods_downstream_exposure=(
                "value_musd",
                lambda s: s[io.loc[s.index, "tradable_goods_buyer"].eq(1)].sum(),
            ),
            goods_supply_chain_downstream_exposure=(
                "value_musd",
                lambda s: s[io.loc[s.index, "goods_supply_chain_buyer"].eq(1)].sum(),
            ),
        )
        .rename(columns={"commodity_code": "industry_code"})
        .merge(sales, on="industry_code", how="left")
    )
    for col in ["tradable_goods_downstream_exposure", "goods_supply_chain_downstream_exposure"]:
        downstream[col] = downstream[col] / downstream["total_intermediate_sales_musd"]
        downstream[col] = downstream[col].fillna(0)

    return upstream, downstream.drop(columns=["total_intermediate_sales_musd"])


def build_qcew_bea(qcew: pd.DataFrame) -> pd.DataFrame:
    concordance_path = first_existing(
        [
            DATA_DIR / "cleaned" / "bea_naics_concordance_clean.csv",
            OLD_PROJECT / "Data" / "cleaned" / "bea_naics_concordance_clean.csv",
        ]
    )
    concordance_raw = pd.read_csv(concordance_path, dtype=str)
    concordance = (
        concordance_raw.dropna(subset=["summary_code", "naics_2017"])
        .assign(naics_2017=lambda d: d["naics_2017"].astype(str).str.strip())
    )
    concordance = concordance[concordance["naics_2017"].str.match(r"^[0-9]+$", na=False)].copy()
    concordance = concordance[["summary_code", "summary_name", "naics_2017"]].drop_duplicates()
    ambiguous = (
        concordance[["summary_code", "naics_2017"]]
        .drop_duplicates()
        .groupby("naics_2017", as_index=False)
        .size()
        .query("size > 1")
    )
    concordance = concordance[~concordance["naics_2017"].isin(ambiguous["naics_2017"])].copy()

    merged = concordance.merge(qcew, left_on="naics_2017", right_on="naics_code", how="left")
    out = (
        merged.groupby(["summary_code", "summary_name", "year"], as_index=False)
        .agg(
            qcew_employment=("annual_avg_emplvl", "sum"),
            qcew_total_annual_wages=("total_annual_wages", "sum"),
            qcew_avg_weekly_wage=(
                "annual_avg_wkly_wage",
                lambda s: np.average(
                    s.dropna(),
                    weights=merged.loc[s.dropna().index, "annual_avg_emplvl"],
                )
                if len(s.dropna()) and merged.loc[s.dropna().index, "annual_avg_emplvl"].sum() > 0
                else np.nan,
            ),
            n_naics_wage_matches=("annual_avg_emplvl", lambda s: s.notna().sum()),
        )
        .rename(columns={"summary_code": "industry_code", "summary_name": "summary_name"})
    )
    out["qcew_avg_annual_pay"] = np.where(
        out["qcew_employment"] > 0,
        out["qcew_total_annual_wages"] / out["qcew_employment"],
        np.nan,
    )
    return out


def build_extended_panel() -> pd.DataFrame:
    gross, intermediate = build_bea_price_inputs()
    qcew = build_qcew_private_panel()
    qcew_bea = build_qcew_bea(qcew)
    inflation_panel = build_tradable_inflation()

    io_ind = pd.read_csv(
        first_existing(
            [
                DATA_DIR / "cleaned" / "bea_industry_output_2019.csv",
                OLD_PROJECT / "Data" / "cleaned" / "bea_industry_output_2019.csv",
            ]
        )
    ).rename(columns={"year": "io_year"})
    io_ind["industry_name_clean"] = io_ind["industry_name"].map(clean_name)

    io = pd.read_csv(
        first_existing(
            [
                DATA_DIR / "cleaned" / "bea_input_coefficients_2019.csv",
                OLD_PROJECT / "Data" / "cleaned" / "bea_input_coefficients_2019.csv",
            ]
        )
    )
    upstream, downstream = build_io_exposures(io)

    industry_price_panel = (
        io_ind[~io_ind["industry_code"].astype(str).str.startswith("G")]
        .merge(
            gross[["industry_name_clean", "year", "gross_output_price_index_2017_100"]],
            on="industry_name_clean",
            how="left",
        )
        .merge(
            intermediate[["industry_name_clean", "year", "intermediate_inputs_price_index_2017_100"]],
            on=["industry_name_clean", "year"],
            how="left",
        )
        .query("year in @YEARS_WITH_LAG")
        .sort_values(["industry_code", "year"])
    )

    exposure_path = first_existing(
        [
            DATA_DIR / "analysis" / "bea_summary_tariff_exposure_301_clean.csv",
            DATA_DIR / "rebuild" / "rebuild_bea_summary_tariff_exposure_301.csv",
            OLD_PROJECT / "Data" / "analysis" / "bea_summary_tariff_exposure_301_clean.csv",
        ]
    )
    exposure = pd.read_csv(exposure_path)
    exposure["industry_code"] = exposure["industry_code"].astype(str)
    exposure["year"] = pd.to_numeric(exposure["year"], errors="coerce").astype("Int64")

    tariff_panel = pd.MultiIndex.from_product(
        [io_ind["industry_code"].astype(str).unique(), YEARS_WITH_LAG],
        names=["industry_code", "year"],
    ).to_frame(index=False)
    tariff_cols = [
        "industry_code",
        "year",
        "tariff_301_direct",
        "targeted_import_share_2017_china",
        "china_import_value_2017",
        "n_naics_with_import_weights",
        "n_naics_in_concordance",
    ]
    use_cols = [col for col in tariff_cols if col in exposure.columns]
    tariff_panel = tariff_panel.merge(exposure[use_cols], on=["industry_code", "year"], how="left")
    tariff_panel["tariff_301_direct"] = tariff_panel["tariff_301_direct"].fillna(0)
    tariff_panel["tariff_direct_prelim"] = tariff_panel["tariff_301_direct"]
    tariff_panel["tariff_direct_post_prelim"] = tariff_panel["tariff_301_direct"]
    if "n_naics_with_import_weights" in tariff_panel.columns:
        tariff_panel["n_naics_tariff_matches"] = tariff_panel["n_naics_with_import_weights"].fillna(0)
    else:
        tariff_panel["n_naics_tariff_matches"] = 0

    network_tariff = (
        io[["industry_code", "commodity_code", "input_share", "link_5pct"]]
        .merge(pd.DataFrame({"year": YEARS_WITH_LAG}), how="cross")
        .merge(
            tariff_panel[["industry_code", "year", "tariff_direct_prelim"]].rename(
                columns={"industry_code": "commodity_code", "tariff_direct_prelim": "supplier_tariff_direct"}
            ),
            on=["commodity_code", "year"],
            how="left",
        )
    )
    network_tariff["supplier_tariff_direct"] = network_tariff["supplier_tariff_direct"].fillna(0)
    network_tariff = (
        network_tariff.assign(
            network_component=lambda d: d["input_share"] * d["supplier_tariff_direct"],
            network_component_5pct=lambda d: np.where(
                d["link_5pct"].eq(1),
                d["input_share"] * d["supplier_tariff_direct"],
                0,
            ),
            network_component_excl_own=lambda d: np.where(
                d["commodity_code"].ne(d["industry_code"]),
                d["input_share"] * d["supplier_tariff_direct"],
                0,
            ),
        )
        .groupby(["industry_code", "year"], as_index=False)
        .agg(
            network_tariff_shock=("network_component", "sum"),
            network_tariff_shock_5pct=("network_component_5pct", "sum"),
            network_tariff_shock_excl_own=("network_component_excl_own", "sum"),
        )
    )

    panel = (
        industry_price_panel.merge(qcew_bea, on=["industry_code", "year"], how="left")
        .merge(tariff_panel[["industry_code", "year", "tariff_301_direct", "tariff_direct_prelim", "tariff_direct_post_prelim", "n_naics_tariff_matches"]], on=["industry_code", "year"], how="left")
        .merge(network_tariff, on=["industry_code", "year"], how="left")
        .merge(upstream, on="industry_code", how="left")
        .merge(downstream, on="industry_code", how="left")
        .merge(inflation_panel, on="year", how="left")
        .sort_values(["industry_code", "year"])
        .copy()
    )

    fill_zero = [
        "tariff_301_direct",
        "tariff_direct_prelim",
        "tariff_direct_post_prelim",
        "n_naics_tariff_matches",
        "network_tariff_shock",
        "network_tariff_shock_5pct",
        "network_tariff_shock_excl_own",
        "tradable_goods_input_exposure",
        "goods_supply_chain_input_exposure",
        "tradable_goods_downstream_exposure",
        "goods_supply_chain_downstream_exposure",
    ]
    for col in fill_zero:
        panel[col] = panel[col].fillna(0)

    panel["ln_gross_output_price"] = np.log(panel["gross_output_price_index_2017_100"])
    panel["ln_intermediate_inputs_price"] = np.log(panel["intermediate_inputs_price_index_2017_100"])
    panel["ln_avg_annual_pay"] = np.log(panel["qcew_avg_annual_pay"])
    for col in ["ln_gross_output_price", "ln_intermediate_inputs_price", "ln_avg_annual_pay"]:
        panel[f"d{col}"] = panel.groupby("industry_code")[col].diff()
    panel = panel.rename(
        columns={
            "dln_gross_output_price": "dln_gross_output_price",
            "dln_intermediate_inputs_price": "dln_intermediate_inputs_price",
            "dln_avg_annual_pay": "dln_avg_annual_pay",
        }
    )

    panel["post2021"] = (panel["year"] >= 2021).astype(int)
    for col in [
        "network_tariff_shock",
        "network_tariff_shock_5pct",
        "network_tariff_shock_excl_own",
        "tariff_direct_prelim",
    ]:
        lag1 = f"lag1_{col}"
        lag2 = f"lag2_{col}"
        panel[lag1] = panel.groupby("industry_code")[col].shift(1)
        panel[lag2] = panel.groupby("industry_code")[col].shift(2)
    panel["network_tariff_shock_cum01"] = panel["network_tariff_shock"] + panel["lag1_network_tariff_shock"].fillna(0)
    panel["network_tariff_shock_5pct_cum01"] = panel["network_tariff_shock_5pct"] + panel["lag1_network_tariff_shock_5pct"].fillna(0)
    panel["network_tariff_shock_excl_own_cum01"] = panel["network_tariff_shock_excl_own"] + panel["lag1_network_tariff_shock_excl_own"].fillna(0)
    panel["tariff_direct_prelim_cum01"] = panel["tariff_direct_prelim"] + panel["lag1_tariff_direct_prelim"].fillna(0)

    panel["tradable_input_inflation_shock"] = (
        panel["tradable_goods_input_exposure"] * panel["tradable_goods_inflation"]
    )
    panel["goods_supply_chain_inflation_shock"] = (
        panel["goods_supply_chain_input_exposure"] * panel["tradable_goods_inflation"]
    )
    panel["tradable_downstream_inflation_shock"] = (
        panel["tradable_goods_downstream_exposure"] * panel["tradable_goods_inflation"]
    )
    panel["goods_supply_chain_downstream_inflation_shock"] = (
        panel["goods_supply_chain_downstream_exposure"] * panel["tradable_goods_inflation"]
    )
    for col in [
        "tradable_input_inflation_shock",
        "goods_supply_chain_inflation_shock",
        "tradable_downstream_inflation_shock",
        "goods_supply_chain_downstream_inflation_shock",
    ]:
        lag_col = f"lag1_{col}"
        cum_col = f"{col}_cum01"
        panel[lag_col] = panel.groupby("industry_code")[col].shift(1)
        panel[cum_col] = panel[col].fillna(0) + panel[lag_col].fillna(0)

    panel["industry_fe"] = panel["industry_code"]
    panel["price_pressure_gap"] = panel["dln_gross_output_price"] - panel["dln_avg_annual_pay"]
    panel["input_price_pressure_gap"] = panel["dln_intermediate_inputs_price"] - panel["dln_avg_annual_pay"]

    out = panel[panel["year"].between(SAMPLE_START, END_YEAR)].copy()
    out.to_csv(EXTENDED_DIR / "extended_industry_network_panel_2010_2025.csv", index=False)

    diagnostics = {
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "sample_years": [SAMPLE_START, END_YEAR],
        "lag_year_included_for_growth_rates": PRICE_LAG_START,
        "rows": int(len(out)),
        "industries": int(out["industry_code"].nunique()),
        "bea_gross_price_years": [int(gross["year"].min()), int(gross["year"].max())],
        "bea_intermediate_price_years": [int(intermediate["year"].min()), int(intermediate["year"].max())],
        "qcew_years": [int(qcew["year"].min()), int(qcew["year"].max())],
        "tradable_inflation_years": [
            int(inflation_panel["year"].min()),
            int(inflation_panel["year"].max()),
        ],
        "missing_tradable_inflation_rows": int(out["tradable_goods_inflation"].isna().sum()),
        "output_panel": str(EXTENDED_DIR / "extended_industry_network_panel_2010_2025.csv"),
    }
    (EXTENDED_DIR / "extended_sample_manifest.json").write_text(
        json.dumps(diagnostics, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    return out


def main() -> None:
    ensure_dirs()
    panel = build_extended_panel()
    print(
        json.dumps(
            {
                "rows": len(panel),
                "industries": panel["industry_code"].nunique(),
                "years": [int(panel["year"].min()), int(panel["year"].max())],
                "output": str(EXTENDED_DIR / "extended_industry_network_panel_2010_2025.csv"),
            },
            indent=2,
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
