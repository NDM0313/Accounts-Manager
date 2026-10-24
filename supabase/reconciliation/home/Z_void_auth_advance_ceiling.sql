-- Z_void_auth_advance_ceiling.sql
-- Correctness follow-ups from AM_E2E_20261024_UI verification.
-- 1) fx_has_permission: unset fx_seed.active made OR-chain NULL → auth bypass
-- 2) fx_recompute_deal_status: restore 'delivered' when delivery leg exists
-- 3) fx_unwind_deal_payment_for_voided_tx: reverse agent_payment legs + agent payable
-- 4) fx_delete_transaction: unwind agent-held currency_buy balance side effects
-- 5) fx_post_agent_currency_purchase_funded: refuse advance mode without 1180 cover
-- AM only. Backup before APPLY.

BEGIN;

CREATE OR REPLACE FUNCTION fx_has_permission(p_permission TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    COALESCE(NULLIF(current_setting('fx_seed.active', true), ''), '') = '1'
    OR EXISTS (
      SELECT 1
      FROM fx_user_active_workspace w
      JOIN fx_user_company_memberships m
        ON m.user_id = w.user_id AND m.company_id = w.company_id AND m.is_active
      JOIN fx_roles r ON r.id = m.role_id
      WHERE w.user_id = auth.uid()
        AND p_permission = ANY (r.permissions)
    )
    OR (
      auth.uid() IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM fx_user_active_workspace w WHERE w.user_id = auth.uid())
      AND EXISTS (
        SELECT 1 FROM fx_user_roles ur
        JOIN fx_roles r ON r.id = ur.role_id
        WHERE ur.user_id = auth.uid() AND p_permission = ANY (r.permissions)
      )
    );
$$;

CREATE OR REPLACE FUNCTION fx_recompute_deal_status(p_deal_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_has_delivery BOOLEAN;
  v_has_agent_source BOOLEAN;
  v_has_pending_agent_source BOOLEAN;
  v_has_currency_receipt BOOLEAN;
  v_has_sourcing_req BOOLEAN;
BEGIN
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RETURN; END IF;

  IF v_deal.status IN ('completed', 'cancelled', 'voided') THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM fx_deal_legs
    WHERE deal_id = p_deal_id AND leg_type = 'delivery'::fx_deal_leg_type
      AND status IS DISTINCT FROM 'reversed'::fx_deal_leg_status
  ) INTO v_has_delivery;

  -- Delivery is terminal for ops status; always restore if a live delivery exists
  -- (third-party payment must not leave the deal stuck at customer_partially_paid).
  IF v_has_delivery THEN
    UPDATE fx_deals SET status = 'delivered'::fx_deal_status, updated_at = NOW()
    WHERE id = p_deal_id AND status IS DISTINCT FROM 'delivered'::fx_deal_status;
    RETURN;
  END IF;

  IF v_deal.status = 'delivered' THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM fx_deal_legs
    WHERE deal_id = p_deal_id AND leg_type = 'agent_source'::fx_deal_leg_type
  ) INTO v_has_agent_source;

  SELECT EXISTS (
    SELECT 1 FROM fx_deal_legs
    WHERE deal_id = p_deal_id
      AND leg_type = 'agent_source'::fx_deal_leg_type
      AND status = 'pending'::fx_deal_leg_status
  ) INTO v_has_pending_agent_source;

  SELECT EXISTS (
    SELECT 1 FROM fx_deal_legs
    WHERE deal_id = p_deal_id AND leg_type = 'currency_receipt'::fx_deal_leg_type
  ) INTO v_has_currency_receipt;

  SELECT EXISTS (
    SELECT 1 FROM fx_deal_legs
    WHERE deal_id = p_deal_id AND leg_type = 'sourcing_requirement'::fx_deal_leg_type
  ) INTO v_has_sourcing_req;

  IF v_has_currency_receipt THEN
    UPDATE fx_deals SET status = 'currency_received'::fx_deal_status, updated_at = NOW()
    WHERE id = p_deal_id;
  ELSIF v_has_agent_source AND NOT v_has_pending_agent_source THEN
    UPDATE fx_deals SET status = 'sourcing_in_progress'::fx_deal_status, updated_at = NOW()
    WHERE id = p_deal_id;
  ELSIF v_has_sourcing_req OR v_deal.status IN ('sourcing_required', 'sourcing_in_progress') THEN
    UPDATE fx_deals SET status = 'sourcing_required'::fx_deal_status, updated_at = NOW()
    WHERE id = p_deal_id;
  ELSIF v_deal.customer_receivable_pkr <= 0 THEN
    UPDATE fx_deals SET status = 'customer_paid'::fx_deal_status, updated_at = NOW()
    WHERE id = p_deal_id;
  ELSIF v_deal.customer_paid_pkr > 0 THEN
    UPDATE fx_deals SET status = 'customer_partially_paid'::fx_deal_status, updated_at = NOW()
    WHERE id = p_deal_id;
  ELSE
    UPDATE fx_deals SET status = 'booked'::fx_deal_status, updated_at = NOW()
    WHERE id = p_deal_id;
  END IF;
END;
$$;

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

  -- Sibling agent_payment legs from third-party / settlement (same linked tx)
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

    IF v_deal.company_id IS NOT NULL AND v_leg.counterparty_party_id IS NOT NULL THEN
      v_row := fx_agent_balance_ensure(
        v_deal.company_id, v_deal.branch_id, v_leg.counterparty_party_id, v_cc
      );
      UPDATE fx_agent_currency_balances SET
        payable_pkr = COALESCE(payable_pkr, 0) + COALESCE(v_leg.pay_amount, 0),
        updated_at = NOW()
      WHERE id = v_row.id;
      v_payable_restored := v_payable_restored + COALESCE(v_leg.pay_amount, 0);
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

-- Unwind agent custody qty when voiding currency_buy that updated balances
CREATE OR REPLACE FUNCTION fx_unwind_agent_currency_buy_for_voided_tx(
  p_transaction_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_row fx_agent_currency_balances;
BEGIN
  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('unwound', false, 'reason', 'missing_tx');
  END IF;
  IF v_tx.transaction_type IS DISTINCT FROM 'currency_buy' THEN
    RETURN jsonb_build_object('unwound', false, 'reason', 'not_currency_buy');
  END IF;
  IF v_tx.party_id IS NULL OR v_tx.currency_code IS NULL THEN
    RETURN jsonb_build_object('unwound', false, 'reason', 'missing_party_or_ccy');
  END IF;

  v_row := fx_agent_balance_ensure(
    v_tx.company_id, v_tx.branch_id, v_tx.party_id,
    fx_normalize_currency_code(v_tx.currency_code)
  );

  UPDATE fx_agent_currency_balances SET
    owned_amount = GREATEST(0, owned_amount - COALESCE(v_tx.total_foreign_amount, 0)),
    carrying_cost_pkr = GREATEST(0, COALESCE(carrying_cost_pkr, 0) - COALESCE(v_tx.total_base_amount_pkr, 0)),
    payable_pkr = CASE
      -- credit-funded buys increased payable; reverse that bump
      WHEN EXISTS (
        SELECT 1 FROM fx_journal_entries je
        JOIN fx_journal_lines jl ON jl.journal_entry_id = je.id
        JOIN fx_accounts a ON a.id = jl.account_id
        WHERE je.transaction_id = p_transaction_id
          AND a.code = '2100'
          AND jl.credit_pkr > 0
      ) THEN GREATEST(0, COALESCE(payable_pkr, 0) - COALESCE(v_tx.total_base_amount_pkr, 0))
      ELSE payable_pkr
    END,
    updated_at = NOW()
  WHERE id = v_row.id;

  RETURN jsonb_build_object(
    'unwound', true,
    'agent_party_id', v_tx.party_id,
    'currency', fx_normalize_currency_code(v_tx.currency_code),
    'qty', v_tx.total_foreign_amount,
    'pkr', v_tx.total_base_amount_pkr
  );
END;
$$;

CREATE OR REPLACE FUNCTION fx_delete_transaction(
  p_transaction_id UUID,
  p_reason TEXT
)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_voided INT;
  v_unwind JSONB;
  v_buy_unwind JSONB;
BEGIN
  IF NOT COALESCE(fx_has_permission('can_delete_fx_transaction'), false) THEN
    RAISE EXCEPTION 'Missing permission: can_delete_fx_transaction';
  END IF;

  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required for delete/void';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found'; END IF;
  IF NOT fx_same_branch(v_tx.branch_id) THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  IF v_tx.status = 'draft' THEN
    DELETE FROM fx_transactions WHERE id = p_transaction_id;
    INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, reason, old_value, actor_id)
    VALUES (v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'deleted', p_reason, to_jsonb(v_tx), auth.uid());
    RETURN v_tx;
  END IF;

  IF v_tx.is_deleted OR v_tx.status = 'voided' THEN
    RAISE EXCEPTION 'Transaction already voided';
  END IF;

  IF fx_is_day_closed(v_tx.branch_id, v_tx.transaction_date) THEN
    RAISE EXCEPTION 'Day is closed. Delete requires admin approval.';
  END IF;

  IF v_tx.transaction_type = 'opening_balance' THEN
    RAISE EXCEPTION
      'Opening-balance transactions must be voided via fx_void_opening_balance_batch, not ordinary void.';
  END IF;

  v_voided := fx_void_journals_for_transaction(p_transaction_id);
  v_unwind := fx_unwind_deal_payment_for_voided_tx(p_transaction_id);
  v_buy_unwind := fx_unwind_agent_currency_buy_for_voided_tx(p_transaction_id);

  UPDATE fx_transactions
  SET
    status = 'voided',
    is_deleted = TRUE,
    voided_at = NOW(),
    voided_by = auth.uid(),
    delete_reason = p_reason,
    updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, reason, old_value, new_value, actor_id)
  VALUES (
    v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'deleted', p_reason,
    NULL,
    jsonb_build_object(
      'transaction', to_jsonb(v_tx),
      'journals_voided', v_voided,
      'deal_unwind', v_unwind,
      'agent_buy_unwind', v_buy_unwind
    ),
    auth.uid()
  );

  RETURN v_tx;
END;
$$;

-- Advance ceiling on funded purchase
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
  v_adv_bal NUMERIC;
BEGIN
  IF NOT COALESCE(fx_has_permission('can_post_fx_transaction'), false) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
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

  IF v_mode = 'advance' AND v_code = '1180' THEN
    SELECT COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0) INTO v_adv_bal
    FROM fx_accounts a
    JOIN fx_journal_lines jl ON jl.account_id = a.id
    JOIN fx_journal_entries je ON je.id = jl.journal_entry_id AND NOT COALESCE(je.is_void, false)
    JOIN fx_transactions t ON t.id = je.transaction_id
      AND t.party_id = p_agent_party_id
      AND t.status = 'posted'
      AND NOT COALESCE(t.is_deleted, false)
    WHERE a.company_id = p_company_id AND a.code = '1180';

    IF v_adv_bal + 0.00000001 < v_pkr THEN
      RAISE EXCEPTION
        'Insufficient agent advance on 1180: available % required %',
        v_adv_bal, v_pkr;
    END IF;
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
GRANT EXECUTE ON FUNCTION fx_unwind_agent_currency_buy_for_voided_tx(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
