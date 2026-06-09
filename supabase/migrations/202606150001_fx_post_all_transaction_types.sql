-- Enable posting for all transaction types supported by draft line builder
-- Project: ygidlcqhupmxvsdjmvnf only (fx_* tables)

CREATE OR REPLACE FUNCTION fx_post_transaction(p_transaction_id UUID)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_journal_id UUID;
  v_allowed_types TEXT[] := ARRAY[
    'opening_balance', 'account_transfer', 'expense',
    'currency_buy', 'currency_sell', 'cross_currency',
    'settlement_send', 'settlement_receive',
    'revaluation', 'daily_closing_adjustment'
  ];
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

  IF NOT (v_tx.transaction_type::TEXT = ANY (v_allowed_types)) THEN
    RAISE EXCEPTION 'Transaction type % not enabled for posting', v_tx.transaction_type;
  END IF;

  IF fx_is_day_closed(v_tx.branch_id, v_tx.transaction_date) THEN
    RAISE EXCEPTION 'Day is closed. Posting requires admin approval.';
  END IF;

  IF v_tx.transaction_no IS NULL OR v_tx.transaction_no = '' THEN
    v_tx.transaction_no := fx_generate_transaction_no(v_tx.branch_id);
  END IF;

  v_journal_id := fx_build_journal_from_transaction(p_transaction_id);

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
  VALUES (
    v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'posted',
    jsonb_build_object('transaction', to_jsonb(v_tx), 'journal_entry_id', v_journal_id),
    auth.uid()
  );

  RETURN v_tx;
END;
$$;
