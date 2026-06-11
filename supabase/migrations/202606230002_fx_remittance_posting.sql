-- PROPOSAL ONLY — do not apply without explicit approval.
-- FX Remittance posting RPCs — balanced journals via fx_post_transaction

-- Helper: cash account for currency
CREATE OR REPLACE FUNCTION fx_cash_account_for_currency(p_company_id UUID, p_currency TEXT)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT a.id FROM fx_accounts a
  JOIN fx_currencies c ON c.id = a.currency_id
  WHERE a.company_id = p_company_id
    AND a.is_active
    AND a.account_type = 'asset'
    AND c.code = upper(p_currency)
    AND a.code LIKE '11%'
  ORDER BY a.code
  LIMIT 1;
$$;

-- ---------------------------------------------------------------------------
-- fx_record_remittance_customer_payment
-- Dr Cash, Cr Remittance Liability (+ Cr Commission Income)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_record_remittance_customer_payment(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
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
  v_liability UUID;
  v_commission UUID;
  v_pay NUMERIC(20, 8);
  v_comm NUMERIC(20, 8);
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status NOT IN ('booked', 'customer_paid') THEN
    RAISE EXCEPTION 'Invalid status for customer payment: %', v_r.status;
  END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  v_cash := CASE
    WHEN p_cash_account_code IS NOT NULL THEN fx_account_id_by_code(v_r.company_id, p_cash_account_code)
    ELSE COALESCE(fx_cash_account_for_currency(v_r.company_id, v_r.receive_currency), fx_account_id_by_code(v_r.company_id, '1110'))
  END;
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_commission := fx_account_id_by_code(v_r.company_id, '4310');

  v_comm := LEAST(p_amount, v_r.commission_amount);
  v_pay := p_amount - v_comm;

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, remittance_id, created_by
  ) VALUES (
    v_r.company_id, v_r.branch_id, 'manual_journal', 'draft', CURRENT_DATE,
    v_r.sender_party_id, v_r.receive_currency, p_amount, 1, p_amount,
    COALESCE(p_notes, 'Remittance customer payment ' || v_r.tracking_id),
    p_remittance_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, 1, v_cash, v_r.receive_currency, p_amount, 1, p_amount, 0, 'Customer payment received');

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, 2, v_liability, v_r.receive_currency, v_pay, 1, 0, v_pay, 'Remittance liability');

  IF v_comm > 0 THEN
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, 3, v_commission, v_r.receive_currency, v_comm, 1, 0, v_comm, 'Commission income');
  END IF;

  PERFORM fx_post_transaction(v_tx_id);

  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose)
  VALUES (p_remittance_id, v_tx_id, 'customer_payment');

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, amount, currency_code,
    linked_transaction_id, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'customer_payment', 'customer_paid', p_amount, v_r.receive_currency,
    v_tx_id, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET
    paid_amount = paid_amount + p_amount,
    status = CASE
      WHEN paid_amount + p_amount >= total_payable THEN 'customer_paid'::fx_remittance_status
      ELSE 'customer_paid'::fx_remittance_status
    END,
    updated_at = NOW()
  WHERE id = p_remittance_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_send_remittance_to_agent (status + assign agent)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_send_remittance_to_agent(
  p_remittance_id UUID,
  p_agent_party_id UUID,
  p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_event_no INT;
BEGIN
  IF NOT fx_has_permission('can_manage_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status <> 'customer_paid' THEN RAISE EXCEPTION 'Customer must pay before sending to agent'; END IF;

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  UPDATE fx_remittances SET
    payout_agent_party_id = p_agent_party_id,
    status = 'sent_to_agent',
    updated_at = NOW()
  WHERE id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'sent_to_agent', 'sent_to_agent', p_notes, auth.uid()
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_confirm_remittance_payout
-- Dr Remittance Liability, Cr Agent Payable
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_confirm_remittance_payout(
  p_remittance_id UUID,
  p_proof_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
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
  v_liability UUID;
  v_agent_pay UUID;
  v_amount NUMERIC(20, 8);
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF v_r.payout_agent_party_id IS NULL THEN RAISE EXCEPTION 'Payout agent required'; END IF;
  IF v_r.status NOT IN ('sent_to_agent', 'ready_for_payout') THEN
    RAISE EXCEPTION 'Invalid status for payout: %', v_r.status;
  END IF;

  v_amount := v_r.receive_amount;
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, remittance_id, created_by
  ) VALUES (
    v_r.company_id, v_r.branch_id, 'manual_journal', 'draft', CURRENT_DATE,
    v_r.payout_agent_party_id, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate,
    v_amount, COALESCE(p_notes, 'Remittance payout ' || v_r.tracking_id),
    p_remittance_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_liability, v_r.receive_currency, v_amount, 1, v_amount, 0, 'Clear remittance liability'),
    (v_tx_id, 2, v_agent_pay, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, 0, v_amount, 'Agent payable');

  PERFORM fx_post_transaction(v_tx_id);

  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose)
  VALUES (p_remittance_id, v_tx_id, 'agent_payout');

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, amount, currency_code,
    linked_transaction_id, proof_reference, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'payout_confirmed', 'paid_out', v_r.payout_amount, v_r.payout_currency,
    v_tx_id, p_proof_reference, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET
    status = 'paid_out',
    payout_status = 'paid',
    updated_at = NOW()
  WHERE id = p_remittance_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_settle_remittance_agent — Dr Agent Payable, Cr Cash
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_settle_remittance_agent(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT '1110',
  p_notes TEXT DEFAULT NULL
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
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  v_cash := fx_account_id_by_code(v_r.company_id, p_cash_account_code);
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, remittance_id, created_by
  ) VALUES (
    v_r.company_id, v_r.branch_id, 'manual_journal', 'draft', CURRENT_DATE,
    v_r.payout_agent_party_id, 'PKR', p_amount, 1, p_amount,
    COALESCE(p_notes, 'Agent settlement ' || v_r.tracking_id),
    p_remittance_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_agent_pay, 'PKR', p_amount, 1, p_amount, 0, 'Settle agent payable'),
    (v_tx_id, 2, v_cash, 'PKR', p_amount, 1, 0, p_amount, 'Cash paid to agent');

  PERFORM fx_post_transaction(v_tx_id);

  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose)
  VALUES (p_remittance_id, v_tx_id, 'agent_settlement');

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, amount, currency_code,
    linked_transaction_id, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'agent_settlement', 'completed', p_amount, 'PKR',
    v_tx_id, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET
    settlement_status = 'settled',
    status = 'completed',
    completed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_remittance_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_refund_remittance / fx_cancel_remittance
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_refund_remittance(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT '1110',
  p_notes TEXT DEFAULT NULL
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
  v_liability UUID;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  v_cash := fx_account_id_by_code(v_r.company_id, p_cash_account_code);
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, remittance_id, created_by
  ) VALUES (
    v_r.company_id, v_r.branch_id, 'manual_journal', 'draft', CURRENT_DATE,
    v_r.sender_party_id, v_r.receive_currency, p_amount, 1, p_amount,
    COALESCE(p_notes, 'Remittance refund ' || v_r.tracking_id),
    p_remittance_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_liability, v_r.receive_currency, p_amount, 1, p_amount, 0, 'Reverse liability'),
    (v_tx_id, 2, v_cash, v_r.receive_currency, p_amount, 1, 0, p_amount, 'Refund cash');

  PERFORM fx_post_transaction(v_tx_id);

  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose)
  VALUES (p_remittance_id, v_tx_id, 'refund');

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, amount, currency_code,
    linked_transaction_id, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'refund', 'refunded', p_amount, v_r.receive_currency,
    v_tx_id, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET status = 'refunded', updated_at = NOW() WHERE id = p_remittance_id;
  RETURN v_tx_id;
END;
$$;

CREATE OR REPLACE FUNCTION fx_cancel_remittance(
  p_remittance_id UUID,
  p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_event_no INT;
BEGIN
  IF NOT fx_has_permission('can_manage_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF v_r.status NOT IN ('draft', 'booked') THEN
    RAISE EXCEPTION 'Can only cancel draft or booked remittances';
  END IF;

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  UPDATE fx_remittances SET status = 'cancelled', cancelled_at = NOW(), updated_at = NOW()
  WHERE id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'status_change', 'cancelled', p_notes, auth.uid()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION fx_cash_account_for_currency(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_record_remittance_customer_payment(UUID, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_send_remittance_to_agent(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_confirm_remittance_payout(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_settle_remittance_agent(UUID, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_refund_remittance(UUID, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_cancel_remittance(UUID, TEXT) TO authenticated;
