# Route coverage — accounting completion (post-4408c6d)

Branch: `feat/home-shared-db-reconciliation`

| Path | Status |
|------|--------|
| `/reports/general-ledger` | **Done** — no viewport truncation; honest cash metrics |
| `/parties` | **Done** — PKR balances + expandable per-currency control nets |
| `/parties/:id/ledger` (agent) | **Done** — PKR statement + FX custody from `fx_list_agent_custody` |
| `/reports/roznamcha` | **Done** — screen + Preview/Print/PDF/CSV export (same builder) |
| `/expenses` | **Done** — list + draft/post via existing engine |
| `/remittance` | **Partial** — list/detail on shared PageHeader/ContentContainer; body cards preserved |
| `/remittance/:id` | **Partial** — FxPageHeader Back/Home; workflow unchanged |
| `/audit` · `/messages` | **Partial** — real implementations; E2E browser limited |

## SQL

| Script | Applied | Backup |
|--------|---------|--------|
| `U_party_balances_roznamcha.sql` | `APPLY_OK_20261022T120351Z` | `fx_sql_backups/U_pre_*` |
| `V_agent_custody_party_currencies.sql` | `APPLY_OK_20261022T130106Z` | `fx_sql_backups/V_pre_20261022T130106Z_agent_custody.sql` |

## Unit tests (focused)

PASS: GL visibility, running balance, month groups, Roznamcha builder/export, agent custody labels.
