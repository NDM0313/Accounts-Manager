-- FX Ledger workflow smoke test (run on Cloud ygidlcqhupmxvsdjmvnf after 202606180005)
-- Asserts: no legacy overloads, v2 RPCs work, agent_source side effects, payment math

DO $$
DECLARE
  v_legacy_add INT;
  v_legacy_book INT;
  v_v2_add INT;
  v_v2_book INT;
  v_branch UUID := '00000000-0000-4000-8000-000000000002';
  v_customer UUID;
  v_agent UUID;
  v_deal_id UUID;
  v_leg_id UUID;
  v_deal_status TEXT;
  v_commitment_count INT;
  v_paid NUMERIC;
  v_receivable NUMERIC;
BEGIN
  -- 1) Overload check
  SELECT COUNT(*) INTO v_legacy_add
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'fx_add_deal_leg';

  SELECT COUNT(*) INTO v_legacy_book
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'fx_book_customer_deal';

  SELECT COUNT(*) INTO v_v2_add
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'fx_add_deal_leg_v2';

  SELECT COUNT(*) INTO v_v2_book
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'fx_book_customer_deal_v2';

  IF v_legacy_add <> 0 THEN
    RAISE EXCEPTION 'FAIL: expected 0 fx_add_deal_leg overloads, found %', v_legacy_add;
  END IF;
  IF v_legacy_book <> 0 THEN
    RAISE EXCEPTION 'FAIL: expected 0 fx_book_customer_deal overloads, found %', v_legacy_book;
  END IF;
  IF v_v2_add <> 1 THEN
    RAISE EXCEPTION 'FAIL: expected 1 fx_add_deal_leg_v2, found %', v_v2_add;
  END IF;
  IF v_v2_book <> 1 THEN
    RAISE EXCEPTION 'FAIL: expected 1 fx_book_customer_deal_v2, found %', v_v2_book;
  END IF;
  RAISE NOTICE 'PASS: RPC overload check';

  SELECT id INTO v_customer FROM fx_parties WHERE party_type = 'customer' AND is_active LIMIT 1;
  SELECT id INTO v_agent FROM fx_parties WHERE party_type = 'agent' AND is_active LIMIT 1;
  IF v_customer IS NULL OR v_agent IS NULL THEN
    RAISE NOTICE 'SKIP deal workflow: need active customer and agent parties';
    RETURN;
  END IF;

  BEGIN
    -- Deal workflow requires authenticated FX user (fx_has_permission). CLI runs skip here.
    SELECT fx_book_customer_deal_v2(jsonb_build_object(
    'branch_id', v_branch,
    'customer_party_id', v_customer,
    'sell_currency_code', 'USD',
    'sell_amount', 10000,
    'sale_rate_pkr', 280,
    'customer_paid_now_pkr', 0,
    'delivery_method', 'later',
    'allow_short_position', false,
    'notes', 'Smoke test book',
    'auto_source', true
  )) INTO v_deal_id;

  SELECT status::text INTO v_deal_status FROM fx_deals WHERE id = v_deal_id;
  IF v_deal_status NOT IN ('sourcing_required', 'booked') THEN
    RAISE EXCEPTION 'FAIL: unexpected deal status after book: %', v_deal_status;
  END IF;
  RAISE NOTICE 'PASS: book customer deal % status=%', v_deal_id, v_deal_status;

  -- 3) Agent source leg → sourcing_in_progress + on_order_inbound commitment
  SELECT fx_add_deal_leg_v2(jsonb_build_object(
    'deal_id', v_deal_id,
    'leg_type', 'agent_source',
    'counterparty_party_id', v_agent,
    'receive_currency', 'USD',
    'receive_amount', 10000,
    'pay_currency', 'AED',
    'pay_amount', 36700,
    'rate_used', 0.272,
    'delivery_target', 'our_account',
    'notes', 'Smoke agent source'
  )) INTO v_leg_id;

  SELECT status::text INTO v_deal_status FROM fx_deals WHERE id = v_deal_id;
  IF v_deal_status <> 'sourcing_in_progress' THEN
    RAISE EXCEPTION 'FAIL: expected sourcing_in_progress, got %', v_deal_status;
  END IF;

  SELECT COUNT(*) INTO v_commitment_count
  FROM fx_currency_commitments
  WHERE deal_id = v_deal_id AND commitment_type = 'on_order_inbound' AND leg_id = v_leg_id;

  IF v_commitment_count <> 1 THEN
    RAISE EXCEPTION 'FAIL: expected on_order_inbound commitment for leg %', v_leg_id;
  END IF;
  RAISE NOTICE 'PASS: agent source leg + commitment';

  -- 4) Partial customer payment — no double count (book with 0, pay once)
  PERFORM fx_record_deal_customer_payment(v_deal_id, 500000, 'Smoke partial payment');

  SELECT customer_paid_pkr, customer_receivable_pkr
  INTO v_paid, v_receivable
  FROM fx_deals WHERE id = v_deal_id;

  IF v_paid <> 500000 THEN
    RAISE EXCEPTION 'FAIL: customer_paid_pkr expected 500000, got %', v_paid;
  END IF;
  IF v_receivable <> GREATEST(0, 2800000 - 500000) THEN
    RAISE EXCEPTION 'FAIL: customer_receivable_pkr expected %, got %',
      GREATEST(0, 2800000 - 500000), v_receivable;
  END IF;
  RAISE NOTICE 'PASS: customer payment math paid=% receivable=%', v_paid, v_receivable;

  RAISE NOTICE 'ALL FX LEDGER SMOKE CHECKS PASSED';
  EXCEPTION
    WHEN others THEN
      IF SQLERRM LIKE '%Unauthorized%' THEN
        RAISE NOTICE 'SKIP deal workflow: requires authenticated FX user (test via Flutter Agent Source Leg)';
        RAISE NOTICE 'PASS: overload check only (CLI context)';
      ELSE
        RAISE;
      END IF;
  END;
END $$;
