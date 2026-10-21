# FX Cash Ledger (`accounts_manager`)

[![Flutter CI](https://github.com/NDM0313/Accounts-Manager/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/NDM0313/Accounts-Manager/actions/workflows/flutter_ci.yml)

Private internal multi-currency accounting ledger — Flutter + Supabase.

**Repository:** [github.com/NDM0313/Accounts-Manager](https://github.com/NDM0313/Accounts-Manager)

**Intended home API:** `https://api.ndmcore.com` (Studio `db.ndmcore.com` is rejected by the app).  
Shared-DB reconciliation SQL is prepared under `supabase/reconciliation/home/` and is **not** auto-applied.

## Quick start

```bash
git clone https://github.com/NDM0313/Accounts-Manager.git
cd Accounts-Manager
cp assets/config/client_config.json.example assets/config/client_config.json   # public keys only
# Optional: copy supabase/.env.migrations.example for CLI tooling (never in Flutter assets)
flutter pub get && flutter run -d chrome
```

## Supabase targets

| Setting | Value |
|---------|-------|
| Home API (allowlisted) | `https://api.ndmcore.com` |
| Studio (not for Flutter) | `https://db.ndmcore.com` |
| Legacy Cloud host (explicit only) | `https://ygidlcqhupmxvsdjmvnf.supabase.co` |

**Do not use** `supabase.dincouture.pk`, Studio URLs as API, or unknown hosts.  
Flutter loads `assets/config/client_config.json` (URL + publishable/anon key only).

## Setup

1. Create `assets/config/client_config.json` from the example (public client keys only).
2. Required Flutter variables: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`.
3. DB passwords / service_role belong in `supabase/.env.migrations` — never in Flutter assets.
4. Run `flutter pub get` then `flutter run`.

## Migrations

- **Home shared DB:** do **not** run `./scripts/apply_migrations.sh`. Use reviewed packages in `supabase/reconciliation/home/` after disposable PG17 validation.
- **Legacy Cloud only:** `FX_MIGRATION_TARGET=legacy_cloud ./scripts/apply_migrations.sh` (still fails closed on host/ref mismatch).

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
