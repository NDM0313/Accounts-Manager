# FX Ledger — Remaining Tasks

**Project:** `ygidlcqhupmxvsdjmvnf` (Supabase Cloud only)  
**Branch:** `ui/remittance-premium-polish`  
**Last updated:** 2026-06-13

---

## Done today (2026-06-13)

### Backend & database

| Item | Status | Notes |
|------|--------|-------|
| Messaging RLS infinite recursion fix (`42P17`) | Done | `202606260001_fx_messaging_rls_recursion_fix.sql` deployed |
| Remittance posting type fix (duplicate timestamp) | Done | Renamed → `202606240002_fx_remittance_posting_type_fix.sql`, applied with `--include-all` |
| Secure share links migration | Done | `202606240001_fx_secure_share_links.sql` on cloud |
| Cloud migration ceiling | Done | Through `202606260001` |
| `apply_migrations.sh` | Done | Now uses `--include-all` for out-of-order migrations |
| RLS / RPC smoke | Done | `fx_get_or_create_entity_conversation`, `fx_list_conversations` — no 42P17 |
| `flutter analyze` + `flutter test` | Done | Clean, 155 passed |

### Stitch Premium UI (exact replica sprints)

| Sprint | Screens | Status |
|--------|---------|--------|
| 7 Sub-Pages | transaction menu, opening balance, rate board, receive payment, reports hub, settings security | **Pass** |
| 4 Sub-Pages | share export, secure link config, transaction audit chat, transaction confirmation | **Pass** |
| Prior pages | login, dashboard, GL, remittance, team chat, deal detail, agent source, attachment preview, customer/agent ledger | **Pass** |

New shared widgets under `lib/core/widgets/premium/stitch/` (export, secure share, audit, deal, chat, reports, etc.).

Docs updated: `doc/STITCH_SCREEN_BY_SCREEN_DIFF.md`, `doc/FX_MESSAGING_MODULE.md`, `doc/TESTING_AND_STATUS.md`.

---

## Remaining — manual QA (user)

Full **hot restart** (`stop flutter run` → `flutter run -d chrome`) then verify:

| # | Flow | Expected |
|---|------|----------|
| 1 | Agent Sourcing → Save Leg / Confirm Received | No Postgres snackbar |
| 2 | Transaction Detail → **Team chat** | Opens conversation room |
| 3 | `/transactions/:id/audit` | Unified audit thread + send comment |
| 4 | `/messages` | Inbox loads |
| 5 | Share Configuration → Generate link | Dashed preview + copy |
| 6 | Export sheet (deal/txn) | PDF / Print / Image / Email + Copy Link |
| 7 | Side-by-side 390px PNG vs Stitch `screen.png` | Visual spot-check (see `doc/STITCH_SCREEN_BY_SCREEN_DIFF.md`) |

---

## Remaining — product / UI

| # | Task | Priority | Notes |
|---|------|----------|-------|
| 1 | **`new_customer_fx_deal` pixel polish** | Medium | Only Stitch screen still **Partial** — rate boxes vs PNG |
| 2 | Email verification toggle (secure share) | Low | UI-only; no API/DB field yet |
| 3 | Export sheet lifecycle timeline from callers | Low | Optional `lifecycleSteps` / `shareUrl` props not wired everywhere |
| 4 | Transaction audit voice bubble vs mock | Low | Inline play/progress in sent bubble |
| 5 | Confirm dialog animated ping | Low | Mock `animate-ping`; static ring implemented |
| 6 | Messaging Realtime in Flutter | Low | DB publication enabled; no client subscription yet |
| 7 | `FeatureFlags.rateSnapshotColumnsEnabled` | Low | Set `true` after confirming migration `202606180002` on all envs |

---

## Remaining — backend / ops

| # | Task | Owner | Notes |
|---|------|-------|-------|
| 1 | **Dev data reset** | User approval | `supabase/scripts/reset_dev_fx_data.sql` — destructive |
| 2 | Storage bucket cleanup | Manual | After reset: `docs/STORAGE_CLEANUP_AFTER_RESET.md` |
| 3 | End-to-end deal workflow QA | User | Book deal → agent leg → receipt → delivery |
| 4 | Remittance H4–H7 flows | QA | Payout, agent portal, notifications |
| 5 | Live rate source integration | Future | `docs/RATE_SOURCE_INTEGRATION_PLAN.md` |

---

## Remaining — verify SQL (optional re-run)

```bash
# After any migration change
./scripts/apply_migrations.sh

# Read-only checks (Supabase SQL Editor or scripts/run_cloud_sql.py)
supabase/scripts/verify_messaging_module.sql
supabase/scripts/verify_posting_engine.sql
supabase/scripts/verify_handoff_rpcs.sql
supabase/scripts/verify_posting_smoke.sql
supabase/scripts/verify_remittance_module.sql
```

---

## Safety (always)

- Do **not** use old ERP VPS / `supabase.dincouture.pk`
- Never commit `.env` or service_role keys
- Preserve admin `ndm313@yahoo.com`, COA, default currencies on reset

---

## Quick commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port=7358
./scripts/apply_migrations.sh
```

---

## Approve destructive reset

Reply **"approve reset"** to run `reset_dev_fx_data.sql` on Cloud, then storage cleanup per doc.
