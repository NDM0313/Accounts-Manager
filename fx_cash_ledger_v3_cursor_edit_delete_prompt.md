# Cursor Agent Prompt — FX Cash Ledger V3 Edit/Delete Update

```text
Update FX Cash Ledger V2 to support user-friendly Edit and Delete workflows.

Context:
The user wants daily workflow to be simple. They do not want to manually handle reverse entries. They want to edit and delete transactions like a normal app.

Important:
- Keep the app proper double-entry accounting.
- Do not break Trial Balance, Balance Sheet, P&L, or Ledger.
- Do not force normal users to understand reverse journal entries.
- UI should show simple Edit and Delete buttons.
- Backend should keep audit/version history and accounting safety.

Rules:
1. Draft transactions can be edited and hard deleted.
2. Posted/completed transactions can be edited through amend-and-repost logic.
3. Posted/completed transactions can be deleted through soft delete/void logic.
4. Do not physically remove posted records from database.
5. Keep same visible transaction number when editing.
6. Store old_data and new_data in version/audit tables.
7. Save edit reason and delete reason.
8. Normal reports should exclude deleted/voided transactions by default.
9. Audit reports should include deleted/edited/voided transactions.
10. Trial Balance must remain balanced after edit/delete.
11. Daily Closing lock must prevent normal edit/delete after approval.
12. Manager/Admin can edit/delete same-day posted entries before closing.
13. Super Admin can handle locked/closed-day corrections if allowed.
14. Flutter must call RPC functions for posted edit/delete, not direct table updates.

Add tables:
- fx_transaction_versions
- fx_audit_logs, if not already present

Add/ensure fields in fx_transactions:
- status
- edited_count
- last_edited_by
- last_edited_at
- deleted_by
- deleted_at
- delete_reason
- is_visible
- is_locked

Add RPC functions:
1. fx_edit_transaction(transaction_id, new_data, reason)
2. fx_delete_transaction(transaction_id, reason)
3. fx_restore_deleted_transaction(transaction_id, reason), optional admin only

UI:
- Transaction Detail: Edit, Delete, View Audit
- Edit Transaction screen with date, party, account, currency, amount, rate, fee, notes, attachment, reason
- Delete modal with reason
- Audit timeline showing old value vs new value
- Locked closing warning
- Report filter: Active only / Deleted-voided / All with audit

Testing:
- Editing amount should repost balanced journal lines.
- Editing account should update ledger correctly.
- Editing date should move entry to correct period if not locked.
- Deleting posted transaction should remove effect from normal reports.
- Deleted transaction should remain visible in audit.
- Trial Balance should remain balanced.
- Balance Sheet should remain balanced.
- P&L should update correctly.
- Closed-day edit/delete should be blocked unless admin rule allows.
```
