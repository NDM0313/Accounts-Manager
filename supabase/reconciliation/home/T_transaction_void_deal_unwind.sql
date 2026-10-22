-- T_transaction_void_deal_unwind.sql
-- Additive home reconciliation script (do NOT re-run N–S).
-- Extends fx_delete_transaction to unwind deal customer_payment legs
-- and exposes fx_preview_void_transaction for confirmation UI.
-- Idempotent: CREATE OR REPLACE only.

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
  v_deal fx_deals;
  v_paid_delta NUMERIC := 0;
  v_leg_count INT := 0;
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

  RETURN jsonb_build_object(
    'legs_reversed', v_leg_count,
    'customer_paid_pkr_released', v_paid_delta
  );
END;
$$;

CREATE OR REPLACE FUNCTION fx_preview_void_transaction(
  p_transaction_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_deal_id UUID;
  v_deal_no TEXT;
  v_paid NUMERIC := 0;
  v_payable NUMERIC := 0;
  v_outstanding_after NUMERIC := 0;
  v_leg_count INT := 0;
  v_blockers TEXT[] := ARRAY[]::TEXT[];
BEGIN
  IF NOT fx_has_permission('can_delete_fx_transaction')
     AND NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found'; END IF;
  IF NOT fx_same_branch(v_tx.branch_id) THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  IF v_tx.status = 'draft' THEN
    RETURN jsonb_build_object(
      'mode', 'delete_draft',
      'summary', 'Hard-deletes this unposted draft. No journals are affected.',
      'can_proceed', TRUE,
      'blockers', '[]'::jsonb
    );
  END IF;

  IF v_tx.is_deleted OR v_tx.status = 'voided' THEN
    RETURN jsonb_build_object(
      'mode', 'already_voided',
      'summary', 'Transaction is already voided.',
      'can_proceed', FALSE,
      'blockers', jsonb_build_array('Already voided')
    );
  END IF;

  IF fx_is_day_closed(v_tx.branch_id, v_tx.transaction_date) THEN
    v_blockers := array_append(v_blockers, 'Day is closed for this transaction date');
  END IF;

  IF v_tx.transaction_type = 'opening_balance' THEN
    v_blockers := array_append(
      v_blockers,
      'Opening-balance rows should be voided via fx_void_opening_balance_batch'
    );
  END IF;

  SELECT COUNT(*), COALESCE(SUM(l.pay_amount), 0), MIN(d.id), MIN(d.deal_no),
         MIN(d.customer_payable_pkr)
  INTO v_leg_count, v_paid, v_deal_id, v_deal_no, v_payable
  FROM fx_deal_legs l
  JOIN fx_deals d ON d.id = l.deal_id
  WHERE l.linked_transaction_id = p_transaction_id
    AND l.leg_type = 'customer_payment'::fx_deal_leg_type
    AND l.status IS DISTINCT FROM 'reversed'::fx_deal_leg_status;

  IF v_leg_count > 0 THEN
    v_outstanding_after := GREATEST(0, COALESCE(v_payable, 0) - (
      SELECT COALESCE(customer_paid_pkr, 0) - v_paid
      FROM fx_deals WHERE id = v_deal_id
    ));
  END IF;

  RETURN jsonb_build_object(
    'mode', 'void_posted',
    'transaction_id', v_tx.id,
    'transaction_no', v_tx.transaction_no,
    'transaction_type', v_tx.transaction_type,
    'amount_foreign', v_tx.total_foreign_amount,
    'amount_pkr', v_tx.total_base_amount_pkr,
    'currency_code', v_tx.currency_code,
    'deal_id', v_deal_id,
    'deal_no', v_deal_no,
    'deal_payment_legs', v_leg_count,
    'deal_paid_pkr_released', v_paid,
    'deal_outstanding_after_pkr', v_outstanding_after,
    'summary', CASE
      WHEN v_leg_count > 0 THEN
        format(
          'This voids the posted journals for %s %s (PKR %s) and releases PKR %s of deal %s payment allocation (outstanding after ≈ PKR %s). Currency delivery legs are not undone.',
          v_tx.currency_code,
          trim(to_char(v_tx.total_foreign_amount, '9999999999990.00')),
          trim(to_char(v_tx.total_base_amount_pkr, '9999999999990.00')),
          trim(to_char(v_paid, '9999999999990.00')),
          COALESCE(v_deal_no, v_deal_id::TEXT),
          trim(to_char(v_outstanding_after, '9999999999990.00'))
        )
      ELSE
        format(
          'This voids the posted journals for %s %s (PKR %s). Original entry is retained as Voided.',
          v_tx.currency_code,
          trim(to_char(v_tx.total_foreign_amount, '9999999999990.00')),
          trim(to_char(v_tx.total_base_amount_pkr, '9999999999990.00'))
        )
    END,
    'can_proceed', cardinality(v_blockers) = 0,
    'blockers', to_jsonb(v_blockers)
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
BEGIN
  IF NOT fx_has_permission('can_delete_fx_transaction') THEN
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
      'deal_unwind', v_unwind
    ),
    auth.uid()
  );

  RETURN v_tx;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_unwind_deal_payment_for_voided_tx(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_preview_void_transaction(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_delete_transaction(UUID, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
