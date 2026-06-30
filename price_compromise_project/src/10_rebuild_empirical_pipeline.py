from __future__ import annotations

from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OLD_PROJECT = Path("/Users/linian/Desktop/PROJ_completed/proj_class_compromise")

DATA_REBUILD = PROJECT_ROOT / "data" / "rebuild"
OUTPUT_REBUILD = PROJECT_ROOT / "output" / "rebuild"
FIG_DIR = OUTPUT_REBUILD / "figures"
TABLE_DIR = OUTPUT_REBUILD / "tables"


LOW_PRICE_CATEGORIES = {
    "durables",
    "apparel",
    "household_furnishings",
    "new_vehicles",
    "used_cars_trucks",
    "recreation",
}

LOCAL_REPRODUCTION_CATEGORIES = {
    "shelter",
    "rent_primary_residence",
    "medical_care",
    "education_communication",
}

BASIC_REPRODUCTION_CATEGORIES = {
    "food",
    "energy",
    "transportation",
}

INDEX_LABELS = {
    "CheapGoodsIndex": "Low-price tradable goods",
    "CPIAllItems": "CPI all items",
    "BasicReproductionCostIndex": "Basic reproduction costs",
    "LocalReproductionCostIndex": "Local institutional reproduction costs",
}

CLASS_LABELS = {
    "low_price_global": "Low-price tradable/global goods",
    "local_reproduction": "Local institutional reproduction costs",
    "basic_reproduction": "Basic reproduction necessities",
    "official_cpi": "Official CPI baseline",
}

CLASS_COLORS = {
    "low_price_global": "#2f6f8f",
    "local_reproduction": "#9a3d2f",
    "basic_reproduction": "#7a6a38",
    "official_cpi": "#595959",
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


def ensure_dirs() -> None:
    for path in [DATA_REBUILD, FIG_DIR, TABLE_DIR]:
        path.mkdir(parents=True, exist_ok=True)


def classify_category(category: str) -> str:
    if category == "cpi_all":
        return "official_cpi"
    if category in LOW_PRICE_CATEGORIES:
        return "low_price_global"
    if category in LOCAL_REPRODUCTION_CATEGORIES:
        return "local_reproduction"
    if category in BASIC_REPRODUCTION_CATEGORIES:
        return "basic_reproduction"
    return "other"


def build_cpi_outputs() -> None:
    cpi = pd.read_csv(PROJECT_ROOT / "data" / "processed" / "cpi_annual_normalized.csv")
    indices = pd.read_csv(PROJECT_ROOT / "data" / "processed" / "constructed_price_indices.csv")
    tariff = pd.read_csv(PROJECT_ROOT / "data" / "processed" / "cpi_category_301_tariff_exposure.csv")

    cpi["class"] = cpi["category"].map(classify_category)
    cpi["class_label"] = cpi["class"].map(CLASS_LABELS)
    cpi = cpi.sort_values(["category", "year"]).copy()
    cpi["inflation"] = cpi.groupby("category")["price_index_1984_100"].pct_change(fill_method=None) * 100
    cpi["post2019_cum_change"] = cpi.groupby("category")["price_index_1984_100"].transform(
        lambda s: (s / s.loc[cpi.loc[s.index, "year"].eq(2019)].iloc[0] - 1) * 100
        if (cpi.loc[s.index, "year"] == 2019).any()
        else pd.NA
    )

    cpi.to_csv(DATA_REBUILD / "rebuild_cpi_category_panel.csv", index=False)

    category_summary = (
        cpi[cpi["category"] != "cpi_all"]
        .groupby(["category", "label", "class", "class_label"], as_index=False)
        .agg(
            price_index_2025=("price_index_1984_100", lambda x: x[cpi.loc[x.index, "year"].eq(2025)].iloc[0]),
            avg_inflation_1985_2025=("inflation", "mean"),
            inflation_2021=("inflation", lambda x: x[cpi.loc[x.index, "year"].eq(2021)].iloc[0]),
            inflation_2022=("inflation", lambda x: x[cpi.loc[x.index, "year"].eq(2022)].iloc[0]),
            cum_change_2019_2022=(
                "price_index_1984_100",
                lambda x: (
                    x[cpi.loc[x.index, "year"].eq(2022)].iloc[0]
                    / x[cpi.loc[x.index, "year"].eq(2019)].iloc[0]
                    - 1
                )
                * 100,
            ),
        )
        .sort_values("price_index_2025")
    )
    category_summary.to_csv(TABLE_DIR / "rebuild_cpi_category_summary.csv", index=False)

    index_summary = (
        indices.groupby("index_name", as_index=False)
        .agg(
            price_index_2025=("index_value", lambda x: x[indices.loc[x.index, "year"].eq(2025)].iloc[0]),
            avg_inflation_1985_2025=("inflation", "mean"),
            inflation_2021=("inflation", lambda x: x[indices.loc[x.index, "year"].eq(2021)].iloc[0]),
            inflation_2022=("inflation", lambda x: x[indices.loc[x.index, "year"].eq(2022)].iloc[0]),
            cum_change_2019_2022=(
                "index_value",
                lambda x: (
                    x[indices.loc[x.index, "year"].eq(2022)].iloc[0]
                    / x[indices.loc[x.index, "year"].eq(2019)].iloc[0]
                    - 1
                )
                * 100,
            ),
        )
        .assign(index_label=lambda d: d["index_name"].map(INDEX_LABELS))
    )
    index_summary.to_csv(TABLE_DIR / "rebuild_constructed_index_summary.csv", index=False)

    index_wide = indices.pivot(index="year", columns="index_name", values="index_value")
    gap = pd.DataFrame(
        {
            "year": index_wide.index,
            "local_to_cheap_ratio": index_wide["LocalReproductionCostIndex"] / index_wide["CheapGoodsIndex"],
            "basic_to_cheap_ratio": index_wide["BasicReproductionCostIndex"] / index_wide["CheapGoodsIndex"],
        }
    )
    gap.to_csv(TABLE_DIR / "rebuild_reproduction_to_cheap_goods_gap.csv", index=False)

    tariff_panel = tariff.merge(
        cpi[["category", "year", "label", "class", "class_label"]],
        on=["category", "year"],
        how="left",
    )
    tariff_merged = (
        tariff_panel[tariff_panel["year"].between(2018, 2025)]
        .groupby(["category", "label", "class", "class_label"], as_index=False)
        .agg(
            mean_tariff_301_rate_2018_2025=("tariff_301_rate", "mean"),
            max_tariff_301_rate_2018_2025=("tariff_301_rate", "max"),
        )
        .sort_values("mean_tariff_301_rate_2018_2025", ascending=False)
    )
    tariff_merged.to_csv(TABLE_DIR / "rebuild_cpi_301_exposure_by_class.csv", index=False)


def build_industry_outputs() -> None:
    panel_path = OLD_PROJECT / "Data" / "analysis" / "analysis_panel_bea_summary_2016_2025_prelim.csv"
    shock_path = OLD_PROJECT / "Data" / "analysis" / "luo_style_own_up_down_tariff_shocks_2016_2025.csv"
    io_path = OLD_PROJECT / "Data" / "cleaned" / "bea_input_coefficients_2019.csv"
    exposure_path = OLD_PROJECT / "Data" / "analysis" / "bea_summary_tariff_exposure_301_clean.csv"
    tradable_inflation_path = (
        PROJECT_ROOT / "Data" / "analysis" / "us_tradable_nontradable_inflation_annual_2015_2025.csv"
    )

    panel = pd.read_csv(panel_path)
    shocks = pd.read_csv(shock_path)
    io = pd.read_csv(io_path)
    exposure = pd.read_csv(exposure_path)
    tradable_inflation = pd.read_csv(tradable_inflation_path)

    tradable_goods_inflation = (
        tradable_inflation[tradable_inflation["category"].eq("tradable_proxy_core_commodities")]
        [["year", "annual_avg_yoy_inflation"]]
        .rename(columns={"annual_avg_yoy_inflation": "tradable_goods_inflation"})
    )

    nontradable_services_inflation = (
        tradable_inflation[tradable_inflation["category"].eq("nontradable_proxy_core_services")]
        [["year", "annual_avg_yoy_inflation"]]
        .rename(columns={"annual_avg_yoy_inflation": "nontradable_services_inflation"})
    )

    inflation_panel = tradable_goods_inflation.merge(
        nontradable_services_inflation,
        on="year",
        how="outer",
    )
    inflation_panel["tradable_minus_nontradable_inflation"] = (
        inflation_panel["tradable_goods_inflation"] - inflation_panel["nontradable_services_inflation"]
    )

    io = io.copy()
    io["tradable_goods_supplier"] = io["commodity_code"].isin(TRADABLE_GOODS_COMMODITY_CODES).astype(int)
    io["goods_supply_chain_supplier"] = io["commodity_code"].isin(GOODS_SUPPLY_CHAIN_COMMODITY_CODES).astype(int)
    io["tradable_goods_buyer"] = io["industry_code"].isin(TRADABLE_GOODS_COMMODITY_CODES).astype(int)
    io["goods_supply_chain_buyer"] = io["industry_code"].isin(GOODS_SUPPLY_CHAIN_COMMODITY_CODES).astype(int)

    upstream_exposure = (
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
    )

    sales = (
        io.groupby("commodity_code", as_index=False)
        .agg(total_intermediate_sales_musd=("value_musd", "sum"))
        .rename(columns={"commodity_code": "industry_code"})
    )
    downstream_exposure = (
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
        downstream_exposure[col] = downstream_exposure[col] / downstream_exposure["total_intermediate_sales_musd"]
        downstream_exposure[col] = downstream_exposure[col].fillna(0)

    merged = panel.merge(shocks, on=["industry_code", "year"], how="left")
    merged = merged.merge(
        upstream_exposure.drop(columns=["industry_name"]),
        on="industry_code",
        how="left",
    )
    merged = merged.merge(
        downstream_exposure[
            [
                "industry_code",
                "tradable_goods_downstream_exposure",
                "goods_supply_chain_downstream_exposure",
            ]
        ],
        on="industry_code",
        how="left",
    )
    merged = merged.merge(inflation_panel, on="year", how="left")
    for col in [
        "tradable_goods_input_exposure",
        "goods_supply_chain_input_exposure",
        "tradable_goods_downstream_exposure",
        "goods_supply_chain_downstream_exposure",
    ]:
        merged[col] = merged[col].fillna(0)

    merged["tradable_input_inflation_shock"] = (
        merged["tradable_goods_input_exposure"] * merged["tradable_goods_inflation"]
    )
    merged["goods_supply_chain_inflation_shock"] = (
        merged["goods_supply_chain_input_exposure"] * merged["tradable_goods_inflation"]
    )
    merged["tradable_downstream_inflation_shock"] = (
        merged["tradable_goods_downstream_exposure"] * merged["tradable_goods_inflation"]
    )
    merged["goods_supply_chain_downstream_inflation_shock"] = (
        merged["goods_supply_chain_downstream_exposure"] * merged["tradable_goods_inflation"]
    )
    merged = merged.sort_values(["industry_code", "year"]).copy()
    for col in [
        "tradable_input_inflation_shock",
        "goods_supply_chain_inflation_shock",
        "tradable_downstream_inflation_shock",
        "goods_supply_chain_downstream_inflation_shock",
    ]:
        lag_col = f"lag1_{col}"
        cum_col = f"{col}_cum01"
        merged[lag_col] = merged.groupby("industry_code")[col].shift(1)
        merged[cum_col] = merged[col].fillna(0) + merged[lag_col].fillna(0)

    merged["industry_fe"] = merged["industry_code"]
    merged["price_pressure_gap"] = merged["dln_gross_output_price"] - merged["dln_avg_annual_pay"]
    merged["input_price_pressure_gap"] = merged["dln_intermediate_inputs_price"] - merged["dln_avg_annual_pay"]
    merged.to_csv(DATA_REBUILD / "rebuild_industry_network_panel.csv", index=False)

    exposure.to_csv(DATA_REBUILD / "rebuild_bea_summary_tariff_exposure_301.csv", index=False)
    io.to_csv(DATA_REBUILD / "rebuild_bea_input_coefficients_2019.csv", index=False)
    inflation_panel.to_csv(DATA_REBUILD / "rebuild_tradable_nontradable_inflation_panel.csv", index=False)

    input_exposure_summary = (
        merged.groupby(["industry_code", "industry_name"], as_index=False)
        .agg(
            tradable_goods_input_exposure=("tradable_goods_input_exposure", "first"),
            goods_supply_chain_input_exposure=("goods_supply_chain_input_exposure", "first"),
            tradable_goods_downstream_exposure=("tradable_goods_downstream_exposure", "first"),
            goods_supply_chain_downstream_exposure=("goods_supply_chain_downstream_exposure", "first"),
            direct_tariff_max=("tariff_301_direct", "max"),
            output_2025=(
                "total_industry_output_basic_musd",
                lambda x: x[merged.loc[x.index, "year"].eq(2025)].iloc[0]
                if (merged.loc[x.index, "year"] == 2025).any()
                else x.iloc[-1],
            ),
        )
        .sort_values("tradable_goods_input_exposure", ascending=False)
    )
    input_exposure_summary.to_csv(TABLE_DIR / "rebuild_tradable_input_exposure_summary.csv", index=False)

    industry_summary = (
        merged.groupby(["industry_code", "industry_name"], as_index=False)
        .agg(
            direct_tariff_max=("tariff_301_direct", "max"),
            network_tariff_max=("network_tariff_shock", "max"),
            strong_network_tariff_max=("network_tariff_shock_5pct", "max"),
            avg_output_price_growth_2018_2025=(
                "dln_gross_output_price",
                lambda x: x[merged.loc[x.index, "year"].between(2018, 2025)].mean() * 100,
            ),
            avg_input_price_growth_2018_2025=(
                "dln_intermediate_inputs_price",
                lambda x: x[merged.loc[x.index, "year"].between(2018, 2025)].mean() * 100,
            ),
            output_2025=(
                "total_industry_output_basic_musd",
                lambda x: x[merged.loc[x.index, "year"].eq(2025)].iloc[0]
                if (merged.loc[x.index, "year"] == 2025).any()
                else x.iloc[-1],
            ),
        )
        .sort_values("network_tariff_max", ascending=False)
    )
    industry_summary.to_csv(TABLE_DIR / "rebuild_industry_tariff_network_summary.csv", index=False)

    manifest = [
        "# Rebuilt Empirical Data Manifest",
        "",
        "This rebuild keeps the CPI descriptive evidence separate from the industry network price-transmission evidence.",
        "",
        "## Inputs",
        "",
        f"- CPI category panel: `{PROJECT_ROOT / 'data' / 'processed' / 'cpi_annual_normalized.csv'}`",
        f"- Constructed CPI indexes: `{PROJECT_ROOT / 'data' / 'processed' / 'constructed_price_indices.csv'}`",
        f"- CPI Section 301 exposure: `{PROJECT_ROOT / 'data' / 'processed' / 'cpi_category_301_tariff_exposure.csv'}`",
        f"- BEA annual industry panel: `{panel_path}`",
        f"- Luo-style own/upstream/downstream shocks: `{shock_path}`",
        f"- BEA 2019 input coefficients: `{io_path}`",
        f"- Tradable/nontradable CPI inflation proxy: `{tradable_inflation_path}`",
        "",
        "## Methodological choices",
        "",
        "- CPI indexes are used as descriptive boundary evidence, not as the main causal design.",
        "- Industry price regressions use BEA gross-output and intermediate-input price indexes as PPI-like industry price outcomes.",
        "- The preferred shock is an exposure-share design: 2019 tradable-goods input exposure interacted with annual tradable-goods inflation.",
        "- Section 301 tariff exposure is retained as a policy-shock robustness design rather than the only explanation for the 2021-2022 inflation surge.",
        "- Reproduction-cost real wage regressions are deliberately excluded from the rebuilt main empirical design.",
    ]
    (OUTPUT_REBUILD / "rebuild_data_manifest.md").write_text("\n".join(manifest), encoding="utf-8")

def main() -> None:
    ensure_dirs()
    build_cpi_outputs()
    build_industry_outputs()
    print(f"Wrote rebuilt data and tables under {OUTPUT_REBUILD}")


if __name__ == "__main__":
    main()
