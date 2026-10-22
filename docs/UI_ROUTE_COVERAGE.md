# Route coverage checklist — unified design system

Branch: `feat/home-shared-db-reconciliation`  
Legend: **Done** = migrated to shared tokens/components · **Partial** = tokens/shell only · **Pending** = still Stitch-era layout

| Path | Group | Mobile | Tablet | Desktop | Status |
|------|-------|--------|--------|---------|--------|
| `/` | Dashboard | ✓ tokens | ✓ | ✓ sidebar | **Partial** — compact KPIs; activity still legacy density |
| `/deals` | Lists | ✓ | ✓ | ✓ | **Done** — ContentContainer + PageTitleBlock |
| `/ledger` | Lists | ✓ | ✓ | ✓ | **Done** — hub header + ContentContainer |
| `/reports` | Reports | ✓ | ✓ | ✓ | **Done** — tab root PageTitleBlock, no duplicate AppBar |
| `/settings` | Settings | ✓ | ✓ | ✓ | **Done** — ContentContainer + PageTitleBlock |
| `/parties/:id/ledger` | Ledger | ✓ | ✓ | ✓ | **Done** — reference ResponsiveLedgerView |
| `/parties/agents` + agent ledger | Ledger | ✓ | ✓ | ✓ | **Done** — shared ledger |
| `/parties` | Lists | ✓ | ✓ | ✓ | **Done** — PageHeader + FilterToolbar + state views |
| `/transactions/:id` | Details | ✓ chrome | ✓ | ✓ | **Partial** — FxPageScaffold Back/Home; actions sheet retained |
| `/deals/:id` | Details | ✓ | ✓ | ✓ | **Done** — FxPageHeader + state views |
| `/reports/general-ledger` | Reports | ✓ | ✓ | ✓ | **Done** — PageHeader |
| `/reports/trial-balance` | Reports | ✓ | ✓ | ✓ | **Done** — PageHeader |
| `/reports/profit-loss` | Reports | ✓ | ✓ | ✓ | **Done** — PageHeader |
| `/reports/balance-sheet` | Reports | ✓ | ✓ | ✓ | **Done** — PageHeader |
| `/reports/currency-position` | Reports | ✓ | ✓ | ✓ | **Done** — PageHeader |
| `/reports/audit-log` | Reports | ✓ | ✓ | ✓ | **Done** — PageHeader + ContentContainer |
| `/accounts-hub` | Lists | ✓ | ✓ | ✓ | **Done** — ContentContainer + PageTitleBlock |
| `/slips/import` | OCR | ✓ | ✓ | ✓ | **Done** — form-width ContentContainer |
| Forms (`/parties/new`, …) | Forms | ✓ | ✓ | ✓ | **Partial** — party form ContentContainer; FormSection/ActionBar available |
| Remittance / messaging / rates | Mixed | shell | shell | shell | **Partial** — shared shell/tokens; page bodies mostly unchanged |

## Shell

| Width | Behavior | Status |
|-------|----------|--------|
| `< 600` | Bottom nav | Done |
| `600–1023` | Bottom nav + denser content | Done |
| `≥ 1024` | 232px sidebar + top controls | Done |

## Verified accounting (unit)

| Case | Result |
|------|--------|
| Opening 0 + Dr 77000 + Cr 77000 → 0 | **PASS** `party_statement_running_balance_test.dart` |
| Receipt-first then sale → credit intermediate then 0 | **PASS** |
| Newest-first display keeps chronological balance-after | **PASS** + `FxResponsiveLedgerView` |
| Opening balance carries into period | **PASS** existing builder test |
| PDF uses same builder lines | Existing export path (unchanged) |

## Visual verification (viewport screenshots)

| Capture | Status |
|---------|--------|
| Desktop dashboard (sidebar + compact KPIs, AM_DEMO) | Captured after deploy `0918090` → `tmp/ui-redesign-screenshots/` |
| Desktop ledger list | Captured earlier in session (top chrome / list density) |
| Mobile 390 / tablet 768 / 1920 suite | Not fully automated this pass |
| Authenticated party ledger / bank / OCR / forms after redesign | Not captured (Flutter web canvas click/deep-link flaky in automation) |

## Remaining limitations

- Remittance/messaging/rates body layouts not fully restyled (shell/tokens only)
- Dashboard recent-activity density polish
- Deal/new and other form screens not all on `FxFormSection` yet
- Live AM_DEMO pagination / multi-currency ledger click-through not run
- Physical device verification not claimed
- No SQL/schema changes in this redesign deploy
