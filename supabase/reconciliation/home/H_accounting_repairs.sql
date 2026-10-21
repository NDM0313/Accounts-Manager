-- =============================================================================
-- H) ACCOUNTING REPAIRS (A1–A11 established fixes) — NOT DEFAULT-RUNNABLE
-- Apply ONLY after G_bundled_am_modules.sql on a disposable PG17 clone.
-- Does NOT invent cost-basis/TTP/valuation policies — see POLICY blockers below.
-- =============================================================================
-- Activation:
--   SELECT set_config('fx_reconciliation.confirm', 'APPLY_ACCOUNTING_REPAIRS', true);
-- =============================================================================

DO $guard$
BEGIN
  IF current_setting('fx_reconciliation.confirm', true) IS DISTINCT FROM 'APPLY_ACCOUNTING_REPAIRS' THEN
    RAISE EXCEPTION 'BLOCKED: set fx_reconciliation.confirm=APPLY_ACCOUNTING_REPAIRS';
  END IF;
  IF current_database() <> 'postgres' THEN
    RAISE EXCEPTION 'BLOCKED: expected database postgres';
  END IF;
  IF to_regclass('public.fx_remittances') IS NULL OR to_regclass('public.fx_deals') IS NULL THEN
    RAISE EXCEPTION 'BLOCKED: remittance/deal schema missing — run G first';
  END IF;
  PERFORM set_config('lock_timeout', '5s', true);
  PERFORM set_config('statement_timeout', '60s', true);
END
$guard$;

-- ---------------------------------------------------------------------------
-- A1–A3: Per-agent currency balances (owned custody vs payable credit)
-- available = owned - reserved; cannot go negative.
-- payable_pkr tracks amounts OWED TO agent (credit), separate from custody.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fx_agent_currency_balances (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id       UUID NOT NULL REFERENCES fx_branches (id) ON DELETE RESTRICT,
  agent_party_id  UUID NOT NULL REFERENCES fx_parties (id) ON DELETE RESTRICT,
  currency_code   TEXT NOT NULL,
  -- Currency units held by / for the agent (owned inventory at agent)
  owned_amount    NUMERIC(20, 8) NOT NULL DEFAULT 0
    CHECK (owned_amount >= 0),
  reserved_amount NUMERIC(20, 8) NOT NULL DEFAULT 0
    CHECK (reserved_amount >= 0),
  -- PKR payable credit owed to agent (liability), not currency custody
  payable_pkr     NUMERIC(20, 8) NOT NULL DEFAULT 0
    CHECK (payable_pkr >= 0),
  -- Optional carrying cost of owned stock in PKR (NULL until policy set)
  carrying_cost_pkr NUMERIC(20, 8),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (company_id, branch_id, agent_party_id, currency_code),
  CONSTRAINT fx_agent_bal_reserve_le_owned CHECK (reserved_amount <= owned_amount)
);

CREATE INDEX IF NOT EXISTS idx_fx_agent_currency_balances_agent
  ON fx_agent_currency_balances (agent_party_id, currency_code);

ALTER TABLE fx_agent_currency_balances ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fx_agent_currency_balances_select ON fx_agent_currency_balances;
CREATE POLICY fx_agent_currency_balances_select ON fx_agent_currency_balances
  FOR SELECT TO authenticated
  USING (fx_same_company(company_id));

CREATE OR REPLACE FUNCTION fx_agent_balance_available(
  p_company_id UUID, p_branch_id UUID, p_agent_party_id UUID, p_currency TEXT
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(owned_amount - reserved_amount, 0)
  FROM fx_agent_currency_balances
  WHERE company_id = p_company_id
    AND branch_id = p_branch_id
    AND agent_party_id = p_agent_party_id
    AND currency_code = upper(p_currency);
$$;

CREATE OR REPLACE FUNCTION fx_agent_balance_ensure(
  p_company_id UUID, p_branch_id UUID, p_agent_party_id UUID, p_currency TEXT
)
RETURNS fx_agent_currency_balances
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row fx_agent_currency_balances;
  v_cc TEXT := upper(p_currency);
BEGIN
  INSERT INTO fx_agent_currency_balances (company_id, branch_id, agent_party_id, currency_code)
  VALUES (p_company_id, p_branch_id, p_agent_party_id, v_cc)
  ON CONFLICT (company_id, branch_id, agent_party_id, currency_code) DO NOTHING;

  SELECT * INTO v_row FROM fx_agent_currency_balances
  WHERE company_id = p_company_id AND branch_id = p_branch_id
    AND agent_party_id = p_agent_party_id AND currency_code = v_cc
  FOR UPDATE;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION fx_agent_balance_reserve(
  p_company_id UUID, p_branch_id UUID, p_agent_party_id UUID,
  p_currency TEXT, p_amount NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row fx_agent_currency_balances;
BEGIN
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Reserve amount must be positive'; END IF;
  v_row := fx_agent_balance_ensure(p_company_id, p_branch_id, p_agent_party_id, p_currency);
  IF (v_row.owned_amount - v_row.reserved_amount) < p_amount THEN
    RAISE EXCEPTION 'Insufficient available agent currency: need % have %',
      p_amount, (v_row.owned_amount - v_row.reserved_amount);
  END IF;
  UPDATE fx_agent_currency_balances
  SET reserved_amount = reserved_amount + p_amount, updated_at = NOW()
  WHERE id = v_row.id;
END;
$$;

CREATE OR REPLACE FUNCTION fx_agent_balance_release_reserve(
  p_company_id UUID, p_branch_id UUID, p_agent_party_id UUID,
  p_currency TEXT, p_amount NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row fx_agent_currency_balances;
BEGIN
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Release amount must be positive'; END IF;
  v_row := fx_agent_balance_ensure(p_company_id, p_branch_id, p_agent_party_id, p_currency);
  IF v_row.reserved_amount < p_amount THEN
    RAISE EXCEPTION 'Cannot release more than reserved';
  END IF;
  UPDATE fx_agent_currency_balances
  SET reserved_amount = reserved_amount - p_amount, updated_at = NOW()
  WHERE id = v_row.id;
END;
$$;

CREATE OR REPLACE FUNCTION fx_agent_balance_consume_reserve(
  p_company_id UUID, p_branch_id UUID, p_agent_party_id UUID,
  p_currency TEXT, p_amount NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row fx_agent_currency_balances;
BEGIN
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Consume amount must be positive'; END IF;
  v_row := fx_agent_balance_ensure(p_company_id, p_branch_id, p_agent_party_id, p_currency);
  IF v_row.reserved_amount < p_amount OR v_row.owned_amount < p_amount THEN
    RAISE EXCEPTION 'Cannot consume reserve/owned for amount %', p_amount;
  END IF;
  UPDATE fx_agent_currency_balances
  SET reserved_amount = reserved_amount - p_amount,
      owned_amount = owned_amount - p_amount,
      updated_at = NOW()
  WHERE id = v_row.id;
END;
$$;

-- ---------------------------------------------------------------------------
-- A11: Idempotency registry for money RPCs
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fx_client_operations (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  operation_key     TEXT NOT NULL,
  operation_type    TEXT NOT NULL,
  entity_type       TEXT NOT NULL,
  entity_id         UUID NOT NULL,
  result_json       JSONB,
  created_by        UUID REFERENCES auth.users (id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (company_id, operation_key)
);

ALTER TABLE fx_client_operations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS fx_client_operations_select ON fx_client_operations;
CREATE POLICY fx_client_operations_select ON fx_client_operations
  FOR SELECT TO authenticated
  USING (fx_same_company(company_id));

-- ---------------------------------------------------------------------------
-- Remittance columns for A5/A7/A10
-- ---------------------------------------------------------------------------

ALTER TABLE fx_remittances
  ADD COLUMN IF NOT EXISTS commission_recognized_pkr NUMERIC(20, 8) NOT NULL DEFAULT 0
    CHECK (commission_recognized_pkr >= 0);

ALTER TABLE fx_remittances
  ADD COLUMN IF NOT EXISTS settled_amount_pkr NUMERIC(20, 8) NOT NULL DEFAULT 0
    CHECK (settled_amount_pkr >= 0);

ALTER TABLE fx_remittances
  ADD COLUMN IF NOT EXISTS refunded_amount_pkr NUMERIC(20, 8) NOT NULL DEFAULT 0
    CHECK (refunded_amount_pkr >= 0);

ALTER TABLE fx_remittances
  ADD COLUMN IF NOT EXISTS reserved_payout_currency TEXT;

ALTER TABLE fx_remittances
  ADD COLUMN IF NOT EXISTS reserved_payout_amount NUMERIC(20, 8) NOT NULL DEFAULT 0
    CHECK (reserved_payout_amount >= 0);

ALTER TABLE fx_remittances
  ADD COLUMN IF NOT EXISTS payout_funding_mode TEXT
    CHECK (payout_funding_mode IS NULL OR payout_funding_mode IN ('agent_owned_balance', 'agent_credit_payable'));

-- ---------------------------------------------------------------------------
-- A5: Partial customer payment — recognize commission only once (remainder)
-- A11: optional p_client_operation_id
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_record_remittance_customer_payment(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_client_operation_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_cash UUID;
  v_liability UUID;
  v_commission UUID;
  v_pay NUMERIC(20, 8);
  v_comm NUMERIC(20, 8);
  v_comm_remaining NUMERIC(20, 8);
  v_new_paid NUMERIC(20, 8);
  v_new_status fx_remittance_status;
  v_old_status TEXT;
  v_existing UUID;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;

  IF p_client_operation_id IS NOT NULL THEN
    SELECT (result_json->>'transaction_id')::uuid INTO v_existing
    FROM fx_client_operations
    WHERE company_id = v_r.company_id AND operation_key = p_client_operation_id;
    IF v_existing IS NOT NULL THEN
      RETURN v_existing;
    END IF;
  END IF;

  IF v_r.status NOT IN ('booked', 'customer_paid') THEN
    RAISE EXCEPTION 'Invalid status for customer payment: %', v_r.status;
  END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;
  IF v_r.paid_amount + p_amount > v_r.total_payable + 0.00000001 THEN
    RAISE EXCEPTION 'Payment exceeds total payable';
  END IF;

  v_old_status := v_r.status::TEXT;
  v_cash := CASE WHEN p_cash_account_code IS NOT NULL THEN fx_account_id_by_code(v_r.company_id, p_cash_account_code)
    ELSE COALESCE(fx_cash_account_for_currency(v_r.company_id, v_r.receive_currency), fx_account_id_by_code(v_r.company_id, '1110')) END;
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_commission := fx_account_id_by_code(v_r.company_id, '4310');

  -- A5: only recognize remaining unrecognized commission
  IF v_r.commission_mode = 'customer_paid' THEN
    v_comm_remaining := GREATEST(0, v_r.commission_amount - v_r.commission_recognized_pkr);
    v_comm := LEAST(p_amount, v_comm_remaining);
  ELSE
    v_comm := 0;
  END IF;
  v_pay := p_amount - v_comm;
  v_new_paid := v_r.paid_amount + p_amount;
  v_new_status := CASE WHEN v_new_paid >= v_r.total_payable THEN 'customer_paid'::fx_remittance_status ELSE 'booked'::fx_remittance_status END;

  INSERT INTO fx_transactions (company_id, branch_id, transaction_type, status, transaction_date, party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr, description, remittance_id, created_by)
  VALUES (v_r.company_id, v_r.branch_id, 'settlement_receive', 'draft', CURRENT_DATE, v_r.sender_party_id, v_r.receive_currency, p_amount, 1, p_amount,
    COALESCE(p_notes, 'Remittance customer payment ' || v_r.tracking_id), p_remittance_id, auth.uid())
  RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, 1, v_cash, v_r.receive_currency, p_amount, 1, p_amount, 0, 'Customer payment received');
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, 2, v_liability, v_r.receive_currency, v_pay, 1, 0, v_pay, 'Remittance liability');
  IF v_comm > 0 THEN
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, 3, v_commission, v_r.receive_currency, v_comm, 1, 0, v_comm, 'Commission income');
  END IF;

  PERFORM fx_post_transaction(v_tx_id);
  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose) VALUES (p_remittance_id, v_tx_id, 'customer_payment');
  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, amount, currency_code, linked_transaction_id, notes, created_by)
  VALUES (p_remittance_id, v_event_no, 'customer_payment', v_new_status, p_amount, v_r.receive_currency, v_tx_id, p_notes, auth.uid());

  UPDATE fx_remittances SET
    paid_amount = v_new_paid,
    commission_recognized_pkr = commission_recognized_pkr + v_comm,
    status = v_new_status,
    updated_by = auth.uid(),
    updated_at = NOW()
  WHERE id = p_remittance_id;

  IF p_client_operation_id IS NOT NULL THEN
    INSERT INTO fx_client_operations (company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by)
    VALUES (v_r.company_id, p_client_operation_id, 'remittance_customer_payment', 'fx_remittance', p_remittance_id,
      jsonb_build_object('transaction_id', v_tx_id), auth.uid());
  END IF;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- A7: Partial agent settlement — do not complete early
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_settle_remittance_agent(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT '1110',
  p_notes TEXT DEFAULT NULL,
  p_client_operation_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_cash UUID;
  v_agent_pay UUID;
  v_old_status TEXT;
  v_new_settled NUMERIC(20, 8);
  v_due NUMERIC(20, 8);
  v_settlement_status fx_remittance_settlement_status;
  v_new_status fx_remittance_status;
  v_existing UUID;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  IF p_client_operation_id IS NOT NULL THEN
    SELECT (result_json->>'transaction_id')::uuid INTO v_existing
    FROM fx_client_operations
    WHERE company_id = v_r.company_id AND operation_key = p_client_operation_id;
    IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;
  END IF;

  -- Due = receive amount in PKR terms for settlement (existing design uses PKR cash)
  v_due := v_r.receive_amount; -- POLICY: settlement currency basis may need revision
  v_new_settled := v_r.settled_amount_pkr + p_amount;
  IF v_new_settled > v_due + 0.00000001 THEN
    RAISE EXCEPTION 'Settlement exceeds remaining due (settled % + % > %)', v_r.settled_amount_pkr, p_amount, v_due;
  END IF;

  v_old_status := v_r.status::TEXT;
  v_cash := fx_account_id_by_code(v_r.company_id, p_cash_account_code);
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');

  INSERT INTO fx_transactions (company_id, branch_id, transaction_type, status, transaction_date, party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr, description, remittance_id, created_by)
  VALUES (v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', CURRENT_DATE, v_r.payout_agent_party_id, 'PKR', p_amount, 1, p_amount, COALESCE(p_notes, 'Agent settlement ' || v_r.tracking_id), p_remittance_id, auth.uid())
  RETURNING id INTO v_tx_id;
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo) VALUES
    (v_tx_id, 1, v_agent_pay, 'PKR', p_amount, 1, p_amount, 0, 'Settle agent payable'),
    (v_tx_id, 2, v_cash, 'PKR', p_amount, 1, 0, p_amount, 'Cash paid to agent');
  PERFORM fx_post_transaction(v_tx_id);
  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose) VALUES (p_remittance_id, v_tx_id, 'agent_settlement');

  IF v_new_settled + 0.00000001 >= v_due THEN
    v_settlement_status := 'settled';
    v_new_status := 'completed';
  ELSE
    v_settlement_status := 'partial';
    v_new_status := v_r.status; -- remain in current operational status
  END IF;

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, amount, currency_code, linked_transaction_id, notes, created_by)
  VALUES (p_remittance_id, v_event_no, 'agent_settlement', v_new_status, p_amount, 'PKR', v_tx_id, p_notes, auth.uid());

  UPDATE fx_remittances SET
    settled_amount_pkr = v_new_settled,
    settlement_status = v_settlement_status,
    status = v_new_status,
    completed_at = CASE WHEN v_new_status = 'completed' THEN NOW() ELSE completed_at END,
    updated_by = auth.uid(),
    updated_at = NOW()
  WHERE id = p_remittance_id;

  IF p_client_operation_id IS NOT NULL THEN
    INSERT INTO fx_client_operations (company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by)
    VALUES (v_r.company_id, p_client_operation_id, 'remittance_agent_settlement', 'fx_remittance', p_remittance_id,
      jsonb_build_object('transaction_id', v_tx_id), auth.uid());
  END IF;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- A9: Currency receipt must target a specific agent_source leg (parent_leg_id)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_add_deal_leg_v2(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_leg_no INT;
  v_leg_id UUID;
  v_deal_id UUID := (p_payload->>'deal_id')::UUID;
  v_leg_type fx_deal_leg_type := (p_payload->>'leg_type')::fx_deal_leg_type;
  v_receive_currency TEXT := NULLIF(p_payload->>'receive_currency', '');
  v_receive_amount NUMERIC := COALESCE((p_payload->>'receive_amount')::NUMERIC, 0);
  v_pay_currency TEXT := NULLIF(p_payload->>'pay_currency', '');
  v_pay_amount NUMERIC := COALESCE((p_payload->>'pay_amount')::NUMERIC, 0);
  v_rate_used NUMERIC := NULLIF(p_payload->>'rate_used', '')::NUMERIC;
  v_delivery_target fx_delivery_target := NULLIF(p_payload->>'delivery_target', '')::fx_delivery_target;
  v_parent_leg_id UUID := NULLIF(p_payload->>'parent_leg_id', '')::UUID;
  v_counterparty UUID := NULLIF(p_payload->>'counterparty_party_id', '')::UUID;
  v_notes TEXT := NULLIF(p_payload->>'notes', '');
  v_linked_tx UUID := NULLIF(p_payload->>'linked_transaction_id', '')::UUID;
  v_leg_status fx_deal_leg_status := CASE
    WHEN v_leg_type = 'currency_receipt' THEN 'completed'::fx_deal_leg_status
    ELSE 'pending'::fx_deal_leg_status
  END;
  v_source fx_deal_legs;
  v_remaining NUMERIC;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_deal FROM fx_deals WHERE id = v_deal_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  IF v_leg_type = 'currency_receipt' THEN
    IF v_parent_leg_id IS NULL THEN
      RAISE EXCEPTION 'currency_receipt requires parent_leg_id targeting agent_source';
    END IF;
    SELECT * INTO v_source FROM fx_deal_legs WHERE id = v_parent_leg_id FOR UPDATE;
    IF NOT FOUND OR v_source.deal_id <> v_deal_id THEN
      RAISE EXCEPTION 'parent_leg_id not found on deal';
    END IF;
    IF v_source.leg_type <> 'agent_source'::fx_deal_leg_type THEN
      RAISE EXCEPTION 'parent_leg_id must be agent_source';
    END IF;
    IF v_source.status NOT IN ('pending', 'partial') THEN
      RAISE EXCEPTION 'agent_source leg not open for receipt';
    END IF;
    v_remaining := GREATEST(0, v_source.receive_amount - v_source.paid_amount);
    IF v_receive_amount <= 0 OR v_receive_amount > v_remaining + 0.00000001 THEN
      RAISE EXCEPTION 'Receipt amount % exceeds remaining on source leg %', v_receive_amount, v_remaining;
    END IF;
  END IF;

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = v_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    paid_amount, remaining_amount, delivery_target, parent_leg_id, notes,
    linked_transaction_id, completed_at
  ) VALUES (
    v_deal_id, v_leg_no, v_leg_type, v_leg_status, v_counterparty,
    CASE WHEN v_receive_currency IS NOT NULL THEN fx_normalize_currency_code(v_receive_currency) ELSE NULL END,
    v_receive_amount,
    CASE WHEN v_pay_currency IS NOT NULL THEN fx_normalize_currency_code(v_pay_currency) ELSE NULL END,
    v_pay_amount, v_rate_used,
    CASE WHEN v_leg_type = 'currency_receipt' THEN v_receive_amount ELSE 0 END,
    CASE WHEN v_leg_type = 'currency_receipt' THEN 0 ELSE COALESCE(v_pay_amount, v_receive_amount, 0) END,
    v_delivery_target, v_parent_leg_id, v_notes,
    v_linked_tx,
    CASE WHEN v_leg_status = 'completed' THEN NOW() ELSE NULL END
  ) RETURNING id INTO v_leg_id;

  IF v_leg_type = 'agent_source' THEN
    UPDATE fx_deals SET status = 'sourcing_in_progress'::fx_deal_status, updated_at = NOW() WHERE id = v_deal_id;
    INSERT INTO fx_currency_commitments (deal_id, leg_id, currency_code, commitment_type, committed_amount)
    VALUES (
      v_deal_id, v_leg_id,
      fx_normalize_currency_code(v_receive_currency),
      'on_order_inbound'::fx_commitment_type,
      v_receive_amount
    );
  ELSIF v_leg_type = 'currency_receipt' THEN
    -- A8/A9: update ONLY the targeted source leg proportionally
    UPDATE fx_deal_legs SET
      paid_amount = paid_amount + v_receive_amount,
      remaining_amount = GREATEST(0, receive_amount - (paid_amount + v_receive_amount)),
      status = CASE
        WHEN paid_amount + v_receive_amount + 0.00000001 >= receive_amount THEN 'completed'::fx_deal_leg_status
        ELSE 'partial'::fx_deal_leg_status
      END,
      completed_at = CASE
        WHEN paid_amount + v_receive_amount + 0.00000001 >= receive_amount THEN COALESCE(completed_at, NOW())
        ELSE completed_at
      END,
      linked_transaction_id = COALESCE(linked_transaction_id, v_linked_tx),
      updated_at = NOW()
    WHERE id = v_parent_leg_id;

    IF v_deal.status NOT IN ('delivered', 'completed', 'cancelled', 'voided') THEN
      UPDATE fx_deals SET status = 'currency_received'::fx_deal_status, updated_at = NOW() WHERE id = v_deal_id;
    END IF;
  END IF;

  RETURN v_leg_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- A10: Refund caps + idempotency (RPC may lack Flutter UI yet)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_refund_remittance(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_client_operation_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_refundable NUMERIC(20, 8);
  v_existing UUID;
  v_event_no INT;
  v_cash UUID;
  v_liability UUID;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;

  IF p_client_operation_id IS NOT NULL THEN
    SELECT (result_json->>'transaction_id')::uuid INTO v_existing
    FROM fx_client_operations
    WHERE company_id = v_r.company_id AND operation_key = p_client_operation_id;
    IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;
  END IF;

  IF v_r.status IN ('cancelled') THEN RAISE EXCEPTION 'Cannot refund cancelled remittance'; END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  v_refundable := GREATEST(0, v_r.paid_amount - v_r.refunded_amount_pkr);
  IF p_amount > v_refundable + 0.00000001 THEN
    RAISE EXCEPTION 'Refund % exceeds refundable %', p_amount, v_refundable;
  END IF;

  v_cash := CASE WHEN p_cash_account_code IS NOT NULL THEN fx_account_id_by_code(v_r.company_id, p_cash_account_code)
    ELSE COALESCE(fx_cash_account_for_currency(v_r.company_id, v_r.receive_currency), fx_account_id_by_code(v_r.company_id, '1110')) END;
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');

  INSERT INTO fx_transactions (company_id, branch_id, transaction_type, status, transaction_date, party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr, description, remittance_id, created_by)
  VALUES (v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', CURRENT_DATE, v_r.sender_party_id, v_r.receive_currency, p_amount, 1, p_amount,
    COALESCE(p_notes, 'Remittance refund ' || v_r.tracking_id), p_remittance_id, auth.uid())
  RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo) VALUES
    (v_tx_id, 1, v_liability, v_r.receive_currency, p_amount, 1, p_amount, 0, 'Reduce remittance liability'),
    (v_tx_id, 2, v_cash, v_r.receive_currency, p_amount, 1, 0, p_amount, 'Cash refund to customer');
  -- NOTE: commission reversal policy is POLICY-DEPENDENT — not auto-reversed here.

  PERFORM fx_post_transaction(v_tx_id);
  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose) VALUES (p_remittance_id, v_tx_id, 'refund');
  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, amount, currency_code, linked_transaction_id, notes, created_by)
  VALUES (p_remittance_id, v_event_no, 'refund',
    CASE WHEN v_r.refunded_amount_pkr + p_amount + 0.00000001 >= v_r.paid_amount THEN 'refunded'::fx_remittance_status ELSE v_r.status END,
    p_amount, v_r.receive_currency, v_tx_id, p_notes, auth.uid());

  UPDATE fx_remittances SET
    refunded_amount_pkr = refunded_amount_pkr + p_amount,
    status = CASE WHEN refunded_amount_pkr + p_amount + 0.00000001 >= paid_amount THEN 'refunded'::fx_remittance_status ELSE status END,
    updated_by = auth.uid(),
    updated_at = NOW()
  WHERE id = p_remittance_id;

  IF p_client_operation_id IS NOT NULL THEN
    INSERT INTO fx_client_operations (company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by)
    VALUES (v_r.company_id, p_client_operation_id, 'remittance_refund', 'fx_remittance', p_remittance_id,
      jsonb_build_object('transaction_id', v_tx_id), auth.uid());
  END IF;

  RETURN v_tx_id;
END;
$$;

REVOKE ALL ON FUNCTION fx_record_remittance_customer_payment(UUID, NUMERIC, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION fx_settle_remittance_agent(UUID, NUMERIC, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION fx_refund_remittance(UUID, NUMERIC, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION fx_add_deal_leg_v2(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_record_remittance_customer_payment(UUID, NUMERIC, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_settle_remittance_agent(UUID, NUMERIC, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_refund_remittance(UUID, NUMERIC, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_add_deal_leg_v2(JSONB) TO authenticated;

-- ---------------------------------------------------------------------------
-- POLICY BLOCKERS (do not invent defaults that invent zero profit)
-- ---------------------------------------------------------------------------
-- P1 TTP meaning — unresolved
-- P2 Cost basis for owned FX inventory (FIFO / weighted average / explicit lot)
-- P3 Whether refund reverses commission income and in what order
-- P4 Settlement due currency (PKR vs receive_currency) for agent settle
-- P5 Unrealized FX revaluation frequency and accounts
-- Until P2 is decided: carrying_cost_pkr may stay NULL; reports must NOT
-- silently use sale proceeds as purchase cost.
