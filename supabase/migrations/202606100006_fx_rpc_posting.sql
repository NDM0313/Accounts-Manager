-- FX Cash Ledger — RPC skeletons (posting/edit/delete/reports)
-- All functions: SECURITY DEFINER, permission-checked, fx_* tables only.

-- ---------------------------------------------------------------------------
-- fx_generate_transaction_no
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_generate_transaction_no(p_branch_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prefix TEXT;
  v_seq INT;
BEGIN
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  SELECT COALESCE(MAX(
    NULLIF(regexp_replace(transaction_no, '\D', '', 'g'), '')::INT
  ), 0) + 1
  INTO v_seq
  FROM fx_transactions
  WHERE branch_id = p_branch_id;

  v_prefix := TO_CHAR(NOW(), 'YYYYMMDD');
  RETURN v_prefix || '-' || LPAD(v_seq::TEXT, 5, '0');
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_post_transaction — skeleton: validates draft, assigns number, marks posted
-- Full journal logic to be implemented in Phase 2.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_post_transaction(p_transaction_id UUID)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_post_fx_transaction';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transaction not found: %', p_transaction_id;
  END IF;

  IF NOT fx_same_branch(v_tx.branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  IF v_tx.status <> 'draft' THEN
    RAISE EXCEPTION 'Only draft transactions can be posted';
  END IF;

  IF fx_is_day_closed(v_tx.branch_id, v_tx.transaction_date) THEN
    RAISE EXCEPTION 'Day is closed. Posting requires admin approval.';
  END IF;

  IF v_tx.transaction_no IS NULL OR v_tx.transaction_no = '' THEN
    v_tx.transaction_no := fx_generate_transaction_no(v_tx.branch_id);
  END IF;

  UPDATE fx_transactions
  SET
    status = 'posted',
    transaction_no = v_tx.transaction_no,
    posted_at = NOW(),
    posted_by = auth.uid(),
    updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, new_value, actor_id)
  VALUES (v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'posted', to_jsonb(v_tx), auth.uid());

  -- TODO Phase 2: create balanced fx_journal_entries + fx_journal_lines

  RETURN v_tx;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_edit_transaction — skeleton: version snapshot + reason required
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_edit_transaction(
  p_transaction_id UUID,
  p_payload JSONB,
  p_reason TEXT
)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_new_version INT;
BEGIN
  IF NOT fx_has_permission('can_edit_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_edit_fx_transaction';
  END IF;

  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required for editing posted transactions';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found'; END IF;
  IF NOT fx_same_branch(v_tx.branch_id) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF v_tx.is_deleted THEN RAISE EXCEPTION 'Cannot edit deleted transaction'; END IF;

  IF fx_is_day_closed(v_tx.branch_id, v_tx.transaction_date) THEN
    RAISE EXCEPTION 'Day is closed. Edit requires admin approval.';
  END IF;

  v_new_version := v_tx.version + 1;

  INSERT INTO fx_transaction_versions (transaction_id, version, snapshot, change_reason, changed_by)
  VALUES (v_tx.id, v_tx.version, to_jsonb(v_tx), p_reason, auth.uid());

  UPDATE fx_transactions
  SET
    transaction_date = COALESCE((p_payload->>'transaction_date')::DATE, transaction_date),
    description = COALESCE(p_payload->>'description', description),
    notes = COALESCE(p_payload->>'notes', notes),
    version = v_new_version,
    updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, reason, old_value, new_value, actor_id)
  VALUES (v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'edited', p_reason,
    (SELECT snapshot FROM fx_transaction_versions WHERE transaction_id = v_tx.id AND version = v_new_version - 1),
    to_jsonb(v_tx), auth.uid());

  -- TODO Phase 2: void/repost journal entries

  RETURN v_tx;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_delete_transaction — soft void (not physical delete)
-- ---------------------------------------------------------------------------

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
    RETURN v_tx;
  END IF;

  IF fx_is_day_closed(v_tx.branch_id, v_tx.transaction_date) THEN
    RAISE EXCEPTION 'Day is closed. Delete requires admin approval.';
  END IF;

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
  VALUES (v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'deleted', p_reason, NULL, to_jsonb(v_tx), auth.uid());

  -- TODO Phase 2: void journal entries via fx_assert_journal_balanced

  RETURN v_tx;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_restore_deleted_transaction
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_restore_deleted_transaction(p_transaction_id UUID, p_reason TEXT)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
BEGIN
  IF NOT fx_has_permission('can_edit_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found'; END IF;

  UPDATE fx_transactions
  SET is_deleted = FALSE, status = 'posted', voided_at = NULL, voided_by = NULL,
      delete_reason = NULL, updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, reason, actor_id)
  VALUES (v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'restored', p_reason, auth.uid());

  RETURN v_tx;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_post_manual_journal — skeleton
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_post_manual_journal(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_post_fx_transaction';
  END IF;
  -- TODO Phase 2: insert fx_journal_entries + balanced fx_journal_lines from p_payload
  RAISE EXCEPTION 'fx_post_manual_journal not yet implemented';
END;
$$;

-- ---------------------------------------------------------------------------
-- Report RPCs — skeletons returning empty sets until Phase 2
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_trial_balance(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  account_code TEXT,
  account_name TEXT,
  debit_pkr NUMERIC,
  credit_pkr NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN
    RAISE EXCEPTION 'Missing permission: can_view_fx_reports';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT a.code, a.name, COALESCE(SUM(jl.debit_pkr), 0), COALESCE(SUM(jl.credit_pkr), 0)
  FROM fx_accounts a
  LEFT JOIN fx_journal_lines jl ON jl.account_id = a.id
  LEFT JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    AND je.branch_id = p_branch_id
    AND je.entry_date <= p_as_of
    AND NOT je.is_void
  WHERE a.company_id = (SELECT company_id FROM fx_branches WHERE id = p_branch_id)
  GROUP BY a.code, a.name
  ORDER BY a.code;
END;
$$;

CREATE OR REPLACE FUNCTION fx_get_profit_and_loss(
  p_branch_id UUID,
  p_from DATE,
  p_to DATE
)
RETURNS TABLE (account_code TEXT, account_name TEXT, amount_pkr NUMERIC)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  RETURN QUERY SELECT NULL::TEXT, NULL::TEXT, NULL::NUMERIC WHERE FALSE;
  -- TODO Phase 2
END;
$$;

CREATE OR REPLACE FUNCTION fx_get_balance_sheet(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (account_code TEXT, account_name TEXT, balance_pkr NUMERIC)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  RETURN QUERY SELECT NULL::TEXT, NULL::TEXT, NULL::NUMERIC WHERE FALSE;
  -- TODO Phase 2
END;
$$;

CREATE OR REPLACE FUNCTION fx_get_currency_position(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (currency_code TEXT, foreign_balance NUMERIC, base_equivalent_pkr NUMERIC)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  RETURN QUERY SELECT NULL::TEXT, NULL::NUMERIC, NULL::NUMERIC WHERE FALSE;
  -- TODO Phase 2
END;
$$;

CREATE OR REPLACE FUNCTION fx_close_day(
  p_branch_id UUID,
  p_closing_date DATE,
  p_notes TEXT DEFAULT NULL
)
RETURNS fx_daily_closings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_closing fx_daily_closings;
BEGIN
  IF NOT fx_has_permission('can_close_day') THEN
    RAISE EXCEPTION 'Missing permission: can_close_day';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  INSERT INTO fx_daily_closings (company_id, branch_id, closing_date, status, notes, closed_by, closed_at)
  SELECT b.company_id, p_branch_id, p_closing_date, 'closed', p_notes, auth.uid(), NOW()
  FROM fx_branches b WHERE b.id = p_branch_id
  ON CONFLICT (branch_id, closing_date)
  DO UPDATE SET status = 'closed', notes = EXCLUDED.notes, closed_by = auth.uid(), closed_at = NOW(), updated_at = NOW()
  RETURNING * INTO v_closing;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, actor_id)
  VALUES (v_closing.company_id, v_closing.branch_id, 'fx_daily_closings', v_closing.id, 'closed_day', auth.uid());

  -- TODO Phase 2: populate fx_closing_lines with system balances

  RETURN v_closing;
END;
$$;

-- Grant execute to authenticated users (RLS enforced inside functions)
GRANT EXECUTE ON FUNCTION fx_generate_transaction_no(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_post_transaction(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_edit_transaction(UUID, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_delete_transaction(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_restore_deleted_transaction(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_post_manual_journal(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_trial_balance(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_profit_and_loss(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_balance_sheet(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_currency_position(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_close_day(UUID, DATE, TEXT) TO authenticated;
