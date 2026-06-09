# FX Cash Ledger (`accounts_manager`)

[![Flutter CI](https://github.com/NDM0313/Accounts-Manager/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/NDM0313/Accounts-Manager/actions/workflows/flutter_ci.yml)

Private internal multi-currency accounting ledger — Flutter + **Supabase Cloud**.

**Repository:** [github.com/NDM0313/Accounts-Manager](https://github.com/NDM0313/Accounts-Manager)

## Quick start

```bash
git clone https://github.com/NDM0313/Accounts-Manager.git
cd Accounts-Manager
cp .env.example .env   # fill in Supabase keys
flutter pub get && flutter run -d chrome
```

## Supabase Cloud (required)

This project uses **only** the new Supabase Cloud project:

| Setting | Value |
|---------|-------|
| Project ref | `ygidlcqhupmxvsdjmvnf` |
| API URL | `https://ygidlcqhupmxvsdjmvnf.supabase.co` |
| Dashboard | `https://supabase.com/dashboard/project/ygidlcqhupmxvsdjmvnf` |
| Session pooler (migrations, IPv4) | `aws-1-ap-southeast-1.pooler.supabase.com:5432` |

**Do not use** `supabase.dincouture.pk` or any old ERP VPS Supabase for this app.

## Setup

1. Copy [`.env.example`](.env.example) to `.env` and fill in secrets (never commit `.env`).
2. Required variables: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_DB_PASSWORD`, `SUPABASE_DB_POOLER_HOST`.
3. Run `flutter pub get` then `flutter run`.

## Migrations

Apply `fx_*` migrations to the cloud project only:

```bash
./scripts/apply_migrations.sh
```

The script aborts if project ref or URL does not match `ygidlcqhupmxvsdjmvnf`, or if the old VPS domain is detected.

## Admin bootstrap (first user)

After signing up in the app, map your auth user to the ledger (RLS requires `fx_users_profiles` + `fx_user_roles`):

1. See **[doc/admin_bootstrap.md](doc/admin_bootstrap.md)** for full steps.
2. Run **[supabase/scripts/bootstrap_first_admin.sql](supabase/scripts/bootstrap_first_admin.sql)** in Supabase SQL Editor (replace `YOUR_AUTH_USER_UUID_HERE`).
3. Assigns **FXDEV** company, **MAIN** branch, **admin** role.

The Flutter app shows your User ID on the “Profile not configured” screen. Flutter never bypasses RLS.

## Verification

After migrations are applied and admin is bootstrapped:

1. See **[doc/TESTING_AND_STATUS.md](doc/TESTING_AND_STATUS.md)** for the full QA checklist, feature matrix, and Stitch UX gap tracker.
2. Run [supabase/scripts/verify_posting_engine.sql](supabase/scripts/verify_posting_engine.sql) in SQL Editor.
3. In the app: create a draft (e.g. Opening Balance or Currency Buy) → **Post to ledger**.
4. Run [supabase/scripts/verify_posting_smoke.sql](supabase/scripts/verify_posting_smoke.sql) — trial balance should show `is_balanced = true`.
5. Run [supabase/scripts/verify_handoff_rpcs.sql](supabase/scripts/verify_handoff_rpcs.sql) — handoff RPCs and `fx-attachments` bucket (after migration `202606140001`).
6. Check **Reports → Trial Balance** and **Transactions** in the app.


Project-level [`.cursor/mcp.json`](.cursor/mcp.json) points Supabase MCP to **Supabase Cloud** (`mcp.supabase.com`) scoped to this project. Restart Cursor after opening this workspace if MCP still shows the old VPS URL from global config.
