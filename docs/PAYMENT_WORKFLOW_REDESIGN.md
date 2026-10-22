# Payment workflow redesign

## Duplicate Receive — root cause

Two competing UIs existed:

1. **Stitch** `ReceivePaymentScreen` at `/transactions/receive-payment` (dashboard, party ledger).
2. **Obsidian** `DraftTransactionScreen` at `/transactions/new?type=settlement_receive&mode=customer_receipt` (transaction menu).

The Stitch screen collected party/amount/method then navigated to Draft with **only** `type`, `mode`, `partyId`, and `currency` — amount, bank/cash method, and vault account were discarded. Draft then defaulted settlement control and often the first cash account (`cashCodeForCurrency`), which looked like a second blank form and could silently prefer Cash.

**Fix:** All receive/pay settlement entry points route to `MoneyMovementComposerScreen` (`/transactions/money` and `/transactions/receive-payment`). `/transactions/new` redirects settlement_receive/send to the composer.

## Balance unavailable — root cause

RPCs from scripts U/V referenced non-existent `fx_profiles(user_id)`. Canonical table is `fx_users_profiles` with `id = auth.uid()`. Migration **W** replaces those functions. The Flutter provider no longer swallows RPC errors into `{}`.

## Entry paths

| Action | Route |
|--------|--------|
| Receive Money | `/transactions/money?direction=receive&mode=customer_receipt` |
| Pay Money | `/transactions/money?direction=pay&mode=agent_payment` |
| Legacy receive deep link | `/transactions/receive-payment?partyId=` → composer |
| Scan Slip | `/slips/import` → optional continue in composer |
| Buy / Sell / Transfer / Expense | existing draft routes |

## Deal allocation

Optional searchable deal selector on Receive (customer). When a deal is selected,
posting uses `fx_record_deal_customer_payment` only — no second generic settlement.
General party receipt remains the default when no deal is selected.

## Migration W backups (durable)

Copied from `/tmp` to `/home/ndm313/sql_backups/` on 2026-10-22:

| File | SHA256 |
|------|--------|
| `backup_fx_party_directory_balances_before_W_copied_20261022T1941Z.sql` | `7fc9bca148b90b26c9524a437ccba932bb4719583cd958290281c6af49f3f023` |
| `backup_fx_list_agent_custody_before_W_copied_20261022T1941Z.sql` | `6b8ea4228210e7a3ce4755808c28954a9bc56f1fc0bc9aefec3d15e058331f3b` |
| `backup_fx_party_directory_currency_balances_before_W_copied_20261022T1941Z.sql` | `d63978da0a9458a63a2f58c4815fed23c3fc491c5b95871e270e6f3fa8abec4b` |

Authenticated AM_DEMO check: directory balances match control-account ledgers for
`Auto Code Customer Test 2` (1000) and `DEMO Dubai Agent` (18000). Cross-company
`fx_party_directory_balances` denied with `Unauthorized company access`.
