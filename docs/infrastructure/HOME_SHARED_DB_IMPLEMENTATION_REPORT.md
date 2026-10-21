# Home shared-DB implementation report

**Branch:** `feat/home-shared-db-reconciliation`  
**Updated:** 2026-10-21 (frontend config 403 repair)

| Gate | Value |
|---|---|
| Disposable PG17 / prod SQL (prior) | **PASS** (unchanged this pass — no migrations re-run) |
| Frontend blank-page / config 403 | **FIXED** |
| Origin login screen (browser) | **PASS** |
| Public `fx.ndmcore.com` | **CLOUDFLARE_ACCESS_BLOCKED** (no Cursor CF write access; DNS absent; tunnel not updated here) |

---

## Frontend 403 root cause

Mac `127.0.0.1:3099` is a **Cursor SSH forward** to dinserver `accounts-manager-web`.

Deployed `client.env` was mode `600` (owner-only). Nginx worker could not `open()` it → **HTTP 403 Permission denied** (not an `.env` location deny rule). Flutter asset load failed → blank page.

`assets/assets/...` path is normal Flutter web packaging (confirmed via AssetManifest / runtime).

## Fix

- Public config moved to `assets/config/client_config.json` (gitignored; example committed).
- Loader: `ClientConfig.loadIntoDotenv()`; startup failure screen without key leakage.
- Deploy nginx: `deploy/nginx-fx.conf` (SPA + deny root `.env`; public JSON `no-store`).
- Redeployed `accounts-manager-web` with `chmod 644` assets; removed legacy `client.env` from docroot.

Verified origin:

- `GET /` → 200  
- `GET /assets/assets/config/client_config.json` → **200**, `SUPABASE_URL=https://api.ndmcore.com`  
- `GET /.env` → 404  
- Unknown `/assets/...` → 404 (not index.html)  
- Browser: login UI “Welcome Back” / Sign In (desktop + mobile viewport)

## Cloudflare (not done in Cursor)

Verified live facts match handoff: no `fx.ndmcore.com` DNS; tunnel ingress not configured for FX in this session. Origin ready: **`http://127.0.0.1:3099`** on host-network cloudflared path. ChatGPT/CF connection can add DNS+ingress without touching `api.ndmcore.com` → `:8000`.

## Client

- Runtime: `https://api.ndmcore.com` + home anon/publishable key in `client_config.json` (gitignored).
