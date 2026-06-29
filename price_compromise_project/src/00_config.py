from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_RAW = PROJECT_ROOT / "data" / "raw"
DATA_PROCESSED = PROJECT_ROOT / "data" / "processed"
DATA_MANUAL = PROJECT_ROOT / "data" / "manual"
OUTPUT_FIGURES = PROJECT_ROOT / "output" / "figures"
OUTPUT_TABLES = PROJECT_ROOT / "output" / "tables"
OUTPUT_REGRESSIONS = PROJECT_ROOT / "output" / "regressions"

START_YEAR = 1984
END_YEAR = 2025
BASE_YEAR = 1984

BLS_CPI_SERIES = {
    "cpi_all": "CUUR0000SA0",
    "durables": "CUUR0000SAD",
    "apparel": "CUUR0000SAA",
    "household_furnishings": "CUUR0000SAH3",
    "new_vehicles": "CUUR0000SETA01",
    "used_cars_trucks": "CUUR0000SETA02",
    "recreation": "CUUR0000SAR",
    "shelter": "CUUR0000SAH1",
    "rent_primary_residence": "CUUR0000SEHA",
    "medical_care": "CUUR0000SAM",
    "education_communication": "CUUR0000SAE",
    "food": "CUUR0000SAF1",
    "energy": "CUUR0000SA0E",
    "transportation": "CUUR0000SAT",
}

FRED_SERIES = {
    "pce_price": "PCEPI",
    "avg_hourly_earnings_prod_nonsup": "AHETPI",
    "median_weekly_earnings": "LES1252881500Q",
    "global_supply_chain_pressure": "GSCPI",
    "import_price_index_all": "IR",
    "transportation_warehousing_ppi": "PCUATRNWRATRNWR",
    "quits_rate": "JTSQUR",
    "consumer_sentiment": "UMCSENT",
    "delinquency_rate": "DRSFRMACBS",
}

CHEAP_GOODS_CATEGORIES = [
    "durables",
    "apparel",
    "household_furnishings",
    "new_vehicles",
    "used_cars_trucks",
    "recreation",
]

LOCAL_REPRODUCTION_CATEGORIES = [
    "shelter",
    "rent_primary_residence",
    "medical_care",
    "education_communication",
]

BASIC_REPRODUCTION_CATEGORIES = [
    "shelter",
    "food",
    "energy",
    "transportation",
    "medical_care",
    "education_communication",
]

CATEGORY_LABELS = {
    "cpi_all": "CPI All Items",
    "durables": "Durable goods",
    "apparel": "Apparel",
    "household_furnishings": "Household furnishings",
    "new_vehicles": "New vehicles",
    "used_cars_trucks": "Used cars and trucks",
    "recreation": "Recreation goods/services",
    "shelter": "Shelter",
    "rent_primary_residence": "Rent",
    "medical_care": "Medical care",
    "education_communication": "Education and communication",
    "food": "Food",
    "energy": "Energy",
    "transportation": "Transportation",
}

TARIFF_EXPOSURE_DEFAULT = {
    "durables": 1,
    "apparel": 1,
    "household_furnishings": 1,
    "new_vehicles": 1,
    "used_cars_trucks": 0,
    "recreation": 1,
    "shelter": 0,
    "rent_primary_residence": 0,
    "medical_care": 0,
    "education_communication": 0,
    "food": 0,
    "energy": 0,
    "transportation": 0,
}

TRADABLE_DEFAULT = {
    **{cat: 1 for cat in CHEAP_GOODS_CATEGORIES},
    **{cat: 0 for cat in LOCAL_REPRODUCTION_CATEGORIES + ["food", "energy", "transportation"]},
}


def ensure_dirs() -> None:
    for path in [
        DATA_RAW,
        DATA_PROCESSED,
        DATA_MANUAL,
        OUTPUT_FIGURES,
        OUTPUT_TABLES,
        OUTPUT_REGRESSIONS,
    ]:
        path.mkdir(parents=True, exist_ok=True)
