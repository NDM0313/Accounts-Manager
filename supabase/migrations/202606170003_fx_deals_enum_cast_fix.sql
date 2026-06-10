-- FX Deals: explicit enum casts for deal RPCs (fixes PostgreSQL 42804)
-- Replaces fx_book_customer_deal, fx_record_deal_customer_payment,
-- fx_add_deal_leg, fx_add_settlement_link, fx_confirm_deal_delivery
-- ---------------------------------------------------------------------------
-- fx_book_customer_deal
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_book_customer_deal(
  p_branch_id UUID,
  p_customer_party_id UUID,
  p_sell_currency_code TEXT,
  p_sell_amount NUMERIC,
  p_sale_rate_pkr NUMERIC,
  p_customer_paid_now_pkr NUMERIC DEFAULT 0,
  p_delivery_method fx_delivery_method DEFAULT 'later',
  p_allow_short_position BOOLEAN DEFAULT FALSE,
  p_notes TEXT DEFAULT NULL,
  p_auto_source BOOLEAN DEFAULT TRUE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_deal_id UUID;
  v_leg_id UUID;
  v_payable NUMERIC(20, 8);
  v_currency TEXT;
  v_available NUMERIC;
  v_required NUMERIC;
  v_status fx_deal_status;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_profile FROM fx_current_profile();
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  v_currency := fx_normalize_currency_code(p_sell_currency_code);
  v_payable := ROUND(p_sell_amount * p_sale_rate_pkr, 8);

  INSERT INTO fx_deals (
    company_id, branch_id, customer_party_id,
    sell_currency_code, sell_amount, sale_rate_pkr,
    customer_payable_pkr, customer_paid_pkr, customer_receivable_pkr,
    delivery_method, status, allow_short_position, notes,
    booked_at, created_by
  ) VALUES (
    v_profile.company_id, p_branch_id, p_customer_party_id,
    v_currency, p_sell_amount, p_sale_rate_pkr,
    v_payable, COALESCE(p_customer_paid_now_pkr, 0),
    GREATEST(0, v_payable - COALESCE(p_customer_paid_now_pkr, 0)),
    p_delivery_method,
    (CASE
      WHEN COALESCE(p_customer_paid_now_pkr, 0) >= v_payable THEN 'customer_paid'
      WHEN COALESCE(p_customer_paid_now_pkr, 0) > 0 THEN 'customer_partially_paid'
      ELSE 'booked'
    END)::fx_deal_status,
    COALESCE(p_allow_short_position, FALSE),
    p_notes,
    NOW(), auth.uid()
  )
  RETURNING id INTO v_deal_id;

  UPDATE fx_deals SET deal_no = fx_generate_deal_no(p_branch_id) WHERE id = v_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    remaining_amount, notes
  ) VALUES (
    v_deal_id, 1, 'customer_order'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, p_customer_party_id,
    v_currency, p_sell_amount, 'PKR', v_payable, p_sale_rate_pkr,
    0, 'Customer FX order booked'
  );

  INSERT INTO fx_currency_commitments (
    deal_id, leg_id, currency_code, commitment_type, committed_amount
  ) VALUES (
    v_deal_id,
    (SELECT id FROM fx_deal_legs WHERE deal_id = v_deal_id AND leg_no = 1),
    v_currency, 'customer_sale'::fx_commitment_type, p_sell_amount
  );

  v_available := fx_deal_actual_balance(p_branch_id, v_currency) - fx_deal_open_commitment(p_branch_id, v_currency, 'customer_sale'::fx_commitment_type) + p_sell_amount;
  v_required := GREATEST(0, p_sell_amount - v_available);

  IF v_required > 0 AND p_auto_source THEN
    v_status := 'sourcing_required'::fx_deal_status;
    INSERT INTO fx_deal_legs (
      deal_id, leg_no, leg_type, status,
      receive_currency, receive_amount, remaining_amount, notes
    ) VALUES (
      v_deal_id, 2, 'sourcing_requirement'::fx_deal_leg_type, 'pending'::fx_deal_leg_status,
      v_currency, v_required, v_required,
      'Auto-created: insufficient available balance'
    );
    INSERT INTO fx_currency_commitments (
      deal_id, currency_code, commitment_type, committed_amount
    ) VALUES (
      v_deal_id, v_currency, 'sourcing_required'::fx_commitment_type, v_required
    );
    UPDATE fx_deals SET status = v_status WHERE id = v_deal_id;
  ELSIF v_required > 0 AND NOT COALESCE(p_allow_short_position, FALSE) THEN
    UPDATE fx_deals SET status = 'sourcing_required'::fx_deal_status WHERE id = v_deal_id;
  END IF;

  RETURN v_deal_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_record_deal_customer_payment — Dr PKR Cash / Cr Customer Advances
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_record_deal_customer_payment(
  p_deal_id UUID,
  p_amount_pkr NUMERIC,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_tx_id UUID;
  v_leg_no INT;
  v_leg_id UUID;
  v_pkr_cash UUID;
  v_advances UUID;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;
  IF p_amount_pkr <= 0 THEN RAISE EXCEPTION 'Payment amount must be positive'; END IF;

  v_pkr_cash := fx_account_id_by_code(v_deal.company_id, '1110');
  v_advances := fx_account_id_by_code(v_deal.company_id, '1160');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, created_by
  ) VALUES (
    v_deal.company_id, v_deal.branch_id, 'manual_journal', 'draft', CURRENT_DATE,
    v_deal.customer_party_id, 'PKR', p_amount_pkr, 1, p_amount_pkr,
    COALESCE(p_notes, 'Customer payment — deal ' || v_deal.deal_no),
    p_deal_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_pkr_cash, 'PKR', p_amount_pkr, 1, p_amount_pkr, 0, 'Customer payment received'),
    (v_tx_id, 2, v_advances, 'PKR', p_amount_pkr, 1, 0, p_amount_pkr, 'Customer advance');

  PERFORM fx_post_transaction(v_tx_id);

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    pay_currency, pay_amount, paid_amount, remaining_amount,
    linked_transaction_id, notes
  ) VALUES (
    p_deal_id, v_leg_no, 'customer_payment'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, v_deal.customer_party_id,
    'PKR', p_amount_pkr, p_amount_pkr, 0,
    v_tx_id, p_notes
  ) RETURNING id INTO v_leg_id;

  UPDATE fx_transactions SET leg_id = v_leg_id WHERE id = v_tx_id;

  UPDATE fx_deals SET
    customer_paid_pkr = customer_paid_pkr + p_amount_pkr,
    customer_receivable_pkr = GREATEST(0, customer_payable_pkr - customer_paid_pkr - p_amount_pkr),
    status = (CASE
      WHEN customer_paid_pkr + p_amount_pkr >= customer_payable_pkr THEN 'customer_paid'
      WHEN customer_paid_pkr + p_amount_pkr > 0 THEN 'customer_partially_paid'
      ELSE status::text
    END)::fx_deal_status,
    updated_at = NOW()
  WHERE id = p_deal_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_add_deal_leg — generic leg append
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_add_deal_leg(
  p_deal_id UUID,
  p_leg_type fx_deal_leg_type,
  p_counterparty_party_id UUID DEFAULT NULL,
  p_receive_currency TEXT DEFAULT NULL,
  p_receive_amount NUMERIC DEFAULT 0,
  p_pay_currency TEXT DEFAULT NULL,
  p_pay_amount NUMERIC DEFAULT 0,
  p_rate_used NUMERIC DEFAULT NULL,
  p_delivery_target fx_delivery_target DEFAULT NULL,
  p_parent_leg_id UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_leg_no INT;
  v_leg_id UUID;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    paid_amount, remaining_amount, delivery_target, parent_leg_id, notes
  ) VALUES (
    p_deal_id, v_leg_no, p_leg_type, 'pending'::fx_deal_leg_status, p_counterparty_party_id,
    CASE WHEN p_receive_currency IS NOT NULL THEN fx_normalize_currency_code(p_receive_currency) ELSE NULL END,
    COALESCE(p_receive_amount, 0),
    CASE WHEN p_pay_currency IS NOT NULL THEN fx_normalize_currency_code(p_pay_currency) ELSE NULL END,
    COALESCE(p_pay_amount, 0), p_rate_used,
    0, COALESCE(p_pay_amount, p_receive_amount, 0),
    p_delivery_target, p_parent_leg_id, p_notes
  ) RETURNING id INTO v_leg_id;

  IF p_leg_type = 'agent_source' THEN
    UPDATE fx_deals SET status = 'sourcing_in_progress'::fx_deal_status, updated_at = NOW() WHERE id = p_deal_id;
    INSERT INTO fx_currency_commitments (deal_id, leg_id, currency_code, commitment_type, committed_amount)
    VALUES (p_deal_id, v_leg_id, fx_normalize_currency_code(p_receive_currency), 'on_order_inbound'::fx_commitment_type, p_receive_amount);
  END IF;

  RETURN v_leg_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_add_settlement_link
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_add_settlement_link(
  p_deal_id UUID,
  p_from_leg_id UUID,
  p_to_leg_id UUID,
  p_link_type fx_settlement_link_type,
  p_currency_code TEXT,
  p_amount NUMERIC,
  p_proof_reference TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_deal fx_deals;
BEGIN
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  INSERT INTO fx_settlement_links (deal_id, from_leg_id, to_leg_id, link_type, currency_code, amount, proof_reference)
  VALUES (p_deal_id, p_from_leg_id, p_to_leg_id, p_link_type, fx_normalize_currency_code(p_currency_code), p_amount, p_proof_reference)
  RETURNING id INTO v_id;

  UPDATE fx_settlement_links SET status = 'completed'::fx_deal_leg_status, updated_at = NOW() WHERE id = v_id;
  RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_confirm_deal_delivery — final delivery + P/L recognition
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_confirm_deal_delivery(
  p_deal_id UUID,
  p_delivered_amount NUMERIC,
  p_delivery_target fx_delivery_target DEFAULT 'direct_to_customer',
  p_cost_basis_pkr NUMERIC DEFAULT NULL,
  p_proof_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_tx_id UUID;
  v_leg_no INT;
  v_leg_id UUID;
  v_cost NUMERIC;
  v_profit NUMERIC;
  v_foreign_cash UUID;
  v_advances UUID;
  v_receivable UUID;
  v_spread UUID;
  v_clearing UUID;
  v_line_no INT := 0;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  v_cost := COALESCE(p_cost_basis_pkr, v_deal.cost_basis_pkr, v_deal.customer_payable_pkr);
  v_profit := v_deal.customer_payable_pkr - v_cost;

  v_foreign_cash := fx_account_id_by_code(v_deal.company_id,
    CASE fx_normalize_currency_code(v_deal.sell_currency_code)
      WHEN 'PKR' THEN '1110' WHEN 'USD' THEN '1120' WHEN 'AED' THEN '1130'
      WHEN 'CNY' THEN '1140' WHEN 'SAR' THEN '1150' ELSE '1110'
    END);
  v_advances := fx_account_id_by_code(v_deal.company_id, '1160');
  v_receivable := fx_account_id_by_code(v_deal.company_id, '1190');
  v_spread := fx_account_id_by_code(v_deal.company_id, '4100');
  v_clearing := fx_account_id_by_code(v_deal.company_id, '1170');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, created_by
  ) VALUES (
    v_deal.company_id, v_deal.branch_id, 'currency_sell', 'draft', CURRENT_DATE,
    v_deal.customer_party_id, v_deal.sell_currency_code, p_delivered_amount,
    v_deal.sale_rate_pkr, v_deal.customer_payable_pkr,
    COALESCE(p_notes, 'Delivery — deal ' || v_deal.deal_no),
    p_deal_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  -- Dr Customer Advance (paid portion) + Dr Receivable (unpaid) / Cr Foreign cash at cost + Cr Spread
  IF v_deal.customer_paid_pkr > 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_advances, 'PKR', v_deal.customer_paid_pkr, 1, v_deal.customer_paid_pkr, 0, 'Clear customer advance');
  END IF;

  IF v_deal.customer_receivable_pkr > 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_receivable, 'PKR', v_deal.customer_receivable_pkr, 1, v_deal.customer_receivable_pkr, 0, 'Customer receivable');
  END IF;

  v_line_no := v_line_no + 1;
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, v_line_no, v_foreign_cash, v_deal.sell_currency_code, p_delivered_amount, v_deal.sale_rate_pkr, 0, v_cost, 'RMB delivered at cost');

  IF v_profit <> 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_spread, 'PKR', ABS(v_profit), 1, CASE WHEN v_profit < 0 THEN ABS(v_profit) ELSE 0 END, CASE WHEN v_profit > 0 THEN v_profit ELSE 0 END, 'FX spread income');
  END IF;

  PERFORM fx_post_transaction(v_tx_id);

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;
  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, delivery_target,
    linked_transaction_id, proof_reference, notes, completed_at
  ) VALUES (
    p_deal_id, v_leg_no, 'delivery'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, v_deal.customer_party_id,
    v_deal.sell_currency_code, p_delivered_amount, p_delivery_target,
    v_tx_id, p_proof_reference, p_notes, NOW()
  ) RETURNING id INTO v_leg_id;

  UPDATE fx_transactions SET leg_id = v_leg_id WHERE id = v_tx_id;

  UPDATE fx_currency_commitments SET
    delivered_amount = delivered_amount + p_delivered_amount,
    is_open = CASE WHEN delivered_amount + p_delivered_amount >= committed_amount THEN FALSE ELSE is_open END,
    updated_at = NOW()
  WHERE deal_id = p_deal_id AND commitment_type = 'customer_sale'::fx_commitment_type;

  UPDATE fx_deals SET
    status = 'completed'::fx_deal_status,
    actual_profit_pkr = v_profit,
    cost_basis_pkr = v_cost,
    completed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_deal_id;

  RETURN v_leg_id;
END;
$$;
