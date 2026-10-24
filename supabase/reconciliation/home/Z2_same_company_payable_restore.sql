-- Z2_same_company_payable_restore.sql
-- Follow-ups from read-only recon after Z_:
-- 1) fx_same_company / fx_same_branch: unset fx_seed.active made OR-chain NULL
--    (same class as fx_has_permission NULL bypass).
-- 2) Third-party payable: record actual amount reduced; void restores only that
--    (GREATEST floor on decrease + full restore created phantom CNY payable 500
--    after AM_E2E_20261024_UI r2).
-- AM only. Backup before APPLY.

BEGIN;

CREATE OR REPLACE FUNCTION fx_same_company(p_company_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    (
      COALESCE(NULLIF(current_setting('fx_seed.active', true), ''), '') = '1'
      AND current_setting('fx_seed.company_id', true) = p_company_id::text
    )
    OR EXISTS (
      SELECT 1
      FROM fx_user_active_workspace w
      JOIN fx_user_company_memberships m
        ON m.user_id = w.user_id AND m.company_id = w.company_id AND m.is_active
      WHERE w.user_id = auth.uid() AND w.company_id = p_company_id
    )
    OR (
      auth.uid() IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM fx_users_profiles p
        WHERE p.id = auth.uid() AND p.company_id = p_company_id AND p.is_active
          AND NOT EXISTS (SELECT 1 FROM fx_user_active_workspace w WHERE w.user_id = auth.uid())
      )
    );
$$;

CREATE OR REPLACE FUNCTION fx_same_branch(p_branch_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    (
      COALESCE(NULLIF(current_setting('fx_seed.active', true), ''), '') = '1'
      AND current_setting('fx_seed.branch_id', true) = p_branch_id::text
    )
    OR EXISTS (
      SELECT 1
      FROM fx_user_active_workspace w
      JOIN fx_user_company_memberships m
        ON m.user_id = w.user_id AND m.company_id = w.company_id
       AND m.branch_id = w.branch_id AND m.is_active
      WHERE w.user_id = auth.uid() AND w.branch_id = p_branch_id
    )
    OR (
      auth.uid() IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM fx_users_profiles p
        WHERE p.id = auth.uid() AND p.branch_id = p_branch_id AND p.is_active
          AND NOT EXISTS (SELECT 1 FROM fx_user_active_workspace w WHERE w.user_id = auth.uid())
      )
    );
$$;

-- Patch third-party: capture applied payable reduction
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
  v_pay_before NUMERIC;
  v_pay_applied NUMERIC;
BEGIN
  IF NOT COALESCE(fx_has_permission('can_post_fx_transaction'), false) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT COALESCE(fx_same_branch(v_deal.branch_id), false) THEN
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
  SELECT COALESCE(payable_pkr, 0) INTO v_pay_before
  FROM fx_agent_currency_balances WHERE id = v_row.id FOR UPDATE;
  v_pay_applied := LEAST(v_pay_before, p_amount_pkr);
  UPDATE fx_agent_currency_balances SET
    payable_pkr = v_pay_before - v_pay_applied,
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
        'owned_bank_touched', false,
        'agent_payable_reduced_pkr', v_pay_applied,
        'agent_payable_before_pkr', v_pay_before
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

-- Unwind restores only recorded reduction when present
CREATE OR REPLACE FUNCTION fx_unwind_deal_payment_for_voided_tx(
  p_transaction_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_leg fx_deal_legs;
  v_paid_delta NUMERIC := 0;
  v_leg_count INT := 0;
  v_agent_legs INT := 0;
  v_payable_restored NUMERIC := 0;
  v_row fx_agent_currency_balances;
  v_cc TEXT;
  v_deal fx_deals;
  v_source fx_deal_legs;
  v_applied NUMERIC;
BEGIN
  FOR v_leg IN
    SELECT *
    FROM fx_deal_legs
    WHERE linked_transaction_id = p_transaction_id
      AND leg_type = 'customer_payment'::fx_deal_leg_type
      AND status IS DISTINCT FROM 'reversed'::fx_deal_leg_status
  LOOP
    v_paid_delta := v_paid_delta + COALESCE(v_leg.pay_amount, 0);
    UPDATE fx_deal_legs
    SET
      status = 'reversed'::fx_deal_leg_status,
      notes = CONCAT(
        COALESCE(notes, ''),
        CASE WHEN notes IS NULL OR notes = '' THEN '' ELSE E'\n' END,
        'Reversed via void of linked transaction ',
        p_transaction_id::TEXT
      ),
      updated_at = NOW()
    WHERE id = v_leg.id;

    UPDATE fx_deals
    SET
      customer_paid_pkr = GREATEST(
        0,
        COALESCE(customer_paid_pkr, 0) - COALESCE(v_leg.pay_amount, 0)
      ),
      customer_receivable_pkr = GREATEST(
        0,
        COALESCE(customer_payable_pkr, 0)
          - GREATEST(0, COALESCE(customer_paid_pkr, 0) - COALESCE(v_leg.pay_amount, 0))
      ),
      updated_at = NOW()
    WHERE id = v_leg.deal_id;

    PERFORM fx_recompute_deal_status(v_leg.deal_id);
    v_leg_count := v_leg_count + 1;
  END LOOP;

  FOR v_leg IN
    SELECT *
    FROM fx_deal_legs
    WHERE linked_transaction_id = p_transaction_id
      AND leg_type = 'agent_payment'::fx_deal_leg_type
      AND status IS DISTINCT FROM 'reversed'::fx_deal_leg_status
  LOOP
    UPDATE fx_deal_legs
    SET
      status = 'reversed'::fx_deal_leg_status,
      notes = CONCAT(
        COALESCE(notes, ''),
        CASE WHEN notes IS NULL OR notes = '' THEN '' ELSE E'\n' END,
        'Reversed via void of linked transaction ',
        p_transaction_id::TEXT
      ),
      updated_at = NOW()
    WHERE id = v_leg.id;

    SELECT * INTO v_deal FROM fx_deals WHERE id = v_leg.deal_id;
    v_cc := 'PKR';
    IF v_leg.parent_leg_id IS NOT NULL THEN
      SELECT * INTO v_source FROM fx_deal_legs WHERE id = v_leg.parent_leg_id;
      IF FOUND THEN
        v_cc := COALESCE(fx_normalize_currency_code(v_source.receive_currency), 'PKR');
      END IF;
    END IF;

    SELECT COALESCE((result_json->>'agent_payable_reduced_pkr')::numeric, v_leg.pay_amount)
    INTO v_applied
    FROM fx_client_operations
    WHERE entity_id = p_transaction_id
    ORDER BY created_at DESC
    LIMIT 1;
    IF v_applied IS NULL THEN
      v_applied := COALESCE(v_leg.pay_amount, 0);
    END IF;

    IF v_deal.company_id IS NOT NULL AND v_leg.counterparty_party_id IS NOT NULL THEN
      v_row := fx_agent_balance_ensure(
        v_deal.company_id, v_deal.branch_id, v_leg.counterparty_party_id, v_cc
      );
      UPDATE fx_agent_currency_balances SET
        payable_pkr = COALESCE(payable_pkr, 0) + v_applied,
        updated_at = NOW()
      WHERE id = v_row.id;
      v_payable_restored := v_payable_restored + v_applied;
    END IF;
    v_agent_legs := v_agent_legs + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'legs_reversed', v_leg_count,
    'customer_paid_pkr_released', v_paid_delta,
    'agent_payment_legs_reversed', v_agent_legs,
    'agent_payable_pkr_restored', v_payable_restored
  );
END;
$$;

NOTIFY pgrst, 'reload schema';
COMMIT;
