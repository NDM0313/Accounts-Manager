# FX Cash Ledger — Testing & Status

Living checklist for manual QA, backend deploy, and Stitch UX gaps. Update this file when something is missing or fixed.

**Project:** `ygidlcqhupmxvsdjmvnf`  
**Last updated:** 2026-06-11 (Deal leg edit/delete, agent source receipt, demo seed)

---

## Opening Balance workflow

**Migration:** `202606200002_fx_opening_balance_batches.sql` — apply with `./scripts/apply_migrations.sh` before using wizard RPCs.

**Entry points:** Settings → Opening Balances; Accounts Hub → Opening Balances; Dashboard warning when missing/draft; New Transaction sheet → Opening Balances.

**Manual QA (after migration apply + full restart):**

1. Dashboard shows warning if no opening balance posted
2. Open wizard → Step 1 setup (date, warning) → add PKR cash row → add party receivable → Review shows balanced totals
3. Post → Dashboard shows “Opening balance posted”; trial balance includes opening journals
4. Party statement shows opening balance line for party with receivable
5. Share summary from hub / post step

**Automated tests:** `test/accounting/opening_balance_test.dart`, `test/accounting/opening_balance_view_test.dart`

**Verify SQL:** `supabase/scripts/verify_opening_balance_batch.sql`

---

## Manual QA session log

| When | Who | Notes |
|------|-----|-------|
| 2026-06-10 | User confirmed | Login (1), Dashboard (3), draft→post (4) **passed** |
| 2026-06-10 | Agent | Bottom sheet + audit scroll overflow fixes |
| 2026-06-10 | Agent | Attachment InvalidKey fix (`storage_path.dart`); manual journal Dr/Cr exclusivity |
| 2026-06-10 | Agent | Reports hub: COA entry; CSV Share on COA, TB, BS, P&L |
| 2026-06-10 | Agent | Journal balance math fix (invalid dual-side lines); attachment sanitize at picker + path segments |
| 2026-06-10 | Agent | Parties linked to Settlement Send/Receive; party name on ledger/detail/search |
| 2026-06-10 | Agent | Mandatory transaction date on drafts; Accounts nav tab; migration `202606150001` for all txn post types |

**Transaction date + settlement (manual re-test after migration + full restart):**

1. Apply `./scripts/apply_migrations.sh` (includes `202606150001`)
2. New draft → **Transaction date** visible and editable → save → post keeps selected date
3. Settlement Send with party → post succeeds (no Phase 3 error)
4. **Accounts** tab (bottom nav) → Chart of Accounts opens
5. Transaction detail shows **Date** row

**Parties + transactions (manual re-test):**

1. Reports → Parties → create party (e.g. Agent)
2. Ledger → + → **Settlement Send** → select party → post
3. Reports → Parties → tap party → **Party Ledger** shows txn
4. Transaction detail shows **Party** (tap → party ledger); ledger search finds party name

**Note:** Currency Buy/Sell **link to parties** when party is selected (cash or on credit). Use **Chained Exchange** for PKR→USD→AED flows.

**Customer FX Order (New Customer FX Order):** Customer dropdown prefers **Customer**-type parties; if none exist, shows all parties (`code · name · type`) with an info banner. After creating a party, return to the form — list refreshes automatically. Re-open the screen if it was already open with an empty list. **Book Order** requires migration `202606200001` (`fx_generate_deal_no` INT overflow fix); apply `./scripts/apply_migrations.sh` then re-test booking (deal_no format `DL-YYYYMMDD-0001`).

**Back navigation + Deal Detail workflow (manual re-test, Flutter-only — no new migration):**

1. Deal Detail → back arrow returns to `/deals` (even after `context.go` from book order)
2. Party Statement, Agent Source Leg, Rate Entry, Journal Detail → back arrow visible
3. Deal Detail: **What happened?** summary, **Workflow help**, quick links (Customer/Agent statement, Share deal summary)
4. Timeline: tappable Tx link, leg action buttons, proof buttons

**Re-test after full restart (stop `flutter run`, then `flutter run -d chrome`):**

1. Edit txn → upload `Screenshot 2026-01-18 at 12.40.52 AM.png` → should succeed
2. Manual journal → 900 Dr line 1, 900 Cr line 2 → Post → success
3. Same line 900 Dr + 900 Cr → UI shows **Invalid line**, Post disabled
4. Report CSV exports (COA, TB, BS, P&L)

Hot reload (`r`) / hot restart (`R`) alone may not pick up `storage_path.dart` changes.

---

## Backend status

| Item | Status | Notes |
|------|--------|-------|
| All migrations applied (incl. `202606200002`) | [x] | Through `202606210008` on cloud (2026-06-11) |
| `verify_handoff_rpcs.sql` | [x] | Re-verified RC 2026-06-10 — 3 RPCs + `fx-attachments` bucket |
| `verify_posting_smoke.sql` | [x] | Re-verified RC 2026-06-10 — trial balance balanced |
| RLS on all `fx_*` tables | [x] | 18 tables, all `rowsecurity = true` |
| `seed_sample_parties.sql` | [x] | Optional parties for settlement testing |
| Admin bootstrapped | [x] | `ndm313@yahoo.com` → FXDEV / MAIN / admin (verified SELECT) |

---

## Feature matrix

| Area | Screen / feature | Status | Notes |
|------|------------------|--------|-------|
| Auth | Login, profile, branch | Done | Settings → Workspace |
| Dashboard | KPI row, export CSV | Done | Share today's txns |
| Transactions | Draft, post, types | Done | All txn types in draft builder |
| Transactions | Edit / repost | Done | Requires migration RPC |
| Transactions | Void / restore | Done | Reason required |
| Transactions | Attachments | Done | Sanitized at picker + storage path segments |
| Transactions | Share / print receipt | Done | Plain text via Share |
| Parties | List, ledger, CRUD | Done | Settlement Send/Receive links party; Accounts nav tab |
| Navigation | Accounts tab | Done | COA, Parties, Rates, Reports hub links |
| Journal | Manual journal | Done | Invalid dual-side lines blocked; strict post payload |
| Reports | COA, TB, P&L, BS, GL | Done | Hub + CSV Share export |
| Closing | Daily closing | Done | Locked-day banner on detail |
| Settings | Currency management | Done | Settings → Currencies; RPC `fx_create_currency` |
| Navigation | Accounts tab grid | Done | 2-column cubic tiles on Accounts hub |
| Transactions | Chained exchange wizard | Done | PKR→USD→AED linked drafts via `exchange_group_id` |
| Transactions | Buy/Sell party + credit | Done | Agent purchase / customer sale on credit |
| Settings | Theme toggle | Done | Dark Obsidian / Light Precision |
| Settings | Backup export | Partial | Trial balance CSV via Share |
| Opening balance | Wizard + batch RPC | Done | Migration `202606200002`; Settings / Accounts Hub / Dashboard |
| Offline | Drift / SQLite | Out of scope | Future phase |

---

## Manual QA checklist

**Owner: user** — mark `[x]` only after confirmed pass in Chrome.

- [x] Login with bootstrapped user
- [ ] Settings shows company + branch; toggle light/dark theme
- [x] Dashboard: KPIs load, export today's CSV
- [x] New transaction: save draft → attach file → post → complete screen
  - Attach on **edit** screen failed (InvalidKey) — **fixed** picker + path hardening; re-test pending (full restart)
- [ ] Detail: Share receipt, Edit (repost), View Audit, Void
- [ ] Voided txn: Restore with reason
- [ ] Reports hub: Manual Journal, Parties, Trial Balance
- [ ] Parties: create → Settlement Send with party → party ledger shows txn; search by party name
- [ ] Closed day: banner + disabled edit/delete
- [ ] Manual journal: balanced lines post (900 Dr line 1, 900 Cr line 2)
  - Failed: both Dr and Cr on same line showed false “Balanced” — **fixed** balance math + invalid UI; re-test pending

### Fixed pending re-test

| Issue | Screen | Error | Fix |
|-------|--------|-------|-----|
| Attachment upload | Edit transaction | `StorageException InvalidKey` (spaces in filename) | Sanitize at picker + `sanitizeStoragePathSegment` in repo path |
| Manual journal post | Manual Journal | False “Balanced” + `fx_journal_lines_debit_credit_check` | Exclusive totals, invalid line banner, Post disabled, strict XOR payload |

---

## Stitch UX gap table

**Target:** Dark = [Obsidian](../doc/stitch_dark_mode_integration/obsidian/DESIGN.md) · Light = [Precision Ledger](../doc/stitch_dark_mode_integration/precision_ledger/DESIGN.md)

| Screen / component | Spec reference | Gap | Priority | Fixed |
|--------------------|----------------|-----|----------|-------|
| Typography dark | Geist | Geist assets | — | [x] |
| Typography light | Hanken + Inter + JetBrains | Was Geist everywhere | High | [x] |
| Transaction detail actions | Edit solid primary, Delete soft red | Was all OutlinedButton | High | [x] |
| Delete modal | Soft red title | Generic title color | Medium | [x] |
| Audit timeline | Old/new diff | Basic diff panel | Medium | [x] |
| Print / Share | Secondary bordered icons | Was "coming soon" | Medium | [x] |
| Shell / nav | Precision light surfaces | FxColors light tokens | Low | [x] |
| Pixel-perfect all screens | Stitch export | No screenshots in repo | Low | [ ] |

---

## Google Stitch — screenshots & links

```
(Stitch project URL)
(Screen exports folder)
```

---

## Display currency & export (2026-06-10)

**Phase 1:** Display/reporting currency stored in local `SharedPreferences` (`fx_display_currency_code`). Accounting base remains PKR from `fx_companies.base_currency_code`.

**Entry points:** Settings → Currency Settings; report screens (TB, BS, P&L, currency position, account statement) have PKR / display / Both toggle.

**Export:** Unified export sheet (text, CSV, PDF, print) on party statements, deal detail, TB, BS, P&L, currency position, account statement, daily closing (when day closed), transaction receipt.

**Packages:** `pdf`, `printing`, `shared_preferences` (explicit).

**Migrations (applied 2026-06-10 on `ygidlcqhupmxvsdjmvnf`):**

- `202606210001_fx_display_currency.sql` — profile `display_currency_code` + `fx_update_display_currency`
- `202606210002_fx_seed_fxdev_demo_rpc.sql` — `fx_seed_fxdev_demo` stub
- `202606210003_fx_seed_fxdev_demo_impl.sql` — full demo workflow RPC + helpers
- `202606210004_fx_seed_fxdev_demo_fix.sql` — payment fix (book advance at deal time)

App still uses local SharedPreferences for display currency (Phase 1); RPC available for Phase 2 sync.

**Demo seed (applied 2026-06-10 on FXDEV):**

- `supabase/scripts/seed_realistic_fx_demo.sql` — 8 DEMO parties + rates
- `SELECT fx_seed_fxdev_demo('FXDEV_DEMO_SEED')` — **12 posted [DEMO] txs**, deal `DEMO-DIN-USD-001` completed, TB balanced
- `doc/DEMO_SEED_DRY_RUN.md` — dry-run plan + execution log

**Demo workflow manual QA:**

1. Parties → DEMO_ASAD / DEMO_WALI statements (receivable / payable + partial payments)
2. Deals → DEMO-DIN-USD-001 timeline complete
3. Dashboard + Currency position → PKR, USD, AED, CNY, AFN
4. P&L → courier, bank, agent, office expenses
5. Trial balance → balanced; export PDF/CSV

**Workflow guide:** Dashboard card → `/guide/fx-workflow` (10-step FX deal workflow).

**Automated tests:** `test/domain/reporting_currency_converter_test.dart`, `test/core/report_export_test.dart`

**Manual QA:**

1. Settings → Currency Settings → set display to USD → Dashboard hero shows USD with PKR subtitle
2. Trial Balance → toggle Both → export → CSV has PKR + display columns; PDF opens
3. Party statement → Export → customer copy omits internal fields
4. Deal detail → Share internal vs customer statement
5. Transaction detail → export sheet with PDF

---

## Deal workflow — leg edit/delete & agent source (2026-06-11)

**Migrations (applied on `ygidlcqhupmxvsdjmvnf`):**

- `202606210005_fx_currency_receipt_completes_agent_source.sql` — currency receipt completes pending agent source
- `202606210006_fx_deal_leg_edit_delete.sql` — `fx_delete_deal_leg_v2`, `fx_update_deal_leg_v2`
- `202606210007_fx_deal_leg_edit_delete_fix.sql` — rename output column `deal` → `deal_row`
- `202606210008_fx_deal_leg_edit_delete_fix2.sql` — PL/pgSQL composite access fix (42P01)

**App:**

- Timeline pending legs: **⋮ → Edit / Delete** (customer order, delivery, linked tx locked)
- Agent Source pending → **Confirm received** opens Currency receipt screen (proof alone does not complete leg)
- Duplicate leg warning when adding second pending agent source / agent payment

**Automated tests:** `test/domain/deal_leg_permissions_test.dart`, `test/domain/deal_workflow_narrative_test.dart`, `test/domain/deal_workflow_guide_test.dart`

**Verify SQL:** `supabase/scripts/verify_deal_leg_edit_delete.sql`

**Manual QA (user):**

1. Deal DL-20260610-0001 → delete duplicate Agent Source / Agent Payment legs via timeline ⋮
2. Edit pending agent source → change agent/amount → Save changes
3. Pending agent source → Confirm received → Currency receipt → leg completes
4. Full app refresh after migration apply (`R` or restart `flutter run`)

---

## Remaining tasks

| Task | Owner | Notes |
|------|-------|-------|
| Manual QA checklist (below) | User | Theme, void/restore, closed day, reports hub |
| Re-test attachment upload after full restart | User | Edit txn with spaced filename |
| Re-test manual journal 900 Dr / 900 Cr | User | Post + invalid dual-side blocked |
| Stitch pixel-perfect pass | Low | No screenshots in repo |
| Offline / Drift | Future | Out of scope |
| Display currency Phase 2 (profile RPC sync) | Future | Local prefs only today |
| `fx_record_deal_customer_payment` in post allowlist | Future | Demo seed uses book-time advance workaround |

---

## Commands

```bash
flutter pub get && flutter run -d chrome
flutter test && flutter analyze
graphify update .
```
