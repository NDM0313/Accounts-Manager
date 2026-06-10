-- READ-ONLY dry-run: FXDEV data counts before cleanup
-- Project: ygidlcqhupmxvsdjmvnf only. Do NOT delete anything.

DO $$
DECLARE
  v_company UUID;
  v_branch UUID;
BEGIN
  SELECT id INTO v_company FROM fx_companies WHERE code = 'FXDEV';
  SELECT id INTO v_branch FROM fx_branches WHERE company_id = v_company AND code = 'MAIN';

  IF v_company IS NULL THEN
    RAISE EXCEPTION 'FXDEV company not found';
  END IF;

  RAISE NOTICE '=== FXDEV CLEANUP DRY-RUN ===';
  RAISE NOTICE 'company_id: %', v_company;
  RAISE NOTICE 'branch_id (MAIN): %', v_branch;
END $$;

-- Transactional / deal data
SELECT 'fx_deals' AS table_name, COUNT(*) AS row_count
FROM fx_deals d JOIN fx_branches b ON b.id = d.branch_id JOIN fx_companies c ON c.id = b.company_id WHERE c.code = 'FXDEV'
UNION ALL
SELECT 'fx_deal_legs', COUNT(*)
FROM fx_deal_legs l JOIN fx_deals d ON d.id = l.deal_id JOIN fx_branches b ON b.id = d.branch_id JOIN fx_companies c ON c.id = b.company_id WHERE c.code = 'FXDEV'
UNION ALL
SELECT 'fx_currency_commitments', COUNT(*)
FROM fx_currency_commitments cc JOIN fx_deals d ON d.id = cc.deal_id JOIN fx_branches b ON b.id = d.branch_id JOIN fx_companies c ON c.id = b.company_id WHERE c.code = 'FXDEV'
UNION ALL
SELECT 'fx_settlement_links', COUNT(*)
FROM fx_settlement_links sl JOIN fx_deals d ON d.id = sl.deal_id JOIN fx_branches b ON b.id = d.branch_id JOIN fx_companies c ON c.id = b.company_id WHERE c.code = 'FXDEV'
UNION ALL
SELECT 'fx_transactions', COUNT(*)
FROM fx_transactions t JOIN fx_branches b ON b.id = t.branch_id JOIN fx_companies c ON c.id = b.company_id WHERE c.code = 'FXDEV'
UNION ALL
SELECT 'fx_transaction_lines', COUNT(*)
FROM fx_transaction_lines tl JOIN fx_transactions t ON t.id = tl.transaction_id JOIN fx_branches b ON b.id = t.branch_id JOIN fx_companies c ON c.id = b.company_id WHERE c.code = 'FXDEV'
UNION ALL
SELECT 'fx_transaction_versions', COUNT(*)
FROM fx_transaction_versions tv JOIN fx_transactions t ON t.id = tv.transaction_id JOIN fx_branches b ON b.id = t.branch_id JOIN fx_companies c ON c.id = b.company_id WHERE c.code = 'FXDEV'
UNION ALL
SELECT 'fx_journal_entries', COUNT(*)
FROM fx_journal_entries j JOIN fx_branches b ON b.id = j.branch_id JOIN fx_companies c ON c.id = b.company_id WHERE c.code = 'FXDEV'
UNION ALL
SELECT 'fx_journal_lines', COUNT(*)
FROM fx_journal_lines jl JOIN fx_journal_entries j ON j.id = jl.journal_entry_id JOIN fx_branches b ON b.id = j.branch_id JOIN fx_companies c ON c.id = b.company_id WHERE c.code = 'FXDEV'
UNION ALL
SELECT 'fx_daily_closings', COUNT(*)
FROM fx_daily_closings dc JOIN fx_branches b ON b.id = dc.branch_id JOIN fx_companies c ON c.id = b.company_id WHERE c.code = 'FXDEV'
UNION ALL
SELECT 'fx_closing_lines', COUNT(*)
FROM fx_closing_lines cl JOIN fx_daily_closings dc ON dc.id = cl.daily_closing_id JOIN fx_branches b ON b.id = dc.branch_id JOIN fx_companies c ON c.id = b.company_id WHERE c.code = 'FXDEV'
UNION ALL
SELECT 'fx_attachments', COUNT(*)
FROM fx_attachments a JOIN fx_transactions t ON t.id = a.transaction_id JOIN fx_branches b ON b.id = t.branch_id JOIN fx_companies c ON c.id = b.company_id WHERE c.code = 'FXDEV'
UNION ALL
SELECT 'fx_parties', COUNT(*)
FROM fx_parties p JOIN fx_companies c ON c.id = p.company_id WHERE c.code = 'FXDEV'
UNION ALL
SELECT 'fx_audit_logs', COUNT(*)
FROM fx_audit_logs al JOIN fx_companies c ON c.id = al.company_id WHERE c.code = 'FXDEV'
UNION ALL
SELECT 'fx_rates', COUNT(*)
FROM fx_rates r JOIN fx_branches b ON b.id = r.branch_id JOIN fx_companies c ON c.id = b.company_id WHERE c.code = 'FXDEV'
ORDER BY table_name;

-- Demo parties sample
SELECT p.code, p.name, p.party_type, p.is_active
FROM fx_parties p JOIN fx_companies c ON c.id = p.company_id
WHERE c.code = 'FXDEV'
ORDER BY p.code;

-- Admin sanity (email only — no secrets)
SELECT u.id, u.email, p.full_name, p.is_active AS profile_active
FROM auth.users u
LEFT JOIN fx_users_profiles p ON p.id = u.id
WHERE u.email = 'ndm313@yahoo.com';

SELECT COUNT(*) AS coa_accounts FROM fx_accounts a JOIN fx_companies c ON c.id = a.company_id WHERE c.code = 'FXDEV';

SELECT code, name, is_base, is_active FROM fx_currencies ORDER BY code;
