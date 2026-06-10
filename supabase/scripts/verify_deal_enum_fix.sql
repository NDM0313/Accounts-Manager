-- Smoke test: fx_book_customer_deal enum casts (run via supabase db query)
DO $$
DECLARE
  v_deal_id UUID;
  v_customer UUID;
  v_status fx_deal_status;
  v_deal_no TEXT;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '4187ee4c-623c-42d1-89dd-63821e891533', true);

  SELECT id INTO v_customer
  FROM fx_parties
  WHERE party_type = 'customer' AND is_active
  LIMIT 1;

  IF v_customer IS NULL THEN
    RAISE EXCEPTION 'No active customer party found';
  END IF;

  SELECT fx_book_customer_deal(
    '00000000-0000-4000-8000-000000000002'::uuid,
    v_customer,
    'USD',
    50000,
    283.5,
    0,
    'tt'::fx_delivery_method,
    FALSE,
    'enum cast smoke test',
    TRUE
  ) INTO v_deal_id;

  SELECT status, deal_no INTO v_status, v_deal_no
  FROM fx_deals
  WHERE id = v_deal_id;

  IF v_status <> 'sourcing_required'::fx_deal_status THEN
    RAISE EXCEPTION 'Expected sourcing_required, got %', v_status;
  END IF;

  RAISE NOTICE 'OK deal=% status=% deal_no=%', v_deal_id, v_status, v_deal_no;
END $$;
