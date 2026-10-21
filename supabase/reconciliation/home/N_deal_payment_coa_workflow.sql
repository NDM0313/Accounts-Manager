-- N: Deal customer payment COA + workflow harden
-- Root cause: fx_record_deal_customer_payment credits account code 1160
-- (Customer Advances). AM_DEMO (and any thin COA) lacked 1160 → line 2
-- account_id NULL → P0001 "Line 2 missing account_id".
-- Deal row was already inserted (separate RPC), payment rolled back → orphan unpaid deals.
--
-- This package:
-- 1) fx_ensure_deal_coa — idempotent deal accounts (1160/1170/1190/2310)
-- 2) Safer fx_record_deal_customer_payment (early mapping check, overpay reject,
--    optional cash account + client_operation_id idempotency)
-- 3) fx_book_customer_deal_v2 records initial payment in the SAME transaction
--    when customer_paid_now_pkr > 0 (atomic book+pay)

CREATE OR REPLACE FUNCTION fx_ensure_deal_coa(p_company_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_company_id IS NULL THEN
    RAISE EXCEPTION 'company_id required';
  END IF;

  INSERT INTO fx_accounts (company_id, code, name, account_type, is_active)
  SELECT p_company_id, x.code, x.name, x.atype::fx_account_type, TRUE
  FROM (VALUES
    ('1160', 'Customer Advances', 'liability'),
    ('1170', 'Delivery Clearing', 'asset'),
    ('1190', 'Customer Receivable', 'asset'),
    ('2310', 'Agent Settlement', 'liability')
  ) AS x(code, name, atype)
  ON CONFLICT (company_id, code) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION fx_ensure_deal_coa(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_ensure_deal_coa(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- Payment RPC (replace signature to add optional cash + idempotency)
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fx_record_deal_customer_payment(UUID, NUMERIC, TEXT);

CREATE OR REPLACE FUNCTION fx_record_deal_customer_payment(
  p_deal_id UUID,
  p_amount_pkr NUMERIC,
  p_notes TEXT DEFAULT NULL,
  p_cash_account_id UUID DEFAULT NULL,
  p_client_operation_id TEXT DEFAULT NULL
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
  v_outstanding NUMERIC(20, 8);
  v_existing UUID;
  v_cash_acct fx_accounts;
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
    RAISE EXCEPTION 'Payment amount must be positive';
  END IF;

  IF p_client_operation_id IS NOT NULL THEN
    SELECT entity_id INTO v_existing
    FROM fx_client_operations
    WHERE company_id = v_deal.company_id
      AND operation_key = p_client_operation_id;
    IF v_existing IS NOT NULL THEN
      RETURN v_existing;
    END IF;
  END IF;

  PERFORM fx_ensure_deal_coa(v_deal.company_id);

  IF p_cash_account_id IS NOT NULL THEN
    SELECT * INTO v_cash_acct FROM fx_accounts WHERE id = p_cash_account_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Receiving account not found';
    END IF;
    IF v_cash_acct.company_id IS DISTINCT FROM v_deal.company_id THEN
      RAISE EXCEPTION 'Receiving account belongs to another company';
    END IF;
    IF v_cash_acct.account_type IS DISTINCT FROM 'asset'::fx_account_type THEN
      RAISE EXCEPTION 'Receiving account must be a cash/bank asset account';
    END IF;
    IF NOT v_cash_acct.is_active THEN
      RAISE EXCEPTION 'Receiving account is inactive';
    END IF;
    v_pkr_cash := v_cash_acct.id;
  ELSE
    v_pkr_cash := fx_account_id_by_code(v_deal.company_id, '1110');
  END IF;

  v_advances := fx_account_id_by_code(v_deal.company_id, '1160');

  IF v_pkr_cash IS NULL THEN
    RAISE EXCEPTION
      'Missing cash account 1110 (Cash PKR) for this company. Add it under Chart of Accounts before recording a payment.';
  END IF;
  IF v_advances IS NULL THEN
    RAISE EXCEPTION
      'Missing liability account 1160 (Customer Advances) for this company. Run deal COA setup or add the account before recording a payment.';
  END IF;

  v_outstanding := GREATEST(0, COALESCE(v_deal.customer_payable_pkr, 0) - COALESCE(v_deal.customer_paid_pkr, 0));
  IF p_amount_pkr > v_outstanding + 0.00000001 THEN
    RAISE EXCEPTION
      'Payment % exceeds outstanding % for this deal. Overpayment is not allowed.',
      p_amount_pkr, v_outstanding;
  END IF;

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

  INSERT INTO fx_transaction_lines (
    transaction_id, line_no, account_id, currency_code,
    foreign_amount, rate_used, debit_pkr, credit_pkr, memo
  ) VALUES
    (v_tx_id, 1, v_pkr_cash, 'PKR', p_amount_pkr, 1, p_amount_pkr, 0, 'Customer payment received'),
    (v_tx_id, 2, v_advances, 'PKR', p_amount_pkr, 1, 0, p_amount_pkr, 'Customer advance');

  PERFORM fx_post_transaction(v_tx_id);

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    pay_currency, pay_amount, paid_amount, remaining_amount,
    linked_transaction_id, notes
  ) VALUES (
    p_deal_id, v_leg_no, 'customer_payment'::fx_deal_leg_type, 'completed'::fx_deal_leg_status,
    v_deal.customer_party_id,
    'PKR', p_amount_pkr, p_amount_pkr, 0,
    v_tx_id, p_notes
  ) RETURNING id INTO v_leg_id;

  UPDATE fx_transactions SET leg_id = v_leg_id WHERE id = v_tx_id;

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

  IF p_client_operation_id IS NOT NULL THEN
    INSERT INTO fx_client_operations (
      company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
    ) VALUES (
      v_deal.company_id, p_client_operation_id, 'deal_customer_payment', 'fx_transaction', v_tx_id,
      jsonb_build_object('deal_id', p_deal_id, 'amount_pkr', p_amount_pkr),
      auth.uid()
    )
    ON CONFLICT (company_id, operation_key) DO NOTHING;
  END IF;

  RETURN v_tx_id;
END;
$$;

REVOKE ALL ON FUNCTION fx_record_deal_customer_payment(UUID, NUMERIC, TEXT, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_record_deal_customer_payment(UUID, NUMERIC, TEXT, UUID, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- Book deal: ensure COA + atomic initial payment
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_book_customer_deal_v2(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_deal_id UUID;
  v_payable NUMERIC(20, 8);
  v_currency TEXT;
  v_available NUMERIC;
  v_required NUMERIC;
  v_status fx_deal_status;
  v_branch_id UUID := (p_payload->>'branch_id')::UUID;
  v_customer_party_id UUID := (p_payload->>'customer_party_id')::UUID;
  v_sell_amount NUMERIC := COALESCE((p_payload->>'sell_amount')::NUMERIC, 0);
  v_sale_rate_pkr NUMERIC := COALESCE((p_payload->>'sale_rate_pkr')::NUMERIC, 0);
  v_paid_now NUMERIC := COALESCE((p_payload->>'customer_paid_now_pkr')::NUMERIC, 0);
  v_delivery_method fx_delivery_method := COALESCE(
    NULLIF(p_payload->>'delivery_method', '')::fx_delivery_method, 'later'::fx_delivery_method
  );
  v_allow_short BOOLEAN := COALESCE((p_payload->>'allow_short_position')::BOOLEAN, FALSE);
  v_notes TEXT := NULLIF(p_payload->>'notes', '');
  v_auto_source BOOLEAN := COALESCE((p_payload->>'auto_source')::BOOLEAN, TRUE);
  v_cash_account_id UUID := NULLIF(p_payload->>'cash_account_id', '')::UUID;
  v_client_op TEXT := NULLIF(p_payload->>'client_operation_id', '');
  v_expected_pay DATE := NULLIF(p_payload->>'expected_payment_date', '')::DATE;
  v_pay_notes TEXT;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_profile FROM fx_current_profile();
  IF NOT fx_same_branch(v_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  IF v_sell_amount <= 0 OR v_sale_rate_pkr <= 0 THEN
    RAISE EXCEPTION 'Sell amount and sale rate must be positive';
  END IF;
  IF v_paid_now < 0 THEN
    RAISE EXCEPTION 'Initial payment cannot be negative';
  END IF;

  PERFORM fx_ensure_deal_coa(v_profile.company_id);

  v_currency := fx_normalize_currency_code(p_payload->>'sell_currency_code');
  v_payable := ROUND(v_sell_amount * v_sale_rate_pkr, 8);

  IF v_paid_now > v_payable + 0.00000001 THEN
    RAISE EXCEPTION
      'Initial payment % exceeds deal total %. Overpayment is not allowed.',
      v_paid_now, v_payable;
  END IF;

  IF v_expected_pay IS NOT NULL THEN
    v_notes := trim(both FROM COALESCE(v_notes, '') ||
      E'\nExpected payment date: ' || v_expected_pay::TEXT);
  END IF;

  -- Book with paid=0; apply payment atomically below so a payment failure
  -- rolls back the entire deal insert.
  INSERT INTO fx_deals (
    company_id, branch_id, customer_party_id,
    sell_currency_code, sell_amount, sale_rate_pkr,
    customer_payable_pkr, customer_paid_pkr, customer_receivable_pkr,
    delivery_method, status, allow_short_position, notes,
    booked_at, created_by,
    reference_rate, reference_rate_pair, reference_rate_source, reference_rate_at,
    reference_rate_is_stale, deal_rate_spread, deal_rate_spread_percent,
    reference_rate_id, rate_locked_at, rate_locked_by
  ) VALUES (
    v_profile.company_id, v_branch_id, v_customer_party_id,
    v_currency, v_sell_amount, v_sale_rate_pkr,
    v_payable, 0, v_payable,
    v_delivery_method,
    'booked'::fx_deal_status,
    v_allow_short,
    v_notes,
    NOW(), auth.uid(),
    NULLIF(p_payload->>'reference_rate', '')::NUMERIC,
    NULLIF(p_payload->>'reference_rate_pair', ''),
    NULLIF(p_payload->>'reference_rate_source', ''),
    NULLIF(p_payload->>'reference_rate_at', '')::TIMESTAMPTZ,
    (p_payload->>'reference_rate_is_stale')::BOOLEAN,
    NULLIF(p_payload->>'deal_rate_spread', '')::NUMERIC,
    NULLIF(p_payload->>'deal_rate_spread_percent', '')::NUMERIC,
    NULLIF(p_payload->>'reference_rate_id', '')::UUID,
    NULLIF(p_payload->>'rate_locked_at', '')::TIMESTAMPTZ,
    NULLIF(p_payload->>'rate_locked_by', '')::UUID
  )
  RETURNING id INTO v_deal_id;

  UPDATE fx_deals SET deal_no = fx_generate_deal_no(v_branch_id) WHERE id = v_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    remaining_amount, notes,
    reference_rate, reference_rate_pair, reference_rate_source, reference_rate_at,
    reference_rate_is_stale, deal_rate_spread, deal_rate_spread_percent,
    reference_rate_id, rate_locked_at, rate_locked_by
  ) VALUES (
    v_deal_id, 1, 'customer_order'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, v_customer_party_id,
    v_currency, v_sell_amount, 'PKR', v_payable, v_sale_rate_pkr,
    0, 'Customer FX order booked',
    NULLIF(p_payload->>'reference_rate', '')::NUMERIC,
    NULLIF(p_payload->>'reference_rate_pair', ''),
    NULLIF(p_payload->>'reference_rate_source', ''),
    NULLIF(p_payload->>'reference_rate_at', '')::TIMESTAMPTZ,
    (p_payload->>'reference_rate_is_stale')::BOOLEAN,
    NULLIF(p_payload->>'deal_rate_spread', '')::NUMERIC,
    NULLIF(p_payload->>'deal_rate_spread_percent', '')::NUMERIC,
    NULLIF(p_payload->>'reference_rate_id', '')::UUID,
    NULLIF(p_payload->>'rate_locked_at', '')::TIMESTAMPTZ,
    NULLIF(p_payload->>'rate_locked_by', '')::UUID
  );

  INSERT INTO fx_currency_commitments (
    deal_id, leg_id, currency_code, commitment_type, committed_amount
  ) VALUES (
    v_deal_id,
    (SELECT id FROM fx_deal_legs WHERE deal_id = v_deal_id AND leg_no = 1),
    v_currency, 'customer_sale'::fx_commitment_type, v_sell_amount
  );

  v_available := fx_deal_actual_balance(v_branch_id, v_currency)
    - fx_deal_open_commitment(v_branch_id, v_currency, 'customer_sale'::fx_commitment_type)
    + v_sell_amount;
  v_required := GREATEST(0, v_sell_amount - v_available);

  IF v_required > 0 AND v_auto_source THEN
    v_status := 'sourcing_required'::fx_deal_status;
    INSERT INTO fx_deal_legs (
      deal_id, leg_no, leg_type, status,
      receive_currency, receive_amount, remaining_amount, notes
    ) VALUES (
      v_deal_id, 2, 'sourcing_requirement'::fx_deal_leg_type, 'pending'::fx_deal_leg_status,
      v_currency, v_required, v_required,
      'Auto-created: insufficient available balance (sourcing request only — currency not yet purchased)'
    );
    INSERT INTO fx_currency_commitments (
      deal_id, currency_code, commitment_type, committed_amount
    ) VALUES (
      v_deal_id, v_currency, 'sourcing_required'::fx_commitment_type, v_required
    );
    UPDATE fx_deals SET status = v_status WHERE id = v_deal_id;
  ELSIF v_required > 0 AND NOT v_allow_short THEN
    UPDATE fx_deals SET status = 'sourcing_required'::fx_deal_status WHERE id = v_deal_id;
  END IF;

  IF v_paid_now > 0 THEN
    v_pay_notes := COALESCE(NULLIF(p_payload->>'payment_notes', ''), 'Initial payment on booking');
    PERFORM fx_record_deal_customer_payment(
      v_deal_id,
      v_paid_now,
      v_pay_notes,
      v_cash_account_id,
      CASE WHEN v_client_op IS NULL THEN NULL ELSE v_client_op || ':pay' END
    );
  END IF;

  RETURN v_deal_id;
END;
$$;

REVOKE ALL ON FUNCTION fx_book_customer_deal_v2(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_book_customer_deal_v2(JSONB) TO authenticated;

-- Provision missing deal COA on existing companies (idempotent)
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT id FROM fx_companies LOOP
    PERFORM fx_ensure_deal_coa(r.id);
  END LOOP;
END $$;

-- Annotate orphan unpaid deals from the failed screenshot attempts (no delete)
UPDATE fx_deals d
SET notes = trim(both FROM COALESCE(notes, '') ||
  E'\n[SYSTEM] Partial booking before COA 1160 fix — payment never posted.'),
    updated_at = NOW()
FROM fx_companies c
WHERE c.id = d.company_id
  AND c.code = 'AM_DEMO'
  AND d.deal_no IN ('DL-20261021-0001', 'DL-20261021-0002', 'DL-20261021-0003')
  AND COALESCE(d.customer_paid_pkr, 0) = 0;

NOTIFY pgrst, 'reload schema';
