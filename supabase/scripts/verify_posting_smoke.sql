-- Posting smoke checks (run after manual draft → post in app)
-- Project: ygidlcqhupmxvsdjmvnf · Branch MAIN

-- Trial balance (SQL Editor safe)
SELECT
  'trial_balance_direct' AS check_name,
  COALESCE(SUM(jl.debit_pkr), 0) AS total_debit,
  COALESCE(SUM(jl.credit_pkr), 0) AS total_credit,
  COALESCE(SUM(jl.debit_pkr), 0) = COALESCE(SUM(jl.credit_pkr), 0) AS is_balanced
FROM fx_journal_lines jl
JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
WHERE je.branch_id = '00000000-0000-4000-8000-000000000002'::uuid
  AND NOT je.is_void;

-- Recent posted transactions with journal links
SELECT
  t.transaction_no,
  t.transaction_type,
  t.status,
  t.total_base_amount_pkr,
  je.entry_no AS journal_entry_no
FROM fx_transactions t
LEFT JOIN fx_journal_entries je ON je.transaction_id = t.id AND NOT je.is_void
WHERE t.branch_id = '00000000-0000-4000-8000-000000000002'::uuid
  AND t.status = 'posted'
ORDER BY t.posted_at DESC NULLS LAST
LIMIT 10;

-- Closed-day block test (manual):
-- SELECT fx_close_day('00000000-0000-4000-8000-000000000002'::uuid, CURRENT_DATE, 'test close');
-- Then post a draft in the app — expect "Day is closed" error.
