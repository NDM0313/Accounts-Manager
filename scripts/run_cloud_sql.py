#!/usr/bin/env python3
"""Run FX ledger SQL on Supabase Cloud (ygidlcqhupmxvsdjmvnf only)."""
from __future__ import annotations

import sys
import urllib.parse
from pathlib import Path

import psycopg2

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_REF = "ygidlcqhupmxvsdjmvnf"
FORBIDDEN = "dincouture"


def strip_sql_comments(text: str) -> str:
    """Remove full-line -- comments (safe for our script files)."""
    return "\n".join(
        line for line in text.splitlines() if not line.strip().startswith("--")
    )


def split_sql(text: str) -> list[str]:
    """Split SQL on semicolons outside dollar-quoted blocks (DO $$ ... $$)."""
    text = strip_sql_comments(text)
    statements: list[str] = []
    buf: list[str] = []
    i = 0
    n = len(text)
    dollar_delim: str | None = None

    def flush() -> None:
        stmt = "".join(buf).strip()
        buf.clear()
        if stmt:
            statements.append(stmt)

    while i < n:
        ch = text[i]

        if dollar_delim is None:
            if ch == "$":
                j = i + 1
                while j < n and (text[j].isalnum() or text[j] == "_"):
                    j += 1
                if j < n and text[j] == "$":
                    dollar_delim = text[i : j + 1]
                    buf.append(dollar_delim)
                    i = j + 1
                    continue
            if ch == ";":
                flush()
                i += 1
                continue
            buf.append(ch)
            i += 1
            continue

        if text.startswith(dollar_delim, i):
            buf.append(dollar_delim)
            i += len(dollar_delim)
            dollar_delim = None
            continue

        buf.append(ch)
        i += 1

    flush()
    return statements


def load_env() -> dict[str, str]:
    env_path = ROOT / ".env"
    if not env_path.exists():
        sys.exit("ABORT: .env not found")
    out: dict[str, str] = {}
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip().strip('"')
    return out


def db_url(env: dict[str, str]) -> str:
    url = env.get("SUPABASE_URL", "")
    if FORBIDDEN in url:
        sys.exit("ABORT: forbidden domain in SUPABASE_URL")
    ref = url.replace("https://", "").split(".")[0]
    if ref != EXPECTED_REF:
        sys.exit(f"ABORT: project ref {ref} != {EXPECTED_REF}")
    password = env.get("SUPABASE_DB_PASSWORD")
    if not password:
        sys.exit("ABORT: SUPABASE_DB_PASSWORD missing")
    pooler = env.get("SUPABASE_DB_POOLER_HOST", "aws-1-ap-southeast-1.pooler.supabase.com")
    enc = urllib.parse.quote(password, safe="")
    return f"postgresql://postgres.{ref}:{enc}@{pooler}:5432/postgres?sslmode=require"


def run_file(conn, path: Path, label: str) -> None:
    print(f"\n######## {label} ########")
    for i, stmt in enumerate(split_sql(path.read_text()), 1):
        with conn.cursor() as cur:
            cur.execute(stmt if stmt.rstrip().endswith(";") else stmt + ";")
            if cur.description:
                cols = [d.name for d in cur.description]
                print(f"\n--- {label} #{i} ---")
                print(" | ".join(cols))
                for row in cur.fetchall():
                    print(" | ".join(str(v) for v in row))


def main() -> None:
    env = load_env()
    url = db_url(env)
    with psycopg2.connect(url) as conn:
        conn.autocommit = True
        run_file(conn, ROOT / "supabase/scripts/bootstrap_admin_by_email.sql", "bootstrap")
        run_file(conn, ROOT / "supabase/scripts/verify_posting_engine.sql", "verify")
    print("\nDone.")


if __name__ == "__main__":
    main()
