# FX Ledger — Remaining Tasks

**Project:** `ygidlcqhupmxvsdjmvnf` (Cloud only)  
**Last updated:** 2026-06-19

---

## Done (this push)

- Deal RPC v2 consolidation (`fx_book_customer_deal_v2`, `fx_add_deal_leg_v2`)
- Per-leg attachments migration + Flutter proof upload UI
- Guided deal workflow panel on deal detail
- AFN currency seed migration
- Honest rate source labels + rate repository column fix
- Currency management (decimals, deactivate)
- Double customer payment bug fix in deal booking
- Compile fix: restored `app_colors.dart` import on rate board widgets
- Audit / dry-run / reset scripts and docs under `docs/` and `supabase/scripts/`

---

## Remaining — needs approval or manual action

| # | Task | Owner | Notes |
|---|------|-------|-------|
| 1 | **Run dev data reset** | User approval | `supabase/scripts/reset_dev_fx_data.sql` — destructive; not executed |
| 2 | **Storage bucket cleanup** | Manual | After reset, follow `docs/STORAGE_CLEANUP_AFTER_RESET.md` |
| 3 | **End-to-end deal test** | QA / user | Order → agent source leg → payment proof → delivery |
| 4 | **Hot restart verify** | User | Workflow panel, proof attachments, AFN in settings, rate source labels |

---

## Remaining — product / follow-up (optional)

| # | Task | Notes |
|---|------|-------|
| 5 | Live rate source integration | See `docs/RATE_SOURCE_INTEGRATION_PLAN.md` |
| 6 | Seed demo deals post-reset | `supabase/scripts/seed_deal_demo.sql` after clean start |
| 7 | Party statement demo data | `supabase/scripts/seed_statement_demo.sql` if needed |

---

## Safety (always)

- Do **not** touch old ERP VPS / `supabase.dincouture.pk`
- Preserve admin user `ndm313@yahoo.com`, COA, and default currencies on any reset
- Never commit `.env` or Supabase service keys

---

## Quick commands

```bash
# Verify RPC overloads (read-only)
npx supabase db query --linked --file supabase/scripts/audit_rpc_overloads.sql

# Dry-run row counts (read-only)
npx supabase db query --linked --file supabase/scripts/dry_run_dev_data_counts.sql

# Reset (ONLY after explicit approval)
npx supabase db query --linked --file supabase/scripts/reset_dev_fx_data.sql

# Flutter
flutter test
flutter run -d chrome
```

---

## Approve reset

Reply **"approve reset"** to run the destructive clean-start script on Cloud, then complete storage cleanup per doc.
