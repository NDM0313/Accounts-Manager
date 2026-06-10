-- Manual demo: multi-leg FX deal (customer order → agent source → delivery)
-- Run in Supabase SQL Editor AFTER applying 202606170001_fx_deals_workflow.sql
-- Does NOT touch old ERP/VPS

-- Requires: dev company branch MAIN, customer + agent parties exist
-- Adjust party UUIDs after checking fx_parties

DO $$
DECLARE
  v_branch UUID := '00000000-0000-4000-8000-000000000002';
  v_customer UUID;
  v_agent_c UUID;
  v_deal_id UUID;
  v_leg_c UUID;
BEGIN
  SELECT id INTO v_customer FROM fx_parties WHERE party_type = 'customer' AND is_active LIMIT 1;
  SELECT id INTO v_agent_c FROM fx_parties WHERE party_type = 'agent' AND is_active LIMIT 1;

  IF v_customer IS NULL OR v_agent_c IS NULL THEN
    RAISE NOTICE 'Skip seed: create at least one customer and one agent party first';
    RETURN;
  END IF;

  SELECT fx_book_customer_deal_v2(jsonb_build_object(
    'branch_id', v_branch,
    'customer_party_id', v_customer,
    'sell_currency_code', 'CNY',
    'sell_amount', 5000,
    'sale_rate_pkr', 41.25,
    'customer_paid_now_pkr', 0,
    'delivery_method', 'agent',
    'allow_short_position', false,
    'notes', 'Demo RMB sale to customer',
    'auto_source', true
  )) INTO v_deal_id;

  SELECT fx_add_deal_leg_v2(jsonb_build_object(
    'deal_id', v_deal_id,
    'leg_type', 'agent_source',
    'counterparty_party_id', v_agent_c,
    'receive_currency', 'CNY',
    'receive_amount', 5000,
    'pay_currency', 'AED',
    'pay_amount', 500,
    'rate_used', 0.08,
    'delivery_target', 'our_account',
    'notes', 'Agent C provides RMB for AED'
  )) INTO v_leg_c;

  RAISE NOTICE 'Demo deal created: % (agent leg %)', v_deal_id, v_leg_c;
END $$;
