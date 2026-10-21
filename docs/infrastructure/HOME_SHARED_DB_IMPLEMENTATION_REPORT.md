# Home shared-DB implementation report

**Branch:** `feat/home-shared-db-reconciliation`  
**Updated:** 2026-10-21 (E2E execution pass)

| Gate | Value |
|---|---|
| Disposable PG17 clean+reconcile scenarios | **PASS** |
| Production G→H→I apply | **PASS** (stamp `20261021T192804Z`) |
| ERP purchase/settlement row counts | **unchanged** (5 / 3) |
| FX user bootstrap | **PASS** (`ndm313@yahoo.com` only) |
| Public FX hostname | **NOT configured** — `fx.ndmcore.com` already maps to API (conflict) |
| App static deploy | **PASS** on `127.0.0.1:3099` (`accounts-manager-web`) |

---

## Package

| File | Role |
|---|---|
| `G_bundled_am_modules.sql` | Softened AM modules; FXDEV seed gated by `allow_dev_seed` |
| `H_accounting_repairs.sql` | A1–A11 repairs |
| `I_remaining_fixes.sql` | A6 recon, A8 partial delivery, policy table, cost never=sale |
| `J_prod_bootstrap_company.sql` | NDMFX company + baseline COA when empty |
| `K_bootstrap_fx_user.sql` | Single-email FX membership |
| `run_disposable_validation.sh` | Local Docker `am-fx-validate-pg17` |
| `apply_production_reconcile.sh` | Gated production apply + backup |

Backups: `/home/ndm313/fx_reconcile_backups/` (mode 700).

---

## Client

- `assets/config/client.env` → `https://api.ndmcore.com` + home anon key (**gitignored**)
- Refund UI + `ClientOperationId` + required delivery cost wired
- Fresh web build scanned: no service_role JWT; no DB URL; deny-list **names** only in JS

---

## Limitations

- Full browser Auth login smoke **NOT RUN** (no password automation).
- Auth/Storage HTTP checks: GoTrue health/settings **PASS**; Storage bucket list as anon **PASS** (`[]`).
- Public Flutter URL pending non-conflicting Cloudflare tunnel hostname (do not steal `fx.ndmcore.com` from API).
- P1/P3–P6 unresolved; commission-reversing refund and revaluation **disabled**.
