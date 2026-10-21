-- Scenario 03: partial settlement; refund caps; duplicate refund rejected by idempotency/cap
SET statement_timeout = '60s';
SELECT set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', false);

DO $$
DECLARE
  v_rid UUID;
  v_tx UUID;
  v_r fx_remittances;
BEGIN
  v_rid := fx_create_remittance(
    '22222222-2222-4222-8222-222222222222',
    'c2222222-c222-4222-8222-c22222222222',
    'Recv Two', NULL, NULL, NULL,
    'b2222222-b222-4222-8222-b22222222222',
    'PKR', 50000, 'PKR', 50000, 1,
    0, NULL, 'internal', true
  );
  PERFORM fx_record_remittance_customer_payment(v_rid, 50000, '1110', 'full', 'op-full-1');

  v_tx := fx_settle_remittance_agent(v_rid, 20000, '1110', 's1', 'op-settle-1');
  SELECT * INTO v_r FROM fx_remittances WHERE id = v_rid;
  IF v_r.settlement_status <> 'partial' THEN RAISE EXCEPTION 'FAIL expect partial got %', v_r.settlement_status; END IF;
  IF v_r.status = 'completed' THEN RAISE EXCEPTION 'FAIL must not complete early'; END IF;
  IF v_r.settled_amount_pkr <> 20000 THEN RAISE EXCEPTION 'FAIL settled=%', v_r.settled_amount_pkr; END IF;

  PERFORM fx_settle_remittance_agent(v_rid, 30000, '1110', 's2', 'op-settle-2');
  SELECT * INTO v_r FROM fx_remittances WHERE id = v_rid;
  IF v_r.settlement_status <> 'settled' OR v_r.status <> 'completed' THEN
    RAISE EXCEPTION 'FAIL final settlement status=% remittance=%', v_r.settlement_status, v_r.status;
  END IF;

  -- New remittance for refund path
  v_rid := fx_create_remittance(
    '22222222-2222-4222-8222-222222222222',
    'c1111111-c111-4111-8111-c11111111111',
    'Recv Refund', NULL, NULL, NULL,
    'b1111111-b111-4111-8111-b11111111111',
    'PKR', 10000, 'PKR', 10000, 1,
    0, NULL, 'internal', true
  );
  PERFORM fx_record_remittance_customer_payment(v_rid, 10000, '1110', 'pay', 'op-rf-pay');
  v_tx := fx_refund_remittance(v_rid, 4000, '1110', 'r1', 'op-rf-1');
  PERFORM fx_refund_remittance(v_rid, 4000, '1110', 'r1', 'op-rf-1'); -- idempotent
  BEGIN
    PERFORM fx_refund_remittance(v_rid, 7000, '1110', 'over', 'op-rf-over');
    RAISE EXCEPTION 'FAIL expected over-refund error';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Refund %' THEN RAISE; END IF;
  END;

  RAISE NOTICE 'PASS scenario_03_partial_settlement_refund';
END $$;
