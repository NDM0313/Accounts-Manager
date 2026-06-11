-- Smoke test: opening balance batch RPCs exist and balance helpers work
-- Run after migration apply: supabase db query --file supabase/scripts/verify_opening_balance_batch.sql

DO $$
DECLARE
  v_fn_count INT;
  v_debit NUMERIC;
  v_credit NUMERIC;
BEGIN
  SELECT COUNT(*) INTO v_fn_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'fx_get_opening_balance_status',
      'fx_save_opening_balance_batch',
      'fx_post_opening_balance_batch',
      'fx_void_opening_balance_batch'
    );

  IF v_fn_count <> 4 THEN
    RAISE EXCEPTION 'FAIL: expected 4 opening balance RPCs, found %', v_fn_count;
  END IF;

  v_debit := fx_ob_line_debit_pkr('cash_bank'::fx_opening_balance_line_kind, 1000000);
  v_credit := fx_ob_line_credit_pkr('cash_bank'::fx_opening_balance_line_kind, 1000000);

  IF v_debit <> 1000000 OR v_credit <> 1000000 THEN
    RAISE EXCEPTION 'FAIL: cash_bank balance helper expected 1000000/1000000, got %/%', v_debit, v_credit;
  END IF;

  v_debit := fx_ob_line_debit_pkr('party_payable'::fx_opening_balance_line_kind, 300000);
  v_credit := fx_ob_line_credit_pkr('party_payable'::fx_opening_balance_line_kind, 300000);

  IF v_debit <> 300000 OR v_credit <> 300000 THEN
    RAISE EXCEPTION 'FAIL: party_payable balance helper expected 300000/300000, got %/%', v_debit, v_credit;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'fx_opening_balance_batches'
  ) THEN
    RAISE EXCEPTION 'FAIL: fx_opening_balance_batches table missing';
  END IF;

  RAISE NOTICE 'PASS: opening balance batch RPCs and helpers present';
END;
$$;
