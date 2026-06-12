-- H5: Agent remittance workspace — linked party + agent RPCs
-- Project: ygidlcqhupmxvsdjmvnf only

ALTER TABLE fx_users_profiles
  ADD COLUMN IF NOT EXISTS linked_party_id UUID REFERENCES fx_parties (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_fx_users_profiles_linked_party ON fx_users_profiles (linked_party_id) WHERE linked_party_id IS NOT NULL;

UPDATE fx_roles SET permissions = array_append(permissions, 'can_agent_remittance')
WHERE name IN ('admin', 'manager', 'agent')
  AND NOT ('can_agent_remittance' = ANY (permissions));

DROP POLICY IF EXISTS fx_remittances_agent_select ON fx_remittances;
CREATE POLICY fx_remittances_agent_select ON fx_remittances
  FOR SELECT TO authenticated
  USING (
    payout_agent_party_id IS NOT NULL
    AND payout_agent_party_id = (SELECT linked_party_id FROM fx_users_profiles WHERE id = auth.uid())
    AND fx_has_permission('can_agent_remittance')
  );

CREATE OR REPLACE FUNCTION fx_list_agent_remittances(p_query TEXT DEFAULT NULL)
RETURNS SETOF fx_remittances
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_party UUID;
  v_q TEXT;
BEGIN
  IF NOT fx_has_permission('can_agent_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT linked_party_id INTO v_party FROM fx_users_profiles WHERE id = auth.uid();
  IF v_party IS NULL THEN RAISE EXCEPTION 'No agent party linked to your profile'; END IF;
  v_q := NULLIF(trim(p_query), '');
  RETURN QUERY
  SELECT r.* FROM fx_remittances r
  WHERE r.payout_agent_party_id = v_party
    AND (v_q IS NULL OR r.remittance_no ILIKE '%' || v_q || '%' OR r.tracking_id ILIKE '%' || v_q || '%'
      OR r.receiver_name ILIKE '%' || v_q || '%' OR r.receiver_phone ILIKE '%' || v_q || '%' OR r.payout_code = v_q)
  ORDER BY r.updated_at DESC;
END;
$$;

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
BEGIN
  IF NOT fx_has_permission('can_agent_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_profile FROM fx_current_profile();
  IF v_profile.linked_party_id IS NULL THEN RAISE EXCEPTION 'No agent party linked'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF v_r.payout_agent_party_id IS DISTINCT FROM v_profile.linked_party_id THEN RAISE EXCEPTION 'Not assigned to your agent account'; END IF;
  IF v_r.status IN ('cancelled', 'refunded') THEN RAISE EXCEPTION 'Cannot confirm — remittance is %', v_r.status; END IF;
  IF v_r.status IN ('paid_out', 'completed') THEN RAISE EXCEPTION 'Payout already confirmed'; END IF;
  IF v_r.status NOT IN ('sent_to_agent', 'ready_for_payout') THEN RAISE EXCEPTION 'Invalid status: %', v_r.status; END IF;
  v_amount := v_r.receive_amount;
  v_payout_at := COALESCE(p_payout_at, NOW());
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');
  INSERT INTO fx_transactions (company_id, branch_id, transaction_type, status, transaction_date, party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr, description, remittance_id, created_by)
  VALUES (v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', (v_payout_at AT TIME ZONE 'UTC')::DATE, v_r.payout_agent_party_id, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, v_amount, COALESCE(p_notes, 'Agent payout ' || v_r.tracking_id), p_remittance_id, auth.uid()) RETURNING id INTO v_tx_id;
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo) VALUES
    (v_tx_id, 1, v_liability, v_r.receive_currency, v_amount, 1, v_amount, 0, 'Clear remittance liability'),
    (v_tx_id, 2, v_agent_pay, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, 0, v_amount, 'Agent payable');
  PERFORM fx_post_transaction(v_tx_id);
  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose) VALUES (p_remittance_id, v_tx_id, 'agent_payout');
  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, amount, currency_code, linked_transaction_id, proof_reference, notes, created_by)
  VALUES (p_remittance_id, v_event_no, 'payout_confirmed', 'paid_out', v_r.payout_amount, v_r.payout_currency, v_tx_id, p_proof_reference, p_notes, auth.uid());
  UPDATE fx_remittances SET status = 'paid_out', payout_status = 'paid', payout_method = COALESCE(p_payout_method, payout_method), payout_confirmed_at = v_payout_at, updated_by = auth.uid(), updated_at = NOW() WHERE id = p_remittance_id;
  RETURN v_tx_id;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_list_agent_remittances(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_agent_confirm_remittance_payout(UUID, NUMERIC, TEXT, TIMESTAMPTZ, TEXT, TEXT) TO authenticated;
NOTIFY pgrst, 'reload schema';
