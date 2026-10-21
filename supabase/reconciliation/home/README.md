# Home shared-database reconciliation (NOT APPLIED)

**Status:** Complete local package for review. **SQL_EXECUTED on prod/stage: NO**

## Packages

| File | Role |
|---|---|
| `A_schema_preflight.sql` | Read-only checks |
| `B_additive_schema.sql` | Early core additive (superseded for full coverage by G) |
| `C_am_privileges_rls.sql` | AM RLS/helpers (allowlisted) |
| `D_storage_bucket_policies.sql` | `fx-attachments` |
| `E_post_apply_verification.sql` | Post-apply checks |
| `F_recovery_rollback.md` | Rollback notes |
| `G_bundled_am_modules.sql` | **Full** AM modules from migrations (41 files, demos excluded) |
| `H_accounting_repairs.sql` | A1–A11 established repairs |
| `APPLY_ORDER.md` | Clone apply sequence |
| `TEMPORARY_VALIDATION_PROPOSAL.md` | Disposable PG17 Mac Docker proposal |
| `tests/` | Synthetic fixtures + scenarios |

## Hard rules

1. No `scripts/apply_migrations.sh` against home.
2. No falsifying `schema_migrations` history.
3. Preserve ERP `fx_currency_purchases*`, `import_fx_*`.
4. Confirmation GUC **plus** database/version identity asserts.
5. Exclude demo seeds / admin impersonation helpers.
