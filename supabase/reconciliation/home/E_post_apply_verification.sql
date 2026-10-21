-- =============================================================================
-- E) POST-APPLY VERIFICATION (read-only)
-- =============================================================================

SET statement_timeout = '30s';
SET default_transaction_read_only = on;

-- Identity
SELECT current_database(), version();

-- ERP objects untouched (presence)
SELECT to_regclass('public.fx_currency_purchases') AS erp_purchases,
       to_regclass('public.fx_currency_purchase_settlements') AS erp_settlements;

-- AM core + modules
SELECT t, to_regclass('public.'||t) IS NOT NULL AS ok
FROM unnest(ARRAY[
  'fx_transactions','fx_journal_entries','fx_deals','fx_deal_legs',
  'fx_remittances','fx_messages','fx_conversations',
  'fx_opening_balance_batches','fx_notifications',
  'fx_agent_currency_balances','fx_client_operations'
]) t;

-- Flutter RPC allowlist presence
SELECT r AS rpc, to_regprocedure(r) IS NOT NULL AS ok
FROM unnest(ARRAY[
  'fx_post_transaction(uuid)',
  'fx_book_customer_deal_v2(jsonb)',
  'fx_add_deal_leg_v2(jsonb)',
  'fx_create_remittance(uuid,uuid,text,text,text,text,uuid,text,numeric,text,numeric,numeric,numeric,text,text,boolean)',
  'fx_record_remittance_customer_payment(uuid,numeric,text,text,text)',
  'fx_settle_remittance_agent(uuid,numeric,text,text,text)',
  'fx_refund_remittance(uuid,numeric,text,text,text)',
  'fx_list_conversations(uuid)',
  'fx_get_trial_balance(uuid,date,date)'
]) r;

-- Demo seed functions should remain absent (excluded from G)
SELECT count(*) AS demo_seed_functions
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname ILIKE 'fx_seed_fxdev%';

-- Bucket
SELECT id, public FROM storage.buckets WHERE id = 'fx-attachments';
