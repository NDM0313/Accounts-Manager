-- =============================================================================
-- I) REMAINING FIXES: policy gate, A6 recon, A8 partial delivery, cost never=sale
-- Activation: set fx_reconciliation.confirm = 'APPLY_REMAINING_FIXES'
-- =============================================================================

DO $guard$
BEGIN
  IF current_setting('fx_reconciliation.confirm', true) IS DISTINCT FROM 'APPLY_REMAINING_FIXES' THEN
    RAISE EXCEPTION 'BLOCKED: set fx_reconciliation.confirm=APPLY_REMAINING_FIXES';
  END IF;
  IF to_regclass('public.fx_deals') IS NULL THEN
    RAISE EXCEPTION 'BLOCKED: fx_deals missing';
  END IF;
END
$guard$;

-- Persisted accounting policy config (no silent financially material defaults)
CREATE TABLE IF NOT EXISTS fx_accounting_policies (
  company_id UUID PRIMARY KEY REFERENCES fx_companies(id) ON DELETE RESTRICT,
  -- NULL = not configured (block affected operations)
  cost_basis_method TEXT CHECK (cost_basis_method IS NULL OR cost_basis_method IN ('explicit_lot','weighted_average','fifo')),
  refund_reverses_commission BOOLEAN,
  settlement_due_basis TEXT CHECK (settlement_due_basis IS NULL OR settlement_due_basis IN ('receive_amount','payout_amount','explicit')),
  ttp_meaning TEXT, -- intentionally free-text; never assumed
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by UUID REFERENCES auth.users(id)
);

ALTER TABLE fx_accounting_policies ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS fx_accounting_policies_select ON fx_accounting_policies;
CREATE POLICY fx_accounting_policies_select ON fx_accounting_policies
  FOR SELECT TO authenticated USING (fx_same_company(company_id));

-- Payload consistency for idempotency keys
ALTER TABLE fx_client_operations
  ADD COLUMN IF NOT EXISTS request_hash TEXT;

ALTER TABLE fx_deals
  ADD COLUMN IF NOT EXISTS delivered_amount NUMERIC(20,8) NOT NULL DEFAULT 0 CHECK (delivered_amount >= 0);

ALTER TABLE fx_deals
  ADD COLUMN IF NOT EXISTS delivered_cost_basis_pkr NUMERIC(20,8) NOT NULL DEFAULT 0 CHECK (delivered_cost_basis_pkr >= 0);

-- ---------------------------------------------------------------------------
-- A6: original-currency vs PKR journal reconciliation
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_currency_pkr_reconciliation(
  p_branch_id UUID,
  p_from DATE DEFAULT NULL,
  p_to DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  currency_code TEXT,
  foreign_debit NUMERIC,
  foreign_credit NUMERIC,
  pkr_debit NUMERIC,
  pkr_credit NUMERIC,
  foreign_net NUMERIC,
  pkr_net NUMERIC,
  implied_avg_rate NUMERIC,
  journal_entry_count BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch';
  END IF;

  RETURN QUERY
  SELECT
    jl.currency_code,
    COALESCE(SUM(jl.foreign_amount) FILTER (WHERE jl.debit_pkr > 0), 0),
    COALESCE(SUM(jl.foreign_amount) FILTER (WHERE jl.credit_pkr > 0), 0),
    COALESCE(SUM(jl.debit_pkr), 0),
    COALESCE(SUM(jl.credit_pkr), 0),
    COALESCE(SUM(jl.foreign_amount) FILTER (WHERE jl.debit_pkr > 0), 0)
      - COALESCE(SUM(jl.foreign_amount) FILTER (WHERE jl.credit_pkr > 0), 0),
    COALESCE(SUM(jl.debit_pkr), 0) - COALESCE(SUM(jl.credit_pkr), 0),
    CASE
      WHEN COALESCE(SUM(jl.foreign_amount) FILTER (WHERE jl.debit_pkr > 0 OR jl.credit_pkr > 0), 0) = 0 THEN NULL
      ELSE ROUND(
        (COALESCE(SUM(jl.debit_pkr),0) + COALESCE(SUM(jl.credit_pkr),0))
        / NULLIF(COALESCE(SUM(jl.foreign_amount) FILTER (WHERE jl.debit_pkr > 0 OR jl.credit_pkr > 0), 0), 0)
      , 8)
    END,
    COUNT(DISTINCT je.id)
  FROM fx_journal_lines jl
  JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
  WHERE je.branch_id = p_branch_id
    AND je.is_void IS NOT TRUE
    AND (p_from IS NULL OR je.entry_date >= p_from)
    AND je.entry_date <= p_to
  GROUP BY jl.currency_code
  ORDER BY jl.currency_code;
END;
$$;

REVOKE ALL ON FUNCTION fx_get_currency_pkr_reconciliation(UUID, DATE, DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_get_currency_pkr_reconciliation(UUID, DATE, DATE) TO authenticated;

-- ---------------------------------------------------------------------------
-- A8: Partial delivery — proportional PKR; NEVER default cost to sale
-- ---------------------------------------------------------------------------

-- Drop obsolete overloads so Flutter/RPC contracts resolve uniquely
DROP FUNCTION IF EXISTS fx_confirm_deal_delivery(UUID, NUMERIC, fx_delivery_target, NUMERIC, TEXT, TEXT);
DROP FUNCTION IF EXISTS fx_confirm_deal_delivery(UUID, NUMERIC, fx_delivery_target, NUMERIC, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION fx_confirm_deal_delivery(
  p_deal_id UUID,
  p_delivered_amount NUMERIC,
  p_delivery_target fx_delivery_target DEFAULT 'direct_to_customer',
  p_cost_basis_pkr NUMERIC DEFAULT NULL,
  p_proof_reference TEXT DEFAULT NULL,
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
  v_tx_id UUID;
  v_leg_no INT;
  v_leg_id UUID;
  v_cost NUMERIC;
  v_sale_portion NUMERIC;
  v_profit NUMERIC;
  v_paid_portion NUMERIC;
  v_recv_portion NUMERIC;
  v_ratio NUMERIC;
  v_remaining NUMERIC;
  v_foreign_cash UUID;
  v_advances UUID;
  v_receivable UUID;
  v_spread UUID;
  v_line_no INT := 0;
  v_new_delivered NUMERIC;
  v_new_cost_total NUMERIC;
  v_status fx_deal_status;
  v_existing UUID;
  v_req_hash TEXT;
  v_prev_hash TEXT;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  v_req_hash := md5(concat_ws('|',
    p_deal_id::text, p_delivered_amount::text, COALESCE(p_delivery_target::text,''),
    COALESCE(p_cost_basis_pkr::text,''), COALESCE(p_proof_reference,'')));

  IF p_client_operation_id IS NOT NULL THEN
    SELECT (result_json->>'leg_id')::uuid, request_hash
      INTO v_existing, v_prev_hash
    FROM fx_client_operations
    WHERE company_id = v_deal.company_id AND operation_key = p_client_operation_id;
    IF v_existing IS NOT NULL THEN
      IF v_prev_hash IS NOT NULL AND v_prev_hash IS DISTINCT FROM v_req_hash THEN
        RAISE EXCEPTION 'Idempotency key reused with different payload';
      END IF;
      RETURN v_existing;
    END IF;
  END IF;

  IF p_delivered_amount IS NULL OR p_delivered_amount <= 0 THEN
    RAISE EXCEPTION 'Delivered amount must be positive';
  END IF;

  v_remaining := GREATEST(0, v_deal.sell_amount - v_deal.delivered_amount);
  IF p_delivered_amount > v_remaining + 0.00000001 THEN
    RAISE EXCEPTION 'Delivery % exceeds remaining %', p_delivered_amount, v_remaining;
  END IF;

  -- Cost MUST be explicit for this slice (or pre-set on deal). Never use sale as cost.
  v_cost := COALESCE(p_cost_basis_pkr, NULL);
  IF v_cost IS NULL THEN
    RAISE EXCEPTION 'cost_basis_pkr required for delivery slice (will not default to sale value)';
  END IF;
  IF v_cost < 0 THEN RAISE EXCEPTION 'cost_basis_pkr must be >= 0'; END IF;

  v_ratio := p_delivered_amount / NULLIF(v_deal.sell_amount, 0);
  v_sale_portion := ROUND(v_deal.customer_payable_pkr * v_ratio, 8);
  v_paid_portion := ROUND(v_deal.customer_paid_pkr * v_ratio, 8);
  v_recv_portion := ROUND(v_deal.customer_receivable_pkr * v_ratio, 8);
  -- Rebalance rounding to sale_portion
  IF ABS((v_paid_portion + v_recv_portion) - v_sale_portion) > 0.0001 THEN
    v_recv_portion := v_sale_portion - v_paid_portion;
  END IF;
  v_profit := v_sale_portion - v_cost;

  v_foreign_cash := fx_account_id_by_code(v_deal.company_id,
    CASE fx_normalize_currency_code(v_deal.sell_currency_code)
      WHEN 'PKR' THEN '1110' WHEN 'USD' THEN '1120' WHEN 'AED' THEN '1130'
      WHEN 'CNY' THEN '1140' WHEN 'SAR' THEN '1150' ELSE '1110'
    END);
  v_advances := fx_account_id_by_code(v_deal.company_id, '1160');
  v_receivable := fx_account_id_by_code(v_deal.company_id, '1190');
  v_spread := fx_account_id_by_code(v_deal.company_id, '4100');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, created_by
  ) VALUES (
    v_deal.company_id, v_deal.branch_id, 'currency_sell', 'draft', CURRENT_DATE,
    v_deal.customer_party_id, v_deal.sell_currency_code, p_delivered_amount,
    v_deal.sale_rate_pkr, v_sale_portion,
    COALESCE(p_notes, 'Partial delivery — deal ' || v_deal.deal_no),
    p_deal_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  IF v_paid_portion > 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_advances, 'PKR', v_paid_portion, 1, v_paid_portion, 0, 'Clear customer advance (portion)');
  END IF;
  IF v_recv_portion > 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_receivable, 'PKR', v_recv_portion, 1, v_recv_portion, 0, 'Customer receivable (portion)');
  END IF;

  v_line_no := v_line_no + 1;
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, v_line_no, v_foreign_cash, v_deal.sell_currency_code, p_delivered_amount, v_deal.sale_rate_pkr, 0, v_cost, 'Currency delivered at explicit cost');

  IF v_profit <> 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_spread, 'PKR', ABS(v_profit), 1,
      CASE WHEN v_profit < 0 THEN ABS(v_profit) ELSE 0 END,
      CASE WHEN v_profit > 0 THEN v_profit ELSE 0 END,
      'FX spread on delivery slice');
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

  UPDATE fx_currency_commitments SET
    delivered_amount = delivered_amount + p_delivered_amount,
    is_open = CASE WHEN delivered_amount + p_delivered_amount + 0.00000001 >= committed_amount THEN FALSE ELSE TRUE END,
    updated_at = NOW()
  WHERE deal_id = p_deal_id AND commitment_type = 'customer_sale'::fx_commitment_type;

  v_new_delivered := v_deal.delivered_amount + p_delivered_amount;
  v_new_cost_total := v_deal.delivered_cost_basis_pkr + v_cost;
  v_status := CASE
    WHEN v_new_delivered + 0.00000001 >= v_deal.sell_amount THEN 'completed'::fx_deal_status
    ELSE 'delivered'::fx_deal_status
  END;

  UPDATE fx_deals SET
    delivered_amount = v_new_delivered,
    delivered_cost_basis_pkr = v_new_cost_total,
    cost_basis_pkr = v_new_cost_total,
    actual_profit_pkr = ROUND(customer_payable_pkr * (v_new_delivered / NULLIF(sell_amount, 0)), 8) - v_new_cost_total,
    status = v_status,
    completed_at = CASE WHEN v_status = 'completed' THEN NOW() ELSE completed_at END,
    updated_at = NOW()
  WHERE id = p_deal_id;

  IF p_client_operation_id IS NOT NULL THEN
    INSERT INTO fx_client_operations (company_id, operation_key, operation_type, entity_type, entity_id, result_json, request_hash, created_by)
    VALUES (v_deal.company_id, p_client_operation_id, 'deal_delivery', 'fx_deal', p_deal_id,
      jsonb_build_object('leg_id', v_leg_id, 'transaction_id', v_tx_id), v_req_hash, auth.uid());
  END IF;

  RETURN v_leg_id;
END;
$$;

REVOKE ALL ON FUNCTION fx_confirm_deal_delivery(UUID, NUMERIC, fx_delivery_target, NUMERIC, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_confirm_deal_delivery(UUID, NUMERIC, fx_delivery_target, NUMERIC, TEXT, TEXT, TEXT) TO authenticated;
