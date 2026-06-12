# FX Remittance / Hawala Module

**Status:** H1–H8 deployed (live on Supabase Cloud)  
**Supabase project:** `ygidlcqhupmxvsdjmvnf` only — not `supabase.dincouture.pk` / old ERP VPS  
**Scope:** Internal private ledger tracking — not a public money transfer service.

See also: [H4–H8 upgrade report](../docs/fx-remittance/H4_H8_REMITTANCE_WORKFLOW_UPGRADE_REPORT.md)

## Separation from FX Deals

| Module | Purpose |
|--------|---------|
| `fx_deals` | Customer FX currency order → sourcing → delivery |
| `fx_remittances` | Hawala/remittance: sender pays → agent pays receiver |

Do not fold remittance into deals or generic settlement drafts without linking to `fx_remittances`.

## Deployed migrations

Applied to `ygidlcqhupmxvsdjmvnf` via `supabase db push`:

| Migration | Phase | Purpose |
|-----------|-------|---------|
| `202606230001_fx_remittance_module.sql` | H1 | Tables, enums, COA seed, RLS, create/list/timeline RPCs |
| `202606230002_fx_remittance_posting.sql` | H3 | Posting RPCs (customer payment, payout, settlement, refund, cancel) |
| `202606230003_fx_messaging_module.sql` | M1 | Messaging tables (separate module; shares attachment FKs) |
| `202606230004_fx_attachments_remittance_message.sql` | M2/H8 | `remittance_id`, `remittance_event_id`, `message_id` on `fx_attachments` |
| `202606240001_fx_remittance_posting_type_fix.sql` | H3 fix | Posting uses `settlement_receive` / `settlement_send` (not `manual_journal`) |
| `202606250001_fx_remittance_workflow_h4.sql` | H4 | `commission_mode`, payout metadata, payment/send/payout guards, detail + enriched timeline |
| `202606250002_fx_remittance_agent_h5.sql` | H5 | `linked_party_id`, agent list/search, agent confirm payout |
| `202606250003_fx_remittance_notifications_audit_h6.sql` | H6 | `fx_notifications`, audit helpers, RPC notification wiring |
| `202606250004_fx_remittance_reports_h7.sql` | H7 | Cash flow + statement RPCs (read-only) |
| `202606250005_fx_remittance_agent_detail_access.sql` | H5 | Agent cross-branch detail RPC |

Verify scripts: `supabase/scripts/verify_remittance_module.sql`

## Status machine and guards

```
draft → booked → customer_paid → sent_to_agent → ready_for_payout → paid_out → completed
draft → cancelled
customer_paid → refunded
paid_out → disputed → completed | refunded
```

### Workflow guards (H4+)

| Rule | Behavior |
|------|----------|
| Partial payment | Status stays `booked` until `paid_amount >= total_payable` |
| Send to Agent | Requires `customer_paid` **and** full payment (`paid_amount >= total_payable`) |
| Duplicate payout | `fx_confirm_remittance_payout` and `fx_agent_confirm_remittance_payout` reject if already `paid_out` / `completed` |
| Cancelled / refunded | Cannot receive payout or send to agent |
| Completed / cancelled UI | View/Print receipts only — no workflow actions |

### Commission modes (`commission_mode`)

| Mode | `total_payable` | Customer must pay |
|------|-----------------|-------------------|
| `customer_paid` (default) | `receive_amount + commission_amount` | Full total including commission |
| `internal` | `receive_amount` only | Receive amount; commission tracked internally |

On send-to-agent, a 6-digit `payout_code` is generated for agent verification.

### UI action mapping

| Status | Label | Actions |
|--------|-------|---------|
| `booked` (balance > 0) | Awaiting Payment | Receive Payment, Cancel (if no payments) |
| `customer_paid` | Customer Paid | Send to Agent |
| `sent_to_agent` | Sent to Agent | Confirm Payout (branch) |
| `paid_out` | Payout Confirmed | Mark Settled |
| `completed` / `cancelled` | Settled / Cancelled | View/Print only |

## Fields (header `fx_remittances`)

| Field | Type | Notes |
|-------|------|-------|
| remittance_no | TEXT | Branch-unique, `RM-YYYYMMDD-NNNN` |
| tracking_id | TEXT | Shareable reference (defaults to remittance_no) |
| sender_party_id | UUID | FK `fx_parties` (customer) |
| receiver_name | TEXT | Required |
| receiver_phone | TEXT | Optional |
| receiver_city | TEXT | Optional |
| receiver_country | TEXT | Optional |
| payout_agent_party_id | UUID | FK `fx_parties` (agent) |
| receive_currency | TEXT | Currency customer pays in |
| receive_amount | NUMERIC | |
| payout_currency | TEXT | Currency receiver gets |
| payout_amount | NUMERIC | |
| exchange_rate | NUMERIC | Receive→payout or PKR bridge |
| commission_amount | NUMERIC | Service charge |
| commission_mode | TEXT | `customer_paid` or `internal` |
| total_payable | NUMERIC | Depends on commission_mode |
| paid_amount | NUMERIC | Customer paid so far |
| balance_due | computed | `total_payable - paid_amount` (detail RPC) |
| status | enum | See status machine |
| payout_status | TEXT | pending / partial / paid |
| settlement_status | enum | pending / partial / settled |
| payout_code | TEXT | 6-digit code for agent lookup |
| payout_method | TEXT | cash / bank / mobile |
| payout_confirmed_at | TIMESTAMPTZ | Set on payout confirm |
| notes | TEXT | Internal |
| created_by | UUID | FK auth.users |
| updated_by | UUID | FK auth.users |

## Timeline (`fx_remittance_events`)

Event types: `created`, `customer_payment`, `sent_to_agent`, `payout_confirmed`, `agent_settlement`, `refund`, `note`, `status_change`.

Enriched timeline RPC (`fx_get_remittance_timeline`) returns: event fields, `created_by_name`, `branch_name`, `actor_role`, `attachment_count`.

Each event may link `linked_transaction_id` after posting. Proofs attach via `fx_attachments.remittance_event_id`.

## Accounting (balanced journals)

Posting transaction types: `settlement_receive` (customer payment), `settlement_send` (payout, settlement, refund).

**Customer payment:**

```
Dr Cash/Bank (1110 or currency cash)
Cr 2350 Remittance Liability
Cr 4310 Remittance Commission Income  (if commission > 0 and customer_paid mode)
```

**Payout confirmed** (branch or agent):

```
Dr 2350 Remittance Liability
Cr 2100 Agent Payables
```

**Agent settlement:**

```
Dr 2100 Agent Payables
Cr Cash/Bank
```

**Refund:**

```
Dr 2350 Remittance Liability
Cr Cash/Bank
```

All postings via SECURITY DEFINER RPCs → balanced draft lines → `fx_post_transaction`. Closed-day guard enforced.

### COA accounts

| Code | Name | Role |
|------|------|------|
| 2350 | Remittance Liability | Customer funds held until payout |
| 4310 | Remittance Commission Income | Service charge (customer_paid mode) |
| 2100 | Agent Payables | Amount owed to payout agent |
| 1110 | Cash PKR | Default cash account |

H7 report RPCs are **read-only** — they aggregate events and journal lines; they do not create postings.

## RPCs

| RPC | Phase |
|-----|-------|
| `fx_generate_remittance_no` | H1 |
| `fx_create_remittance` | H2/H4 (includes `p_commission_mode`) |
| `fx_get_remittance_detail` | H4 |
| `fx_get_agent_remittance_detail` | H5 |
| `fx_get_remittance_timeline` | H1/H4 (enriched) |
| `fx_list_remittances` | H2 |
| `fx_list_agent_remittances` | H5 |
| `fx_record_remittance_customer_payment` | H3/H4/H6 |
| `fx_send_remittance_to_agent` | H3/H4/H6 |
| `fx_confirm_remittance_payout` | H3/H4/H6 |
| `fx_agent_confirm_remittance_payout` | H5/H6 |
| `fx_settle_remittance_agent` | H3/H6 |
| `fx_refund_remittance` | H3 |
| `fx_cancel_remittance` | H3/H6 |
| `fx_remittance_cash_flow_summary` | H7 |
| `fx_remittance_branch_statement` | H7 |
| `fx_remittance_agent_statement` | H7 |
| `fx_remittance_customer_statement` | H7 |
| `fx_list_notifications` | H6 |
| `fx_mark_notification_read` | H6 |

## Agent workspace (H5)

| Route | Screen |
|-------|--------|
| `/remittance/agent` | Agent inbox with search |
| `/remittance/agent/:id` | Agent remittance detail |
| `/remittance/agent/:id/confirm` | Agent confirm payout |

**Search:** RM number, tracking ID, receiver name, receiver phone, payout code.

**Setup:**

1. Set `fx_users_profiles.linked_party_id` to the agent's `fx_parties` record.
2. Grant `can_agent_remittance` permission (seeded on admin/manager/agent roles).

Agent RLS allows SELECT on remittances where `payout_agent_party_id = linked_party_id` (cross-branch).

Agent confirm payout uses the same `settlement_send` journals as branch confirm; duplicate and cancelled guards apply.

## Notifications (H6)

**Table:** `fx_notifications` — recipient, remittance_id, event_type, title, body, payload, read_at.

**Events notified:** payment received, sent to agent, payout confirmed, settlement completed, cancellation.

**Flutter:**

| Route / UI | Purpose |
|------------|---------|
| `/notifications` | Inbox |
| Remittance list badge | Unread count |

Recipients: remittance creator + branch users with `can_manage_remittance` or `can_post_fx_transaction`.

Audit trail: `fx_remittance_write_audit` writes to `fx_audit_logs` on each workflow transition.

## Reports (H7)

Route: `/remittance/reports` — tabbed hub.

| Tab | RPC | Content |
|-----|-----|---------|
| Cash Flow | `fx_remittance_cash_flow_summary` | Today received, payouts, commission, pending 2350/2100 |
| Branch Statement | `fx_remittance_branch_statement` | Collections, commission, pending payouts |
| Agent Statement | `fx_remittance_agent_statement` | Assigned, paid, pending settlement |
| Customer Statement | `fx_remittance_customer_statement` | Sender history |

All read-only — no journal impact.

## Attachments and receipts (H8)

**Attachment types** on `fx_attachments`:

| Type | Used on |
|------|---------|
| `payment_receipt` | Customer payment screen |
| `payout_proof` | Agent / branch payout confirm |
| `receiver_proof` | Payout verification |
| `sender_proof` | Order creation (optional) |
| `settlement_proof` | Agent settlement |

**Receipt exports** (`remittance_receipt_builder.dart`):

| Copy | Redaction |
|------|-----------|
| Customer copy | Hides internal commission totals and notes |
| Internal copy | Full amounts, commission mode, balance |
| Agent payout slip | RM, receiver, payout amount, payout code, agent, branch |

Export picker on remittance detail (share icon).

## Flutter routes (branch)

| Route | Screen |
|-------|--------|
| `/remittance` | List (+ notification badge, agent workspace entry) |
| `/remittance/new` | New order (commission mode toggle) |
| `/remittance/reports` | Reports hub |
| `/remittance/:id` | Detail / timeline / proofs |
| `/remittance/:id/payment` | Customer payment |
| `/remittance/:id/assign-agent` | Send to payout agent |
| `/remittance/:id/payout` | Branch confirm payout |
| `/remittance/:id/settlement` | Agent settlement |
| `/notifications` | Notification inbox |

Feature flag: `FeatureFlags.remittanceWorkflowEnabled`.

## Permissions

| Permission | Use |
|------------|-----|
| `can_manage_remittance` | Create, send to agent, cancel |
| `can_post_fx_transaction` | Customer payment, payout, settlement |
| `can_view_remittance_reports` | Reports hub |
| `can_agent_remittance` | Agent workspace, agent payout confirm |

## Testing

Automated (`flutter test` — 154 passing):

- `test/domain/remittance_status_test.dart`
- `test/accounting/remittance_posting_test.dart`
- `test/core/remittance_receipt_test.dart`
- `test/widgets/remittance_list_screen_test.dart`

## Manual QA checklist

- [ ] Create remittance (customer-paid and internal commission modes)
- [ ] Receive **full** customer payment → status `customer_paid`
- [ ] **Partial** payment → Send to Agent blocked (stays `booked`)
- [ ] Send to selected agent → payout code generated
- [ ] Agent searches by RM / phone / name / code at `/remittance/agent`
- [ ] Agent confirms payout with proof → branch notification in `/notifications`
- [ ] Timeline shows timestamps, actors, branch, attachment counts
- [ ] Cash flow report updates after today's activity
- [ ] Agent and customer statements load for selected party
- [ ] Customer vs internal receipt differ (redaction)
- [ ] Agent payout slip shows payout code
- [ ] Duplicate payout blocked (branch and agent)
- [ ] Cancelled remittance cannot be paid out
- [ ] Full lifecycle: create → pay → send → payout → settle → completed
- [ ] Trial balance remains balanced after full lifecycle

## Known limitations

- In-app notifications only — no push/email/SMS
- Voice attachments deferred (same as messaging module)
- One `linked_party_id` per user profile — no multi-agent switch without profile change
- Notification delivery uses refresh/poll — no Realtime subscription on `fx_notifications` yet
- Agent cross-branch attachment upload may need branch staff assistance in some RLS edge cases
- Messaging module (`202606230003`) deployed alongside remittance but documented in `doc/FX_MESSAGING_MODULE.md`

## Rollback notes

**Do not** drop or edit applied migration files in git history on production.

Safe rollback approach:

1. **Flutter only:** Set `FeatureFlags.remittanceWorkflowEnabled = false` to hide UI without touching DB.
2. **Disable agent access:** Remove `can_agent_remittance` from roles or clear `linked_party_id` on profiles.
3. **Database:** Reverting schema requires a **new forward migration** that reverses specific objects — never delete rows from `supabase_migrations.schema_migrations` manually unless you fully understand drift.
4. **Posted transactions:** Remittance journals (`settlement_receive` / `settlement_send`) must be voided through existing transaction void flows — do not delete `fx_remittances` rows that have posted `fx_remittance_transactions`.
5. **Rollback order (if ever needed):** Disable UI → stop new orders → void open draft/posted txs per accounting policy → apply compensating migration — consult `docs/fx-remittance/H4_H8_REMITTANCE_WORKFLOW_UPGRADE_REPORT.md` for object inventory.

Target cloud project for all operations: **`ygidlcqhupmxvsdjmvnf` only**.
