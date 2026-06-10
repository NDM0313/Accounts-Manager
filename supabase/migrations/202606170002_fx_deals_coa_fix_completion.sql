-- FX Deals completion patch: fixed COA (currency_id) + RPCs/RLS/grants
-- Safe when 202606170001 partially applied via SQL Editor (enums/tables exist, COA/RPCs missing)
-- Cloud only: ygidlcqhupmxvsdjmvnf
-- ---------------------------------------------------------------------------
-- COA additions (idempotent per company)
-- ---------------------------------------------------------------------------

DO $$
DECLARE
  v_company UUID;
  v_assets UUID;
  v_liabilities UUID;
BEGIN
  FOR v_company IN SELECT id FROM fx_companies LOOP
    SELECT id INTO v_assets FROM fx_accounts WHERE company_id = v_company AND code = '1000' LIMIT 1;
    SELECT id INTO v_liabilities FROM fx_accounts WHERE company_id = v_company AND code = '2000' LIMIT 1;

    INSERT INTO fx_accounts (company_id, code, name, account_type, currency_id, parent_id)
    VALUES
      (v_company, '1160', 'Customer Advances', 'liability', NULL, v_liabilities),
      (v_company, '1170', 'FX Delivery Clearing', 'asset', NULL, v_assets),
      (v_company, '2310', 'Agent Settlement Clearing', 'liability', NULL, v_liabilities),
      (v_company, '2320', 'Cross-Currency Clearing', 'liability', NULL, v_liabilities)
    ON CONFLICT (company_id, code) DO NOTHING;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_normalize_currency_code(p_code TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE WHEN UPPER(TRIM(p_code)) IN ('RMB', 'CNY') THEN 'CNY' ELSE UPPER(TRIM(p_code)) END;
$$;

CREATE OR REPLACE FUNCTION fx_generate_deal_no(p_branch_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seq INT;
BEGIN
  SELECT COALESCE(MAX(
    NULLIF(regexp_replace(deal_no, '\D', '', 'g'), '')::INT
  ), 0) + 1
  INTO v_seq
  FROM fx_deals
  WHERE branch_id = p_branch_id;

  RETURN 'DL-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(v_seq::TEXT, 4, '0');
END;
$$;

CREATE OR REPLACE FUNCTION fx_deal_open_commitment(
  p_branch_id UUID,
  p_currency_code TEXT,
  p_commitment_type fx_commitment_type
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(SUM(
    c.committed_amount - c.sourced_amount - c.released_amount
  ), 0)
  FROM fx_currency_commitments c
  JOIN fx_deals d ON d.id = c.deal_id
  WHERE d.branch_id = p_branch_id
    AND c.is_open
    AND c.commitment_type = p_commitment_type
    AND fx_normalize_currency_code(c.currency_code) = fx_normalize_currency_code(p_currency_code);
$$;

CREATE OR REPLACE FUNCTION fx_deal_actual_balance(
  p_branch_id UUID,
  p_currency_code TEXT,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(SUM(
    CASE
      WHEN jl.debit_pkr > 0 THEN jl.foreign_amount
      WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount
      ELSE 0
    END
  ), 0)
  FROM fx_journal_lines jl
  JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
  JOIN fx_accounts a ON a.id = jl.account_id
  WHERE je.branch_id = p_branch_id
    AND NOT je.is_void
    AND je.entry_date <= p_as_of
    AND a.code IN ('1110', '1120', '1130', '1140', '1150')
    AND fx_normalize_currency_code(jl.currency_code) = fx_normalize_currency_code(p_currency_code);
$$;

-- ---------------------------------------------------------------------------
-- fx_get_currency_position_extended
-- ---------------------------------------------------------------------------

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
      AND a.code IN ('1110', '1120', '1130', '1140', '1150')
  ),
  actuals AS (
    SELECT
      fx_normalize_currency_code(jl.currency_code) AS code,
      COALESCE(SUM(
        CASE WHEN jl.debit_pkr > 0 THEN jl.foreign_amount WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount ELSE 0 END
      ), 0) AS actual_bal,
      COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0) AS pkr_eq
    FROM fx_journal_lines jl
    JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    JOIN fx_accounts a ON a.id = jl.account_id
    WHERE je.branch_id = p_branch_id
      AND NOT je.is_void
      AND je.entry_date <= p_as_of
      AND a.code IN ('1110', '1120', '1130', '1140', '1150')
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

-- ---------------------------------------------------------------------------
-- fx_book_customer_deal
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_book_customer_deal(
  p_branch_id UUID,
  p_customer_party_id UUID,
  p_sell_currency_code TEXT,
  p_sell_amount NUMERIC,
  p_sale_rate_pkr NUMERIC,
  p_customer_paid_now_pkr NUMERIC DEFAULT 0,
  p_delivery_method fx_delivery_method DEFAULT 'later',
  p_allow_short_position BOOLEAN DEFAULT FALSE,
  p_notes TEXT DEFAULT NULL,
  p_auto_source BOOLEAN DEFAULT TRUE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_deal_id UUID;
  v_leg_id UUID;
  v_payable NUMERIC(20, 8);
  v_currency TEXT;
  v_available NUMERIC;
  v_required NUMERIC;
  v_status fx_deal_status;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_profile FROM fx_current_profile();
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  v_currency := fx_normalize_currency_code(p_sell_currency_code);
  v_payable := ROUND(p_sell_amount * p_sale_rate_pkr, 8);

  INSERT INTO fx_deals (
    company_id, branch_id, customer_party_id,
    sell_currency_code, sell_amount, sale_rate_pkr,
    customer_payable_pkr, customer_paid_pkr, customer_receivable_pkr,
    delivery_method, status, allow_short_position, notes,
    booked_at, created_by
  ) VALUES (
    v_profile.company_id, p_branch_id, p_customer_party_id,
    v_currency, p_sell_amount, p_sale_rate_pkr,
    v_payable, COALESCE(p_customer_paid_now_pkr, 0),
    GREATEST(0, v_payable - COALESCE(p_customer_paid_now_pkr, 0)),
    p_delivery_method,
    (CASE
      WHEN COALESCE(p_customer_paid_now_pkr, 0) >= v_payable THEN 'customer_paid'
      WHEN COALESCE(p_customer_paid_now_pkr, 0) > 0 THEN 'customer_partially_paid'
      ELSE 'booked'
    END)::fx_deal_status,
    COALESCE(p_allow_short_position, FALSE),
    p_notes,
    NOW(), auth.uid()
  )
  RETURNING id INTO v_deal_id;

  UPDATE fx_deals SET deal_no = fx_generate_deal_no(p_branch_id) WHERE id = v_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    remaining_amount, notes
  ) VALUES (
    v_deal_id, 1, 'customer_order'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, p_customer_party_id,
    v_currency, p_sell_amount, 'PKR', v_payable, p_sale_rate_pkr,
    0, 'Customer FX order booked'
  );

  INSERT INTO fx_currency_commitments (
    deal_id, leg_id, currency_code, commitment_type, committed_amount
  ) VALUES (
    v_deal_id,
    (SELECT id FROM fx_deal_legs WHERE deal_id = v_deal_id AND leg_no = 1),
    v_currency, 'customer_sale'::fx_commitment_type, p_sell_amount
  );

  v_available := fx_deal_actual_balance(p_branch_id, v_currency) - fx_deal_open_commitment(p_branch_id, v_currency, 'customer_sale'::fx_commitment_type) + p_sell_amount;
  v_required := GREATEST(0, p_sell_amount - v_available);

  IF v_required > 0 AND p_auto_source THEN
    v_status := 'sourcing_required'::fx_deal_status;
    INSERT INTO fx_deal_legs (
      deal_id, leg_no, leg_type, status,
      receive_currency, receive_amount, remaining_amount, notes
    ) VALUES (
      v_deal_id, 2, 'sourcing_requirement'::fx_deal_leg_type, 'pending'::fx_deal_leg_status,
      v_currency, v_required, v_required,
      'Auto-created: insufficient available balance'
    );
    INSERT INTO fx_currency_commitments (
      deal_id, currency_code, commitment_type, committed_amount
    ) VALUES (
      v_deal_id, v_currency, 'sourcing_required'::fx_commitment_type, v_required
    );
    UPDATE fx_deals SET status = v_status WHERE id = v_deal_id;
  ELSIF v_required > 0 AND NOT COALESCE(p_allow_short_position, FALSE) THEN
    UPDATE fx_deals SET status = 'sourcing_required'::fx_deal_status WHERE id = v_deal_id;
  END IF;

  RETURN v_deal_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_record_deal_customer_payment â€” Dr PKR Cash / Cr Customer Advances
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_record_deal_customer_payment(
  p_deal_id UUID,
  p_amount_pkr NUMERIC,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_tx_id UUID;
  v_leg_no INT;
  v_leg_id UUID;
  v_pkr_cash UUID;
  v_advances UUID;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;
  IF p_amount_pkr <= 0 THEN RAISE EXCEPTION 'Payment amount must be positive'; END IF;

  v_pkr_cash := fx_account_id_by_code(v_deal.company_id, '1110');
  v_advances := fx_account_id_by_code(v_deal.company_id, '1160');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, created_by
  ) VALUES (
    v_deal.company_id, v_deal.branch_id, 'manual_journal', 'draft', CURRENT_DATE,
    v_deal.customer_party_id, 'PKR', p_amount_pkr, 1, p_amount_pkr,
    COALESCE(p_notes, 'Customer payment â€” deal ' || v_deal.deal_no),
    p_deal_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_pkr_cash, 'PKR', p_amount_pkr, 1, p_amount_pkr, 0, 'Customer payment received'),
    (v_tx_id, 2, v_advances, 'PKR', p_amount_pkr, 1, 0, p_amount_pkr, 'Customer advance');

  PERFORM fx_post_transaction(v_tx_id);

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    pay_currency, pay_amount, paid_amount, remaining_amount,
    linked_transaction_id, notes
  ) VALUES (
    p_deal_id, v_leg_no, 'customer_payment'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, v_deal.customer_party_id,
    'PKR', p_amount_pkr, p_amount_pkr, 0,
    v_tx_id, p_notes
  ) RETURNING id INTO v_leg_id;

  UPDATE fx_transactions SET leg_id = v_leg_id WHERE id = v_tx_id;

  UPDATE fx_deals SET
    customer_paid_pkr = customer_paid_pkr + p_amount_pkr,
    customer_receivable_pkr = GREATEST(0, customer_payable_pkr - customer_paid_pkr - p_amount_pkr),
    status = (CASE
      WHEN customer_paid_pkr + p_amount_pkr >= customer_payable_pkr THEN 'customer_paid'
      WHEN customer_paid_pkr + p_amount_pkr > 0 THEN 'customer_partially_paid'
      ELSE status::text
    END)::fx_deal_status,
    updated_at = NOW()
  WHERE id = p_deal_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_add_deal_leg â€” generic leg append
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_add_deal_leg(
  p_deal_id UUID,
  p_leg_type fx_deal_leg_type,
  p_counterparty_party_id UUID DEFAULT NULL,
  p_receive_currency TEXT DEFAULT NULL,
  p_receive_amount NUMERIC DEFAULT 0,
  p_pay_currency TEXT DEFAULT NULL,
  p_pay_amount NUMERIC DEFAULT 0,
  p_rate_used NUMERIC DEFAULT NULL,
  p_delivery_target fx_delivery_target DEFAULT NULL,
  p_parent_leg_id UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_leg_no INT;
  v_leg_id UUID;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    paid_amount, remaining_amount, delivery_target, parent_leg_id, notes
  ) VALUES (
    p_deal_id, v_leg_no, p_leg_type, 'pending'::fx_deal_leg_status, p_counterparty_party_id,
    CASE WHEN p_receive_currency IS NOT NULL THEN fx_normalize_currency_code(p_receive_currency) ELSE NULL END,
    COALESCE(p_receive_amount, 0),
    CASE WHEN p_pay_currency IS NOT NULL THEN fx_normalize_currency_code(p_pay_currency) ELSE NULL END,
    COALESCE(p_pay_amount, 0), p_rate_used,
    0, COALESCE(p_pay_amount, p_receive_amount, 0),
    p_delivery_target, p_parent_leg_id, p_notes
  ) RETURNING id INTO v_leg_id;

  IF p_leg_type = 'agent_source' THEN
    UPDATE fx_deals SET status = 'sourcing_in_progress'::fx_deal_status, updated_at = NOW() WHERE id = p_deal_id;
    INSERT INTO fx_currency_commitments (deal_id, leg_id, currency_code, commitment_type, committed_amount)
    VALUES (p_deal_id, v_leg_id, fx_normalize_currency_code(p_receive_currency), 'on_order_inbound'::fx_commitment_type, p_receive_amount);
  END IF;

  RETURN v_leg_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_add_settlement_link
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_add_settlement_link(
  p_deal_id UUID,
  p_from_leg_id UUID,
  p_to_leg_id UUID,
  p_link_type fx_settlement_link_type,
  p_currency_code TEXT,
  p_amount NUMERIC,
  p_proof_reference TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_deal fx_deals;
BEGIN
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  INSERT INTO fx_settlement_links (deal_id, from_leg_id, to_leg_id, link_type, currency_code, amount, proof_reference)
  VALUES (p_deal_id, p_from_leg_id, p_to_leg_id, p_link_type, fx_normalize_currency_code(p_currency_code), p_amount, p_proof_reference)
  RETURNING id INTO v_id;

  UPDATE fx_settlement_links SET status = 'completed'::fx_deal_leg_status, updated_at = NOW() WHERE id = v_id;
  RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_confirm_deal_delivery â€” final delivery + P/L recognition
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_confirm_deal_delivery(
  p_deal_id UUID,
  p_delivered_amount NUMERIC,
  p_delivery_target fx_delivery_target DEFAULT 'direct_to_customer',
  p_cost_basis_pkr NUMERIC DEFAULT NULL,
  p_proof_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_tx_id UUID;
  v_leg_no INT;
  v_leg_id UUID;
  v_cost NUMERIC;
  v_profit NUMERIC;
  v_foreign_cash UUID;
  v_advances UUID;
  v_receivable UUID;
  v_spread UUID;
  v_clearing UUID;
  v_line_no INT := 0;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  v_cost := COALESCE(p_cost_basis_pkr, v_deal.cost_basis_pkr, v_deal.customer_payable_pkr);
  v_profit := v_deal.customer_payable_pkr - v_cost;

  v_foreign_cash := fx_account_id_by_code(v_deal.company_id,
    CASE fx_normalize_currency_code(v_deal.sell_currency_code)
      WHEN 'PKR' THEN '1110' WHEN 'USD' THEN '1120' WHEN 'AED' THEN '1130'
      WHEN 'CNY' THEN '1140' WHEN 'SAR' THEN '1150' ELSE '1110'
    END);
  v_advances := fx_account_id_by_code(v_deal.company_id, '1160');
  v_receivable := fx_account_id_by_code(v_deal.company_id, '1190');
  v_spread := fx_account_id_by_code(v_deal.company_id, '4100');
  v_clearing := fx_account_id_by_code(v_deal.company_id, '1170');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, created_by
  ) VALUES (
    v_deal.company_id, v_deal.branch_id, 'currency_sell', 'draft', CURRENT_DATE,
    v_deal.customer_party_id, v_deal.sell_currency_code, p_delivered_amount,
    v_deal.sale_rate_pkr, v_deal.customer_payable_pkr,
    COALESCE(p_notes, 'Delivery â€” deal ' || v_deal.deal_no),
    p_deal_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  -- Dr Customer Advance (paid portion) + Dr Receivable (unpaid) / Cr Foreign cash at cost + Cr Spread
  IF v_deal.customer_paid_pkr > 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_advances, 'PKR', v_deal.customer_paid_pkr, 1, v_deal.customer_paid_pkr, 0, 'Clear customer advance');
  END IF;

  IF v_deal.customer_receivable_pkr > 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_receivable, 'PKR', v_deal.customer_receivable_pkr, 1, v_deal.customer_receivable_pkr, 0, 'Customer receivable');
  END IF;

  v_line_no := v_line_no + 1;
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, v_line_no, v_foreign_cash, v_deal.sell_currency_code, p_delivered_amount, v_deal.sale_rate_pkr, 0, v_cost, 'RMB delivered at cost');

  IF v_profit <> 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_spread, 'PKR', ABS(v_profit), 1, CASE WHEN v_profit < 0 THEN ABS(v_profit) ELSE 0 END, CASE WHEN v_profit > 0 THEN v_profit ELSE 0 END, 'FX spread income');
  END IF;

  PERFORM fx_post_transaction(v_tx_id);

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;
  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, delivery_target,
    linked_transaction_id, proof_reference, notes, completed_at
  ) VALUES (
    p_deal_id, v_leg_no, 'delivery'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, v_deal.customer_party_id,
    v_deal.sell_currency_code, p_delivered_amount, p_delivery_target,
    v_tx_id, p_proof_reference, p_notes, NOW()
  ) RETURNING id INTO v_leg_id;

  UPDATE fx_transactions SET leg_id = v_leg_id WHERE id = v_tx_id;

  UPDATE fx_currency_commitments SET
    delivered_amount = delivered_amount + p_delivered_amount,
    is_open = CASE WHEN delivered_amount + p_delivered_amount >= committed_amount THEN FALSE ELSE is_open END,
    updated_at = NOW()
  WHERE deal_id = p_deal_id AND commitment_type = 'customer_sale'::fx_commitment_type;

  UPDATE fx_deals SET
    status = 'completed'::fx_deal_status,
    actual_profit_pkr = v_profit,
    cost_basis_pkr = v_cost,
    completed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_deal_id;

  RETURN v_leg_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_get_deal_timeline
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_deal_timeline(p_deal_id UUID)
RETURNS TABLE (
  leg_id UUID,
  leg_no INT,
  leg_type fx_deal_leg_type,
  leg_status fx_deal_leg_status,
  counterparty_name TEXT,
  receive_currency TEXT,
  receive_amount NUMERIC,
  pay_currency TEXT,
  pay_amount NUMERIC,
  paid_amount NUMERIC,
  remaining_amount NUMERIC,
  proof_reference TEXT,
  notes TEXT,
  linked_transaction_no TEXT,
  created_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
BEGIN
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  RETURN QUERY
  SELECT
    l.id, l.leg_no, l.leg_type, l.status,
    p.name,
    l.receive_currency, l.receive_amount,
    l.pay_currency, l.pay_amount,
    l.paid_amount, l.remaining_amount,
    l.proof_reference, l.notes,
    t.transaction_no,
    l.created_at, l.completed_at
  FROM fx_deal_legs l
  LEFT JOIN fx_parties p ON p.id = l.counterparty_party_id
  LEFT JOIN fx_transactions t ON t.id = l.linked_transaction_id
  WHERE l.deal_id = p_deal_id
  ORDER BY l.leg_no;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_get_party_deal_open_items
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_party_deal_open_items(p_party_id UUID)
RETURNS TABLE (
  deal_id UUID,
  deal_no TEXT,
  deal_status fx_deal_status,
  sell_currency TEXT,
  sell_amount NUMERIC,
  customer_payable_pkr NUMERIC,
  customer_receivable_pkr NUMERIC,
  role TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id, d.deal_no, d.status,
    d.sell_currency_code, d.sell_amount,
    d.customer_payable_pkr, d.customer_receivable_pkr,
    'customer'::TEXT
  FROM fx_deals d
  WHERE d.customer_party_id = p_party_id
    AND d.status NOT IN ('completed', 'cancelled', 'voided')
    AND fx_same_branch(d.branch_id)
  UNION ALL
  SELECT
    d.id, d.deal_no, d.status,
    l.receive_currency, l.receive_amount,
    l.pay_amount, l.remaining_amount,
    'agent'::TEXT
  FROM fx_deal_legs l
  JOIN fx_deals d ON d.id = l.deal_id
  WHERE l.counterparty_party_id = p_party_id
    AND l.status IN ('pending', 'partial')
    AND d.status NOT IN ('cancelled', 'voided')
    AND fx_same_branch(d.branch_id);
END;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE fx_deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_deal_legs ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_currency_commitments ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_settlement_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fx_deals_select ON fx_deals;
DROP POLICY IF EXISTS fx_deals_write ON fx_deals;
DROP POLICY IF EXISTS fx_deal_legs_select ON fx_deal_legs;
DROP POLICY IF EXISTS fx_deal_legs_write ON fx_deal_legs;
DROP POLICY IF EXISTS fx_commitments_select ON fx_currency_commitments;
DROP POLICY IF EXISTS fx_commitments_write ON fx_currency_commitments;
DROP POLICY IF EXISTS fx_settlement_links_select ON fx_settlement_links;
DROP POLICY IF EXISTS fx_settlement_links_write ON fx_settlement_links;

CREATE POLICY fx_deals_select ON fx_deals
  FOR SELECT TO authenticated
  USING (fx_same_branch(branch_id) AND fx_has_permission('can_access_fx_ledger'));

CREATE POLICY fx_deals_write ON fx_deals
  FOR ALL TO authenticated
  USING (fx_same_branch(branch_id) AND fx_has_permission('can_access_fx_ledger'))
  WITH CHECK (fx_same_branch(branch_id) AND fx_has_permission('can_access_fx_ledger'));

CREATE POLICY fx_deal_legs_select ON fx_deal_legs
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  );

CREATE POLICY fx_deal_legs_write ON fx_deal_legs
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id))
  );

CREATE POLICY fx_commitments_select ON fx_currency_commitments
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  );

CREATE POLICY fx_commitments_write ON fx_currency_commitments
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id))
  );

CREATE POLICY fx_settlement_links_select ON fx_settlement_links
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  );

CREATE POLICY fx_settlement_links_write ON fx_settlement_links
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id))
  );

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

GRANT EXECUTE ON FUNCTION fx_generate_deal_no(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_currency_position_extended(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_book_customer_deal(UUID, UUID, TEXT, NUMERIC, NUMERIC, NUMERIC, fx_delivery_method, BOOLEAN, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_record_deal_customer_payment(UUID, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_add_deal_leg(UUID, fx_deal_leg_type, UUID, TEXT, NUMERIC, TEXT, NUMERIC, NUMERIC, fx_delivery_target, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_add_settlement_link(UUID, UUID, UUID, fx_settlement_link_type, TEXT, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_confirm_deal_delivery(UUID, NUMERIC, fx_delivery_target, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_deal_timeline(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_party_deal_open_items(UUID) TO authenticated;
