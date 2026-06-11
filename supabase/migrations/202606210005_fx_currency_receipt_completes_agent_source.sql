-- Currency receipt leg completes pending agent_source; demo seed + backfill for DEMO-DIN-USD-001

CREATE OR REPLACE FUNCTION fx_add_deal_leg_v2(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_leg_no INT;
  v_leg_id UUID;
  v_deal_id UUID := (p_payload->>'deal_id')::UUID;
  v_leg_type fx_deal_leg_type := (p_payload->>'leg_type')::fx_deal_leg_type;
  v_receive_currency TEXT := NULLIF(p_payload->>'receive_currency', '');
  v_receive_amount NUMERIC := COALESCE((p_payload->>'receive_amount')::NUMERIC, 0);
  v_pay_currency TEXT := NULLIF(p_payload->>'pay_currency', '');
  v_pay_amount NUMERIC := COALESCE((p_payload->>'pay_amount')::NUMERIC, 0);
  v_rate_used NUMERIC := NULLIF(p_payload->>'rate_used', '')::NUMERIC;
  v_delivery_target fx_delivery_target := NULLIF(p_payload->>'delivery_target', '')::fx_delivery_target;
  v_parent_leg_id UUID := NULLIF(p_payload->>'parent_leg_id', '')::UUID;
  v_counterparty UUID := NULLIF(p_payload->>'counterparty_party_id', '')::UUID;
  v_notes TEXT := NULLIF(p_payload->>'notes', '');
  v_linked_tx UUID := NULLIF(p_payload->>'linked_transaction_id', '')::UUID;
  v_leg_status fx_deal_leg_status := CASE
    WHEN v_leg_type = 'currency_receipt' THEN 'completed'::fx_deal_leg_status
    ELSE 'pending'::fx_deal_leg_status
  END;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_deal FROM fx_deals WHERE id = v_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = v_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    paid_amount, remaining_amount, delivery_target, parent_leg_id, notes,
    linked_transaction_id, completed_at,
    reference_rate, reference_rate_pair, reference_rate_source, reference_rate_at,
    reference_rate_is_stale, deal_rate_spread, deal_rate_spread_percent,
    reference_rate_id, rate_locked_at, rate_locked_by
  ) VALUES (
    v_deal_id, v_leg_no, v_leg_type, v_leg_status, v_counterparty,
    CASE WHEN v_receive_currency IS NOT NULL THEN fx_normalize_currency_code(v_receive_currency) ELSE NULL END,
    v_receive_amount,
    CASE WHEN v_pay_currency IS NOT NULL THEN fx_normalize_currency_code(v_pay_currency) ELSE NULL END,
    v_pay_amount, v_rate_used,
    0, COALESCE(v_pay_amount, v_receive_amount, 0),
    v_delivery_target, v_parent_leg_id, v_notes,
    v_linked_tx,
    CASE WHEN v_leg_status = 'completed' THEN NOW() ELSE NULL END,
    NULLIF(p_payload->>'reference_rate', '')::NUMERIC,
    NULLIF(p_payload->>'reference_rate_pair', ''),
    NULLIF(p_payload->>'reference_rate_source', ''),
    NULLIF(p_payload->>'reference_rate_at', '')::TIMESTAMPTZ,
    (p_payload->>'reference_rate_is_stale')::BOOLEAN,
    NULLIF(p_payload->>'deal_rate_spread', '')::NUMERIC,
    NULLIF(p_payload->>'deal_rate_spread_percent', '')::NUMERIC,
    NULLIF(p_payload->>'reference_rate_id', '')::UUID,
    NULLIF(p_payload->>'rate_locked_at', '')::TIMESTAMPTZ,
    NULLIF(p_payload->>'rate_locked_by', '')::UUID
  ) RETURNING id INTO v_leg_id;

  IF v_leg_type = 'agent_source' THEN
    UPDATE fx_deals SET status = 'sourcing_in_progress'::fx_deal_status, updated_at = NOW() WHERE id = v_deal_id;
    INSERT INTO fx_currency_commitments (deal_id, leg_id, currency_code, commitment_type, committed_amount)
    VALUES (
      v_deal_id, v_leg_id,
      fx_normalize_currency_code(v_receive_currency),
      'on_order_inbound'::fx_commitment_type,
      v_receive_amount
    );
  ELSIF v_leg_type = 'currency_receipt' THEN
    UPDATE fx_deal_legs SET
      status = 'completed'::fx_deal_leg_status,
      completed_at = COALESCE(completed_at, NOW()),
      linked_transaction_id = COALESCE(linked_transaction_id, v_linked_tx)
    WHERE deal_id = v_deal_id
      AND leg_type = 'agent_source'::fx_deal_leg_type
      AND status = 'pending'::fx_deal_leg_status;

    IF v_deal.status NOT IN ('delivered', 'completed', 'cancelled', 'voided') THEN
      UPDATE fx_deals SET
        status = 'currency_received'::fx_deal_status,
        updated_at = NOW()
      WHERE id = v_deal_id;
    END IF;
  END IF;

  RETURN v_leg_id;
END;
$$;

-- Backfill existing DEMO-DIN-USD-001 where agent_source stayed pending after seed
DO $$
DECLARE
  v_deal UUID;
  v_agent_leg UUID;
  v_wali UUID;
  v_tx UUID;
  v_leg_no INT;
BEGIN
  SELECT d.id INTO v_deal
  FROM fx_deals d
  WHERE d.deal_no = 'DEMO-DIN-USD-001'
  LIMIT 1;

  IF v_deal IS NULL THEN
    RETURN;
  END IF;

  SELECT l.id, l.counterparty_party_id INTO v_agent_leg, v_wali
  FROM fx_deal_legs l
  WHERE l.deal_id = v_deal
    AND l.leg_type = 'agent_source'::fx_deal_leg_type
    AND l.status = 'pending'::fx_deal_leg_status
  ORDER BY l.leg_no
  LIMIT 1;

  IF v_agent_leg IS NULL THEN
    RETURN;
  END IF;

  SELECT t.id INTO v_tx
  FROM fx_transactions t
  WHERE t.deal_id = v_deal
    AND t.description LIKE '[DEMO] Receive USD from WALI%'
    AND t.status = 'posted'
  ORDER BY t.created_at
  LIMIT 1;

  IF v_tx IS NULL THEN
    SELECT t.id INTO v_tx
    FROM fx_transactions t
    JOIN fx_branches b ON b.id = t.branch_id
    JOIN fx_companies c ON c.id = b.company_id
    WHERE c.code = 'FXDEV'
      AND t.description LIKE '[DEMO] Receive USD from WALI%'
      AND t.status = 'posted'
    ORDER BY t.created_at
    LIMIT 1;
  END IF;

  UPDATE fx_deal_legs SET
    status = 'completed'::fx_deal_leg_status,
    completed_at = COALESCE(completed_at, NOW()),
    linked_transaction_id = COALESCE(linked_transaction_id, v_tx)
  WHERE id = v_agent_leg;

  IF NOT EXISTS (
    SELECT 1 FROM fx_deal_legs
    WHERE deal_id = v_deal AND leg_type = 'currency_receipt'::fx_deal_leg_type
  ) THEN
    SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = v_deal;

    INSERT INTO fx_deal_legs (
      deal_id, leg_no, leg_type, status, counterparty_party_id,
      receive_currency, receive_amount, linked_transaction_id, notes, completed_at
    ) VALUES (
      v_deal, v_leg_no, 'currency_receipt'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, v_wali,
      'USD', 3000, v_tx, '[DEMO] USD received from WALI (backfill)', NOW()
    );
  END IF;
END;
$$;

-- Update demo seed for fresh runs (skipped when [DEMO] txs already exist)
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
  v_kabul UUID;
  v_afn_acct TEXT;
  v_deal_id UUID;
  v_leg_id UUID;
  v_wali_usd_tx UUID;
  v_tx_count INT := 0;
  v_deal_count INT := 0;
  v_ob_status TEXT;
  v_cny_buy NUMERIC := 50000;
  v_cny_buy_pkr NUMERIC := 1950000;
  v_cny_sell NUMERIC := 8000;
  v_cny_sell_pkr NUMERIC := 332000;
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
  v_kabul := fx_demo_party_id(v_company, 'DEMO_KABUL_AFN');

  IF v_asad IS NULL OR v_din IS NULL OR v_wali IS NULL OR v_china IS NULL THEN
    RAISE EXCEPTION 'Run seed_realistic_fx_demo.sql first (DEMO parties missing)';
  END IF;

  v_admin := fx_demo_act_as_fxdev_admin();

  SELECT CASE WHEN EXISTS (
    SELECT 1 FROM fx_opening_balance_batches WHERE branch_id = v_branch AND status = 'posted'
  ) THEN 'already_posted' ELSE 'missing' END INTO v_ob_status;

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

  SELECT fx_book_customer_deal_v2(jsonb_build_object(
    'branch_id', v_branch,
    'customer_party_id', v_din,
    'sell_currency_code', 'USD',
    'sell_amount', 3000,
    'sale_rate_pkr', 282,
    'customer_paid_now_pkr', 500000,
    'delivery_method', 'tt',
    'allow_short_position', false,
    'notes', 'DEMO-DIN-USD-001 customer order',
    'auto_source', true
  )) INTO v_deal_id;

  UPDATE fx_deals SET
    deal_no = 'DEMO-DIN-USD-001',
    customer_receivable_pkr = GREATEST(0, 846000 - 500000)
  WHERE id = v_deal_id;
  v_deal_count := v_deal_count + 1;

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

  v_wali_usd_tx := fx_demo_post_tx(
    v_company, v_branch, 'currency_buy', CURRENT_DATE, v_wali,
    'USD', 3000, 278, 834000,
    '[DEMO] Receive USD from WALI (agent credit)',
    jsonb_build_array(
      jsonb_build_object('account_code','1120','currency_code','USD','foreign_amount',3000,'rate_used',278,'base_amount_pkr',834000,'debit_pkr',834000,'credit_pkr',0),
      jsonb_build_object('account_code','2100','currency_code','PKR','foreign_amount',834000,'rate_used',1,'base_amount_pkr',834000,'debit_pkr',0,'credit_pkr',834000)
    )
  );
  v_tx_count := v_tx_count + 1;

  UPDATE fx_transactions SET deal_id = v_deal_id WHERE id = v_wali_usd_tx;

  PERFORM fx_add_deal_leg_v2(jsonb_build_object(
    'deal_id', v_deal_id,
    'leg_type', 'currency_receipt',
    'counterparty_party_id', v_wali,
    'receive_currency', 'USD',
    'receive_amount', 3000,
    'linked_transaction_id', v_wali_usd_tx::TEXT,
    'notes', '[DEMO] USD received from WALI'
  ));

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

  PERFORM fx_confirm_deal_delivery(
    v_deal_id, 3000, 'direct_to_customer'::fx_delivery_target,
    834000, 'DEMO-TT-001', '[DEMO] USD TT delivered to DIN'
  );
  v_tx_count := v_tx_count + 1;

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

  RETURN jsonb_build_object(
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
END;
$$;

NOTIFY pgrst, 'reload schema';
