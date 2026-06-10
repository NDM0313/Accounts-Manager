# FX Clean Start — Final Report

**Project:** `ygidlcqhupmxvsdjmvnf` only | **Date:** 2026-06-19

## Completed

### Phase 0 — Audit & scripts
- `docs/FX_WORKFLOW_AUDIT.md`, `docs/FX_ATTACHMENT_ANALYSIS.md`, `docs/FX_DEAL_WORKFLOW_GUIDE_SPEC.md`
- `docs/RATE_SOURCE_INTEGRATION_PLAN.md`, `docs/FX_CURRENCY_AFN_PLAN.md`, `docs/FX_CLEAN_START_DAILY_STATUS.md`
- `supabase/scripts/dry_run_dev_data_counts.sql`, `supabase/scripts/reset_dev_fx_data.sql` (draft)
- `docs/FX_CLEANUP_DRY_RUN_REPORT.md`, `docs/STORAGE_CLEANUP_AFTER_RESET.md`

### Phase 1 — Migrations (deployed to Cloud)
- `202606190001_fx_deal_leg_attachments.sql` — `deal_id` / `deal_leg_id` on `fx_attachments`, RLS, timeline `attachment_count`
- `202606190002_fx_seed_afn_currency.sql` — AFN currency + cash COA

### Phase 2 — Flutter
- **Attachments:** `FxProofAttachmentsSection`, extended `AttachmentRepository`, proof picker on leg screens, timeline badges on deal detail
- **Guided workflow:** `DealWorkflowGuide` + `DealWorkflowPanel` on deal detail (next action, checklist, warnings)

### Phase 3 — Currencies & rates
- Settings → Currencies: decimal places, deactivate toggle
- Rate board/form: honest source labels (`Manual Reference Rate`, etc.), `rate_source` read fix

### Tests
- **88 tests passing**

## Not executed (requires your approval)

- **`reset_dev_fx_data.sql`** — destructive demo data wipe not run
- **Storage object deletion** — manual step documented

## Verify after hot restart

1. Deal detail → **WORKFLOW** panel shows next action
2. Agent source leg → attach proof before/after save
3. Timeline → paperclip count + View/Add proof
4. Settings → Currencies → AFN listed
5. Rate board → source shows "Manual Reference Rate" (or saved source)

## To start fresh real entries

Reply to approve reset, then we run:

```bash
npx supabase db query --linked --file supabase/scripts/reset_dev_fx_data.sql
```

Then clear storage per `docs/STORAGE_CLEANUP_AFTER_RESET.md`.

## Safety confirmed

- Old ERP VPS: **not touched**
- Admin / COA / default currencies: **preserved**
