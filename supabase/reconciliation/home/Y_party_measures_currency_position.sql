-- Y_party_measures_currency_position.sql
-- Additive clarity for directory chips + currency Actual semantics.
-- AM only. Does not rewrite journals. Backup before APPLY.
--
-- Root causes addressed:
-- 1) Directory chip was a single net of 1180/1190/2100/2200/2300 via t.party_id,
--    which is NOT deal.customer_receivable_pkr. Third-party Dr 2100/Cr 1160 on a
--    customer-tagged tx inflated the chip (+2100) while 1160 was excluded.
-- 2) Currency Actual only scanned 1110/1120–1150, omitting TRAINING 1113/1114 and
--    all 121x banks; legend said "vault" while 1120–1150 also hold agent inventory.

BEGIN;

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

  -- Preserved single-column RPC for older clients: control net including 1160
  -- so third-party Cr 1160 offsets Dr 2100 on the same customer-tagged tx.
  RETURN QUERY
  SELECT
    p.id AS party_id,
    p.party_type::TEXT,
    COALESCE(SUM(
      CASE
        WHEN p.party_type::TEXT IN ('customer', 'supplier') THEN
          CASE
            WHEN a.code IN ('1160', '1180', '1190', '2100', '2200', '2300')
              THEN jl.debit_pkr - jl.credit_pkr
            ELSE 0
          END
        ELSE
          CASE
            WHEN a.code IN ('1160', '1180', '1190', '2100', '2200', '2300')
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

-- Richer measures for honest UI labels (does not replace deal outstanding).
CREATE OR REPLACE FUNCTION fx_party_directory_measures(
  p_company_id UUID DEFAULT NULL
)
RETURNS TABLE (
  party_id UUID,
  party_type TEXT,
  control_net_pkr NUMERIC,
  open_deal_receivable_pkr NUMERIC,
  agent_advance_pkr NUMERIC,
  agent_payable_pkr NUMERIC
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
  WITH control AS (
    SELECT
      p.id AS pid,
      p.party_type::TEXT AS ptype,
      COALESCE(SUM(
        CASE
          WHEN p.party_type::TEXT IN ('customer', 'supplier') THEN
            CASE
              WHEN a.code IN ('1160', '1180', '1190', '2100', '2200', '2300')
                THEN jl.debit_pkr - jl.credit_pkr
              ELSE 0
            END
          ELSE
            CASE
              WHEN a.code IN ('1160', '1180', '1190', '2100', '2200', '2300')
                THEN jl.credit_pkr - jl.debit_pkr
              ELSE 0
            END
        END
      ), 0)::NUMERIC AS cnet,
      COALESCE(SUM(
        CASE WHEN a.code = '1180' THEN jl.debit_pkr - jl.credit_pkr ELSE 0 END
      ), 0)::NUMERIC AS adv1180,
      COALESCE(SUM(
        CASE WHEN a.code = '2100' THEN jl.credit_pkr - jl.debit_pkr ELSE 0 END
      ), 0)::NUMERIC AS pay2100
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
    GREATEST(c.pay2100, 0)
  FROM control c
  LEFT JOIN deals d ON d.pid = c.pid
  ORDER BY c.pid;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_party_directory_measures(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION fx_get_currency_position_extended(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  currency_code TEXT,
  actual_balance NUMERIC,
  committed_balance NUMERIC,
  on_order_balance NUMERIC,
  required_balance NUMERIC,
  available_balance NUMERIC,
  base_equivalent_pkr NUMERIC
)
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

  -- Actual:
  --   FX codes → company inventory GL 1120–1150 (includes agent-held stock booked
  --              to those accounts; NOT the same as fx_agent_currency_balances UI).
  --   PKR      → owned cash 111x + owned banks 121x (excludes 1180 advance).
  RETURN QUERY
  WITH currencies AS (
    SELECT DISTINCT fx_normalize_currency_code(c.code) AS code
    FROM fx_currencies c
    WHERE c.is_active
    UNION
    SELECT DISTINCT fx_normalize_currency_code(jl.currency_code)
    FROM fx_journal_lines jl
    JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    JOIN fx_accounts a ON a.id = jl.account_id
    WHERE je.branch_id = p_branch_id
      AND NOT je.is_void
      AND je.entry_date <= p_as_of
      AND (
        a.code IN ('1120', '1130', '1140', '1150')
        OR a.code LIKE '111%'
        OR a.code LIKE '121%'
      )
  ),
  actuals AS (
    SELECT
      fx_normalize_currency_code(jl.currency_code) AS code,
      COALESCE(SUM(
        CASE
          WHEN jl.debit_pkr > 0 THEN jl.foreign_amount
          WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount
          ELSE 0
        END
      ), 0) AS actual_bal,
      COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0) AS pkr_eq
    FROM fx_journal_lines jl
    JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    JOIN fx_accounts a ON a.id = jl.account_id
    WHERE je.branch_id = p_branch_id
      AND NOT je.is_void
      AND je.entry_date <= p_as_of
      AND (
        (
          fx_normalize_currency_code(jl.currency_code) <> 'PKR'
          AND a.code IN ('1120', '1130', '1140', '1150')
        )
        OR (
          fx_normalize_currency_code(jl.currency_code) = 'PKR'
          AND (a.code LIKE '111%' OR a.code LIKE '121%')
        )
      )
    GROUP BY 1
  ),
  committed AS (
    SELECT
      fx_normalize_currency_code(c.currency_code) AS code,
      COALESCE(SUM(c.committed_amount - c.sourced_amount - c.released_amount), 0) AS amt
    FROM fx_currency_commitments c
    JOIN fx_deals d ON d.id = c.deal_id
    WHERE d.branch_id = p_branch_id
      AND c.is_open
      AND c.commitment_type = 'customer_sale'
    GROUP BY 1
  ),
  on_order AS (
    SELECT
      fx_normalize_currency_code(c.currency_code) AS code,
      COALESCE(SUM(c.committed_amount - c.sourced_amount - c.released_amount), 0) AS amt
    FROM fx_currency_commitments c
    JOIN fx_deals d ON d.id = c.deal_id
    WHERE d.branch_id = p_branch_id
      AND c.is_open
      AND c.commitment_type = 'on_order_inbound'
    GROUP BY 1
  )
  SELECT
    cur.code,
    COALESCE(a.actual_bal, 0),
    COALESCE(cm.amt, 0),
    COALESCE(oo.amt, 0),
    GREATEST(0, COALESCE(cm.amt, 0) - COALESCE(a.actual_bal, 0) - COALESCE(oo.amt, 0)),
    COALESCE(a.actual_bal, 0) - COALESCE(cm.amt, 0) + COALESCE(oo.amt, 0),
    COALESCE(a.pkr_eq, 0)
  FROM currencies cur
  LEFT JOIN actuals a ON a.code = cur.code
  LEFT JOIN committed cm ON cm.code = cur.code
  LEFT JOIN on_order oo ON oo.code = cur.code
  WHERE COALESCE(a.actual_bal, 0) <> 0
     OR COALESCE(cm.amt, 0) <> 0
     OR COALESCE(oo.amt, 0) <> 0
  ORDER BY cur.code;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_get_currency_position_extended(UUID, DATE) TO authenticated;

COMMIT;
