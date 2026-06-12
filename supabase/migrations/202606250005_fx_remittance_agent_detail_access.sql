-- Agent cross-branch read access for detail + timeline

CREATE OR REPLACE FUNCTION fx_get_agent_remittance_detail(p_remittance_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_party UUID;
  v_result JSONB;
BEGIN
  IF NOT fx_has_permission('can_agent_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT linked_party_id INTO v_party FROM fx_users_profiles WHERE id = auth.uid();
  IF v_party IS NULL THEN RAISE EXCEPTION 'No agent party linked'; END IF;

  SELECT jsonb_build_object(
    'id', r.id, 'remittance_no', r.remittance_no, 'tracking_id', r.tracking_id,
    'sender_party_id', r.sender_party_id, 'sender_name', sp.name,
    'receiver_name', r.receiver_name, 'receiver_phone', r.receiver_phone,
    'receiver_city', r.receiver_city, 'receiver_country', r.receiver_country,
    'payout_agent_party_id', r.payout_agent_party_id, 'payout_agent_name', ap.name,
    'branch_id', r.branch_id, 'branch_name', b.name,
    'receive_currency', r.receive_currency, 'receive_amount', r.receive_amount,
    'payout_currency', r.payout_currency, 'payout_amount', r.payout_amount,
    'exchange_rate', r.exchange_rate, 'commission_amount', r.commission_amount,
    'commission_mode', r.commission_mode, 'total_payable', r.total_payable,
    'paid_amount', r.paid_amount, 'balance_due', GREATEST(0, r.total_payable - r.paid_amount),
    'status', r.status, 'payout_status', r.payout_status, 'settlement_status', r.settlement_status,
    'payout_code', r.payout_code, 'payout_method', r.payout_method,
    'payout_confirmed_at', r.payout_confirmed_at, 'notes', r.notes,
    'booked_at', r.booked_at, 'completed_at', r.completed_at,
    'created_by_name', cp.full_name, 'created_at', r.created_at, 'updated_at', r.updated_at
  ) INTO v_result
  FROM fx_remittances r
  JOIN fx_branches b ON b.id = r.branch_id
  JOIN fx_parties sp ON sp.id = r.sender_party_id
  LEFT JOIN fx_parties ap ON ap.id = r.payout_agent_party_id
  LEFT JOIN fx_users_profiles cp ON cp.id = r.created_by
  WHERE r.id = p_remittance_id AND r.payout_agent_party_id = v_party;

  IF v_result IS NULL THEN RAISE EXCEPTION 'Remittance not found or not assigned to you'; END IF;
  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_get_agent_remittance_detail(UUID) TO authenticated;
NOTIFY pgrst, 'reload schema';
