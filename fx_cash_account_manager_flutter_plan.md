# Private Multi-Currency Cash Account Manager — Flutter App Build Plan

**Project type:** Private/internal accounting and ledger app  
**Target platforms:** Android + iOS  
**Preferred frontend:** Flutter / Dart  
**Recommended backend:** Supabase PostgreSQL + Supabase Auth + Row Level Security  
**Local offline storage:** SQLite via Drift or equivalent Flutter SQL layer  
**Important scope note:** This is **not** a public money exchange, crypto, Binance, USDT, or mobile wallet service. This app is only for private/internal tracking of physical cash currencies, agent balances, incoming/outgoing payments, expenses, and multi-currency account ledgers.

---

## 1. Main Goal

Build a private multi-currency account manager that works like an accounting ledger for physical currency movement.

The app should manage:

- PKR cash
- USD cash, if enabled later
- AED / Dirham cash
- RMB / Chinese Yuan cash
- SAR or other currencies, if added later
- Branch-wise and cashier-wise cash balances
- Daily buy/sell rates
- Internal payment send/receive records
- Agent/partner balances
- Expenses
- Profit/loss from currency rate differences
- Daily closing by currency

This app must behave more like an **accounting and cash ledger system**, not like a public exchange platform.

---

## 2. Non-Negotiable Scope Rules

The developer/agent must follow these rules from the start:

1. Do **not** build public customer onboarding for open money exchange service.
2. Do **not** build Binance, USDT, crypto wallet, blockchain, or mobile wallet integration.
3. Do **not** build automatic public remittance service like Western Union or MoneyGram.
4. Do **not** allow transaction deletion after posting.
5. Wrong transactions must be reversed through a reverse entry.
6. Every financial transaction must have an audit trail.
7. Every transaction must store the original currency amount and PKR equivalent value.
8. PKR should be the base currency for reports.
9. Rates must be locked at transaction time.
10. Rate changes must be logged with user, date, time, and reason.

---

## 3. Recommended Foundation

### 3.1 Why Flutter

Use Flutter because the same codebase can target both Android and iOS. The app should be planned as mobile-first from day one.

### 3.2 Recommended Stack

```txt
Frontend: Flutter + Dart
State Management: Riverpod or Bloc
Navigation: GoRouter
Local DB: Drift / SQLite
Backend: Supabase PostgreSQL
Auth: Supabase Auth
Security: Supabase RLS policies
Sync: Offline-first local DB + cloud sync
Reports: Flutter PDF package or backend PDF service
Exports: CSV / PDF
```

### 3.3 App Architecture

Use clean architecture:

```txt
lib/
  core/
    constants/
    errors/
    utils/
    theme/
    permissions/
  features/
    auth/
    dashboard/
    currencies/
    rate_board/
    accounts/
    exchange/
    remittance_records/
    agents/
    expenses/
    daily_closing/
    reports/
    settings/
    audit_logs/
  data/
    local/
    remote/
    sync/
  shared/
    widgets/
    models/
    validators/
```

---

## 4. Business Terminology

Use these names inside the app:

| Term | Meaning |
|---|---|
| Currency | PKR, AED, RMB, USD, SAR etc. |
| Account | Cash box, branch cash, agent balance, expense account etc. |
| Rate Board | Daily buy/sell/reference rate list |
| Transaction | Any financial movement |
| Exchange Transaction | Buy/sell/cross-currency movement |
| Remittance Record | Internal record of money sent/received through a known agent/partner |
| Agent | External party/partner through whom RMB/AED/PKR settlement is tracked |
| Daily Closing | End-of-day physical cash count and expected system balance |
| Reverse Entry | Correction entry instead of delete |

---

## 5. Main Modules

## 5.1 Dashboard

Dashboard should show:

- Today rate board
- Currency-wise cash balance
- Today PKR inflow/outflow
- Today currency buy/sell summary
- Today expenses
- Today estimated profit/loss
- Pending payment send/receive records
- Agent receivable/payable summary
- Branch-wise balance, if branches are enabled
- Rate last updated time

### Dashboard widgets

```txt
1. Rate Board Card
2. Cash Position Card
3. Today Transactions Card
4. Pending Send/Receive Card
5. Agent Balance Card
6. Expense Summary Card
7. Profit/Loss Card
8. Daily Closing Status Card
```

---

## 5.2 Currency Master

Admin can define currencies:

```txt
currency_code: PKR, AED, RMB, USD, SAR
currency_name: Pakistani Rupee, UAE Dirham, Chinese Yuan
symbol: Rs, د.إ, ¥
decimal_places: 2
is_base_currency: true/false
is_active: true/false
```

Rules:

- Only one base currency: PKR.
- Inactive currency should not appear in new transactions.
- Old transactions must keep inactive currency visible in reports.

---

## 5.3 Rate Board

Rate Board is one of the most important screens.

Fields:

```txt
currency_from
currency_to
reference_rate
buy_rate
sell_rate
effective_date
effective_time
source: manual / market / previous_day / other
notes
created_by
approved_by
```

Example:

| Pair | Reference | Buy | Sell |
|---|---:|---:|---:|
| AED/PKR | 75.80 | 75.50 | 76.20 |
| RMB/PKR | 38.50 | 38.20 | 39.00 |
| USD/PKR | 278.50 | 278.00 | 279.20 |

Rules:

1. Rate should be editable by admin/manager only.
2. Every rate change should create a history record.
3. A posted transaction must keep its own locked rate.
4. Later rate changes must not change old transaction values.
5. Dashboard should show latest active rates.

---

## 5.4 Accounts / Cash Boxes

Accounts represent where money is physically or logically held.

Examples:

```txt
Main Cash PKR
Main Cash AED
Main Cash RMB
Branch 1 Cash PKR
Branch 1 Cash AED
Agent Ali RMB Payable
Agent China Office Receivable
Expense Account
Owner Capital
```

Account fields:

```txt
account_id
account_name
account_type
currency_code
branch_id
opening_balance
current_balance
is_cash_account
is_agent_account
is_expense_account
is_active
```

Account types:

```txt
cash
agent_receivable
agent_payable
expense
income
equity
adjustment
```

Rules:

1. Every account must have a currency.
2. Same-currency transfers do not create FX profit/loss.
3. Cross-currency transactions must use rate and PKR equivalent.
4. Cash accounts must be included in daily closing.

---

## 5.5 Exchange Transactions

This module handles physical currency exchange records.

### Transaction types

```txt
currency_buy
currency_sell
cross_currency_exchange
account_transfer
rate_adjustment
reverse_entry
```

### Currency Buy Example

Customer gives AED and receives PKR.

```txt
Customer gives: 1000 AED
Buy rate: 75.50
Customer receives: 75,500 PKR
```

System effect:

```txt
AED Cash +1000
PKR Cash -75,500
Rate locked: 75.50
PKR equivalent saved: 75,500
```

### Currency Sell Example

Customer gives PKR and receives AED.

```txt
Customer pays: 76,200 PKR
Sell rate: 76.20
Customer receives: 1000 AED
```

System effect:

```txt
PKR Cash +76,200
AED Cash -1000
Rate locked: 76.20
Profit calculated using weighted average cost
```

### Cross Currency Example

Customer gives AED and receives RMB.

Recommended internal calculation:

```txt
AED value in PKR = AED amount × AED/PKR rate
RMB value in PKR = RMB amount × RMB/PKR rate
Difference = gain/loss or service margin
```

System effect:

```txt
AED Cash increases
RMB Cash decreases
PKR equivalent saved for both sides
Difference posted to FX Gain/Loss
```

---

## 5.6 Payment Send / Receive Records

This is not a public remittance service. This is an internal record module for payments that are sent or received through known parties/agents.

### Payment Send Record

Use case:

Customer/party gives PKR locally, and RMB needs to be paid/settled outside through an agent/partner.

Fields:

```txt
record_no
sender_name
receiver_name
receiver_country
receiver_currency
from_account
from_currency
from_amount
payout_currency
payout_amount
rate
service_charges
agent_id
agent_account
status: draft / pending / completed / cancelled / reversed
proof_attachment
notes
```

Accounting effect:

```txt
Local cash/account increases if money received
Agent payable increases if agent has to pay outside
Service charges income recorded if applicable
```

### Payment Receive Record

Use case:

Agent/partner has sent instruction, and local payout is given here.

Fields:

```txt
record_no
agent_id
receiver_name
receiver_contact
receiver_id_document_optional
payout_account
payout_currency
payout_amount
agent_currency
agent_amount
rate
charges
status
proof_attachment
```

Accounting effect:

```txt
Local cash decreases when payout is made
Agent receivable increases or payable decreases depending on settlement model
```

---

## 5.7 Agent / Partner Ledger

Agent ledger is very important for RMB/AED/PKR settlements.

Each agent should have:

```txt
agent_name
contact
country
currency
opening_balance
receivable_balance
payable_balance
status
notes
```

Agent ledger should show:

```txt
date
reference_no
type
currency
debit
credit
balance
linked_transaction
notes
```

Reports:

- Agent statement
- Agent receivable/payable summary
- Agent pending settlement list
- Agent currency-wise balance

---

## 5.8 Expenses

The app should support expenses because the user wants it as an account manager too.

Expense fields:

```txt
expense_no
date
expense_category
paid_from_account
currency
amount
rate_to_pkr
pkr_equivalent
notes
attachment
created_by
```

Examples:

```txt
Office rent
Courier
Tea/food
Travel
Mobile balance
Bank charges
Agent fee
```

Accounting effect:

```txt
Expense increases
Cash/account decreases
PKR equivalent saved
```

---

## 5.9 Daily Closing

Daily closing must be currency-wise.

Fields:

```txt
closing_date
branch_id
account_id
currency_code
system_opening
inflow_total
outflow_total
expected_closing
physical_count
difference
status: draft / submitted / approved
notes
```

Rules:

1. Cashier enters physical count.
2. System compares expected vs actual.
3. Difference must be explained.
4. Approved closing should lock the day.
5. Locked day transactions need admin override or adjustment entry.

---

## 5.10 Reports

Required reports:

```txt
1. Currency Cash Balance Report
2. Daily Rate History Report
3. Currency Buy/Sell Report
4. Cross Currency Exchange Report
5. Agent Ledger Report
6. Pending Send/Receive Report
7. Expense Report
8. Daily Closing Report
9. Profit/Loss Report
10. Audit Log Report
11. Account Ledger Report
12. Branch-wise Currency Balance Report
```

Every report should support:

```txt
Date range
Currency filter
Account filter
Agent filter
Branch filter
PDF export
CSV export
Print
```

---

## 6. Profit / Loss Calculation

Use PKR as base currency.

For currency stock, use weighted average cost.

### Weighted Average Example

Buy AED:

```txt
1000 AED @ 75.00 = 75,000 PKR
1000 AED @ 76.00 = 76,000 PKR
Total AED = 2000
Total PKR cost = 151,000
Average cost = 75.50 PKR per AED
```

Sell AED:

```txt
500 AED sold @ 76.20
Sale value = 38,100 PKR
Cost value = 500 × 75.50 = 37,750 PKR
Profit = 350 PKR
```

Rules:

1. Profit only realizes when currency is sold or exchanged out.
2. Rate board changes should not directly change realized profit.
3. Optional unrealized gain/loss can be shown separately.
4. Reports must clearly separate realized profit from estimated revaluation.

---

## 7. Database Schema Draft

Use PostgreSQL for cloud database.

### 7.1 currencies

```sql
create table currencies (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  symbol text,
  decimal_places int not null default 2,
  is_base_currency boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
```

### 7.2 fx_rates

```sql
create table fx_rates (
  id uuid primary key default gen_random_uuid(),
  from_currency text not null references currencies(code),
  to_currency text not null references currencies(code),
  reference_rate numeric(18,6) not null,
  buy_rate numeric(18,6) not null,
  sell_rate numeric(18,6) not null,
  effective_at timestamptz not null default now(),
  source text not null default 'manual',
  notes text,
  created_by uuid,
  approved_by uuid,
  created_at timestamptz not null default now()
);
```

### 7.3 accounts

```sql
create table accounts (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid,
  name text not null,
  account_type text not null,
  currency_code text not null references currencies(code),
  opening_balance numeric(18,4) not null default 0,
  current_balance numeric(18,4) not null default 0,
  is_cash_account boolean not null default false,
  is_agent_account boolean not null default false,
  is_expense_account boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
```

### 7.4 agents

```sql
create table agents (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  country text,
  default_currency text references currencies(code),
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
```

### 7.5 transactions

```sql
create table transactions (
  id uuid primary key default gen_random_uuid(),
  transaction_no text not null unique,
  transaction_type text not null,
  transaction_date timestamptz not null default now(),
  branch_id uuid,
  party_name text,
  agent_id uuid references agents(id),
  status text not null default 'draft',
  notes text,
  reversed_transaction_id uuid references transactions(id),
  created_by uuid,
  approved_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

### 7.6 transaction_lines

```sql
create table transaction_lines (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references transactions(id) on delete restrict,
  line_no int not null,
  account_id uuid not null references accounts(id),
  currency_code text not null references currencies(code),
  debit_amount numeric(18,4) not null default 0,
  credit_amount numeric(18,4) not null default 0,
  rate_to_pkr numeric(18,6) not null default 1,
  pkr_equivalent_debit numeric(18,4) not null default 0,
  pkr_equivalent_credit numeric(18,4) not null default 0,
  description text,
  created_at timestamptz not null default now()
);
```

### 7.7 expenses

```sql
create table expenses (
  id uuid primary key default gen_random_uuid(),
  expense_no text not null unique,
  expense_date timestamptz not null default now(),
  category text not null,
  paid_from_account_id uuid not null references accounts(id),
  currency_code text not null references currencies(code),
  amount numeric(18,4) not null,
  rate_to_pkr numeric(18,6) not null,
  pkr_equivalent numeric(18,4) not null,
  notes text,
  created_by uuid,
  created_at timestamptz not null default now()
);
```

### 7.8 daily_closings

```sql
create table daily_closings (
  id uuid primary key default gen_random_uuid(),
  closing_date date not null,
  branch_id uuid,
  account_id uuid not null references accounts(id),
  currency_code text not null references currencies(code),
  system_opening numeric(18,4) not null default 0,
  inflow_total numeric(18,4) not null default 0,
  outflow_total numeric(18,4) not null default 0,
  expected_closing numeric(18,4) not null default 0,
  physical_count numeric(18,4) not null default 0,
  difference numeric(18,4) not null default 0,
  status text not null default 'draft',
  notes text,
  created_by uuid,
  approved_by uuid,
  created_at timestamptz not null default now()
);
```

### 7.9 audit_logs

```sql
create table audit_logs (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid,
  action text not null,
  old_data jsonb,
  new_data jsonb,
  reason text,
  user_id uuid,
  created_at timestamptz not null default now()
);
```

---

## 8. Screens Required in Flutter

### 8.1 Auth

```txt
Login
PIN / biometric unlock optional
Forgot password optional
```

### 8.2 Home / Dashboard

```txt
Rate board
Cash balances
Today activity
Pending records
Quick actions
```

Quick actions:

```txt
New Buy
New Sell
New Payment Send
New Payment Receive
New Expense
Daily Closing
```

### 8.3 Rate Board Screen

```txt
List latest rates
Add/update rate
Rate history
Currency pair filter
```

### 8.4 Accounts Screen

```txt
Account list
Account detail
Currency-wise balance
Opening balance
Account ledger
```

### 8.5 New Exchange Screen

Form fields:

```txt
Type: Buy / Sell / Cross Currency
Party name optional
From account
From currency
From amount
To account
To currency
To amount
Rate
Charges
Notes
Attachment optional
```

The app must auto-calculate:

```txt
Converted amount
PKR equivalent
Profit/loss estimate
```

### 8.6 Payment Send Screen

```txt
Sender name
Receiver name
Agent
From account
From currency
From amount
Payout currency
Payout amount
Rate
Charges
Status
Proof image/document
```

### 8.7 Payment Receive Screen

```txt
Agent
Receiver name
Payout account
Payout currency
Payout amount
Agent amount
Rate
Charges
Status
Proof image/document
```

### 8.8 Agent Ledger Screen

```txt
Agent list
Agent balance
Agent ledger detail
Settlement entry
PDF/CSV export
```

### 8.9 Expense Screen

```txt
New expense
Expense list
Expense category summary
Currency-wise expense report
```

### 8.10 Daily Closing Screen

```txt
Select date
Select account
System balance
Physical count input
Difference
Submit
Approve
Print/PDF
```

### 8.11 Reports Screen

```txt
Account ledger
Currency balance
Rate history
Transaction report
Agent ledger
Daily closing
Profit/loss
Expense report
```

### 8.12 Settings

```txt
Currencies
Accounts
Branches
Users
Roles
Permissions
Numbering
Backup/sync
```

---

## 9. Permissions

Roles:

```txt
owner
admin
manager
cashier
viewer
```

Permissions:

| Action | Owner | Admin | Manager | Cashier | Viewer |
|---|---|---|---|---|---|
| View dashboard | yes | yes | yes | yes | yes |
| Add transaction | yes | yes | yes | yes | no |
| Approve transaction | yes | yes | yes | no | no |
| Change rate | yes | yes | yes | no | no |
| Reverse transaction | yes | yes | no/optional | no | no |
| Daily closing submit | yes | yes | yes | yes | no |
| Daily closing approve | yes | yes | yes | no | no |
| View reports | yes | yes | yes | limited | yes |
| Manage settings | yes | yes | no | no | no |

---

## 10. Numbering Rules

Use separate number series:

```txt
FXB-0001 = currency buy
FXS-0001 = currency sell
FXC-0001 = cross currency
PS-0001  = payment send
PR-0001  = payment receive
EXP-0001 = expense
CLS-0001 = daily closing
REV-0001 = reverse entry
```

Rules:

1. Numbers must be generated server-side or through a safe local sequence with sync protection.
2. Number should not duplicate.
3. Branch prefix optional: HQ-FXB-0001.
4. If branch prefix is enabled later, numbering should continue from existing max number, not reset.

---

## 11. Validation Rules

1. Amount must be greater than zero.
2. Rate must be greater than zero for cross-currency transactions.
3. Currency account must match account currency.
4. Cash account cannot go negative unless admin setting allows it.
5. Completed transaction cannot be edited directly.
6. Completed transaction can only be reversed.
7. Rate must be locked at posting time.
8. Daily closing difference must require notes.
9. Pending payment send/receive must not affect final closing unless marked completed, unless business setting says otherwise.
10. Agent settlement must update agent ledger.

---

## 12. Offline-First Requirement

The app should work even when internet is weak.

Local storage should save:

```txt
currencies
latest rates
accounts
agents
transactions created offline
daily closing drafts
expenses
```

Sync rules:

1. Every local record gets a local UUID.
2. When internet returns, sync to Supabase.
3. If conflict happens, server-approved posted transaction wins.
4. Rate board conflict should require admin review.
5. Completed transaction cannot be silently changed by sync.

---

## 13. Audit Rules

Every important action must create audit log:

```txt
rate_created
rate_updated
transaction_created
transaction_posted
transaction_reversed
daily_closing_submitted
daily_closing_approved
account_created
account_updated
agent_created
agent_updated
expense_created
```

Audit log must store:

```txt
user
branch
time
device
old_data
new_data
reason
```

---

## 14. Suggested Build Phases for Cursor Agent

### Phase 0 — Project Setup

Tasks:

1. Create Flutter project.
2. Add folder architecture.
3. Add theme, routes, constants.
4. Add Supabase client config.
5. Add local SQLite/Drift setup.
6. Add environment config for dev/prod.
7. Add base error handling.

Deliverable:

```txt
Flutter app boots on Android and iOS simulator.
Login placeholder works.
Navigation shell works.
```

---

### Phase 1 — Core Master Data

Tasks:

1. Currency master CRUD.
2. Account master CRUD.
3. Agent master CRUD.
4. Branch optional support.
5. Opening balance setup.

Deliverable:

```txt
Admin can create currencies, accounts, and agents.
Cash accounts show balance by currency.
```

---

### Phase 2 — Rate Board

Tasks:

1. Add rate board table.
2. Latest rate screen.
3. Rate history screen.
4. Buy/sell/reference rate.
5. Rate change audit log.

Deliverable:

```txt
Dashboard shows latest rates.
Admin can update rates.
Old rates remain in history.
```

---

### Phase 3 — Exchange Transactions

Tasks:

1. Currency buy form.
2. Currency sell form.
3. Cross-currency form.
4. Rate lock at posting.
5. Transaction lines generation.
6. Account balance update.
7. Reverse entry support.

Deliverable:

```txt
User can post buy/sell/cross-currency records.
Balances update correctly.
Completed transaction cannot be edited directly.
```

---

### Phase 4 — Payment Send / Receive Records

Tasks:

1. Payment send form.
2. Payment receive form.
3. Agent payable/receivable ledger.
4. Status flow: draft/pending/completed/reversed.
5. Proof attachment.

Deliverable:

```txt
Internal send/receive records work.
Agent ledger updates correctly.
Pending and completed records are separate.
```

---

### Phase 5 — Expenses

Tasks:

1. Expense categories.
2. Expense entry.
3. Multi-currency expense support.
4. Expense report.

Deliverable:

```txt
User can enter expenses from any currency account.
Reports show PKR equivalent and original currency.
```

---

### Phase 6 — Daily Closing

Tasks:

1. Closing by account and currency.
2. Expected vs physical balance.
3. Difference notes.
4. Submit/approve flow.
5. Closing report PDF.

Deliverable:

```txt
Cashier can close day currency-wise.
Admin can approve closing.
Difference is highlighted.
```

---

### Phase 7 — Reports

Tasks:

1. Account ledger report.
2. Currency balance report.
3. Agent ledger report.
4. Rate history report.
5. Profit/loss report.
6. Expense report.
7. PDF/CSV export.

Deliverable:

```txt
All core financial reports export to PDF/CSV.
Reports support date range and currency filters.
```

---

### Phase 8 — Offline Sync and Production Hardening

Tasks:

1. Offline drafts.
2. Sync queue.
3. Conflict detection.
4. Error retry.
5. Device id tracking.
6. Security rules.
7. Backup/export.

Deliverable:

```txt
App works during weak internet.
Transactions sync safely.
No duplicate transaction numbers.
```

---

## 15. Cursor Agent Master Prompt

Use this prompt in Cursor or any coding agent:

```txt
You are building a private internal multi-currency cash account manager app in Flutter for Android and iOS.

Important: This is not a public money exchange, remittance platform, crypto app, Binance app, USDT wallet, or mobile wallet service. It is only an internal ledger/account manager for physical currency cash balances, exchange records, internal payment send/receive records, agent balances, expenses, and daily closing.

Use Flutter/Dart with clean architecture. Prefer Riverpod or Bloc for state management, GoRouter for navigation, Drift/SQLite for local offline storage, and Supabase PostgreSQL/Auth/RLS for backend sync. Build the foundation mobile-first for Android and iOS.

Base currency is PKR. Other currencies include AED, RMB, USD, SAR and future custom currencies. Every transaction must store original currency amount, rate, and PKR equivalent. Rates must be locked at transaction time. Completed transactions must not be edited or deleted; corrections must be done by reverse entries. Every rate change and transaction action must create an audit log.

Build modules step by step:
1. Project setup and architecture.
2. Currency, account, and agent master data.
3. Rate board with buy/sell/reference rate and history.
4. Currency buy/sell/cross-currency transactions.
5. Internal payment send/receive records with agent ledger.
6. Expenses.
7. Daily closing by account/currency.
8. Reports with PDF/CSV.
9. Offline-first sync and production hardening.

Do not skip validation, permissions, audit logs, reversal flow, daily closing, or rate locking. Keep code modular and testable. After every phase, provide a markdown completion report with changed files, tests run, and remaining risks.
```

---

## 16. Acceptance Criteria

The app is acceptable only when:

1. Android build passes.
2. iOS build passes.
3. Dashboard loads latest rate board.
4. Currency balances are correct.
5. Buy transaction updates both currencies correctly.
6. Sell transaction calculates profit correctly.
7. Cross-currency transaction stores PKR equivalent for both sides.
8. Payment send/receive updates agent ledger correctly.
9. Expense reduces correct account balance.
10. Daily closing shows expected vs physical balance.
11. Completed transaction cannot be edited/deleted.
12. Reverse entry works.
13. Audit log is created.
14. PDF/CSV reports work.
15. Offline draft and sync flow works.

---

## 17. Important Business Decision

Start with this name:

```txt
Private FX Cash Account Manager
```

Avoid public-facing names like:

```txt
Money Exchange App
Remittance App
Western Union Style App
Crypto Exchange
USDT Wallet
```

Reason: The real requirement is account management, physical cash tracking, agent ledger, rate board, and multi-currency accounting — not public exchange service.

---

## 18. Final Build Direction

Best foundation from day one:

```txt
Flutter mobile app
Clean architecture
Offline-first SQLite
Supabase backend sync
PKR base currency
Manual/admin-controlled rate board
Physical cash accounts
Agent ledger
Daily closing
Audit-first transaction design
No delete, only reverse entry
```

This foundation will allow Android and iOS apps now, and later web/admin dashboard can also be added if needed.
