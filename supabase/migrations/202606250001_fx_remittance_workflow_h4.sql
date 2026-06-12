-- H4: Remittance workflow — commission mode, payment guards, detail/timeline RPCs
-- Project: ygidlcqhupmxvsdjmvnf only

ALTER TABLE fx_remittances
  ADD COLUMN IF NOT EXISTS commission_mode TEXT NOT NULL DEFAULT 'customer_paid'
    CHECK (commission_mode IN ('customer_paid', 'internal')),
  ADD COLUMN IF NOT EXISTS payout_code TEXT,
  ADD COLUMN IF NOT EXISTS payout_method TEXT,
  ADD COLUMN IF NOT EXISTS payout_confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users (id);

CREATE INDEX IF NOT EXISTS idx_fx_remittances_payout_code ON fx_remittances (payout_code) WHERE payout_code IS NOT NULL;

-- ---------------------------------------------------------------------------
-- fx_create_remittance — commission_mode + total_payable logic
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_create_remittance(
  p_branch_id UUID,
  p_sender_party_id UUID,
  p_receiver_name TEXT,
  p_receiver_phone TEXT DEFAULT NULL,
  p_receiver_city TEXT DEFAULT NULL,
  p_receiver_country TEXT DEFAULT NULL,
  p_payout_agent_party_id UUID DEFAULT NULL,
  p_receive_currency TEXT DEFAULT 'PKR',
  p_receive_amount NUMERIC DEFAULT 0,
  p_payout_currency TEXT DEFAULT 'PKR',
  p_payout_amount NUMERIC DEFAULT 0,
  p_exchange_rate NUMERIC DEFAULT 1,
  p_commission_amount NUMERIC DEFAULT 0,
  p_notes TEXT DEFAULT NULL,
  p_commission_mode TEXT DEFAULT 'customer_paid',
  p_book_immediately BOOLEAN DEFAULT TRUE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_id UUID;
  v_no TEXT;
  v_total NUMERIC(20, 8);
  v_status fx_remittance_status;
  v_mode TEXT;
BEGIN
  IF NOT fx_has_permission('can_manage_remittance') AND NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_profile FROM fx_current_profile();
  IF NOT FOUND OR v_profile.branch_id <> p_branch_id THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;
  IF p_receive_amount <= 0 OR p_payout_amount <= 0 THEN
    RAISE EXCEPTION 'Receive and payout amounts must be positive';
  END IF;

  v_mode := CASE WHEN p_commission_mode = 'internal' THEN 'internal' ELSE 'customer_paid' END;
  PERFORM fx_seed_remittance_coa(v_profile.company_id);

  v_total := p_receive_amount + CASE WHEN v_mode = 'customer_paid' THEN COALESCE(p_commission_amount, 0) ELSE 0 END;
  v_no := fx_generate_remittance_no(p_branch_id);
  v_status := CASE WHEN p_book_immediately THEN 'booked'::fx_remittance_status ELSE 'draft'::fx_remittance_status END;

  INSERT INTO fx_remittances (
    company_id, branch_id, remittance_no, tracking_id, sender_party_id,
    receiver_name, receiver_phone, receiver_city, receiver_country,
    payout_agent_party_id, receive_currency, receive_amount, payout_currency, payout_amount,
    exchange_rate, commission_amount, commission_mode, total_payable, status, notes, booked_at, created_by
  ) VALUES (
    v_profile.company_id, p_branch_id, v_no, v_no, p_sender_party_id,
    p_receiver_name, p_receiver_phone, p_receiver_city, p_receiver_country,
    p_payout_agent_party_id, upper(p_receive_currency), p_receive_amount,
    upper(p_payout_currency), p_payout_amount, p_exchange_rate, p_commission_amount, v_mode,
    v_total, v_status, p_notes,
    CASE WHEN p_book_immediately THEN NOW() ELSE NULL END,
    auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, notes, created_by
  ) VALUES (
    v_id, 1, 'created', v_status, p_notes, auth.uid()
  );

  RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_record_remittance_customer_payment — partial payment stays booked
-- ---------------------------------------------------------------------------

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
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status NOT IN ('booked', 'customer_paid') THEN
    RAISE EXCEPTION 'Invalid status for customer payment: %', v_r.status;
  END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  v_cash := CASE
    WHEN p_cash_account_code IS NOT NULL THEN fx_account_id_by_code(v_r.company_id, p_cash_account_code)
    ELSE COALESCE(fx_cash_account_for_currency(v_r.company_id, v_r.receive_currency), fx_account_id_by_code(v_r.company_id, '1110'))
  END;
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_commission := fx_account_id_by_code(v_r.company_id, '4310');

  v_comm := CASE WHEN v_r.commission_mode = 'customer_paid' THEN LEAST(p_amount, v_r.commission_amount) ELSE 0 END;
  v_pay := p_amount - v_comm;
  v_new_paid := v_r.paid_amount + p_amount;
  v_new_status := CASE
    WHEN v_new_paid >= v_r.total_payable THEN 'customer_paid'::fx_remittance_status
    ELSE 'booked'::fx_remittance_status
  END;

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, remittance_id, created_by
  ) VALUES (
    v_r.company_id, v_r.branch_id, 'settlement_receive', 'draft', CURRENT_DATE,
    v_r.sender_party_id, v_r.receive_currency, p_amount, 1, p_amount,
    COALESCE(p_notes, 'Remittance customer payment ' || v_r.tracking_id),
    p_remittance_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, 1, v_cash, v_r.receive_currency, p_amount, 1, p_amount, 0, 'Customer payment received');

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, 2, v_liability, v_r.receive_currency, v_pay, 1, 0, v_pay, 'Remittance liability');

  IF v_comm > 0 THEN
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, 3, v_commission, v_r.receive_currency, v_comm, 1, 0, v_comm, 'Commission income');
  END IF;

  PERFORM fx_post_transaction(v_tx_id);

  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose)
  VALUES (p_remittance_id, v_tx_id, 'customer_payment');

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, amount, currency_code,
    linked_transaction_id, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'customer_payment', v_new_status, p_amount, v_r.receive_currency,
    v_tx_id, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET
    paid_amount = v_new_paid,
    status = v_new_status,
    updated_by = auth.uid(),
    updated_at = NOW()
  WHERE id = p_remittance_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_send_remittance_to_agent — full payment required + payout code
-- ---------------------------------------------------------------------------

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
BEGIN
  IF NOT fx_has_permission('can_manage_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status IN ('cancelled', 'refunded', 'completed') THEN
    RAISE EXCEPTION 'Remittance is % — cannot send to agent', v_r.status;
  END IF;
  IF v_r.status <> 'customer_paid' THEN
    RAISE EXCEPTION 'Customer must fully pay before sending to agent (status: %)', v_r.status;
  END IF;
  IF v_r.paid_amount < v_r.total_payable THEN
    RAISE EXCEPTION 'Payment incomplete: paid % of % required', v_r.paid_amount, v_r.total_payable;
  END IF;

  v_code := COALESCE(v_r.payout_code, LPAD((FLOOR(random() * 1000000))::TEXT, 6, '0'));

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  UPDATE fx_remittances SET
    payout_agent_party_id = p_agent_party_id,
    payout_code = v_code,
    status = 'sent_to_agent',
    updated_by = auth.uid(),
    updated_at = NOW()
  WHERE id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'sent_to_agent', 'sent_to_agent', p_notes, auth.uid()
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_confirm_remittance_payout — duplicate guard + payout metadata
-- ---------------------------------------------------------------------------

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
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status IN ('cancelled', 'refunded') THEN
    RAISE EXCEPTION 'Cannot confirm payout — remittance is %', v_r.status;
  END IF;
  IF v_r.status IN ('paid_out', 'completed') THEN
    RAISE EXCEPTION 'Payout already confirmed for this remittance';
  END IF;
  IF v_r.payout_agent_party_id IS NULL THEN RAISE EXCEPTION 'Payout agent required'; END IF;
  IF v_r.status NOT IN ('sent_to_agent', 'ready_for_payout') THEN
    RAISE EXCEPTION 'Invalid status for payout: %', v_r.status;
  END IF;

  v_amount := v_r.receive_amount;
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, remittance_id, created_by
  ) VALUES (
    v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', CURRENT_DATE,
    v_r.payout_agent_party_id, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate,
    v_amount, COALESCE(p_notes, 'Remittance payout ' || v_r.tracking_id),
    p_remittance_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_liability, v_r.receive_currency, v_amount, 1, v_amount, 0, 'Clear remittance liability'),
    (v_tx_id, 2, v_agent_pay, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, 0, v_amount, 'Agent payable');

  PERFORM fx_post_transaction(v_tx_id);

  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose)
  VALUES (p_remittance_id, v_tx_id, 'agent_payout');

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, amount, currency_code,
    linked_transaction_id, proof_reference, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'payout_confirmed', 'paid_out', v_r.payout_amount, v_r.payout_currency,
    v_tx_id, p_proof_reference, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET
    status = 'paid_out',
    payout_status = 'paid',
    payout_method = COALESCE(p_payout_method, payout_method),
    payout_confirmed_at = NOW(),
    updated_by = auth.uid(),
    updated_at = NOW()
  WHERE id = p_remittance_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_get_remittance_detail
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_remittance_detail(p_remittance_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'id', r.id,
    'remittance_no', r.remittance_no,
    'tracking_id', r.tracking_id,
    'sender_party_id', r.sender_party_id,
    'sender_name', sp.name,
    'receiver_name', r.receiver_name,
    'receiver_phone', r.receiver_phone,
    'receiver_city', r.receiver_city,
    'receiver_country', r.receiver_country,
    'payout_agent_party_id', r.payout_agent_party_id,
    'payout_agent_name', ap.name,
    'branch_id', r.branch_id,
    'branch_name', b.name,
    'receive_currency', r.receive_currency,
    'receive_amount', r.receive_amount,
    'payout_currency', r.payout_currency,
    'payout_amount', r.payout_amount,
    'exchange_rate', r.exchange_rate,
    'commission_amount', r.commission_amount,
    'commission_mode', r.commission_mode,
    'total_payable', r.total_payable,
    'paid_amount', r.paid_amount,
    'balance_due', GREATEST(0, r.total_payable - r.paid_amount),
    'status', r.status,
    'payout_status', r.payout_status,
    'settlement_status', r.settlement_status,
    'payout_code', r.payout_code,
    'payout_method', r.payout_method,
    'payout_confirmed_at', r.payout_confirmed_at,
    'notes', r.notes,
    'booked_at', r.booked_at,
    'completed_at', r.completed_at,
    'created_by', r.created_by,
    'created_by_name', cp.full_name,
    'created_at', r.created_at,
    'updated_at', r.updated_at
  ) INTO v_result
  FROM fx_remittances r
  JOIN fx_branches b ON b.id = r.branch_id
  JOIN fx_parties sp ON sp.id = r.sender_party_id
  LEFT JOIN fx_parties ap ON ap.id = r.payout_agent_party_id
  LEFT JOIN fx_users_profiles cp ON cp.id = r.created_by
  WHERE r.id = p_remittance_id
    AND fx_same_branch(r.branch_id);

  IF v_result IS NULL THEN
    RAISE EXCEPTION 'Remittance not found or unauthorized';
  END IF;

  RETURN v_result;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_get_remittance_timeline — enriched
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS fx_get_remittance_timeline(UUID);

CREATE OR REPLACE FUNCTION fx_get_remittance_timeline(p_remittance_id UUID)
RETURNS TABLE (
  event_id UUID,
  event_no INT,
  event_type fx_remittance_event_type,
  status_after fx_remittance_status,
  amount NUMERIC,
  currency_code TEXT,
  linked_transaction_id UUID,
  proof_reference TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ,
  created_by UUID,
  created_by_name TEXT,
  branch_name TEXT,
  actor_role TEXT,
  attachment_count BIGINT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    e.id,
    e.event_no,
    e.event_type,
    e.status_after,
    e.amount,
    e.currency_code,
    e.linked_transaction_id,
    e.proof_reference,
    e.notes,
    e.created_at,
    e.created_by,
    p.full_name,
    b.name,
    COALESCE(
      (SELECT r.name FROM fx_user_roles ur JOIN fx_roles r ON r.id = ur.role_id
       WHERE ur.user_id = e.created_by LIMIT 1),
      'staff'
    ),
    (SELECT COUNT(*) FROM fx_attachments a WHERE a.remittance_event_id = e.id)
  FROM fx_remittance_events e
  JOIN fx_remittances rem ON rem.id = e.remittance_id
  JOIN fx_branches b ON b.id = rem.branch_id
  LEFT JOIN fx_users_profiles p ON p.id = e.created_by
  WHERE e.remittance_id = p_remittance_id
    AND fx_same_branch(rem.branch_id)
  ORDER BY e.event_no;
$$;

GRANT EXECUTE ON FUNCTION fx_create_remittance(UUID, UUID, TEXT, TEXT, TEXT, TEXT, UUID, TEXT, NUMERIC, TEXT, NUMERIC, NUMERIC, NUMERIC, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_record_remittance_customer_payment(UUID, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_send_remittance_to_agent(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_confirm_remittance_payout(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_remittance_detail(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_remittance_timeline(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
