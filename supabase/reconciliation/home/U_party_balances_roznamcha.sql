-- U_party_balances_roznamcha.sql
-- Additive: party directory balances + daily cash/bank book (Roznamcha).
-- Idempotent CREATE OR REPLACE. Do not re-run earlier lettered scripts.
-- Backup definitions before apply on shared home DB.

BEGIN;

-- ---------------------------------------------------------------------------
-- Party directory: one PKR balance row per party (control-account convention)
-- Customer/supplier: debit-normal (receivable + / payable -)
-- Agent/settlement: credit-normal (custody/payable semantics per existing builder)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_party_directory_balances(
  p_company_id UUID DEFAULT NULL
)
RETURNS TABLE (
  party_id UUID,
  party_type TEXT,
  balance_pkr NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_company UUID;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger')
     AND NOT fx_has_permission('can_view_fx_reports') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  v_company := COALESCE(
    p_company_id,
    (SELECT company_id FROM fx_users_profiles WHERE id = auth.uid() AND is_active LIMIT 1)
  );
  IF v_company IS NULL THEN
    RAISE EXCEPTION 'No company context';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM fx_users_profiles pr
    WHERE pr.id = auth.uid() AND pr.company_id = v_company AND pr.is_active
  ) THEN
    RAISE EXCEPTION 'Unauthorized company access';
  END IF;

  RETURN QUERY
  SELECT
    p.id AS party_id,
    p.party_type::TEXT,
    COALESCE(SUM(
      CASE
        WHEN p.party_type::TEXT IN ('customer', 'supplier') THEN
          CASE
            WHEN a.code IN ('1180', '1190', '2100', '2200', '2300')
              THEN jl.debit_pkr - jl.credit_pkr
            ELSE 0
          END
        ELSE
          CASE
            WHEN a.code IN ('1180', '1190', '2100', '2200', '2300')
              THEN jl.credit_pkr - jl.debit_pkr
            ELSE 0
          END
      END
    ), 0)::NUMERIC AS balance_pkr
  FROM fx_parties p
  LEFT JOIN fx_transactions t
    ON t.party_id = p.id
   AND t.company_id = p.company_id
   AND t.status = 'posted'
   AND NOT COALESCE(t.is_deleted, false)
  LEFT JOIN fx_journal_entries je
    ON je.transaction_id = t.id
   AND NOT COALESCE(je.is_void, false)
  LEFT JOIN fx_journal_lines jl ON jl.journal_entry_id = je.id
  LEFT JOIN fx_accounts a ON a.id = jl.account_id
  WHERE p.company_id = v_company
  GROUP BY p.id, p.party_type, p.name
  ORDER BY p.name;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_party_directory_balances(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- Roznamcha / cash & bank book lines for a date range (Asia/Karachi calendar dates
-- are expected from the client as DATE params).
-- Cash/bank: account codes 11xx and 12xx (asset cash/bank family).
-- money_in = debit_pkr, money_out = credit_pkr on these asset accounts.
-- Internal transfers: both legs appear; client consolidates labels via tx type.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_get_roznamcha(
  p_branch_id UUID,
  p_from DATE DEFAULT CURRENT_DATE,
  p_to DATE DEFAULT CURRENT_DATE,
  p_account_code TEXT DEFAULT NULL
)
RETURNS TABLE (
  entry_date DATE,
  entry_time TIMESTAMPTZ,
  entry_no TEXT,
  transaction_id UUID,
  transaction_type TEXT,
  account_code TEXT,
  account_name TEXT,
  party_id UUID,
  party_name TEXT,
  description TEXT,
  money_in_pkr NUMERIC,
  money_out_pkr NUMERIC,
  currency_code TEXT,
  foreign_amount NUMERIC,
  attachment_count INTEGER
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports')
     AND NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT
    je.entry_date,
    COALESCE(t.posted_at, t.created_at, je.entry_date::timestamptz) AS entry_time,
    je.entry_no,
    t.id AS transaction_id,
    COALESCE(t.transaction_type::TEXT, 'journal') AS transaction_type,
    a.code AS account_code,
    a.name AS account_name,
    t.party_id,
    pt.name AS party_name,
    COALESCE(jl.memo, t.description, je.description) AS description,
    jl.debit_pkr AS money_in_pkr,
    jl.credit_pkr AS money_out_pkr,
    jl.currency_code,
    jl.foreign_amount,
    COALESCE((
      SELECT COUNT(*)::INTEGER
      FROM fx_attachments att
      WHERE att.transaction_id = t.id
    ), 0) AS attachment_count
  FROM fx_journal_entries je
  JOIN fx_journal_lines jl ON jl.journal_entry_id = je.id
  JOIN fx_accounts a ON a.id = jl.account_id
  LEFT JOIN fx_transactions t ON t.id = je.transaction_id
  LEFT JOIN fx_parties pt ON pt.id = t.party_id
  WHERE je.branch_id = p_branch_id
    AND NOT COALESCE(je.is_void, false)
    AND je.entry_date BETWEEN p_from AND p_to
    AND (a.code LIKE '11%' OR a.code LIKE '12%')
    AND a.account_type = 'asset'
    AND (p_account_code IS NULL OR a.code = p_account_code)
    AND (t.id IS NULL OR (t.status = 'posted' AND NOT COALESCE(t.is_deleted, false)))
  ORDER BY je.entry_date, COALESCE(t.posted_at, t.created_at, je.entry_date::timestamptz), je.entry_no, jl.line_no;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_get_roznamcha(UUID, DATE, DATE, TEXT) TO authenticated;

-- Opening cash/bank PKR balance before p_from (per account or all).
CREATE OR REPLACE FUNCTION fx_get_roznamcha_opening(
  p_branch_id UUID,
  p_as_of DATE,
  p_account_code TEXT DEFAULT NULL
)
RETURNS TABLE (
  account_code TEXT,
  account_name TEXT,
  opening_pkr NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports')
     AND NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT
    a.code,
    a.name,
    COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0)::NUMERIC AS opening_pkr
  FROM fx_accounts a
  LEFT JOIN fx_journal_lines jl ON jl.account_id = a.id
  LEFT JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    AND je.branch_id = p_branch_id
    AND NOT COALESCE(je.is_void, false)
    AND je.entry_date < p_as_of
  WHERE a.company_id = (SELECT company_id FROM fx_branches WHERE id = p_branch_id)
    AND (a.code LIKE '11%' OR a.code LIKE '12%')
    AND a.account_type = 'asset'
    AND (p_account_code IS NULL OR a.code = p_account_code)
  GROUP BY a.code, a.name
  ORDER BY a.code;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_get_roznamcha_opening(UUID, DATE, TEXT) TO authenticated;

COMMIT;
