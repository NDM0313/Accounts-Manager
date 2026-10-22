# UI Design System — Accounts-Manager

**Commit baseline:** unified financial workspace redesign  
**Target:** Flutter web (mobile / tablet / desktop) on `https://fx.ndmcore.com`

## Direction

Calm professional FX operations workspace — navy text, blue actions, neutral grey canvas, white surfaces, subtle borders, minimal shadow. No oversized decorative balance cards, no fictional “Premium / Verified” badges, no invented metrics.

## Light tokens

| Role | Hex | Usage |
|------|-----|--------|
| Background | `#F5F7FB` | Page canvas |
| Surface | `#FFFFFF` | Cards / panels |
| Primary text | `#14263D` | Titles, amounts |
| Secondary text | `#64748B` | Labels, hints |
| Primary action | `#2563EB` | Filled buttons, links |
| Border | `#E2E8F0` | Dividers, card edges |
| Success | `#047857` | Settled / positive confirmation |
| Warning | `#B45309` | Caution |
| Error | `#B91C1C` | Destructive / errors |

Dark theme remains charcoal + blue accents (existing dark tokens).

## Spacing & type

- 8-point spacing (`AppSpacing`); 4-point tweaks allowed
- Panel radius 12–16px (`radiusLg` / `radiusXl`)
- Body 14–16px; avoid tiny all-caps as primary labels
- Money: tabular figures, full precision (never silent “77K” for statement balances)

## Breakpoints (layout width)

| Name | Width |
|------|-------|
| Compact | `< 600` |
| Tablet | `600–1023` |
| Desktop | `≥ 1024` |
| Content max | `1440` |
| Form max | `720–960` |
| Sidebar | `232` |

## Shared components (`lib/core/widgets/system/`)

| Widget | Role |
|--------|------|
| `FxContentContainer` | Max-width page padding |
| `FxPageHeader` | Title + Back/Home + actions |
| `FxCompactMetric` | Content-height KPI tile |
| `FxFilterToolbar` | Search + filter chips |
| `FxMoneyLabel` | Currency + tabular amount |
| `FxLedgerSummaryStrip` | Opening / Debits / Credits / Closing |
| `FxResponsiveLedgerView` | Desktop table + mobile rows with balance-after |
| `FxEmptyState` / `FxLoadingState` / `FxErrorState` | Status surfaces |
| `FxFormSection` / `FxFormActionBar` | Form layout |
| `FxStatusBadge` | Accessible status chip (label + tone) |

Navigation: `FxAppBar` / `FxPageHeader` + `fxSafePop` for child routes; MainShell desktop sidebar / mobile bottom nav. Transaction overflow actions remain in `FxTransactionActionsSheet`.

## Root causes of oversized cards (confirmed)

1. `GridView` + low `childAspectRatio` (width-derived tall cells)
2. Hero cards with large decorative icons / watermark
3. `MainAxisAlignment.center` inside fixed-height grid cells
4. Inconsistent breakpoints (700 vs 900) stretching layouts

Fix: content-driven `Wrap` / `FxResponsiveGrid`, compact metrics, no aspect-ratio financial cards.

## Ledger balance rules

- Canonical: `PartyStatementBuilder` chronological sort (date → txn no → id)
- Running: opening ± cumulative debit/credit per party sign convention
- Newest-first UI may reverse **display** only; `runningBalancePkr` stays chronological balance-after
- Do not recompute from search matches alone
- PDF must match on-screen filtered statement
