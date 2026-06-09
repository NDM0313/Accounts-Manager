-- Manual journal, repost transaction, restore with journal repost, attachments storage bucket

-- ---------------------------------------------------------------------------
-- fx_post_manual_journal
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_post_manual_journal(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_branch_id UUID := (p_payload->>'branch_id')::UUID;
  v_company_id UUID := (p_payload->>'company_id')::UUID;
  v_entry_date DATE := COALESCE((p_payload->>'entry_date')::DATE, CURRENT_DATE);
  v_description TEXT := NULLIF(p_payload->>'description', '');
  v_entry_id UUID;
  v_line JSONB;
  v_line_no INT := 0;
  v_debit NUMERIC(20, 8) := 0;
  v_credit NUMERIC(20, 8) := 0;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_post_fx_transaction';
  END IF;
  IF NOT fx_same_branch(v_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;
  IF fx_is_day_closed(v_branch_id, v_entry_date) THEN
    RAISE EXCEPTION 'Day is closed';
  END IF;

  FOR v_line IN SELECT * FROM jsonb_array_elements(COALESCE(p_payload->'lines', '[]'::JSONB))
  LOOP
    v_debit := v_debit + COALESCE((v_line->>'debit_pkr')::NUMERIC, 0);
    v_credit := v_credit + COALESCE((v_line->>'credit_pkr')::NUMERIC, 0);
  END LOOP;

  IF v_debit <> v_credit OR v_debit = 0 THEN
    RAISE EXCEPTION 'Manual journal lines not balanced: debit=% credit=%', v_debit, v_credit;
  END IF;

  INSERT INTO fx_journal_entries (
    company_id, branch_id, transaction_id, entry_no, entry_date, description, posted_by
  ) VALUES (
    v_company_id, v_branch_id, NULL, fx_generate_entry_no(v_branch_id), v_entry_date,
    COALESCE(v_description, 'Manual journal'), auth.uid()
  )
  RETURNING id INTO v_entry_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_payload->'lines')
  LOOP
    v_line_no := v_line_no + 1;
    INSERT INTO fx_journal_lines (
      journal_entry_id, line_no, account_id, currency_code,
      foreign_amount, rate_used, debit_pkr, credit_pkr, memo
    ) VALUES (
      v_entry_id,
      COALESCE((v_line->>'line_no')::INT, v_line_no),
      (v_line->>'account_id')::UUID,
      v_line->>'currency_code',
      COALESCE((v_line->>'foreign_amount')::NUMERIC, 0),
      COALESCE((v_line->>'rate_used')::NUMERIC, 1),
      COALESCE((v_line->>'debit_pkr')::NUMERIC, 0),
      COALESCE((v_line->>'credit_pkr')::NUMERIC, 0),
      NULLIF(v_line->>'memo', '')
    );
  END LOOP;

  PERFORM fx_assert_journal_balanced(v_entry_id);

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, actor_id)
  VALUES (v_company_id, v_branch_id, 'fx_journal_entries', v_entry_id, 'posted', auth.uid());

  RETURN v_entry_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_repost_transaction — void journals, replace lines, rebuild journal
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_repost_transaction(
  p_transaction_id UUID,
  p_reason TEXT,
  p_lines JSONB,
  p_currency_code TEXT,
  p_foreign_amount NUMERIC,
  p_rate_used NUMERIC,
  p_base_amount_pkr NUMERIC,
  p_description TEXT DEFAULT NULL
)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_old JSONB;
  v_line JSONB;
  v_line_no INT := 0;
  v_voided INT;
BEGIN
  IF NOT fx_has_permission('can_edit_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_edit_fx_transaction';
  END IF;
  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found'; END IF;
  IF NOT fx_same_branch(v_tx.branch_id) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF v_tx.status <> 'posted' OR v_tx.is_deleted THEN
    RAISE EXCEPTION 'Only posted transactions can be reposted';
  END IF;
  IF fx_is_day_closed(v_tx.branch_id, v_tx.transaction_date) THEN
    RAISE EXCEPTION 'Day is closed';
  END IF;

  v_old := to_jsonb(v_tx);
  v_voided := fx_void_journals_for_transaction(p_transaction_id);

  UPDATE fx_transactions
  SET
    currency_code = p_currency_code,
    total_foreign_amount = p_foreign_amount,
    rate_used = p_rate_used,
    total_base_amount_pkr = p_base_amount_pkr,
    description = COALESCE(NULLIF(p_description, ''), description),
    version = version + 1,
    updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  DELETE FROM fx_transaction_lines WHERE transaction_id = p_transaction_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines)
  LOOP
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (
      transaction_id, line_no, account_id, currency_code,
      foreign_amount, rate_used, base_amount_pkr, debit_pkr, credit_pkr, memo
    ) VALUES (
      p_transaction_id,
      COALESCE((v_line->>'line_no')::INT, v_line_no),
      (v_line->>'account_id')::UUID,
      v_line->>'currency_code',
      COALESCE((v_line->>'foreign_amount')::NUMERIC, 0),
      COALESCE((v_line->>'rate_used')::NUMERIC, 1),
      COALESCE((v_line->>'base_amount_pkr')::NUMERIC, 0),
      COALESCE((v_line->>'debit_pkr')::NUMERIC, 0),
      COALESCE((v_line->>'credit_pkr')::NUMERIC, 0),
      NULLIF(v_line->>'memo', '')
    );
  END LOOP;

  PERFORM fx_validate_transaction_lines_balanced(p_transaction_id);
  PERFORM fx_build_journal_from_transaction(p_transaction_id);

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, reason, old_value, new_value, actor_id)
  VALUES (
    v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'edited', p_reason,
    jsonb_build_object('transaction', v_old, 'journals_voided', v_voided),
    to_jsonb(v_tx),
    auth.uid()
  );

  RETURN v_tx;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_restore_deleted_transaction — restore status + repost journal if missing
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_restore_deleted_transaction(p_transaction_id UUID, p_reason TEXT)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_active_journal INT;
BEGIN
  IF NOT fx_has_permission('can_edit_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission';
  END IF;
  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found'; END IF;
  IF NOT fx_same_branch(v_tx.branch_id) THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  UPDATE fx_transactions
  SET is_deleted = FALSE, status = 'posted', voided_at = NULL, voided_by = NULL,
      delete_reason = NULL, updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  SELECT COUNT(*) INTO v_active_journal
  FROM fx_journal_entries
  WHERE transaction_id = p_transaction_id AND NOT is_void;

  IF v_active_journal = 0 THEN
    PERFORM fx_validate_transaction_lines_balanced(p_transaction_id);
    PERFORM fx_build_journal_from_transaction(p_transaction_id);
  END IF;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, reason, actor_id)
  VALUES (v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'restored', p_reason, auth.uid());

  RETURN v_tx;
END;
$$;

-- ---------------------------------------------------------------------------
-- Storage bucket for attachments
-- ---------------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'fx-attachments',
  'fx-attachments',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']::TEXT[]
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS fx_attachments_storage_select ON storage.objects;
CREATE POLICY fx_attachments_storage_select ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'fx-attachments');

DROP POLICY IF EXISTS fx_attachments_storage_insert ON storage.objects;
CREATE POLICY fx_attachments_storage_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'fx-attachments');

DROP POLICY IF EXISTS fx_attachments_storage_delete ON storage.objects;
CREATE POLICY fx_attachments_storage_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'fx-attachments');

GRANT EXECUTE ON FUNCTION fx_post_manual_journal(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_repost_transaction(UUID, TEXT, JSONB, TEXT, NUMERIC, NUMERIC, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_restore_deleted_transaction(UUID, TEXT) TO authenticated;
