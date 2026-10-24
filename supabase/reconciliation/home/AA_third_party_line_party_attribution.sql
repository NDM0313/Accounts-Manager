-- AA_third_party_line_party_attribution.sql
-- Fix: third-party Dr 2100 must attribute to agent; Cr 1160 to customer.
-- Adds line-level party_id; measures use COALESCE(jl.party_id, t.party_id).
-- Correction RPC voids journals + rebuilds (no silent line edit; deal legs intact).
-- AM only. Backup before APPLY.

BEGIN;

-- ---------------------------------------------------------------------------
-- Schema: line-level party + transaction counterparty (agent) reference
-- ---------------------------------------------------------------------------
ALTER TABLE fx_transaction_lines
  ADD COLUMN IF NOT EXISTS party_id UUID REFERENCES fx_parties (id) ON DELETE RESTRICT;

ALTER TABLE fx_journal_lines
  ADD COLUMN IF NOT EXISTS party_id UUID REFERENCES fx_parties (id) ON DELETE RESTRICT;

ALTER TABLE fx_transactions
  ADD COLUMN IF NOT EXISTS counterparty_party_id UUID REFERENCES fx_parties (id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS idx_fx_journal_lines_party ON fx_journal_lines (party_id)
  WHERE party_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fx_transaction_lines_party ON fx_transaction_lines (party_id)
  WHERE party_id IS NOT NULL;

COMMENT ON COLUMN fx_journal_lines.party_id IS
  'Subledger party for this line; NULL falls back to fx_transactions.party_id';
COMMENT ON COLUMN fx_transactions.counterparty_party_id IS
  'Secondary party (e.g. agent on third-party receipt); primary remains party_id';

-- ---------------------------------------------------------------------------
-- Journal builder copies line party (fallback tx.party_id)
-- ---------------------------------------------------------------------------
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
      foreign_amount, rate_used, debit_pkr, credit_pkr, memo, party_id
    ) VALUES (
      v_entry_id, v_line_no, v_line.account_id, v_line.currency_code,
      v_line.foreign_amount, v_line.rate_used, v_line.debit_pkr, v_line.credit_pkr, v_line.memo,
      COALESCE(v_line.party_id, v_tx.party_id)
    );
  END LOOP;

  PERFORM fx_assert_journal_balanced(v_entry_id);
  RETURN v_entry_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- Party measures: attribute by line party, fallback tx party
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
  )
  SELECT
    p.id,
    p.party_type::TEXT,
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
    ), 0)::NUMERIC
  FROM fx_parties p
  LEFT JOIN lines l ON l.attrib_party_id = p.id
  WHERE p.company_id = v_company
  GROUP BY p.id, p.party_type, p.name
  ORDER BY p.name;
END;
$$;

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
      ), 0)::NUMERIC AS pay2100
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
    GREATEST(c.pay2100, 0)
  FROM control c
  LEFT JOIN deals d ON d.pid = c.pid
  ORDER BY c.pid;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_party_directory_balances(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_party_directory_measures(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- Third-party RPC: line parties + counterparty on tx
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_record_deal_third_party_payment(
  p_deal_id UUID,
  p_amount_pkr NUMERIC,
  p_agent_party_id UUID,
  p_agent_source_leg_id UUID DEFAULT NULL,
  p_external_bank_label TEXT DEFAULT NULL,
  p_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_client_operation_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_tx UUID;
  v_existing UUID;
  v_advances UUID;
  v_payable UUID;
  v_outstanding NUMERIC;
  v_source fx_deal_legs;
  v_leg_no INT;
  v_cust_leg UUID;
  v_agent_leg UUID;
  v_row fx_agent_currency_balances;
  v_memo TEXT;
  v_pkr_allocated NUMERIC;
  v_pay_before NUMERIC;
  v_pay_applied NUMERIC;
BEGIN
  IF NOT COALESCE(fx_has_permission('can_post_fx_transaction'), false) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT COALESCE(fx_same_company(v_deal.company_id), false)
     OR NOT COALESCE(fx_same_branch(v_deal.branch_id), false) THEN
    RAISE EXCEPTION 'Unauthorized company/branch';
  END IF;
  IF p_amount_pkr IS NULL OR p_amount_pkr <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;
  IF p_agent_party_id IS NULL THEN
    RAISE EXCEPTION 'Agent party required';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM fx_parties ap
    WHERE ap.id = p_agent_party_id AND ap.company_id = v_deal.company_id
  ) THEN
    RAISE EXCEPTION 'Agent party not in deal company';
  END IF;

  IF p_client_operation_id IS NOT NULL THEN
    SELECT entity_id INTO v_existing
    FROM fx_client_operations
    WHERE company_id = v_deal.company_id AND operation_key = p_client_operation_id;
    IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;
  END IF;

  PERFORM fx_ensure_deal_coa(v_deal.company_id);
  v_advances := fx_account_id_by_code(v_deal.company_id, '1160');
  v_payable := fx_account_id_by_code(v_deal.company_id, '2100');
  IF v_advances IS NULL OR v_payable IS NULL THEN
    RAISE EXCEPTION 'Missing 1160/2100 for third-party payment';
  END IF;

  v_outstanding := GREATEST(0, COALESCE(v_deal.customer_payable_pkr, 0) - COALESCE(v_deal.customer_paid_pkr, 0));
  IF p_amount_pkr > v_outstanding + 0.00000001 THEN
    RAISE EXCEPTION 'Third-party payment % exceeds customer outstanding %',
      p_amount_pkr, v_outstanding;
  END IF;

  IF p_agent_source_leg_id IS NOT NULL THEN
    SELECT * INTO v_source FROM fx_deal_legs WHERE id = p_agent_source_leg_id FOR UPDATE;
  ELSE
    SELECT * INTO v_source
    FROM fx_deal_legs
    WHERE deal_id = p_deal_id
      AND leg_type = 'agent_source'::fx_deal_leg_type
      AND counterparty_party_id = p_agent_party_id
    ORDER BY leg_no
    LIMIT 1
    FOR UPDATE;
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No agent_source leg for agent on this deal';
  END IF;
  IF v_source.counterparty_party_id IS DISTINCT FROM p_agent_party_id THEN
    RAISE EXCEPTION 'agent_source counterparty mismatch';
  END IF;

  SELECT COALESCE(SUM(pay_amount), 0) INTO v_pkr_allocated
  FROM fx_deal_legs
  WHERE parent_leg_id = v_source.id
    AND leg_type = 'agent_payment'::fx_deal_leg_type
    AND status = 'completed'::fx_deal_leg_status;

  IF v_pkr_allocated + p_amount_pkr
       > COALESCE(v_source.pay_amount, 0) + 0.00000001 THEN
    RAISE EXCEPTION
      'Third-party amount exceeds remaining agent source PKR payable on leg (allocated % of %)',
      v_pkr_allocated, v_source.pay_amount;
  END IF;

  v_memo := trim(both FROM concat_ws(' | ',
    COALESCE(p_notes, 'Third-party client→agent payment'),
    CASE WHEN p_reference IS NOT NULL THEN 'Ref: ' || p_reference ELSE NULL END,
    CASE WHEN p_external_bank_label IS NOT NULL THEN 'External: ' || p_external_bank_label ELSE NULL END,
    'NO owned-bank movement'
  ));

  -- Primary party = customer; counterparty = agent (both preserved on tx)
  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, counterparty_party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, created_by
  ) VALUES (
    v_deal.company_id, v_deal.branch_id, 'settlement_receive', 'draft', CURRENT_DATE,
    v_deal.customer_party_id, p_agent_party_id, 'PKR', p_amount_pkr, 1, p_amount_pkr,
    v_memo, p_deal_id, auth.uid()
  ) RETURNING id INTO v_tx;

  -- Line 1: agent payable reduction → Agent A
  -- Line 2: customer advance → Client A
  INSERT INTO fx_transaction_lines (
    transaction_id, line_no, account_id, currency_code,
    foreign_amount, rate_used, debit_pkr, credit_pkr, memo, party_id
  ) VALUES
    (v_tx, 1, v_payable, 'PKR', p_amount_pkr, 1, p_amount_pkr, 0,
      'Allocate to agent payable (client paid agent directly)', p_agent_party_id),
    (v_tx, 2, v_advances, 'PKR', p_amount_pkr, 1, 0, p_amount_pkr,
      'Customer advance via third-party', v_deal.customer_party_id);

  PERFORM fx_post_transaction(v_tx);

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;
  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    pay_currency, pay_amount, paid_amount, remaining_amount,
    linked_transaction_id, notes, completed_at
  ) VALUES (
    p_deal_id, v_leg_no, 'customer_payment'::fx_deal_leg_type, 'completed'::fx_deal_leg_status,
    v_deal.customer_party_id,
    'PKR', p_amount_pkr, p_amount_pkr, 0,
    v_tx, v_memo || ' [third_party]', NOW()
  ) RETURNING id INTO v_cust_leg;

  v_leg_no := v_leg_no + 1;
  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    pay_currency, pay_amount, paid_amount, remaining_amount,
    parent_leg_id, linked_transaction_id, notes, completed_at
  ) VALUES (
    p_deal_id, v_leg_no, 'agent_payment'::fx_deal_leg_type, 'completed'::fx_deal_leg_status,
    p_agent_party_id,
    'PKR', p_amount_pkr, p_amount_pkr, 0,
    v_source.id, v_tx, v_memo || ' [allocated_to_source]', NOW()
  ) RETURNING id INTO v_agent_leg;

  UPDATE fx_transactions SET leg_id = v_cust_leg WHERE id = v_tx;

  UPDATE fx_deals SET
    customer_paid_pkr = customer_paid_pkr + p_amount_pkr,
    customer_receivable_pkr = GREATEST(0, customer_payable_pkr - (customer_paid_pkr + p_amount_pkr)),
    status = (CASE
      WHEN customer_paid_pkr + p_amount_pkr >= customer_payable_pkr THEN 'customer_paid'
      WHEN customer_paid_pkr + p_amount_pkr > 0 THEN 'customer_partially_paid'
      ELSE status::text
    END)::fx_deal_status,
    updated_at = NOW()
  WHERE id = p_deal_id;

  v_row := fx_agent_balance_ensure(
    v_deal.company_id, v_deal.branch_id, p_agent_party_id,
    COALESCE(fx_normalize_currency_code(v_source.receive_currency), 'PKR')
  );
  SELECT COALESCE(payable_pkr, 0) INTO v_pay_before
  FROM fx_agent_currency_balances WHERE id = v_row.id FOR UPDATE;
  v_pay_applied := LEAST(v_pay_before, p_amount_pkr);
  UPDATE fx_agent_currency_balances SET
    payable_pkr = v_pay_before - v_pay_applied,
    updated_at = NOW()
  WHERE id = v_row.id;

  IF p_client_operation_id IS NOT NULL THEN
    INSERT INTO fx_client_operations (
      company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
    ) VALUES (
      v_deal.company_id, p_client_operation_id, 'deal_third_party_payment',
      'fx_transaction', v_tx,
      jsonb_build_object(
        'deal_id', p_deal_id,
        'amount_pkr', p_amount_pkr,
        'agent_party_id', p_agent_party_id,
        'customer_party_id', v_deal.customer_party_id,
        'source_leg_id', v_source.id,
        'customer_leg_id', v_cust_leg,
        'agent_leg_id', v_agent_leg,
        'external_bank_label', p_external_bank_label,
        'reference', p_reference,
        'owned_bank_touched', false,
        'agent_payable_reduced_pkr', v_pay_applied,
        'agent_payable_before_pkr', v_pay_before,
        'line_party_attribution', jsonb_build_object(
          '2100', p_agent_party_id,
          '1160', v_deal.customer_party_id
        )
      ),
      auth.uid()
    ) ON CONFLICT (company_id, operation_key) DO NOTHING;
  END IF;

  RETURN v_tx;
END;
$$;

REVOKE ALL ON FUNCTION fx_record_deal_third_party_payment(UUID, NUMERIC, UUID, UUID, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_record_deal_third_party_payment(UUID, NUMERIC, UUID, UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_record_deal_third_party_payment(UUID, NUMERIC, UUID, UUID, TEXT, TEXT, TEXT, TEXT) TO service_role;

-- ---------------------------------------------------------------------------
-- Audited correction: void journals + rebuild with line parties; keep deal legs
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_correct_third_party_line_attribution(
  p_transaction_id UUID,
  p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_agent UUID;
  v_customer UUID;
  v_voided INT;
  v_new_je UUID;
  v_old_je JSONB;
  v_payable UUID;
  v_advances UUID;
  v_has_2100 BOOLEAN;
  v_has_1160 BOOLEAN;
BEGIN
  IF NOT COALESCE(fx_has_permission('can_post_fx_transaction'), false)
     AND NOT COALESCE(fx_has_permission('can_delete_fx_transaction'), false) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason required';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found'; END IF;
  IF NOT COALESCE(fx_same_branch(v_tx.branch_id), false) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;
  IF v_tx.status IS DISTINCT FROM 'posted' OR COALESCE(v_tx.is_deleted, false) THEN
    RAISE EXCEPTION 'Only posted live transactions can be reattributed';
  END IF;
  IF v_tx.transaction_type IS DISTINCT FROM 'settlement_receive' THEN
    RAISE EXCEPTION 'Not a settlement_receive third-party candidate';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM fx_journal_entries je
    JOIN fx_journal_lines jl ON jl.journal_entry_id = je.id
    JOIN fx_accounts a ON a.id = jl.account_id
    WHERE je.transaction_id = p_transaction_id AND NOT COALESCE(je.is_void, false)
      AND a.code = '2100' AND jl.debit_pkr > 0
  ) INTO v_has_2100;
  SELECT EXISTS (
    SELECT 1 FROM fx_journal_entries je
    JOIN fx_journal_lines jl ON jl.journal_entry_id = je.id
    JOIN fx_accounts a ON a.id = jl.account_id
    WHERE je.transaction_id = p_transaction_id AND NOT COALESCE(je.is_void, false)
      AND a.code = '1160' AND jl.credit_pkr > 0
  ) INTO v_has_1160;
  IF NOT (v_has_2100 AND v_has_1160) THEN
    RAISE EXCEPTION 'Transaction journals are not Dr 2100 / Cr 1160 third-party shape';
  END IF;

  -- Resolve agent: counterparty column, else agent_payment leg, else client_operations
  v_customer := v_tx.party_id;
  v_agent := v_tx.counterparty_party_id;
  IF v_agent IS NULL THEN
    SELECT l.counterparty_party_id INTO v_agent
    FROM fx_deal_legs l
    WHERE l.linked_transaction_id = p_transaction_id
      AND l.leg_type = 'agent_payment'::fx_deal_leg_type
    ORDER BY l.leg_no
    LIMIT 1;
  END IF;
  IF v_agent IS NULL THEN
    SELECT (result_json->>'agent_party_id')::uuid INTO v_agent
    FROM fx_client_operations WHERE entity_id = p_transaction_id
    ORDER BY created_at DESC LIMIT 1;
  END IF;
  IF v_customer IS NULL OR v_agent IS NULL THEN
    RAISE EXCEPTION 'Cannot resolve customer/agent parties for reattribution';
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'journal_entry_id', je.id,
    'is_void', je.is_void,
    'lines', (
      SELECT jsonb_agg(jsonb_build_object(
        'line_no', jl.line_no, 'account_id', jl.account_id,
        'debit_pkr', jl.debit_pkr, 'credit_pkr', jl.credit_pkr,
        'party_id', jl.party_id, 'memo', jl.memo
      ) ORDER BY jl.line_no)
      FROM fx_journal_lines jl WHERE jl.journal_entry_id = je.id
    )
  ))
  INTO v_old_je
  FROM fx_journal_entries je
  WHERE je.transaction_id = p_transaction_id;

  v_payable := fx_account_id_by_code(v_tx.company_id, '2100');
  v_advances := fx_account_id_by_code(v_tx.company_id, '1160');

  -- Snapshot then void live journals (deal legs / paid amounts untouched)
  v_voided := fx_void_journals_for_transaction(p_transaction_id);

  UPDATE fx_transactions
  SET counterparty_party_id = v_agent,
      updated_at = NOW()
  WHERE id = p_transaction_id;

  UPDATE fx_transaction_lines tl
  SET party_id = CASE
      WHEN tl.account_id = v_payable AND tl.debit_pkr > 0 THEN v_agent
      WHEN tl.account_id = v_advances AND tl.credit_pkr > 0 THEN v_customer
      ELSE COALESCE(tl.party_id, v_customer)
    END
  WHERE tl.transaction_id = p_transaction_id;

  v_new_je := fx_build_journal_from_transaction(p_transaction_id);

  INSERT INTO fx_audit_logs (
    company_id, branch_id, entity_type, entity_id, action, reason, old_value, new_value, actor_id
  ) VALUES (
    v_tx.company_id, v_tx.branch_id, 'fx_transactions', p_transaction_id, 'edited', p_reason,
    jsonb_build_object(
      'journals_before', v_old_je,
      'party_id', v_tx.party_id,
      'counterparty_party_id', v_tx.counterparty_party_id
    ),
    jsonb_build_object(
      'journals_voided', v_voided,
      'new_journal_entry_id', v_new_je,
      'customer_party_id', v_customer,
      'agent_party_id', v_agent,
      'line_party_attribution', jsonb_build_object('2100', v_agent, '1160', v_customer),
      'deal_legs_unwound', false
    ),
    auth.uid()
  );

  RETURN jsonb_build_object(
    'transaction_id', p_transaction_id,
    'journals_voided', v_voided,
    'new_journal_entry_id', v_new_je,
    'customer_party_id', v_customer,
    'agent_party_id', v_agent
  );
END;
$$;

GRANT EXECUTE ON FUNCTION fx_correct_third_party_line_attribution(UUID, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
