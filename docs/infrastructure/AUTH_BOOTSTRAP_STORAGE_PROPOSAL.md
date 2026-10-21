# Auth, bootstrap, and Storage proposal (design only — not applied)

**Phase:** Local implementation / reconciliation prep  
**Remote Auth/config changes:** **0**

## 1. Shared `auth.users`

- Continue using production GoTrue → `auth.users` on `supabase-db`.
- Accounts-Manager entitlement = presence of **`fx_users_profiles`** (+ `fx_user_roles`), not mere Auth signup.
- ERP users without FX profile must see “profile not configured” / no FX rows (RLS deny).

## 2. No automatic FX access

- **Do not** add a global `auth.users` insert trigger that creates `fx_users_profiles` for every ERP signup.
- Optional future: explicit admin RPC `fx_admin_grant_access(user_id, company_id, branch_id, role)` with permission checks — not in this phase.

## 3. Company / branch membership

- All AM policies use `fx_same_company` / `fx_same_branch` / `fx_has_permission` with `search_path = public`.
- ERP `get_user_company_id()` remains for ERP tables only.

## 4. SECURITY DEFINER

- AM helpers/RPCs: `SECURITY DEFINER` only where necessary; always `SET search_path = public` (or tighter).
- `REVOKE EXECUTE … FROM PUBLIC`; grant to `authenticated` (or specific roles) only.
- Each DEFINER body must re-check `auth.uid()` membership before mutation.

## 5. Narrow FX admin bootstrap (procedure text only)

Preconditions: additive schema + RLS applied on **disposable clone** first; never run on prod in this phase.

1. Operator authenticates as an existing Auth user (or creates one via Studio without ERP side effects beyond Auth).
2. Insert allowlisted AM company/branch/role/COA **without** demo party business data (or with clearly tagged synthetic codes).
3. Insert `fx_users_profiles` for **that** user id only.
4. Insert `fx_user_roles` admin role for that user only.
5. Verify: second ERP user without profile cannot `SELECT` AM rows.

SQL sketch lives conceptually beside `supabase/scripts/bootstrap_first_admin.sql` but must be rewritten for home (no Cloud dashboard assumptions) before use.

## 6. Auth URL / callback (do not change shared Auth this phase)

Observed prod Auth (audit):

- `API_EXTERNAL_URL` / site URL oriented to LAN `http://192.168.86.235:8000`
- Allow-list includes dincouture portal hosts

**Effects of changing Auth URLs later:**

| Change | Risk to ERP |
|---|---|
| `API_EXTERNAL_URL` → `https://api.ndmcore.com` | Email links / redirects may break if ERP clients still expect LAN or dincouture hosts |
| Frontend `SITE_URL` vs API external URL | Must remain distinct: API = gateway; site = portal/app origin |
| Allow-list edits | Must **preserve** required ERP redirects (`erp.dincouture.pk`, portal hosts, etc.) while adding AM app origins |

**This phase:** document only; no GoTrue env changes.

## 7. Storage

- Dedicated private bucket `fx-attachments` (package D).
- Path: `{company_id}/{branch_id}/{transaction_id}/…`
- Do not reuse `sale-attachments` / `purchase-attachments`.
