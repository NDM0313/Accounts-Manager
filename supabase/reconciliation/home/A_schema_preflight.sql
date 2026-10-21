-- =============================================================================
-- A) SCHEMA PREFLIGHT (read-only intent)
-- Home shared DB: supabase-db / postgres (PG17)
-- DO NOT apply mutations. Safe to run as SELECT diagnostics.
-- =============================================================================
-- Expected target identity (manual verification before any later apply):
--   current_database() = 'postgres'
--   version() includes 'PostgreSQL 17'
-- =============================================================================

SET statement_timeout = '15s';
SET default_transaction_read_only = on;

-- 1) Identity
SELECT current_database() AS db,
       current_user AS usr,
       version() AS pg_version;

-- 2) ERP-owned purchase tables MUST exist (preserve)
SELECT to_regclass('public.fx_currency_purchases') AS fx_currency_purchases,
       to_regclass('public.fx_currency_purchase_settlements') AS fx_currency_purchase_settlements;

-- 3) Foundation tables present (Accounts-Manager reusable / shared names)
SELECT t AS table_name, to_regclass('public.' || t) IS NOT NULL AS exists
FROM unnest(ARRAY[
  'fx_companies','fx_branches','fx_users_profiles','fx_roles','fx_user_roles',
  'fx_currencies','fx_rates','fx_accounts','fx_parties'
]) AS t;

-- 4) Accounts-Manager ledger objects expected missing before additive apply
SELECT t AS missing_expected, to_regclass('public.' || t) IS NOT NULL AS exists
FROM unnest(ARRAY[
  'fx_transactions','fx_transaction_lines','fx_journal_entries','fx_journal_lines',
  'fx_deals','fx_deal_legs','fx_remittances','fx_attachments','fx_messages',
  'fx_opening_balance_batches'
]) AS t;

-- 5) Enum labels (must match AM foundation if reusing types)
SELECT t.typname,
       string_agg(e.enumlabel, ',' ORDER BY e.enumsortorder) AS labels
FROM pg_type t
JOIN pg_enum e ON e.enumtypid = t.oid
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'public'
  AND t.typname IN (
    'fx_account_type','fx_party_type','fx_transaction_type','fx_transaction_status'
  )
GROUP BY t.typname
ORDER BY 1;

-- 6) RLS / policy inventory for allowlisted tables only
SELECT c.relname,
       c.relrowsecurity AS rls,
       c.relforcerowsecurity AS force_rls,
       pg_get_userbyid(c.relowner) AS owner
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relname IN (
    'fx_companies','fx_branches','fx_users_profiles','fx_roles','fx_user_roles',
    'fx_currencies','fx_rates','fx_accounts','fx_parties',
    'fx_currency_purchases','fx_currency_purchase_settlements'
  )
ORDER BY 1;

SELECT tablename, policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'fx_companies','fx_branches','fx_users_profiles','fx_roles','fx_user_roles',
    'fx_currencies','fx_rates','fx_accounts','fx_parties',
    'fx_currency_purchases','fx_currency_purchase_settlements'
  )
ORDER BY 1, 2;

-- 7) ERP purchase FKs must continue pointing at ERP companies/contacts/etc.
SELECT conname, conrelid::regclass AS from_table, confrelid::regclass AS to_table
FROM pg_constraint
WHERE contype = 'f'
  AND conrelid::regclass::text IN (
    'fx_currency_purchases','fx_currency_purchase_settlements'
  )
ORDER BY 1;

-- 8) Storage bucket for AM attachments
SELECT id, name, public
FROM storage.buckets
WHERE id = 'fx-attachments';

-- 9) Stop conditions for later apply (human checklist):
-- FAIL if fx_currency_purchases missing
-- FAIL if foundation enums labels diverge from AM expectation
-- FAIL if unexpected columns appear on foundation tables vs matrix
-- FAIL if database is not postgres PG17 production identity
