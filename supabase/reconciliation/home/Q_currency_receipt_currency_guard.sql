-- Q_currency_receipt_currency_guard.sql
-- Enforce currency + source-agent match BEFORE amount/remaining comparison
-- on currency_receipt. Keeps over-remaining guard intact. Adds optional
-- client_operation_id idempotency for receipt retries.

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
  v_op TEXT := NULLIF(TRIM(p_payload->>'client_operation_id'), '');
  v_leg_status fx_deal_leg_status := CASE
    WHEN v_leg_type = 'currency_receipt' THEN 'completed'::fx_deal_leg_status
    ELSE 'pending'::fx_deal_leg_status
  END;
  v_source fx_deal_legs;
  v_remaining NUMERIC;
  v_source_ccy TEXT;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_deal FROM fx_deals WHERE id = v_deal_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;
  IF NOT fx_same_company(v_deal.company_id) THEN
    RAISE EXCEPTION 'Unauthorized company access';
  END IF;

  -- Idempotent retry for currency_receipt (and other legs when key provided)
  IF v_op IS NOT NULL THEN
    SELECT entity_id INTO v_leg_id
    FROM fx_client_operations
    WHERE company_id = v_deal.company_id AND operation_key = v_op;
    IF v_leg_id IS NOT NULL THEN
      RETURN v_leg_id;
    END IF;
  END IF;

  IF v_leg_type = 'currency_receipt' THEN
    IF v_parent_leg_id IS NULL THEN
      RAISE EXCEPTION
        'currency_receipt requires parent_leg_id targeting agent_source';
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

    v_source_ccy := fx_normalize_currency_code(v_source.receive_currency);
    IF v_source_ccy IS NULL OR v_source_ccy = '' THEN
      RAISE EXCEPTION 'Source agent leg has no receive currency';
    END IF;

    -- Currency must match source BEFORE any amount/remaining comparison.
    IF v_receive_currency IS NULL OR btrim(v_receive_currency) = '' THEN
      v_receive_currency := v_source_ccy;
    ELSE
      v_receive_currency := fx_normalize_currency_code(v_receive_currency);
    END IF;
    IF v_receive_currency IS DISTINCT FROM v_source_ccy THEN
      RAISE EXCEPTION
        'CURRENCY_MISMATCH: currency receipt must use source currency % (got %). Do not compare amounts across currencies. Use Customer Payment for PKR against the deal.',
        v_source_ccy, v_receive_currency;
    END IF;

    -- Counterparty must be the source agent (or omitted → inherit).
    IF v_counterparty IS NULL THEN
      v_counterparty := v_source.counterparty_party_id;
    ELSIF v_source.counterparty_party_id IS NOT NULL
          AND v_counterparty IS DISTINCT FROM v_source.counterparty_party_id THEN
      RAISE EXCEPTION
        'COUNTERPARTY_MISMATCH: currency receipt counterparty must be the source agent on the selected leg';
    END IF;

    v_remaining := GREATEST(0, v_source.receive_amount - v_source.paid_amount);
    IF v_receive_amount <= 0 THEN
      RAISE EXCEPTION
        'Receipt amount must be greater than zero (% %)',
        v_receive_amount, v_receive_currency;
    END IF;
    IF v_receive_amount > v_remaining + 0.00000001 THEN
      RAISE EXCEPTION
        'OVER_REMAINING: receipt % % exceeds remaining % % on source leg',
        v_receive_amount, v_receive_currency, v_remaining, v_receive_currency;
    END IF;
  END IF;

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no
  FROM fx_deal_legs WHERE deal_id = v_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    paid_amount, remaining_amount, delivery_target, parent_leg_id, notes,
    linked_transaction_id, completed_at
  ) VALUES (
    v_deal_id, v_leg_no, v_leg_type, v_leg_status, v_counterparty,
    CASE WHEN v_receive_currency IS NOT NULL
      THEN fx_normalize_currency_code(v_receive_currency) ELSE NULL END,
    v_receive_amount,
    CASE WHEN v_pay_currency IS NOT NULL
      THEN fx_normalize_currency_code(v_pay_currency) ELSE NULL END,
    v_pay_amount, v_rate_used,
    CASE WHEN v_leg_type = 'currency_receipt' THEN v_receive_amount ELSE 0 END,
    CASE WHEN v_leg_type = 'currency_receipt'
      THEN 0 ELSE COALESCE(v_pay_amount, v_receive_amount, 0) END,
    v_delivery_target, v_parent_leg_id, v_notes,
    v_linked_tx,
    CASE WHEN v_leg_status = 'completed' THEN NOW() ELSE NULL END
  ) RETURNING id INTO v_leg_id;

  IF v_leg_type = 'agent_source' THEN
    UPDATE fx_deals
    SET status = 'sourcing_in_progress'::fx_deal_status, updated_at = NOW()
    WHERE id = v_deal_id;
    INSERT INTO fx_currency_commitments (
      deal_id, leg_id, currency_code, commitment_type, committed_amount
    ) VALUES (
      v_deal_id, v_leg_id,
      fx_normalize_currency_code(v_receive_currency),
      'on_order_inbound'::fx_commitment_type,
      v_receive_amount
    );
  ELSIF v_leg_type = 'currency_receipt' THEN
    UPDATE fx_deal_legs SET
      paid_amount = paid_amount + v_receive_amount,
      remaining_amount = GREATEST(0, receive_amount - (paid_amount + v_receive_amount)),
      status = CASE
        WHEN paid_amount + v_receive_amount + 0.00000001 >= receive_amount
          THEN 'completed'::fx_deal_leg_status
        ELSE 'partial'::fx_deal_leg_status
      END,
      completed_at = CASE
        WHEN paid_amount + v_receive_amount + 0.00000001 >= receive_amount
          THEN COALESCE(completed_at, NOW())
        ELSE completed_at
      END,
      linked_transaction_id = COALESCE(linked_transaction_id, v_linked_tx),
      updated_at = NOW()
    WHERE id = v_parent_leg_id;

    IF v_deal.status NOT IN ('delivered', 'completed', 'cancelled', 'voided') THEN
      UPDATE fx_deals
      SET status = 'currency_received'::fx_deal_status, updated_at = NOW()
      WHERE id = v_deal_id;
    END IF;
  END IF;

  IF v_op IS NOT NULL THEN
    INSERT INTO fx_client_operations (
      company_id, operation_key, operation_type, entity_type, entity_id,
      result_json, created_by
    ) VALUES (
      v_deal.company_id, v_op, 'deal_leg_add', 'fx_deal_leg', v_leg_id,
      jsonb_build_object('leg_id', v_leg_id, 'leg_type', v_leg_type::text),
      auth.uid()
    )
    ON CONFLICT (company_id, operation_key) DO NOTHING;
  END IF;

  RETURN v_leg_id;
END;
$$;

REVOKE ALL ON FUNCTION fx_add_deal_leg_v2(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_add_deal_leg_v2(JSONB) TO authenticated;

NOTIFY pgrst, 'reload schema';
