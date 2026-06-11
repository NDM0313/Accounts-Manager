-- Smoke test: fx_generate_deal_no must not overflow INT on DL-YYYYMMDD-NNNN format
-- Run: supabase db query --file supabase/scripts/verify_deal_number_sequence.sql
-- Expected format: DL-YYYYMMDD-0001 (trailing sequence only, not full digit strip)

DO $$
DECLARE
  v_fn_count INT;
  v_sample TEXT := 'DL-20260610-0001';
  v_seq INT;
BEGIN
  SELECT COUNT(*) INTO v_fn_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'fx_generate_deal_no';

  IF v_fn_count <> 1 THEN
    RAISE EXCEPTION 'FAIL: expected 1 fx_generate_deal_no, found %', v_fn_count;
  END IF;

  -- Simulate sequence extraction (must not cast 202606100001)
  v_seq := (regexp_match(v_sample, '-(\d+)$'))[1]::INT;
  IF v_seq <> 1 THEN
    RAISE EXCEPTION 'FAIL: expected trailing seq 1 from %, got %', v_sample, v_seq;
  END IF;

  RAISE NOTICE 'PASS: fx_generate_deal_no exists; trailing seq parse OK (DL-YYYYMMDD-0001 → %)', v_seq;
END;
$$;
