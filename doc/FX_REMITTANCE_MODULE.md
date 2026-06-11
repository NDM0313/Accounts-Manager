# FX Remittance / Hawala Module

**Status:** Schema proposed (not applied until migration approved)  
**Supabase project:** `ygidlcqhupmxvsdjmvnf` only  
**Scope:** Internal private ledger tracking — not a public money transfer service.

## Separation from FX Deals

| Module | Purpose |
|--------|---------|
| `fx_deals` | Customer FX currency order → sourcing → delivery |
| `fx_remittances` | Hawala/remittance: sender pays → agent pays receiver |

Do not fold remittance into deals or generic settlement drafts without linking to `fx_remittances`.

## Status machine

```
draft → booked → customer_paid → sent_to_agent → ready_for_payout → paid_out → completed
draft → cancelled
customer_paid → refunded
paid_out → disputed → completed | refunded
```

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
| total_payable | NUMERIC | receive + commission (PKR equiv stored) |
| paid_amount | NUMERIC | Customer paid so far |
| status | enum | See above |
| payout_status | TEXT | pending / partial / paid |
| settlement_status | enum | pending / partial / settled |
| notes | TEXT | Internal |

## Timeline (`fx_remittance_events`)

Event types: `created`, `customer_payment`, `sent_to_agent`, `payout_confirmed`, `agent_settlement`, `refund`, `note`, `status_change`.

Each event may link `linked_transaction_id` after posting.

## Accounting (balanced journals)

**Customer payment** (cash received + commission upfront):

```
Dr Cash/Bank (1110 or currency cash)
Cr 2350 Remittance Liability
Cr 4310 Remittance Commission Income  (if commission > 0)
```

**Payout confirmed** (agent owes receiver):

```
Dr 2350 Remittance Liability
Cr 2100 Agent Payables
```

**Agent settlement**:

```
Dr 2100 Agent Payables
Cr Cash/Bank
```

**Refund**:

```
Dr 2350 Remittance Liability (or 2200 Customer Payables)
Cr Cash/Bank
```

All postings via SECURITY DEFINER RPCs calling `fx_post_transaction` after draft lines are balanced. Closed-day guard enforced.

## COA additions (per company seed in migration)

- `2350` Remittance Liability (under 2300 Settlement Payables group)
- `4310` Remittance Commission Income (under income)

## RPCs

| RPC | Phase |
|-----|-------|
| `fx_generate_remittance_no` | H1 |
| `fx_create_remittance` | H2 |
| `fx_get_remittance_detail` | H2 |
| `fx_list_remittances` | H2 |
| `fx_record_remittance_customer_payment` | H3 |
| `fx_send_remittance_to_agent` | H3 |
| `fx_confirm_remittance_payout` | H3 |
| `fx_settle_remittance_agent` | H3 |
| `fx_refund_remittance` | H3 |
| `fx_cancel_remittance` | H3 |

## Flutter routes

| Route | Screen |
|-------|--------|
| `/remittance` | List |
| `/remittance/new` | New order |
| `/remittance/reports` | Reports hub |
| `/remittance/:id` | Detail / timeline |
| `/remittance/:id/payment` | Confirm customer payment |
| `/remittance/:id/assign-agent` | Send to payout agent |
| `/remittance/:id/payout` | Confirm payout |
| `/remittance/:id/settlement` | Agent settlement |

Feature flag: `FeatureFlags.remittanceWorkflowEnabled`.

## Permissions

Migration adds to admin/manager roles:

- `can_manage_remittance`
- `can_view_remittance_reports`

Posting uses existing `can_post_fx_transaction`.

## Migrations (proposal — do not apply without approval)

1. `202606230001_fx_remittance_module.sql`
2. `202606230002_fx_remittance_posting.sql`

Verify: `supabase/scripts/verify_remittance_module.sql`

## Testing

- `test/domain/remittance_status_test.dart`
- `test/accounting/remittance_posting_test.dart`
- `test/widgets/remittance_list_screen_test.dart`
- Post sample lifecycle in FXDEV; confirm trial balance balances.
