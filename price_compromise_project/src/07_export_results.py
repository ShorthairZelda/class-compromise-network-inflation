#!/usr/bin/env python3
from pathlib import Path

from importlib import import_module

cfg = import_module("00_config")


def main() -> None:
    cfg.ensure_dirs()
    manifest = []
    for folder in [cfg.DATA_PROCESSED, cfg.OUTPUT_TABLES, cfg.OUTPUT_FIGURES, cfg.OUTPUT_REGRESSIONS]:
        for path in sorted(folder.glob("*")):
            if path.is_file():
                manifest.append(f"{path.relative_to(cfg.PROJECT_ROOT)}\t{path.stat().st_size} bytes")
    out = cfg.PROJECT_ROOT / "output" / "result_manifest.txt"
    out.write_text("\n".join(manifest) + "\n", encoding="utf-8")
    print(f"[07_export_results] Wrote {out}")


if __name__ == "__main__":
    main()
