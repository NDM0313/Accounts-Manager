# App ↔ Database contract matrix

**Date:** 2026-10-21 (completion pass)  
**Source:** Flutter `lib/data/repositories/*` + `FeatureFlags` + live audit  

Statuses:

| Status | Meaning |
|---|---|
| EXISTING_COMPATIBLE | Present on home prod with compatible shape (foundation empty tables / enums) |
| RECONCILIATION_INCLUDED | Packaged in `supabase/reconciliation/home/` (G and/or H) — **not applied** |
| MISSING | Still absent from package or requires service not covered by SQL |
| INTENTIONALLY_DISABLED | UI gated / not invoked |

---

## Feature flags vs UI reachability

| Flag | Value | Reachable UI | Backend deps |
|---|---|---|---|
| `dealsWorkflowEnabled` | **true** | Deals screens in router | deals tables + `fx_*_deal*` RPCs |
| `remittanceWorkflowEnabled` | **true** | Remittance list shows disabled text only if false; currently **enabled** | remittance RPCs |
| `messagingEnabled` | **true** | Messages inbox | messaging RPCs |
| `rateSnapshotColumnsEnabled` | **false** | Rate snapshot persistence skipped in payloads | columns in rates/deals — INTENTIONALLY_DISABLED |

No silent omission: remittance/deals/messaging are reachable and therefore **must** be in reconciliation package G (+ accounting overlays H).

---

## Tables / views (direct `.from`)

| Object | Status | Notes |
|---|---|---|
| `fx_companies` | EXISTING_COMPATIBLE | Empty on home; reused |
| `fx_users_profiles` | EXISTING_COMPATIBLE | Empty |
| `fx_accounts` | EXISTING_COMPATIBLE | Empty |
| `fx_parties` | EXISTING_COMPATIBLE | Empty |
| `fx_currencies` | EXISTING_COMPATIBLE | Empty |
| `fx_rates` | EXISTING_COMPATIBLE | Empty |
| `fx_transactions` | RECONCILIATION_INCLUDED | B + G |
| `fx_transaction_lines` | RECONCILIATION_INCLUDED | B + G |
| `fx_journal_entries` / `fx_journal_lines` | RECONCILIATION_INCLUDED | B + G |
| `fx_attachments` | RECONCILIATION_INCLUDED | B + G (+ remittance/message cols in G) |
| `fx_audit_logs` | RECONCILIATION_INCLUDED | B + G |
| `fx_deals` / `fx_deal_legs` | RECONCILIATION_INCLUDED | G |
| `fx_agent_currency_balances` | RECONCILIATION_INCLUDED | **H** (A1–A3) |
| `fx_client_operations` | RECONCILIATION_INCLUDED | **H** (A11) |
| `fx_remittances` (+ events/tx) | RECONCILIATION_INCLUDED | G (via RPC primarily) |
| Messaging / notifications / OB / share tables | RECONCILIATION_INCLUDED | G |
| ERP `fx_currency_purchases*` | EXISTING (ERP) | **PRESERVE** — not AM contract |

---

## RPCs invoked by Flutter (57)

All listed RPCs are included via migration bundle **G** except where **H** replaces the body:

| RPC | Status |
|---|---|
| `fx_post_transaction`, `fx_edit_transaction`, `fx_delete_transaction`, `fx_restore_deleted_transaction`, `fx_repost_transaction`, `fx_post_manual_journal` | RECONCILIATION_INCLUDED (G) |
| `fx_get_trial_balance`, `fx_get_trial_balance_totals`, `fx_get_cash_balances`, `fx_get_general_ledger`, `fx_get_profit_and_loss`, `fx_get_balance_sheet`, `fx_get_currency_position`, `fx_get_currency_position_extended`, `fx_get_closing_preview`, `fx_close_day`, `fx_is_day_closed` | RECONCILIATION_INCLUDED (G) |
| `fx_create_currency`, `fx_deactivate_currency` | RECONCILIATION_INCLUDED (G) |
| `fx_book_customer_deal_v2`, `fx_record_deal_customer_payment`, `fx_add_deal_leg_v2`, `fx_update_deal_leg_v2`, `fx_delete_deal_leg_v2`, `fx_add_settlement_link`, `fx_confirm_deal_delivery`, `fx_get_deal_timeline`, `fx_get_party_deal_open_items` | RECONCILIATION_INCLUDED (G); **`fx_add_deal_leg_v2` repaired in H** |
| Opening balance RPCs | RECONCILIATION_INCLUDED (G) |
| Remittance create/list/detail/timeline/agent/payment/send/payout/settle/cancel/reports/notifications | RECONCILIATION_INCLUDED (G); **payment/settle/refund repaired in H** |
| Messaging RPCs | RECONCILIATION_INCLUDED (G) |
| Secure share RPCs | RECONCILIATION_INCLUDED (G) |
| `fx_refund_remittance` | RECONCILIATION_INCLUDED (H) — **Flutter UI does not call it yet** (status display only) |

Helpers used by RLS/RPCs (`fx_current_profile`, `fx_has_permission`, `fx_same_company`, `fx_same_branch`, `fx_account_id_by_code`, …): RECONCILIATION_INCLUDED (C/G).

---

## Storage

| Item | Status |
|---|---|
| Bucket `fx-attachments` | RECONCILIATION_INCLUDED (D) |
| Path helpers in Flutter | Implemented locally |

---

## Auth / bootstrap

| Item | Status |
|---|---|
| `auth.users` reuse | Design only (proposal doc) |
| Explicit `fx_users_profiles` membership | Required; empty on home |
| Auto-grant on ERP signup | INTENTIONALLY_DISABLED (must not add) |

---

## Totals (this pass)

| Metric | Count |
|---|---|
| Flutter RPCs inventoried | **57** |
| Direct fx_ tables | **14** (+ more via RPC-only) |
| RECONCILIATION_INCLUDED core | G (41 migration files) + H repairs + B/C/D |
| INTENTIONALLY_DISABLED | rate snapshot columns; refund **UI** (RPC present) |
| MISSING after this package | Service integration proof (Auth/Storage E2E); policy-dependent P&L (cost basis/TTP); `FX_SCHEMA_READY` not set |

**DATABASE_CONTRACT_TOTAL:** 57 RPCs + 14 direct tables + storage bucket + auth profile helpers ≈ **75+ contract items** mapped.  
**MISSING_DATABASE_DEPENDENCIES (runtime):** home schema not applied; publishable key unproven; Auth URL ERP coupling unresolved.
