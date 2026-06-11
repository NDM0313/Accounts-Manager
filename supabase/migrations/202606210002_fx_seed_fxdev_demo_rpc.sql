-- FXDEV demo seed RPC — applied 2026-06-10 (placeholder; extend for full auto-posting)

CREATE OR REPLACE FUNCTION fx_seed_fxdev_demo(p_confirm TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_company UUID;
  v_branch UUID;
BEGIN
  IF p_confirm IS DISTINCT FROM 'FXDEV_DEMO_SEED' THEN
    RAISE EXCEPTION 'Invalid confirm token';
  END IF;
  SELECT id INTO v_company FROM fx_companies WHERE code = 'FXDEV';
  IF v_company IS NULL THEN RAISE EXCEPTION 'FXDEV not found'; END IF;
  SELECT id INTO v_branch FROM fx_branches WHERE company_id = v_company AND code = 'MAIN';

  IF EXISTS (SELECT 1 FROM fx_deals d WHERE d.branch_id = v_branch AND d.deal_no LIKE 'DEMO-%') THEN
    RETURN jsonb_build_object('status', 'skipped', 'reason', 'Demo deals already exist');
  END IF;

  -- Requires parties from seed_realistic_fx_demo.sql
  -- Full posting implementation: call fx_book_customer_deal_v2, opening balance batch, etc.
  -- Placeholder returns instruction until expanded in approved migration apply.

  RETURN jsonb_build_object(
    'status', 'pending',
    'message', 'Run seed_realistic_fx_demo.sql then complete scenarios via Flutter wizard or extend this RPC'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION fx_seed_fxdev_demo(TEXT) TO authenticated;
