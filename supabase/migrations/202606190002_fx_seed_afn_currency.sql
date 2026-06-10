-- Seed AFN (Afghan Afghani) default currency + cash COA account
-- PKR remains base. SAR retained.

INSERT INTO fx_currencies (code, name, symbol, decimal_places, is_base, is_active)
VALUES ('AFN', 'Afghan Afghani', '؋', 2, FALSE, TRUE)
ON CONFLICT (code) DO NOTHING;

DO $$
DECLARE
  v_company UUID := '00000000-0000-4000-8000-000000000001';
  v_afn UUID;
  v_assets UUID;
  v_acct_code TEXT;
  v_slot INT;
BEGIN
  SELECT id INTO v_company FROM fx_companies WHERE code = 'FXDEV';
  IF v_company IS NULL THEN
    SELECT id INTO v_company FROM fx_companies LIMIT 1;
  END IF;
  IF v_company IS NULL THEN RETURN; END IF;

  SELECT id INTO v_afn FROM fx_currencies WHERE code = 'AFN';
  IF v_afn IS NULL THEN RETURN; END IF;

  SELECT id INTO v_assets FROM fx_accounts WHERE company_id = v_company AND code = '1000';
  IF v_assets IS NULL THEN RETURN; END IF;

  IF EXISTS (SELECT 1 FROM fx_accounts WHERE company_id = v_company AND currency_id = v_afn) THEN
    RETURN;
  END IF;

  v_acct_code := NULL;
  FOR v_slot IN 1151..1159 LOOP
    IF NOT EXISTS (SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = v_slot::TEXT) THEN
      v_acct_code := v_slot::TEXT;
      EXIT;
    END IF;
  END LOOP;

  IF v_acct_code IS NULL THEN
    FOR v_slot IN 1181..1189 LOOP
      IF NOT EXISTS (SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = v_slot::TEXT) THEN
        v_acct_code := v_slot::TEXT;
        EXIT;
      END IF;
    END LOOP;
  END IF;

  IF v_acct_code IS NOT NULL THEN
    INSERT INTO fx_accounts (company_id, parent_id, code, name, account_type, currency_id)
    VALUES (v_company, v_assets, v_acct_code, 'Cash AFN', 'asset', v_afn)
    ON CONFLICT (company_id, code) DO NOTHING;
  END IF;
END $$;
