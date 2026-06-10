-- DRAFT: Reference rate snapshot columns (DO NOT deploy until approved)
-- SUPERSEDED BY: 202606180002_fx_rates_versioning_and_snapshots.sql
-- Project: ygidlcqhupmxvsdjmvnf only
--
-- Phase 1 ships UI-only reference display; this migration enables persisting
-- reference snapshots at deal/transaction booking time.

-- fx_rates: optional source metadata (manual / SBP / market / api)
ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS rate_source TEXT NOT NULL DEFAULT 'manual';

-- fx_deal_legs: reference snapshot at leg creation
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate NUMERIC(20, 8);
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_pair TEXT;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_source TEXT;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_at TIMESTAMPTZ;

-- fx_transactions: reference snapshot for draft/posted transactions
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate NUMERIC(20, 8);
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_pair TEXT;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_source TEXT;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_at TIMESTAMPTZ;

-- NOTE: After approval, update fx_add_deal_leg and transaction insert RPCs
-- to accept optional reference snapshot params. Posting continues to use rate_used only.
