# Accounts-Manager — office handoff

**Date:** 2026-10-22 (closing)  
**Repo:** NDM0313/Accounts-Manager  
**Branch:** `feat/home-shared-db-reconciliation`  
**Do not merge to main as part of this handoff.**

## Identities (closing snapshot)

| Item | Value |
|------|--------|
| Code tip (local/remote after this handoff commit) | see git after push |
| Prior code tip at start of closing | `2d01e6b` |
| Deployed production web | `d0c726c` (`flutter_bootstrap.js?v=d0c726c`) |
| URL | https://fx.ndmcore.com |
| API | https://api.ndmcore.com |

Deployed web (`d0c726c`) is **behind** tip `2d01e6b` by the OCR script-only commit (`ensure_ocr_assets.sh`). Lang packs were copied onto the host separately; a full web redeploy of tip is optional and **not** part of this closing task.

## Status (payment workflow + verification)

On this branch (among earlier shared-DB / UI work):

- Shared **Receive Money / Pay Money** composer; settlement entry points unified
- Optional **deal allocation** via `fx_record_deal_customer_payment` (no second generic settlement when allocated)
- Action picker Primary / More; Buy Currency labelled Pay now / Pay later + custody notes
- Migration **W** — `fx_users_profiles` fix for party directory / custody / currency balance RPCs
- Party directory balances reconcile to control ledgers under authenticated AM_DEMO context

## OCR language assets

- **Manually deployed** to `/home/ndm313/fx_app_web/ocr/lang/`:
  - `eng.traineddata` (~23 MB)
  - `eng.traineddata.gz` (~10.9 MB)
- Public HEAD checks returned **HTTP 200** for those paths after deploy.
- **Actual OCR extraction remains unverified** after the lang-pack fix (prior run: 404 then 90s timeout). Do not treat upload→composer alone as OCR PASS.

### `ensure_ocr_assets.sh`

- Path: `deploy/ensure_ocr_assets.sh`
- Populates `web/ocr/` (+ `web/ocr/lang/`) including gzipped `eng.traineddata.gz` (tesseract.js fetches `.gz`).
- **Deployment verification required:** after any web deploy, confirm:
  - `https://fx.ndmcore.com/ocr/tesseract.min.js`
  - `https://fx.ndmcore.com/ocr/lang/eng.traineddata.gz` (non-zero `Content-Length`)
- Large tessdata files under `web/ocr/lang/` are **not** committed to git; regenerate/copy via the script or host copy.

## Successful AM_DEMO E2E references (preserve)

| Ref / note | TX id (short) | Effect |
|------------|---------------|--------|
| `E2E-BANK-RCPT-20261022` | `9ea899ff…` | Sara receive PKR 2,500 → Dr **1210** / Cr **1190** |
| `E2E-AGENT-PAY-20261022` | `864fcc5b…` | Dubai Agent pay PKR 500 → Dr **2100** / Cr **1210** |
| `E2E-DEAL-ALLOC-20261022` | `db7afe0c…` | Ali deal DL-20261021-0005 partial PKR 7,500 → Dr **1210** / Cr **1160**; outstanding −7,500 once |
| `E2E-ATTACH-20261022` | `8760ec59…` | Sara receive PKR 100 + proof attachment; signed URL opened |

### Bank / cash reconciliation (AM_DEMO, as reported)

| Account | Start (session) | End (after listed posts) |
|---------|-----------------|---------------------------|
| **1210** SYNTH Bank PKR Meezan | 100 | **19,700** |
| **1110** Cash PKR | 1,323,900 | **1,323,900** (unchanged) |

Deal **DL-20261021-0005:** receivable **1,575,000 → 1,567,500**; paid **500,000 → 507,500**.

## Mistaken generic demo transaction (preserve — do not delete/reverse in closing)

| Field | Value |
|-------|--------|
| TX id | `33c28e39-ae32-491e-9046-32bb454cf9f3` |
| Ref | `E2E-DEAL-PARTIAL-20261022` |
| Amount | PKR **10,000** |
| Nature | Generic `settlement_receive` (deal outstanding **not** reduced) |
| Cause | Composer cleared `dealId` while deals list still loading (fixed in `d0c726c`) |

**Preserve** this row for audit trail. No hard deletion or void/reversal as part of this office closing task. Optional later: labelled void on AM_DEMO only if product owners request cleanup.

## Remaining work (home / next session)

1. **Clean upload → OCR extraction → composer** — confirm fields (amount/ref/date) after lang packs; then action → composer → review/post.
2. **Labelled AM_DEMO Buy Currency posting** — verify payment-now/later vs agent custody / vault effects **without double-counting** the same quantity.
3. Optional: redeploy tip web so cache-bust matches `2d01e6b`+ if OCR script changes must ship in the built tree (lang packs already on host).

## Rollbacks and SQL backups

| Kind | Location |
|------|----------|
| Web rollback (deal-alloc deploy) | `/home/ndm313/fx_app_web_rollback_20261022T202356Z` |
| Earlier web rollback example | `/home/ndm313/fx_app_web_rollback_20261022T191314Z` / `…T131007Z` |
| Persistent SQL backups | `/home/ndm313/sql_backups/` |
| Pre-W function defs (copied from `/tmp`) | `backup_fx_*_before_W_copied_20261022T1941Z.sql` in `sql_backups` |
| Broader reconcile dumps | `/home/ndm313/fx_reconcile_backups/` |

### Applied home SQL (do NOT re-run)

Through `T_…`; then **U** party balances/roznamcha, **V** agent custody/currency balances, **W** profile table refs. Prefer new additive letters only. Financial writes: **AM_DEMO only**.

## Home browser / auth

- Home PC browser may need a **fresh manual login** to https://fx.ndmcore.com; select **AM_DEMO** for write tests.
- **Never** save browser tokens, cookies, passwords, or Playwright storage state into Git.
- Do not commit `.env`, `client.env`, dumps, or `tmp/` evidence trees.

## Office PC setup (existing home Supabase)

1. Pull `feat/home-shared-db-reconciliation`
2. Flutter stable matching project
3. Existing client config → `https://api.ndmcore.com` only
4. `flutter pub get` → `flutter run -d chrome` or web build
5. Sign in; **AM_DEMO** for financial tests
6. If redeploying: build → `deploy/ensure_ocr_assets.sh` → bust cache → tar/rsync to `fx_app_web` with rollback copy first

## Secrets

No secrets in this doc or in git. `tmp/` and large `web/ocr/lang/*traineddata*` stay local/untracked unless an explicit asset-hosting decision is made later.
