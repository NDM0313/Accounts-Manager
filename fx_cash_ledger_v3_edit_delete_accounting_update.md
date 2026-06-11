# FX Cash Ledger V3
## Edit/Delete Friendly Accounting Rules for Flutter + Supabase

**Purpose:**  
This document updates the FX Cash Ledger plan to support practical **Edit** and **Delete** workflows while still keeping accounting, ledger, audit, trial balance, profit & loss, and balance sheet safe.

**Main user requirement:**  
The app should be simple for daily use. Users should be able to:

- Edit the same transaction
- Change date
- Change account
- Change amount/value
- Change currency
- Correct rate
- Delete wrong transaction
- Understand the system easily

**Important accounting reality:**  
Hard delete of posted financial records can break ledger, trial balance, audit, profit/loss, and balance sheet.  
So the best practical solution is:

> Show simple **Edit** and **Delete** buttons in the app, but backend should maintain safe audit/version history.

This gives the user easy workflow and keeps accounting clean.

---

# 1. New Rule: User-Friendly Edit/Delete, Accounting-Safe Backend

## 1.1 Draft transactions

Draft transactions are not posted to ledger.

Allowed actions:

- Edit freely
- Delete freely
- Change date
- Change account
- Change currency
- Change amount
- Change party
- Change note

Because draft does not affect accounting reports.

## 1.2 Posted transactions before daily closing

If transaction is posted but daily closing is not approved yet:

Allow **Edit** from UI.

Backend should do one of these safe methods:

### Recommended method: Amend and Repost

When user edits a posted transaction:

1. Keep same visible transaction number.
2. Save old values in transaction version history.
3. Void old journal lines internally.
4. Recreate corrected journal lines.
5. Keep audit log of old vs new.
6. Recalculate balances/reports.
7. Show user only the corrected transaction.

From user side it feels like normal edit.

From accounting side it is safe.

## 1.3 Posted transactions after daily closing

If daily closing is already approved/locked:

Editing should require manager/admin approval.

Allowed only through:

- Edit Request
- Manager Approval
- System Amendment Entry

UI wording can still be simple:

> “This transaction is already closed. Admin approval required to edit.”

## 1.4 Delete button

Show **Delete** button, but do not physically remove posted records from database.

Use **Soft Delete / Void**.

From user side:

- Transaction disappears from normal list or shows as Deleted.
- Balance and reports are corrected.
- User does not need to understand reverse journal complexity.

From backend side:

- Mark transaction status = deleted/voided.
- Mark old journal entry status = void.
- Create adjustment/reversal internally if needed.
- Store deleted_by, deleted_at, delete_reason.
- Keep audit log.

---

# 2. Statuses

Use these statuses:

```text
draft
posted
edited
voided
deleted
cancelled
locked
```

Recommended display labels:

| Backend Status | User Label |
|---|---|
| draft | Draft |
| posted | Completed |
| edited | Edited |
| voided | Deleted |
| deleted | Deleted |
| cancelled | Cancelled |
| locked | Locked |

Do not show complex accounting wording to normal user.

---

# 3. Edit Workflow

## 3.1 User action

User opens transaction detail and taps **Edit**.

Fields editable:

- Date
- Party/customer/agent
- From account
- To account
- Currency
- Amount
- Rate
- Fee/charges
- Notes
- Attachment/proof
- Expense category
- Settlement status where allowed

## 3.2 System validation

Before saving edit:

- Check user permission
- Check daily closing lock
- Check branch permission
- Check rate lock rule
- Check account balance if negative not allowed
- Check journal balance after edit
- Check old transaction has no dependent settlement if applicable

## 3.3 Save edit

Backend should:

1. Create entry in `fx_transaction_versions`.
2. Store old JSON and new JSON.
3. Mark old journal lines inactive/void or create internal reversal.
4. Repost updated journal lines.
5. Keep same transaction number unless admin chooses “create corrected copy”.
6. Write `fx_audit_logs`.

---

# 4. Delete Workflow

## 4.1 User action

User taps **Delete**.

App asks:

```text
Delete this transaction?
This will remove it from normal reports and update balances.
Reason is required.
```

Fields:

- Delete reason
- Confirm button

## 4.2 Backend action

If draft:

- Hard delete allowed.

If posted:

- Soft delete/void only.
- Journal must be neutralized.
- Trial balance must remain balanced.
- Audit must remain.

Backend should:

1. Set transaction status = `deleted` or `voided`.
2. Save delete reason.
3. Save deleted_by and deleted_at.
4. Void old journal entry or create internal reversal.
5. Exclude from normal operational reports.
6. Include in audit/deleted report.
7. Recalculate balances.

---

# 5. Hard Delete Policy

## Allowed hard delete

Hard delete allowed only for:

- Draft transactions
- Unsynced local drafts
- Failed incomplete records
- Test data in development only

## Not allowed hard delete

Hard delete not allowed for:

- Posted journal entries
- Completed currency buy/sell
- Completed expense
- Completed settlement
- Approved daily closing
- Rate history used by transaction

Reason:

Hard delete can create:

- Trial balance mismatch
- Ledger gap
- Missing audit
- Wrong profit/loss
- Wrong balance sheet
- Cash mismatch
- Fraud risk

---

# 6. Tables Needed for Edit/Delete

## 6.1 fx_transaction_versions

```sql
create table fx_transaction_versions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  branch_id uuid not null,
  transaction_id uuid not null,
  version_no integer not null,
  action text not null check (action in ('created','edited','deleted','voided','restored')),
  old_data jsonb,
  new_data jsonb,
  reason text,
  changed_by uuid,
  changed_at timestamptz default now()
);
```

## 6.2 fx_audit_logs

```sql
create table fx_audit_logs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  branch_id uuid,
  actor_id uuid,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  old_data jsonb,
  new_data jsonb,
  reason text,
  created_at timestamptz default now()
);
```

## 6.3 Add fields to fx_transactions

```sql
alter table fx_transactions
add column if not exists status text default 'draft',
add column if not exists edited_count integer default 0,
add column if not exists last_edited_by uuid,
add column if not exists last_edited_at timestamptz,
add column if not exists deleted_by uuid,
add column if not exists deleted_at timestamptz,
add column if not exists delete_reason text,
add column if not exists is_visible boolean default true,
add column if not exists is_locked boolean default false;
```

---

# 7. RPC Functions Required

Flutter should not directly edit posted accounting data.  
Use server-side RPC functions.

## 7.1 fx_edit_transaction

```text
fx_edit_transaction(
  p_transaction_id,
  p_new_data,
  p_reason
)
```

Responsibilities:

1. Validate permission.
2. Validate daily closing status.
3. Save old version.
4. Validate new transaction.
5. Repost journal safely.
6. Update transaction.
7. Write audit log.
8. Return updated transaction.

## 7.2 fx_delete_transaction

```text
fx_delete_transaction(
  p_transaction_id,
  p_reason
)
```

Responsibilities:

1. Validate permission.
2. If draft: hard delete allowed.
3. If posted: soft delete/void.
4. Neutralize journal effect.
5. Write audit log.
6. Hide from normal reports.
7. Return success.

## 7.3 fx_restore_deleted_transaction

Optional admin-only function.

Use when something was deleted by mistake.

Responsibilities:

1. Validate admin permission.
2. Restore transaction if not locked by closing.
3. Repost journal.
4. Write audit log.

---

# 8. Daily Closing and Edit/Delete

## 8.1 Before closing

- Edit allowed for manager/admin.
- Delete allowed with reason.
- Cashier can edit own same-day drafts.
- Cashier can request edit/delete for posted entries.

## 8.2 After closing

- Normal user cannot edit/delete.
- Manager/admin approval required.
- App should show:

```text
This day is already closed. Edit requires approval.
```

## 8.3 If edit after closing is approved

System should:

- Reopen affected closing or create adjustment entry.
- Show difference in daily closing report.
- Keep audit log.

Recommended Phase 1 rule:

> Do not allow edit/delete after approved daily closing except Super Admin.

---

# 9. Report Rules

## 9.1 Normal reports

Exclude deleted/voided transactions from normal totals.

## 9.2 Audit reports

Include deleted/voided/edited transactions.

## 9.3 Trial Balance

Trial Balance must always include accounting-safe journal effect only.

If transaction is deleted:

- Its effect should be neutralized.
- Trial balance must remain balanced.

## 9.4 Ledger

Ledger should have a filter:

- Show active only
- Show deleted/voided
- Show all with audit

Default:

> Active only

## 9.5 Profit & Loss

Deleted/voided transactions must not affect current P&L after deletion.

## 9.6 Balance Sheet

Deleted/voided transactions must not affect current balance sheet after deletion.

---

# 10. UI Changes

## 10.1 Transaction detail screen

Add buttons:

- Edit
- Delete
- Print
- Share
- View Audit

For posted transactions:

- Edit visible according to permission
- Delete visible according to permission
- View Audit always visible for admin/manager

## 10.2 Edit screen

Show warning only when needed:

```text
Editing this completed transaction will update the ledger and reports.
Reason is required.
```

Fields:

- Reason for edit
- Save changes

## 10.3 Delete modal

```text
Delete transaction?
This will remove it from normal reports and update balances.
This action will be saved in audit history.

Reason:
[ text field ]

Cancel | Delete
```

## 10.4 Audit tab

Show:

- Created by
- Edited by
- Deleted by
- Old amount
- New amount
- Old account
- New account
- Old date
- New date
- Reason
- Time

---

# 11. User Permission Rules

## Cashier

- Create draft
- Edit own draft
- Delete own draft
- Submit posted edit request
- Cannot delete posted transaction directly

## Manager

- Edit posted same-day transaction before closing
- Delete/void posted same-day transaction before closing
- Approve cashier edit/delete request
- Cannot change locked closing without admin

## Admin / Super Admin

- Full edit/delete permission
- Can edit after closing if allowed
- Can restore deleted transaction
- Can view full audit

## Auditor

- View only
- Can see audit
- Cannot edit/delete

---

# 12. Best Practical Recommendation

For simple daily use:

- UI should show **Edit** and **Delete**.
- Draft records can be truly deleted.
- Posted records should be **soft deleted/voided** behind the scenes.
- User should not be forced to manually create reverse entries.
- System should handle accounting safety automatically.

Best rule:

> “User sees simple Edit/Delete. System keeps audit and accounting correct.”

---

# 13. Updated Cursor Agent Prompt

```text
Update FX Cash Ledger V2 to support user-friendly Edit and Delete workflows.

Important:
- Users want simple Edit and Delete buttons because daily work needs to be easy.
- Do not force normal users to manually understand reverse journal entries.
- UI should allow editing transaction date, account, amount, currency, rate, party, fee, notes, and attachments where allowed.
- UI should allow delete with required reason.
- Draft transactions may be hard deleted.
- Posted/completed transactions must not be physically removed from database.
- For posted transactions, implement accounting-safe soft delete/void behind the scenes.
- For posted edit, implement amend-and-repost logic behind the scenes.
- Keep same visible transaction number when editing unless admin chooses otherwise.
- Store old_data and new_data in fx_transaction_versions and fx_audit_logs.
- Trial Balance must remain balanced after edit/delete.
- P&L and Balance Sheet must update correctly.
- Daily Closing lock must restrict edit/delete after approval.
- Manager/Admin can edit/delete same-day posted entries before daily closing.
- After closing, edit/delete requires Super Admin or approval workflow.
- Normal reports should exclude deleted/voided transactions by default.
- Audit reports must include edited/deleted/voided transactions.
- Add Transaction Detail buttons: Edit, Delete, View Audit.
- Add Edit Reason and Delete Reason fields.
- Add RPC functions:
  1. fx_edit_transaction
  2. fx_delete_transaction
  3. fx_restore_deleted_transaction, admin only optional
- Flutter must call RPC functions for posted edit/delete, not direct table updates.
```

---

# 14. Final Implementation Rule

Do not choose between “simple user workflow” and “proper accounting”.

Use this design:

```text
Frontend: simple Edit/Delete
Backend: versioning + audit + safe repost/void
Reports: active records by default
Audit: complete history
```

This is the best balance for the user's real daily workflow.
