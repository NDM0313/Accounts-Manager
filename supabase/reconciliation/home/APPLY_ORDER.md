# Apply order (disposable clone only)

Never default-run against production.

1. `A_schema_preflight.sql` (read-only)
2. `G_bundled_am_modules.sql` — requires `fx_reconciliation.confirm=APPLY_BUNDLED_AM_MODULES`
3. `H_accounting_repairs.sql` — requires `APPLY_ACCOUNTING_REPAIRS`
4. `I_remaining_fixes.sql` — requires `APPLY_REMAINING_FIXES` (A6 recon, A8 partial delivery, policy table)
5. `C_am_privileges_rls.sql` — extend/merge carefully after G (confirm GUC)
6. `D_storage_bucket_policies.sql` — if Storage schema present
7. `tests/synthetic_fixtures.sql`
8. `tests/scenario_01_*.sql` … `scenario_06_*.sql`
9. `E_post_apply_verification.sql`

Disposable runner: `run_disposable_validation.sh clean|reconcile` (Docker `am-fx-validate-pg17`).

Optional earlier core: `B_additive_schema.sql` is superseded for completeness by **G** (G includes softened CREATE IF NOT EXISTS from migrations). Prefer **G** on a fresh disposable DB; on home prod later, use G only after clone proof and conflict review with existing foundation tables.

**Do not** insert rows into `supabase_migrations.schema_migrations` for historical AM versions unless each statement effect is verified.
