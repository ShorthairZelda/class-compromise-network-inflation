#!/usr/bin/env python3
"""Extract HTS-like codes from USTR Section 301 core notice PDFs.

This creates an auditable intermediate product list. It is not yet a final
tariff panel because Federal Register PDFs contain repeated codes, chapter 98
special rules, and later exclusion/modification notices.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import OrderedDict
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
from pypdf import PdfReader


HTS_RE = re.compile(r"\b(?:\d{4}\.\d{2}\.\d{2}|\d{8})\b")


CORE_NOTICES = [
    {
        "list_id": "list1",
        "description": "$34 billion action / List 1",
        "source_pdf": "Data/tariffs/ustr_301/raw/attachments/2018-13248.pdf",
        "page_ranges": [(5, 9)],
        "page_note": "Formal list in Annex A; excludes Annex C proposed $16bn list.",
        "initial_effective_date": "2018-07-06",
        "initial_rate": 0.25,
    },
    {
        "list_id": "list2",
        "description": "$16 billion action / List 2",
        "source_pdf": "Data/tariffs/ustr_301/raw/attachments/2018-17709.pdf",
        "page_ranges": [(6, 16)],
        "page_note": "Formal list pages only; earlier pages contain background and repeated legal text.",
        "initial_effective_date": "2018-08-23",
        "initial_rate": 0.25,
    },
    {
        "list_id": "list3",
        "description": "$200 billion action / List 3",
        "source_pdf": "Data/tariffs/ustr_301/raw/core_notices/list3_83_FR_47974.pdf",
        "page_ranges": [(30, 219)],
        "page_note": "Annex product-list pages.",
        "initial_effective_date": "2018-09-24",
        "initial_rate": 0.10,
        "rate_note": "Rate increased to 25 percent on 2019-05-10 per 84 FR 20459.",
    },
    {
        "list_id": "list4a",
        "description": "$300 billion action / List 4A",
        "source_pdf": "Data/tariffs/ustr_301/raw/core_notices/list4_notice_modification_4A_4B.pdf",
        "page_ranges": [(4, 26)],
        "page_note": "Annex A legal code-list pages; excludes Annex B product-description duplicate table.",
        "initial_effective_date": "2019-09-01",
        "initial_rate": 0.15,
        "rate_note": "Rate later reduced to 7.5 percent from 2020-02-14.",
    },
    {
        "list_id": "list4b",
        "description": "$300 billion action / List 4B",
        "source_pdf": "Data/tariffs/ustr_301/raw/core_notices/list4_notice_modification_4A_4B.pdf",
        "page_ranges": [(143, 146)],
        "page_note": "Annex C legal code-list pages; excludes Annex D product-description duplicate table.",
        "initial_effective_date": "2019-12-15",
        "initial_rate": 0.15,
        "rate_note": "List 4B duties were suspended in December 2019; do not treat as active without modification data.",
    },
]


def normalize_hts(code: str) -> str:
    digits = re.sub(r"\D", "", code)
    if len(digits) >= 8:
        digits = digits[:8]
        return f"{digits[:4]}.{digits[4:6]}.{digits[6:8]}"
    return code


def extract_codes(pdf_path: Path, page_ranges: list[tuple[int, int]]) -> tuple[list[str], int, int, str]:
    reader = PdfReader(str(pdf_path))
    text_parts = []
    for start, end in page_ranges:
        for page in reader.pages[start - 1 : end]:
            text_parts.append(page.extract_text() or "")
    text = "\n".join(text_parts)
    raw_codes = HTS_RE.findall(text)
    codes = []
    for raw in raw_codes:
        code = normalize_hts(raw)
        # Drop chapter 99 legal mechanism lines and chapter 98 special customs
        # treatment lines from this product-list intermediate.
        if code.startswith("9903.") or code.startswith("9802."):
            continue
        codes.append(code)
    return list(OrderedDict.fromkeys(codes)), len(raw_codes), len(reader.pages), text


def write_diagnostics(rows: list[dict], out_dir: Path) -> None:
    if not rows:
        return
    df = pd.DataFrame(rows)
    by_list = (
        df.assign(chapter=df["hts8"].str[:2])
        .groupby("list_id", as_index=False)
        .agg(
            n_codes=("hts8", "size"),
            n_unique_codes=("hts8", "nunique"),
            n_chapters=("chapter", "nunique"),
            min_hts=("hts8", "min"),
            max_hts=("hts8", "max"),
        )
    )
    dupes = df[df.duplicated("hts8", keep=False)].sort_values(["hts8", "list_id"])
    chapters = (
        df.assign(chapter=df["hts8"].str[:2])
        .groupby(["list_id", "chapter"], as_index=False)
        .size()
        .sort_values(["list_id", "size"], ascending=[True, False])
    )

    by_list.to_csv(out_dir / "ustr_301_core_hts_diagnostics_by_list.csv", index=False)
    chapters.to_csv(out_dir / "ustr_301_core_hts_diagnostics_chapters.csv", index=False)
    dupes.to_csv(out_dir / "ustr_301_core_hts_cross_list_duplicates.csv", index=False)

    lines = [
        "# USTR Section 301 HTS extraction diagnostics",
        "",
        "This is a diagnostic note for the core-list HTS extraction. It is still not a final HTS-year tariff panel because exclusions, suspensions, and later rate changes must be incorporated before final empirical use.",
        "",
        "## Counts by list",
        "",
        by_list.to_markdown(index=False),
        "",
        f"Cross-list duplicate rows: {len(dupes)}",
        "",
        "## Extraction notes",
        "",
    ]
    for notice in CORE_NOTICES:
        ranges = ", ".join(f"{start}-{end}" for start, end in notice["page_ranges"])
        lines.append(f"- {notice['list_id']}: pages {ranges}. {notice.get('page_note', '')}")
    lines.append("")
    lines.append("## Next empirical step")
    lines.append("")
    lines.append("Map these HTS codes to NAICS/BEA industries with import weights, then build an annual active-rate panel for 2018-2025.")
    (out_dir / "ustr_301_core_hts_diagnostics.md").write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    root = args.project_root.expanduser().resolve()
    out_dir = root / "Data" / "tariffs" / "ustr_301" / "processed"
    cleaned_dir = root / "Data" / "cleaned"
    out_dir.mkdir(parents=True, exist_ok=True)
    cleaned_dir.mkdir(parents=True, exist_ok=True)

    rows = []
    manifest = {
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "notes": [
            "Codes are regex-extracted from USTR/Federal Register PDFs.",
            "Chapter 99 and chapter 98 codes are dropped.",
            "This file is an auditable intermediate, not the final HTS-year tariff panel.",
        ],
        "sources": [],
    }
    for notice in CORE_NOTICES:
        pdf_path = root / notice["source_pdf"]
        if not pdf_path.exists():
            manifest["sources"].append({**notice, "status": "missing"})
            continue
        codes, raw_count, n_pages, _text = extract_codes(pdf_path, notice["page_ranges"])
        manifest["sources"].append(
            {
                **notice,
                "status": "ok",
                "pages": n_pages,
                "extracted_page_ranges": notice["page_ranges"],
                "raw_code_mentions": raw_count,
                "unique_product_codes_after_filters": len(codes),
            }
        )
        for code in codes:
            rows.append(
                {
                    "list_id": notice["list_id"],
                    "description": notice["description"],
                    "hts8": code,
                    "initial_effective_date": notice["initial_effective_date"],
                    "initial_rate": notice["initial_rate"],
                    "rate_note": notice.get("rate_note", ""),
                    "page_ranges": ";".join(f"{start}-{end}" for start, end in notice["page_ranges"]),
                    "page_note": notice.get("page_note", ""),
                    "source_pdf": notice["source_pdf"],
                }
            )

    out_csv = out_dir / "ustr_301_core_hts_lists_from_pdfs.csv"
    clean_csv = cleaned_dir / "ustr_301_core_hts_lists_from_pdfs.csv"
    pd.DataFrame(rows).to_csv(out_csv, index=False)
    clean_csv.write_text(out_csv.read_text(encoding="utf-8"), encoding="utf-8")
    write_diagnostics(rows, out_dir)

    manifest_path = out_dir / "ustr_301_core_hts_lists_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")

    print(json.dumps(manifest, indent=2, ensure_ascii=False))
    print(f"Wrote {len(rows)} rows to {out_csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
