# F) Recovery / rollback (instructions only — not executed)

## Before any apply

1. Confirm daily Bunny backup success for the same day.
2. Take an on-demand `pg_dump -Fc` of `supabase-db` / `postgres` to a dated file outside the DB.
3. Record `SELECT count(*)` for `fx_currency_purchases` and `fx_currency_purchase_settlements`.
4. Apply only on a disposable PG17 clone first.

## If additive AM objects misbehave

Preferred rollback for **new empty AM tables** (no business AM rows yet):

```sql
-- ONLY after confirming tables are empty and not referenced by ERP:
-- DROP TABLE IF EXISTS fx_audit_logs CASCADE;
-- DROP TABLE IF EXISTS fx_attachments CASCADE;
-- ... allowlisted new tables only — NEVER drop fx_currency_purchases*
```

Do **not** drop foundation tables (`fx_companies`, …) even if empty without dependency review — ERP purchase tables do **not** FK to them today, but AM objects and future code will.

## If RLS/grants break ERP clients

- ERP purchase policies use `get_user_company_id()` on ERP `companies` — they should remain untouched by package C.
- If accidental change: restore policy definitions from the pre-apply dump for those two tables only.

## Full database restore

Restore the dated `supabase.dump` / Bunny archive onto a **temporary** PG17 instance, verify ERP + FX, then plan cutover. Do not restore PG17 dumps onto ERP staging PG16.

## Restore testing status

**UNVERIFIED** in the 2026-10-21 audit and still **NOT RUN** in this phase.
