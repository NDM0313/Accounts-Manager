# Google Stitch UI Design Prompt
## FX Cash Ledger — Private Multi-Currency Account Manager

**Use this document in Google Stitch to generate the mobile app UI.**

---

## 1. Product Summary

Design a modern mobile app UI for a **private multi-currency cash ledger and account manager**.

This app is for internal/private use only.  
It is not a public money exchange service, not a crypto app, not Binance/USDT, and not a public remittance platform.

The app tracks physical cash currencies, exchange rates, internal settlements, cash accounts, expenses, and daily closing.

Supported currencies:

- PKR
- USD
- AED / Dirham
- RMB / CNY
- SAR
- More currencies can be added later

---

## 2. Design Style

Create a premium modern fintech mobile UI.

Style keywords:

- Clean
- Premium
- Trustworthy
- Fast for cashier use
- Mobile-first
- Easy for non-technical users
- Minimal clutter
- Large readable numbers
- Clear currency cards
- Soft shadows
- Rounded cards
- Smooth spacing
- Modern banking dashboard style
- Dark mode and light mode support

Do not design it like a public money exchange advertisement.  
Design it like a private internal finance/accounting app.

---

## 3. Color Direction

Use a professional color palette.

Recommended:

- Primary: Deep Navy / Royal Blue
- Secondary: Emerald Green
- Accent: Amber / Gold for rate board
- Danger: Soft Red for loss/reversal
- Warning: Orange for pending items
- Background: Light grey / off-white
- Dark mode: Charcoal / near black with soft cards

Use color meaning:

- Green = cash in / profit / completed
- Red = cash out / loss / reversed
- Amber = rates / pending / attention
- Blue = navigation / main actions

---

## 4. Typography

Use modern, readable typography.

Requirements:

- Large currency numbers
- Strong card headings
- Clean labels
- Good spacing
- Avoid tiny text
- Forms should be easy to use on mobile

Suggested style:

- Bold for balances
- Medium weight for labels
- Small text only for notes and timestamps

---

## 5. Main Navigation

Use bottom navigation with 5 primary tabs:

1. Dashboard
2. Rates
3. Transactions
4. Ledger
5. More

Floating quick action button:

- New Buy
- New Sell
- New Transfer
- New Expense
- New Settlement

Alternative: use a central plus button in bottom nav.

---

## 6. Screen 1 — Login

Design a clean login screen.

Elements:

- App logo placeholder: FX Cash Ledger
- Email/phone field
- Password field
- Login button
- Branch/company note
- Soft gradient or clean card layout

Mood:

- Secure
- Professional
- Simple

---

## 7. Screen 2 — Dashboard

Dashboard should be the main screen.

Top area:

- Greeting: “Welcome back”
- Branch selector
- Date filter
- Profile icon
- Sync status icon

Main cards:

### Today Rate Board
Show currencies in compact cards:

- USD/PKR
- AED/PKR
- RMB/PKR
- SAR/PKR

Each card shows:

- Buy rate
- Sell rate
- Last updated
- Small up/down indicator

### Cash Position
Show currency balances:

- PKR Cash
- USD Cash
- AED Cash
- RMB Cash

Use large numbers and currency symbols.

### Today Summary
Cards:

- Total Buy
- Total Sell
- Expenses
- Profit/Loss
- Pending Settlements

### Quick Actions
Large buttons:

- Buy Currency
- Sell Currency
- Transfer
- Expense
- Settlement

Design should be clean and not too busy.

---

## 8. Screen 3 — Rate Board

Rate board screen.

Elements:

- Currency list
- Buy rate
- Sell rate
- Reference rate
- Last updated time
- Edit button for authorized users
- Rate history button

Design:

- Table-like mobile cards
- Each currency as card
- Amber/gold accent for rates
- Clear “Update Rate” button

---

## 9. Screen 4 — New Rate Entry

Form fields:

- Currency
- Reference rate
- Buy margin
- Sell margin
- Buy rate auto-calculated
- Sell rate auto-calculated
- Effective time
- Notes

Bottom sticky button:

- Save Rate

Add warning text:

- “New rate applies only to future transactions.”

---

## 10. Screen 5 — Currency Buy

This screen is for recording currency received from party and cash paid out.

Header:

- Currency Buy
- Auto transaction no placeholder

Fields:

- Party/customer
- Received currency
- Received amount
- Paid currency
- Rate
- Paid amount auto-calculated
- Source account
- Destination account
- Fee/charges optional
- Notes
- Attachment/proof

Summary card:

- Customer gives
- Business pays
- Rate locked
- Fee
- Final amount

Bottom buttons:

- Save Draft
- Complete Transaction

Design:

- Large numeric input
- Calculator-like clean layout
- Currency chips
- Rate lock badge

---

## 11. Screen 6 — Currency Sell

This screen is for recording currency given to party and cash received.

Fields:

- Party/customer
- Sold currency
- Sold amount
- Received currency
- Rate
- Received amount auto-calculated
- Source account
- Destination account
- Fee/charges
- Notes
- Attachment/proof

Summary card:

- Business gives
- Customer pays
- Estimated profit
- Rate locked

Bottom buttons:

- Save Draft
- Complete Transaction

---

## 12. Screen 7 — Cross Currency Conversion

Use when converting one currency to another.

Fields:

- From currency
- From amount
- To currency
- Rate
- To amount
- From account
- To account
- Base PKR equivalent
- Fee
- Notes

Design:

- Two large currency panels side by side or vertical
- Swap icon between currencies
- Rate lock card
- Clean conversion summary

---

## 13. Screen 8 — Internal Transfer

Use for moving money between accounts.

Fields:

- From account
- To account
- Currency
- Amount
- Transfer date
- Notes
- Attachment optional

Show:

- Current balance before transfer
- Balance after transfer

---

## 14. Screen 9 — Expense Entry

Fields:

- Expense category
- Currency
- Amount
- Paid from account
- Rate used for PKR equivalent
- Party optional
- Notes
- Attachment

Summary:

- Expense amount
- PKR equivalent
- Account balance after expense

---

## 15. Screen 10 — Settlement Send

Use safer wording: “Settlement Send”.

Fields:

- Party/customer
- Receiver name
- Receiver country
- Payout currency
- Payout amount
- Received currency
- Received amount
- Rate
- Service fee
- Agent/partner
- Status
- Proof attachment
- Notes

Status chips:

- Pending
- Processing
- Completed
- Reversed

Design:

- Step form layout
- 3 sections: Sender, Receiver, Payment
- Clear summary card

---

## 16. Screen 11 — Settlement Receive

Fields:

- Agent/partner
- Receiver party
- Payout currency
- Payout amount
- Local account paid from
- Agent reference
- Proof attachment
- Status
- Notes

Summary:

- Agent balance impact
- Cash paid
- Remaining balance

---

## 17. Screen 12 — Party Ledger

Party detail screen.

Top:

- Party name
- Party type
- Phone
- Current balance by currency

Ledger list:

- Date
- Reference
- Type
- Currency
- Debit
- Credit
- Running balance
- Notes

Filters:

- Date range
- Currency
- Transaction type

Buttons:

- New transaction
- Export PDF
- Share

---

## 18. Screen 13 — Agent Ledger

Agent ledger for settlement partners.

Top cards:

- Payable
- Receivable
- Net balance
- Currency-wise balance

Ledger rows:

- Settlement send
- Settlement receive
- Adjustment
- Payment
- Expense/fee

Use strong color indicators for payable/receivable.

---

## 19. Screen 14 — Daily Closing

Daily closing screen.

Sections:

### System Balance
Show expected closing by account/currency.

### Physical Count
User enters counted cash.

### Difference
Show difference:

- Match = green
- Short = red
- Excess = amber/green

Fields:

- Notes
- Attachment
- Manager approval

Bottom button:

- Submit Closing

After approval, show locked badge.

---

## 20. Screen 15 — Reports

Report grid/cards:

- Currency Stock
- Daily Closing
- Rate History
- Buy/Sell Report
- Expense Report
- Party Ledger
- Agent Ledger
- Profit/Loss
- Audit Log

Each card should have icon, short description, and open button.

---

## 21. Screen 16 — Transaction Detail

Show full transaction details.

Sections:

- Transaction no
- Date/time
- Status
- Created by
- Party
- Currency movement
- Rate used
- Fee
- Accounts affected
- Notes
- Attachment/proof
- Ledger lines
- Audit history

Actions:

- Print receipt
- Share PDF
- Reverse transaction
- Duplicate as new

Do not show delete button for completed transaction.

---

## 22. Screen 17 — Settings

Settings screen:

- Company/branch
- Currencies
- Accounts
- Rate margins
- Permissions
- Numbering
- Theme
- Backup/sync status
- Device info

---

## 23. Components to Generate

Ask Stitch to create reusable components:

- Currency balance card
- Rate board card
- Summary KPI card
- Transaction list item
- Party ledger row
- Agent balance card
- Large amount input
- Currency selector chip
- Status badge
- Bottom action bar
- Receipt preview card
- Closing difference card
- Filter sheet
- Date range selector

---

## 24. UX Rules

- Keep cashier entry fast.
- Do not overload screens.
- Use big number input.
- Show live calculation.
- Always show rate locked.
- Always show source/destination account.
- Make currency selection very clear.
- Use confirmation screen before completing transaction.
- Use reversal instead of delete.
- Show sync status if offline/online support exists.
- Keep important buttons at bottom thumb area.

---

## 25. Stitch Master Prompt

Copy this prompt into Google Stitch:

```text
Design a premium modern mobile app UI for "FX Cash Ledger", a private internal multi-currency cash account manager.

This is not a public money exchange service, not crypto, not USDT, not Binance, and not a public remittance app. It is an internal ledger for physical cash currencies, rate board, cash accounts, expenses, settlements, agent ledger, and daily closing.

Create a clean fintech-style app for Android and iOS with light and dark mode. Use a professional palette: deep navy/royal blue primary, emerald green for completed/profit/cash-in, amber/gold for rate board and pending items, soft red for loss/reversal, neutral grey backgrounds, rounded cards, large readable numbers, and minimal clutter.

Create these screens:
1. Login
2. Dashboard with branch selector, date filter, today rate board, cash position by currency, today summary, profit/loss, pending settlements, and quick actions
3. Rate Board with buy/sell/reference rates and last updated time
4. New Rate Entry form
5. Currency Buy form
6. Currency Sell form
7. Cross Currency Conversion form
8. Internal Transfer form
9. Expense Entry form
10. Settlement Send form
11. Settlement Receive form
12. Party Ledger
13. Agent Ledger
14. Daily Closing
15. Reports
16. Transaction Detail
17. Settings

The dashboard should be modern and clean, not busy. Show PKR, USD, AED, RMB/CNY, and SAR balances. The rate board should show buy rate, sell rate, reference rate, and update time. Transaction forms should have large amount inputs, currency chips, source/destination account selectors, live calculation summary, rate locked badge, notes, attachment/proof option, and bottom sticky action buttons.

Use bottom navigation with Dashboard, Rates, Transactions, Ledger, and More. Add a central floating quick action button for Buy, Sell, Transfer, Expense, and Settlement.

Generate reusable components: currency balance card, rate card, KPI card, transaction list item, status badge, ledger row, large amount input, currency selector chip, closing difference card, filter sheet, and receipt preview card.

Design should feel like a private banking/accounting dashboard: trustworthy, premium, fast, simple, and easy for non-technical users.
```

---

## 26. Stitch Follow-up Prompt for Refinement

After the first design, use this refinement prompt:

```text
Refine the UI to make it less busy and more premium. Increase spacing, make currency numbers larger, reduce unnecessary text, and make the dashboard easier for a cashier/manager to understand quickly. Keep a clean fintech look with strong cards, clear rate board, and quick transaction actions. Make the forms faster to use with large numeric inputs and sticky bottom buttons.
```

---

## 27. Stitch Follow-up Prompt for Dark Mode

```text
Create a dark mode version of the same FX Cash Ledger app. Use charcoal background, soft dark cards, navy/blue highlights, amber/gold rate accents, emerald green for profit/completed, and soft red for loss/reversal. Keep all text highly readable.
```

---

## 28. Final Design Reminder

The UI should never look like a public exchange counter or ad.  
It should look like a private internal ledger/accounting app with multi-currency support.

