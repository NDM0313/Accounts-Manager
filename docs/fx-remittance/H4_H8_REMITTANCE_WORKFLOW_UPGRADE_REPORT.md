# H4–H8 Remittance Workflow Upgrade Report

**Date:** 2026-06-12  
**Project:** `ygidlcqhupmxvsdjmvnf` (Supabase Cloud)  
**Status:** Implemented and deployed

## Summary

Upgraded the FX Remittance module from a minimal branch workflow to a full operational lifecycle: corrected payment/commission logic, rich detail/timeline UI, agent workspace, in-app notifications, audit trail, reporting, and proof attachments with multi-format receipts.

## Workflow changes

| Status | User-facing label | Allowed actions |
|--------|-------------------|-----------------|
| `booked` (balance > 0) | Awaiting Payment | Receive Payment, Cancel |
| `customer_paid` | Customer Paid | Send to Agent (only when fully paid) |
| `sent_to_agent` | Sent to Agent | Confirm Payout (branch) / Agent confirms in workspace |
| `paid_out` | Payout Confirmed | Mark Settled |
| `completed` / `cancelled` | Settled / Cancelled | View/Print receipts only |

**Commission modes:**
- `customer_paid` — `total_payable = receive + commission`; customer must pay full total before send-to-agent
- `internal` — `total_payable = receive` only; commission tracked separately

**Partial payments** remain `booked` until `paid_amount >= total_payable`.

## Database migrations (additive)

| File | Phase |
|------|-------|
| `202606250001_fx_remittance_workflow_h4.sql` | commission_mode, payout metadata, payment/send/payout guards, detail + timeline RPCs |
| `202606250002_fx_remittance_agent_h5.sql` | linked_party_id, agent list/search, agent confirm payout |
| `202606250003_fx_remittance_notifications_audit_h6.sql` | fx_notifications, audit helpers, RPC patches |
| `202606250004_fx_remittance_reports_h7.sql` | cash flow + statement RPCs (read-only) |
| `202606250005_fx_remittance_agent_detail_access.sql` | agent cross-branch detail RPC |

Prior migrations (`202606230001`–`004`, `202606240001`) were **not modified**.

## Accounting impact

| Change | Journal impact |
|--------|----------------|
| Payment status guard | None — same Dr Cash / Cr 2350 / Cr 4310 via `settlement_receive` |
| Send-to-agent guard | None — status/metadata only |
| Payout duplicate block | None — prevents double Dr 2350 |
| Agent confirm payout | Same `settlement_send` journals as branch confirm |
| Reports H7 | Read-only aggregation |
| Notifications / audit | No journals |

## Files changed (Flutter)

### Models
- `lib/domain/models/fx_remittance.dart` — commission mode, balance due, metadata fields
- `lib/domain/models/fx_remittance_event.dart` — actor, branch, attachment count
- `lib/domain/models/fx_notification.dart`

### Data
- `lib/data/repositories/remittance_repository.dart` — detail, agent, reports
- `lib/data/repositories/notification_repository.dart`
- `lib/data/repositories/attachment_repository.dart` — remittance proofs

### Features
- `lib/features/remittance/remittance_detail_screen.dart` — full header, status actions, export picker
- `lib/features/remittance/widgets/remittance_summary_card.dart`
- `lib/features/remittance/widgets/remittance_attachments_section.dart`
- `lib/features/remittance/new_remittance_order_screen.dart` — commission mode toggle
- `lib/features/remittance/remittance_workflow_screens.dart` — payout method
- `lib/features/remittance/remittance_customer_payment_screen.dart` — balance due + receipt attach
- `lib/features/remittance/remittance_reports_screen.dart` — tabbed reports
- `lib/features/remittance/agent/*` — agent inbox, detail, confirm payout
- `lib/features/notifications/notifications_inbox_screen.dart`
- `lib/features/auth/providers/remittance_providers.dart`
- `lib/app/router.dart` — `/remittance/agent`, `/notifications`

### Export
- `lib/core/export/remittance_receipt_builder.dart` — customer / internal / agent slip

### Tests
- `test/domain/remittance_status_test.dart`
- `test/core/remittance_receipt_test.dart`

## Test results

```
flutter test → 154 passed (all green)
```

## Manual QA checklist

- [ ] Create remittance (customer-paid and internal commission modes)
- [ ] Receive full customer payment → status `customer_paid`
- [ ] Partial payment → Send to Agent blocked
- [ ] Send to selected agent → payout code generated
- [ ] Agent searches by RM / phone / name / code (`/remittance/agent`)
- [ ] Agent confirms payout with proof → branch notification
- [ ] Timeline shows timestamps, actors, branch
- [ ] Cash flow + agent/customer/branch reports load
- [ ] Customer vs internal receipt differ; agent slip shows payout code
- [ ] Duplicate payout blocked
- [ ] Cancelled remittance cannot be paid out

## Known limitations

- In-app notifications only (no push/email)
- Voice attachments deferred
- Agent users need `linked_party_id` on profile + `can_agent_remittance` permission
- Notification delivery uses refresh/poll (no Realtime on `fx_notifications` yet)
- Agent attachment RLS may require branch staff to upload proofs on behalf of agent in some edge cases

## Deployment

Migrations applied via `supabase db push` to `ygidlcqhupmxvsdjmvnf` on 2026-06-12.
