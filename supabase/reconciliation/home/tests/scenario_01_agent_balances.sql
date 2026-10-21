-- Scenario 01: owned custody vs payable; reserve/release/consume
SET statement_timeout = '30s';
SELECT set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', false);

DO $$
DECLARE
  v_co UUID := '11111111-1111-4111-8111-111111111111';
  v_br UUID := '22222222-2222-4222-8222-222222222222';
  v_ag UUID := 'b1111111-b111-4111-8111-b11111111111';
  v_avail NUMERIC;
  v_row fx_agent_currency_balances;
BEGIN
  v_avail := fx_agent_balance_available(v_co, v_br, v_ag, 'USD');
  IF v_avail <> 10000 THEN RAISE EXCEPTION 'FAIL avail want 10000 got %', v_avail; END IF;

  -- Payable credit is independent of owned currency
  UPDATE fx_agent_currency_balances
  SET payable_pkr = 250000
  WHERE agent_party_id = v_ag AND currency_code = 'USD';

  PERFORM fx_agent_balance_reserve(v_co, v_br, v_ag, 'USD', 3000);
  v_avail := fx_agent_balance_available(v_co, v_br, v_ag, 'USD');
  IF v_avail <> 7000 THEN RAISE EXCEPTION 'FAIL after reserve avail=%', v_avail; END IF;

  BEGIN
    PERFORM fx_agent_balance_reserve(v_co, v_br, v_ag, 'USD', 8000);
    RAISE EXCEPTION 'FAIL expected insufficient reserve error';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Insufficient available%' THEN RAISE; END IF;
  END;

  PERFORM fx_agent_balance_release_reserve(v_co, v_br, v_ag, 'USD', 1000);
  PERFORM fx_agent_balance_consume_reserve(v_co, v_br, v_ag, 'USD', 2000);

  SELECT * INTO v_row FROM fx_agent_currency_balances
  WHERE agent_party_id = v_ag AND currency_code = 'USD';
  IF v_row.owned_amount <> 8000 OR v_row.reserved_amount <> 0 THEN
    RAISE EXCEPTION 'FAIL owned/reserved after consume owned=% reserved=%', v_row.owned_amount, v_row.reserved_amount;
  END IF;
  IF v_row.payable_pkr <> 250000 THEN
    RAISE EXCEPTION 'FAIL payable must remain separate got %', v_row.payable_pkr;
  END IF;

  RAISE NOTICE 'PASS scenario_01_agent_balances';
END $$;
