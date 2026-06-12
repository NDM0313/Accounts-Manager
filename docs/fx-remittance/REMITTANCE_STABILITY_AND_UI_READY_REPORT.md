# Remittance Stability and UI Readiness Report

**Date:** 2026-06-12  
**Project:** `ygidlcqhupmxvsdjmvnf` (Supabase Cloud)  
**Branch verified:** `redesign/stitch-premium-ui` → merged to `main` at `8df1f03`  
**UI polish branch:** `ui/remittance-premium-polish`

## 1. PR / main merge status

| Item | Result |
|------|--------|
| PR #1 | Merged to `main` (fast-forward `b86d682` → `8df1f03`) |
| Required commits on main | `af0bb14`, `f53cf1f`, `8df1f03` present |
| GitHub CI on `8df1f03` | `Flutter CI / analyze-and-test` — success |
| Post-merge main HEAD | `8df1f03` (includes H4–H8 + docs + CI fix) |

## 2. Automated test results (Phase 0)

Run on `redesign/stitch-premium-ui` and re-verified on `ui/remittance-premium-polish`:

| Check | Result |
|-------|--------|
| `flutter analyze` | No issues found |
| `dart format --set-exit-if-changed .` | 0 files changed |
| `flutter test` | **154 passed** |
| `FeatureFlags.remittanceWorkflowEnabled` | `true` |
| Target Supabase | `ygidlcqhupmxvsdjmvnf` (from `.env`) |

## 3. Manual QA matrix (Phases 1–2)

Dummy/demo data only. UI walkthrough items marked **Pending human sign-off** where browser session was not recorded in this run; backend guards verified via SQL + unit tests.

### Scenario A — Full lifecycle

| Step | Evidence | Result |
|------|----------|--------|
| Create remittance (customer_paid) | RPC `fx_create_remittance` + UI form | **Pass** (code) / **Pending** (live UI) |
| Full payment → `customer_paid` | SQL: `paid_amount >= total_payable` → status transition | **Pass** |
| Partial payment stays `booked` | `test/domain/remittance_status_test.dart` + SQL guard | **Pass** |
| Send to Agent blocked until full pay | SQL `RAISE EXCEPTION 'Payment incomplete'` + detail UI `isFullyPaid` | **Pass** |
| Send to agent → payout code | SQL `fx_send_remittance_to_agent` generates 6-digit code | **Pass** (code) |
| Agent search RM/phone/name/code | RPC `fx_list_agent_remittances` ILIKE filters | **Pass** (code) |
| Agent confirm payout + proof | RPC + attachment section wired | **Pass** (code) / **Pending** (live) |
| Duplicate payout blocked | SQL guards on branch + agent confirm | **Pass** (code) |
| Notification after payout | `fx_notifications` + inbox route | **Pass** (code) / **Pending** (0 rows in DB) |
| Settlement → completed | Workflow screen + RPC | **Pass** (code) |
| Receipt exports (3 types) | `test/core/remittance_receipt_test.dart` | **Pass** |
| Enriched timeline | `fx_get_remittance_timeline` + `FxTimelineStepCard` | **Pass** (code) |

### Scenario B — Partial / cancel

| Step | Evidence | Result |
|------|----------|--------|
| Partial → stays `booked` | SQL + `isFullyPaid` model test | **Pass** |
| Send to Agent blocked | SQL + no action button unless `customerPaid && isFullyPaid` | **Pass** |
| Cancel (no payments) | Detail cancel dialog + `fx_cancel_remittance` | **Pass** (code) |
| Cancelled cannot payout | SQL `Cannot confirm payout — remittance is cancelled` | **Pass** |

## 4. Agent setup and security (Phase 2)

| Check | Evidence | Result |
|-------|----------|--------|
| `linked_party_id` column | Migration `202606250002` | **Deployed** |
| `can_agent_remittance` permission | Seeded on roles via migration | **Deployed** |
| Agent list scoped to assigned agent | RLS + RPC `payout_agent_party_id = linked_party_id` | **Pass** (code) |
| Cross-agent isolation | RPC raises if not assigned | **Pass** (code) |
| Reports require `can_view_remittance_reports` | H7 RPC permission checks | **Pass** (code) |
| Agent attachment upload | RLS on `fx_attachments` — edge case documented | **Pending live test** |

**Agent setup instructions added in UI:** `FxHelpTipCard` on agent inbox (`/remittance/agent`).

## 5. Accounting and reports (Phase 3)

### Live demo remittance `RM-20260611-0001` (cloud DB)

Customer payment journal (`settlement_receive`):

| Account | Debit PKR | Credit PKR |
|---------|-----------|------------|
| 1110 Cash | 90,000 | — |
| 2350 Remittance Liability | — | 89,900 |
| 4310 Commission Income | — | 100 |

Status: `sent_to_agent` (payout/settlement not yet posted on this record).

### H7 reports

| RPC | Posting impact |
|-----|----------------|
| `fx_remittance_cash_flow_summary` | Read-only |
| `fx_remittance_branch_statement` | Read-only |
| `fx_remittance_agent_statement` | Read-only |
| `fx_remittance_customer_statement` | Read-only |

All four tabs load via `RemittanceReportsScreen` — **Pass** (code).

## 6. Known limitations and decisions (Phase 4)

| Limitation | Before UI redesign | Before live customer use | Decision |
|------------|-------------------|--------------------------|----------|
| In-app notifications only | Accept | Document | Defer push/email |
| Poll/refresh notifications | Accept | Optional Realtime (Flutter-only) | Defer unless ops requires |
| Voice attachments | Defer | Defer | Out of scope |
| Agent `linked_party_id` setup | **Address in UI** | **Required** | Added help tip on agent inbox |
| Agent attachment RLS edge case | Test when agent QA runs | Fix if fails | Proposal-only until confirmed |

## 7. Readiness decision

| Gate | Decision |
|------|----------|
| **Ready for UI redesign** | **Yes** — Phases 0–3 pass at code/DB level; no P0 workflow/accounting bugs found |
| **Ready for real customer use** | **No** — pending full live UI QA (Scenarios A/B in browser), agent profile setup on production users, and notification verification with real workflow events |

## 8. UI redesign (Phase 5)

**Branch:** `ui/remittance-premium-polish`  
**Commit:** `style(fx): polish remittance premium UI`

### Files changed (UI-only)

| File | Changes |
|------|---------|
| `lib/features/remittance/widgets/fx_remittance_card.dart` | **New** — premium list card with pending action hint |
| `lib/features/remittance/remittance_list_screen.dart` | `FxPremiumScaffold`, search, filter chips, today summary |
| `lib/features/remittance/widgets/remittance_summary_card.dart` | `FxAmountCard`, `FxPremiumCard`, section headers |
| `lib/features/remittance/remittance_detail_screen.dart` | `FxPremiumScaffold`, `FxActionTile` workflow actions |
| `lib/features/remittance/new_remittance_order_screen.dart` | Step sections, amount preview, help tip, bottom bar |
| `lib/features/remittance/remittance_customer_payment_screen.dart` | Balance hero, partial-pay tip, bottom bar |
| `lib/features/remittance/remittance_workflow_screens.dart` | Premium scaffold + bottom bar (3 screens) |
| `lib/features/remittance/remittance_reports_screen.dart` | Premium scaffold, `FxAmountCard` grid for cash flow |
| `lib/features/remittance/agent/agent_remittance_inbox_screen.dart` | Search field, help tip, premium cards |
| `lib/features/remittance/agent/agent_remittance_detail_screen.dart` | Amount hero, verification card, warnings |
| `lib/features/remittance/agent/agent_confirm_payout_screen.dart` | Premium scaffold + bottom bar |
| `lib/features/notifications/notifications_inbox_screen.dart` | Premium cards, unread indicator |

**Not changed:** repositories, models, RPC signatures, migrations, status machine, posting logic.

### Tests after UI polish

| Check | Result |
|-------|--------|
| `flutter analyze` | No issues found |
| `flutter test` | 154 passed |

### Rollback

1. Revert `ui/remittance-premium-polish` branch (UI only).
2. Or set `FeatureFlags.remittanceWorkflowEnabled = false` to hide module without DB changes.
3. Posted journals must be voided via standard transaction void flows — do not delete remittance rows with postings.

## 9. Recommended next steps

1. Run browser QA for Scenarios A/B with dummy parties (sign-off checklist in `doc/FX_REMITTANCE_MODULE.md`).
2. Configure one agent user: `linked_party_id` + `can_agent_remittance`.
3. Complete payout → settlement on demo RM and verify 2350/2100 journals end-to-end.
4. Merge `ui/remittance-premium-polish` to `main` after visual review.
5. Optional: Supabase Realtime on `fx_notifications` (Flutter-only, no migration).
