# Shared-database object compatibility matrix

**Date:** 2026-10-21  
**Sources:** home audit + live read-only catalog (constraints/FKs/indexes/RLS)  
**Remote mutations:** 0  

Legend — **Owner:** `ERP` | `AM` (Accounts-Manager) | `SHARED-NAME` | `UNCERTAIN`

---

## A. Explicitly preserve (ERP)

| Object | Owner | Existing definition (summary) | AM expected | Action | ERP impact if mishandled | Verify |
|---|---|---|---|---|---|---|
| `public.fx_currency_purchases` | ERP | Purchase docs; FKs → `companies`,`branches`,`contacts`,`accounts`,`payments`,`purchases`,`journal_entries`,`import_fx_cases`; statuses open/partial/paid/void; 5 void rows | Not an AM ledger table | **PRESERVE** — no ALTER/DROP/TRUNCATE; no AM RLS rewrite | Breaks import-FX purchase flow | Preflight FK list + row counts |
| `public.fx_currency_purchase_settlements` | ERP | Settlements; FK → purchases + `payments` + `companies`; status active/inactive; 3 inactive rows | Not AM | **PRESERVE** | Breaks settlement lifecycle | Same |
| `public.import_fx_*` (all) | ERP | Import FX case domain | Out of scope | **PRESERVE** | Breaks ERP import FX | `to_regclass` inventory |
| ERP `get_user_company_id()` + purchase policies | ERP | Policies on purchase tables only | Do not replace with `fx_same_company` | **LEAVE** | ERP RLS regression | `pg_policies` |

---

## B. Foundation tables (name shared; empty; AM-shaped)

Live columns/constraints match AM `202606100001_fx_foundation.sql` closely. Enums match. Indexes present. RLS **enabled**, policies **absent** on these tables (deny-by-default for non-owners). Owner `postgres`. Row counts **0**.

| Object | Owner | Live vs AM expected | Dependencies | Proposed action | ERP impact | Verify |
|---|---|---|---|---|---|---|
| `fx_account_type` enum | SHARED-NAME | Labels match AM | Used by `fx_accounts` | **REUSE** — do not `CREATE TYPE` again | None if untouched | enum label agg |
| `fx_party_type` enum | SHARED-NAME | Match | `fx_parties` | **REUSE** | None | same |
| `fx_transaction_type` / `fx_transaction_status` | SHARED-NAME | Match AM; unused by ERP purchase tables | Needed by AM `fx_transactions` | **REUSE** | None | same |
| `fx_companies` | SHARED-NAME / AM-intended | Columns match AM; empty | Referenced by other foundation + future AM | **REUSE**; add AM RLS policies only | ERP purchases do **not** FK here | FK catalog |
| `fx_branches` | SHARED-NAME / AM-intended | Match; empty | AM | **REUSE** + AM RLS | None on ERP purchase FKs | same |
| `fx_users_profiles` | AM-intended | Match; empty; FK → `auth.users` | AM auth mapping | **REUSE**; bootstrap explicitly | No auto ERP entitlement | counts + RLS |
| `fx_roles` / `fx_user_roles` | AM-intended | Match; empty | AM RBAC | **REUSE** | None | same |
| `fx_currencies` / `fx_rates` | AM-intended | Match; empty | AM | **REUSE**; seed currencies carefully (no demo parties) | None | column diff |
| `fx_accounts` / `fx_parties` | AM-intended | Match; empty | AM COA/parties | **REUSE**; COA seed allowlisted | None | column diff |
| `fx_set_updated_at()` | AM-intended | Present | Triggers on foundation | **REUSE** | None | `pg_proc` |

**Empty ≠ automatically safe to DROP.** Prefer REUSE. Do not rename merely for prefix hygiene.

**Grants note:** Live grants give `anon`/`authenticated` broad privileges including `TRUNCATE` on foundation tables. Under RLS with no policies, row DML from clients is still denied; still **narrow grants** in package C for AM allowlist (not via `fx_%` wildcard). ERP purchase grants left alone.

---

## C. Missing AM objects (create additively)

| Object | Owner | Live | AM expected | Action | ERP impact | Verify |
|---|---|---|---|---|---|---|
| `fx_transactions` (+ lines, versions) | AM | Absent | Required | **CREATE** via `B_additive_schema.sql` | None if no name clash | `to_regclass` |
| `fx_journal_entries` / `fx_journal_lines` | AM | Absent | Required | **CREATE** | None | same |
| `fx_daily_closings` / `fx_closing_lines` | AM | Absent | Required | **CREATE** | None | same |
| `fx_attachments` / `fx_audit_logs` | AM | Absent | Required | **CREATE** | None | same |
| `fx_audit_action` enum | AM | Absent | Required | **CREATE** if missing | None | `pg_type` |
| Deals / remittance / messaging / opening-balance / RPCs | AM | Absent | Required for full app | **Follow-up allowlisted files** after clone test; exclude demo seeds | None if new names only | migration allowlist |
| Storage `fx-attachments` | AM | Absent | Required | **CREATE** bucket + policies (D) | Must not alter ERP buckets | `storage.buckets` |

---

## D. Auth / helpers

| Object | Owner | Notes | Action |
|---|---|---|---|
| `auth.users` | SHARED platform | 17 users (prod) | Reuse identities; **no** automatic FX profile |
| AM `fx_current_profile` / `fx_same_*` | AM | Not present live | Create in C; revoke PUBLIC execute |
| ERP `get_user_company_id` | ERP | Used by purchase RLS | **Do not replace** |

---

## E. Migration lineage

| Item | Finding | Action |
|---|---|---|
| Live `supabase_migrations` FX names | ERP `fx_currency_purchase_*` / `import_fx_*` (Aug 2026) | Leave |
| AM files `20260610*`–`20260626*` | Not applied as lineage | **Do not** mark applied without verified effects |
| `scripts/apply_migrations.sh` | Now blocks home unless legacy Cloud target | Keep blocked for home |

---

## F. Potential ERP impact summary

| Risky action | Impact |
|---|---|
| `DROP`/`TRUNCATE` purchase tables | **High** — destroys ERP FX purchase history |
| Blanket `REVOKE` on `fx_%` | **High** — could break purchase API grants |
| Replaying full AM foundation `CREATE TYPE/TABLE` | **Medium** — fails or drifts on existing objects |
| Additive AM tables + AM-only RLS | **Low** if allowlisted and purchase objects untouched |
