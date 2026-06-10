# FX Cash Ledger — Testing & Status

Living checklist for manual QA, backend deploy, and Stitch UX gaps. Update this file when something is missing or fixed.

**Project:** `ygidlcqhupmxvsdjmvnf`  
**Last updated:** 2026-06-10 (Transaction date + Accounts nav + settlement post fix)

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
| All migrations applied (incl. `202606140001`) | [x] | Applied via `./scripts/apply_migrations.sh` |
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

## Commands

```bash
flutter pub get && flutter run -d chrome
flutter test && flutter analyze
graphify update .
```
