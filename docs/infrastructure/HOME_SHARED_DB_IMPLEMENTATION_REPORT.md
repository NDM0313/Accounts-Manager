# Home shared-DB implementation report (updated)

**Branch:** `feat/home-shared-db-reconciliation`  
**HEAD (uncommitted work on):** `4b6bb759e858a63b76231c29443727f211b68a6a`  
**Updated:** 2026-10-21 (completion pass)  

| Gate | Value |
|---|---|
| SQL on production/staging | **NO** |
| New DBs/containers | **0** |
| ERP objects changed | **0** |
| Credential values printed | **NO** |
| Production readiness claim | **NONE** |

---

## Implemented vs proposed

### Implemented (local)

- Flutter API allowlist + privileged-secret exclusion from client env
- Client asset split (`assets/config/client.env`)
- Migration runner fail-closed for home
- **Complete** reconciliation package: **G** (41 migration files, demos excluded) + **H** accounting repairs
- Synthetic DB scenarios 01–05 (executable SQL, not run on prod)
- App/DB contract matrix
- Backend readiness messaging (Settings)
- Currency receipt UI requires `parent_leg_id`
- Remittance repo accepts optional `client_operation_id`

### Proposed / NOT RUN

- Disposable PG17 Docker validation (documented only)
- Applying G/H to any live database
- Auth URL changes on shared GoTrue
- Credential rotation
- Policy decisions P1–P6
- Full delivery RPC proportional rewrite (A8 partial)
- Currency↔PKR recon report RPC (A6)
- Flutter refund button wiring to `fx_refund_remittance`

---

## Key artifacts

- `docs/infrastructure/APP_DATABASE_CONTRACT_MATRIX.md`
- `docs/infrastructure/ACCOUNTING_POLICY_DECISIONS.md`
- `supabase/reconciliation/home/G_bundled_am_modules.sql` (~396KB)
- `supabase/reconciliation/home/H_accounting_repairs.sql`
- `supabase/reconciliation/home/tests/*`
- `supabase/reconciliation/home/TEMPORARY_VALIDATION_PROPOSAL.md`
- `supabase/reconciliation/home/APPLY_ORDER.md`

---

## Local verification (this pass)

| Check | Result |
|---|---|
| `flutter analyze` (changed paths) | PASS |
| Focused config/readiness tests | PASS (17) |
| Full `flutter test` | PASS |
| Client env privileged keys | none |
| Web bundle DB password value | absent (deny-list **names** only, from validation constants) |
| Database scenario SQL | prepared; **NOT RUN** |

---

## Next required action

Authorize **Mac localhost PG17 disposable container** (proposal doc), apply G→H→fixtures→scenarios, then decide whether production apply is warranted. Still no automatic prod apply.
