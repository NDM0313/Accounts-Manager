-- Production bootstrap: create operating company + COA when none exists.
-- Activation: fx_reconciliation.confirm = APPLY_PROD_COMPANY_BOOTSTRAP
-- Does NOT grant FX roles to users (see separate membership bootstrap).

DO $guard$
BEGIN
  IF current_setting('fx_reconciliation.confirm', true) IS DISTINCT FROM 'APPLY_PROD_COMPANY_BOOTSTRAP' THEN
    RAISE EXCEPTION 'BLOCKED: set fx_reconciliation.confirm=APPLY_PROD_COMPANY_BOOTSTRAP';
  END IF;
END
$guard$;

DO $$
DECLARE
  v_company UUID;
  v_branch UUID;
BEGIN
  SELECT id INTO v_company FROM fx_companies ORDER BY created_at LIMIT 1;
  IF v_company IS NOT NULL THEN
    RAISE NOTICE 'Company already exists: % — skipping create', v_company;
  ELSE
    INSERT INTO fx_companies (id, name, code, base_currency_code)
    VALUES ('00000000-0000-4000-8000-000000000001', 'NDM FX', 'NDMFX', 'PKR')
    RETURNING id INTO v_company;
    INSERT INTO fx_branches (id, company_id, name, code)
    VALUES ('00000000-0000-4000-8000-000000000002', v_company, 'Main', 'MAIN')
    ON CONFLICT DO NOTHING;
    -- Reuse disposable COA seeder against this company id by temporarily enabling seed path:
    -- Core COA accounts expected by RPCs
    INSERT INTO fx_accounts (company_id, code, name, account_type)
    SELECT v_company, x.code, x.name, x.atype::fx_account_type
    FROM (VALUES
      ('1000','Assets','asset'),
      ('1100','Cash & Banks','asset'),
      ('1110','Cash PKR','asset'),
      ('1120','Cash USD','asset'),
      ('1130','Cash AED','asset'),
      ('1140','Cash CNY','asset'),
      ('1150','Cash SAR','asset'),
      ('1160','Customer Advances','liability'),
      ('1170','Delivery Clearing','asset'),
      ('1190','Customer Receivable','asset'),
      ('2000','Liabilities','liability'),
      ('2100','Agent Payable','liability'),
      ('2310','Agent Settlement','liability'),
      ('2350','Remittance Liability','liability'),
      ('3000','Equity','equity'),
      ('4000','Income','income'),
      ('4100','FX Spread Income','income'),
      ('4310','Remittance Commission Income','income'),
      ('5000','Expenses','expense')
    ) AS x(code,name,atype)
    ON CONFLICT DO NOTHING;
    PERFORM fx_seed_remittance_coa(v_company);
    RAISE NOTICE 'Created NDMFX company % with baseline COA', v_company;
  END IF;

  SELECT id INTO v_branch FROM fx_branches WHERE company_id = v_company ORDER BY created_at LIMIT 1;
  RAISE NOTICE 'Bootstrap company=% branch=%', v_company, v_branch;
END $$;
