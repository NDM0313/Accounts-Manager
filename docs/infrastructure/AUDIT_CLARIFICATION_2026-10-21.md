# Audit clarification (dated 2026-10-21, evening)

This note **corrects interpretation** of `HOME_MINIPC_EXISTING_DB_AUDIT.md` without silently rewriting historical findings. Original audit remains the evidence log; where this note conflicts on *meaning*, prefer this clarification.

## 1. RLS enabled + no policies ≠ “grants prove public exposure”

**Clarification:** With `ENABLE ROW LEVEL SECURITY` and **no** applicable policy for a role, ordinary non-owner clients (e.g. `authenticated` / `anon` via PostgREST) receive **no rows** (fail closed for row access).

Broad `GRANT` including `SELECT` does **not** by itself mean data is publicly readable under RLS.

Still separately risk-assess:

- Table **ownership** and `FORCE ROW LEVEL SECURITY`
- Roles that **bypass** RLS (e.g. `service_role` in Supabase)
- Privileges such as `TRUNCATE` / `REFERENCES` / ownership escalation
- `SECURITY DEFINER` functions and their `EXECUTE` grants / `search_path`

**Implication for home DB:** Empty-looking foundation `fx_*` tables with RLS on and no policies are **not** automatically “world readable.” They still need AM policies before the app can work, and grants should be least-privilege.

## 2. `fx_` prefix is not ownership

Do **not** apply blanket `GRANT` / `REVOKE` / `ALTER` / `DROP` to `fx_%`.

Verified ERP-owned (preserve):

- `public.fx_currency_purchases`
- `public.fx_currency_purchase_settlements`
- all `public.import_fx_*`

These purchase tables FK to ERP `companies` / `contacts` / `payments` / `accounts` / `import_fx_cases` — **not** to AM `fx_companies`.

## 3. Cloud endpoint unreachable ≠ proven deleted

`ygidlcqhupmxvsdjmvnf.supabase.co` failed from the audited Mac/network. That proves **unavailable from the tested environment**, not cryptographic proof of project deletion. Treat as unavailable for operations until independently confirmed.

## 4. ERP staging is not a PG17 restore target

`erp-core-db` / `erp_core` is PostgreSQL **16** and is **not** a proven compatible restore/validation target for production `supabase-db` (PostgreSQL **17.6**).

## 5. Accounting correctness gate

Passing Flutter unit/widget tests does **not** authorize real-money use. Database scenario tests for balances, partial payments, commission, refunds, and delivery allocation remain a hard gate (see accounting backlog).

## 6. Term “TTP”

Remains **undefined / unresolved**. Do not invent meaning.
