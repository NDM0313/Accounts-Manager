# Database validation plan (home shared DB)

## Status this phase

| Item | Status |
|---|---|
| SQL executed on production | **NO** |
| SQL executed on ERP staging | **NO** |
| Disposable PG17 validation env | **NOT AVAILABLE / NOT CREATED** |
| DB_VALIDATION | **NOT RUN** |

## Why staging cannot substitute

- Production: `supabase-db` PostgreSQL **17.6**, full Supabase catalog (`auth`, `storage`, …)
- Staging: `erp-core-db` PostgreSQL **16**, database `erp_core`, not a Supabase clone

## Smallest temporary validation environment (test infrastructure only)

**Not** a new production stack. Create only with explicit future authorization:

1. **Engine:** PostgreSQL 17.x (match prod major)
2. **Seed:** restore latest `supabase.dump` (custom format) **or** schema-only dump + synthetic AM fixtures
3. **Resources (estimate):** 2–4 vCPU, 4–8 GiB RAM, 20–40 GiB disk on the mini PC or an isolated volume
4. **Network:** bind to `127.0.0.1` only; no public ports; no Cloudflare route
5. **Synthetic data:** empty AM company `FXDEV`-like fixtures; **no** copy of live customer PII; keep ERP purchase void rows as restored or replace with synthetic twins
6. **Cleanup:** `docker rm -f` + delete volume; confirm no Traefik/CF hostname

## Test sequence on disposable clone

1. Run `home/A_schema_preflight.sql`
2. Set confirm GUC → `home/B_additive_schema.sql`
3. Confirm GUC → `home/C_am_privileges_rls.sql` (extend full policies)
4. Confirm GUC → `home/D_storage_bucket_policies.sql`
5. Run `home/E_post_apply_verification.sql`
6. Port remaining allowlisted RPCs from migrations (non-demo)
7. Run accounting scenario suite (see accounting backlog)
8. Only then propose production apply window

## Explicit non-goals

- Do not create this environment automatically in this phase
- Do not point Flutter at the disposable clone without a separate allowlist entry / dev mode
