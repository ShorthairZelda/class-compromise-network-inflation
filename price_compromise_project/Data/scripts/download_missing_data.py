#!/usr/bin/env python3
"""Download missing empirical data for the class compromise project.

The script is intentionally conservative:
- keep raw official files under Data/*/raw;
- create light processed CSVs when the transformation is mechanical;
- write a manifest with URLs and timestamps for reproducibility.

Usage:
    python3 scripts/download_missing_data.py \
      --project-root /Users/linian/Desktop/PROJ_completed/proj_class_compromise
"""

from __future__ import annotations

import argparse
import csv
import json
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path


BLS_API_URL = "https://api.bls.gov/publicAPI/v2/timeseries/data/"

# CES industry codes are BLS CES supersector/industry codes. We use broad
# industry groups first; QCEW provides the finer NAICS-based annual panel.
CES_INDUSTRIES = {
    "05000000": "Total private",
    "06000000": "Goods-producing",
    "10000000": "Mining and logging",
    "20000000": "Construction",
    "30000000": "Manufacturing",
    "31000000": "Durable goods",
    "32000000": "Nondurable goods",
    "08000000": "Private service-providing",
    "40000000": "Trade, transportation, and utilities",
    "41420000": "Wholesale trade",
    "42000000": "Retail trade",
    "43000000": "Transportation and warehousing",
    "44220000": "Utilities",
    "50000000": "Information",
    "55000000": "Financial activities",
    "60000000": "Professional and business services",
    "65000000": "Education and health services",
    "70000000": "Leisure and hospitality",
    "80000000": "Other services",
}

CES_DATA_TYPES = {
    "03": "avg_hourly_earnings_all_employees",
    "08": "avg_hourly_earnings_prod_nonsupervisory",
}

USTR_301_PAGES = [
    "https://ustr.gov/issue-areas/enforcement/section-301-investigations/tariff-actions",
    "https://ustr.gov/issue-areas/enforcement/section-301-investigations/section-301-china/34-billion-trade-action",
    "https://ustr.gov/issue-areas/enforcement/section-301-investigations/section-301-china/16-billion-trade-action",
    "https://ustr.gov/issue-areas/enforcement/section-301-investigations/section-301-china/200-billion-trade-action",
    "https://ustr.gov/issue-areas/enforcement/section-301-investigations/section-301-china/300-billion-trade-action",
    "https://ustr.gov/issue-areas/enforcement/section-301-investigations/section-301-china-technology-transfer/china-section-301-tariff-actions-and-exclusion-process/four-year-review",
]


@dataclass
class DownloadRecord:
    name: str
    url: str
    path: str
    status: str
    note: str = ""


class LinkParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.links: list[tuple[str, str]] = []
        self._href: str | None = None
        self._text: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() != "a":
            return
        attrs_dict = dict(attrs)
        self._href = attrs_dict.get("href")
        self._text = []

    def handle_data(self, data: str) -> None:
        if self._href:
            self._text.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() == "a" and self._href:
            self.links.append((self._href, " ".join(self._text).strip()))
            self._href = None
            self._text = []


def request_url(url: str, method: str = "GET", data: bytes | None = None) -> bytes:
    headers = {
        "User-Agent": "Mozilla/5.0 academic research downloader",
        "Accept": "*/*",
    }
    if data is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=90) as resp:
        return resp.read()


def save_url(url: str, path: Path) -> DownloadRecord:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        payload = request_url(url)
        path.write_bytes(payload)
        status = "ok"
        note = f"{len(payload)} bytes"
    except Exception as exc:  # noqa: BLE001
        status = "error"
        note = f"{type(exc).__name__}: {exc}"
    return DownloadRecord(path.name, url, str(path), status, note)


def download_ces(project_root: Path, start_year: int, end_year: int) -> list[DownloadRecord]:
    records: list[DownloadRecord] = []
    raw_dir = project_root / "Data" / "bls" / "ces" / "raw"
    processed_dir = project_root / "Data" / "bls" / "ces" / "processed"
    raw_dir.mkdir(parents=True, exist_ok=True)
    processed_dir.mkdir(parents=True, exist_ok=True)

    series_meta = []
    for industry_code, industry_name in CES_INDUSTRIES.items():
        for data_type, data_type_name in CES_DATA_TYPES.items():
            series_id = f"CES{industry_code}{data_type}"
            series_meta.append(
                {
                    "series_id": series_id,
                    "industry_code": industry_code,
                    "industry_name": industry_name,
                    "data_type": data_type,
                    "data_type_name": data_type_name,
                }
            )

    all_rows = []
    batch_size = 25
    for batch_index in range(0, len(series_meta), batch_size):
        batch = series_meta[batch_index : batch_index + batch_size]
        body = {
            "seriesid": [m["series_id"] for m in batch],
            "startyear": str(start_year),
            "endyear": str(end_year),
        }
        payload = json.dumps(body).encode("utf-8")
        out_path = raw_dir / f"ces_wages_batch_{batch_index // batch_size + 1}.json"
        try:
            response = request_url(BLS_API_URL, method="POST", data=payload)
            out_path.write_bytes(response)
            records.append(DownloadRecord(out_path.name, BLS_API_URL, str(out_path), "ok", f"{len(response)} bytes"))
            parsed = json.loads(response.decode("utf-8"))
            meta_by_id = {m["series_id"]: m for m in series_meta}
            for series in parsed.get("Results", {}).get("series", []):
                sid = series.get("seriesID")
                meta = meta_by_id.get(sid, {})
                for item in series.get("data", []):
                    period = item.get("period", "")
                    if not period.startswith("M"):
                        continue
                    all_rows.append(
                        {
                            **meta,
                            "year": item.get("year"),
                            "period": period,
                            "month": period[1:],
                            "value": item.get("value"),
                        }
                    )
        except Exception as exc:  # noqa: BLE001
            records.append(DownloadRecord(out_path.name, BLS_API_URL, str(out_path), "error", f"{type(exc).__name__}: {exc}"))
        time.sleep(0.25)

    out_csv = processed_dir / "ces_wages_monthly_2016_2025.csv"
    if all_rows:
        with out_csv.open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=list(all_rows[0].keys()))
            writer.writeheader()
            writer.writerows(all_rows)
        records.append(DownloadRecord(out_csv.name, "BLS API processed output", str(out_csv), "ok", f"{len(all_rows)} rows"))
    else:
        records.append(DownloadRecord(out_csv.name, "BLS API processed output", str(out_csv), "error", "no rows returned"))
    return records


def download_qcew(project_root: Path, start_year: int, end_year: int) -> list[DownloadRecord]:
    records: list[DownloadRecord] = []
    raw_dir = project_root / "Data" / "bls" / "qcew" / "raw"
    processed_dir = project_root / "Data" / "bls" / "qcew" / "processed"
    raw_dir.mkdir(parents=True, exist_ok=True)
    processed_dir.mkdir(parents=True, exist_ok=True)

    combined_rows = []
    private_rows = []
    for year in range(start_year, end_year + 1):
        url = f"https://data.bls.gov/cew/data/api/{year}/a/area/US000.csv"
        raw_path = raw_dir / f"qcew_us_annual_{year}.csv"
        rec = save_url(url, raw_path)
        records.append(rec)
        if rec.status != "ok":
            continue
        with raw_path.open("r", encoding="utf-8-sig", newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                if row.get("size_code") != "0":
                    continue
                combined_rows.append(row)
                # QCEW own_code 5 is private ownership and gives the richest
                # NAICS detail for national industry panels.
                if row.get("own_code") == "5":
                    private_rows.append(row)
        time.sleep(0.15)

    out_csv = processed_dir / "qcew_us_annual_all_ownerships_2016_2025.csv"
    if combined_rows:
        with out_csv.open("w", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=list(combined_rows[0].keys()))
            writer.writeheader()
            writer.writerows(combined_rows)
        records.append(DownloadRecord(out_csv.name, "QCEW processed output", str(out_csv), "ok", f"{len(combined_rows)} rows"))
    else:
        records.append(DownloadRecord(out_csv.name, "QCEW processed output", str(out_csv), "error", "no rows returned"))

    private_csv = processed_dir / "qcew_us_annual_private_industries_2016_2025.csv"
    if private_rows:
        with private_csv.open("w", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=list(private_rows[0].keys()))
            writer.writeheader()
            writer.writerows(private_rows)
        records.append(DownloadRecord(private_csv.name, "QCEW processed output", str(private_csv), "ok", f"{len(private_rows)} rows"))
    else:
        records.append(DownloadRecord(private_csv.name, "QCEW processed output", str(private_csv), "error", "no rows returned"))
    return records


def download_ustr_301(project_root: Path, download_attachments: bool = False) -> list[DownloadRecord]:
    records: list[DownloadRecord] = []
    raw_dir = project_root / "Data" / "tariffs" / "ustr_301" / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    links_path = raw_dir / "ustr_301_links.csv"

    found_links = []
    for page_url in USTR_301_PAGES:
        safe_name = page_url.rstrip("/").split("/")[-1] or "index"
        page_path = raw_dir / f"{safe_name}.html"
        rec = save_url(page_url, page_path)
        records.append(rec)
        if rec.status != "ok":
            continue
        parser = LinkParser()
        parser.feed(page_path.read_text(encoding="utf-8", errors="replace"))
        for href, text in parser.links:
            absolute = urllib.parse.urljoin(page_url, href)
            lower = absolute.lower()
            if any(token in lower for token in [".xlsx", ".xls", ".csv", ".zip", ".pdf", "federalregister.gov", "hts", "annex"]):
                found_links.append({"source_page": page_url, "url": absolute, "text": text})

    with links_path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["source_page", "url", "text"])
        writer.writeheader()
        writer.writerows(found_links)
    records.append(DownloadRecord(links_path.name, "parsed USTR pages", str(links_path), "ok", f"{len(found_links)} links"))

    # Download attachment-like files only when requested. USTR pages contain
    # many PDFs and external links; mirroring all of them can be slow. Federal
    # Register pages are recorded in the links CSV but not mirrored here.
    if not download_attachments:
        records.append(
            DownloadRecord(
                "ustr_301_attachments",
                "parsed USTR pages",
                str(raw_dir / "attachments"),
                "skipped",
                "use --download-ustr-attachments to mirror PDF/XLS/CSV/ZIP attachments",
            )
        )
        return records

    seen = set()
    for item in found_links:
        url = item["url"]
        lower = url.lower()
        if url in seen or not any(lower.endswith(ext) for ext in [".xlsx", ".xls", ".csv", ".zip", ".pdf"]):
            continue
        seen.add(url)
        filename = urllib.parse.unquote(url.rstrip("/").split("/")[-1])
        if not filename:
            continue
        rec = save_url(url, raw_dir / "attachments" / filename)
        records.append(rec)
        time.sleep(0.2)
    return records


def write_manifest(project_root: Path, records: list[DownloadRecord]) -> None:
    manifest = {
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "project_root": str(project_root),
        "records": [r.__dict__ for r in records],
    }
    path = project_root / "Data" / "download_manifest.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument("--start-year", type=int, default=2016)
    parser.add_argument("--end-year", type=int, default=2025)
    parser.add_argument("--download-ustr-attachments", action="store_true")
    args = parser.parse_args()

    project_root = args.project_root.expanduser().resolve()
    records: list[DownloadRecord] = []
    records.extend(download_ces(project_root, args.start_year, args.end_year))
    records.extend(download_qcew(project_root, args.start_year, args.end_year))
    records.extend(download_ustr_301(project_root, download_attachments=args.download_ustr_attachments))
    write_manifest(project_root, records)

    ok = sum(1 for r in records if r.status == "ok")
    skipped = sum(1 for r in records if r.status == "skipped")
    err = len(records) - ok - skipped
    print(f"Done. {ok} ok, {err} errors.")
    for r in records:
        print(f"[{r.status}] {r.path} -- {r.note}")
    return 0 if err == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
