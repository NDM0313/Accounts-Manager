# Admin Bootstrap — First User Setup

Map a Supabase Auth user to the FX Ledger so RLS allows read/write (via RPC in later phases).

**Project:** `ygidlcqhupmxvsdjmvnf` only — never use old ERP / `supabase.dincouture.pk`.

Flutter **cannot** create profiles or roles (RLS blocks insecure client inserts). Setup is **one-time, server-side** via Supabase Dashboard.

---

## Prerequisites

- Phase 1 migrations applied (seed company **FXDEV**, branch **MAIN**, **admin** role exist).
- User has signed up or signed in once in the Flutter app (creates `auth.users` row).

---

## Step 1 — Find `auth.users.id`

**Option A — Supabase Dashboard**

1. Open [Authentication → Users](https://supabase.com/dashboard/project/ygidlcqhupmxvsdjmvnf/auth/users)
2. Click the user row
3. Copy **User UID** (UUID format)

**Option B — Flutter app**

1. Sign in
2. On **Profile not configured** screen, copy **Your User ID** (shown after sign-in)

---

## Step 2 — Run bootstrap SQL

1. Open [SQL Editor](https://supabase.com/dashboard/project/ygidlcqhupmxvsdjmvnf/sql/new)
2. Open [`supabase/scripts/bootstrap_first_admin.sql`](../supabase/scripts/bootstrap_first_admin.sql)
3. Replace `YOUR_AUTH_USER_UUID_HERE` with your UUID
4. Run the script

This inserts:

| Table | Values |
|-------|--------|
| `fx_users_profiles` | `company_id` = FXDEV, `branch_id` = MAIN |
| `fx_user_roles` | `role_id` = **admin** (all ledger permissions) |

Seeded IDs (from migration `202606100005`):

| Entity | UUID |
|--------|------|
| Company FXDEV | `00000000-0000-4000-8000-000000000001` |
| Branch MAIN | `00000000-0000-4000-8000-000000000002` |
| Role admin | `00000000-0000-4000-8000-000000000010` |

---

## Step 3 — Verify in app

1. Sign out and sign in again (or pull-to-refresh profile — restart app)
2. You should reach the **Dashboard** (not “Profile not configured”)
3. Confirm read-only data:
   - **Home** — currency cards (PKR, USD, AED, CNY, SAR)
   - **COA** — 37 accounts
   - **Rates** — empty until rates added (RLS OK if empty)
   - **Settings** — profile linked, project ref `ygidlcqhupmxvsdjmvnf`

---

## Step 4 — Verify RLS (optional SQL)

Run in SQL Editor (replace UUID):

```sql
SELECT id, email FROM fx_users_profiles WHERE id = 'YOUR_AUTH_USER_UUID_HERE';
SELECT r.name, r.permissions FROM fx_user_roles ur
JOIN fx_roles r ON r.id = ur.role_id WHERE ur.user_id = 'YOUR_AUTH_USER_UUID_HERE';
```

Flutter still uses **publishable key only** — no service_role, no RLS bypass.

---

## Manual Table Editor alternative

Instead of SQL, insert rows manually:

**`fx_users_profiles`**

| Column | Value |
|--------|-------|
| `id` | auth User UID |
| `company_id` | `00000000-0000-4000-8000-000000000001` |
| `branch_id` | `00000000-0000-4000-8000-000000000002` |
| `email` | user email |
| `is_active` | `true` |

**`fx_user_roles`**

| Column | Value |
|--------|-------|
| `user_id` | auth User UID |
| `role_id` | `00000000-0000-4000-8000-000000000010` |

---

## Troubleshooting

| Symptom | Cause |
|---------|--------|
| Still “Profile not configured” | Profile row missing or wrong UUID |
| COA empty / error | Missing `fx_user_roles` or wrong company |
| Rates empty | Normal until rates inserted for MAIN branch |
| Cannot insert from Flutter | Expected — use Dashboard SQL only |

---

## Security notes

- Do not add service_role key to Flutter or commit it.
- Do not disable RLS on `fx_*` tables.
- Additional users: repeat profile + role mapping per user (cashier/manager/auditor roles in seed data).
