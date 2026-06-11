# FX Cash Ledger V2 — Google Stitch UI Prompt
## Proper Accounting + Multi-Currency Mobile UI

Use this prompt in Google Stitch.

---

## Product

Design a premium modern mobile app for **FX Cash Ledger**, a private internal multi-currency account manager with proper accounting.

This is not a public money exchange app.  
This is not crypto/USDT/Binance.  
This is an internal ledger app for physical currencies, cash accounts, rates, settlements, expenses, and double-entry accounting.

---

## Must include accounting screens

Create UI for:

1. Dashboard
2. Rate Board
3. Currency Buy
4. Currency Sell
5. Cross Currency Conversion
6. Account Transfer
7. Expense Entry
8. Settlement Send
9. Settlement Receive
10. Party Ledger
11. Agent Ledger
12. Chart of Accounts
13. Account Detail
14. General Ledger
15. Trial Balance
16. Profit & Loss
17. Balance Sheet
18. Currency Position Report
19. Journal Entry Detail
20. Manual Journal Entry, admin only
21. Daily Closing
22. Audit Log
23. Reports
24. Settings

---

## Design Style

Premium fintech/accounting UI:

- Clean
- Modern
- Trustworthy
- Professional
- Easy for cashier/manager
- Not too busy
- Large numbers
- Clear cards
- Strong spacing
- Light and dark mode
- Rounded cards
- Smooth shadows
- Minimal clutter

Color direction:

- Deep navy / royal blue primary
- Emerald green for cash-in/profit/completed
- Soft red for cash-out/loss/reversal
- Amber/gold for rate board/pending/revaluation
- Grey/off-white backgrounds
- Dark charcoal for dark mode

---

## Dashboard Requirements

Dashboard top:

- Branch selector
- Date filter
- Sync status
- Profile icon

Top KPI cards:

- Total Assets
- Total Liabilities
- Net Equity
- Today Profit/Loss

Currency balance cards:

- PKR Cash
- USD Cash
- AED Cash
- RMB/CNY Cash
- SAR Cash

Rate board cards:

- Reference rate
- Buy rate
- Sell rate
- Last updated

Accounting health card:

- Trial Balance: Balanced / Not Balanced
- Unposted Transactions
- Pending Closings
- Cash Difference
- Reversal Count

Quick actions:

- Buy
- Sell
- Transfer
- Expense
- Settlement
- Journal Entry
- Daily Closing

---

## Chart of Accounts Screen

Show account tree:

- Assets
- Liabilities
- Equity
- Income
- Expenses
- Adjustments

Each account row:

- Code
- Name
- Type
- Currency if fixed
- Current balance
- Active/inactive badge

Actions:

- Add account
- Edit account
- View ledger

---

## General Ledger Screen

Filters:

- Date range
- Account
- Currency
- Branch
- Party
- Transaction type

Ledger row:

- Date
- Entry no
- Description
- Currency
- Debit
- Credit
- Running balance

Top summary:

- Opening balance
- Period debit
- Period credit
- Closing balance

---

## Trial Balance Screen

Show modern accounting table/cards:

Columns:

- Account code
- Account name
- Debit
- Credit

Top status:

- Balanced
- Difference amount if not balanced

Use green badge for balanced and red warning for not balanced.

---

## Profit & Loss Screen

Sections:

- Income
- Expenses
- Net Profit / Net Loss

Income cards:

- Exchange Spread Income
- Service Charges Income
- Settlement Charges Income
- Revaluation Gain

Expense cards:

- Agent Charges
- Bank Charges
- Delivery/Courier
- Salary
- Rent
- Currency Shortage/Loss
- Revaluation Loss

---

## Balance Sheet Screen

Sections:

- Assets
- Liabilities
- Equity

Top formula card:

Assets = Liabilities + Equity

Show balance status:

- Balanced
- Difference

---

## Currency Position Report

Show currency stock:

- Currency
- Actual amount
- Average cost
- Current rate
- PKR equivalent
- Unrealized gain/loss

Use clean cards for each currency.

---

## Journal Entry Detail

Show:

- Entry no
- Date
- Source type
- Status
- Description
- Created by
- Approved by

Journal lines table:

- Account
- Currency
- Debit
- Credit
- PKR equivalent
- Notes

Actions:

- Print
- Share PDF
- Reverse Entry

Do not show delete button for posted entries.

---

## Daily Closing

Show:

- Expected closing by currency/account
- Physical counted amount input
- Difference
- Notes
- Attachment/proof
- Submit for approval

Use green if matched, red if short, amber if excess.

---

## Master Stitch Prompt

```text
Design a premium mobile UI for FX Cash Ledger V2, a private internal multi-currency cash account manager with full double-entry accounting.

Important: this is not a public money exchange app, not crypto, not USDT, not Binance. It is an internal accounting ledger app for physical currencies, rates, settlements, expenses, cash accounts, daily closing, and accounting reports.

The app must feel like a modern banking/accounting dashboard. Use deep navy/royal blue, emerald green, amber/gold, soft red, rounded cards, large numbers, clean spacing, light and dark mode.

Create these screens:
Dashboard, Rate Board, Currency Buy, Currency Sell, Cross Currency Conversion, Account Transfer, Expense Entry, Settlement Send, Settlement Receive, Party Ledger, Agent Ledger, Chart of Accounts, Account Detail, General Ledger, Trial Balance, Profit & Loss, Balance Sheet, Currency Position Report, Journal Entry Detail, Manual Journal Entry, Daily Closing, Audit Log, Reports, Settings.

Dashboard must include:
Total Assets, Total Liabilities, Net Equity, Today Profit/Loss, PKR/USD/AED/RMB/SAR cash balances, rate board with reference/buy/sell rates, accounting health card showing Trial Balance balanced/not balanced, unposted transactions, pending closings, cash difference, and reversal count.

Transaction forms must have large numeric inputs, currency chips, source/destination account selectors, rate locked badge, live PKR equivalent, notes, attachment/proof, and sticky bottom buttons.

Accounting screens must be clean and readable: Chart of Accounts tree, General Ledger rows, Trial Balance with debit/credit totals, Profit & Loss by income/expense, Balance Sheet with Assets = Liabilities + Equity, Currency Position with actual amount and PKR equivalent, and Journal Entry detail with debit/credit lines.

Use bottom navigation: Dashboard, Transactions, Accounting, Reports, More. Add a central quick action button for Buy, Sell, Transfer, Expense, Settlement, Journal Entry, and Daily Closing.
```
