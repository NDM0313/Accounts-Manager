# Route coverage checklist — accounting workspace completion

Branch: `feat/home-shared-db-reconciliation`  
Legend: **Done** = working workflow · **Partial** = usable but incomplete · **Pending** = placeholder/missing

| Path | Group | Status |
|------|-------|--------|
| `/` | Dashboard | **Partial** — compact KPIs; fake GL “net worth” claims removed from GL header |
| `/accounts` | Chart of Accounts | **Done** — structure/management |
| `/reports/general-ledger` | Account Ledger | **Done** — no viewport truncation; scrollable full account list; honest cash metrics |
| `/parties` | Party Directory | **Done** — role filters + batch PKR balances (`fx_party_directory_balances`) |
| `/parties/:id/ledger` | Party Ledger | **Done** — month groups + running balance + attachments column |
| `/parties/agents` | Party Directory | **Done** — agents filter |
| `/reports/roznamcha` | Roznamcha | **Done** — cash/bank book Opening+In−Out=Closing; internal transfer labeling |
| `/expenses` | Expenses | **Done** — list + new expense → existing draft/post engine; unpaid not faked |
| `/reports/*` | Reports | **Partial** — TB/P&L/BS/currency/audit wired; PDF/CSV for Roznamcha NOT RUN |
| `/audit` · `/reports/audit-log` | Audit | **Done** — existing server audit UI + PageHeader |
| `/messages` | Team Messages | **Partial** — real inbox when feature flag on; never posts journals |
| `/slips/import` | OCR | **Partial** — form container; workflow pre-existing |
| Remittance / rates | Mixed | **Partial** — shell only |

## Shell

| Width | Behavior | Status |
|-------|----------|--------|
| `< 600` | Bottom nav | Done |
| `600–1023` | Bottom nav + denser content | Done |
| `≥ 1024` | 232px sidebar | Done |

## Defect fixed

| Issue | Cause | Fix |
|-------|-------|-----|
| Accounts missing on phone, visible on tablet | GL `filtered.take(4)` when width&lt;900; column `take(12)` | `visibleGlAccounts()` + scrollable full list; breakpoint 1024 |

## SQL applied (home)

| Script | Backup | Status |
|--------|--------|--------|
| `U_party_balances_roznamcha.sql` | `/home/ndm313/fx_sql_backups/U_pre_20261022T120351Z_party_roznamcha.sql` | Applied `APPLY_OK_20261022T120351Z` |

## Tests

| Suite | Result |
|-------|--------|
| `visibleGlAccounts` + GL list scroll visibility | PASS (after scrollUntilVisible) |
| `roznamcha_builder_test` | PASS |
| `ledger_month_groups_test` | PASS |
| `party_statement_running_balance_test` | PASS |
| Live AM_DEMO E2E / physical phone / Roznamcha PDF | **NOT RUN** |
