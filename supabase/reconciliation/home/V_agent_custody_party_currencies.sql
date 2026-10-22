-- V_agent_custody_party_currencies.sql
-- Additive: agent FX custody read API + party per-currency control balances.
-- Do NOT re-run U_ or earlier scripts. Backup before apply.

BEGIN;

-- ---------------------------------------------------------------------------
-- Agent foreign-currency custody (existing fx_agent_currency_balances table)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_list_agent_custody(
  p_company_id UUID DEFAULT NULL,
  p_agent_party_id UUID DEFAULT NULL
)
RETURNS TABLE (
  agent_party_id UUID,
  currency_code TEXT,
  owned_amount NUMERIC,
  reserved_amount NUMERIC,
  available_amount NUMERIC,
  payable_pkr NUMERIC
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

  IF to_regclass('public.fx_agent_currency_balances') IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    b.agent_party_id,
    b.currency_code,
    b.owned_amount,
    b.reserved_amount,
    GREATEST(b.owned_amount - b.reserved_amount, 0) AS available_amount,
    COALESCE(b.payable_pkr, 0) AS payable_pkr
  FROM fx_agent_currency_balances b
  WHERE b.company_id = v_company
    AND (p_agent_party_id IS NULL OR b.agent_party_id = p_agent_party_id)
  ORDER BY b.agent_party_id, b.currency_code;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_list_agent_custody(UUID, UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- Party directory: per-currency foreign amounts on party control accounts
-- (does NOT sum currencies into one total; each currency is separate)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_party_directory_currency_balances(
  p_company_id UUID DEFAULT NULL
)
RETURNS TABLE (
  party_id UUID,
  currency_code TEXT,
  foreign_net NUMERIC,
  pkr_net NUMERIC
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
    jl.currency_code,
    COALESCE(SUM(
      CASE
        WHEN p.party_type::TEXT IN ('customer', 'supplier') THEN
          CASE WHEN jl.debit_pkr > 0 THEN jl.foreign_amount
               WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount
               ELSE 0 END
        ELSE
          CASE WHEN jl.credit_pkr > 0 THEN jl.foreign_amount
               WHEN jl.debit_pkr > 0 THEN -jl.foreign_amount
               ELSE 0 END
      END
    ), 0)::NUMERIC AS foreign_net,
    COALESCE(SUM(
      CASE
        WHEN p.party_type::TEXT IN ('customer', 'supplier')
          THEN jl.debit_pkr - jl.credit_pkr
        ELSE jl.credit_pkr - jl.debit_pkr
      END
    ), 0)::NUMERIC AS pkr_net
  FROM fx_parties p
  JOIN fx_transactions t
    ON t.party_id = p.id
   AND t.company_id = p.company_id
   AND t.status = 'posted'
   AND NOT COALESCE(t.is_deleted, false)
  JOIN fx_journal_entries je
    ON je.transaction_id = t.id
   AND NOT COALESCE(je.is_void, false)
  JOIN fx_journal_lines jl ON jl.journal_entry_id = je.id
  JOIN fx_accounts a ON a.id = jl.account_id
  WHERE p.company_id = v_company
    AND a.code IN ('1180', '1190', '2100', '2200', '2300')
    AND jl.currency_code IS NOT NULL
    AND jl.currency_code <> 'PKR'
  GROUP BY p.id, jl.currency_code
  HAVING ABS(COALESCE(SUM(
      CASE
        WHEN p.party_type::TEXT IN ('customer', 'supplier') THEN
          CASE WHEN jl.debit_pkr > 0 THEN jl.foreign_amount
               WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount
               ELSE 0 END
        ELSE
          CASE WHEN jl.credit_pkr > 0 THEN jl.foreign_amount
               WHEN jl.debit_pkr > 0 THEN -jl.foreign_amount
               ELSE 0 END
      END
    ), 0)) > 0.00000001
  ORDER BY p.id, jl.currency_code;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_party_directory_currency_balances(UUID) TO authenticated;

COMMIT;
