-- Full FXDEV demo workflow seed (balanced postings via existing RPCs)
-- Project: ygidlcqhupmxvsdjmvnf only. Replaces placeholder fx_seed_fxdev_demo.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_demo_party_id(p_company UUID, p_code TEXT)
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
  SELECT id FROM fx_parties WHERE company_id = p_company AND code = p_code LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fx_demo_act_as_fxdev_admin()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin UUID;
BEGIN
  SELECT p.id INTO v_admin
  FROM fx_users_profiles p
  JOIN fx_companies c ON c.id = p.company_id
  WHERE c.code = 'FXDEV' AND p.is_active = TRUE
  ORDER BY p.created_at
  LIMIT 1;

  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'FXDEV admin profile not found';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_admin::TEXT, TRUE);
  RETURN v_admin;
END;
$$;

CREATE OR REPLACE FUNCTION fx_demo_post_tx(
  p_company UUID,
  p_branch UUID,
  p_type fx_transaction_type,
  p_date DATE,
  p_party UUID,
  p_currency TEXT,
  p_foreign NUMERIC,
  p_rate NUMERIC,
  p_pkr NUMERIC,
  p_description TEXT,
  p_lines JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx UUID;
  v_line JSONB;
  v_no INT := 0;
  v_acct UUID;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Demo seed: missing can_post_fx_transaction';
  END IF;
  IF NOT fx_same_branch(p_branch) THEN
    RAISE EXCEPTION 'Demo seed: branch access denied';
  END IF;

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used,
    total_base_amount_pkr, description, created_by
  ) VALUES (
    p_company, p_branch, p_type, 'draft', p_date,
    p_party, p_currency, p_foreign, p_rate,
    p_pkr, p_description, auth.uid()
  ) RETURNING id INTO v_tx;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines)
  LOOP
    v_no := v_no + 1;
    v_acct := fx_account_id_by_code(p_company, v_line->>'account_code');
    IF v_acct IS NULL THEN
      RAISE EXCEPTION 'Demo seed: account % not found', v_line->>'account_code';
    END IF;
    INSERT INTO fx_transaction_lines (
      transaction_id, line_no, account_id, currency_code,
      foreign_amount, rate_used, base_amount_pkr, debit_pkr, credit_pkr, memo
    ) VALUES (
      v_tx, v_no, v_acct, COALESCE(v_line->>'currency_code', 'PKR'),
      COALESCE((v_line->>'foreign_amount')::NUMERIC, 0),
      COALESCE((v_line->>'rate_used')::NUMERIC, 1),
      COALESCE((v_line->>'base_amount_pkr')::NUMERIC, 0),
      COALESCE((v_line->>'debit_pkr')::NUMERIC, 0),
      COALESCE((v_line->>'credit_pkr')::NUMERIC, 0),
      COALESCE(v_line->>'memo', p_description)
    );
  END LOOP;

  PERFORM fx_post_transaction(v_tx);
  RETURN v_tx;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_seed_fxdev_demo — full workflow (idempotent on [DEMO] markers)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_seed_fxdev_demo(p_confirm TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_company UUID;
  v_branch UUID;
  v_admin UUID;
  v_asad UUID;
  v_din UUID;
  v_khan UUID;
  v_wali UUID;
  v_china UUID;
  v_dubai UUID;
  v_kabul UUID;
  v_afn_acct TEXT;
  v_deal_id UUID;
  v_leg_id UUID;
  v_tx_count INT := 0;
  v_deal_count INT := 0;
  v_ob_status TEXT;
  v_cny_buy NUMERIC := 50000;
  v_cny_buy_pkr NUMERIC := 1950000; -- @ 39
  v_cny_sell NUMERIC := 8000;
  v_cny_sell_pkr NUMERIC := 332000; -- @ 41.5
  v_result JSONB := '{}'::JSONB;
BEGIN
  IF p_confirm IS DISTINCT FROM 'FXDEV_DEMO_SEED' THEN
    RAISE EXCEPTION 'Invalid confirm token';
  END IF;

  SELECT id INTO v_company FROM fx_companies WHERE code = 'FXDEV';
  IF v_company IS NULL THEN RAISE EXCEPTION 'FXDEV not found'; END IF;
  SELECT id INTO v_branch FROM fx_branches WHERE company_id = v_company AND code = 'MAIN';
  IF v_branch IS NULL THEN RAISE EXCEPTION 'FXDEV MAIN branch not found'; END IF;

  IF EXISTS (
    SELECT 1 FROM fx_transactions t
    WHERE t.branch_id = v_branch AND t.description LIKE '[DEMO]%' AND t.status = 'posted'
  ) THEN
    RETURN jsonb_build_object(
      'status', 'skipped',
      'reason', 'Demo workflow already posted ([DEMO] transactions exist)',
      'demo_transactions', (
        SELECT COUNT(*) FROM fx_transactions
        WHERE branch_id = v_branch AND description LIKE '[DEMO]%' AND status = 'posted'
      ),
      'demo_deals', (
        SELECT COUNT(*) FROM fx_deals d
        WHERE d.branch_id = v_branch AND (d.deal_no LIKE 'DEMO-%' OR d.notes LIKE '%DEMO-DIN%')
      )
    );
  END IF;

  v_asad := fx_demo_party_id(v_company, 'DEMO_ASAD');
  v_din := fx_demo_party_id(v_company, 'DEMO_DIN');
  v_khan := fx_demo_party_id(v_company, 'DEMO_KHAN');
  v_wali := fx_demo_party_id(v_company, 'DEMO_WALI');
  v_china := fx_demo_party_id(v_company, 'DEMO_CHINA_RMB');
  v_dubai := fx_demo_party_id(v_company, 'DEMO_DUBAI_AED');
  v_kabul := fx_demo_party_id(v_company, 'DEMO_KABUL_AFN');

  IF v_asad IS NULL OR v_din IS NULL OR v_wali IS NULL OR v_china IS NULL THEN
    RAISE EXCEPTION 'Run seed_realistic_fx_demo.sql first (DEMO parties missing)';
  END IF;

  v_admin := fx_demo_act_as_fxdev_admin();

  SELECT CASE WHEN EXISTS (
    SELECT 1 FROM fx_opening_balance_batches WHERE branch_id = v_branch AND status = 'posted'
  ) THEN 'already_posted' ELSE 'missing' END INTO v_ob_status;

  -- Scenario 2: Buy CNY from China agent (on credit)
  PERFORM fx_demo_post_tx(
    v_company, v_branch, 'currency_buy', CURRENT_DATE, v_china,
    'CNY', v_cny_buy, 39, v_cny_buy_pkr,
    '[DEMO] Buy CNY from China agent',
    jsonb_build_array(
      jsonb_build_object('account_code','1140','currency_code','CNY','foreign_amount',v_cny_buy,'rate_used',39,'base_amount_pkr',v_cny_buy_pkr,'debit_pkr',v_cny_buy_pkr,'credit_pkr',0),
      jsonb_build_object('account_code','2100','currency_code','PKR','foreign_amount',v_cny_buy_pkr,'rate_used',1,'base_amount_pkr',v_cny_buy_pkr,'debit_pkr',0,'credit_pkr',v_cny_buy_pkr)
    )
  );
  v_tx_count := v_tx_count + 1;

  -- Scenario 3: Sell CNY to ASAD on credit (receivable)
  PERFORM fx_demo_post_tx(
    v_company, v_branch, 'currency_sell', CURRENT_DATE, v_asad,
    'CNY', v_cny_sell, 41.5, v_cny_sell_pkr,
    '[DEMO] Sell CNY to ASAD (on credit)',
    jsonb_build_array(
      jsonb_build_object('account_code','1190','currency_code','PKR','foreign_amount',v_cny_sell_pkr,'rate_used',1,'base_amount_pkr',v_cny_sell_pkr,'debit_pkr',v_cny_sell_pkr,'credit_pkr',0),
      jsonb_build_object('account_code','1140','currency_code','CNY','foreign_amount',v_cny_sell,'rate_used',41.5,'base_amount_pkr',v_cny_sell_pkr,'debit_pkr',0,'credit_pkr',v_cny_sell_pkr)
    )
  );
  v_tx_count := v_tx_count + 1;

  -- Partial PKR payment from ASAD
  PERFORM fx_demo_post_tx(
    v_company, v_branch, 'settlement_receive', CURRENT_DATE, v_asad,
    'PKR', 150000, 1, 150000,
    '[DEMO] ASAD partial PKR payment',
    jsonb_build_array(
      jsonb_build_object('account_code','1110','currency_code','PKR','foreign_amount',150000,'rate_used',1,'base_amount_pkr',150000,'debit_pkr',150000,'credit_pkr',0),
      jsonb_build_object('account_code','1190','currency_code','PKR','foreign_amount',150000,'rate_used',1,'base_amount_pkr',150000,'debit_pkr',0,'credit_pkr',150000)
    )
  );
  v_tx_count := v_tx_count + 1;

  -- Scenario 4: USD customer order (DIN) before stock available
  SELECT fx_book_customer_deal_v2(jsonb_build_object(
    'branch_id', v_branch,
    'customer_party_id', v_din,
    'sell_currency_code', 'USD',
    'sell_amount', 3000,
    'sale_rate_pkr', 282,
    'customer_paid_now_pkr', 300000,
    'delivery_method', 'tt',
    'allow_short_position', false,
    'notes', 'DEMO-DIN-USD-001 customer order',
    'auto_source', true
  )) INTO v_deal_id;

  UPDATE fx_deals SET deal_no = 'DEMO-DIN-USD-001' WHERE id = v_deal_id;
  v_deal_count := v_deal_count + 1;

  PERFORM fx_record_deal_customer_payment(v_deal_id, 200000, '[DEMO] DIN additional PKR advance');

  SELECT fx_add_deal_leg_v2(jsonb_build_object(
    'deal_id', v_deal_id,
    'leg_type', 'agent_source',
    'counterparty_party_id', v_wali,
    'receive_currency', 'USD',
    'receive_amount', 3000,
    'pay_currency', 'AED',
    'pay_amount', 8160,
    'rate_used', 0.272,
    'delivery_target', 'our_account',
    'notes', '[DEMO] WALI sources USD for AED'
  )) INTO v_leg_id;

  -- Receive USD from WALI (buy on credit)
  PERFORM fx_demo_post_tx(
    v_company, v_branch, 'currency_buy', CURRENT_DATE, v_wali,
    'USD', 3000, 278, 834000,
    '[DEMO] Receive USD from WALI (agent credit)',
    jsonb_build_array(
      jsonb_build_object('account_code','1120','currency_code','USD','foreign_amount',3000,'rate_used',278,'base_amount_pkr',834000,'debit_pkr',834000,'credit_pkr',0),
      jsonb_build_object('account_code','2100','currency_code','PKR','foreign_amount',834000,'rate_used',1,'base_amount_pkr',834000,'debit_pkr',0,'credit_pkr',834000)
    )
  );
  v_tx_count := v_tx_count + 1;

  -- Scenario 5: Partial agent payment to WALI
  PERFORM fx_demo_post_tx(
    v_company, v_branch, 'settlement_send', CURRENT_DATE, v_wali,
    'PKR', 250000, 1, 250000,
    '[DEMO] Partial payment to WALI',
    jsonb_build_array(
      jsonb_build_object('account_code','2100','currency_code','PKR','foreign_amount',250000,'rate_used',1,'base_amount_pkr',250000,'debit_pkr',250000,'credit_pkr',0),
      jsonb_build_object('account_code','1110','currency_code','PKR','foreign_amount',250000,'rate_used',1,'base_amount_pkr',250000,'debit_pkr',0,'credit_pkr',250000)
    )
  );
  v_tx_count := v_tx_count + 1;

  -- Complete DIN USD deal delivery
  PERFORM fx_confirm_deal_delivery(
    v_deal_id, 3000, 'direct_to_customer'::fx_delivery_target,
    834000, 'DEMO-TT-001', '[DEMO] USD TT delivered to DIN'
  );
  v_tx_count := v_tx_count + 1;

  -- Scenario 6: Expenses
  PERFORM fx_demo_post_tx(
    v_company, v_branch, 'expense', CURRENT_DATE, NULL,
    'PKR', 5000, 1, 5000,
    '[DEMO] Bank charges',
    jsonb_build_array(
      jsonb_build_object('account_code','5400','currency_code','PKR','foreign_amount',5000,'rate_used',1,'base_amount_pkr',5000,'debit_pkr',5000,'credit_pkr',0),
      jsonb_build_object('account_code','1110','currency_code','PKR','foreign_amount',5000,'rate_used',1,'base_amount_pkr',5000,'debit_pkr',0,'credit_pkr',5000)
    )
  );
  v_tx_count := v_tx_count + 1;

  PERFORM fx_demo_post_tx(
    v_company, v_branch, 'expense', CURRENT_DATE, NULL,
    'PKR', 3500, 1, 3500,
    '[DEMO] Courier expense',
    jsonb_build_array(
      jsonb_build_object('account_code','5300','currency_code','PKR','foreign_amount',3500,'rate_used',1,'base_amount_pkr',3500,'debit_pkr',3500,'credit_pkr',0),
      jsonb_build_object('account_code','1110','currency_code','PKR','foreign_amount',3500,'rate_used',1,'base_amount_pkr',3500,'debit_pkr',0,'credit_pkr',3500)
    )
  );
  v_tx_count := v_tx_count + 1;

  PERFORM fx_demo_post_tx(
    v_company, v_branch, 'expense', CURRENT_DATE, v_wali,
    'PKR', 8000, 1, 8000,
    '[DEMO] Agent commission',
    jsonb_build_array(
      jsonb_build_object('account_code','5500','currency_code','PKR','foreign_amount',8000,'rate_used',1,'base_amount_pkr',8000,'debit_pkr',8000,'credit_pkr',0),
      jsonb_build_object('account_code','1110','currency_code','PKR','foreign_amount',8000,'rate_used',1,'base_amount_pkr',8000,'debit_pkr',0,'credit_pkr',8000)
    )
  );
  v_tx_count := v_tx_count + 1;

  PERFORM fx_demo_post_tx(
    v_company, v_branch, 'expense', CURRENT_DATE, NULL,
    'PKR', 12000, 1, 12000,
    '[DEMO] Office expense',
    jsonb_build_array(
      jsonb_build_object('account_code','5200','currency_code','PKR','foreign_amount',12000,'rate_used',1,'base_amount_pkr',12000,'debit_pkr',12000,'credit_pkr',0),
      jsonb_build_object('account_code','1110','currency_code','PKR','foreign_amount',12000,'rate_used',1,'base_amount_pkr',12000,'debit_pkr',0,'credit_pkr',12000)
    )
  );
  v_tx_count := v_tx_count + 1;

  -- Scenario 7: AFN buy/sell if Cash AFN account exists
  SELECT a.code INTO v_afn_acct
  FROM fx_accounts a
  JOIN fx_currencies cur ON cur.id = a.currency_id
  WHERE a.company_id = v_company AND cur.code = 'AFN' AND a.account_type = 'asset'
  LIMIT 1;

  IF v_afn_acct IS NOT NULL AND v_kabul IS NOT NULL AND v_khan IS NOT NULL THEN
    PERFORM fx_demo_post_tx(
      v_company, v_branch, 'currency_buy', CURRENT_DATE, v_kabul,
      'AFN', 50000, 3.2, 160000,
      '[DEMO] Buy AFN from Kabul agent',
      jsonb_build_array(
        jsonb_build_object('account_code', v_afn_acct, 'currency_code','AFN','foreign_amount',50000,'rate_used',3.2,'base_amount_pkr',160000,'debit_pkr',160000,'credit_pkr',0),
        jsonb_build_object('account_code','1110','currency_code','PKR','foreign_amount',160000,'rate_used',1,'base_amount_pkr',160000,'debit_pkr',0,'credit_pkr',160000)
      )
    );
    v_tx_count := v_tx_count + 1;

    PERFORM fx_demo_post_tx(
      v_company, v_branch, 'currency_sell', CURRENT_DATE, v_khan,
      'AFN', 20000, 3.35, 67000,
      '[DEMO] Sell AFN to KHAN (cash)',
      jsonb_build_array(
        jsonb_build_object('account_code','1110','currency_code','PKR','foreign_amount',67000,'rate_used',1,'base_amount_pkr',67000,'debit_pkr',67000,'credit_pkr',0),
        jsonb_build_object('account_code', v_afn_acct, 'currency_code','AFN','foreign_amount',20000,'rate_used',3.35,'base_amount_pkr',67000,'debit_pkr',0,'credit_pkr',67000)
      )
    );
    v_tx_count := v_tx_count + 1;
  END IF;

  v_result := jsonb_build_object(
    'status', 'posted',
    'admin_user_id', v_admin,
    'opening_balance', v_ob_status,
    'transactions_posted', v_tx_count,
    'deals_created', v_deal_count,
    'deal_din_usd', v_deal_id,
    'afn_account', v_afn_acct,
    'trial_balance_balanced', (
      SELECT COALESCE(SUM(debit_pkr), 0) = COALESCE(SUM(credit_pkr), 0)
      FROM fx_journal_lines jl
      JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
      WHERE je.branch_id = v_branch
    )
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_demo_party_id(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_demo_act_as_fxdev_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION fx_demo_post_tx(UUID, UUID, fx_transaction_type, DATE, UUID, TEXT, NUMERIC, NUMERIC, NUMERIC, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_seed_fxdev_demo(TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
