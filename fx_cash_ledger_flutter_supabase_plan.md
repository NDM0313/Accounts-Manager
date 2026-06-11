# Private Multi-Currency Cash Account Manager
## Flutter + Existing Self-Hosted Supabase/VPS Build Plan

**Document purpose:**  
This document is for Cursor/AI Agent/Developer handoff. The goal is to build a private internal-use mobile app for multi-currency cash ledger, rate board, account movement, expenses, and daily closing.

**Important scope clarification:**  
This is **not** a public money exchange, remittance company, crypto wallet, Binance/USDT app, or public financial service.  
This is a **private account manager / ledger system** for recording physical cash currencies and internal settlements.

---

## 1. Existing Infrastructure Assumption

The user already has:

- Self-hosted Supabase running on VPS.
- Existing ERP database and authentication setup.
- Existing company/branch/user structure.
- Existing accounting style data flow in ERP.
- Requirement: use the same Supabase backend/database foundation where possible.

### Development decision

Use:

- **Frontend Mobile:** Flutter
- **Backend:** Existing Supabase on VPS
- **Database:** PostgreSQL inside existing Supabase
- **Auth:** Existing Supabase Auth if already active
- **Storage:** Existing Supabase Storage for attachments/proofs
- **Offline local cache:** Drift/SQLite or Flutter local database layer
- **Deployment:** Android APK/AAB + iOS IPA/App Store build path

Do **not** create a separate backend unless required.  
Do **not** create a separate public exchange service.  
Do **not** include USDT/Binance/crypto wallet features.

---

## 2. App Name Options

Recommended internal names:

1. **FX Ledger**
2. **Currency Cash Manager**
3. **Multi-Currency Account Manager**
4. **Cash Exchange Ledger**
5. **DIN FX Ledger** if linked with existing DIN internal ERP

Best recommended name:

> **FX Cash Ledger**

Because it sounds like an internal ledger, not a public exchange service.

---

## 3. Core Business Model

The app tracks physical cash and account-based movements in multiple currencies.

Example currencies:

- PKR
- USD
- AED / Dirham
- RMB / CNY
- SAR
- Any future currency added by admin

The app should support:

- Currency rate board
- Buy/sell rate records
- Physical cash in/out
- Currency purchase/sale record
- Cross-currency conversion record
- Internal account transfers
- Expense records
- Customer/party ledger
- Agent/partner ledger
- Daily closing
- Profit/loss reporting
- Branch/cashier-wise balances
- Full audit history

---

## 4. Main User Roles

Use existing ERP role system if available.

Recommended roles:

### Super Admin
- Full access
- Can add currency
- Can change rate
- Can approve/edit/reverse transactions
- Can view all branches

### Admin / Manager
- Can create transactions
- Can approve normal transactions
- Can run closing
- Can view reports

### Cashier / Operator
- Can create buy/sell/expense/transfer records
- Cannot delete transactions
- Cannot change system settings
- Cannot backdate without permission

### Viewer / Auditor
- Read-only access
- Can view reports and audit logs

---

## 5. Core Modules

### 5.1 Dashboard

Dashboard must show:

- Today rate board
- Currency cash balances
- Today purchase total by currency
- Today sale total by currency
- Today expense total
- Today profit/loss
- Pending settlements
- Branch-wise summary
- Cashier-wise closing status
- Quick action buttons

Quick actions:

- New Currency Buy
- New Currency Sell
- New Transfer
- New Expense
- New Settlement
- Daily Closing

---

### 5.2 Currency Master

Fields:

- currency_id
- code: PKR, USD, AED, CNY/RMB
- name
- symbol
- decimal_places
- is_base_currency
- is_active
- display_order

Base currency should normally be PKR.

---

### 5.3 Rate Board

Rate board records should support day-by-day and intraday rate changes.

Fields:

- rate_id
- company_id
- branch_id nullable
- currency_code
- base_currency_code
- reference_rate
- buy_rate
- sell_rate
- buy_margin
- sell_margin
- effective_from
- effective_to nullable
- source: manual / reference / import
- note
- created_by
- created_at

Rules:

- Latest active rate appears on dashboard.
- Every rate change must be logged.
- Old rate history must never be deleted.
- Transactions must use locked rate from transaction time.
- Rate edit must not change old transaction amounts.

---

### 5.4 Cash Accounts / Currency Accounts

Each currency can have multiple accounts.

Examples:

- PKR Cash Counter 1
- PKR Bank Account
- USD Cash
- AED Cash
- RMB Cash
- Branch Safe PKR
- Agent Settlement Account

Fields:

- account_id
- company_id
- branch_id
- account_name
- currency_code
- account_type: cash / bank / agent / settlement / adjustment
- opening_balance
- current_balance calculated or derived
- is_active

Important:

- Do not mix currencies in one balance column without currency code.
- Every ledger movement must store currency_code.
- Store base_currency_equivalent for reporting.

---

### 5.5 Currency Buy

Use when the business receives foreign currency and gives PKR or another currency.

Example:

Customer gives 1,000 AED.  
Business pays 75,500 PKR.

Transaction should store:

- transaction_no
- transaction_type = currency_buy
- party_id
- from_currency = PKR
- to_currency = AED
- from_amount = 75,500
- to_amount = 1,000
- rate = 75.50
- service_fee if any
- source_account = PKR Cash
- destination_account = AED Cash
- transaction_date
- branch_id
- created_by
- status

Accounting/ledger effect:

- PKR cash decreases
- AED cash increases
- Party ledger updated if party selected

---

### 5.6 Currency Sell

Use when business gives foreign currency and receives PKR or another currency.

Example:

Customer pays 76,200 PKR.  
Business gives 1,000 AED.

Transaction should store:

- transaction_no
- transaction_type = currency_sell
- party_id
- from_currency = AED
- to_currency = PKR
- from_amount = 1,000
- to_amount = 76,200
- rate = 76.20
- service_fee if any
- source_account = AED Cash
- destination_account = PKR Cash
- transaction_date
- branch_id
- created_by
- status

Ledger effect:

- AED cash decreases
- PKR cash increases
- Realized profit/loss calculated using weighted average cost

---

### 5.7 Cross Currency Conversion

Example:

AED to RMB  
USD to RMB  
PKR to RMB

The app should support direct entry, but internally save:

- Source currency
- Destination currency
- Source amount
- Destination amount
- Rate
- Base PKR equivalent
- Fee/charges
- Account from
- Account to

Recommended accounting logic:

- Save every currency movement as ledger lines.
- Use PKR equivalent only for reporting and profit calculation.
- Keep actual currency amount separate.

---

### 5.8 Remittance / Settlement Record

Because this is private internal ledger, use safer wording:

Use **Settlement Send** and **Settlement Receive**, not public remittance service.

#### Settlement Send

Example:

Customer/party gives PKR here.  
Business records RMB payable/settlement through agent.

Fields:

- settlement_no
- party_id
- receiver_name
- receiver_country
- payout_currency
- payout_amount
- received_currency
- received_amount
- rate
- service_fee
- agent_id
- status: pending / processing / completed / cancelled / reversed
- proof_attachment
- notes

Ledger effect:

- Received account increases
- Agent payable increases
- Service income recorded if applicable

#### Settlement Receive

Example:

Agent sends instruction, business pays customer locally.

Fields:

- settlement_no
- agent_id
- receiver_party_id
- payout_currency
- payout_amount
- agent_reference
- status
- proof
- notes

Ledger effect:

- Local cash decreases
- Agent receivable increases or payable decreases
- Service income/charges if applicable

---

### 5.9 Expenses

Expense module must support multi-currency expense.

Examples:

- Courier expense in PKR
- Travel expense in AED
- China-side delivery expense in RMB
- Bank charges
- Agent fee

Fields:

- expense_id
- category
- currency_code
- amount
- base_currency_equivalent
- rate_used
- paid_from_account_id
- party_id nullable
- notes
- attachment
- created_by
- branch_id
- expense_date

Ledger effect:

- selected account decreases
- expense account increases

---

### 5.10 Party / Customer / Agent Ledger

Use one flexible contact/party module.

Party types:

- Customer
- Supplier
- Agent
- Partner
- Staff
- Other

Party ledger must show:

- Date
- Reference no
- Type
- Currency
- Debit
- Credit
- Running balance
- Base PKR equivalent
- Notes
- Attachment link

Agent ledger is important for RMB/foreign settlement tracking.

---

### 5.11 Daily Closing

Daily closing must be branch-wise and cashier-wise.

Closing screen should show:

- Opening balance by currency/account
- Total currency bought
- Total currency sold
- Total transfers in/out
- Total expenses
- System expected closing
- Physical counted closing
- Difference
- Notes
- Manager approval

Rules:

- Once closing is approved, same day transactions need manager override to edit/reverse.
- Closing difference must be recorded.
- Do not allow hidden balance changes.

---

### 5.12 Reports

Required reports:

1. Currency Stock Report
2. Daily Cash Closing Report
3. Rate History Report
4. Currency Buy/Sell Report
5. Cross Currency Report
6. Expense Report
7. Party Ledger
8. Agent Ledger
9. Profit/Loss by Currency
10. Branch Summary
11. Cashier Summary
12. Audit Log

Export options:

- PDF
- CSV/Excel
- Print
- Share file

---

## 6. Profit/Loss Logic

### Recommended Method: Weighted Average Cost

Example:

Bought AED:

- 1,000 AED @ 75
- 1,000 AED @ 76

Average cost:

- 75.50 PKR per AED

If sold:

- 500 AED @ 76.20

Profit:

- 76.20 - 75.50 = 0.70 PKR per AED
- 500 × 0.70 = 350 PKR

The system should maintain average cost per currency/account/branch.

### Alternative Methods

FIFO can also be used, but weighted average is easier for mobile ledger.

Recommended:

> Use weighted average cost in Phase 1.

---

## 7. Status Rules

Transaction statuses:

- draft
- pending
- completed
- reversed
- cancelled

Rules:

- Only completed transactions affect balances.
- Draft does not affect balance.
- Cancelled does not affect balance.
- Reversed creates opposite ledger lines.
- Never hard-delete completed transactions.

---

## 8. Audit and Security Rules

Must have:

- created_by
- created_at
- updated_by
- updated_at
- approved_by
- approved_at
- reversed_by
- reversed_at
- reversal_reason
- device_id optional
- ip_address optional if available

Security:

- User cannot delete completed transactions.
- Rate changes are logged.
- Backdated entries require permission.
- Large transactions require approval threshold.
- User can only see assigned company/branch data.

---

## 9. Supabase Database Design

Use existing Supabase.

Recommended new tables:

```sql
fx_currencies
fx_rates
fx_accounts
fx_transactions
fx_transaction_lines
fx_expenses
fx_daily_closings
fx_closing_lines
fx_parties
fx_attachments
fx_audit_logs
```

If existing tables already exist for:

- companies
- branches
- users/profiles
- contacts
- accounts
- expenses

Then reuse them where safe. Do not duplicate unless required.

### Core principle

Every financial movement should create ledger lines.

Recommended line structure:

```sql
fx_transaction_lines (
  id uuid primary key,
  company_id uuid not null,
  branch_id uuid not null,
  transaction_id uuid not null,
  account_id uuid not null,
  currency_code text not null,
  debit_amount numeric(18, 4) default 0,
  credit_amount numeric(18, 4) default 0,
  base_currency_code text default 'PKR',
  base_debit_amount numeric(18, 4) default 0,
  base_credit_amount numeric(18, 4) default 0,
  rate_used numeric(18, 8),
  line_note text,
  created_at timestamptz default now()
)
```

---

## 10. Row Level Security

RLS must be enabled.

Rules:

- User can access only own company_id.
- Branch users can access assigned branch data.
- Admin/Super Admin can access all assigned branches.
- Cashier cannot change rates unless permission is granted.
- Cashier cannot reverse completed transaction unless allowed.

Use existing ERP RLS patterns where possible.

---

## 11. Flutter App Architecture

Recommended structure:

```text
lib/
  app/
    app.dart
    router.dart
    theme.dart

  core/
    config/
    constants/
    errors/
    utils/
    widgets/

  features/
    auth/
    dashboard/
    rates/
    accounts/
    transactions/
    settlements/
    expenses/
    parties/
    reports/
    closing/
    settings/

  data/
    supabase/
    local_cache/
    repositories/

  domain/
    models/
    services/
```

State management options:

- Riverpod recommended
- Bloc acceptable
- Provider only if app is small

Recommended:

> Flutter + Riverpod + Supabase + Drift/SQLite cache

---

## 12. Offline-First Requirement

Because cash counter apps may lose internet sometimes:

- App should allow draft entries offline.
- Completed financial posting should sync carefully.
- Avoid duplicate transaction numbers.
- Server should assign final transaction number through RPC.
- Offline drafts get temporary local number.
- Sync screen should show pending uploads.

Recommended safe mode:

- Offline draft allowed
- Final completion requires online server confirmation in Phase 1

---

## 13. Transaction Numbering

Use server-side RPC for transaction numbers.

Prefixes:

- FXB-0001 = currency buy
- FXS-0001 = currency sell
- FXC-0001 = cross conversion
- FXSEND-0001 = settlement send
- FXRCV-0001 = settlement receive
- FXEXP-0001 = FX expense
- FXTR-0001 = transfer

Rule:

- Number should be company/branch safe.
- Do not reset unexpectedly after prefix change.
- Use existing ERP numbering style if already available.

---

## 14. Modern UI Direction

Style:

- Clean fintech UI
- Dark and light mode
- Soft cards
- Bold currency balances
- Clear rate board
- Minimal clutter
- Large tap buttons for cashier use
- Red/green indicators for in/out
- Charts only where useful
- Fast entry screens

Colors:

- Primary: deep navy / royal blue
- Secondary: emerald green
- Accent: amber/gold for rates
- Danger: red for reversal/loss
- Neutral: grey backgrounds

Design should look like a modern banking/cash dashboard, not a money exchange shop poster.

---

## 15. Screen List for Flutter

1. Login
2. Company/Branch Select
3. Dashboard
4. Rate Board
5. New Rate
6. Currency Buy
7. Currency Sell
8. Cross Currency
9. Account Transfer
10. Settlement Send
11. Settlement Receive
12. Expense Entry
13. Party List
14. Party Detail/Ledger
15. Agent Ledger
16. Currency Stock
17. Daily Closing
18. Reports
19. Audit Log
20. Settings

---

## 16. Build Phases for Cursor/Agent

### Phase 0 — Existing ERP/Supabase discovery

Agent should inspect:

- Existing Supabase schema
- Existing auth/profile/company/branch tables
- Existing account/contact tables
- Existing RLS policies
- Existing numbering RPCs
- Existing deployment setup

Deliverable:

- Discovery report
- Reuse vs new table plan
- Migration safety plan

### Phase 1 — Database foundation

Create migrations for:

- currencies
- rates
- fx accounts
- transactions
- transaction lines
- daily closing
- audit logs

Add RLS.

Add seed data:

- PKR
- USD
- AED
- RMB/CNY
- SAR

### Phase 2 — Flutter shell

Create:

- App routing
- Theme
- Auth
- Dashboard shell
- Supabase connection
- Branch selector
- Permission guard

### Phase 3 — Rate board + currency balances

Create:

- Rate board UI
- New rate entry
- Rate history
- Currency cash balance cards

### Phase 4 — Buy/Sell transactions

Create:

- Currency Buy form
- Currency Sell form
- Ledger posting
- Balance update
- Receipt view

### Phase 5 — Cross currency + transfer + expense

Create:

- Cross currency screen
- Internal transfer screen
- Multi-currency expense screen

### Phase 6 — Settlement send/receive

Create:

- Settlement send form
- Settlement receive form
- Agent ledger
- Proof attachment

### Phase 7 — Daily closing + reports

Create:

- Closing count screen
- Difference calculation
- Approval flow
- PDF/CSV export

### Phase 8 — Testing + production hardening

Add:

- Unit tests for calculations
- RLS tests
- Balance consistency tests
- No-delete rule tests
- Offline draft tests
- Sync conflict tests

---

## 17. Cursor Agent Prompt

Use this prompt in Cursor:

```text
You are working on an internal private multi-currency cash ledger app for Flutter and an existing self-hosted Supabase backend.

Important scope:
- This is NOT a public money exchange service.
- This is NOT a crypto/USDT/Binance wallet.
- This is a private account manager / internal ledger for physical currencies, cash accounts, expenses, settlements, and daily closing.
- Use existing Supabase VPS database foundation where possible.
- Do not create a separate backend unless necessary.

First task:
1. Inspect the existing Supabase/ERP schema.
2. Identify reusable tables for companies, branches, users, contacts, accounts, roles, and numbering.
3. Propose safe new fx_* tables only where needed.
4. Prepare migrations with RLS.
5. Build Flutter app architecture with Riverpod and Supabase.
6. Keep Android and iOS compatibility from the beginning.
7. Keep UI modern, clean, fintech-style, with dark/light mode.
8. Use server-side RPC for final transaction numbering and financial posting.
9. Never hard-delete completed transactions; use reversal entries.
10. Store every transaction with actual currency amount and PKR/base currency equivalent.
```

---

## 18. Final Recommendation

Best foundation:

> **Flutter + existing self-hosted Supabase VPS + PostgreSQL RLS + Supabase Storage + Riverpod + Drift/SQLite for local cache**

Do not start with separate Firebase, MongoDB, or local-only app.  
Because the user already has Supabase on VPS, the cleanest path is to reuse that backend and add a controlled FX ledger module.

