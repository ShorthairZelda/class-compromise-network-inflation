#!/usr/bin/env python3
import matplotlib.pyplot as plt
import pandas as pd

from importlib import import_module

cfg = import_module("00_config")


def log(message: str) -> None:
    print(f"[04_descriptive_figures] {message}", flush=True)


def savefig(name: str) -> None:
    for ext in ["png", "pdf"]:
        path = cfg.OUTPUT_FIGURES / f"{name}.{ext}"
        plt.savefig(path, dpi=300, bbox_inches="tight")
        log(f"Saved {path}")
    plt.close()


def figure2_price_divergence_bar(indices: pd.DataFrame) -> None:
    latest_year = int(indices["year"].max())
    order = [
        "CheapGoodsIndex",
        "CPIAllItems",
        "BasicReproductionCostIndex",
        "LocalReproductionCostIndex",
    ]
    labels = {
        "CheapGoodsIndex": "Cheap goods",
        "CPIAllItems": "CPI all items",
        "BasicReproductionCostIndex": "Basic reproduction costs",
        "LocalReproductionCostIndex": "Local reproduction costs",
    }
    plot_df = indices[(indices["year"] == latest_year) & (indices["index_name"].isin(order))].copy()
    plot_df = plot_df.dropna(subset=["index_value"])
    plot_df["index_name"] = pd.Categorical(plot_df["index_name"], categories=order, ordered=True)
    plot_df = plot_df.sort_values("index_name")
    plot_df["label"] = plot_df["index_name"].map(labels)

    colors = ["#7A7A7A", "#BDBDBD", "#4D4D4D", "#1F1F1F"]
    plt.figure(figsize=(9.2, 5.6))
    bars = plt.bar(plot_df["label"], plot_df["index_value"], color=colors[: len(plot_df)])
    for bar in bars:
        height = bar.get_height()
        plt.text(bar.get_x() + bar.get_width() / 2, height + 8, f"{height:.1f}", ha="center", va="bottom", fontsize=9)
    plt.ylabel(f"Price index, {cfg.BASE_YEAR}=100")
    plt.title(f"Price Divergence across Consumption and Reproduction Costs, {latest_year}")
    plt.xticks(rotation=18, ha="right")
    plt.ylim(0, max(plot_df["index_value"]) * 1.18)
    savefig("figure2_price_divergence_bar")


def figure3_timeseries(indices: pd.DataFrame) -> None:
    keep = ["CheapGoodsIndex", "LocalReproductionCostIndex", "BasicReproductionCostIndex", "CPIAllItems"]
    labels = {
        "CheapGoodsIndex": "Cheap goods",
        "LocalReproductionCostIndex": "Local reproduction costs",
        "BasicReproductionCostIndex": "Basic reproduction costs",
        "CPIAllItems": "CPI All Items",
    }
    plt.figure(figsize=(10, 6))
    for name in keep:
        data = indices[indices["index_name"] == name]
        plt.plot(data["year"], data["index_value"], linewidth=2, label=labels[name])
    plt.ylabel(f"Price index, {cfg.BASE_YEAR}=100")
    plt.title("Low-price Goods Channel and Reproduction Costs, 1984-2025")
    plt.legend()
    savefig("figure3_price_divergence_timeseries")


def figure4_recent_inflation(indices: pd.DataFrame) -> None:
    keep = ["CheapGoodsIndex", "BasicReproductionCostIndex", "CPIAllItems"]
    data = indices[(indices["year"] >= 2016) & (indices["index_name"].isin(keep))]
    plt.figure(figsize=(10, 6))
    for name, group in data.groupby("index_name"):
        plt.plot(group["year"], group["inflation"], marker="o", linewidth=2, label=name)
    plt.axvspan(2021, 2022, alpha=0.12, color="gray", label="2021-2022 shock window")
    plt.ylabel("Annual inflation, percent")
    plt.title("Inflation Shock and Reproduction Costs, 2016-2025")
    plt.legend()
    savefig("figure4_inflation_shock_2016_2025")


def figure5_real_wage() -> None:
    path = cfg.DATA_PROCESSED / "real_wage_indices.csv"
    if not path.exists():
        log("real_wage_indices.csv missing; skipping Figure 5.")
        return
    df = pd.read_csv(path)
    keep = ["nominal_wage_index", "CPIRealWage", "ReproductionRealWage"]
    labels = {
        "nominal_wage_index": "Nominal wage index",
        "CPIRealWage": "CPI real wage",
        "ReproductionRealWage": "Reproduction-cost real wage",
    }
    plt.figure(figsize=(10, 6))
    for col in keep:
        if col in df:
            plt.plot(df["year"], df[col], linewidth=2, label=labels[col])
    plt.ylabel(f"Index, {cfg.BASE_YEAR}=100")
    plt.title("US Worker Real Wages under Alternative Price Deflators")
    plt.legend()
    savefig("figure5_real_wage_comparison")


def figure6_supply_chain(indices: pd.DataFrame) -> None:
    fred_path = cfg.DATA_PROCESSED / "fred_series_annual_clean.csv"
    if not fred_path.exists():
        log("FRED annual data missing; skipping Figure 6.")
        return
    fred = pd.read_csv(fred_path)
    for candidate in [
        "global_supply_chain_pressure",
        "import_price_index_all",
        "transportation_warehousing_ppi",
    ]:
        shock = fred[fred["series"] == candidate][["year", "value"]]
        if not shock.empty:
            shock_name = candidate
            break
    else:
        log("No supply-chain or import-cost proxy available; skipping Figure 6.")
        return
    cheap = indices[indices["index_name"] == "CheapGoodsIndex"][["year", "inflation"]]
    df = cheap.merge(shock, on="year", how="inner").dropna()
    if df.empty:
        log("Supply chain data unavailable; skipping Figure 6.")
        return
    plt.figure(figsize=(8, 6))
    plt.scatter(df["value"], df["inflation"], color="#D55E00")
    for _, row in df.iterrows():
        if row["year"] >= 2016:
            plt.text(row["value"], row["inflation"], str(int(row["year"])), fontsize=8)
    plt.xlabel(shock_name.replace("_", " ").title())
    plt.ylabel("Cheap goods inflation, percent")
    plt.title("Supply Chain Pressure and Cheap Goods Inflation")
    savefig("figure6_supply_chain_and_cheap_goods")


def figure7_tariff_exposure() -> None:
    path = cfg.OUTPUT_TABLES / "cpi_category_301_tariff_exposure_summary.csv"
    if not path.exists():
        log("Section 301 exposure summary missing; skipping tariff exposure figure.")
        return
    df = pd.read_csv(path)
    df = df[df["mean_tariff_301_rate"] > 0].copy()
    df = df.sort_values("mean_tariff_301_rate", ascending=False)
    df["label"] = df["category"].map(cfg.CATEGORY_LABELS).fillna(df["category"])
    df["type"] = df["category"].apply(
        lambda x: "Cheap/tradable goods" if x in cfg.CHEAP_GOODS_CATEGORIES else "Reproduction/local costs"
    )
    colors = ["#4D4D4D" if t == "Cheap/tradable goods" else "#8C8C8C" for t in df["type"]]
    plt.figure(figsize=(9.5, 5.8))
    bars = plt.bar(df["label"], df["mean_tariff_301_rate"] * 100, color=colors)
    for bar in bars:
        height = bar.get_height()
        plt.text(bar.get_x() + bar.get_width() / 2, height + 0.5, f"{height:.1f}", ha="center", va="bottom", fontsize=8)
    plt.ylabel("Mean Section 301 exposure, 2018-2025, percent")
    plt.title("Section 301 Tariff Exposure by CPI Category")
    plt.xticks(rotation=28, ha="right")
    plt.ylim(0, max(df["mean_tariff_301_rate"] * 100) * 1.18)
    savefig("figure7_section301_exposure_by_cpi_category")


def main() -> None:
    cfg.ensure_dirs()
    cpi = pd.read_csv(cfg.DATA_PROCESSED / "cpi_annual_normalized.csv")
    indices = pd.read_csv(cfg.DATA_PROCESSED / "constructed_price_indices.csv")
    figure2_price_divergence_bar(indices)
    figure3_timeseries(indices)
    figure4_recent_inflation(indices)
    figure5_real_wage()
    figure6_supply_chain(indices)
    figure7_tariff_exposure()


if __name__ == "__main__":
    main()
