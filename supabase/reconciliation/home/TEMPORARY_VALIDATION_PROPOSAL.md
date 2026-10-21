# Temporary validation environment proposal (DO NOT CREATE in this phase)

**Purpose:** Test infrastructure only — **not** a second production stack.  
**NEW_DATABASES_OR_CONTAINERS this phase:** **0**

## Preference

Run on the **user’s Mac** if Docker Desktop is available (keeps production mini PC untouched).

## Engine match

| Need | Spec |
|---|---|
| PostgreSQL | **17.x** (prod is 17.6) — image e.g. `postgres:17.6` |
| Not allowed as substitute | ERP staging `erp-core-db` **PG16** |
| Extensions (minimum for SQL package) | `pgcrypto` / `uuid-ossp` as used by migrations; `auth` schema stubbed in fixtures |
| Full Supabase parity | Optional second step: local Supabase CLI stack for Auth/REST/Storage |

## What PostgreSQL-alone can validate

- Packages G + H + C (policy expressions with `auth.uid()` stub)
- Synthetic scenarios 01–05 (balances, commission, settlement, receipt leg, authz)
- Constraint/trigger/RPC accounting asserts

## What needs service integration later

| Layer | Why |
|---|---|
| GoTrue | Real JWT `role=authenticated`, signup flows |
| PostgREST/Envoy | Grant/RLS as seen by Flutter client |
| Storage API | Signed URL + bucket policies |
| Realtime | Messaging live updates (optional) |

## Suggested Mac Docker shape (commands for future authorization only)

```bash
# NOT EXECUTED NOW — illustrative
docker run -d --name am-fx-validate-pg17 \
  --network none \
  -p 127.0.0.1:55432:5432 \
  -e POSTGRES_PASSWORD=local_only_not_prod \
  -e POSTGRES_DB=postgres \
  --memory=4g --cpus=2 \
  -v am_fx_validate_pg17:/var/lib/postgresql/data \
  postgres:17.6

# Apply: A (read) → G → H → fixtures → scenarios → E
# Cleanup when done:
docker rm -f am-fx-validate-pg17
docker volume rm am_fx_validate_pg17
```

## Data rules

- Prefer **schema-only** + `tests/synthetic_fixtures.sql`
- No production dump copy of customer PII into the laptop volume unless explicitly authorized later
- Disable outbound webhooks/jobs (network none)

## Readiness verification

1. `SELECT version()` starts with PostgreSQL 17  
2. Scenario scripts print `PASS scenario_*`  
3. ERP purchase table checksum unchanged if present  
4. Flutter remains pointed at non-home or non-`FX_SCHEMA_READY` until then

## Resource estimate

2 CPU / 4 GiB RAM / ~10–20 GiB volume for schema+synthetic; more if restoring a sanitized dump.
