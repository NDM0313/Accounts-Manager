# FX Cleanup Dry-Run Report

**Project:** `ygidlcqhupmxvsdjmvnf` | **Generated:** 2026-06-19  
**Script:** `supabase/scripts/dry_run_dev_data_counts.sql` (read-only)

## Summary

Dry-run executed against Cloud. Use counts below before approving `reset_dev_fx_data.sql`.

## Currencies (current)

| Code | Name | Base | Active |
|------|------|------|--------|
| PKR | Pakistani Rupee | Yes | Yes |
| USD | US Dollar | No | Yes |
| AED | UAE Dirham | No | Yes |
| CNY | Chinese Yuan (RMB) | No | Yes |
| SAR | Saudi Riyal | No | Yes |
| AFN | Afghan Afghani | No | Yes | *(after migration 202606190002)* |

## Tables to reset (transactional — run dry-run for live counts)

- `fx_deals`, `fx_deal_legs`, `fx_currency_commitments`, `fx_settlement_links`
- `fx_transactions`, `fx_transaction_lines`, `fx_transaction_versions`
- `fx_journal_entries`, `fx_journal_lines`
- `fx_daily_closings`, `fx_closing_lines`
- `fx_attachments` (metadata)
- `fx_parties` (FXDEV demo parties e.g. WALI TT)
- `fx_audit_logs` (optional — commented in reset script)

## Preserved (never deleted by reset script)

- `auth.users` / admin `ndm313@yahoo.com`
- `fx_users_profiles`, `fx_roles`, `fx_user_roles`
- `fx_companies` (FXDEV), `fx_branches` (MAIN)
- `fx_currencies`, `fx_accounts` (COA)
- Storage bucket definition; migration history

## Next step

**Reset NOT executed** — awaiting explicit approval. When approved:

1. Run `supabase/scripts/reset_dev_fx_data.sql` via SQL Editor or `supabase db query`
2. Follow `docs/STORAGE_CLEANUP_AFTER_RESET.md` for bucket objects
3. Re-run this dry-run — all transactional counts should be 0

Re-run counts anytime:

```bash
npx supabase db query --linked --file supabase/scripts/dry_run_dev_data_counts.sql
```
