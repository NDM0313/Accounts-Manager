-- Phase 5: Reports engine + daily closing lines
-- Project: ygidlcqhupmxvsdjmvnf only

DROP FUNCTION IF EXISTS fx_get_profit_and_loss(UUID, DATE, DATE);
DROP FUNCTION IF EXISTS fx_get_balance_sheet(UUID, DATE);
DROP FUNCTION IF EXISTS fx_get_currency_position(UUID, DATE);
DROP FUNCTION IF EXISTS fx_close_day(UUID, DATE, TEXT);
DROP FUNCTION IF EXISTS fx_is_day_closed(UUID, DATE);

-- ---------------------------------------------------------------------------
-- General Ledger
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_general_ledger(
  p_branch_id UUID,
  p_from DATE DEFAULT date_trunc('month', CURRENT_DATE)::DATE,
  p_to DATE DEFAULT CURRENT_DATE,
  p_account_code TEXT DEFAULT NULL
)
RETURNS TABLE (
  entry_date DATE,
  entry_no TEXT,
  account_code TEXT,
  account_name TEXT,
  description TEXT,
  debit_pkr NUMERIC,
  credit_pkr NUMERIC,
  currency_code TEXT,
  foreign_amount NUMERIC
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
    je.entry_date,
    je.entry_no,
    a.code,
    a.name,
    COALESCE(jl.memo, je.description),
    jl.debit_pkr,
    jl.credit_pkr,
    jl.currency_code,
    jl.foreign_amount
  FROM fx_journal_entries je
  JOIN fx_journal_lines jl ON jl.journal_entry_id = je.id
  JOIN fx_accounts a ON a.id = jl.account_id
  WHERE je.branch_id = p_branch_id
    AND NOT je.is_void
    AND je.entry_date BETWEEN p_from AND p_to
    AND (p_account_code IS NULL OR a.code = p_account_code)
  ORDER BY je.entry_date, je.entry_no, jl.line_no;
END;
$$;

-- ---------------------------------------------------------------------------
-- Profit & Loss (income + expense leaf accounts)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_profit_and_loss(
  p_branch_id UUID,
  p_from DATE,
  p_to DATE
)
RETURNS TABLE (account_code TEXT, account_name TEXT, account_type TEXT, amount_pkr NUMERIC)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT
    a.code,
    a.name,
    a.account_type::TEXT,
    CASE
      WHEN a.account_type = 'income' THEN COALESCE(SUM(jl.credit_pkr - jl.debit_pkr), 0)
      ELSE COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0)
    END AS amount_pkr
  FROM fx_accounts a
  LEFT JOIN fx_journal_lines jl ON jl.account_id = a.id
  LEFT JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    AND je.branch_id = p_branch_id
    AND je.entry_date BETWEEN p_from AND p_to
    AND NOT je.is_void
  WHERE a.company_id = (SELECT company_id FROM fx_branches WHERE id = p_branch_id)
    AND a.account_type IN ('income', 'expense')
    AND char_length(a.code) >= 4
  GROUP BY a.code, a.name, a.account_type
  HAVING COALESCE(SUM(jl.debit_pkr), 0) <> 0 OR COALESCE(SUM(jl.credit_pkr), 0) <> 0
  ORDER BY a.code;
END;
$$;

-- ---------------------------------------------------------------------------
-- Balance Sheet
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_balance_sheet(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (account_code TEXT, account_name TEXT, account_type TEXT, balance_pkr NUMERIC)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT
    a.code,
    a.name,
    a.account_type::TEXT,
    CASE
      WHEN a.account_type IN ('asset', 'expense') THEN COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0)
      ELSE COALESCE(SUM(jl.credit_pkr - jl.debit_pkr), 0)
    END AS balance_pkr
  FROM fx_accounts a
  LEFT JOIN fx_journal_lines jl ON jl.account_id = a.id
  LEFT JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    AND je.branch_id = p_branch_id
    AND je.entry_date <= p_as_of
    AND NOT je.is_void
  WHERE a.company_id = (SELECT company_id FROM fx_branches WHERE id = p_branch_id)
    AND a.account_type IN ('asset', 'liability', 'equity')
    AND char_length(a.code) >= 4
  GROUP BY a.code, a.name, a.account_type
  HAVING COALESCE(SUM(jl.debit_pkr), 0) <> 0 OR COALESCE(SUM(jl.credit_pkr), 0) <> 0
  ORDER BY a.code;
END;
$$;

-- ---------------------------------------------------------------------------
-- Currency Position
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_currency_position(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (currency_code TEXT, foreign_balance NUMERIC, base_equivalent_pkr NUMERIC)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT
    jl.currency_code,
    COALESCE(SUM(
      CASE
        WHEN jl.debit_pkr > 0 THEN jl.foreign_amount
        WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount
        ELSE 0
      END
    ), 0) AS foreign_balance,
    COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0) AS base_equivalent_pkr
  FROM fx_journal_lines jl
  JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
  JOIN fx_accounts a ON a.id = jl.account_id
  WHERE je.branch_id = p_branch_id
    AND NOT je.is_void
    AND je.entry_date <= p_as_of
    AND a.code IN ('1110', '1120', '1130', '1140', '1150')
  GROUP BY jl.currency_code
  HAVING COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0) <> 0
      OR COALESCE(SUM(
        CASE WHEN jl.debit_pkr > 0 THEN jl.foreign_amount WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount ELSE 0 END
      ), 0) <> 0
  ORDER BY jl.currency_code;
END;
$$;

-- ---------------------------------------------------------------------------
-- Closing preview + enhanced fx_close_day
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_closing_preview(
  p_branch_id UUID,
  p_closing_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  account_code TEXT,
  account_name TEXT,
  currency_code TEXT,
  system_balance NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_close_day') AND NOT fx_has_permission('can_view_fx_reports') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT cb.account_code, cb.account_name, cb.currency_code, cb.foreign_balance
  FROM fx_get_cash_balances(p_branch_id) cb;
END;
$$;

CREATE OR REPLACE FUNCTION fx_is_day_closed(p_branch_id UUID, p_date DATE)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM fx_daily_closings
    WHERE branch_id = p_branch_id
      AND closing_date = p_date
      AND status IN ('closed', 'approved')
  );
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
  v_row RECORD;
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

  DELETE FROM fx_closing_lines WHERE daily_closing_id = v_closing.id;

  FOR v_row IN
    SELECT a.id AS account_id, cb.currency_code, cb.foreign_balance AS system_balance
    FROM fx_get_cash_balances(p_branch_id) cb
    JOIN fx_accounts a ON a.code = cb.account_code
      AND a.company_id = v_closing.company_id
  LOOP
    INSERT INTO fx_closing_lines (daily_closing_id, account_id, currency_code, system_balance, difference)
    VALUES (v_closing.id, v_row.account_id, v_row.currency_code, v_row.system_balance, 0);
  END LOOP;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, actor_id)
  VALUES (v_closing.company_id, v_closing.branch_id, 'fx_daily_closings', v_closing.id, 'closed_day', auth.uid());

  RETURN v_closing;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_get_general_ledger(UUID, DATE, DATE, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_closing_preview(UUID, DATE) TO authenticated;
