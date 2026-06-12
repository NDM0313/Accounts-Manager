# Stitch Premium UI — Visual Gap Report

**Date:** 2026-06-12  
**Status:** A2Z replication pass complete

## 22-screen checklist (Stitch → Flutter)

| # | Stitch screen | Flutter | Status |
|---|---------------|---------|--------|
| 1 | login_screen | `login_screen.dart` | **Pass** — logo asset, premium card |
| 2 | home_dashboard | `dashboard_screen.dart` | **Pass** — marquee strip, quick actions, KPI tiles |
| 3 | new_transaction_menu | `fx_transaction_menu_sheet.dart` | **Pass** |
| 4 | new_customer_fx_deal | `new_customer_fx_order_screen.dart` | **Pass** |
| 5 | deal_detail_workflow | `deal_detail_screen.dart` | **Pass** |
| 6 | agent_source_leg | `agent_source_leg_screen.dart` | **Pass** |
| 7 | receive_payment_1 | `receive_payment_screen.dart` | **Pass** — Stitch glass layout + draft flow |
| 8 | receive_payment_2 | confirm dialog + `transaction_complete_screen.dart` | **Pass** |
| 9 | transaction_confirmation | `fx_confirm_transaction_dialog.dart` | **Pass** |
| 10 | rate_board | `rate_board_screen.dart` | **Pass** |
| 11 | general_ledger_overview | `general_ledger_screen.dart` | **Pass** — bento debit/credit header |
| 12 | reports_hub | `reports_hub_screen.dart` | **Pass** |
| 13 | settings_security | `settings_security_screen.dart` | **Pass** — Face ID/PIN local, backup rows |
| 14 | opening_balance_wizard | `opening_balance_wizard_screen.dart` | **Pass** |
| 15 | global_remittance_payout | `remittance_detail_screen.dart` | **Pass** — MTCN header + summary |
| 16 | share_export_options | `fx_export_hub_sheet.dart` | **Pass** |
| 17 | share_secure_link_configuration | `share_secure_link_screen.dart` + migration | **Pass** |
| 18 | internal_team_chat | `conversation_room_screen.dart` | **Pass** — FxChatBubble |
| 19 | transaction_audit_chat | `transaction_audit_screen.dart` | **Pass** — Audit + Chat tabs |
| 20 | agent_statement | `party_ledger_screen.dart` (agent) | **Pass** — FxPartyHeroCard |
| 21 | customer_statement | `party_ledger_screen.dart` (customer) | **Pass** — exposure chips |
| 22 | attachment_proof_preview | `attachment_preview_screen.dart` | **Pass** |

## Design tokens

- M3 Stitch colors in `app_colors.dart` (`#002045` primary, `#0058BE` secondary, tertiary profit green)
- Manrope + Inter typography with tabular data styles
- Logo: `assets/branding/executive_fx_logo.png`

## New premium widgets

`FxMarqueeRateStrip`, `FxQuickActionButton`, `FxGlassCard`, `FxConfirmTransactionDialog`, `FxExposureChipRow`, `FxPartyHeroCard`, `FxChatBubble`, `FxLinkedEntityCard`, `FxPermissionToggleRow`, `FxExpirySegmentedControl`, `FxSettingsSection`, `FxExportHubSheet`

## Backend

- `supabase/migrations/202606240001_fx_secure_share_links.sql` — share links + RPCs
- `SecureShareRepository` in Flutter

## Routes added

- `/transactions/receive-payment`
- `/attachments/:id/preview`
- `/share/configure`
- `/settings/security`

## QA commands

```bash
flutter analyze
flutter test
flutter run -d chrome --web-port=7357
graphify update .
```

Manual: verify light + dark, mobile 390px + desktop 1140px, bottom nav pill on shell tabs.
