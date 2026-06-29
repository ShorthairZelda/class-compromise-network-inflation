#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

SCRIPTS = [
    "01_download_data.py",
    "02_clean_price_data.py",
    "03_construct_indices.py",
    "08_import_section301_to_cpi.py",
    "04_descriptive_figures.py",
    "05_regression_analysis.py",
    "09_regression_tables_R.R",
    "06_labor_conflict_analysis.py",
    "07_export_results.py",
]


def main() -> None:
    src_dir = Path(__file__).resolve().parent
    for script in SCRIPTS:
        print(f"[run_all] Running {script}", flush=True)
        if script.endswith(".R"):
            subprocess.run(["Rscript", str(src_dir / script)], check=True)
        else:
            subprocess.run([sys.executable, str(src_dir / script)], check=True)
    print("[run_all] Pipeline completed.", flush=True)


if __name__ == "__main__":
    main()
