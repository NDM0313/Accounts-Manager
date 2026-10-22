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
