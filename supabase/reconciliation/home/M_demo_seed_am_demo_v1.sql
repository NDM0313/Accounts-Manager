-- =============================================================================
-- M) AM_DEMO company bootstrap + deterministic seed v1
-- Activation: fx_reconciliation.confirm = 'APPLY_AM_DEMO_SEED_V1'
-- Synthetic rates/data only. Never touches non-AM_DEMO companies.
-- =============================================================================

DO $guard$
BEGIN
  IF current_setting('fx_reconciliation.confirm', true) IS DISTINCT FROM 'APPLY_AM_DEMO_SEED_V1' THEN
    RAISE EXCEPTION 'BLOCKED: set fx_reconciliation.confirm=APPLY_AM_DEMO_SEED_V1';
  END IF;
  IF to_regclass('public.fx_user_company_memberships') IS NULL THEN
    RAISE EXCEPTION 'BLOCKED: run L_demo_workspace_membership.sql first';
  END IF;
END
$guard$;

CREATE TABLE IF NOT EXISTS fx_demo_seed_batches (
  seed_version TEXT PRIMARY KEY,
  company_id UUID NOT NULL REFERENCES fx_companies(id),
  actor_user_id UUID,
  result_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Stable demo IDs
-- company a1111111-1111-4111-8111-111111111101
-- branch  a1111111-1111-4111-8111-111111111102

CREATE OR REPLACE FUNCTION fx_post_agent_currency_purchase(
  p_company_id UUID,
  p_branch_id UUID,
  p_agent_party_id UUID,
  p_currency TEXT,
  p_foreign_amount NUMERIC,
  p_rate_pkr NUMERIC,
  p_cash_account_code TEXT DEFAULT '1110',
  p_notes TEXT DEFAULT NULL,
  p_client_operation_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx UUID;
  v_cash UUID;
  v_inv UUID;
  v_pkr NUMERIC;
  v_cc TEXT := upper(p_currency);
  v_existing UUID;
  v_row fx_agent_currency_balances;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF NOT fx_same_company(p_company_id) OR NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized company/branch';
  END IF;
  IF p_foreign_amount <= 0 OR p_rate_pkr <= 0 THEN RAISE EXCEPTION 'Amount/rate must be positive'; END IF;
  v_pkr := ROUND(p_foreign_amount * p_rate_pkr, 8);

  IF p_client_operation_id IS NOT NULL THEN
    SELECT (result_json->>'transaction_id')::uuid INTO v_existing
    FROM fx_client_operations
    WHERE company_id = p_company_id AND operation_key = p_client_operation_id;
    IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;
  END IF;

  v_cash := fx_account_id_by_code(p_company_id, p_cash_account_code);
  v_inv := COALESCE(
    fx_account_id_by_code(p_company_id, CASE v_cc
      WHEN 'USD' THEN '1120' WHEN 'AED' THEN '1130' WHEN 'CNY' THEN '1140' ELSE '1120' END),
    fx_account_id_by_code(p_company_id, '1120')
  );

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, created_by
  ) VALUES (
    p_company_id, p_branch_id, 'currency_buy', 'draft', CURRENT_DATE,
    p_agent_party_id, v_cc, p_foreign_amount, p_rate_pkr, v_pkr,
    COALESCE(p_notes, 'Agent-held purchase ' || v_cc), auth.uid()
  ) RETURNING id INTO v_tx;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx, 1, v_inv, v_cc, p_foreign_amount, p_rate_pkr, v_pkr, 0, 'Currency held by agent'),
    (v_tx, 2, v_cash, 'PKR', v_pkr, 1, 0, v_pkr, 'PKR paid for purchase');

  PERFORM fx_post_transaction(v_tx);

  v_row := fx_agent_balance_ensure(p_company_id, p_branch_id, p_agent_party_id, v_cc);
  UPDATE fx_agent_currency_balances SET
    owned_amount = owned_amount + p_foreign_amount,
    carrying_cost_pkr = COALESCE(carrying_cost_pkr, 0) + v_pkr,
    updated_at = NOW()
  WHERE id = v_row.id;

  IF p_client_operation_id IS NOT NULL THEN
    INSERT INTO fx_client_operations (company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by)
    VALUES (p_company_id, p_client_operation_id, 'agent_currency_purchase', 'fx_transaction', v_tx,
      jsonb_build_object('transaction_id', v_tx, 'pkr', v_pkr), auth.uid());
  END IF;
  RETURN v_tx;
END;
$$;

-- Partial / funding-aware remittance payout from agent custody or agent-funded credit
CREATE OR REPLACE FUNCTION fx_confirm_remittance_payout_ex(
  p_remittance_id UUID,
  p_payout_foreign_amount NUMERIC DEFAULT NULL,
  p_funding_mode TEXT DEFAULT NULL,
  p_proof_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_payout_method TEXT DEFAULT NULL,
  p_client_operation_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx UUID;
  v_event_no INT;
  v_liability UUID;
  v_agent_pay UUID;
  v_inv UUID;
  v_spread UUID;
  v_pay_amt NUMERIC;
  v_pkr_slice NUMERIC;
  v_cost NUMERIC;
  v_mode TEXT;
  v_existing UUID;
  v_paid_out_foreign NUMERIC;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status IN ('cancelled', 'refunded', 'completed') THEN RAISE EXCEPTION 'Invalid status %', v_r.status; END IF;
  IF v_r.payout_agent_party_id IS NULL THEN RAISE EXCEPTION 'Payout agent required'; END IF;

  IF p_client_operation_id IS NOT NULL THEN
    SELECT (result_json->>'transaction_id')::uuid INTO v_existing
    FROM fx_client_operations WHERE company_id = v_r.company_id AND operation_key = p_client_operation_id;
    IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;
  END IF;

  v_mode := COALESCE(p_funding_mode, v_r.payout_funding_mode, 'agent_owned_balance');
  IF v_mode NOT IN ('agent_owned_balance', 'agent_credit_payable') THEN
    RAISE EXCEPTION 'Invalid funding mode %', v_mode;
  END IF;

  v_paid_out_foreign := COALESCE((
    SELECT SUM(amount) FROM fx_remittance_events
    WHERE remittance_id = p_remittance_id AND event_type = 'payout_confirmed'
  ), 0);
  v_pay_amt := COALESCE(p_payout_foreign_amount, v_r.payout_amount - v_paid_out_foreign);
  IF v_pay_amt <= 0 THEN RAISE EXCEPTION 'Payout amount must be positive'; END IF;
  IF v_paid_out_foreign + v_pay_amt > v_r.payout_amount + 0.00000001 THEN
    RAISE EXCEPTION 'Payout exceeds remaining';
  END IF;

  v_pkr_slice := ROUND(v_r.receive_amount * (v_pay_amt / NULLIF(v_r.payout_amount, 0)), 8);
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');
  v_spread := fx_account_id_by_code(v_r.company_id, '4100');
  v_inv := COALESCE(
    fx_account_id_by_code(v_r.company_id, CASE upper(v_r.payout_currency)
      WHEN 'USD' THEN '1120' WHEN 'AED' THEN '1130' WHEN 'CNY' THEN '1140' ELSE '1120' END),
    fx_account_id_by_code(v_r.company_id, '1120')
  );

  IF v_mode = 'agent_owned_balance' THEN
    IF COALESCE(v_r.reserved_payout_amount, 0) < v_pay_amt THEN
      PERFORM fx_agent_balance_reserve(v_r.company_id, v_r.branch_id, v_r.payout_agent_party_id, v_r.payout_currency,
        v_pay_amt - COALESCE(v_r.reserved_payout_amount, 0));
      UPDATE fx_remittances SET
        reserved_payout_amount = COALESCE(reserved_payout_amount, 0)
          + (v_pay_amt - COALESCE(reserved_payout_amount, 0)),
        reserved_payout_currency = v_r.payout_currency,
        payout_funding_mode = v_mode
      WHERE id = p_remittance_id;
      SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
    END IF;

    -- Explicit lot cost BEFORE consume (never default to sale)
    SELECT ROUND(COALESCE(carrying_cost_pkr, 0) * (v_pay_amt / NULLIF(owned_amount, 0)), 8)
      INTO v_cost
    FROM fx_agent_currency_balances
    WHERE company_id = v_r.company_id AND branch_id = v_r.branch_id
      AND agent_party_id = v_r.payout_agent_party_id AND currency_code = upper(v_r.payout_currency)
    FOR UPDATE;
    IF v_cost IS NULL OR COALESCE(v_cost, -1) < 0 THEN
      RAISE EXCEPTION 'Missing carrying cost for owned payout — refuse silent zero/sale default';
    END IF;

    PERFORM fx_agent_balance_consume_reserve(
      v_r.company_id, v_r.branch_id, v_r.payout_agent_party_id, v_r.payout_currency, v_pay_amt);
    UPDATE fx_remittances
      SET reserved_payout_amount = GREATEST(0, reserved_payout_amount - v_pay_amt)
    WHERE id = p_remittance_id;
    UPDATE fx_agent_currency_balances SET
      carrying_cost_pkr = GREATEST(0, COALESCE(carrying_cost_pkr, 0) - v_cost),
      updated_at = NOW()
    WHERE company_id = v_r.company_id AND branch_id = v_r.branch_id
      AND agent_party_id = v_r.payout_agent_party_id AND currency_code = upper(v_r.payout_currency);

    INSERT INTO fx_transactions (company_id, branch_id, transaction_type, status, transaction_date, party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr, description, remittance_id, created_by)
    VALUES (v_r.company_id, v_r.branch_id, 'currency_sell', 'draft', CURRENT_DATE, v_r.sender_party_id, v_r.payout_currency, v_pay_amt, v_r.exchange_rate, v_pkr_slice,
      COALESCE(p_notes, 'Owned-balance payout ' || v_r.tracking_id), p_remittance_id, auth.uid())
    RETURNING id INTO v_tx;

    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo) VALUES
      (v_tx, 1, v_liability, 'PKR', v_pkr_slice, 1, v_pkr_slice, 0, 'Clear customer advance portion'),
      (v_tx, 2, v_inv, v_r.payout_currency, v_pay_amt, v_r.exchange_rate, 0, v_cost, 'Release agent-held inventory at cost');
    IF v_pkr_slice - v_cost <> 0 THEN
      INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
      VALUES (v_tx, 3, v_spread, 'PKR', ABS(v_pkr_slice - v_cost), 1,
        CASE WHEN v_pkr_slice < v_cost THEN ABS(v_pkr_slice - v_cost) ELSE 0 END,
        CASE WHEN v_pkr_slice > v_cost THEN v_pkr_slice - v_cost ELSE 0 END,
        'Realized gross spread');
    END IF;
  ELSE
    -- agent-funded: liability → agent payable; no owned inventory move
    INSERT INTO fx_transactions (company_id, branch_id, transaction_type, status, transaction_date, party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr, description, remittance_id, created_by)
    VALUES (v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', CURRENT_DATE, v_r.payout_agent_party_id, v_r.payout_currency, v_pay_amt, v_r.exchange_rate, v_pkr_slice,
      COALESCE(p_notes, 'Agent-funded payout ' || v_r.tracking_id), p_remittance_id, auth.uid())
    RETURNING id INTO v_tx;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo) VALUES
      (v_tx, 1, v_liability, 'PKR', v_pkr_slice, 1, v_pkr_slice, 0, 'Clear remittance liability'),
      (v_tx, 2, v_agent_pay, 'PKR', v_pkr_slice, 1, 0, v_pkr_slice, 'Agent payable (agent-funded)');
    UPDATE fx_agent_currency_balances SET
      payable_pkr = payable_pkr + v_pkr_slice, updated_at = NOW()
    WHERE company_id = v_r.company_id AND branch_id = v_r.branch_id
      AND agent_party_id = v_r.payout_agent_party_id AND currency_code = upper(v_r.payout_currency);
    IF NOT FOUND THEN
      PERFORM fx_agent_balance_ensure(v_r.company_id, v_r.branch_id, v_r.payout_agent_party_id, v_r.payout_currency);
      UPDATE fx_agent_currency_balances SET payable_pkr = payable_pkr + v_pkr_slice, updated_at = NOW()
      WHERE company_id = v_r.company_id AND branch_id = v_r.branch_id
        AND agent_party_id = v_r.payout_agent_party_id AND currency_code = upper(v_r.payout_currency);
    END IF;
  END IF;

  PERFORM fx_post_transaction(v_tx);
  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose) VALUES (p_remittance_id, v_tx, 'agent_payout');
  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, amount, currency_code, linked_transaction_id, proof_reference, notes, created_by)
  VALUES (
    p_remittance_id, v_event_no, 'payout_confirmed',
    CASE WHEN v_paid_out_foreign + v_pay_amt + 0.00000001 >= v_r.payout_amount THEN 'paid_out'::fx_remittance_status ELSE v_r.status END,
    v_pay_amt, v_r.payout_currency, v_tx, p_proof_reference, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET
    payout_funding_mode = v_mode,
    status = CASE WHEN v_paid_out_foreign + v_pay_amt + 0.00000001 >= payout_amount THEN 'paid_out'::fx_remittance_status ELSE status END,
    payout_status = CASE WHEN v_paid_out_foreign + v_pay_amt + 0.00000001 >= payout_amount THEN 'paid' ELSE 'partial' END,
    payout_method = COALESCE(p_payout_method, payout_method),
    payout_confirmed_at = CASE WHEN v_paid_out_foreign + v_pay_amt + 0.00000001 >= payout_amount THEN NOW() ELSE payout_confirmed_at END,
    updated_by = auth.uid(), updated_at = NOW()
  WHERE id = p_remittance_id;

  IF p_client_operation_id IS NOT NULL THEN
    INSERT INTO fx_client_operations (company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by)
    VALUES (v_r.company_id, p_client_operation_id, 'remittance_payout_ex', 'fx_remittance', p_remittance_id,
      jsonb_build_object('transaction_id', v_tx, 'payout_foreign', v_pay_amt, 'funding_mode', v_mode), auth.uid());
  END IF;
  RETURN v_tx;
END;
$$;

-- Patch settle to reduce agent payable_pkr when present
CREATE OR REPLACE FUNCTION fx_settle_remittance_agent(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT '1110',
  p_notes TEXT DEFAULT NULL,
  p_client_operation_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_cash UUID;
  v_agent_pay UUID;
  v_new_settled NUMERIC(20, 8);
  v_due NUMERIC(20, 8);
  v_settlement_status fx_remittance_settlement_status;
  v_new_status fx_remittance_status;
  v_existing UUID;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  IF p_client_operation_id IS NOT NULL THEN
    SELECT (result_json->>'transaction_id')::uuid INTO v_existing
    FROM fx_client_operations WHERE company_id = v_r.company_id AND operation_key = p_client_operation_id;
    IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;
  END IF;

  v_due := v_r.receive_amount;
  v_new_settled := v_r.settled_amount_pkr + p_amount;
  IF v_new_settled > v_due + 0.00000001 THEN
    RAISE EXCEPTION 'Settlement exceeds remaining due';
  END IF;

  v_cash := fx_account_id_by_code(v_r.company_id, COALESCE(p_cash_account_code, '1110'));
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');

  INSERT INTO fx_transactions (company_id, branch_id, transaction_type, status, transaction_date, party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr, description, remittance_id, created_by)
  VALUES (v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', CURRENT_DATE, v_r.payout_agent_party_id, 'PKR', p_amount, 1, p_amount, COALESCE(p_notes, 'Agent settlement ' || v_r.tracking_id), p_remittance_id, auth.uid())
  RETURNING id INTO v_tx_id;
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo) VALUES
    (v_tx_id, 1, v_agent_pay, 'PKR', p_amount, 1, p_amount, 0, 'Settle agent payable'),
    (v_tx_id, 2, v_cash, 'PKR', p_amount, 1, 0, p_amount, 'Cash paid to agent');
  PERFORM fx_post_transaction(v_tx_id);

  IF v_r.payout_agent_party_id IS NOT NULL THEN
    UPDATE fx_agent_currency_balances SET
      payable_pkr = GREATEST(0, payable_pkr - p_amount), updated_at = NOW()
    WHERE company_id = v_r.company_id AND branch_id = v_r.branch_id
      AND agent_party_id = v_r.payout_agent_party_id
      AND currency_code = upper(v_r.payout_currency);
  END IF;

  IF v_new_settled + 0.00000001 >= v_due THEN
    v_settlement_status := 'settled'; v_new_status := 'completed';
  ELSE
    v_settlement_status := 'partial'; v_new_status := v_r.status;
  END IF;

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, amount, currency_code, linked_transaction_id, notes, created_by)
  VALUES (p_remittance_id, v_event_no, 'agent_settlement', v_new_status, p_amount, 'PKR', v_tx_id, p_notes, auth.uid());
  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose) VALUES (p_remittance_id, v_tx_id, 'agent_settlement');

  UPDATE fx_remittances SET
    settled_amount_pkr = v_new_settled,
    settlement_status = v_settlement_status,
    status = v_new_status,
    completed_at = CASE WHEN v_new_status = 'completed' THEN NOW() ELSE completed_at END,
    updated_by = auth.uid(), updated_at = NOW()
  WHERE id = p_remittance_id;

  IF p_client_operation_id IS NOT NULL THEN
    INSERT INTO fx_client_operations (company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by)
    VALUES (v_r.company_id, p_client_operation_id, 'remittance_agent_settlement', 'fx_remittance', p_remittance_id,
      jsonb_build_object('transaction_id', v_tx_id), auth.uid());
  END IF;
  RETURN v_tx_id;
END;
$$;

CREATE OR REPLACE FUNCTION fx_seed_am_demo_v1(p_grant_user_email TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seed TEXT := 'AM_DEMO_SEED_V1';
  v_co UUID := 'a1111111-1111-4111-8111-111111111101';
  v_br UUID := 'a1111111-1111-4111-8111-111111111102';
  v_role UUID;
  v_actor UUID;
  v_uid UUID;
  v_china UUID := 'a1111111-1111-4111-8111-111111111201';
  v_dubai UUID := 'a1111111-1111-4111-8111-111111111202';
  v_usd_ag UUID := 'a1111111-1111-4111-8111-111111111203';
  v_ali UUID := 'a1111111-1111-4111-8111-111111111301';
  v_sara UUID := 'a1111111-1111-4111-8111-111111111302';
  v_bilal UUID := 'a1111111-1111-4111-8111-111111111303';
  v_hina UUID := 'a1111111-1111-4111-8111-111111111304';
  v_batch UUID;
  v_rid UUID;
  v_cash NUMERIC;
  v_cny_owned NUMERIC; v_cny_res NUMERIC; v_cny_avail NUMERIC;
  v_aed_owned NUMERIC; v_usd_owned NUMERIC;
  v_advances NUMERIC; v_payable NUMERIC; v_profit NUMERIC;
  v_result JSONB;
  v_extra INT;
BEGIN
  IF EXISTS (SELECT 1 FROM fx_demo_seed_batches WHERE seed_version = v_seed) THEN
    RETURN (SELECT result_json || jsonb_build_object('idempotent', true) FROM fx_demo_seed_batches WHERE seed_version = v_seed);
  END IF;

  -- Refuse if AM_DEMO already has non-seed user transactions
  IF EXISTS (
    SELECT 1 FROM fx_transactions t
    WHERE t.company_id = v_co AND t.status = 'posted'
      AND COALESCE(t.description, '') NOT LIKE 'DEMO_SEED_V1%'
  ) THEN
    RAISE EXCEPTION 'AM_DEMO has non-seed posted transactions — refuse automatic reset';
  END IF;

  -- Create company/branch
  INSERT INTO fx_companies (id, name, code, base_currency_code)
  VALUES (v_co, 'FX DEMO — SAMPLE DATA', 'AM_DEMO', 'PKR')
  ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO v_co;
  SELECT id INTO v_co FROM fx_companies WHERE code = 'AM_DEMO';

  INSERT INTO fx_branches (id, company_id, name, code)
  VALUES (v_br, v_co, 'Demo Branch', 'DEMO')
  ON CONFLICT (company_id, code) DO NOTHING;
  SELECT id INTO v_br FROM fx_branches WHERE company_id = v_co AND code = 'DEMO';

  INSERT INTO fx_roles (id, company_id, name, permissions)
  VALUES (
    'a1111111-1111-4111-8111-111111111110', v_co, 'admin',
    ARRAY[
      'can_access_fx_ledger','can_manage_fx_rates','can_post_fx_transaction',
      'can_edit_fx_transaction','can_delete_fx_transaction','can_view_fx_reports',
      'can_view_fx_audit','can_manage_chart_of_accounts','can_close_day',
      'can_manage_remittance','can_upload_fx_attachment','can_delete_fx_attachment'
    ]
  )
  ON CONFLICT (company_id, name) DO UPDATE SET permissions = EXCLUDED.permissions
  RETURNING id INTO v_role;
  IF v_role IS NULL THEN
    SELECT id INTO v_role FROM fx_roles WHERE company_id = v_co AND name = 'admin';
  END IF;

  -- Currencies + COA
  INSERT INTO fx_currencies (code, name, symbol, decimal_places, is_base, is_active) VALUES
    ('PKR','Pakistani Rupee','Rs',2,true,true),
    ('USD','US Dollar','$',2,false,true),
    ('AED','UAE Dirham','د.إ',2,false,true),
    ('CNY','Chinese Yuan (RMB)','¥',2,false,true)
  ON CONFLICT (code) DO NOTHING;

  INSERT INTO fx_accounts (company_id, code, name, account_type)
  SELECT v_co, x.code, x.name, x.atype::fx_account_type
  FROM (VALUES
    ('1110','Cash PKR','asset'),
    ('1120','Cash USD / agent inventory','asset'),
    ('1130','Cash AED / agent inventory','asset'),
    ('1140','Cash CNY / agent inventory','asset'),
    ('2100','Agent Payable','liability'),
    ('2350','Remittance Liability / Customer Advances','liability'),
    ('3100','Opening Equity','equity'),
    ('4100','FX Spread Income','income'),
    ('4310','Commission Income','income')
  ) AS x(code,name,atype)
  ON CONFLICT DO NOTHING;

  -- Parties
  INSERT INTO fx_parties (id, company_id, branch_id, party_type, code, name) VALUES
    (v_china, v_co, v_br, 'agent', 'DEMO_CN_AGENT', 'DEMO China Agent'),
    (v_dubai, v_co, v_br, 'agent', 'DEMO_AE_AGENT', 'DEMO Dubai Agent'),
    (v_usd_ag, v_co, v_br, 'agent', 'DEMO_US_AGENT', 'DEMO USD Agent'),
    (v_ali, v_co, v_br, 'customer', 'DEMO_CLI_ALI', 'DEMO Client Ali'),
    (v_sara, v_co, v_br, 'customer', 'DEMO_CLI_SARA', 'DEMO Client Sara'),
    (v_bilal, v_co, v_br, 'customer', 'DEMO_CLI_BILAL', 'DEMO Client Bilal'),
    (v_hina, v_co, v_br, 'customer', 'DEMO_CLI_HINA', 'DEMO Client Hina')
  ON CONFLICT (company_id, code) DO NOTHING;

  -- Narrow seed operator: GUC scoped to AM_DEMO only (no forged login session)
  v_actor := NULL;
  PERFORM set_config('fx_seed.active', '1', true);
  PERFORM set_config('fx_seed.company_id', v_co::text, true);
  PERFORM set_config('fx_seed.branch_id', v_br::text, true);

  -- Grant interactive user membership without removing real company membership
  IF p_grant_user_email IS NOT NULL THEN
    SELECT id INTO v_uid FROM auth.users WHERE lower(email) = lower(p_grant_user_email);
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Grant user % not found', p_grant_user_email; END IF;
    v_actor := v_uid;
    INSERT INTO fx_user_company_memberships (user_id, company_id, branch_id, role_id, is_active)
    VALUES (v_uid, v_co, v_br, v_role, true)
    ON CONFLICT (user_id, company_id) DO UPDATE SET branch_id = EXCLUDED.branch_id, role_id = EXCLUDED.role_id, is_active = true;
    -- Keep existing profile company (NDMFX); memberships enable demo switch
    IF NOT EXISTS (SELECT 1 FROM fx_users_profiles WHERE id = v_uid) THEN
      INSERT INTO fx_users_profiles (id, company_id, branch_id, full_name, email, is_active)
      VALUES (v_uid, v_co, v_br, split_part(p_grant_user_email,'@',1), p_grant_user_email, true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM fx_user_active_workspace WHERE user_id = v_uid) THEN
      INSERT INTO fx_user_active_workspace (user_id, company_id, branch_id)
      SELECT v_uid, company_id, branch_id FROM fx_users_profiles WHERE id = v_uid;
    END IF;
  END IF;

  -- Opening 2,000,000
  v_batch := (
    fx_save_opening_balance_batch(jsonb_build_object(
      'company_id', v_co, 'branch_id', v_br, 'opening_date', CURRENT_DATE,
      'base_currency_code', 'PKR', 'description', 'DEMO_SEED_V1 opening',
      'equity_account_id', fx_account_id_by_code(v_co, '3100'),
      'lines', jsonb_build_array(jsonb_build_object(
        'line_no', 1, 'line_kind', 'cash_bank', 'pkr_amount', 2000000,
        'currency_code', 'PKR', 'foreign_amount', 2000000, 'rate_used', 1,
        'account_id', fx_account_id_by_code(v_co, '1110'),
        'memo', 'DEMO_SEED_V1 opening cash'
      ))
    ))
  )#>>'{batch,id}';
  IF v_batch IS NULL THEN RAISE EXCEPTION 'Opening balance save returned no batch id'; END IF;
  PERFORM fx_post_opening_balance_batch(v_batch);

  -- Purchases
  PERFORM fx_post_agent_currency_purchase(v_co, v_br, v_china, 'CNY', 10000, 40, '1110', 'DEMO_SEED_V1 CNY lot', 'demo-v1-buy-cny');
  PERFORM fx_post_agent_currency_purchase(v_co, v_br, v_dubai, 'AED', 5000, 75, '1110', 'DEMO_SEED_V1 AED lot', 'demo-v1-buy-aed');
  PERFORM fx_post_agent_currency_purchase(v_co, v_br, v_usd_ag, 'USD', 2000, 280, '1110', 'DEMO_SEED_V1 USD lot', 'demo-v1-buy-usd');

  -- A Ali CNY
  v_rid := fx_create_remittance(v_br, v_ali, 'DEMO Receiver Ali', NULL, 'Demo City', 'PK', v_china,
    'PKR', 164000, 'CNY', 4000, 41, 0, 'DEMO_SEED_V1 Ali', 'customer_paid', true);
  UPDATE fx_remittances SET payout_funding_mode = 'agent_owned_balance', notes = 'DEMO_SEED_V1 Ali' WHERE id = v_rid;
  PERFORM fx_record_remittance_customer_payment(v_rid, 100000, '1110', 'DEMO_SEED_V1', 'demo-v1-ali-pay1');
  PERFORM fx_record_remittance_customer_payment(v_rid, 64000, '1110', 'DEMO_SEED_V1', 'demo-v1-ali-pay2');
  PERFORM fx_send_remittance_to_agent(v_rid, v_china, 'DEMO_SEED_V1 reserve');
  PERFORM fx_agent_balance_reserve(v_co, v_br, v_china, 'CNY', 4000);
  UPDATE fx_remittances SET reserved_payout_amount = 4000, reserved_payout_currency = 'CNY' WHERE id = v_rid;
  PERFORM fx_confirm_remittance_payout_ex(v_rid, 1500, 'agent_owned_balance', NULL, 'DEMO_SEED_V1 partial', NULL, 'demo-v1-ali-pay1500');

  -- B Sara AED complete
  v_rid := fx_create_remittance(v_br, v_sara, 'DEMO Receiver Sara', NULL, 'Demo City', 'AE', v_dubai,
    'PKR', 77000, 'AED', 1000, 77, 0, 'DEMO_SEED_V1 Sara', 'customer_paid', true);
  UPDATE fx_remittances SET payout_funding_mode = 'agent_owned_balance' WHERE id = v_rid;
  PERFORM fx_record_remittance_customer_payment(v_rid, 77000, '1110', 'DEMO_SEED_V1', 'demo-v1-sara-pay');
  PERFORM fx_send_remittance_to_agent(v_rid, v_dubai, 'DEMO_SEED_V1');
  PERFORM fx_agent_balance_reserve(v_co, v_br, v_dubai, 'AED', 1000);
  UPDATE fx_remittances SET reserved_payout_amount = 1000, reserved_payout_currency = 'AED' WHERE id = v_rid;
  PERFORM fx_confirm_remittance_payout_ex(v_rid, 1000, 'agent_owned_balance', NULL, 'DEMO_SEED_V1 full', NULL, 'demo-v1-sara-out');

  -- C Bilal USD partial pay only
  v_rid := fx_create_remittance(v_br, v_bilal, 'DEMO Receiver Bilal', NULL, 'Demo City', 'US', v_usd_ag,
    'PKR', 141500, 'USD', 500, 283, 0, 'DEMO_SEED_V1 Bilal', 'customer_paid', true);
  PERFORM fx_record_remittance_customer_payment(v_rid, 50000, '1110', 'DEMO_SEED_V1', 'demo-v1-bilal-pay');

  -- D Hina agent-funded
  v_rid := fx_create_remittance(v_br, v_hina, 'DEMO Receiver Hina', NULL, 'Demo City', 'AE', v_dubai,
    'PKR', 38000, 'AED', 500, 76, 0, 'DEMO_SEED_V1 Hina agent-funded', 'customer_paid', true);
  UPDATE fx_remittances SET payout_funding_mode = 'agent_credit_payable' WHERE id = v_rid;
  PERFORM fx_record_remittance_customer_payment(v_rid, 38000, '1110', 'DEMO_SEED_V1', 'demo-v1-hina-pay');
  PERFORM fx_send_remittance_to_agent(v_rid, v_dubai, 'DEMO_SEED_V1 agent-funded');
  PERFORM fx_confirm_remittance_payout_ex(v_rid, 500, 'agent_credit_payable', NULL, 'DEMO_SEED_V1 funded', NULL, 'demo-v1-hina-out');
  PERFORM fx_settle_remittance_agent(v_rid, 20000, '1110', 'DEMO_SEED_V1 settle', 'demo-v1-hina-settle');

  PERFORM set_config('fx_seed.active', '0', true);

  -- Control totals
  SELECT COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0) INTO v_cash
  FROM fx_journal_lines jl
  JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
  JOIN fx_accounts a ON a.id = jl.account_id
  WHERE je.company_id = v_co AND je.is_void IS NOT TRUE AND a.code = '1110';

  SELECT owned_amount, reserved_amount, owned_amount - reserved_amount
    INTO v_cny_owned, v_cny_res, v_cny_avail
  FROM fx_agent_currency_balances WHERE company_id = v_co AND agent_party_id = v_china AND currency_code = 'CNY';
  SELECT owned_amount INTO v_aed_owned FROM fx_agent_currency_balances WHERE company_id = v_co AND agent_party_id = v_dubai AND currency_code = 'AED';
  SELECT owned_amount INTO v_usd_owned FROM fx_agent_currency_balances WHERE company_id = v_co AND agent_party_id = v_usd_ag AND currency_code = 'USD';

  SELECT COALESCE(SUM(jl.credit_pkr - jl.debit_pkr), 0) INTO v_advances
  FROM fx_journal_lines jl JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
  JOIN fx_accounts a ON a.id = jl.account_id
  WHERE je.company_id = v_co AND NOT je.is_void AND a.code = '2350';

  SELECT COALESCE(SUM(payable_pkr), 0) INTO v_payable FROM fx_agent_currency_balances WHERE company_id = v_co;

  SELECT COALESCE(SUM(jl.credit_pkr - jl.debit_pkr), 0) INTO v_profit
  FROM fx_journal_lines jl JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
  JOIN fx_accounts a ON a.id = jl.account_id
  WHERE je.company_id = v_co AND NOT je.is_void AND a.code = '4100';

  IF ABS(v_cash - 974000) > 1 THEN RAISE EXCEPTION 'PKR cash expected 974000 got %', v_cash; END IF;
  IF ABS(v_cny_owned - 8500) > 0.01 OR ABS(v_cny_res - 2500) > 0.01 OR ABS(v_cny_avail - 6000) > 0.01 THEN
    RAISE EXCEPTION 'CNY owned/res/avail expected 8500/2500/6000 got %/%/%', v_cny_owned, v_cny_res, v_cny_avail;
  END IF;
  IF ABS(v_aed_owned - 4000) > 0.01 THEN RAISE EXCEPTION 'AED owned expected 4000 got %', v_aed_owned; END IF;
  IF ABS(v_usd_owned - 2000) > 0.01 THEN RAISE EXCEPTION 'USD owned expected 2000 got %', v_usd_owned; END IF;
  IF ABS(v_advances - 152500) > 1 THEN RAISE EXCEPTION 'Advances expected 152500 got %', v_advances; END IF;
  IF ABS(v_payable - 18000) > 1 THEN RAISE EXCEPTION 'Agent payable expected 18000 got %', v_payable; END IF;
  IF ABS(v_profit - 3500) > 1 THEN RAISE EXCEPTION 'Profit expected 3500 got %', v_profit; END IF;

  -- Isolation: no rows leaked to NDMFX
  SELECT COUNT(*) INTO v_extra FROM fx_transactions t
  JOIN fx_companies c ON c.id = t.company_id
  WHERE c.code = 'NDMFX' AND t.description LIKE 'DEMO_SEED_V1%';
  IF v_extra > 0 THEN RAISE EXCEPTION 'Demo seed leaked into NDMFX'; END IF;

  v_result := jsonb_build_object(
    'seed_version', v_seed,
    'company_id', v_co,
    'company_code', 'AM_DEMO',
    'branch_id', v_br,
    'pkr_cash', v_cash,
    'cny_owned', v_cny_owned,
    'cny_reserved', v_cny_res,
    'cny_available', v_cny_avail,
    'aed_owned', v_aed_owned,
    'usd_owned', v_usd_owned,
    'customer_advances', v_advances,
    'agent_payable', v_payable,
    'realized_profit', v_profit,
    'granted_email', p_grant_user_email
  );

  INSERT INTO fx_demo_seed_batches (seed_version, company_id, actor_user_id, result_json)
  VALUES (v_seed, v_co, v_actor, v_result);

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION fx_post_agent_currency_purchase(UUID,UUID,UUID,TEXT,NUMERIC,NUMERIC,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION fx_confirm_remittance_payout_ex(UUID,NUMERIC,TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION fx_seed_am_demo_v1(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_post_agent_currency_purchase(UUID,UUID,UUID,TEXT,NUMERIC,NUMERIC,TEXT,TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_confirm_remittance_payout_ex(UUID,NUMERIC,TEXT,TEXT,TEXT,TEXT,TEXT) TO authenticated;
-- Seed only via postgres/service_role on server (not authenticated clients)
GRANT EXECUTE ON FUNCTION fx_seed_am_demo_v1(TEXT) TO service_role;
