# Accounts-Manager — office handoff

**Date:** 2026-10-22  
**Repo:** NDM0313/Accounts-Manager  
**Branch:** `feat/home-shared-db-reconciliation`  
**Do not merge to main as part of this handoff.**

## Status

Implementation on this branch covers (among earlier shared-DB work):

- Party / cash-bank profiles, optional auto codes, inline openings via `fx_post_entity_opening`
- Accounts Hub Home/back + app-wide bottom nav chrome (`FxAuthenticatedChrome`)
- Cancel/Back deep-link traps fixed via `fxSafePop` fallbacks
- Party statement Simple/Detailed professional PDF + export sheet
- Slip OCR / deal payment / currency receipt / profile access restores (earlier commits)

## Deployed (production web)

| Item | Value |
|------|--------|
| URL | https://fx.ndmcore.com |
| API | https://api.ndmcore.com (existing home Supabase) |
| Deployed commit (last handoff) | `a83abca` |
| Cache-bust | `flutter_bootstrap.js?v=a83abca` |
| Host path | `/home/ndm313/fx_app_web` on dinserver |
| Rollback example | `/home/ndm313/fx_app_web_rollback_20261022T131007Z` |
| SQL after T | `U_party_balances_roznamcha` · `V_agent_custody_party_currencies` (do not re-run) |

ERP (`din-couture-portal` / erp.ndmcore.com) was not redeployed; leave it alone.

## Applied home SQL (do NOT re-run on production)

Scripts under `supabase/reconciliation/home/` already applied on shared postgres (order matters; only add **new** letters):

- Through foundation / demo: `B` … `M` (existing prior work)
- `N_deal_payment_coa_workflow.sql`
- `O_party_accounts_attachments_ocr.sql`
- `P_slip_ocr_gaps_fix.sql`
- `Q_currency_receipt_currency_guard.sql`
- `R_profile_self_select.sql`
- `S_party_profile_openings.sql` (party profile columns, allocate/upsert, openings; rate-required fix live)
- `T_transaction_void_deal_unwind.sql` (office 2026-10-22) — `fx_preview_void_transaction`, deal payment unwind on void; backup `T_pre_*_fx_delete_transaction.sql`

**Warning:** Re-applying these on the live shared DB can fail or double-apply privileges. Prefer new additive scripts (`U_…`) for any further schema work. Backups were taken under `/home/ndm313/sql_backups` / `fx_sql_backups` on the home server when changes were applied.

Financial test writes: **AM_DEMO only**. Do not invent balances on real NDMFX parties.

## Pending / NOT RUN

- GitHub push may have been blocked earlier by SSH agent; this handoff uses HTTPS/`gh` credential helper when available
- Live authenticated browser click-through of statement export (PDF sheet) — unit/PDF fixture PASS; UI click NOT fully automated
- Party statement: optional attachment appendix pages; 50+ row multi-page stress; Urdu RTL
- Agent custody inventory opening (currency_position) — ordinary openings done; custody double-count avoided by design limitation note
- Photo upload path on party profile still thin
- Physical iPhone verification of nav/chrome

## Office PC setup (existing home Supabase)

1. Clone/pull this branch: `feat/home-shared-db-reconciliation`
2. Flutter stable matching project (recent builds used Flutter 3.41.x / Dart 3.11.x)
3. Use **existing** client config pointing at `https://api.ndmcore.com` — do not invent a new Supabase project
4. `flutter pub get` then `flutter run -d chrome` or build web as usual
5. Sign in with your real FX user; switch to **AM_DEMO** for any financial write tests
6. Deploy path (if needed): `flutter build web --release --no-tree-shake-icons` → `deploy/bust_web_cache.sh` → rsync to `dinserver-local:/home/ndm313/fx_app_web` with rollback copy first
7. SSH host alias on home Mac: `dinserver-local` (not available on office PC unless configured)

## Secrets

No secrets belong in this doc or in git. Do not commit `.env`, `client.env`, dumps, or customer files. `tmp/` is local evidence only and should stay untracked.
