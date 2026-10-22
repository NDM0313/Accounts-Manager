# Transaction action matrix

**Branch:** `feat/home-shared-db-reconciliation`  
**RPCs:** `fx_edit_transaction`, `fx_repost_transaction`, `fx_delete_transaction`, `fx_preview_void_transaction` (script `T_`), `fx_restore_deleted_transaction`

## UI labels (transaction detail + More actions)

| Label | When enabled | Backend |
|-------|--------------|---------|
| View details | Always | — |
| Edit draft | Draft + day open | Client draft update + RLS |
| Delete draft | Draft + day open | `fx_delete_transaction` hard delete |
| Edit reference/notes | Posted + day open + not OB | `fx_edit_transaction` |
| Correct entry | Posted + day open + not OB | Edit screen → `fx_repost_transaction` (same txn; voids journals then rebuilds) |
| Void/reverse | Posted + day open | `fx_delete_transaction` soft void + journal void + deal payment unwind (`T_`) |
| View audit history | Always | Audit route |

## Type × state

| Type | Draft edit/delete | Metadata edit | Correct (repost) | Void | Notes |
|------|-------------------|---------------|------------------|------|-------|
| currency_buy/sell | Yes | Yes | Yes | Yes | Downstream consumption not auto-cascaded; void journals only |
| account_transfer | Yes | Yes | Yes | Yes | Both sides via original journals |
| settlement_receive/send | Yes | Yes | Yes | Yes | Deal `customer_payment` legs unwind on void (`T_`) |
| expense / manual_journal | Yes | Yes | Yes | Yes | |
| opening_balance | Draft only | Blocked | Blocked | Blocked in ordinary void | Use `fx_void_opening_balance_batch` |
| revaluation / closing adj | Yes | Yes | Yes | Yes | Day-close may block |

## Closed period

`fx_is_day_closed` blocks post/edit/repost/void. UI disables actions and explains the block. **No silent admin bypass** in app.

## Currency position (dashboard)

From `fx_get_currency_position_extended`:

- **Actual** = vault foreign on accounts 1110–1150 (may be negative)
- **Committed** = open `customer_sale` commitments
- **Required** = `max(0, committed − actual − on_order)`

Example CNY Actual −7K, Committed 275K → Required ≈ 282K before on-order; compact labels may round. Negatives are shown, not hidden.
