-- X_training_third_party_and_funding.sql
-- Narrow AM additive RPCs for training scenarios:
-- 1) Cashless client→agent third-party deal payment (no owned-bank touch)
-- 2) Agent currency purchase with cash | credit | advance funding
-- 3) Helper settlement send for agent payable reduction
-- AM_DEMO-safe; does not alter ERP objects. Idempotent via fx_client_operations.

-- ---------------------------------------------------------------------------
-- Recognize agent_source PKR payable on GL + agent balance book
-- Dr 1170 Delivery Clearing / Cr 2100 Agent Payable
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_recognize_agent_source_payable(
  p_leg_id UUID,
  p_client_operation_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_leg fx_deal_legs;
  v_deal fx_deals;
  v_tx UUID;
  v_existing UUID;
  v_clearing UUID;
  v_payable UUID;
  v_amt NUMERIC;
  v_row fx_agent_currency_balances;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_leg FROM fx_deal_legs WHERE id = p_leg_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Leg not found'; END IF;
  IF v_leg.leg_type <> 'agent_source'::fx_deal_leg_type THEN
    RAISE EXCEPTION 'Leg must be agent_source';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = v_leg.deal_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  IF p_client_operation_id IS NOT NULL THEN
    SELECT entity_id INTO v_existing
    FROM fx_client_operations
    WHERE company_id = v_deal.company_id AND operation_key = p_client_operation_id;
    IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;
  END IF;

  v_amt := COALESCE(v_leg.pay_amount, 0);
  IF v_amt <= 0 THEN
    RAISE EXCEPTION 'agent_source pay_amount must be positive to recognize payable';
  END IF;
  IF v_leg.counterparty_party_id IS NULL THEN
    RAISE EXCEPTION 'agent_source requires counterparty agent';
  END IF;

  PERFORM fx_ensure_deal_coa(v_deal.company_id);
  v_clearing := fx_account_id_by_code(v_deal.company_id, '1170');
  v_payable := fx_account_id_by_code(v_deal.company_id, '2100');
  IF v_clearing IS NULL OR v_payable IS NULL THEN
    RAISE EXCEPTION 'Missing 1170/2100 for payable recognition';
  END IF;

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, leg_id, created_by
  ) VALUES (
    v_deal.company_id, v_deal.branch_id, 'account_transfer', 'draft', CURRENT_DATE,
    v_leg.counterparty_party_id, 'PKR', v_amt, 1, v_amt,
    'AM recognize agent_source payable — deal ' || COALESCE(v_deal.deal_no, v_deal.id::text),
    v_deal.id, v_leg.id, auth.uid()
  ) RETURNING id INTO v_tx;

  INSERT INTO fx_transaction_lines (
    transaction_id, line_no, account_id, currency_code,
    foreign_amount, rate_used, debit_pkr, credit_pkr, memo
  ) VALUES
    (v_tx, 1, v_clearing, 'PKR', v_amt, 1, v_amt, 0, 'Delivery clearing (sourced FX cost)'),
    (v_tx, 2, v_payable, 'PKR', v_amt, 1, 0, v_amt, 'Agent payable for source');

  PERFORM fx_post_transaction(v_tx);

  v_row := fx_agent_balance_ensure(
    v_deal.company_id, v_deal.branch_id, v_leg.counterparty_party_id,
    COALESCE(fx_normalize_currency_code(v_leg.receive_currency), 'CNY')
  );
  UPDATE fx_agent_currency_balances
  SET payable_pkr = COALESCE(payable_pkr, 0) + v_amt, updated_at = NOW()
  WHERE id = v_row.id;

  IF p_client_operation_id IS NOT NULL THEN
    INSERT INTO fx_client_operations (
      company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
    ) VALUES (
      v_deal.company_id, p_client_operation_id, 'recognize_agent_source_payable',
      'fx_transaction', v_tx,
      jsonb_build_object('leg_id', p_leg_id, 'amount_pkr', v_amt),
      auth.uid()
    ) ON CONFLICT (company_id, operation_key) DO NOTHING;
  END IF;

  RETURN v_tx;
END;
$$;

REVOKE ALL ON FUNCTION fx_recognize_agent_source_payable(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_recognize_agent_source_payable(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_recognize_agent_source_payable(UUID, TEXT) TO service_role;

-- ---------------------------------------------------------------------------
-- Post inventory when currency_receipt completes (Dr inv / Cr 1170)
-- Increases agent owned_amount; does not touch owned PKR banks.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_post_currency_receipt_inventory(
  p_receipt_leg_id UUID,
  p_client_operation_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_leg fx_deal_legs;
  v_parent fx_deal_legs;
  v_deal fx_deals;
  v_tx UUID;
  v_existing UUID;
  v_inv UUID;
  v_clearing UUID;
  v_cc TEXT;
  v_amt NUMERIC;
  v_pkr NUMERIC;
  v_rate NUMERIC;
  v_row fx_agent_currency_balances;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_leg FROM fx_deal_legs WHERE id = p_receipt_leg_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Receipt leg not found'; END IF;
  IF v_leg.leg_type <> 'currency_receipt'::fx_deal_leg_type THEN
    RAISE EXCEPTION 'Leg must be currency_receipt';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = v_leg.deal_id FOR UPDATE;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;

  IF p_client_operation_id IS NOT NULL THEN
    SELECT entity_id INTO v_existing
    FROM fx_client_operations
    WHERE company_id = v_deal.company_id AND operation_key = p_client_operation_id;
    IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;
  END IF;

  SELECT * INTO v_parent FROM fx_deal_legs WHERE id = v_leg.parent_leg_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Parent agent_source missing'; END IF;

  v_cc := fx_normalize_currency_code(COALESCE(v_leg.receive_currency, v_parent.receive_currency));
  v_amt := COALESCE(v_leg.receive_amount, 0);
  IF v_amt <= 0 THEN RAISE EXCEPTION 'Receipt amount must be positive'; END IF;

  v_rate := COALESCE(NULLIF(v_parent.rate_used, 0), NULLIF(v_parent.pay_amount / NULLIF(v_parent.receive_amount, 0), 0), 1);
  v_pkr := ROUND(v_amt * v_rate, 8);

  v_inv := fx_account_id_by_code(v_deal.company_id, CASE v_cc
    WHEN 'USD' THEN '1120' WHEN 'AED' THEN '1130' WHEN 'CNY' THEN '1140' ELSE '1120' END);
  v_clearing := fx_account_id_by_code(v_deal.company_id, '1170');
  IF v_inv IS NULL OR v_clearing IS NULL THEN
    RAISE EXCEPTION 'Missing inventory/clearing accounts';
  END IF;

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, leg_id, created_by
  ) VALUES (
    v_deal.company_id, v_deal.branch_id, 'currency_buy', 'draft', CURRENT_DATE,
    COALESCE(v_leg.counterparty_party_id, v_parent.counterparty_party_id),
    v_cc, v_amt, v_rate, v_pkr,
    'AM custody receipt inventory — deal ' || COALESCE(v_deal.deal_no, v_deal.id::text),
    v_deal.id, v_leg.id, auth.uid()
  ) RETURNING id INTO v_tx;

  INSERT INTO fx_transaction_lines (
    transaction_id, line_no, account_id, currency_code,
    foreign_amount, rate_used, debit_pkr, credit_pkr, memo
  ) VALUES
    (v_tx, 1, v_inv, v_cc, v_amt, v_rate, v_pkr, 0, 'FX held with agent (custody)'),
    (v_tx, 2, v_clearing, 'PKR', v_pkr, 1, 0, v_pkr, 'Clear delivery clearing');

  PERFORM fx_post_transaction(v_tx);

  v_row := fx_agent_balance_ensure(
    v_deal.company_id, v_deal.branch_id,
    COALESCE(v_leg.counterparty_party_id, v_parent.counterparty_party_id),
    v_cc
  );
  UPDATE fx_agent_currency_balances SET
    owned_amount = owned_amount + v_amt,
    carrying_cost_pkr = COALESCE(carrying_cost_pkr, 0) + v_pkr,
    updated_at = NOW()
  WHERE id = v_row.id;

  -- Reserve full receipt for this deal sale commitment (available = owned - reserved)
  PERFORM fx_agent_balance_reserve(
    v_deal.company_id, v_deal.branch_id,
    COALESCE(v_leg.counterparty_party_id, v_parent.counterparty_party_id),
    v_cc, v_amt
  );

  IF p_client_operation_id IS NOT NULL THEN
    INSERT INTO fx_client_operations (
      company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
    ) VALUES (
      v_deal.company_id, p_client_operation_id, 'currency_receipt_inventory',
      'fx_transaction', v_tx,
      jsonb_build_object('leg_id', p_receipt_leg_id, 'amount', v_amt, 'pkr', v_pkr),
      auth.uid()
    ) ON CONFLICT (company_id, operation_key) DO NOTHING;
  END IF;

  RETURN v_tx;
END;
$$;

REVOKE ALL ON FUNCTION fx_post_currency_receipt_inventory(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_post_currency_receipt_inventory(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_post_currency_receipt_inventory(UUID, TEXT) TO service_role;

-- ---------------------------------------------------------------------------
-- Third-party client→agent payment (no owned bank movement)
-- Dr 2100 Agent Payable / Cr 1160 Customer Advances
-- Updates deal customer_paid exactly once; reduces agent payable_pkr.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_record_deal_third_party_payment(
  p_deal_id UUID,
  p_amount_pkr NUMERIC,
  p_agent_party_id UUID,
  p_agent_source_leg_id UUID DEFAULT NULL,
  p_external_bank_label TEXT DEFAULT NULL,
  p_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_client_operation_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_tx UUID;
  v_existing UUID;
  v_advances UUID;
  v_payable UUID;
  v_outstanding NUMERIC;
  v_source fx_deal_legs;
  v_leg_no INT;
  v_cust_leg UUID;
  v_agent_leg UUID;
  v_row fx_agent_currency_balances;
  v_memo TEXT;
  v_pkr_allocated NUMERIC;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;
  IF p_amount_pkr IS NULL OR p_amount_pkr <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;
  IF p_agent_party_id IS NULL THEN
    RAISE EXCEPTION 'Agent party required';
  END IF;

  IF p_client_operation_id IS NOT NULL THEN
    SELECT entity_id INTO v_existing
    FROM fx_client_operations
    WHERE company_id = v_deal.company_id AND operation_key = p_client_operation_id;
    IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;
  END IF;

  PERFORM fx_ensure_deal_coa(v_deal.company_id);
  v_advances := fx_account_id_by_code(v_deal.company_id, '1160');
  v_payable := fx_account_id_by_code(v_deal.company_id, '2100');
  IF v_advances IS NULL OR v_payable IS NULL THEN
    RAISE EXCEPTION 'Missing 1160/2100 for third-party payment';
  END IF;

  v_outstanding := GREATEST(0, COALESCE(v_deal.customer_payable_pkr, 0) - COALESCE(v_deal.customer_paid_pkr, 0));
  IF p_amount_pkr > v_outstanding + 0.00000001 THEN
    RAISE EXCEPTION 'Third-party payment % exceeds customer outstanding %',
      p_amount_pkr, v_outstanding;
  END IF;

  IF p_agent_source_leg_id IS NOT NULL THEN
    SELECT * INTO v_source FROM fx_deal_legs WHERE id = p_agent_source_leg_id FOR UPDATE;
  ELSE
    SELECT * INTO v_source
    FROM fx_deal_legs
    WHERE deal_id = p_deal_id
      AND leg_type = 'agent_source'::fx_deal_leg_type
      AND counterparty_party_id = p_agent_party_id
    ORDER BY leg_no
    LIMIT 1
    FOR UPDATE;
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No agent_source leg for agent on this deal';
  END IF;
  IF v_source.counterparty_party_id IS DISTINCT FROM p_agent_party_id THEN
    RAISE EXCEPTION 'agent_source counterparty mismatch';
  END IF;

  -- PKR already allocated to this source via completed agent_payment legs
  -- (agent_source.paid_amount tracks FX receipt qty — do NOT overwrite with PKR).
  SELECT COALESCE(SUM(pay_amount), 0) INTO v_pkr_allocated
  FROM fx_deal_legs
  WHERE parent_leg_id = v_source.id
    AND leg_type = 'agent_payment'::fx_deal_leg_type
    AND status = 'completed'::fx_deal_leg_status;

  IF v_pkr_allocated + p_amount_pkr
       > COALESCE(v_source.pay_amount, 0) + 0.00000001 THEN
    RAISE EXCEPTION
      'Third-party amount exceeds remaining agent source PKR payable on leg (allocated % of %)',
      v_pkr_allocated, v_source.pay_amount;
  END IF;

  v_memo := trim(both FROM concat_ws(' | ',
    COALESCE(p_notes, 'Third-party client→agent payment'),
    CASE WHEN p_reference IS NOT NULL THEN 'Ref: ' || p_reference ELSE NULL END,
    CASE WHEN p_external_bank_label IS NOT NULL THEN 'External: ' || p_external_bank_label ELSE NULL END,
    'NO owned-bank movement'
  ));

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, created_by
  ) VALUES (
    v_deal.company_id, v_deal.branch_id, 'settlement_receive', 'draft', CURRENT_DATE,
    v_deal.customer_party_id, 'PKR', p_amount_pkr, 1, p_amount_pkr,
    v_memo, p_deal_id, auth.uid()
  ) RETURNING id INTO v_tx;

  -- Cashless: Dr agent payable / Cr customer advances (mirrors cash receipt credit side)
  INSERT INTO fx_transaction_lines (
    transaction_id, line_no, account_id, currency_code,
    foreign_amount, rate_used, debit_pkr, credit_pkr, memo
  ) VALUES
    (v_tx, 1, v_payable, 'PKR', p_amount_pkr, 1, p_amount_pkr, 0,
      'Allocate to agent payable (client paid agent directly)'),
    (v_tx, 2, v_advances, 'PKR', p_amount_pkr, 1, 0, p_amount_pkr,
      'Customer advance via third-party');

  PERFORM fx_post_transaction(v_tx);

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;
  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    pay_currency, pay_amount, paid_amount, remaining_amount,
    linked_transaction_id, notes, completed_at
  ) VALUES (
    p_deal_id, v_leg_no, 'customer_payment'::fx_deal_leg_type, 'completed'::fx_deal_leg_status,
    v_deal.customer_party_id,
    'PKR', p_amount_pkr, p_amount_pkr, 0,
    v_tx, v_memo || ' [third_party]', NOW()
  ) RETURNING id INTO v_cust_leg;

  v_leg_no := v_leg_no + 1;
  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    pay_currency, pay_amount, paid_amount, remaining_amount,
    parent_leg_id, linked_transaction_id, notes, completed_at
  ) VALUES (
    p_deal_id, v_leg_no, 'agent_payment'::fx_deal_leg_type, 'completed'::fx_deal_leg_status,
    p_agent_party_id,
    'PKR', p_amount_pkr, p_amount_pkr, 0,
    v_source.id, v_tx, v_memo || ' [allocated_to_source]', NOW()
  ) RETURNING id INTO v_agent_leg;

  -- Do not mutate agent_source.paid_amount (FX qty). PKR progress = SUM(agent_payment).
  UPDATE fx_transactions SET leg_id = v_cust_leg WHERE id = v_tx;

  UPDATE fx_deals SET
    customer_paid_pkr = customer_paid_pkr + p_amount_pkr,
    customer_receivable_pkr = GREATEST(0, customer_payable_pkr - (customer_paid_pkr + p_amount_pkr)),
    status = (CASE
      WHEN customer_paid_pkr + p_amount_pkr >= customer_payable_pkr THEN 'customer_paid'
      WHEN customer_paid_pkr + p_amount_pkr > 0 THEN 'customer_partially_paid'
      ELSE status::text
    END)::fx_deal_status,
    updated_at = NOW()
  WHERE id = p_deal_id;

  v_row := fx_agent_balance_ensure(
    v_deal.company_id, v_deal.branch_id, p_agent_party_id,
    COALESCE(fx_normalize_currency_code(v_source.receive_currency), 'PKR')
  );
  UPDATE fx_agent_currency_balances SET
    payable_pkr = GREATEST(0, COALESCE(payable_pkr, 0) - p_amount_pkr),
    updated_at = NOW()
  WHERE id = v_row.id;

  IF p_client_operation_id IS NOT NULL THEN
    INSERT INTO fx_client_operations (
      company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
    ) VALUES (
      v_deal.company_id, p_client_operation_id, 'deal_third_party_payment',
      'fx_transaction', v_tx,
      jsonb_build_object(
        'deal_id', p_deal_id,
        'amount_pkr', p_amount_pkr,
        'agent_party_id', p_agent_party_id,
        'source_leg_id', v_source.id,
        'customer_leg_id', v_cust_leg,
        'agent_leg_id', v_agent_leg,
        'external_bank_label', p_external_bank_label,
        'reference', p_reference,
        'owned_bank_touched', false
      ),
      auth.uid()
    ) ON CONFLICT (company_id, operation_key) DO NOTHING;
  END IF;

  RETURN v_tx;
END;
$$;

REVOKE ALL ON FUNCTION fx_record_deal_third_party_payment(UUID, NUMERIC, UUID, UUID, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_record_deal_third_party_payment(UUID, NUMERIC, UUID, UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_record_deal_third_party_payment(UUID, NUMERIC, UUID, UUID, TEXT, TEXT, TEXT, TEXT) TO service_role;

-- ---------------------------------------------------------------------------
-- Funded agent currency purchase: cash | credit | advance
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_post_agent_currency_purchase_funded(
  p_company_id UUID,
  p_branch_id UUID,
  p_agent_party_id UUID,
  p_currency TEXT,
  p_foreign_amount NUMERIC,
  p_rate_pkr NUMERIC,
  p_funding_mode TEXT DEFAULT 'cash',
  p_settle_account_code TEXT DEFAULT NULL,
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
  v_settle UUID;
  v_inv UUID;
  v_pkr NUMERIC;
  v_cc TEXT := upper(p_currency);
  v_mode TEXT := lower(COALESCE(NULLIF(btrim(p_funding_mode), ''), 'cash'));
  v_existing UUID;
  v_row fx_agent_currency_balances;
  v_code TEXT;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF NOT fx_same_company(p_company_id) OR NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized company/branch';
  END IF;
  IF p_foreign_amount <= 0 OR p_rate_pkr <= 0 THEN RAISE EXCEPTION 'Amount/rate must be positive'; END IF;
  IF v_mode NOT IN ('cash', 'credit', 'advance') THEN
    RAISE EXCEPTION 'funding_mode must be cash|credit|advance';
  END IF;
  v_pkr := ROUND(p_foreign_amount * p_rate_pkr, 8);

  IF p_client_operation_id IS NOT NULL THEN
    SELECT (result_json->>'transaction_id')::uuid INTO v_existing
    FROM fx_client_operations
    WHERE company_id = p_company_id AND operation_key = p_client_operation_id;
    IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;
  END IF;

  v_code := CASE v_mode
    WHEN 'credit' THEN '2100'
    WHEN 'advance' THEN COALESCE(NULLIF(btrim(p_settle_account_code), ''), '1180')
    ELSE COALESCE(NULLIF(btrim(p_settle_account_code), ''), '1110')
  END;
  v_settle := fx_account_id_by_code(p_company_id, v_code);
  v_inv := COALESCE(
    fx_account_id_by_code(p_company_id, CASE v_cc
      WHEN 'USD' THEN '1120' WHEN 'AED' THEN '1130' WHEN 'CNY' THEN '1140' ELSE '1120' END),
    fx_account_id_by_code(p_company_id, '1120')
  );
  IF v_settle IS NULL OR v_inv IS NULL THEN
    RAISE EXCEPTION 'Missing settle/inventory account for mode % code %', v_mode, v_code;
  END IF;

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, created_by
  ) VALUES (
    p_company_id, p_branch_id, 'currency_buy', 'draft', CURRENT_DATE,
    p_agent_party_id, v_cc, p_foreign_amount, p_rate_pkr, v_pkr,
    COALESCE(p_notes, 'Agent-held purchase ' || v_cc || ' (' || v_mode || ')'),
    auth.uid()
  ) RETURNING id INTO v_tx;

  INSERT INTO fx_transaction_lines (
    transaction_id, line_no, account_id, currency_code,
    foreign_amount, rate_used, debit_pkr, credit_pkr, memo
  ) VALUES
    (v_tx, 1, v_inv, v_cc, p_foreign_amount, p_rate_pkr, v_pkr, 0, 'Currency held by agent'),
    (v_tx, 2, v_settle, 'PKR', v_pkr, 1, 0, v_pkr,
      CASE v_mode
        WHEN 'credit' THEN 'Agent payable (credit purchase)'
        WHEN 'advance' THEN 'Apply agent PKR advance'
        ELSE 'PKR paid for purchase'
      END);

  PERFORM fx_post_transaction(v_tx);

  v_row := fx_agent_balance_ensure(p_company_id, p_branch_id, p_agent_party_id, v_cc);
  UPDATE fx_agent_currency_balances SET
    owned_amount = owned_amount + p_foreign_amount,
    carrying_cost_pkr = COALESCE(carrying_cost_pkr, 0) + v_pkr,
    payable_pkr = CASE
      WHEN v_mode = 'credit' THEN COALESCE(payable_pkr, 0) + v_pkr
      ELSE payable_pkr
    END,
    updated_at = NOW()
  WHERE id = v_row.id;

  IF p_client_operation_id IS NOT NULL THEN
    INSERT INTO fx_client_operations (
      company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
    ) VALUES (
      p_company_id, p_client_operation_id, 'agent_currency_purchase_funded',
      'fx_transaction', v_tx,
      jsonb_build_object(
        'transaction_id', v_tx, 'pkr', v_pkr, 'funding_mode', v_mode,
        'settle_account_code', v_code
      ),
      auth.uid()
    ) ON CONFLICT (company_id, operation_key) DO NOTHING;
  END IF;
  RETURN v_tx;
END;
$$;

REVOKE ALL ON FUNCTION fx_post_agent_currency_purchase_funded(UUID,UUID,UUID,TEXT,NUMERIC,NUMERIC,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_post_agent_currency_purchase_funded(UUID,UUID,UUID,TEXT,NUMERIC,NUMERIC,TEXT,TEXT,TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_post_agent_currency_purchase_funded(UUID,UUID,UUID,TEXT,NUMERIC,NUMERIC,TEXT,TEXT,TEXT,TEXT) TO service_role;

-- ---------------------------------------------------------------------------
-- Settlement send helper (Dr settle_code / Cr cash_code) with optional deal leg
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_post_settlement_send(
  p_company_id UUID,
  p_branch_id UUID,
  p_party_id UUID,
  p_amount_pkr NUMERIC,
  p_cash_account_code TEXT,
  p_settle_account_code TEXT DEFAULT '2100',
  p_deal_id UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_client_operation_id TEXT DEFAULT NULL,
  p_reduce_agent_payable BOOLEAN DEFAULT TRUE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx UUID;
  v_existing UUID;
  v_cash UUID;
  v_settle UUID;
  v_leg_no INT;
  v_ccy TEXT := 'PKR';
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF NOT fx_same_company(p_company_id) OR NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized company/branch';
  END IF;
  IF p_amount_pkr IS NULL OR p_amount_pkr <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  IF p_client_operation_id IS NOT NULL THEN
    SELECT entity_id INTO v_existing
    FROM fx_client_operations
    WHERE company_id = p_company_id AND operation_key = p_client_operation_id;
    IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;
  END IF;

  v_cash := fx_account_id_by_code(p_company_id, p_cash_account_code);
  v_settle := fx_account_id_by_code(p_company_id, COALESCE(p_settle_account_code, '2100'));
  IF v_cash IS NULL OR v_settle IS NULL THEN
    RAISE EXCEPTION 'Missing cash/settle account';
  END IF;

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, created_by
  ) VALUES (
    p_company_id, p_branch_id, 'settlement_send', 'draft', CURRENT_DATE,
    p_party_id, v_ccy, p_amount_pkr, 1, p_amount_pkr,
    COALESCE(p_notes, 'Settlement send'),
    p_deal_id, auth.uid()
  ) RETURNING id INTO v_tx;

  INSERT INTO fx_transaction_lines (
    transaction_id, line_no, account_id, currency_code,
    foreign_amount, rate_used, debit_pkr, credit_pkr, memo
  ) VALUES
    (v_tx, 1, v_settle, v_ccy, p_amount_pkr, 1, p_amount_pkr, 0, 'Settlement control'),
    (v_tx, 2, v_cash, v_ccy, p_amount_pkr, 1, 0, p_amount_pkr, 'Cash/bank out');

  PERFORM fx_post_transaction(v_tx);

  IF p_deal_id IS NOT NULL THEN
    SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;
    INSERT INTO fx_deal_legs (
      deal_id, leg_no, leg_type, status, counterparty_party_id,
      pay_currency, pay_amount, paid_amount, remaining_amount,
      linked_transaction_id, notes, completed_at
    ) VALUES (
      p_deal_id, v_leg_no, 'agent_payment'::fx_deal_leg_type, 'completed'::fx_deal_leg_status,
      p_party_id, 'PKR', p_amount_pkr, p_amount_pkr, 0, v_tx, p_notes, NOW()
    );
  END IF;

  IF p_reduce_agent_payable AND COALESCE(p_settle_account_code, '2100') = '2100' THEN
    UPDATE fx_agent_currency_balances SET
      payable_pkr = GREATEST(0, COALESCE(payable_pkr, 0) - p_amount_pkr),
      updated_at = NOW()
    WHERE company_id = p_company_id
      AND branch_id = p_branch_id
      AND agent_party_id = p_party_id;
  END IF;

  IF p_client_operation_id IS NOT NULL THEN
    INSERT INTO fx_client_operations (
      company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
    ) VALUES (
      p_company_id, p_client_operation_id, 'settlement_send', 'fx_transaction', v_tx,
      jsonb_build_object('amount_pkr', p_amount_pkr, 'cash_code', p_cash_account_code),
      auth.uid()
    ) ON CONFLICT (company_id, operation_key) DO NOTHING;
  END IF;

  RETURN v_tx;
END;
$$;

REVOKE ALL ON FUNCTION fx_post_settlement_send(UUID,UUID,UUID,NUMERIC,TEXT,TEXT,UUID,TEXT,TEXT,BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_post_settlement_send(UUID,UUID,UUID,NUMERIC,TEXT,TEXT,UUID,TEXT,TEXT,BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_post_settlement_send(UUID,UUID,UUID,NUMERIC,TEXT,TEXT,UUID,TEXT,TEXT,BOOLEAN) TO service_role;
