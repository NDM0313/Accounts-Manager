# Stitch Premium UI — Visual Gap Report

**Date:** 2026-06-11  
**Branch:** `redesign/stitch-premium-ui`

## Root cause

Previous pass updated theme tokens and added premium widgets but **did not redesign** the screens users open daily: `/#/ledger`, app shell/bottom nav, and transaction cards still used Obsidian layouts.

## Before (baseline notes)

- `/#/ledger`: heavy dark segmented tabs, large search, expandable “How FX works” block, separate dark `FxLedgerCard` rows, custom bottom nav without active pill
- Bottom nav: uppercase labels, gray active state, no primary accent pill
- Transaction menu: plain list rows, no Stitch header/subtitle
- Default theme: dark-only (did not match Stitch light-first mockups)

## Stitch vs Flutter gap table

| Screen | Stitch shows | Flutter (before fix) | Fix target |
|--------|--------------|----------------------|------------|
| Ledger / transactions | Light airy list; compact rows; circular icons | Dark blocks; heavy tabs; large cards | `ledger_hub_screen`, `transaction_list_screen`, `FxTransactionCard` |
| Bottom nav | M3 pill indicator; primary active | Custom InkWell columns | `FxPremiumShell` |
| New transaction menu | Grouped sheet; icon boxes; subtitle | Plain list rows | `FxTransactionMenuSheet` |
| Dashboard | Rate strip; KPI grid; light surfaces | Obsidian composition | `dashboard_screen` |
| Customer statement | Summary chips; row ledger | Obsidian header | `party_ledger_screen` |
| Deal detail | Timeline with badges | Custom `_TimelineTile` | `deal_detail_screen` |
| Rate board | 2-col compact tiles | Expandable list rows | `rate_board_screen` |

## After status (post visual correction)

| Screen | Status | Notes |
|--------|--------|-------|
| Ledger / transactions | **Redesigned** | Premium tabs, help tip, search, filter chips, grouped transaction rows |
| Bottom nav | **Redesigned** | Active pill + primary accent |
| Transaction menu | **Redesigned** | Stitch-style header + icon row entries |
| Dashboard | **Updated** | Section headers, premium recent tx cards |
| Statements | **Updated** | Premium summary chips styling |
| Deal detail | **Updated** | Timeline uses premium card layout |
| Rate board | **Updated** | FxRateCard grid for PKR pairs |

## Files changed (visual correction pass)

See git diff on branch. Key areas:

- `lib/core/widgets/premium/*` — shell, transaction card, search, chips, tabs, help, menu sheet
- `lib/features/ledger/ledger_hub_screen.dart`
- `lib/features/transactions/transaction_list_screen.dart`
- `lib/core/widgets/obsidian/fx_obsidian_shell.dart`
- `lib/core/widgets/obsidian/fx_obsidian_bottom_sheet.dart`
- `lib/app/main_shell.dart`
- `lib/features/auth/providers/app_providers.dart` (ThemeMode.system)

## Remaining old widgets (delegates only)

- `FxObsidianReportPanel`, `FxPageScaffold`, `FxHeroBalanceCard`, `FxHubTile` — thin wrappers; layout migrated at call sites where visible

## Manual QA screenshot checklist

Automated: `flutter analyze` + `flutter test` (143 passed). Run locally:

```bash
flutter run -d chrome --web-port=7357
```

Then verify in light + dark (OS theme):

- [ ] `http://localhost:7357/#/ledger` — premium tabs, grouped rows, pill nav
- [ ] Home dashboard — recent transactions cards
- [ ] New transaction menu (FAB)
- [ ] Customer party statement
- [ ] Deal detail timeline
- [ ] New customer FX deal
- [ ] Rate board 2-col grid
- [ ] Bottom nav active pill on each tab
- [ ] No RenderFlex overflow
- [ ] No duplicate key errors

## Out of scope

No Supabase migrations, VPS/SSH, or `.env` changes.
