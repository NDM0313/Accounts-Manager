# FX Cash Ledger V2
## Flutter + Existing Self-Hosted Supabase + Proper Double-Entry Accounting Plan

**Purpose:**  
This document is a Cursor/AI Agent/Developer handoff for building a private multi-currency cash/account ledger app.

**Main clarification:**  
This is **not** a public money exchange service.  
This is **not** a USDT/Binance/crypto wallet.  
This is a **private internal multi-currency account manager** for physical cash, accounts, settlements, expenses, and proper accounting.

The system must include a real accounting foundation:

- Chart of Accounts
- Double-entry journal
- General Ledger
- Trial Balance
- Profit & Loss
- Balance Sheet
- Cash/Bank/Currency balances
- Party/Agent ledgers
- Audit trail
- Daily closing
- Multi-currency revaluation

---

# 1. Existing Backend Decision

The user already has:

- Self-hosted Supabase on VPS
- Existing ERP database
- Existing authentication/users
- Existing company/branch structure
- Existing accounting concepts in ERP
- Existing deployment workflow

## Important Supabase self-hosting note

Self-hosted Supabase behaves like a **single project** environment.  
Do not assume that Supabase Studio on the VPS can create multiple projects like Supabase Cloud.

## Recommended database approach

Use the existing Supabase VPS, but keep the FX system separated logically:

### Preferred option: Same Supabase, separate schema/tables

Use one of these patterns:

**Option A — public schema with prefixed tables**
```text
fx_currencies
fx_rates
fx_accounts
fx_parties
fx_journal_entries
fx_journal_lines
fx_transactions
fx_daily_closings
fx_audit_logs
```

**Option B — dedicated schema**
```text
fx.currencies
fx.rates
fx.accounts
fx.parties
fx.journal_entries
fx.journal_lines
fx.transactions
fx.daily_closings
fx.audit_logs
```

Recommended:

> Use prefixed `fx_*` tables first if the current ERP already mostly uses `public` schema and existing code/RLS patterns are easier there.

### Alternative option: Separate Supabase stack on same VPS

Only choose this if strict separation is required.

This needs:

- Separate Docker Compose project
- Separate Postgres volume
- Separate API/Kong ports
- Separate Studio port
- Separate JWT secrets
- Separate anon/service role keys
- Separate domain/subdomain
- Separate backup plan
- More RAM/CPU

This is more complex and can break existing VPS if done carelessly.

### Best recommendation for this project

For now:

> Use existing self-hosted Supabase and create a separate FX/accounting module with isolated `fx_*` tables, RLS, and migrations.

This avoids mixing data while keeping deployment simple.

---

# 2. Cursor/AI Agent VPS/SSH Rules

Cursor AI can help prepare files and commands, but it should **not blindly modify the production VPS**.

## Safe workflow

1. Inspect existing project locally.
2. Inspect existing Supabase schema through migration files or read-only queries.
3. Create new migration files.
4. Test locally or on staging if available.
5. Backup production database before applying.
6. Apply migration to VPS Supabase through SSH only after review.
7. Run verification queries.
8. Deploy Flutter app separately.

## Cursor must not do these without approval

- Stop existing Supabase containers
- Delete Docker volumes
- Reset database
- Run destructive migrations
- Change global JWT secrets
- Change existing ERP tables without backup
- Mix FX transactions into old sales/purchase tables
- Hard-delete accounting records

---

# 3. App Foundation

Recommended stack:

- Mobile: Flutter
- State management: Riverpod
- Backend: Existing self-hosted Supabase
- Database: PostgreSQL
- Auth: Existing Supabase Auth
- Storage: Supabase Storage for attachments/proofs
- Local cache: Drift/SQLite
- Accounting engine: PostgreSQL functions/RPC + double-entry tables
- Report export: PDF/CSV from app or backend RPC

Android and iOS must be supported from the start.

---

# 4. Accounting Foundation

This system must not be simple plus/minus only.  
Every completed financial transaction must create double-entry journal lines.

## 4.1 Base Currency

Base currency:

```text
PKR
```

Every transaction must store:

- Actual currency amount
- Actual currency code
- Rate used
- PKR/base equivalent
- Exchange gain/loss if applicable

## 4.2 Chart of Accounts

Create proper COA for FX business.

Recommended account categories:

### Assets
```text
1000 Assets
1100 Cash & Currency Assets
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

### Liabilities
```text
2000 Liabilities
2100 Agent Payables
2200 Customer Payables
2300 Settlement Payables
2400 Other Payables
```

### Equity
```text
3000 Equity
3100 Owner Capital
3200 Owner Drawings
3300 Retained Earnings
```

### Income
```text
4000 Income
4100 Exchange Spread Income
4200 Service Charges Income
4300 Settlement Charges Income
4400 Revaluation Gain
```

### Expenses
```text
5000 Expenses
5100 Salary Expense
5200 Rent Expense
5300 Courier/Delivery Expense
5400 Bank Charges
5500 Agent Charges
5600 Currency Shortage/Loss
5700 Other Expenses
```

### Contra / Adjustment
```text
6000 Adjustment
6100 FX Gain/Loss Clearing
6200 Rounding Difference
6300 Cash Over/Short
```

---

# 5. Accounting Tables

## 5.1 fx_accounts

```sql
create table fx_accounts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  branch_id uuid,
  code text not null,
  name text not null,
  account_type text not null check (account_type in (
    'asset','liability','equity','income','expense','contra'
  )),
  normal_balance text not null check (normal_balance in ('debit','credit')),
  currency_code text,
  parent_id uuid references fx_accounts(id),
  is_cash_account boolean default false,
  is_control_account boolean default false,
  is_active boolean default true,
  created_at timestamptz default now(),
  unique(company_id, code)
);
```

## 5.2 fx_journal_entries

```sql
create table fx_journal_entries (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  branch_id uuid not null,
  entry_no text not null,
  entry_date date not null,
  source_type text not null,
  source_id uuid,
  description text,
  status text not null default 'posted' check (status in ('draft','posted','reversed','void')),
  reversal_of uuid references fx_journal_entries(id),
  created_by uuid,
  approved_by uuid,
  posted_at timestamptz default now(),
  created_at timestamptz default now(),
  unique(company_id, entry_no)
);
```

## 5.3 fx_journal_lines

```sql
create table fx_journal_lines (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  branch_id uuid not null,
  journal_entry_id uuid not null references fx_journal_entries(id),
  account_id uuid not null references fx_accounts(id),
  party_id uuid,
  currency_code text not null,
  debit_amount numeric(18,4) default 0,
  credit_amount numeric(18,4) default 0,
  base_currency_code text not null default 'PKR',
  base_debit_amount numeric(18,4) default 0,
  base_credit_amount numeric(18,4) default 0,
  rate_used numeric(18,8),
  line_note text,
  created_at timestamptz default now(),
  check (debit_amount >= 0 and credit_amount >= 0),
  check (not (debit_amount > 0 and credit_amount > 0))
);
```

## 5.4 Balance rule

For every posted journal entry:

```text
sum(base_debit_amount) = sum(base_credit_amount)
```

This must be enforced by RPC/function before posting.

---

# 6. Transaction Modules and Journal Effects

## 6.1 Currency Buy

Example: Business buys 1,000 AED from customer and pays 75,500 PKR.

Operational movement:

- AED Cash increases
- PKR Cash decreases

Journal:

```text
Dr Cash AED              75,500 PKR equivalent
Cr Cash PKR              75,500 PKR
```

Store actual values:

```text
AED amount = 1,000
PKR amount = 75,500
rate = 75.50
```

## 6.2 Currency Sell

Example: Business sells 1,000 AED to customer and receives 76,200 PKR.  
Average cost of AED = 75.50.

Journal:

```text
Dr Cash PKR              76,200
Cr Cash AED              75,500
Cr Exchange Spread Income   700
```

If loss:

```text
Dr Cash PKR
Dr FX Loss
Cr Cash AED
```

## 6.3 Cross Currency Conversion

Example: AED to RMB.

Use base PKR equivalent internally.

Journal must debit destination currency asset and credit source currency asset.  
Any difference goes to exchange gain/loss.

```text
Dr Cash RMB              PKR equivalent received
Cr Cash AED              PKR equivalent given
Cr/Dr FX Gain/Loss        Difference
```

## 6.4 Expense

Example: delivery expense paid from PKR cash.

```text
Dr Delivery Expense
Cr Cash PKR
```

If expense in RMB:

```text
Dr Delivery Expense      PKR equivalent
Cr Cash RMB              PKR equivalent
```

## 6.5 Settlement Send

Example: Customer gives PKR here, agent/partner must pay RMB outside.

If this is internal ledger only:

```text
Dr Cash PKR
Cr Agent Payable / Settlement Payable
Cr Service Charges Income
```

When agent confirms/payment settles:

```text
Dr Agent Payable
Cr Agent Settlement Account / Cash RMB / Adjustment
```

Exact accounting depends on business flow and must be finalized after real workflow confirmation.

## 6.6 Settlement Receive

Example: Agent instructs business to pay customer locally.

```text
Dr Agent Receivable
Cr Cash PKR
```

When agent settles:

```text
Dr Cash/Bank/Foreign Account
Cr Agent Receivable
```

## 6.7 Owner Capital

When owner adds funds:

```text
Dr Cash PKR / Cash AED / Cash RMB
Cr Owner Capital
```

## 6.8 Owner Withdrawal

When owner takes money:

```text
Dr Owner Drawings
Cr Cash PKR / Cash AED / Cash RMB
```

---

# 7. Reports Required

## 7.1 General Ledger

Filter:

- Date range
- Account
- Currency
- Branch
- Party
- Source type

Columns:

- Date
- Entry no
- Description
- Currency
- Debit
- Credit
- Balance
- Base debit
- Base credit
- Base balance

## 7.2 Trial Balance

Columns:

- Account code
- Account name
- Opening debit
- Opening credit
- Period debit
- Period credit
- Closing debit
- Closing credit

Rule:

```text
Total debit must equal total credit.
```

## 7.3 Profit & Loss

Income:

- Exchange Spread Income
- Service Charges Income
- Settlement Charges Income
- Revaluation Gain

Expenses:

- Agent Charges
- Bank Charges
- Delivery/Courier
- Salary
- Rent
- Currency Shortage/Loss
- Revaluation Loss

Net Profit:

```text
Total Income - Total Expenses
```

## 7.4 Balance Sheet

Assets:

- Cash PKR
- Cash USD
- Cash AED
- Cash RMB
- Bank Accounts
- Agent Receivables
- Customer Receivables

Liabilities:

- Agent Payables
- Customer Payables
- Settlement Payables
- Other Payables

Equity:

- Owner Capital
- Retained Earnings
- Current Year Profit
- Owner Drawings

Balance sheet rule:

```text
Assets = Liabilities + Equity
```

## 7.5 Currency Position Report

Shows actual currency stock:

- PKR amount
- USD amount
- AED amount
- RMB amount
- SAR amount
- PKR equivalent
- Average cost
- Current market value
- Unrealized gain/loss

## 7.6 Daily Closing Report

Shows:

- Opening balance by account/currency
- Debits
- Credits
- Expected closing
- Physical counted closing
- Difference
- Approved by
- Notes

## 7.7 Audit Report

Shows:

- Rate changes
- Backdated entries
- Reversed entries
- Large transactions
- User activity
- Failed posting attempts
- Edited drafts

---

# 8. Multi-Currency Valuation

## 8.1 Actual balance

Always preserve actual currency amount.

Example:

```text
Cash AED = 10,000 AED
Cash RMB = 50,000 RMB
```

## 8.2 Base currency value

For reporting, calculate PKR equivalent.

```text
PKR equivalent = foreign amount × rate
```

## 8.3 Realized gain/loss

Generated when currency is sold/converted.

## 8.4 Unrealized gain/loss

Generated by revaluation of remaining stock.

Revaluation should be optional and posted by authorized user.

Example:

If AED stock average value is 75.50 and current rate is 76.20:

```text
Unrealized gain = stock amount × (current rate - average rate)
```

---

# 9. Posting Engine

All completed transactions must go through one posting RPC.

Recommended function:

```text
fx_post_transaction(transaction_id)
```

It should:

1. Validate transaction status.
2. Lock transaction row.
3. Fetch rate used.
4. Create journal entry.
5. Create balanced journal lines.
6. Verify debit = credit in PKR/base currency.
7. Update status to completed/posted.
8. Write audit log.
9. Return entry_no and transaction_no.

Do not let Flutter directly insert posted journal lines without server validation.

---

# 10. Numbering

Use server-side numbering.

Recommended prefixes:

```text
FXB-0001    Currency Buy
FXS-0001    Currency Sell
FXC-0001    Cross Currency
FXTR-0001   Transfer
FXEXP-0001  Expense
FXSS-0001   Settlement Send
FXSR-0001   Settlement Receive
FXJE-0001   Journal Entry
FXCL-0001   Daily Closing
```

Rules:

- Company-safe
- Branch-safe if needed
- Does not reset unexpectedly
- Must be generated by RPC
- Must not be generated only on mobile side

---

# 11. UI Requirements for Proper Accounting

Add screens:

1. Chart of Accounts
2. Account Detail
3. General Ledger
4. Trial Balance
5. Profit & Loss
6. Balance Sheet
7. Journal Entry Viewer
8. Manual Journal Entry, admin only
9. Revaluation Entry
10. Audit Log

Existing screens still required:

- Dashboard
- Rate Board
- Currency Buy
- Currency Sell
- Cross Currency
- Transfer
- Expense
- Settlement Send
- Settlement Receive
- Party Ledger
- Agent Ledger
- Daily Closing
- Reports
- Settings

---

# 12. Dashboard Requirements

Dashboard must include accounting-level summary:

## Top cards

- Total Assets
- Total Liabilities
- Net Equity
- Today Profit/Loss

## Currency cards

- PKR Cash
- USD Cash
- AED Cash
- RMB Cash
- SAR Cash

## Rate board

- Reference rate
- Buy rate
- Sell rate
- Last updated

## Accounting health

- Trial balance status: Balanced / Not Balanced
- Unposted transactions
- Pending closings
- Reversal count
- Cash difference

## Quick actions

- Buy
- Sell
- Transfer
- Expense
- Settlement
- Journal Entry
- Daily Closing

---

# 13. RLS and Security

Enable RLS on all `fx_*` tables.

Rules:

- User can access only assigned company.
- Branch users can access only assigned branches.
- Cashier can create draft transactions.
- Only manager/admin can post/approve.
- Only admin can reverse.
- No hard delete for posted records.
- Backdated entry requires permission.
- Rate change requires permission.
- Manual journal entry requires admin/auditor role.

---

# 14. Flutter Architecture

Use:

```text
Flutter
Riverpod
Supabase Flutter
GoRouter
Drift/SQLite for offline drafts/cache
PDF package for reports
Responsive mobile layouts
```

Feature folders:

```text
lib/features/dashboard
lib/features/rates
lib/features/transactions
lib/features/accounts
lib/features/journal
lib/features/reports
lib/features/closing
lib/features/parties
lib/features/settings
```

---

# 15. Offline Rule

For safety:

- Offline draft allowed
- Offline posted transaction not allowed in Phase 1
- Final posting requires online connection and server RPC
- Local draft sync must avoid duplicate posting

---

# 16. Updated Cursor Agent Prompt

Use this prompt in Cursor:

```text
You are building "FX Cash Ledger", a private internal multi-currency account manager app.

Important:
- This is not a public money exchange service.
- This is not a crypto, USDT, Binance, or mobile wallet app.
- It is a private internal ledger for physical currencies, cash accounts, settlements, expenses, and accounting.
- The user already has a self-hosted Supabase running on VPS.
- Do not assume Supabase Studio can create multiple cloud-style projects inside self-hosted Supabase.
- Prefer existing Supabase with separate fx_* tables/schemas and RLS.
- Do not mix FX data into old ERP sales/purchase/rental tables.
- Do not create or destroy Supabase Docker containers without explicit approval.
- Do not reset production database.
- Take backup before production migrations.

Critical accounting requirement:
This must be a proper double-entry accounting system, not simple plus/minus cash tracking.

Must include:
1. Chart of Accounts
2. Multi-currency cash accounts
3. Double-entry journal entries
4. Journal lines with actual currency and PKR/base equivalent
5. General Ledger
6. Trial Balance
7. Profit & Loss
8. Balance Sheet
9. Currency Position Report
10. Daily Closing
11. Audit Logs
12. Reversal entries instead of delete
13. Server-side RPC posting engine
14. Server-side transaction numbering
15. RLS by company/branch/user role

Recommended technical stack:
- Flutter for Android/iOS
- Supabase Flutter client
- Existing self-hosted Supabase backend
- PostgreSQL migrations
- Riverpod state management
- Drift/SQLite for offline drafts/cache
- Server RPC for final posting

First tasks:
1. Inspect existing ERP/Supabase schema.
2. Identify reusable company, branch, user, role, contact, account, and numbering tables.
3. Propose safe fx_* table structure.
4. Prepare non-destructive migrations.
5. Add COA seed for FX accounting.
6. Add posting RPC design.
7. Add RLS policies.
8. Build Flutter shell with dashboard, rates, transactions, accounts, journal, reports, and settings.
9. Add tests for balanced journals, trial balance, P&L, balance sheet, and reversal logic.
```

---

# 17. Build Phases

## Phase 0 — Discovery

- Read existing schema
- Read existing RLS
- Read existing auth/branch roles
- Identify reusable tables
- Write discovery report

## Phase 1 — Accounting Database

- fx_accounts
- fx_journal_entries
- fx_journal_lines
- fx_rates
- fx_transactions
- fx_daily_closings
- fx_audit_logs
- RLS
- COA seed

## Phase 2 — Posting Engine

- RPC for transaction numbering
- RPC for posting
- RPC for reversal
- Balance validation
- Audit logs

## Phase 3 — Flutter Foundation

- Auth
- Branch select
- Dashboard
- Theme
- Navigation
- Permissions

## Phase 4 — Rate + Transactions

- Rate Board
- Currency Buy
- Currency Sell
- Cross Currency
- Transfer
- Expense

## Phase 5 — Accounting Reports

- Ledger
- Trial Balance
- P&L
- Balance Sheet
- Currency Position

## Phase 6 — Settlement + Agent Ledger

- Settlement Send
- Settlement Receive
- Agent ledger
- Attachments/proofs

## Phase 7 — Daily Closing + Audit

- Cash count
- Difference
- Approval
- Locking
- Audit report

## Phase 8 — Testing + Deployment

- Unit tests
- RLS tests
- Posting tests
- Report tests
- Build APK/AAB
- Prepare iOS build

---

# 18. Final Recommendation

Do not create a risky new Supabase project on the VPS unless there is a strong reason.

Best approach:

> Existing VPS Supabase + separate `fx_*` accounting module + proper double-entry + Flutter Android/iOS app.

This keeps data separate enough for safety, but avoids breaking the current ERP infrastructure.
