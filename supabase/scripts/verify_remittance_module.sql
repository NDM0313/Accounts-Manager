-- Non-destructive verification for remittance module (run after migration apply)
SELECT 'fx_remittances' AS tbl, COUNT(*) FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'fx_remittances';

SELECT proname FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND proname LIKE 'fx_%remittance%'
ORDER BY proname;

SELECT code, name FROM fx_accounts WHERE code IN ('2350', '4310') ORDER BY code;
