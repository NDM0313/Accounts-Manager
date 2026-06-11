-- Display currency preference on user profile
-- Project: ygidlcqhupmxvsdjmvnf — applied 2026-06-10

ALTER TABLE fx_users_profiles
  ADD COLUMN IF NOT EXISTS display_currency_code TEXT NOT NULL DEFAULT 'PKR';

COMMENT ON COLUMN fx_users_profiles.display_currency_code IS
  'User preferred reporting/display currency; accounting remains in company base currency.';

CREATE OR REPLACE FUNCTION fx_update_display_currency(p_code TEXT)
RETURNS fx_users_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Missing permission';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM fx_currencies WHERE code = p_code AND is_active) THEN
    RAISE EXCEPTION 'Invalid or inactive currency: %', p_code;
  END IF;
  UPDATE fx_users_profiles
  SET display_currency_code = p_code, updated_at = NOW()
  WHERE id = auth.uid()
  RETURNING * INTO v_profile;
  RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_update_display_currency(TEXT) TO authenticated;
