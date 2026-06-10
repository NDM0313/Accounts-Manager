-- =============================================================================
-- WARNING: DESTRUCTIVE — FXDEV transactional data reset
-- =============================================================================
-- Project: ygidlcqhupmxvsdjmvnf ONLY
-- DO NOT RUN until dry_run_dev_data_counts.sql reviewed and user approves.
-- DO NOT run on production / non-FXDEV companies.
--
-- KEEPS: auth.users, admin profile/roles, FXDEV/MAIN, COA, default currencies,
--        storage bucket config, migration history.
-- CLEARS: deals, transactions, journals, closings, attachments metadata,
--         FXDEV parties, optional audit logs / rate rows.
--
-- Rollback: if not committed, ROLLBACK; if committed, data is gone (no undo).
-- Storage objects: delete manually — see docs/STORAGE_CLEANUP_AFTER_RESET.md
-- =============================================================================

BEGIN;

DO $$
DECLARE
  v_company UUID;
  v_branch UUID;
  v_code TEXT;
BEGIN
  SELECT id INTO v_company FROM fx_companies WHERE code = 'FXDEV';
  IF v_company IS NULL THEN
    RAISE EXCEPTION 'ABORT: FXDEV company not found — wrong database?';
  END IF;

  SELECT id INTO v_branch FROM fx_branches WHERE company_id = v_company AND code = 'MAIN';
  RAISE NOTICE 'Resetting transactional data for FXDEV company % branch %', v_company, v_branch;
END $$;

-- 1) Attachment metadata (transaction-scoped; leg-scoped after migration)
DELETE FROM fx_attachments a
USING fx_transactions t, fx_branches b, fx_companies c
WHERE a.transaction_id = t.id AND t.branch_id = b.id AND b.company_id = c.id AND c.code = 'FXDEV';

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'fx_attachments' AND column_name = 'deal_id'
  ) THEN
    DELETE FROM fx_attachments a
    USING fx_deals d, fx_branches b, fx_companies c
    WHERE a.deal_id = d.id AND d.branch_id = b.id AND b.company_id = c.id AND c.code = 'FXDEV';
  END IF;
END $$;

-- 2) Journals
DELETE FROM fx_journal_lines jl
USING fx_journal_entries j, fx_branches b, fx_companies c
WHERE jl.journal_entry_id = j.id AND j.branch_id = b.id AND b.company_id = c.id AND c.code = 'FXDEV';

DELETE FROM fx_journal_entries j
USING fx_branches b, fx_companies c
WHERE j.branch_id = b.id AND b.company_id = c.id AND c.code = 'FXDEV';

-- 3) Transactions
DELETE FROM fx_transaction_lines tl
USING fx_transactions t, fx_branches b, fx_companies c
WHERE tl.transaction_id = t.id AND t.branch_id = b.id AND b.company_id = c.id AND c.code = 'FXDEV';

DELETE FROM fx_transaction_versions tv
USING fx_transactions t, fx_branches b, fx_companies c
WHERE tv.transaction_id = t.id AND t.branch_id = b.id AND b.company_id = c.id AND c.code = 'FXDEV';

DELETE FROM fx_transactions t
USING fx_branches b, fx_companies c
WHERE t.branch_id = b.id AND b.company_id = c.id AND c.code = 'FXDEV';

-- 4) Deals (cascades legs, commitments, settlement links)
DELETE FROM fx_deals d
USING fx_branches b, fx_companies c
WHERE d.branch_id = b.id AND b.company_id = c.id AND c.code = 'FXDEV';

-- 5) Daily closings
DELETE FROM fx_closing_lines cl
USING fx_daily_closings dc, fx_branches b, fx_companies c
WHERE cl.daily_closing_id = dc.id AND dc.branch_id = b.id AND b.company_id = c.id AND c.code = 'FXDEV';

DELETE FROM fx_daily_closings dc
USING fx_branches b, fx_companies c
WHERE dc.branch_id = b.id AND b.company_id = c.id AND c.code = 'FXDEV';

-- 6) Audit logs (uncomment only if user approves dev audit clear)
-- DELETE FROM fx_audit_logs al USING fx_companies c WHERE al.company_id = c.id AND c.code = 'FXDEV';

-- 7) Parties (all FXDEV — add exceptions here if needed)
DELETE FROM fx_parties p
USING fx_companies c
WHERE p.company_id = c.id AND c.code = 'FXDEV';

-- 8) Optional: clear rate history for fresh manual entry (off by default)
-- DELETE FROM fx_rates r USING fx_branches b, fx_companies c
-- WHERE r.branch_id = b.id AND b.company_id = c.id AND c.code = 'FXDEV';

COMMIT;

-- Verify counts should be 0 for deals/transactions after commit.
-- Re-run dry_run_dev_data_counts.sql
