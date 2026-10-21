-- Scenario 02: three partial payments; commission recognized once total only
SET statement_timeout = '60s';
SELECT set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', false);

DO $$
DECLARE
  v_rid UUID;
  v_tx1 UUID; v_tx2 UUID; v_tx3 UUID; v_tx_dup UUID;
  v_r fx_remittances;
  v_comm_lines NUMERIC;
BEGIN
  v_rid := fx_create_remittance(
    '22222222-2222-4222-8222-222222222222',
    'c1111111-c111-4111-8111-c11111111111',
    'Recv One', NULL, NULL, NULL,
    'b1111111-b111-4111-8111-b11111111111',
    'PKR', 100000, 'PKR', 100000, 1,
    2000, NULL, 'customer_paid', true
  );

  v_tx1 := fx_record_remittance_customer_payment(v_rid, 30000, '1110', 'p1', 'op-pay-1');
  v_tx2 := fx_record_remittance_customer_payment(v_rid, 40000, '1110', 'p2', 'op-pay-2');
  v_tx3 := fx_record_remittance_customer_payment(v_rid, 32000, '1110', 'p3', 'op-pay-3');
  -- duplicate idempotent
  v_tx_dup := fx_record_remittance_customer_payment(v_rid, 32000, '1110', 'p3', 'op-pay-3');
  IF v_tx_dup IS DISTINCT FROM v_tx3 THEN RAISE EXCEPTION 'FAIL idempotency'; END IF;

  SELECT * INTO v_r FROM fx_remittances WHERE id = v_rid;
  IF v_r.paid_amount <> 102000 THEN RAISE EXCEPTION 'FAIL paid=%', v_r.paid_amount; END IF;
  IF v_r.commission_recognized_pkr <> 2000 THEN
    RAISE EXCEPTION 'FAIL commission_recognized want 2000 got %', v_r.commission_recognized_pkr;
  END IF;
  IF v_r.status <> 'customer_paid' THEN RAISE EXCEPTION 'FAIL status %', v_r.status; END IF;

  SELECT COALESCE(SUM(jl.credit_pkr),0) INTO v_comm_lines
  FROM fx_journal_lines jl
  JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
  JOIN fx_transactions t ON t.id = je.transaction_id
  JOIN fx_accounts a ON a.id = jl.account_id
  WHERE t.remittance_id = v_rid AND a.code = '4310';

  IF v_comm_lines <> 2000 THEN
    RAISE EXCEPTION 'FAIL commission journal credits want 2000 got %', v_comm_lines;
  END IF;

  RAISE NOTICE 'PASS scenario_02_partial_commission';
END $$;
