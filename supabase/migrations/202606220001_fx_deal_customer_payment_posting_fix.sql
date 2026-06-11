-- Fix deal customer payment posting: use settlement_receive instead of manual_journal
-- Project: ygidlcqhupmxvsdjmvnf only
--
-- manual_journal is not in fx_post_transaction allowlist; customer deal payments
-- must post via settlement_receive (Dr PKR Cash / Cr Customer Advances).

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
    v_deal.company_id, v_deal.branch_id, 'settlement_receive', 'draft', CURRENT_DATE,
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

GRANT EXECUTE ON FUNCTION fx_record_deal_customer_payment(UUID, NUMERIC, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
