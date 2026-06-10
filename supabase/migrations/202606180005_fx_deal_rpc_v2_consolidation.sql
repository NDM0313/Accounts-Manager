-- FX Deal RPC v2 consolidation — resolves PostgREST PGRST203 overload ambiguity
-- Project: ygidlcqhupmxvsdjmvnf only
--
-- Drops ALL legacy fx_add_deal_leg / fx_book_customer_deal overloads.
-- Creates single JSONB entry points: fx_add_deal_leg_v2, fx_book_customer_deal_v2
-- Business logic merged from 202606170003 + optional rate snapshot columns from 180002.
--
-- Rule: never add positional overloads to deal RPCs; extend JSONB keys only.

-- ---------------------------------------------------------------------------
-- Snapshot / rate metadata columns (idempotent)
-- ---------------------------------------------------------------------------

ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS rate_source TEXT NOT NULL DEFAULT 'manual';
ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS superseded_at TIMESTAMPTZ;

ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate NUMERIC(20, 8);
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_source TEXT;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_pair TEXT;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_at TIMESTAMPTZ;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_is_stale BOOLEAN;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS deal_rate_spread NUMERIC(20, 8);
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS deal_rate_spread_percent NUMERIC(10, 4);
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS rate_locked_at TIMESTAMPTZ;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS rate_locked_by UUID REFERENCES auth.users(id);
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_id UUID REFERENCES fx_rates(id);

ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate NUMERIC(20, 8);
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_source TEXT;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_pair TEXT;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_at TIMESTAMPTZ;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_is_stale BOOLEAN;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS deal_rate_spread NUMERIC(20, 8);
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS deal_rate_spread_percent NUMERIC(10, 4);
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS rate_locked_at TIMESTAMPTZ;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS rate_locked_by UUID REFERENCES auth.users(id);
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_id UUID REFERENCES fx_rates(id);

ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate NUMERIC(20, 8);
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate_source TEXT;
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate_pair TEXT;
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate_at TIMESTAMPTZ;
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate_is_stale BOOLEAN;
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS deal_rate_spread NUMERIC(20, 8);
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS deal_rate_spread_percent NUMERIC(10, 4);
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS rate_locked_at TIMESTAMPTZ;
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS rate_locked_by UUID REFERENCES auth.users(id);
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate_id UUID REFERENCES fx_rates(id);

-- ---------------------------------------------------------------------------
-- Drop legacy overloaded RPCs (explicit signatures)
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.fx_add_deal_leg(
  uuid, fx_deal_leg_type, uuid, text, numeric, text, numeric, numeric,
  fx_delivery_target, uuid, text
);

DROP FUNCTION IF EXISTS public.fx_add_deal_leg(
  uuid, fx_deal_leg_type, uuid, text, numeric, text, numeric, numeric,
  fx_delivery_target, uuid, text,
  numeric, text, text, timestamptz, boolean, numeric, numeric, uuid, timestamptz, uuid
);

DROP FUNCTION IF EXISTS public.fx_book_customer_deal(
  uuid, uuid, text, numeric, numeric, numeric,
  fx_delivery_method, boolean, text, boolean
);

DROP FUNCTION IF EXISTS public.fx_book_customer_deal(
  uuid, uuid, text, numeric, numeric, numeric,
  fx_delivery_method, boolean, text, boolean,
  numeric, text, text, timestamptz, boolean, numeric, numeric, uuid, timestamptz, uuid
);

DROP FUNCTION IF EXISTS public.fx_add_deal_leg_v2(jsonb);
DROP FUNCTION IF EXISTS public.fx_book_customer_deal_v2(jsonb);

-- ---------------------------------------------------------------------------
-- fx_book_customer_deal_v2 — JSONB payload
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_book_customer_deal_v2(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_deal_id UUID;
  v_payable NUMERIC(20, 8);
  v_currency TEXT;
  v_available NUMERIC;
  v_required NUMERIC;
  v_status fx_deal_status;
  v_branch_id UUID := (p_payload->>'branch_id')::UUID;
  v_customer_party_id UUID := (p_payload->>'customer_party_id')::UUID;
  v_sell_amount NUMERIC := COALESCE((p_payload->>'sell_amount')::NUMERIC, 0);
  v_sale_rate_pkr NUMERIC := COALESCE((p_payload->>'sale_rate_pkr')::NUMERIC, 0);
  v_paid_now NUMERIC := COALESCE((p_payload->>'customer_paid_now_pkr')::NUMERIC, 0);
  v_delivery_method fx_delivery_method := COALESCE(
    NULLIF(p_payload->>'delivery_method', '')::fx_delivery_method, 'later'::fx_delivery_method
  );
  v_allow_short BOOLEAN := COALESCE((p_payload->>'allow_short_position')::BOOLEAN, FALSE);
  v_notes TEXT := NULLIF(p_payload->>'notes', '');
  v_auto_source BOOLEAN := COALESCE((p_payload->>'auto_source')::BOOLEAN, TRUE);
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_profile FROM fx_current_profile();
  IF NOT fx_same_branch(v_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  v_currency := fx_normalize_currency_code(p_payload->>'sell_currency_code');
  v_payable := ROUND(v_sell_amount * v_sale_rate_pkr, 8);

  INSERT INTO fx_deals (
    company_id, branch_id, customer_party_id,
    sell_currency_code, sell_amount, sale_rate_pkr,
    customer_payable_pkr, customer_paid_pkr, customer_receivable_pkr,
    delivery_method, status, allow_short_position, notes,
    booked_at, created_by,
    reference_rate, reference_rate_pair, reference_rate_source, reference_rate_at,
    reference_rate_is_stale, deal_rate_spread, deal_rate_spread_percent,
    reference_rate_id, rate_locked_at, rate_locked_by
  ) VALUES (
    v_profile.company_id, v_branch_id, v_customer_party_id,
    v_currency, v_sell_amount, v_sale_rate_pkr,
    v_payable, v_paid_now,
    GREATEST(0, v_payable - v_paid_now),
    v_delivery_method,
    (CASE
      WHEN v_paid_now >= v_payable THEN 'customer_paid'
      WHEN v_paid_now > 0 THEN 'customer_partially_paid'
      ELSE 'booked'
    END)::fx_deal_status,
    v_allow_short,
    v_notes,
    NOW(), auth.uid(),
    NULLIF(p_payload->>'reference_rate', '')::NUMERIC,
    NULLIF(p_payload->>'reference_rate_pair', ''),
    NULLIF(p_payload->>'reference_rate_source', ''),
    NULLIF(p_payload->>'reference_rate_at', '')::TIMESTAMPTZ,
    (p_payload->>'reference_rate_is_stale')::BOOLEAN,
    NULLIF(p_payload->>'deal_rate_spread', '')::NUMERIC,
    NULLIF(p_payload->>'deal_rate_spread_percent', '')::NUMERIC,
    NULLIF(p_payload->>'reference_rate_id', '')::UUID,
    NULLIF(p_payload->>'rate_locked_at', '')::TIMESTAMPTZ,
    NULLIF(p_payload->>'rate_locked_by', '')::UUID
  )
  RETURNING id INTO v_deal_id;

  UPDATE fx_deals SET deal_no = fx_generate_deal_no(v_branch_id) WHERE id = v_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    remaining_amount, notes,
    reference_rate, reference_rate_pair, reference_rate_source, reference_rate_at,
    reference_rate_is_stale, deal_rate_spread, deal_rate_spread_percent,
    reference_rate_id, rate_locked_at, rate_locked_by
  ) VALUES (
    v_deal_id, 1, 'customer_order'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, v_customer_party_id,
    v_currency, v_sell_amount, 'PKR', v_payable, v_sale_rate_pkr,
    0, 'Customer FX order booked',
    NULLIF(p_payload->>'reference_rate', '')::NUMERIC,
    NULLIF(p_payload->>'reference_rate_pair', ''),
    NULLIF(p_payload->>'reference_rate_source', ''),
    NULLIF(p_payload->>'reference_rate_at', '')::TIMESTAMPTZ,
    (p_payload->>'reference_rate_is_stale')::BOOLEAN,
    NULLIF(p_payload->>'deal_rate_spread', '')::NUMERIC,
    NULLIF(p_payload->>'deal_rate_spread_percent', '')::NUMERIC,
    NULLIF(p_payload->>'reference_rate_id', '')::UUID,
    NULLIF(p_payload->>'rate_locked_at', '')::TIMESTAMPTZ,
    NULLIF(p_payload->>'rate_locked_by', '')::UUID
  );

  INSERT INTO fx_currency_commitments (
    deal_id, leg_id, currency_code, commitment_type, committed_amount
  ) VALUES (
    v_deal_id,
    (SELECT id FROM fx_deal_legs WHERE deal_id = v_deal_id AND leg_no = 1),
    v_currency, 'customer_sale'::fx_commitment_type, v_sell_amount
  );

  v_available := fx_deal_actual_balance(v_branch_id, v_currency)
    - fx_deal_open_commitment(v_branch_id, v_currency, 'customer_sale'::fx_commitment_type)
    + v_sell_amount;
  v_required := GREATEST(0, v_sell_amount - v_available);

  IF v_required > 0 AND v_auto_source THEN
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
  ELSIF v_required > 0 AND NOT v_allow_short THEN
    UPDATE fx_deals SET status = 'sourcing_required'::fx_deal_status WHERE id = v_deal_id;
  END IF;

  RETURN v_deal_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_add_deal_leg_v2 — JSONB payload (full 170003 logic + snapshots)
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
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_deal FROM fx_deals WHERE id = v_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = v_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    paid_amount, remaining_amount, delivery_target, parent_leg_id, notes,
    reference_rate, reference_rate_pair, reference_rate_source, reference_rate_at,
    reference_rate_is_stale, deal_rate_spread, deal_rate_spread_percent,
    reference_rate_id, rate_locked_at, rate_locked_by
  ) VALUES (
    v_deal_id, v_leg_no, v_leg_type, 'pending'::fx_deal_leg_status, v_counterparty,
    CASE WHEN v_receive_currency IS NOT NULL THEN fx_normalize_currency_code(v_receive_currency) ELSE NULL END,
    v_receive_amount,
    CASE WHEN v_pay_currency IS NOT NULL THEN fx_normalize_currency_code(v_pay_currency) ELSE NULL END,
    v_pay_amount, v_rate_used,
    0, COALESCE(v_pay_amount, v_receive_amount, 0),
    v_delivery_target, v_parent_leg_id, v_notes,
    NULLIF(p_payload->>'reference_rate', '')::NUMERIC,
    NULLIF(p_payload->>'reference_rate_pair', ''),
    NULLIF(p_payload->>'reference_rate_source', ''),
    NULLIF(p_payload->>'reference_rate_at', '')::TIMESTAMPTZ,
    (p_payload->>'reference_rate_is_stale')::BOOLEAN,
    NULLIF(p_payload->>'deal_rate_spread', '')::NUMERIC,
    NULLIF(p_payload->>'deal_rate_spread_percent', '')::NUMERIC,
    NULLIF(p_payload->>'reference_rate_id', '')::UUID,
    NULLIF(p_payload->>'rate_locked_at', '')::TIMESTAMPTZ,
    NULLIF(p_payload->>'rate_locked_by', '')::UUID
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
  END IF;

  RETURN v_leg_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- Grants (v2 only — legacy names removed from PostgREST)
-- ---------------------------------------------------------------------------

GRANT EXECUTE ON FUNCTION fx_book_customer_deal_v2(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_add_deal_leg_v2(JSONB) TO authenticated;

NOTIFY pgrst, 'reload schema';
