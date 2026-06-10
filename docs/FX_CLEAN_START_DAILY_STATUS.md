# FX Clean Start — Daily Status Report

**Project:** `ygidlcqhupmxvsdjmvnf` | **Updated:** _fill on each session_

## Today

| Area | Status | Notes |
|------|--------|-------|
| Attachments per leg | Deployed | migration 202606190001 |
| Guided workflow UI | Done | DealWorkflowPanel |
| AFN currency | Deployed | migration 202606190002 |
| Rate source labels | Done | Manual Reference Rate |
| Dry-run counts | Done | see FX_CLEANUP_DRY_RUN_REPORT.md |
| Data reset | **Pending approval** | reset_dev_fx_data.sql not run |

## Blockers

- _none_

## Next session

1. User approves `reset_dev_fx_data.sql` if clean start needed
2. Manual storage bucket cleanup after reset
3. Real deal test: order → agent source → payment proof → delivery

## Safety checklist

- [ ] Old ERP VPS not touched
- [ ] Admin `ndm313@yahoo.com` preserved after any reset
- [ ] COA + default currencies intact
