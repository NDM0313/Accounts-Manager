# FX Cash Ledger — Final Master Handoff for Cursor
## Flutter + Supabase Cloud Dev Project + Google Stitch UI

**Purpose:**  
This is the final updated handoff file for Cursor/AI Agent.

The Google Stitch UI design work has already been started/completed.  
A new Supabase Cloud project has already been created for development/staging.  
Now Cursor must build the real Flutter app and backend schema using Supabase Cloud first.

---

# 1. Current Confirmed Status

## 1.1 Supabase

- A new Supabase Cloud project has been created.
- This project will be used as **development/staging** first.
- Existing ERP/VPS database must not be touched at this stage.
- Flutter app will connect to this new Supabase Cloud project using:
  - Supabase URL
  - Publishable/anon key
- Service role key must never be used inside Flutter/mobile app.

## 1.2 Google Stitch

- Google Stitch has already generated/started the UI design.
- Cursor should use Stitch output as UI reference.
- Do not redesign randomly from scratch.
- Convert Stitch UI into real Flutter screens/components.

## 1.3 Existing ERP

- The old ERP system on VPS must remain untouched.
- No migrations should be run on old ERP/VPS database.
- No old ERP tables should be modified.
- Later, after this FX app is stable, migration/deployment to VPS can be planned separately.

---

# 2. App Scope

App name:

```text
FX Cash Ledger
```

This app is:

- Private internal multi-currency accounting ledger
- Physical currency cash/account manager
- Accounting/reporting system
- Internal settlement and agent ledger system

This app is not:

- Public money exchange service
- Crypto app
- USDT/Binance app
- Public remittance app
- Mobile wallet app

---

# 3. Main Technical Stack

Use:

```text
Flutter
Supabase Flutter
Supabase Auth
Supabase PostgreSQL
Supabase Storage
Riverpod
GoRouter
Drift/SQLite for offline drafts/cache, later phase
```

Development backend:

```text
New Supabase Cloud project
```

Future production option:

```text
VPS/self-hosted Supabase or separate PostgreSQL after full testing
```

---

# 4. Important Instruction About Old Files

There are older planning files for:

- Flutter + Supabase architecture
- Google Stitch UI prompt
- Proper accounting
- Edit/delete workflow
- Backup/isolation
- Alternative database options

Cursor may use them as reference only.

But this file is the **latest master instruction**.

If there is conflict:

```text
Follow this master handoff file first.
```

---

# 5. Google Stitch UI Integration Instructions

Cursor must ask user to provide one or more of these from Google Stitch:

- Generated UI screenshots
- Exported design/code if available
- Component list
- Color palette
- Screen layouts
- Any Stitch prompt/output file

Then Cursor should:

1. Review the Stitch design.
2. Create Flutter components matching the design.
3. Preserve the same modern fintech look.
4. Use clean light/dark theme.
5. Avoid making UI too busy.
6. Use large amount inputs and readable currency cards.
7. Keep cashier/manager workflow simple.

Do not blindly copy messy generated code if it is poor quality.  
Use Stitch as visual direction and rebuild clean Flutter code.

---

# 6. Supabase Connection Rules

Flutter must use:

```dart
supabase_flutter
```

Required setup:

```bash
flutter pub add supabase_flutter flutter_riverpod go_router intl uuid flutter_dotenv
```

Use `.env`:

```text
SUPABASE_URL=
SUPABASE_PUBLISHABLE_KEY=
```

Never place service role key in Flutter.

Create:

```text
.env.example
.env
```

`.env` must be gitignored.

---

# 7. Database Rule

All schema must be created through migration files.

Do not manually create random tables from Supabase Dashboard unless it is a small temporary test.

Required migrations:

```text
supabase/migrations/
```

Recommended first migration:

```text
20260609_create_fx_foundation.sql
```

---

# 8. Required Database Tables

Create isolated FX tables only:

```text
fx_companies
fx_branches
fx_users_profiles
fx_roles
fx_user_roles
fx_currencies
fx_rates
fx_accounts
fx_parties
fx_transactions
fx_transaction_lines
fx_transaction_versions
fx_journal_entries
fx_journal_lines
fx_daily_closings
fx_closing_lines
fx_attachments
fx_audit_logs
```

If using Supabase Auth, `auth.users` is the source of login identity.  
`fx_users_profiles` should store app-specific profile/role/branch information.

---

# 9. Proper Accounting Requirement

This must not be a simple plus/minus app.

Must include:

- Chart of Accounts
- Double-entry journal
- Journal lines
- General Ledger
- Trial Balance
- Profit & Loss
- Balance Sheet
- Currency Position Report
- Daily Closing
- Audit Logs
- Edit/Delete with version history

All posted financial transactions must create balanced journal entries.

Rule:

```text
Total base debit = Total base credit
```

Base currency:

```text
PKR
```

Every transaction must store:

- Actual currency amount
- Currency code
- Rate used
- PKR equivalent
- Journal entry
- Audit log

---

# 10. Chart of Accounts

Seed the basic COA:

## Assets

```text
1000 Assets
1110 Cash PKR
1120 Cash USD
1130 Cash AED
1140 Cash RMB/CNY
1150 Cash SAR
1160 Bank PKR
1170 Bank Foreign Currency
1180 Agent Receivables
1190 Customer Receivables
```

## Liabilities

```text
2000 Liabilities
2100 Agent Payables
2200 Customer Payables
2300 Settlement Payables
2400 Other Payables
```

## Equity

```text
3000 Equity
3100 Owner Capital
3200 Owner Drawings
3300 Retained Earnings
```

## Income

```text
4000 Income
4100 Exchange Spread Income
4200 Service Charges Income
4300 Settlement Charges Income
4400 Revaluation Gain
```

## Expenses

```text
5000 Expenses
5100 Salary Expense
5200 Rent Expense
5300 Courier/Delivery Expense
5400 Bank Charges
5500 Agent Charges
5600 Currency Shortage/Loss
5700 Revaluation Loss
5800 Other Expenses
```

## Adjustment

```text
6000 Adjustment
6100 FX Gain/Loss Clearing
6200 Rounding Difference
6300 Cash Over/Short
```

---

# 11. Transaction Types

Required transaction types:

```text
currency_buy
currency_sell
cross_currency
account_transfer
expense
settlement_send
settlement_receive
manual_journal
revaluation
opening_balance
daily_closing_adjustment
```

---

# 12. Edit/Delete Workflow

The UI should show simple:

- Edit
- Delete
- View Audit

But backend must keep accounting safe.

## Draft transactions

Allowed:

- Edit freely
- Hard delete allowed

## Posted transactions before daily closing

Allowed by manager/admin:

- Edit same transaction
- Delete transaction

Backend should:

- Keep same visible transaction number
- Save old data and new data
- Void/repost journal safely
- Keep audit log
- Keep trial balance balanced

## Posted transactions after daily closing

Do not allow normal edit/delete.

Show:

```text
This day is already closed. Edit/Delete requires admin approval.
```

## Delete rule

For posted transactions:

- Do not physically remove database record.
- Mark as deleted/voided.
- Remove from normal reports.
- Keep in audit report.
- Neutralize accounting effect.

---

# 13. RLS Security

Enable RLS on all FX tables.

Basic rule:

- Users can access only their assigned company/branch.
- Cashier can create drafts.
- Manager/Admin can post.
- Admin can manage COA/rates.
- Auditor can view only.
- Service role key only server-side, never mobile.

Required permissions:

```text
can_access_fx_ledger
can_manage_fx_rates
can_post_fx_transaction
can_edit_fx_transaction
can_delete_fx_transaction
can_view_fx_reports
can_view_fx_audit
can_manage_chart_of_accounts
can_close_day
```

---

# 14. Required RPC / Database Functions

Create server-side functions/RPC:

```text
fx_generate_transaction_no
fx_post_transaction
fx_edit_transaction
fx_delete_transaction
fx_restore_deleted_transaction
fx_post_manual_journal
fx_get_trial_balance
fx_get_profit_and_loss
fx_get_balance_sheet
fx_get_currency_position
fx_close_day
```

Flutter should not directly create posted journal lines.  
Flutter should call RPC for posting/edit/delete.

---

# 15. Flutter App Structure

Create structure:

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme.dart
  core/
    config/
    errors/
    utils/
    widgets/
  features/
    auth/
    dashboard/
    rates/
    transactions/
    accounts/
    journal/
    reports/
    closing/
    parties/
    settings/
  data/
    supabase/
    repositories/
  domain/
    models/
    services/
```

Use:

- Riverpod for state management
- GoRouter for navigation
- Supabase Flutter for backend
- Flutter dotenv for env
- intl for formatting
- uuid for local draft IDs if needed

---

# 16. Screens Required

Use Google Stitch design as visual guide.

Required screens:

1. Login
2. Branch/Company Select
3. Dashboard
4. Rate Board
5. New Rate Entry
6. Currency Buy
7. Currency Sell
8. Cross Currency Conversion
9. Account Transfer
10. Expense Entry
11. Settlement Send
12. Settlement Receive
13. Party List
14. Party Ledger
15. Agent Ledger
16. Chart of Accounts
17. Account Detail
18. General Ledger
19. Trial Balance
20. Profit & Loss
21. Balance Sheet
22. Currency Position Report
23. Journal Entry Detail
24. Manual Journal Entry
25. Daily Closing
26. Audit Log
27. Reports
28. Settings

---

# 17. Dashboard Requirements

Dashboard must show:

- Today rate board
- Currency cash balances
- Total assets
- Total liabilities
- Net equity
- Today profit/loss
- Pending settlements
- Trial balance status
- Unposted transactions
- Daily closing status
- Quick action buttons

Currencies:

- PKR
- USD
- AED
- RMB/CNY
- SAR

---

# 18. Testing Requirements

Must add tests for:

- Journal debit = credit
- Currency buy posting
- Currency sell posting
- Cross currency posting
- Expense posting
- Edit posted transaction
- Delete/void posted transaction
- Trial balance balanced
- Balance sheet balanced
- Profit & loss correct
- RLS blocks unauthorized access
- Closed day edit/delete blocked

---

# 19. Build Order

## Phase 1 — Supabase foundation

1. Create migrations.
2. Create tables.
3. Enable RLS.
4. Seed currencies.
5. Seed COA.
6. Create RPC posting functions.
7. Create test user/profile/role.

## Phase 2 — Flutter shell

1. Create Flutter project.
2. Add packages.
3. Add env config.
4. Initialize Supabase.
5. Add login screen.
6. Add routing.
7. Add theme.
8. Add dashboard shell.

## Phase 3 — Core accounting

1. Rate board.
2. Accounts.
3. Buy/Sell forms.
4. Posting RPC.
5. Journal detail.
6. Trial balance.

## Phase 4 — Reports

1. General Ledger.
2. P&L.
3. Balance Sheet.
4. Currency Position.
5. Daily Closing.

## Phase 5 — Stitch UI polish

1. Apply Google Stitch layout.
2. Improve spacing.
3. Add light/dark mode.
4. Add mobile responsiveness.
5. Add clean components.

---

# 20. Exact Cursor Start Prompt

Use this prompt first:

```text
We have a new Supabase Cloud project for FX Cash Ledger development/staging, and Google Stitch has already generated the UI design.

Do not touch the old ERP/VPS database.

Your job is to build the real Flutter app and Supabase schema for FX Cash Ledger.

Use this master handoff as the latest instruction. Older files are reference only.

First:
1. Create a discovery checklist for this new Supabase project.
2. Create Flutter project structure.
3. Add required packages.
4. Create .env.example.
5. Prepare Supabase migrations for isolated fx_* tables.
6. Enable RLS.
7. Seed currencies and Chart of Accounts.
8. Create posting RPC skeleton.
9. Build Login + Dashboard shell.
10. Use Google Stitch output as UI reference, not as final architecture.

Important:
- Never use service_role key in Flutter.
- Use migrations, not random dashboard table creation.
- Proper double-entry accounting is required.
- Trial balance must always balance.
- Edit/Delete must be user-friendly but audit-safe.
```

---

# 21. What User Should Give Cursor

Give Cursor these items:

1. This master handoff file.
2. Supabase Flutter connection details:
   - Supabase URL
   - publishable/anon key only
3. Google Stitch output:
   - screenshots/export/components
4. Any older planning files as reference only.
5. Clear instruction:
   - old ERP/VPS must not be touched.

Do not give service role key to normal Flutter code.

---

# 22. Final Rule

The correct workflow now is:

```text
Google Stitch UI = design reference
Supabase Cloud = dev/staging backend
Cursor = real Flutter + migrations + accounting engine
Old ERP/VPS = untouched until final deployment stage
```

