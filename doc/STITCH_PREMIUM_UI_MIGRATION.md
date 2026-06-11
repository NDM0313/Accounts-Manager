# Stitch Premium UI Migration

**Source:** [`stitch_fx_ledger_premium_ui_ux/`](../stitch_fx_ledger_premium_ui_ux/) + [`executive_fx_ledger/DESIGN.md`](../stitch_fx_ledger_premium_ui_ux/executive_fx_ledger/DESIGN.md)

**Completed:** 2026-06-11

## Stitch → Flutter mapping

| Stitch folder | Flutter file | Route / entry | Status |
|---------------|--------------|---------------|--------|
| `executive_fx_ledger/DESIGN.md` | `lib/app/theme/*` | global | **Applied** |
| `login_screen` | `lib/features/auth/login_screen.dart` | `/login` | **Applied** |
| `home_dashboard` | `lib/features/dashboard/dashboard_screen.dart` | `/` | **Applied** (visual correction: premium recent tx) |
| `executive_fx_ledger` / ledger hub | `lib/features/ledger/ledger_hub_screen.dart` + `transaction_list_screen.dart` | `/#/ledger` | **Applied** (visual correction pass) |
| `new_transaction_menu` | `lib/core/widgets/premium/fx_transaction_menu_sheet.dart` | bottom sheet | **Applied** (Stitch grouped layout) |
| `new_customer_fx_deal` | `lib/features/deals/new_customer_fx_order_screen.dart` | `/deals/new` | **Applied** |
| `deal_detail_workflow` | `lib/features/deals/deal_detail_screen.dart` | `/deals/:id` | **Applied** |
| `agent_source_leg` | `lib/features/deals/agent_source_leg_screen.dart` | agent-source leg | **Applied** |
| `customer_statement` | `lib/features/parties/party_ledger_screen.dart` | party ledger | **Applied** |
| `agent_statement` | `party_ledger_screen.dart` / agents list | `/parties/agents` | **Applied** |
| `rate_board` | `lib/features/rates/rate_board_screen.dart` | `/rates` | **Applied** |
| `opening_balance_wizard` | `lib/features/opening_balance/opening_balance_wizard_screen.dart` | OB routes | **Applied** |
| `reports_hub` | `lib/features/reports/reports_hub_screen.dart` | `/reports` | **Applied** |
| `receive_payment_1/2` | deal settlement / payment flows | in-deal | **Applied** (via shared panels) |
| `attachment_proof_preview` | `fx_proof_attachments_section.dart` | modal/sheet | **Applied** (badges + sheets) |
| `settings_security` | `lib/features/settings/settings_screen.dart` | settings tab | **Applied** |
| `share_export_options` | `lib/core/export/fx_document_export.dart` | export sheets | **Applied** |
| `transaction_confirmation` | `transaction_complete_screen.dart` | complete route | **Deferred** |
| `general_ledger_overview` | `general_ledger_screen.dart` | GL report | **Deferred** |
| `internal_team_chat` | — | — | **Future** |
| `transaction_audit_chat` | `transaction_audit_screen.dart` | audit | **Deferred** |
| `global_remittance_payout` | — | — | **Future** |
| `share_secure_link_configuration` | — | — | **Future** |

## Design tokens applied

| Token | Light | Dark |
|-------|-------|------|
| Primary | `#1A365D` | `#3B82F6` |
| Secondary | `#3B82F6` | `#60A5FA` |
| Success | `#10B981` | `#10B981` |
| Background | `#F8F9FF` | `#1A1D24` |
| Surface | `#FFFFFF` | `#252830` |
| Typography | Manrope headlines + Inter body | same |
| Card radius | 16px | 16px |
| Button/input radius | 8px | 8px |
| Nav bar height | 56px | 56px |
| Gutter | 12px | 12px |

Replaced Obsidian violet (`#A78BFA`) + Geist dark typography and Hanken Grotesk light headlines.

## Premium widget library

Location: [`lib/core/widgets/premium/`](../lib/core/widgets/premium/)

| Widget | Purpose |
|--------|---------|
| `FxPremiumScaffold` | 64px app bar, back navigation |
| `FxPremiumCard` | 16px bordered surface |
| `FxAmountCard` | KPI / balance hero |
| `FxRateCard` | Rate board tile |
| `FxStatementRow` | Ledger line with tabular amounts |
| `FxTimelineStepCard` | Deal workflow step |
| `FxActionTile` | Grouped menu / hub tile |
| `FxProofBadge` | Attachment count chip |
| `FxSuccessDialog` | Posted/saved feedback |
| `FxBottomActionBar` | Sticky cancel/save |
| `FxResponsiveGrid` | 2–4 col hub grid |
| `FxSectionHeader` | Uppercase section labels |
| `FxStatusBadge` | Pending/completed pills |
| `FxPremiumShell` | App shell + pill bottom nav + desktop top links |
| `FxPremiumPage` | Max-width page wrapper inside shell |
| `FxTransactionCard` | Compact ledger row (40px icon, badges, chevron) |
| `FxPremiumSearchField` | Dense 40px search |
| `FxPremiumFilterChips` | Active / Drafts / Voided / All + Last 30 days |
| `FxPremiumSegmentedTabs` | Pill tabs (Transactions / Account statement) |
| `FxHelpTipCard` | Collapsible “How FX works” tip |
| `FxTransactionMenuSheet` | Stitch-style grouped new-transaction menu |

Obsidian widgets (`fx_obsidian_report_panel`, `fx_hero_balance_card`, `fx_hub_tile`, `fx_page_scaffold`, `fx_obsidian_shell`, `fx_ledger_card`, `fx_filter_chip_row`, `fx_obsidian_bottom_sheet`) delegate to premium equivalents.

## Future modules (no DB / no routes)

The following Stitch screens are **design reference only** — no tables, RPCs, or routes added:

- **Internal team chat** — team messaging UI
- **Global remittance payout** — cross-border payout workflow
- **Share secure link configuration** — expiring customer links

Optional later: “Coming soon” card on dashboard for remittance/chat.

## Files changed (summary)

- Theme: `app_colors.dart`, `app_typography.dart`, `app_theme.dart`, `app_providers.dart` (`ThemeMode.system`)
- Premium: `lib/core/widgets/premium/*` (20+ widgets + barrel)
- Obsidian wrappers: report panel, hero card, hub tile, page scaffold, bottom sheet, party statement row, shell, ledger card, filter chips
- Screens: login, dashboard, **ledger hub**, **transaction list**, deals (new/detail/agent source), reports hub, settings, rate board, OB wizard, export sheet, party ledger
- Tests: `test/widgets/premium/*`, `test/widgets/ledger_hub_screen_test.dart`, `test/widgets/transaction_list_screen_test.dart`, `test/widget_test.dart`

See also [`STITCH_PREMIUM_UI_VISUAL_GAP_REPORT.md`](STITCH_PREMIUM_UI_VISUAL_GAP_REPORT.md) for before/after ledger + nav status.

## QA results

```bash
flutter analyze   # 0 errors (info/warnings only)
flutter test      # 143 passed
graphify update .
```

App launched with `flutter run -d chrome --web-port=7357` for manual pass.

### Manual QA checklist (visual correction — 2026-06-11)

| Screen | Result | Notes |
|--------|--------|-------|
| **Ledger / transactions** | **Pass** | Premium tabs, help tip, grouped rows in bordered card, compact search/chips |
| **Bottom nav** | **Pass** | Active pill + primary accent; title “Executive FX Ledger” |
| Login | **Pass** | Premium card, error container tint, Manrope title |
| Dashboard | **Pass** | Section headers; recent transactions use `FxTransactionCard` |
| Transaction menu | **Pass** | Header + subtitle; Common / FX Deals / Advanced groups |
| New Customer FX Deal | **Pass** | Sticky save bar; payable/paid/receivable panel |
| Deal Detail | **Pass** | Timeline uses `FxTimelineStepCard`; proof/actions preserved |
| Customer Statement | **Pass** | Premium header card + summary chips |
| Rate Board | **Pass** | 2-col `FxRateCard` grid for PKR pairs |
| Settings | **Pass** | Theme follows OS (default system) |
| Global UI | **Pass** | No analyzer errors; widget tests green |

### Prior manual QA (2026-06-11)

### Issues found & fixed (UI-only)

1. **Save button scrolled off-screen** on new deal / agent source forms → moved `FxObsidianActionBar` to scaffold `bottomBar` via new `FxPremiumScaffold.bottomBar`.
2. **Payable/receivable unclear** on new deal → structured summary rows with tabular amounts and “Outstanding receivable” label.
3. **Reference vs deal rate visually merged** → added “Your deal rate” section label above deal rate field in `FxRateValuationSection`.
4. **Harsh `Colors.orange/red/green`** on rates, deals list, workflow warnings → replaced with `context.fx.warning/tertiary/error`.
5. **Settings theme labels stale** (“Obsidian/Precision”) → renamed to “Executive FX”.
6. **Open deals receivable confusing** on party statement → helper text + “outstanding PKR” wording.
7. **KPI tiles tight on mobile** → relaxed grid `childAspectRatio`.
8. **Deal timeline title row** → ellipsis + compact ⋮ menu padding.

### Files changed (manual QA pass)

- `lib/core/widgets/premium/fx_premium_scaffold.dart` — `bottomBar` support
- `lib/core/widgets/obsidian/fx_page_scaffold.dart` — forwards `bottomBar`
- `lib/features/deals/new_customer_fx_order_screen.dart`
- `lib/features/deals/agent_source_leg_screen.dart`
- `lib/features/deals/deal_detail_screen.dart`
- `lib/features/deals/deals_list_screen.dart`
- `lib/features/deals/widgets/deal_workflow_panel.dart`
- `lib/features/parties/party_ledger_screen.dart`
- `lib/features/dashboard/dashboard_kpi_row.dart`
- `lib/features/settings/settings_screen.dart`
- `lib/features/rates/rate_board_screen.dart`
- `lib/features/opening_balance/opening_balance_hub_screen.dart`
- `lib/core/widgets/rates/fx_rate_valuation_section.dart`
- `lib/core/widgets/rates/fx_rate_pair_card.dart`

### Remaining UI gaps

- Transaction complete screen styling pass
- General ledger overview pixel polish
- Tablet/desktop breakpoint tuning vs Stitch screenshots
- Optional Stitch logo asset in `assets/`
- Manual screenshot capture for gap report checklist (browser verification)

## Out of scope (confirmed)

- No Supabase migrations
- No VPS / SSH / old ERP
- No `.env` changes
