-- Scenario 04: receipt must target specific agent_source; unrelated leg untouched
SET statement_timeout = '60s';
SELECT set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', false);

DO $$
DECLARE
  v_deal UUID;
  v_leg1 UUID;
  v_leg2 UUID;
  v_receipt UUID;
  v_l1 fx_deal_legs;
  v_l2 fx_deal_legs;
BEGIN
  v_deal := fx_book_customer_deal_v2(jsonb_build_object(
    'branch_id', '22222222-2222-4222-8222-222222222222',
    'customer_party_id', 'c1111111-c111-4111-8111-c11111111111',
    'sell_currency_code', 'USD',
    'sell_amount', 5000,
    'sale_rate_pkr', 280,
    'delivery_method', 'agent'
  ));

  v_leg1 := fx_add_deal_leg_v2(jsonb_build_object(
    'deal_id', v_deal,
    'leg_type', 'agent_source',
    'counterparty_party_id', 'b1111111-b111-4111-8111-b11111111111',
    'receive_currency', 'USD',
    'receive_amount', 3000
  ));
  v_leg2 := fx_add_deal_leg_v2(jsonb_build_object(
    'deal_id', v_deal,
    'leg_type', 'agent_source',
    'counterparty_party_id', 'b2222222-b222-4222-8222-b22222222222',
    'receive_currency', 'USD',
    'receive_amount', 2000
  ));

  BEGIN
    PERFORM fx_add_deal_leg_v2(jsonb_build_object(
      'deal_id', v_deal,
      'leg_type', 'currency_receipt',
      'receive_currency', 'USD',
      'receive_amount', 1000
    ));
    RAISE EXCEPTION 'FAIL expected parent_leg_id required';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%parent_leg_id%' THEN RAISE; END IF;
  END;

  v_receipt := fx_add_deal_leg_v2(jsonb_build_object(
    'deal_id', v_deal,
    'leg_type', 'currency_receipt',
    'parent_leg_id', v_leg2,
    'counterparty_party_id', 'b2222222-b222-4222-8222-b22222222222',
    'receive_currency', 'USD',
    'receive_amount', 1500
  ));

  SELECT * INTO v_l1 FROM fx_deal_legs WHERE id = v_leg1;
  SELECT * INTO v_l2 FROM fx_deal_legs WHERE id = v_leg2;
  IF v_l1.status <> 'pending' OR v_l1.paid_amount <> 0 THEN
    RAISE EXCEPTION 'FAIL leg1 must stay pending untouched';
  END IF;
  IF v_l2.status <> 'partial' OR v_l2.paid_amount <> 1500 THEN
    RAISE EXCEPTION 'FAIL leg2 partial paid=% status=%', v_l2.paid_amount, v_l2.status;
  END IF;

  RAISE NOTICE 'PASS scenario_04_deal_receipt_leg receipt=%', v_receipt;
END $$;
