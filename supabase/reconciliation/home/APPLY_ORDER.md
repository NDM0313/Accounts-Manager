# Apply order (disposable clone only)

Never default-run against production.

1. `A_schema_preflight.sql` (read-only)
2. `G_bundled_am_modules.sql` — requires `fx_reconciliation.confirm=APPLY_BUNDLED_AM_MODULES`
3. `H_accounting_repairs.sql` — requires `APPLY_ACCOUNTING_REPAIRS`
4. `C_am_privileges_rls.sql` — extend/merge carefully after G (confirm GUC)
5. `D_storage_bucket_policies.sql` — if Storage schema present
6. `tests/synthetic_fixtures.sql`
7. `tests/scenario_01_*.sql` … `scenario_05_*.sql`
8. `E_post_apply_verification.sql`

Optional earlier core: `B_additive_schema.sql` is superseded for completeness by **G** (G includes softened CREATE IF NOT EXISTS from migrations). Prefer **G** on a fresh disposable DB; on home prod later, use G only after clone proof and conflict review with existing foundation tables.

**Do not** insert rows into `supabase_migrations.schema_migrations` for historical AM versions unless each statement effect is verified.
