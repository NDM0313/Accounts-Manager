-- Phase 3: Posting engine — balanced journal creation from draft transaction lines
-- Project: ygidlcqhupmxvsdjmvnf only (fx_* tables)

DROP FUNCTION IF EXISTS fx_get_trial_balance(UUID, DATE);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_generate_entry_no(p_branch_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seq INT;
BEGIN
  SELECT COALESCE(MAX(
    NULLIF(regexp_replace(entry_no, '\D', '', 'g'), '')::INT
  ), 0) + 1
  INTO v_seq
  FROM fx_journal_entries
  WHERE branch_id = p_branch_id;

  RETURN TO_CHAR(NOW(), 'YYYYMMDD') || '-JE-' || LPAD(v_seq::TEXT, 5, '0');
END;
$$;

CREATE OR REPLACE FUNCTION fx_account_id_by_code(p_company_id UUID, p_code TEXT)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM fx_accounts WHERE company_id = p_company_id AND code = p_code LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fx_validate_transaction_lines_balanced(p_transaction_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_debit NUMERIC(20, 8);
  v_credit NUMERIC(20, 8);
  v_line_count INT;
BEGIN
  SELECT COUNT(*), COALESCE(SUM(debit_pkr), 0), COALESCE(SUM(credit_pkr), 0)
  INTO v_line_count, v_debit, v_credit
  FROM fx_transaction_lines
  WHERE transaction_id = p_transaction_id;

  IF v_line_count < 2 THEN
    RAISE EXCEPTION 'Draft requires at least 2 transaction lines';
  END IF;

  IF v_debit <> v_credit OR v_debit = 0 THEN
    RAISE EXCEPTION 'Transaction lines not balanced: debit=% credit=%', v_debit, v_credit;
  END IF;
END;
$$;

-- Copy balanced draft lines → journal; returns journal_entry_id
CREATE OR REPLACE FUNCTION fx_build_journal_from_transaction(p_transaction_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_entry_id UUID;
  v_line RECORD;
  v_line_no INT := 0;
BEGIN
  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transaction not found';
  END IF;

  PERFORM fx_validate_transaction_lines_balanced(p_transaction_id);

  INSERT INTO fx_journal_entries (
    company_id, branch_id, transaction_id, entry_no, entry_date, description, posted_by
  ) VALUES (
    v_tx.company_id,
    v_tx.branch_id,
    v_tx.id,
    fx_generate_entry_no(v_tx.branch_id),
    v_tx.transaction_date,
    COALESCE(v_tx.description, v_tx.transaction_type::TEXT),
    auth.uid()
  )
  RETURNING id INTO v_entry_id;

  FOR v_line IN
    SELECT * FROM fx_transaction_lines
    WHERE transaction_id = p_transaction_id
    ORDER BY line_no
  LOOP
    IF v_line.account_id IS NULL THEN
      RAISE EXCEPTION 'Line % missing account_id', v_line.line_no;
    END IF;

    v_line_no := v_line_no + 1;
    INSERT INTO fx_journal_lines (
      journal_entry_id, line_no, account_id, currency_code,
      foreign_amount, rate_used, debit_pkr, credit_pkr, memo
    ) VALUES (
      v_entry_id, v_line_no, v_line.account_id, v_line.currency_code,
      v_line.foreign_amount, v_line.rate_used, v_line.debit_pkr, v_line.credit_pkr, v_line.memo
    );
  END LOOP;

  PERFORM fx_assert_journal_balanced(v_entry_id);
  RETURN v_entry_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_post_transaction — full posting with journal
-- ---------------------------------------------------------------------------

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
    'opening_balance', 'account_transfer', 'expense', 'currency_buy', 'currency_sell'
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
    RAISE EXCEPTION 'Transaction type % not enabled in Phase 3', v_tx.transaction_type;
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

-- ---------------------------------------------------------------------------
-- Cash balances for dashboard (asset cash accounts 1110–1150)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_cash_balances(p_branch_id UUID)
RETURNS TABLE (
  account_code TEXT,
  account_name TEXT,
  currency_code TEXT,
  balance_pkr NUMERIC,
  foreign_balance NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') AND NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT
    a.code,
    a.name,
    COALESCE(c.code, jl.currency_code, 'PKR') AS currency_code,
    COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0) AS balance_pkr,
    COALESCE(SUM(
      CASE
        WHEN jl.debit_pkr > 0 THEN jl.foreign_amount
        WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount
        ELSE 0
      END
    ), 0) AS foreign_balance
  FROM fx_accounts a
  LEFT JOIN fx_currencies c ON c.id = a.currency_id
  LEFT JOIN fx_journal_lines jl ON jl.account_id = a.id
  LEFT JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    AND je.branch_id = p_branch_id
    AND NOT je.is_void
  WHERE a.company_id = (SELECT company_id FROM fx_branches WHERE id = p_branch_id)
    AND a.code IN ('1110', '1120', '1130', '1140', '1150')
  GROUP BY a.code, a.name, c.code, jl.currency_code
  HAVING COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0) <> 0
     OR COALESCE(SUM(
       CASE WHEN jl.debit_pkr > 0 THEN jl.foreign_amount WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount ELSE 0 END
     ), 0) <> 0
  ORDER BY a.code;
END;
$$;

-- Trial balance with net column; hide all-zero rows
CREATE OR REPLACE FUNCTION fx_get_trial_balance(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  account_code TEXT,
  account_name TEXT,
  debit_pkr NUMERIC,
  credit_pkr NUMERIC,
  net_pkr NUMERIC
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
  SELECT
    a.code,
    a.name,
    COALESCE(SUM(jl.debit_pkr), 0) AS debit_pkr,
    COALESCE(SUM(jl.credit_pkr), 0) AS credit_pkr,
    COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0) AS net_pkr
  FROM fx_accounts a
  LEFT JOIN fx_journal_lines jl ON jl.account_id = a.id
  LEFT JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    AND je.branch_id = p_branch_id
    AND je.entry_date <= p_as_of
    AND NOT je.is_void
  WHERE a.company_id = (SELECT company_id FROM fx_branches WHERE id = p_branch_id)
  GROUP BY a.code, a.name
  HAVING COALESCE(SUM(jl.debit_pkr), 0) <> 0 OR COALESCE(SUM(jl.credit_pkr), 0) <> 0
  ORDER BY a.code;
END;
$$;

CREATE OR REPLACE FUNCTION fx_get_trial_balance_totals(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (total_debit NUMERIC, total_credit NUMERIC, is_balanced BOOLEAN)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_debit NUMERIC;
  v_credit NUMERIC;
BEGIN
  SELECT COALESCE(SUM(t.debit_pkr), 0), COALESCE(SUM(t.credit_pkr), 0)
  INTO v_debit, v_credit
  FROM fx_get_trial_balance(p_branch_id, p_as_of) t;

  RETURN QUERY SELECT v_debit, v_credit, (v_debit = v_credit);
END;
$$;

GRANT EXECUTE ON FUNCTION fx_generate_entry_no(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_account_id_by_code(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_validate_transaction_lines_balanced(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_build_journal_from_transaction(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_cash_balances(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_trial_balance_totals(UUID, DATE) TO authenticated;
