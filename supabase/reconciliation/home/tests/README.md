# Synthetic database scenario tests

**Status:** Prepared for disposable PG17 validation only.  
**DATABASE_TESTS: NOT RUN** against production or ERP staging.

## Prerequisites

1. Disposable Postgres 17 with Supabase-like roles (`authenticated`, `anon`, `auth.uid()` stub) **or** full local Supabase stack on loopback.
2. Apply packages in order: `A` (read) → `G` → `H` → `C`/`D` as needed → `E`.
3. Load `synthetic_fixtures.sql` (no production data).
4. Run `scenario_*.sql` files; each ends with PASS/FAIL asserts via `RAISE EXCEPTION`.

## What Postgres-alone can test

- Schema, constraints, RPC accounting math, locks, idempotency, RLS expressions (with stubbed `auth.uid()`).

## What needs service integration

- GoTrue login, PostgREST JWT role switching, Storage signed URLs, Realtime — see `../TEMPORARY_VALIDATION_PROPOSAL.md`.
