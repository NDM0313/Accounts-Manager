-- Fix 42P01: output column "deal" conflicted with SQL table reference in v_row.deal.id

DROP FUNCTION IF EXISTS fx_delete_deal_leg_v2(UUID);
DROP FUNCTION IF EXISTS fx_update_deal_leg_v2(JSONB);
DROP FUNCTION IF EXISTS fx_assert_deal_leg_mutable(UUID);

CREATE OR REPLACE FUNCTION fx_assert_deal_leg_mutable(p_leg_id UUID)
RETURNS TABLE (leg fx_deal_legs, deal_row fx_deals)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_leg fx_deal_legs;
  v_deal fx_deals;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_leg FROM fx_deal_legs WHERE id = p_leg_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal leg not found'; END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = v_leg.deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  IF v_deal.status IN ('completed', 'cancelled', 'voided') THEN
    RAISE EXCEPTION 'Cannot modify legs on a % deal', v_deal.status;
  END IF;

  IF v_leg.status <> 'pending'::fx_deal_leg_status THEN
    RAISE EXCEPTION 'Only pending legs can be edited or deleted';
  END IF;

  IF v_leg.linked_transaction_id IS NOT NULL THEN
    RAISE EXCEPTION 'Leg is linked to a posted transaction';
  END IF;

  IF v_leg.leg_type IN (
    'customer_order'::fx_deal_leg_type,
    'customer_payment'::fx_deal_leg_type,
    'delivery'::fx_deal_leg_type
  ) THEN
    RAISE EXCEPTION 'Leg type % cannot be edited or deleted', v_leg.leg_type;
  END IF;

  RETURN QUERY SELECT v_leg, v_deal;
END;
$$;

CREATE OR REPLACE FUNCTION fx_delete_deal_leg_v2(p_leg_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check RECORD;
  v_deal fx_deals;
  v_deal_id UUID;
BEGIN
  SELECT * INTO v_check FROM fx_assert_deal_leg_mutable(p_leg_id);
  v_deal := v_check.deal_row;
  v_deal_id := v_deal.id;

  DELETE FROM fx_settlement_links
  WHERE from_leg_id = p_leg_id OR to_leg_id = p_leg_id;

  DELETE FROM fx_currency_commitments WHERE leg_id = p_leg_id;

  DELETE FROM fx_deal_legs WHERE id = p_leg_id;

  PERFORM fx_recompute_deal_status(v_deal_id);

  RETURN p_leg_id;
END;
$$;

CREATE OR REPLACE FUNCTION fx_update_deal_leg_v2(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check RECORD;
  v_leg fx_deal_legs;
  v_deal fx_deals;
  v_leg_id UUID := (p_payload->>'leg_id')::UUID;
  v_receive_currency TEXT := NULLIF(p_payload->>'receive_currency', '');
  v_receive_amount NUMERIC := COALESCE((p_payload->>'receive_amount')::NUMERIC, 0);
  v_pay_currency TEXT := NULLIF(p_payload->>'pay_currency', '');
  v_pay_amount NUMERIC := COALESCE((p_payload->>'pay_amount')::NUMERIC, 0);
  v_rate_used NUMERIC := NULLIF(p_payload->>'rate_used', '')::NUMERIC;
  v_delivery_target fx_delivery_target := NULLIF(p_payload->>'delivery_target', '')::fx_delivery_target;
  v_counterparty UUID := NULLIF(p_payload->>'counterparty_party_id', '')::UUID;
  v_notes TEXT := NULLIF(p_payload->>'notes', '');
  v_remaining NUMERIC;
BEGIN
  SELECT * INTO v_check FROM fx_assert_deal_leg_mutable(v_leg_id);
  v_leg := v_check.leg;
  v_deal := v_check.deal_row;

  v_remaining := COALESCE(NULLIF(v_pay_amount, 0), NULLIF(v_receive_amount, 0), v_leg.remaining_amount);

  UPDATE fx_deal_legs SET
    counterparty_party_id = COALESCE(v_counterparty, counterparty_party_id),
    receive_currency = CASE
      WHEN p_payload ? 'receive_currency' THEN
        CASE WHEN v_receive_currency IS NOT NULL THEN fx_normalize_currency_code(v_receive_currency) ELSE NULL END
      ELSE receive_currency
    END,
    receive_amount = CASE WHEN p_payload ? 'receive_amount' THEN v_receive_amount ELSE receive_amount END,
    pay_currency = CASE
      WHEN p_payload ? 'pay_currency' THEN
        CASE WHEN v_pay_currency IS NOT NULL THEN fx_normalize_currency_code(v_pay_currency) ELSE NULL END
      ELSE pay_currency
    END,
    pay_amount = CASE WHEN p_payload ? 'pay_amount' THEN v_pay_amount ELSE pay_amount END,
    rate_used = CASE WHEN p_payload ? 'rate_used' THEN v_rate_used ELSE rate_used END,
    remaining_amount = v_remaining,
    delivery_target = CASE WHEN p_payload ? 'delivery_target' THEN v_delivery_target ELSE delivery_target END,
    notes = CASE WHEN p_payload ? 'notes' THEN v_notes ELSE notes END,
    reference_rate = CASE WHEN p_payload ? 'reference_rate' THEN NULLIF(p_payload->>'reference_rate', '')::NUMERIC ELSE reference_rate END,
    reference_rate_pair = CASE WHEN p_payload ? 'reference_rate_pair' THEN NULLIF(p_payload->>'reference_rate_pair', '') ELSE reference_rate_pair END,
    reference_rate_source = CASE WHEN p_payload ? 'reference_rate_source' THEN NULLIF(p_payload->>'reference_rate_source', '') ELSE reference_rate_source END,
    reference_rate_at = CASE WHEN p_payload ? 'reference_rate_at' THEN NULLIF(p_payload->>'reference_rate_at', '')::TIMESTAMPTZ ELSE reference_rate_at END,
    reference_rate_is_stale = CASE WHEN p_payload ? 'reference_rate_is_stale' THEN (p_payload->>'reference_rate_is_stale')::BOOLEAN ELSE reference_rate_is_stale END,
    deal_rate_spread = CASE WHEN p_payload ? 'deal_rate_spread' THEN NULLIF(p_payload->>'deal_rate_spread', '')::NUMERIC ELSE deal_rate_spread END,
    deal_rate_spread_percent = CASE WHEN p_payload ? 'deal_rate_spread_percent' THEN NULLIF(p_payload->>'deal_rate_spread_percent', '')::NUMERIC ELSE deal_rate_spread_percent END,
    reference_rate_id = CASE WHEN p_payload ? 'reference_rate_id' THEN NULLIF(p_payload->>'reference_rate_id', '')::UUID ELSE reference_rate_id END,
    rate_locked_at = CASE WHEN p_payload ? 'rate_locked_at' THEN NULLIF(p_payload->>'rate_locked_at', '')::TIMESTAMPTZ ELSE rate_locked_at END,
    rate_locked_by = CASE WHEN p_payload ? 'rate_locked_by' THEN NULLIF(p_payload->>'rate_locked_by', '')::UUID ELSE rate_locked_by END,
    updated_at = NOW()
  WHERE id = v_leg_id;

  IF v_leg.leg_type = 'agent_source'::fx_deal_leg_type THEN
    UPDATE fx_currency_commitments SET
      currency_code = COALESCE(fx_normalize_currency_code(v_receive_currency), currency_code),
      committed_amount = CASE WHEN p_payload ? 'receive_amount' THEN v_receive_amount ELSE committed_amount END,
      updated_at = NOW()
    WHERE leg_id = v_leg_id;

    IF NOT FOUND AND v_receive_currency IS NOT NULL THEN
      INSERT INTO fx_currency_commitments (deal_id, leg_id, currency_code, commitment_type, committed_amount)
      VALUES (
        v_deal.id, v_leg_id,
        fx_normalize_currency_code(v_receive_currency),
        'on_order_inbound'::fx_commitment_type,
        v_receive_amount
      );
    END IF;
  END IF;

  PERFORM fx_recompute_deal_status(v_deal.id);

  RETURN v_leg_id;
END;
$$;

NOTIFY pgrst, 'reload schema';
