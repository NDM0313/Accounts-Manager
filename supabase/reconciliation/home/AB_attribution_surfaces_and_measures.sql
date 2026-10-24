-- AB_attribution_surfaces_and_measures.sql
-- Final verification follow-ups after AA_:
-- 1) Extend measures with posted 1190 + unapplied 1160 (Client A UI honesty)
-- 2) Currency directory balances use line-party attribution (+ include 1160)
-- 3) RPC to list txs attributed to a party (ledger/statement/PDF)
-- AM only.

BEGIN;

DROP FUNCTION IF EXISTS fx_party_directory_measures(UUID);

CREATE OR REPLACE FUNCTION fx_party_directory_measures(
  p_company_id UUID DEFAULT NULL
)
RETURNS TABLE (
  party_id UUID,
  party_type TEXT,
  control_net_pkr NUMERIC,
  open_deal_receivable_pkr NUMERIC,
  agent_advance_pkr NUMERIC,
  agent_payable_pkr NUMERIC,
  posted_receivable_1190_pkr NUMERIC,
  unapplied_advance_1160_pkr NUMERIC
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
  WITH lines AS (
    SELECT
      COALESCE(jl.party_id, t.party_id) AS attrib_party_id,
      a.code,
      jl.debit_pkr,
      jl.credit_pkr
    FROM fx_transactions t
    JOIN fx_journal_entries je
      ON je.transaction_id = t.id AND NOT COALESCE(je.is_void, false)
    JOIN fx_journal_lines jl ON jl.journal_entry_id = je.id
    JOIN fx_accounts a ON a.id = jl.account_id
    WHERE t.company_id = v_company
      AND t.status = 'posted'
      AND NOT COALESCE(t.is_deleted, false)
      AND COALESCE(jl.party_id, t.party_id) IS NOT NULL
  ),
  control AS (
    SELECT
      p.id AS pid,
      p.party_type::TEXT AS ptype,
      COALESCE(SUM(
        CASE
          WHEN p.party_type::TEXT IN ('customer', 'supplier') THEN
            CASE
              WHEN l.code IN ('1160', '1180', '1190', '2100', '2200', '2300')
                THEN l.debit_pkr - l.credit_pkr
              ELSE 0
            END
          ELSE
            CASE
              WHEN l.code IN ('1160', '1180', '1190', '2100', '2200', '2300')
                THEN l.credit_pkr - l.debit_pkr
              ELSE 0
            END
        END
      ), 0)::NUMERIC AS cnet,
      COALESCE(SUM(
        CASE WHEN l.code = '1180' THEN l.debit_pkr - l.credit_pkr ELSE 0 END
      ), 0)::NUMERIC AS adv1180,
      COALESCE(SUM(
        CASE WHEN l.code = '2100' THEN l.credit_pkr - l.debit_pkr ELSE 0 END
      ), 0)::NUMERIC AS pay2100,
      COALESCE(SUM(
        CASE WHEN l.code = '1190' THEN l.debit_pkr - l.credit_pkr ELSE 0 END
      ), 0)::NUMERIC AS ar1190,
      COALESCE(SUM(
        CASE WHEN l.code = '1160' THEN l.credit_pkr - l.debit_pkr ELSE 0 END
      ), 0)::NUMERIC AS adv1160_cr
    FROM fx_parties p
    LEFT JOIN lines l ON l.attrib_party_id = p.id
    WHERE p.company_id = v_company
    GROUP BY p.id, p.party_type
  ),
  deals AS (
    SELECT d.customer_party_id AS pid,
           COALESCE(SUM(d.customer_receivable_pkr), 0)::NUMERIC AS open_due
    FROM fx_deals d
    WHERE d.company_id = v_company
      AND d.status NOT IN ('cancelled', 'voided')
    GROUP BY d.customer_party_id
  )
  SELECT
    c.pid,
    c.ptype,
    c.cnet,
    COALESCE(d.open_due, 0),
    GREATEST(c.adv1180, 0),
    GREATEST(c.pay2100, 0),
    GREATEST(c.ar1190, 0),
    GREATEST(c.adv1160_cr, 0)
  FROM control c
  LEFT JOIN deals d ON d.pid = c.pid
  ORDER BY c.pid;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_party_directory_measures(UUID) TO authenticated;

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
  WITH lines AS (
    SELECT
      COALESCE(jl.party_id, t.party_id) AS attrib_party_id,
      jl.currency_code,
      jl.foreign_amount,
      jl.debit_pkr,
      jl.credit_pkr,
      a.code
    FROM fx_transactions t
    JOIN fx_journal_entries je
      ON je.transaction_id = t.id AND NOT COALESCE(je.is_void, false)
    JOIN fx_journal_lines jl ON jl.journal_entry_id = je.id
    JOIN fx_accounts a ON a.id = jl.account_id
    WHERE t.company_id = v_company
      AND t.status = 'posted'
      AND NOT COALESCE(t.is_deleted, false)
      AND a.code IN ('1160', '1180', '1190', '2100', '2200', '2300')
      AND jl.currency_code IS NOT NULL
      AND jl.currency_code <> ''
      AND COALESCE(jl.party_id, t.party_id) IS NOT NULL
  )
  SELECT
    p.id,
    l.currency_code,
    COALESCE(SUM(
      CASE
        WHEN p.party_type::TEXT IN ('customer', 'supplier') THEN
          CASE WHEN l.debit_pkr > 0 THEN l.foreign_amount
               WHEN l.credit_pkr > 0 THEN -l.foreign_amount
               ELSE 0 END
        ELSE
          CASE WHEN l.credit_pkr > 0 THEN l.foreign_amount
               WHEN l.debit_pkr > 0 THEN -l.foreign_amount
               ELSE 0 END
      END
    ), 0)::NUMERIC,
    COALESCE(SUM(
      CASE
        WHEN p.party_type::TEXT IN ('customer', 'supplier') THEN
          l.debit_pkr - l.credit_pkr
        ELSE
          l.credit_pkr - l.debit_pkr
      END
    ), 0)::NUMERIC
  FROM fx_parties p
  INNER JOIN lines l ON l.attrib_party_id = p.id
  WHERE p.company_id = v_company
  GROUP BY p.id, l.currency_code
  HAVING ABS(COALESCE(SUM(l.foreign_amount), 0)) > 0.0000001
      OR ABS(COALESCE(SUM(l.debit_pkr - l.credit_pkr), 0)) > 0.0000001
  ORDER BY p.id, l.currency_code;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_party_directory_currency_balances(UUID) TO authenticated;

-- Transaction ids attributable to a party (line party, tx party, or counterparty)
CREATE OR REPLACE FUNCTION fx_list_party_attributed_transaction_ids(
  p_branch_id UUID,
  p_party_id UUID,
  p_from DATE DEFAULT NULL,
  p_to DATE DEFAULT NULL
)
RETURNS TABLE (transaction_id UUID)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger')
     AND NOT fx_has_permission('can_view_fx_reports') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT COALESCE(fx_same_branch(p_branch_id), false) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT DISTINCT t.id
  FROM fx_transactions t
  LEFT JOIN fx_journal_entries je
    ON je.transaction_id = t.id AND NOT COALESCE(je.is_void, false)
  LEFT JOIN fx_journal_lines jl ON jl.journal_entry_id = je.id
  WHERE t.branch_id = p_branch_id
    AND NOT COALESCE(t.is_deleted, false)
    AND (p_from IS NULL OR t.transaction_date >= p_from)
    AND (p_to IS NULL OR t.transaction_date <= p_to)
    AND (
      t.party_id = p_party_id
      OR t.counterparty_party_id = p_party_id
      OR jl.party_id = p_party_id
      OR (jl.id IS NOT NULL AND jl.party_id IS NULL AND t.party_id = p_party_id)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION fx_list_party_attributed_transaction_ids(UUID, UUID, DATE, DATE) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
