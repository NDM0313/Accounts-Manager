-- DRAFT: Rate versioning metadata + reference rate snapshots (DO NOT deploy until approved)
-- Supersedes partial draft 202606180001_fx_rates_reference_snapshot.sql
-- Project: ygidlcqhupmxvsdjmvnf only
--
-- After approval: npx supabase db push, then set FeatureFlags.rateSnapshotColumnsEnabled = true

-- ---------------------------------------------------------------------------
-- fx_rates versioning metadata
-- ---------------------------------------------------------------------------

ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS rate_source TEXT NOT NULL DEFAULT 'manual';
ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS superseded_at TIMESTAMPTZ;

-- ---------------------------------------------------------------------------
-- fx_transactions reference snapshots (audit-only; posting uses rate_used)
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- fx_deal_legs reference snapshots
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- fx_deals reference snapshots (customer order booking)
-- ---------------------------------------------------------------------------

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
-- fx_book_customer_deal — optional snapshot params
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_book_customer_deal(
  p_branch_id UUID,
  p_customer_party_id UUID,
  p_sell_currency_code TEXT,
  p_sell_amount NUMERIC,
  p_sale_rate_pkr NUMERIC,
  p_customer_paid_now_pkr NUMERIC DEFAULT 0,
  p_delivery_method fx_delivery_method DEFAULT 'later',
  p_allow_short_position BOOLEAN DEFAULT FALSE,
  p_notes TEXT DEFAULT NULL,
  p_auto_source BOOLEAN DEFAULT TRUE,
  p_reference_rate NUMERIC DEFAULT NULL,
  p_reference_rate_pair TEXT DEFAULT NULL,
  p_reference_rate_source TEXT DEFAULT NULL,
  p_reference_rate_at TIMESTAMPTZ DEFAULT NULL,
  p_reference_rate_is_stale BOOLEAN DEFAULT NULL,
  p_deal_rate_spread NUMERIC DEFAULT NULL,
  p_deal_rate_spread_percent NUMERIC DEFAULT NULL,
  p_reference_rate_id UUID DEFAULT NULL,
  p_rate_locked_at TIMESTAMPTZ DEFAULT NULL,
  p_rate_locked_by UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_deal_id UUID;
  v_leg_id UUID;
  v_payable NUMERIC(20, 8);
  v_currency TEXT;
  v_available NUMERIC;
  v_required NUMERIC;
  v_status fx_deal_status;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_profile FROM fx_current_profile();
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  v_currency := fx_normalize_currency_code(p_sell_currency_code);
  v_payable := ROUND(p_sell_amount * p_sale_rate_pkr, 8);

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
    v_profile.company_id, p_branch_id, p_customer_party_id,
    v_currency, p_sell_amount, p_sale_rate_pkr,
    v_payable, COALESCE(p_customer_paid_now_pkr, 0),
    GREATEST(0, v_payable - COALESCE(p_customer_paid_now_pkr, 0)),
    p_delivery_method,
    (CASE
      WHEN COALESCE(p_customer_paid_now_pkr, 0) >= v_payable THEN 'customer_paid'
      WHEN COALESCE(p_customer_paid_now_pkr, 0) > 0 THEN 'customer_partially_paid'
      ELSE 'booked'
    END)::fx_deal_status,
    COALESCE(p_allow_short_position, FALSE),
    p_notes,
    NOW(), auth.uid(),
    p_reference_rate, p_reference_rate_pair, p_reference_rate_source, p_reference_rate_at,
    p_reference_rate_is_stale, p_deal_rate_spread, p_deal_rate_spread_percent,
    p_reference_rate_id, p_rate_locked_at, p_rate_locked_by
  )
  RETURNING id INTO v_deal_id;

  UPDATE fx_deals SET deal_no = fx_generate_deal_no(p_branch_id) WHERE id = v_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    remaining_amount, notes,
    reference_rate, reference_rate_pair, reference_rate_source, reference_rate_at,
    reference_rate_is_stale, deal_rate_spread, deal_rate_spread_percent,
    reference_rate_id, rate_locked_at, rate_locked_by
  ) VALUES (
    v_deal_id, 1, 'customer_order'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, p_customer_party_id,
    v_currency, p_sell_amount, 'PKR', v_payable, p_sale_rate_pkr,
    0, 'Customer FX order booked',
    p_reference_rate, p_reference_rate_pair, p_reference_rate_source, p_reference_rate_at,
    p_reference_rate_is_stale, p_deal_rate_spread, p_deal_rate_spread_percent,
    p_reference_rate_id, p_rate_locked_at, p_rate_locked_by
  );

  INSERT INTO fx_currency_commitments (
    deal_id, leg_id, currency_code, commitment_type, committed_amount
  ) VALUES (
    v_deal_id,
    (SELECT id FROM fx_deal_legs WHERE deal_id = v_deal_id AND leg_no = 1),
    v_currency, 'customer_sale'::fx_commitment_type, p_sell_amount
  );

  v_available := fx_deal_actual_balance(p_branch_id, v_currency) - fx_deal_open_commitment(p_branch_id, v_currency, 'customer_sale'::fx_commitment_type) + p_sell_amount;
  v_required := GREATEST(0, p_sell_amount - v_available);

  IF v_required > 0 AND p_auto_source THEN
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
  ELSIF v_required > 0 AND NOT COALESCE(p_allow_short_position, FALSE) THEN
    UPDATE fx_deals SET status = 'sourcing_required'::fx_deal_status WHERE id = v_deal_id;
  END IF;

  RETURN v_deal_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_add_deal_leg — optional snapshot params
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_add_deal_leg(
  p_deal_id UUID,
  p_leg_type fx_deal_leg_type,
  p_counterparty_party_id UUID DEFAULT NULL,
  p_receive_currency TEXT DEFAULT NULL,
  p_receive_amount NUMERIC DEFAULT 0,
  p_pay_currency TEXT DEFAULT NULL,
  p_pay_amount NUMERIC DEFAULT 0,
  p_rate_used NUMERIC DEFAULT NULL,
  p_delivery_target fx_delivery_target DEFAULT NULL,
  p_parent_leg_id UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_reference_rate NUMERIC DEFAULT NULL,
  p_reference_rate_pair TEXT DEFAULT NULL,
  p_reference_rate_source TEXT DEFAULT NULL,
  p_reference_rate_at TIMESTAMPTZ DEFAULT NULL,
  p_reference_rate_is_stale BOOLEAN DEFAULT NULL,
  p_deal_rate_spread NUMERIC DEFAULT NULL,
  p_deal_rate_spread_percent NUMERIC DEFAULT NULL,
  p_reference_rate_id UUID DEFAULT NULL,
  p_rate_locked_at TIMESTAMPTZ DEFAULT NULL,
  p_rate_locked_by UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_leg_no INT;
  v_leg_id UUID;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    paid_amount, remaining_amount, delivery_target, parent_leg_id, notes,
    reference_rate, reference_rate_pair, reference_rate_source, reference_rate_at,
    reference_rate_is_stale, deal_rate_spread, deal_rate_spread_percent,
    reference_rate_id, rate_locked_at, rate_locked_by
  ) VALUES (
    p_deal_id, v_leg_no, p_leg_type, 'pending'::fx_deal_leg_status, p_counterparty_party_id,
    CASE WHEN p_receive_currency IS NOT NULL THEN fx_normalize_currency_code(p_receive_currency) ELSE NULL END,
    COALESCE(p_receive_amount, 0),
    CASE WHEN p_pay_currency IS NOT NULL THEN fx_normalize_currency_code(p_pay_currency) ELSE NULL END,
    COALESCE(p_pay_amount, 0), p_rate_used,
    0, COALESCE(p_pay_amount, p_receive_amount, 0),
    p_delivery_target, p_parent_leg_id, p_notes,
    p_reference_rate, p_reference_rate_pair, p_reference_rate_source, p_reference_rate_at,
    p_reference_rate_is_stale, p_deal_rate_spread, p_deal_rate_spread_percent,
    p_reference_rate_id, p_rate_locked_at, p_rate_locked_by
  )
  RETURNING id INTO v_leg_id;

  RETURN v_leg_id;
END;
$$;
