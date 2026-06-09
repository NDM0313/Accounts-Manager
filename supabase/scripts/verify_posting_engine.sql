-- Verify Phase 3 posting engine (run in Supabase SQL Editor)
-- Project: ygidlcqhupmxvsdjmvnf only
--
-- NOTE: RPCs like fx_get_trial_balance_totals() check auth.uid() permissions.
-- In SQL Editor there is no logged-in app user, so use the DIRECT queries below
-- for trial balance checks. The Flutter app uses the RPCs with your JWT.

-- 1) RPC existence (should return 7 rows)
SELECT proname AS function_name
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN (
    'fx_build_journal_from_transaction',
    'fx_validate_transaction_lines_balanced',
    'fx_get_cash_balances',
    'fx_get_trial_balance',
    'fx_get_trial_balance_totals',
    'fx_post_transaction',
    'fx_generate_transaction_no',
    'fx_void_journals_for_transaction'
  )
ORDER BY proname;

-- 2) Seed sanity
SELECT 'coa_count' AS check_name, COUNT(*)::text AS result FROM fx_accounts;
SELECT 'currencies' AS check_name, string_agg(code, ', ' ORDER BY code) AS result FROM fx_currencies;

-- 3) Trial balance (SQL Editor safe — no auth.uid() required)
SELECT
  'tb_totals_direct' AS check_name,
  COALESCE(SUM(jl.debit_pkr), 0) AS total_debit,
  COALESCE(SUM(jl.credit_pkr), 0) AS total_credit,
  COALESCE(SUM(jl.debit_pkr), 0) = COALESCE(SUM(jl.credit_pkr), 0) AS is_balanced
FROM fx_journal_lines jl
JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
WHERE je.branch_id = '00000000-0000-4000-8000-000000000002'::uuid
  AND NOT je.is_void;

-- 4) Admin bootstrap check (replace email if needed)
SELECT
  u.email,
  p.branch_id,
  r.name AS role_name,
  r.permissions
FROM auth.users u
LEFT JOIN fx_users_profiles p ON p.id = u.id
LEFT JOIN fx_user_roles ur ON ur.user_id = u.id
LEFT JOIN fx_roles r ON r.id = ur.role_id
WHERE u.email = 'ndm313@yahoo.com';
