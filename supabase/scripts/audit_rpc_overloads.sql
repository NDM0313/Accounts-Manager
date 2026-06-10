-- Read-only audit: FX RPC overloads (run on Cloud ygidlcqhupmxvsdjmvnf only)
-- Expected BEFORE fix: 2 rows each for fx_add_deal_leg, fx_book_customer_deal
-- Expected AFTER 202606180005: 0 legacy rows; 1 row each for *_v2

SELECT
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS identity_args,
  p.oid
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
    p.proname LIKE 'fx_%'
    AND p.proname IN (
      'fx_add_deal_leg',
      'fx_book_customer_deal',
      'fx_add_deal_leg_v2',
      'fx_book_customer_deal_v2'
    )
  )
ORDER BY p.proname, p.oid;
