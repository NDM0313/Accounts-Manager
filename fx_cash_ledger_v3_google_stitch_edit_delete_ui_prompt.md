# FX Cash Ledger V3 — Google Stitch UI Update
## Edit/Delete Friendly Accounting UI

Use this as an update prompt in Google Stitch.

---

## Main UI Update

Add user-friendly **Edit** and **Delete** workflows to FX Cash Ledger.

The app is still a private internal multi-currency accounting ledger.  
It is not public money exchange, not crypto, not USDT, not Binance.

The user wants simple daily workflow:

- Edit transaction
- Change date
- Change account
- Change amount
- Change currency
- Change rate
- Delete wrong transaction
- Keep UI easy and understandable

---

## Transaction Detail Screen Update

Add action buttons:

- Edit
- Delete
- Print
- Share
- View Audit

Design:

- Edit button should be primary/blue
- Delete button should be soft red
- View Audit should be secondary/neutral
- Do not make the screen look scary or too technical

---

## Edit Transaction Screen

Create edit screen for completed or draft transactions.

Fields:

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
- Reason for edit

If transaction is completed, show small note:

```text
This change will update ledger and reports.
Reason is required.
```

Bottom buttons:

- Cancel
- Save Changes

Use large amount inputs and clear currency chips.

---

## Delete Confirmation Modal

Design simple delete modal:

Title:

```text
Delete transaction?
```

Message:

```text
This will remove it from normal reports and update balances.
This action will be saved in audit history.
```

Fields:

- Reason for delete

Buttons:

- Cancel
- Delete

Delete button should be red but not overly aggressive.

---

## Audit History Screen

Create a clean audit history screen.

Show timeline cards:

- Created
- Edited
- Deleted
- Restored
- Approved

Each card shows:

- User
- Date/time
- Action
- Reason
- Old value
- New value

Examples:

- Amount changed from 75,500 to 75,800
- Account changed from PKR Cash to PKR Bank
- Date changed from 09 Jun to 10 Jun
- Transaction deleted with reason

---

## Locked Closing Warning

If transaction belongs to approved daily closing, show warning card:

```text
This day is already closed.
Edit/Delete requires admin approval.
```

Buttons:

- Request Edit
- Request Delete

---

## Reports Filter Update

In ledger/report screens add filter:

- Active only
- Deleted/voided
- All with audit

Default should be:

```text
Active only
```

---

## Updated Stitch Prompt

```text
Update FX Cash Ledger UI to support simple Edit and Delete workflows while keeping the app professional and accounting-focused.

Add Edit and Delete buttons on Transaction Detail. Add an Edit Transaction screen where user can change date, party, account, currency, amount, rate, fee, notes, and attachment. Add required Reason for Edit when transaction is completed.

Add a Delete Confirmation modal with required reason. The message should say: "This will remove it from normal reports and update balances. This action will be saved in audit history."

Add an Audit History screen with a timeline showing created, edited, deleted, restored, and approved actions. Show old value vs new value in clean cards.

Add locked closing warning: "This day is already closed. Edit/Delete requires admin approval."

Keep the UI simple for daily users. Do not show complex reverse-entry accounting language. Use friendly labels: Edit, Delete, View Audit. Keep fintech style with navy, emerald green, amber, soft red, rounded cards, large numbers, and clean spacing.
```
