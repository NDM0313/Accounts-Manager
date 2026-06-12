-- H6: Remittance notifications + audit trail
-- Project: ygidlcqhupmxvsdjmvnf only

CREATE TABLE IF NOT EXISTS fx_notifications (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id          UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id           UUID REFERENCES fx_branches (id) ON DELETE RESTRICT,
  recipient_user_id   UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  remittance_id       UUID REFERENCES fx_remittances (id) ON DELETE CASCADE,
  event_type          TEXT NOT NULL,
  title               TEXT NOT NULL,
  body                TEXT NOT NULL,
  payload             JSONB NOT NULL DEFAULT '{}',
  read_at             TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fx_notifications_recipient ON fx_notifications (recipient_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fx_notifications_remittance ON fx_notifications (remittance_id);

ALTER TABLE fx_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fx_notifications_select ON fx_notifications;
CREATE POLICY fx_notifications_select ON fx_notifications
  FOR SELECT TO authenticated
  USING (
    recipient_user_id = auth.uid()
    OR (branch_id IS NOT NULL AND fx_same_branch(branch_id) AND fx_has_permission('can_manage_remittance'))
  );

DROP POLICY IF EXISTS fx_notifications_update ON fx_notifications;
CREATE POLICY fx_notifications_update ON fx_notifications
  FOR UPDATE TO authenticated
  USING (recipient_user_id = auth.uid())
  WITH CHECK (recipient_user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_remittance_write_audit(
  p_remittance_id UUID,
  p_action fx_audit_action,
  p_old_status TEXT,
  p_new_status TEXT,
  p_amount NUMERIC DEFAULT NULL,
  p_note TEXT DEFAULT NULL,
  p_proof_reference TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_role TEXT;
BEGIN
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RETURN; END IF;

  SELECT r.name INTO v_role
  FROM fx_user_roles ur
  JOIN fx_roles r ON r.id = ur.role_id
  WHERE ur.user_id = auth.uid()
  LIMIT 1;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, old_value, new_value, actor_id)
  VALUES (
    v_r.company_id,
    v_r.branch_id,
    'fx_remittances',
    p_remittance_id,
    p_action,
    jsonb_build_object('status', p_old_status, 'amount', p_amount, 'note', p_note, 'proof', p_proof_reference),
    jsonb_build_object('status', p_new_status, 'amount', p_amount, 'note', p_note, 'proof', p_proof_reference, 'role', v_role),
    auth.uid()
  );
END;
$$;

CREATE OR REPLACE FUNCTION fx_remittance_notify_branch(
  p_remittance_id UUID,
  p_event_type TEXT,
  p_title TEXT,
  p_body TEXT,
  p_payload JSONB DEFAULT '{}'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_user RECORD;
BEGIN
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RETURN; END IF;

  FOR v_user IN
    SELECT DISTINCT u.id AS user_id
    FROM (
      SELECT v_r.created_by AS id WHERE v_r.created_by IS NOT NULL
      UNION
      SELECT p.id FROM fx_users_profiles p
      JOIN fx_user_roles ur ON ur.user_id = p.id
      JOIN fx_roles r ON r.id = ur.role_id
      WHERE p.branch_id = v_r.branch_id
        AND p.is_active
        AND ('can_manage_remittance' = ANY (r.permissions) OR 'can_post_fx_transaction' = ANY (r.permissions))
    ) u
    WHERE u.id IS NOT NULL
  LOOP
    INSERT INTO fx_notifications (
      company_id, branch_id, recipient_user_id, remittance_id,
      event_type, title, body, payload
    ) VALUES (
      v_r.company_id, v_r.branch_id, v_user.user_id, p_remittance_id,
      p_event_type, p_title, p_body, p_payload
    );
  END LOOP;
END;
$$;

-- Patch payment RPC with audit + notify
CREATE OR REPLACE FUNCTION fx_record_remittance_customer_payment(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
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
  v_new_paid NUMERIC(20, 8);
  v_new_status fx_remittance_status;
  v_old_status TEXT;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status NOT IN ('booked', 'customer_paid') THEN RAISE EXCEPTION 'Invalid status for customer payment: %', v_r.status; END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  v_old_status := v_r.status::TEXT;
  v_cash := CASE WHEN p_cash_account_code IS NOT NULL THEN fx_account_id_by_code(v_r.company_id, p_cash_account_code)
    ELSE COALESCE(fx_cash_account_for_currency(v_r.company_id, v_r.receive_currency), fx_account_id_by_code(v_r.company_id, '1110')) END;
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_commission := fx_account_id_by_code(v_r.company_id, '4310');
  v_comm := CASE WHEN v_r.commission_mode = 'customer_paid' THEN LEAST(p_amount, v_r.commission_amount) ELSE 0 END;
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

  UPDATE fx_remittances SET paid_amount = v_new_paid, status = v_new_status, updated_by = auth.uid(), updated_at = NOW() WHERE id = p_remittance_id;

  PERFORM fx_remittance_write_audit(p_remittance_id, 'posted', v_old_status, v_new_status::TEXT, p_amount, p_notes, NULL);
  PERFORM fx_remittance_notify_branch(p_remittance_id, 'payment_received', 'Payment received — ' || v_r.tracking_id,
    'Customer payment of ' || p_amount::TEXT || ' ' || v_r.receive_currency,
    jsonb_build_object('amount', p_amount, 'status', v_new_status::TEXT));

  RETURN v_tx_id;
END;
$$;

-- Patch send to agent
CREATE OR REPLACE FUNCTION fx_send_remittance_to_agent(
  p_remittance_id UUID,
  p_agent_party_id UUID,
  p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_event_no INT;
  v_code TEXT;
  v_old_status TEXT;
  v_agent_name TEXT;
BEGIN
  IF NOT fx_has_permission('can_manage_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status IN ('cancelled', 'refunded', 'completed') THEN RAISE EXCEPTION 'Remittance is % — cannot send to agent', v_r.status; END IF;
  IF v_r.status <> 'customer_paid' THEN RAISE EXCEPTION 'Customer must fully pay before sending to agent'; END IF;
  IF v_r.paid_amount < v_r.total_payable THEN RAISE EXCEPTION 'Payment incomplete'; END IF;

  v_old_status := v_r.status::TEXT;
  v_code := COALESCE(v_r.payout_code, LPAD((FLOOR(random() * 1000000))::TEXT, 6, '0'));
  SELECT name INTO v_agent_name FROM fx_parties WHERE id = p_agent_party_id;

  UPDATE fx_remittances SET payout_agent_party_id = p_agent_party_id, payout_code = v_code, status = 'sent_to_agent', updated_by = auth.uid(), updated_at = NOW() WHERE id = p_remittance_id;
  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, notes, created_by) VALUES (p_remittance_id, v_event_no, 'sent_to_agent', 'sent_to_agent', p_notes, auth.uid());

  PERFORM fx_remittance_write_audit(p_remittance_id, 'edited', v_old_status, 'sent_to_agent', NULL, p_notes, v_code);
  PERFORM fx_remittance_notify_branch(p_remittance_id, 'sent_to_agent', 'Sent to agent — ' || v_r.tracking_id,
    'Assigned to ' || COALESCE(v_agent_name, 'agent') || '. Payout code: ' || v_code,
    jsonb_build_object('agent_party_id', p_agent_party_id, 'payout_code', v_code));
END;
$$;

-- Patch branch confirm payout with audit + notify
CREATE OR REPLACE FUNCTION fx_confirm_remittance_payout(
  p_remittance_id UUID,
  p_proof_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_payout_method TEXT DEFAULT NULL
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
  v_liability UUID;
  v_agent_pay UUID;
  v_amount NUMERIC(20, 8);
  v_old_status TEXT;
  v_agent_name TEXT;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status IN ('cancelled', 'refunded') THEN RAISE EXCEPTION 'Cannot confirm payout — remittance is %', v_r.status; END IF;
  IF v_r.status IN ('paid_out', 'completed') THEN RAISE EXCEPTION 'Payout already confirmed'; END IF;
  IF v_r.payout_agent_party_id IS NULL THEN RAISE EXCEPTION 'Payout agent required'; END IF;
  IF v_r.status NOT IN ('sent_to_agent', 'ready_for_payout') THEN RAISE EXCEPTION 'Invalid status for payout: %', v_r.status; END IF;

  v_old_status := v_r.status::TEXT;
  v_amount := v_r.receive_amount;
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');
  SELECT name INTO v_agent_name FROM fx_parties WHERE id = v_r.payout_agent_party_id;

  INSERT INTO fx_transactions (company_id, branch_id, transaction_type, status, transaction_date, party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr, description, remittance_id, created_by)
  VALUES (v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', CURRENT_DATE, v_r.payout_agent_party_id, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, v_amount,
    COALESCE(p_notes, 'Remittance payout ' || v_r.tracking_id), p_remittance_id, auth.uid()) RETURNING id INTO v_tx_id;
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo) VALUES
    (v_tx_id, 1, v_liability, v_r.receive_currency, v_amount, 1, v_amount, 0, 'Clear remittance liability'),
    (v_tx_id, 2, v_agent_pay, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, 0, v_amount, 'Agent payable');
  PERFORM fx_post_transaction(v_tx_id);
  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose) VALUES (p_remittance_id, v_tx_id, 'agent_payout');
  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, amount, currency_code, linked_transaction_id, proof_reference, notes, created_by)
  VALUES (p_remittance_id, v_event_no, 'payout_confirmed', 'paid_out', v_r.payout_amount, v_r.payout_currency, v_tx_id, p_proof_reference, p_notes, auth.uid());
  UPDATE fx_remittances SET status = 'paid_out', payout_status = 'paid', payout_method = COALESCE(p_payout_method, payout_method), payout_confirmed_at = NOW(), updated_by = auth.uid(), updated_at = NOW() WHERE id = p_remittance_id;

  PERFORM fx_remittance_write_audit(p_remittance_id, 'posted', v_old_status, 'paid_out', v_r.payout_amount, p_notes, p_proof_reference);
  PERFORM fx_remittance_notify_branch(p_remittance_id, 'payout_confirmed', 'Payout confirmed — ' || v_r.tracking_id,
    COALESCE(v_agent_name, 'Agent') || ' confirmed payout ' || v_r.payout_amount::TEXT || ' ' || v_r.payout_currency,
    jsonb_build_object('amount', v_r.payout_amount, 'payout_confirmed_at', NOW()));

  RETURN v_tx_id;
END;
$$;

-- Patch agent confirm with notify
CREATE OR REPLACE FUNCTION fx_agent_confirm_remittance_payout(
  p_remittance_id UUID,
  p_amount NUMERIC DEFAULT NULL,
  p_payout_method TEXT DEFAULT NULL,
  p_payout_at TIMESTAMPTZ DEFAULT NULL,
  p_proof_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_liability UUID;
  v_agent_pay UUID;
  v_amount NUMERIC(20, 8);
  v_payout_at TIMESTAMPTZ;
  v_old_status TEXT;
  v_agent_name TEXT;
BEGIN
  IF NOT fx_has_permission('can_agent_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_profile FROM fx_current_profile();
  IF v_profile.linked_party_id IS NULL THEN RAISE EXCEPTION 'No agent party linked'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF v_r.payout_agent_party_id IS DISTINCT FROM v_profile.linked_party_id THEN RAISE EXCEPTION 'Not assigned to your agent account'; END IF;
  IF v_r.status IN ('cancelled', 'refunded') THEN RAISE EXCEPTION 'Cannot confirm — remittance is %', v_r.status; END IF;
  IF v_r.status IN ('paid_out', 'completed') THEN RAISE EXCEPTION 'Payout already confirmed'; END IF;
  IF v_r.status NOT IN ('sent_to_agent', 'ready_for_payout') THEN RAISE EXCEPTION 'Invalid status: %', v_r.status; END IF;

  v_old_status := v_r.status::TEXT;
  v_amount := v_r.receive_amount;
  v_payout_at := COALESCE(p_payout_at, NOW());
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');
  SELECT name INTO v_agent_name FROM fx_parties WHERE id = v_profile.linked_party_id;

  INSERT INTO fx_transactions (company_id, branch_id, transaction_type, status, transaction_date, party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr, description, remittance_id, created_by)
  VALUES (v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', (v_payout_at AT TIME ZONE 'UTC')::DATE, v_r.payout_agent_party_id, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, v_amount,
    COALESCE(p_notes, 'Agent payout ' || v_r.tracking_id), p_remittance_id, auth.uid()) RETURNING id INTO v_tx_id;
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo) VALUES
    (v_tx_id, 1, v_liability, v_r.receive_currency, v_amount, 1, v_amount, 0, 'Clear remittance liability'),
    (v_tx_id, 2, v_agent_pay, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, 0, v_amount, 'Agent payable');
  PERFORM fx_post_transaction(v_tx_id);
  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose) VALUES (p_remittance_id, v_tx_id, 'agent_payout');
  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, amount, currency_code, linked_transaction_id, proof_reference, notes, created_by)
  VALUES (p_remittance_id, v_event_no, 'payout_confirmed', 'paid_out', v_r.payout_amount, v_r.payout_currency, v_tx_id, p_proof_reference, p_notes, auth.uid());
  UPDATE fx_remittances SET status = 'paid_out', payout_status = 'paid', payout_method = COALESCE(p_payout_method, payout_method), payout_confirmed_at = v_payout_at, updated_by = auth.uid(), updated_at = NOW() WHERE id = p_remittance_id;

  PERFORM fx_remittance_write_audit(p_remittance_id, 'posted', v_old_status, 'paid_out', v_r.payout_amount, p_notes, p_proof_reference);
  PERFORM fx_remittance_notify_branch(p_remittance_id, 'payout_confirmed', 'Agent payout — ' || v_r.tracking_id,
    COALESCE(v_agent_name, 'Agent') || ' paid ' || v_r.payout_amount::TEXT || ' ' || v_r.payout_currency || ' at ' || v_payout_at::TEXT,
    jsonb_build_object('agent_name', v_agent_name, 'amount', v_r.payout_amount, 'payout_at', v_payout_at));

  RETURN v_tx_id;
END;
$$;

-- Patch settlement + cancel with audit/notify
CREATE OR REPLACE FUNCTION fx_settle_remittance_agent(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT '1110',
  p_notes TEXT DEFAULT NULL
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
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;
  v_old_status := v_r.status::TEXT;
  v_cash := fx_account_id_by_code(v_r.company_id, p_cash_account_code);
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');
  INSERT INTO fx_transactions (company_id, branch_id, transaction_type, status, transaction_date, party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr, description, remittance_id, created_by)
  VALUES (v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', CURRENT_DATE, v_r.payout_agent_party_id, 'PKR', p_amount, 1, p_amount, COALESCE(p_notes, 'Agent settlement ' || v_r.tracking_id), p_remittance_id, auth.uid()) RETURNING id INTO v_tx_id;
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo) VALUES
    (v_tx_id, 1, v_agent_pay, 'PKR', p_amount, 1, p_amount, 0, 'Settle agent payable'),
    (v_tx_id, 2, v_cash, 'PKR', p_amount, 1, 0, p_amount, 'Cash paid to agent');
  PERFORM fx_post_transaction(v_tx_id);
  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose) VALUES (p_remittance_id, v_tx_id, 'agent_settlement');
  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, amount, currency_code, linked_transaction_id, notes, created_by)
  VALUES (p_remittance_id, v_event_no, 'agent_settlement', 'completed', p_amount, 'PKR', v_tx_id, p_notes, auth.uid());
  UPDATE fx_remittances SET settlement_status = 'settled', status = 'completed', completed_at = NOW(), updated_by = auth.uid(), updated_at = NOW() WHERE id = p_remittance_id;
  PERFORM fx_remittance_write_audit(p_remittance_id, 'posted', v_old_status, 'completed', p_amount, p_notes, NULL);
  PERFORM fx_remittance_notify_branch(p_remittance_id, 'settlement_completed', 'Settlement complete — ' || v_r.tracking_id, 'Agent settlement of PKR ' || p_amount::TEXT, jsonb_build_object('amount', p_amount));
  RETURN v_tx_id;
END;
$$;

CREATE OR REPLACE FUNCTION fx_cancel_remittance(
  p_remittance_id UUID,
  p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_event_no INT;
  v_old_status TEXT;
BEGIN
  IF NOT fx_has_permission('can_manage_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF v_r.status NOT IN ('draft', 'booked') THEN RAISE EXCEPTION 'Can only cancel draft or booked remittances'; END IF;
  v_old_status := v_r.status::TEXT;
  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  UPDATE fx_remittances SET status = 'cancelled', cancelled_at = NOW(), updated_by = auth.uid(), updated_at = NOW() WHERE id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, notes, created_by) VALUES (p_remittance_id, v_event_no, 'status_change', 'cancelled', p_notes, auth.uid());
  PERFORM fx_remittance_write_audit(p_remittance_id, 'voided', v_old_status, 'cancelled', NULL, p_notes, NULL);
  PERFORM fx_remittance_notify_branch(p_remittance_id, 'cancellation', 'Cancelled — ' || v_r.tracking_id, COALESCE(p_notes, 'Remittance cancelled'), jsonb_build_object('status', 'cancelled'));
END;
$$;

CREATE OR REPLACE FUNCTION fx_list_notifications(p_unread_only BOOLEAN DEFAULT FALSE)
RETURNS SETOF fx_notifications
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT n.*
  FROM fx_notifications n
  WHERE n.recipient_user_id = auth.uid()
    AND (NOT p_unread_only OR n.read_at IS NULL)
  ORDER BY n.created_at DESC
  LIMIT 100;
$$;

CREATE OR REPLACE FUNCTION fx_mark_notification_read(p_notification_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE fx_notifications SET read_at = NOW() WHERE id = p_notification_id AND recipient_user_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION fx_remittance_write_audit(UUID, fx_audit_action, TEXT, TEXT, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_list_notifications(BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_mark_notification_read(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_record_remittance_customer_payment(UUID, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_send_remittance_to_agent(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_confirm_remittance_payout(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_agent_confirm_remittance_payout(UUID, NUMERIC, TEXT, TIMESTAMPTZ, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_settle_remittance_agent(UUID, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_cancel_remittance(UUID, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
