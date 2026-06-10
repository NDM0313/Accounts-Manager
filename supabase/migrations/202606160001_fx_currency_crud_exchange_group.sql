-- Currency CRUD RPC + exchange_group_id for chained exchange wizard

ALTER TABLE fx_transactions
  ADD COLUMN IF NOT EXISTS exchange_group_id UUID;

CREATE INDEX IF NOT EXISTS idx_fx_transactions_exchange_group
  ON fx_transactions (exchange_group_id)
  WHERE exchange_group_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- fx_create_currency — insert currency + cash COA account for caller's company
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_create_currency(
  p_code TEXT,
  p_name TEXT,
  p_symbol TEXT DEFAULT '',
  p_decimal_places INT DEFAULT 2
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_company UUID;
  v_assets UUID;
  v_currency_id UUID;
  v_account_code TEXT;
  v_candidate INT;
  v_code_upper TEXT := UPPER(TRIM(p_code));
BEGIN
  IF NOT fx_has_permission('can_manage_chart_of_accounts') THEN
    RAISE EXCEPTION 'Permission denied: can_manage_chart_of_accounts required';
  END IF;

  IF v_code_upper = 'PKR' THEN
    RAISE EXCEPTION 'PKR is the base currency and cannot be added again';
  END IF;

  IF LENGTH(v_code_upper) < 2 OR LENGTH(v_code_upper) > 5 THEN
    RAISE EXCEPTION 'Currency code must be 2–5 characters';
  END IF;

  SELECT company_id INTO v_company
  FROM fx_users_profiles
  WHERE id = auth.uid() AND is_active = TRUE;

  IF v_company IS NULL THEN
    RAISE EXCEPTION 'User profile not configured';
  END IF;

  IF EXISTS (SELECT 1 FROM fx_currencies WHERE code = v_code_upper) THEN
    RAISE EXCEPTION 'Currency % already exists', v_code_upper;
  END IF;

  INSERT INTO fx_currencies (code, name, symbol, decimal_places, is_base, is_active)
  VALUES (v_code_upper, TRIM(p_name), COALESCE(NULLIF(TRIM(p_symbol), ''), v_code_upper), p_decimal_places, FALSE, TRUE)
  RETURNING id INTO v_currency_id;

  SELECT id INTO v_assets FROM fx_accounts WHERE company_id = v_company AND code = '1000';
  IF v_assets IS NULL THEN
    RAISE EXCEPTION 'Assets parent account (1000) not found for company';
  END IF;

  -- Next cash account code: prefer 1151–1159, then 1181–1189
  v_account_code := NULL;
  FOR v_candidate IN 1151..1159 LOOP
    IF NOT EXISTS (
      SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = v_candidate::TEXT
    ) THEN
      v_account_code := v_candidate::TEXT;
      EXIT;
    END IF;
  END LOOP;

  IF v_account_code IS NULL THEN
    FOR v_candidate IN 1181..1189 LOOP
      IF NOT EXISTS (
        SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = v_candidate::TEXT
      ) THEN
        v_account_code := v_candidate::TEXT;
        EXIT;
      END IF;
    END LOOP;
  END IF;

  IF v_account_code IS NULL THEN
    RAISE EXCEPTION 'No available cash account code slot for new currency';
  END IF;

  INSERT INTO fx_accounts (company_id, code, name, account_type, currency_id, parent_id)
  VALUES (
    v_company,
    v_account_code,
    'Cash ' || v_code_upper,
    'asset',
    v_currency_id,
    v_assets
  );

  RETURN jsonb_build_object(
    'currency_id', v_currency_id,
    'code', v_code_upper,
    'account_code', v_account_code
  );
END;
$$;

GRANT EXECUTE ON FUNCTION fx_create_currency(TEXT, TEXT, TEXT, INT) TO authenticated;

-- ---------------------------------------------------------------------------
-- fx_deactivate_currency — soft-disable (no delete if used)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_deactivate_currency(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code_upper TEXT := UPPER(TRIM(p_code));
BEGIN
  IF NOT fx_has_permission('can_manage_chart_of_accounts') THEN
    RAISE EXCEPTION 'Permission denied: can_manage_chart_of_accounts required';
  END IF;

  IF v_code_upper = 'PKR' THEN
    RAISE EXCEPTION 'Cannot deactivate base currency PKR';
  END IF;

  UPDATE fx_currencies SET is_active = FALSE, updated_at = NOW()
  WHERE code = v_code_upper AND is_base = FALSE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Currency % not found or is base currency', v_code_upper;
  END IF;

  RETURN jsonb_build_object('code', v_code_upper, 'is_active', FALSE);
END;
$$;

GRANT EXECUTE ON FUNCTION fx_deactivate_currency(TEXT) TO authenticated;
