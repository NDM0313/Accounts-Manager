# Cursor Agent Prompt — FX Cash Ledger V2

```text
You are building "FX Cash Ledger V2", a private internal multi-currency account manager app with proper double-entry accounting.

Important:
- This is not a public money exchange service.
- This is not crypto, USDT, Binance, or mobile wallet.
- This is a private internal ledger for physical currencies, cash accounts, settlements, expenses, and accounting.
- The user already has self-hosted Supabase on VPS.
- Self-hosted Supabase should be treated as a single-project environment.
- Do not assume Supabase Studio can create multiple cloud-style projects on the VPS.
- Prefer existing Supabase with separate fx_* tables and RLS.
- Do not mix FX records into existing ERP sales/purchase/rental tables.
- Do not reset production database.
- Do not delete Docker volumes.
- Do not change production secrets without approval.
- Take backup before applying production migrations.

Critical accounting requirement:
This must be a real double-entry accounting system.

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

Recommended stack:
- Flutter Android/iOS
- Riverpod
- GoRouter
- Supabase Flutter client
- Existing self-hosted Supabase backend
- PostgreSQL migrations
- Drift/SQLite for offline drafts/cache
- Server RPC for final posting

First work order:
1. Inspect existing ERP/Supabase schema.
2. Identify reusable company, branch, user, role, contact, account, and numbering tables.
3. Propose safe fx_* tables.
4. Prepare non-destructive migrations.
5. Add COA seed for FX accounting.
6. Add posting RPC design.
7. Add RLS policies.
8. Build Flutter shell.
9. Add dashboard, transactions, accounting, reports, settings.
10. Add tests for balanced journals, trial balance, P&L, balance sheet, reversals, and RLS.
```
