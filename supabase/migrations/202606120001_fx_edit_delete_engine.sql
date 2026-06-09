-- Phase 4: Complete edit/delete — void linked journals, audit trail
-- Project: ygidlcqhupmxvsdjmvnf only (fx_* tables)

-- Void all active journal entries for a posted transaction
CREATE OR REPLACE FUNCTION fx_void_journals_for_transaction(p_transaction_id UUID)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT;
BEGIN
  UPDATE fx_journal_entries
  SET
    is_void = TRUE,
    voided_at = NOW(),
    voided_by = auth.uid(),
    updated_at = NOW()
  WHERE transaction_id = p_transaction_id
    AND NOT is_void;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_delete_transaction — draft hard delete; posted soft void + journal void
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
  v_voided INT;
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

  v_voided := fx_void_journals_for_transaction(p_transaction_id);

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
    jsonb_build_object('transaction', to_jsonb(v_tx), 'journals_voided', v_voided),
    auth.uid()
  );

  RETURN v_tx;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_edit_transaction — metadata edit on posted (description/date/notes)
-- Line/journal repost deferred to Phase 4B
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
  v_old JSONB;
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
  IF v_tx.is_deleted OR v_tx.status = 'voided' THEN
    RAISE EXCEPTION 'Cannot edit voided transaction';
  END IF;
  IF v_tx.status = 'draft' THEN
    RAISE EXCEPTION 'Use client draft update for draft transactions';
  END IF;

  IF fx_is_day_closed(v_tx.branch_id, v_tx.transaction_date) THEN
    RAISE EXCEPTION 'Day is closed. Edit requires admin approval.';
  END IF;

  v_old := to_jsonb(v_tx);
  v_new_version := v_tx.version + 1;

  INSERT INTO fx_transaction_versions (transaction_id, version, snapshot, change_reason, changed_by)
  VALUES (v_tx.id, v_tx.version, v_old, p_reason, auth.uid());

  UPDATE fx_transactions
  SET
    transaction_date = COALESCE((p_payload->>'transaction_date')::DATE, transaction_date),
    description = COALESCE(NULLIF(p_payload->>'description', ''), description),
    notes = COALESCE(NULLIF(p_payload->>'notes', ''), notes),
    version = v_new_version,
    updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  -- Sync journal entry header description/date when present
  UPDATE fx_journal_entries
  SET
    entry_date = v_tx.transaction_date,
    description = COALESCE(v_tx.description, description),
    updated_at = NOW()
  WHERE transaction_id = p_transaction_id
    AND NOT is_void;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, reason, old_value, new_value, actor_id)
  VALUES (v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'edited', p_reason, v_old, to_jsonb(v_tx), auth.uid());

  RETURN v_tx;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_void_journals_for_transaction(UUID) TO authenticated;
