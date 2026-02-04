#!/usr/bin/env python3
"""
Join multiple SQLite .sqlite3 databases into a single CSV by reading the
'measurement' table from each DB and appending rows to one output CSV.

Usage:
  python3 sqlite_to_csv.py --inputs "/path/*.sqlite3" --out merged.csv
  python3 sqlite_to_csv.py --inputs db1.sqlite3 db2.sqlite3 --out merged.csv
"""

import argparse
import csv
import glob
import os
import sqlite3
import sys
from typing import List, Tuple


def list_inputs(patterns: List[str]) -> List[str]:
    files: List[str] = []
    for p in patterns:
        # allow direct file paths or globs
        if any(ch in p for ch in ["*", "?", "["]):
            files.extend(glob.glob(p))
        else:
            files.append(p)
    # normalize + keep only existing files
    out = []
    for f in files:
        f2 = os.path.abspath(f)
        if os.path.isfile(f2):
            out.append(f2)
    # deterministic order
    out = sorted(set(out))
    return out


def table_exists(conn: sqlite3.Connection, table: str) -> bool:
    cur = conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1", (table,)
    )
    return cur.fetchone() is not None


def get_columns(conn: sqlite3.Connection, table: str) -> List[str]:
    cur = conn.execute(f"PRAGMA table_info({table})")
    cols = [row[1] for row in cur.fetchall()]  # (cid, name, type, notnull, dflt, pk)
    return cols


def stream_rows(conn: sqlite3.Connection, table: str, columns: List[str]):
    col_sql = ", ".join([f'"{c}"' for c in columns])
    cur = conn.execute(f'SELECT {col_sql} FROM "{table}"')
    for row in cur:
        yield row


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Merge measurement tables from multiple SQLite DBs into one CSV."
    )
    ap.add_argument(
        "--inputs",
        nargs="+",
        required=True,
        help="Input .sqlite3 files and/or glob patterns (e.g. '/opt/bme/*.sqlite3').",
    )
    ap.add_argument("--out", required=True, help="Output CSV file path.")
    ap.add_argument(
        "--table",
        default="measures",
        help="Table name to export (default: measures).",
    )
    ap.add_argument(
        "--add-source",
        action="store_true",
        help="Add a 'source_db' column with the originating DB filename.",
    )
    ap.add_argument(
        "--strict-columns",
        action="store_true",
        help=(
            "Require identical columns across all DBs. "
            "If not set, the script unions columns and fills missing with empty."
        ),
    )
    args = ap.parse_args()

    inputs = list_inputs(args.inputs)
    if not inputs:
        print("No input files found.", file=sys.stderr)
        return 2

    # Determine output columns
    table = args.table
    all_cols_set = set()
    first_cols = None

    per_db_cols = {}

    for db_path in inputs:
        try:
            conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
            with conn:
                if not table_exists(conn, table):
                    print(f"Skipping {db_path}: table '{table}' not found.", file=sys.stderr)
                    continue
                cols = get_columns(conn, table)
                per_db_cols[db_path] = cols
                if first_cols is None:
                    first_cols = cols
                all_cols_set.update(cols)
        except sqlite3.Error as e:
            print(f"Skipping {db_path}: sqlite error: {e}", file=sys.stderr)
        finally:
            try:
                conn.close()
            except Exception:
                pass

    if not per_db_cols:
        print(f"No databases contained table '{table}'.", file=sys.stderr)
        return 2

    if args.strict_columns:
        ref = first_cols
        bad = []
        for db_path, cols in per_db_cols.items():
            if cols != ref:
                bad.append(db_path)
        if bad:
            print("Column mismatch detected (use --strict-columns off to union columns):", file=sys.stderr)
            print("Reference columns:", ref, file=sys.stderr)
            for b in bad:
                print(f"  {b} columns: {per_db_cols[b]}", file=sys.stderr)
            return 2
        out_cols = list(first_cols)
    else:
        # union columns, stable order: reference first, then extras alphabetically
        ref = first_cols or []
        extras = sorted([c for c in all_cols_set if c not in ref])
        out_cols = list(ref) + extras

    if args.add_source:
        out_cols = ["source_db"] + out_cols

    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)

    wrote_header = False
    total_rows = 0
    exported_dbs = 0

    with open(args.out, "w", newline="", encoding="utf-8") as fcsv:
        writer = csv.writer(fcsv)

        writer.writerow(out_cols)
        wrote_header = True

        for db_path in inputs:
            if db_path not in per_db_cols:
                continue
            cols = per_db_cols[db_path]
            try:
                conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
                with conn:
                    if not table_exists(conn, table):
                        continue

                    # Build per-row output aligned to out_cols (union mode)
                    if args.strict_columns:
                        select_cols = cols
                        for row in stream_rows(conn, table, select_cols):
                            out_row = list(row)
                            if args.add_source:
                                out_row = [os.path.basename(db_path)] + out_row
                            writer.writerow(out_row)
                            total_rows += 1
                    else:
                        select_cols = cols  # read only existing columns from this DB
                        idx = {c: i for i, c in enumerate(select_cols)}
                        for row in stream_rows(conn, table, select_cols):
                            row_map = {c: row[idx[c]] for c in select_cols}
                            out_row = []
                            if args.add_source:
                                out_row.append(os.path.basename(db_path))
                            for c in (out_cols[1:] if args.add_source else out_cols):
                                out_row.append(row_map.get(c, ""))
                            writer.writerow(out_row)
                            total_rows += 1

                exported_dbs += 1
            except sqlite3.Error as e:
                print(f"Skipping {db_path}: sqlite error while exporting: {e}", file=sys.stderr)
            finally:
                try:
                    conn.close()
                except Exception:
                    pass

    if not wrote_header:
        print("Nothing written.", file=sys.stderr)
        return 2

    print(f"Wrote {total_rows} rows from {exported_dbs} DB(s) into: {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
