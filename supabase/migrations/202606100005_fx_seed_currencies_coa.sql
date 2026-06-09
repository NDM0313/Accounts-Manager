-- FX Cash Ledger — seed currencies and Chart of Accounts (PKR base)

-- ---------------------------------------------------------------------------
-- Currencies
-- ---------------------------------------------------------------------------

INSERT INTO fx_currencies (code, name, symbol, decimal_places, is_base, is_active)
VALUES
  ('PKR', 'Pakistani Rupee', 'Rs', 2, TRUE,  TRUE),
  ('USD', 'US Dollar', '$', 2, FALSE, TRUE),
  ('AED', 'UAE Dirham', 'د.إ', 2, FALSE, TRUE),
  ('CNY', 'Chinese Yuan (RMB)', '¥', 2, FALSE, TRUE),
  ('SAR', 'Saudi Riyal', '﷼', 2, FALSE, TRUE)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Default dev company + branch
-- ---------------------------------------------------------------------------

INSERT INTO fx_companies (id, name, code, base_currency_code)
VALUES ('00000000-0000-4000-8000-000000000001', 'FX Cash Ledger Dev', 'FXDEV', 'PKR')
ON CONFLICT (code) DO NOTHING;

INSERT INTO fx_branches (id, company_id, name, code)
VALUES (
  '00000000-0000-4000-8000-000000000002',
  '00000000-0000-4000-8000-000000000001',
  'Main Branch',
  'MAIN'
)
ON CONFLICT (company_id, code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Default roles
-- ---------------------------------------------------------------------------

INSERT INTO fx_roles (id, company_id, name, permissions)
VALUES
  (
    '00000000-0000-4000-8000-000000000010',
    '00000000-0000-4000-8000-000000000001',
    'admin',
    ARRAY[
      'can_access_fx_ledger', 'can_manage_fx_rates', 'can_post_fx_transaction',
      'can_edit_fx_transaction', 'can_delete_fx_transaction', 'can_view_fx_reports',
      'can_view_fx_audit', 'can_manage_chart_of_accounts', 'can_close_day'
    ]
  ),
  (
    '00000000-0000-4000-8000-000000000011',
    '00000000-0000-4000-8000-000000000001',
    'manager',
    ARRAY[
      'can_access_fx_ledger', 'can_manage_fx_rates', 'can_post_fx_transaction',
      'can_edit_fx_transaction', 'can_delete_fx_transaction', 'can_view_fx_reports',
      'can_view_fx_audit', 'can_close_day'
    ]
  ),
  (
    '00000000-0000-4000-8000-000000000012',
    '00000000-0000-4000-8000-000000000001',
    'cashier',
    ARRAY['can_access_fx_ledger']
  ),
  (
    '00000000-0000-4000-8000-000000000013',
    '00000000-0000-4000-8000-000000000001',
    'auditor',
    ARRAY['can_view_fx_reports', 'can_view_fx_audit']
  )
ON CONFLICT (company_id, name) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Chart of Accounts (handoff §10) — parents first, then children
-- ---------------------------------------------------------------------------

DO $$
DECLARE
  v_company UUID := '00000000-0000-4000-8000-000000000001';
  v_pkr UUID; v_usd UUID; v_aed UUID; v_cny UUID; v_sar UUID;
  v_assets UUID; v_liabilities UUID; v_equity UUID;
  v_income UUID; v_expenses UUID; v_adjustment UUID;
BEGIN
  SELECT id INTO v_pkr FROM fx_currencies WHERE code = 'PKR';
  SELECT id INTO v_usd FROM fx_currencies WHERE code = 'USD';
  SELECT id INTO v_aed FROM fx_currencies WHERE code = 'AED';
  SELECT id INTO v_cny FROM fx_currencies WHERE code = 'CNY';
  SELECT id INTO v_sar FROM fx_currencies WHERE code = 'SAR';

  INSERT INTO fx_accounts (company_id, code, name, account_type)
  VALUES
    (v_company, '1000', 'Assets', 'asset'),
    (v_company, '2000', 'Liabilities', 'liability'),
    (v_company, '3000', 'Equity', 'equity'),
    (v_company, '4000', 'Income', 'income'),
    (v_company, '5000', 'Expenses', 'expense'),
    (v_company, '6000', 'Adjustment', 'adjustment')
  ON CONFLICT (company_id, code) DO NOTHING;

  SELECT id INTO v_assets FROM fx_accounts WHERE company_id = v_company AND code = '1000';
  SELECT id INTO v_liabilities FROM fx_accounts WHERE company_id = v_company AND code = '2000';
  SELECT id INTO v_equity FROM fx_accounts WHERE company_id = v_company AND code = '3000';
  SELECT id INTO v_income FROM fx_accounts WHERE company_id = v_company AND code = '4000';
  SELECT id INTO v_expenses FROM fx_accounts WHERE company_id = v_company AND code = '5000';
  SELECT id INTO v_adjustment FROM fx_accounts WHERE company_id = v_company AND code = '6000';

  INSERT INTO fx_accounts (company_id, code, name, account_type, currency_id, parent_id) VALUES
    (v_company, '1110', 'Cash PKR', 'asset', v_pkr, v_assets),
    (v_company, '1120', 'Cash USD', 'asset', v_usd, v_assets),
    (v_company, '1130', 'Cash AED', 'asset', v_aed, v_assets),
    (v_company, '1140', 'Cash RMB/CNY', 'asset', v_cny, v_assets),
    (v_company, '1150', 'Cash SAR', 'asset', v_sar, v_assets),
    (v_company, '1160', 'Bank PKR', 'asset', v_pkr, v_assets),
    (v_company, '1170', 'Bank Foreign Currency', 'asset', NULL, v_assets),
    (v_company, '1180', 'Agent Receivables', 'asset', NULL, v_assets),
    (v_company, '1190', 'Customer Receivables', 'asset', NULL, v_assets),
    (v_company, '2100', 'Agent Payables', 'liability', NULL, v_liabilities),
    (v_company, '2200', 'Customer Payables', 'liability', NULL, v_liabilities),
    (v_company, '2300', 'Settlement Payables', 'liability', NULL, v_liabilities),
    (v_company, '2400', 'Other Payables', 'liability', NULL, v_liabilities),
    (v_company, '3100', 'Owner Capital', 'equity', NULL, v_equity),
    (v_company, '3200', 'Owner Drawings', 'equity', NULL, v_equity),
    (v_company, '3300', 'Retained Earnings', 'equity', NULL, v_equity),
    (v_company, '4100', 'Exchange Spread Income', 'income', NULL, v_income),
    (v_company, '4200', 'Service Charges Income', 'income', NULL, v_income),
    (v_company, '4300', 'Settlement Charges Income', 'income', NULL, v_income),
    (v_company, '4400', 'Revaluation Gain', 'income', NULL, v_income),
    (v_company, '5100', 'Salary Expense', 'expense', NULL, v_expenses),
    (v_company, '5200', 'Rent Expense', 'expense', NULL, v_expenses),
    (v_company, '5300', 'Courier/Delivery Expense', 'expense', NULL, v_expenses),
    (v_company, '5400', 'Bank Charges', 'expense', NULL, v_expenses),
    (v_company, '5500', 'Agent Charges', 'expense', NULL, v_expenses),
    (v_company, '5600', 'Currency Shortage/Loss', 'expense', NULL, v_expenses),
    (v_company, '5700', 'Revaluation Loss', 'expense', NULL, v_expenses),
    (v_company, '5800', 'Other Expenses', 'expense', NULL, v_expenses),
    (v_company, '6100', 'FX Gain/Loss Clearing', 'adjustment', NULL, v_adjustment),
    (v_company, '6200', 'Rounding Difference', 'adjustment', NULL, v_adjustment),
    (v_company, '6300', 'Cash Over/Short', 'adjustment', NULL, v_adjustment)
  ON CONFLICT (company_id, code) DO NOTHING;
END $$;
