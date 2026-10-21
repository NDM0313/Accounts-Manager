-- Scenario 06: partial delivery proportions; cost never=sale; A6 recon RPC; idempotency payload
SET statement_timeout = '60s';
SELECT set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', false);

-- Ensure delivery P/L accounts exist
INSERT INTO fx_accounts (company_id, code, name, account_type)
SELECT '11111111-1111-4111-8111-111111111111', x.code, x.name, x.atype::fx_account_type
FROM (VALUES
  ('1160','Customer Advances','liability'),
  ('1190','Customer Receivable','asset'),
  ('4100','FX Spread Income','income')
) AS x(code,name,atype)
ON CONFLICT DO NOTHING;

DO $$
DECLARE
  v_deal UUID;
  v_leg1 UUID;
  v_leg2 UUID;
  v_d fx_deals;
  v_rows INT;
BEGIN
  v_deal := fx_book_customer_deal_v2(jsonb_build_object(
    'branch_id', '22222222-2222-4222-8222-222222222222',
    'customer_party_id', 'c1111111-c111-4111-8111-c11111111111',
    'sell_currency_code', 'USD',
    'sell_amount', 1000,
    'sale_rate_pkr', 280,
    'delivery_method', 'own_balance'
  ));

  -- Record full customer payment so receivable clears for delivery slice math
  PERFORM fx_record_deal_customer_payment(v_deal, 280000, 'full pay');

  BEGIN
    PERFORM fx_confirm_deal_delivery(
      v_deal, 400::numeric, 'direct_to_customer'::fx_delivery_target,
      NULL::numeric, NULL::text, 'no cost'::text, NULL::text
    );
    RAISE EXCEPTION 'FAIL expected cost_basis required';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%cost_basis%' THEN RAISE; END IF;
  END;

  v_leg1 := fx_confirm_deal_delivery(
    v_deal, 400::numeric, 'direct_to_customer'::fx_delivery_target,
    100000::numeric, 'proof-1', 'slice1', 'op-del-1'
  );
  -- Idempotent same key+payload
  PERFORM fx_confirm_deal_delivery(
    v_deal, 400::numeric, 'direct_to_customer'::fx_delivery_target,
    100000::numeric, 'proof-1', 'slice1', 'op-del-1'
  );

  BEGIN
    PERFORM fx_confirm_deal_delivery(
      v_deal, 500::numeric, 'direct_to_customer'::fx_delivery_target,
      110000::numeric, 'proof-diff', 'diff', 'op-del-1'
    );
    RAISE EXCEPTION 'FAIL expected payload mismatch';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%different payload%' AND SQLERRM NOT LIKE '%Idempotency%' THEN RAISE; END IF;
  END;

  SELECT * INTO v_d FROM fx_deals WHERE id = v_deal;
  IF v_d.delivered_amount <> 400 THEN
    RAISE EXCEPTION 'FAIL delivered_amount=%', v_d.delivered_amount;
  END IF;
  IF v_d.status::text NOT IN ('delivered', 'customer_paid', 'booked', 'currency_received')
     AND v_d.status <> 'delivered'::fx_deal_status THEN
    -- after partial must not be completed
    IF v_d.status = 'completed'::fx_deal_status THEN
      RAISE EXCEPTION 'FAIL must not complete after partial';
    END IF;
  END IF;
  IF v_d.status = 'completed'::fx_deal_status THEN
    RAISE EXCEPTION 'FAIL must not complete after partial delivery';
  END IF;

  -- Sale portion = 280000 * 0.4 = 112000; cost 100000; profit slice 12000
  IF ABS(v_d.delivered_cost_basis_pkr - 100000) > 0.01 THEN
    RAISE EXCEPTION 'FAIL cost total=%', v_d.delivered_cost_basis_pkr;
  END IF;

  v_leg2 := fx_confirm_deal_delivery(
    v_deal, 600::numeric, 'direct_to_customer'::fx_delivery_target,
    150000::numeric, 'proof-2', 'slice2', 'op-del-2'
  );

  SELECT * INTO v_d FROM fx_deals WHERE id = v_deal;
  IF ABS(v_d.delivered_amount - 1000) > 0.0001 THEN
    RAISE EXCEPTION 'FAIL final delivered=%', v_d.delivered_amount;
  END IF;
  IF v_d.status <> 'completed'::fx_deal_status THEN
    RAISE EXCEPTION 'FAIL expected completed status=%', v_d.status;
  END IF;
  IF ABS(v_d.delivered_cost_basis_pkr - 250000) > 0.01 THEN
    RAISE EXCEPTION 'FAIL final cost=%', v_d.delivered_cost_basis_pkr;
  END IF;
  -- profit = 280000 - 250000 = 30000
  IF ABS(COALESCE(v_d.actual_profit_pkr, 0) - 30000) > 1 THEN
    RAISE EXCEPTION 'FAIL profit=%', v_d.actual_profit_pkr;
  END IF;

  SELECT COUNT(*) INTO v_rows
  FROM fx_get_currency_pkr_reconciliation(
    '22222222-2222-4222-8222-222222222222'::uuid, NULL, CURRENT_DATE
  );
  IF v_rows < 1 THEN
    RAISE EXCEPTION 'FAIL A6 recon returned no rows';
  END IF;

  RAISE NOTICE 'PASS scenario_06_partial_delivery_a6 legs=% %', v_leg1, v_leg2;
END $$;
