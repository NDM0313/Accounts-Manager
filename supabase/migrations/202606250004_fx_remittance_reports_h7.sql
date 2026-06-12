-- H7: Remittance reports — cash flow + statements (read-only aggregation)
-- Project: ygidlcqhupmxvsdjmvnf only

-- ---------------------------------------------------------------------------
-- fx_remittance_cash_flow_summary
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_remittance_cash_flow_summary(
  p_branch_id UUID,
  p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_company UUID;
  v_liability UUID;
  v_agent_pay UUID;
  v_commission UUID;
  v_result JSONB;
BEGIN
  IF NOT fx_has_permission('can_view_remittance_reports') AND NOT fx_has_permission('can_manage_remittance') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  SELECT company_id INTO v_company FROM fx_branches WHERE id = p_branch_id;
  v_liability := fx_account_id_by_code(v_company, '2350');
  v_agent_pay := fx_account_id_by_code(v_company, '2100');
  v_commission := fx_account_id_by_code(v_company, '4310');

  SELECT jsonb_build_object(
    'branch_id', p_branch_id,
    'date', p_date,
    'customer_received_today', COALESCE((
      SELECT SUM(e.amount)
      FROM fx_remittance_events e
      JOIN fx_remittances r ON r.id = e.remittance_id
      WHERE r.branch_id = p_branch_id
        AND e.event_type = 'customer_payment'
        AND (e.created_at AT TIME ZONE 'UTC')::DATE = p_date
    ), 0),
    'agent_payouts_today', COALESCE((
      SELECT SUM(e.amount)
      FROM fx_remittance_events e
      JOIN fx_remittances r ON r.id = e.remittance_id
      WHERE r.branch_id = p_branch_id
        AND e.event_type = 'payout_confirmed'
        AND (e.created_at AT TIME ZONE 'UTC')::DATE = p_date
    ), 0),
    'commission_earned_today', COALESCE((
      SELECT SUM(jl.credit_pkr - jl.debit_pkr)
      FROM fx_journal_lines jl
      JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
      JOIN fx_transactions t ON t.id = je.source_transaction_id
      WHERE je.branch_id = p_branch_id
        AND NOT je.is_void
        AND je.entry_date = p_date
        AND jl.account_id = v_commission
        AND t.remittance_id IS NOT NULL
    ), 0),
    'pending_payout_liability', COALESCE((
      SELECT SUM(jl.credit_pkr - jl.debit_pkr)
      FROM fx_journal_lines jl
      JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
      WHERE je.branch_id = p_branch_id
        AND NOT je.is_void
        AND je.entry_date <= p_date
        AND jl.account_id = v_liability
    ), 0),
    'pending_agent_settlement', COALESCE((
      SELECT SUM(jl.credit_pkr - jl.debit_pkr)
      FROM fx_journal_lines jl
      JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
      WHERE je.branch_id = p_branch_id
        AND NOT je.is_void
        AND je.entry_date <= p_date
        AND jl.account_id = v_agent_pay
    ), 0),
    'remittances_created_today', (
      SELECT COUNT(*)
      FROM fx_remittances r
      WHERE r.branch_id = p_branch_id
        AND (r.created_at AT TIME ZONE 'UTC')::DATE = p_date
    ),
    'remittances_paid_out_today', (
      SELECT COUNT(*)
      FROM fx_remittances r
      WHERE r.branch_id = p_branch_id
        AND r.payout_confirmed_at IS NOT NULL
        AND (r.payout_confirmed_at AT TIME ZONE 'UTC')::DATE = p_date
    ),
    'remittances_pending_payout', (
      SELECT COUNT(*)
      FROM fx_remittances r
      WHERE r.branch_id = p_branch_id
        AND r.status IN ('sent_to_agent', 'ready_for_payout')
    ),
    'total_receive_volume_today', COALESCE((
      SELECT SUM(r.receive_amount)
      FROM fx_remittances r
      WHERE r.branch_id = p_branch_id
        AND (r.created_at AT TIME ZONE 'UTC')::DATE = p_date
    ), 0),
    'cash_accounts', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'account_code', cb.account_code,
        'account_name', cb.account_name,
        'currency_code', cb.currency_code,
        'balance_pkr', cb.balance_pkr,
        'foreign_balance', cb.foreign_balance
      ) ORDER BY cb.account_code, cb.currency_code)
      FROM fx_get_cash_balances(p_branch_id) cb
    ), '[]'::JSONB)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_remittance_agent_statement
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_remittance_agent_statement(
  p_agent_party_id UUID,
  p_from DATE DEFAULT date_trunc('month', CURRENT_DATE)::DATE,
  p_to DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_agent_name TEXT;
  v_company UUID;
  v_agent_pay UUID;
  v_balance NUMERIC(20, 8);
  v_remittances JSONB;
BEGIN
  SELECT * INTO v_profile FROM fx_current_profile();
  IF fx_has_permission('can_agent_remittance')
     AND v_profile.linked_party_id IS NOT NULL
     AND v_profile.linked_party_id = p_agent_party_id THEN
    NULL;
  ELSIF fx_has_permission('can_view_remittance_reports') OR fx_has_permission('can_manage_remittance') THEN
    IF NOT EXISTS (
      SELECT 1 FROM fx_remittances r
      WHERE r.payout_agent_party_id = p_agent_party_id
        AND fx_same_branch(r.branch_id)
    ) THEN
      RAISE EXCEPTION 'Unauthorized agent access';
    END IF;
  ELSE
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT name INTO v_agent_name FROM fx_parties WHERE id = p_agent_party_id;
  SELECT company_id INTO v_company FROM fx_parties WHERE id = p_agent_party_id;
  v_agent_pay := fx_account_id_by_code(v_company, '2100');

  SELECT COALESCE(SUM(jl.credit_pkr - jl.debit_pkr), 0) INTO v_balance
  FROM fx_journal_lines jl
  JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
  JOIN fx_transactions t ON t.id = je.source_transaction_id
  JOIN fx_remittances r ON r.id = t.remittance_id
  WHERE jl.account_id = v_agent_pay
    AND NOT je.is_void
    AND je.entry_date <= p_to
    AND r.payout_agent_party_id = p_agent_party_id
    AND fx_same_branch(r.branch_id);

  SELECT COALESCE(jsonb_agg(row_to_json(x)::JSONB ORDER BY x.booked_at DESC NULLS LAST, x.remittance_no DESC), '[]'::JSONB)
  INTO v_remittances
  FROM (
    SELECT
      r.id,
      r.remittance_no,
      r.tracking_id,
      r.receiver_name,
      r.receive_currency,
      r.receive_amount,
      r.payout_currency,
      r.payout_amount,
      r.status,
      r.payout_status,
      r.settlement_status,
      r.booked_at,
      r.payout_confirmed_at,
      r.completed_at,
      b.name AS branch_name
    FROM fx_remittances r
    JOIN fx_branches b ON b.id = r.branch_id
    WHERE r.payout_agent_party_id = p_agent_party_id
      AND fx_same_branch(r.branch_id)
      AND COALESCE(r.booked_at, r.created_at)::DATE BETWEEN p_from AND p_to
  ) x;

  RETURN jsonb_build_object(
    'agent_party_id', p_agent_party_id,
    'agent_name', v_agent_name,
    'from', p_from,
    'to', p_to,
    'summary', jsonb_build_object(
      'assigned_count', (
        SELECT COUNT(*) FROM fx_remittances r
        WHERE r.payout_agent_party_id = p_agent_party_id
          AND fx_same_branch(r.branch_id)
          AND COALESCE(r.booked_at, r.created_at)::DATE BETWEEN p_from AND p_to
      ),
      'assigned_payout_amount', COALESCE((
        SELECT SUM(r.payout_amount) FROM fx_remittances r
        WHERE r.payout_agent_party_id = p_agent_party_id
          AND fx_same_branch(r.branch_id)
          AND COALESCE(r.booked_at, r.created_at)::DATE BETWEEN p_from AND p_to
      ), 0),
      'payouts_completed_count', (
        SELECT COUNT(*) FROM fx_remittances r
        WHERE r.payout_agent_party_id = p_agent_party_id
          AND fx_same_branch(r.branch_id)
          AND r.status IN ('paid_out', 'completed')
          AND COALESCE(r.payout_confirmed_at, r.updated_at)::DATE BETWEEN p_from AND p_to
      ),
      'payouts_completed_amount', COALESCE((
        SELECT SUM(r.payout_amount) FROM fx_remittances r
        WHERE r.payout_agent_party_id = p_agent_party_id
          AND fx_same_branch(r.branch_id)
          AND r.status IN ('paid_out', 'completed')
          AND COALESCE(r.payout_confirmed_at, r.updated_at)::DATE BETWEEN p_from AND p_to
      ), 0),
      'settlement_pending_count', (
        SELECT COUNT(*) FROM fx_remittances r
        WHERE r.payout_agent_party_id = p_agent_party_id
          AND fx_same_branch(r.branch_id)
          AND r.status IN ('paid_out', 'completed')
          AND r.settlement_status <> 'settled'
      ),
      'settlement_pending_amount', COALESCE((
        SELECT SUM(r.payout_amount) FROM fx_remittances r
        WHERE r.payout_agent_party_id = p_agent_party_id
          AND fx_same_branch(r.branch_id)
          AND r.status IN ('paid_out', 'completed')
          AND r.settlement_status <> 'settled'
      ), 0),
      'settled_amount', COALESCE((
        SELECT SUM(e.amount)
        FROM fx_remittance_events e
        JOIN fx_remittances r ON r.id = e.remittance_id
        WHERE r.payout_agent_party_id = p_agent_party_id
          AND fx_same_branch(r.branch_id)
          AND e.event_type = 'agent_settlement'
          AND e.created_at::DATE BETWEEN p_from AND p_to
      ), 0),
      'balance', v_balance
    ),
    'remittances', v_remittances
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_remittance_customer_statement
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_remittance_customer_statement(
  p_party_id UUID,
  p_from DATE DEFAULT date_trunc('month', CURRENT_DATE)::DATE,
  p_to DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_party_name TEXT;
  v_remittances JSONB;
  v_receipts JSONB;
BEGIN
  IF NOT fx_has_permission('can_view_remittance_reports') AND NOT fx_has_permission('can_manage_remittance') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM fx_remittances r
    WHERE r.sender_party_id = p_party_id
      AND fx_same_branch(r.branch_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized party access';
  END IF;

  SELECT name INTO v_party_name FROM fx_parties WHERE id = p_party_id;

  SELECT COALESCE(jsonb_agg(row_to_json(x)::JSONB ORDER BY x.created_at DESC), '[]'::JSONB)
  INTO v_remittances
  FROM (
    SELECT
      r.id,
      r.remittance_no,
      r.tracking_id,
      r.receiver_name,
      r.receiver_phone,
      r.receiver_city,
      r.receiver_country,
      r.receive_currency,
      r.receive_amount,
      r.payout_currency,
      r.payout_amount,
      r.commission_amount,
      r.total_payable,
      r.paid_amount,
      r.status,
      r.booked_at,
      r.completed_at,
      r.created_at,
      b.name AS branch_name,
      ap.name AS payout_agent_name
    FROM fx_remittances r
    JOIN fx_branches b ON b.id = r.branch_id
    LEFT JOIN fx_parties ap ON ap.id = r.payout_agent_party_id
    WHERE r.sender_party_id = p_party_id
      AND fx_same_branch(r.branch_id)
      AND COALESCE(r.booked_at, r.created_at)::DATE BETWEEN p_from AND p_to
  ) x;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'remittance_id', rt.remittance_id,
    'transaction_id', rt.transaction_id,
    'purpose', rt.purpose,
    'amount', e.amount,
    'currency_code', e.currency_code,
    'paid_at', e.created_at,
    'tracking_id', r.tracking_id,
    'remittance_no', r.remittance_no
  ) ORDER BY e.created_at DESC), '[]'::JSONB)
  INTO v_receipts
  FROM fx_remittance_transactions rt
  JOIN fx_remittances r ON r.id = rt.remittance_id
  JOIN fx_remittance_events e ON e.remittance_id = rt.remittance_id
    AND e.linked_transaction_id = rt.transaction_id
    AND e.event_type = 'customer_payment'
  WHERE r.sender_party_id = p_party_id
    AND fx_same_branch(r.branch_id)
    AND rt.purpose = 'customer_payment'
    AND e.created_at::DATE BETWEEN p_from AND p_to;

  RETURN jsonb_build_object(
    'party_id', p_party_id,
    'party_name', v_party_name,
    'from', p_from,
    'to', p_to,
    'summary', jsonb_build_object(
      'remittance_count', jsonb_array_length(v_remittances),
      'total_sent', COALESCE((
        SELECT SUM(r.receive_amount) FROM fx_remittances r
        WHERE r.sender_party_id = p_party_id
          AND fx_same_branch(r.branch_id)
          AND COALESCE(r.booked_at, r.created_at)::DATE BETWEEN p_from AND p_to
      ), 0),
      'total_paid', COALESCE((
        SELECT SUM(r.paid_amount) FROM fx_remittances r
        WHERE r.sender_party_id = p_party_id
          AND fx_same_branch(r.branch_id)
          AND COALESCE(r.booked_at, r.created_at)::DATE BETWEEN p_from AND p_to
      ), 0),
      'total_commission', COALESCE((
        SELECT SUM(r.commission_amount) FROM fx_remittances r
        WHERE r.sender_party_id = p_party_id
          AND fx_same_branch(r.branch_id)
          AND COALESCE(r.booked_at, r.created_at)::DATE BETWEEN p_from AND p_to
      ), 0),
      'open_count', (
        SELECT COUNT(*) FROM fx_remittances r
        WHERE r.sender_party_id = p_party_id
          AND fx_same_branch(r.branch_id)
          AND r.status NOT IN ('completed', 'cancelled', 'refunded')
      )
    ),
    'remittances', v_remittances,
    'receipts', v_receipts
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_remittance_branch_statement
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_remittance_branch_statement(
  p_branch_id UUID,
  p_from DATE DEFAULT date_trunc('month', CURRENT_DATE)::DATE,
  p_to DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_branch_name TEXT;
  v_company UUID;
  v_liability UUID;
  v_commission UUID;
BEGIN
  IF NOT fx_has_permission('can_view_remittance_reports') AND NOT fx_has_permission('can_manage_remittance') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  SELECT name, company_id INTO v_branch_name, v_company FROM fx_branches WHERE id = p_branch_id;
  v_liability := fx_account_id_by_code(v_company, '2350');
  v_commission := fx_account_id_by_code(v_company, '4310');

  RETURN jsonb_build_object(
    'branch_id', p_branch_id,
    'branch_name', v_branch_name,
    'from', p_from,
    'to', p_to,
    'summary', jsonb_build_object(
      'collections', COALESCE((
        SELECT SUM(e.amount)
        FROM fx_remittance_events e
        JOIN fx_remittances r ON r.id = e.remittance_id
        WHERE r.branch_id = p_branch_id
          AND e.event_type = 'customer_payment'
          AND e.created_at::DATE BETWEEN p_from AND p_to
      ), 0),
      'commission', COALESCE((
        SELECT SUM(jl.credit_pkr - jl.debit_pkr)
        FROM fx_journal_lines jl
        JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
        JOIN fx_transactions t ON t.id = je.source_transaction_id
        WHERE je.branch_id = p_branch_id
          AND NOT je.is_void
          AND je.entry_date BETWEEN p_from AND p_to
          AND jl.account_id = v_commission
          AND t.remittance_id IS NOT NULL
      ), 0),
      'pending_payouts_count', (
        SELECT COUNT(*) FROM fx_remittances r
        WHERE r.branch_id = p_branch_id
          AND r.status IN ('sent_to_agent', 'ready_for_payout')
      ),
      'pending_payouts_amount', COALESCE((
        SELECT SUM(r.payout_amount) FROM fx_remittances r
        WHERE r.branch_id = p_branch_id
          AND r.status IN ('sent_to_agent', 'ready_for_payout')
      ), 0),
      'paid_out_count', (
        SELECT COUNT(*) FROM fx_remittances r
        WHERE r.branch_id = p_branch_id
          AND r.status IN ('paid_out', 'completed')
          AND COALESCE(r.payout_confirmed_at, r.updated_at)::DATE BETWEEN p_from AND p_to
      ),
      'paid_out_amount', COALESCE((
        SELECT SUM(r.payout_amount) FROM fx_remittances r
        WHERE r.branch_id = p_branch_id
          AND r.status IN ('paid_out', 'completed')
          AND COALESCE(r.payout_confirmed_at, r.updated_at)::DATE BETWEEN p_from AND p_to
      ), 0),
      'pending_liability', COALESCE((
        SELECT SUM(jl.credit_pkr - jl.debit_pkr)
        FROM fx_journal_lines jl
        JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
        WHERE je.branch_id = p_branch_id
          AND NOT je.is_void
          AND je.entry_date <= p_to
          AND jl.account_id = v_liability
      ), 0),
      'remittance_count', (
        SELECT COUNT(*) FROM fx_remittances r
        WHERE r.branch_id = p_branch_id
          AND COALESCE(r.booked_at, r.created_at)::DATE BETWEEN p_from AND p_to
      ),
      'completed_count', (
        SELECT COUNT(*) FROM fx_remittances r
        WHERE r.branch_id = p_branch_id
          AND r.status = 'completed'
          AND COALESCE(r.completed_at, r.updated_at)::DATE BETWEEN p_from AND p_to
      )
    ),
    'daily_collections', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'date', d.day,
        'collections', d.collections,
        'commission', d.commission,
        'payouts', d.payouts
      ) ORDER BY d.day)
      FROM (
        SELECT
          e.created_at::DATE AS day,
          SUM(CASE WHEN e.event_type = 'customer_payment' THEN e.amount ELSE 0 END) AS collections,
          0::NUMERIC AS commission,
          SUM(CASE WHEN e.event_type = 'payout_confirmed' THEN e.amount ELSE 0 END) AS payouts
        FROM fx_remittance_events e
        JOIN fx_remittances r ON r.id = e.remittance_id
        WHERE r.branch_id = p_branch_id
          AND e.created_at::DATE BETWEEN p_from AND p_to
          AND e.event_type IN ('customer_payment', 'payout_confirmed')
        GROUP BY e.created_at::DATE
      ) d
    ), '[]'::JSONB)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION fx_remittance_cash_flow_summary(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_remittance_agent_statement(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_remittance_customer_statement(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_remittance_branch_statement(UUID, DATE, DATE) TO authenticated;

NOTIFY pgrst, 'reload schema';
