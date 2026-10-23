-- =============================================================================
-- X) AM_TRAINING_20261023_V1 — synthetic training seed for AM_DEMO only
-- Activation (session):
--   SELECT set_config('fx_reconciliation.confirm', 'APPLY_AM_TRAINING_20261023_V1', true);
--   SELECT fx_seed_am_training_20261023_v1();
-- Does NOT delete/rewrite unrelated posted transactions.
-- Synthetic SAMPLE data only — not real bank details.
-- =============================================================================

CREATE TABLE IF NOT EXISTS fx_demo_seed_batches (
  seed_version   TEXT PRIMARY KEY,
  company_id     UUID NOT NULL REFERENCES fx_companies(id),
  actor_user_id  UUID,
  result_json    JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fx_training_manifest (
  seed_version TEXT PRIMARY KEY,
  payload      JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION fx_seed_am_training_20261023_v1()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seed TEXT := 'AM_TRAINING_20261023_V1';
  v_op_prefix TEXT := 'AM_TRAINING_20261023_V1';
  v_co UUID := 'a1111111-1111-4111-8111-111111111101';
  v_br UUID := 'a1111111-1111-4111-8111-111111111102';
  v_cli_a UUID := 'a1111111-1111-4111-8111-111111111401';
  v_cli_b UUID := 'a1111111-1111-4111-8111-111111111402';
  v_cli_c UUID := 'a1111111-1111-4111-8111-111111111403';
  v_cli_d UUID := 'a1111111-1111-4111-8111-111111111404';
  v_agt_a UUID := 'a1111111-1111-4111-8111-111111111411';
  v_agt_b UUID := 'a1111111-1111-4111-8111-111111111412';

  v_acc_cash UUID;
  v_acc_petty UUID;
  v_acc_meezan UUID;
  v_acc_alfalah UUID;
  v_acc_hbl UUID;
  v_acc_equity UUID;
  v_acc_expense UUID;
  v_acc_1180 UUID;
  v_parent_1000 UUID;
  v_pkr UUID;

  v_batch UUID;
  v_ob_done BOOLEAN := FALSE;
  v_need_ob BOOLEAN := FALSE;
  v_tx UUID;
  v_result JSONB;

  v_deal1 UUID; v_deal2 UUID; v_deal3 UUID; v_deal4 UUID;
  v_deal1_no TEXT; v_deal2_no TEXT; v_deal3_no TEXT; v_deal4_no TEXT;
  v_src1 UUID; v_src2 UUID; v_src3 UUID; v_src4 UUID;
  v_rcpt UUID;
  v_rem UUID;
  v_ops JSONB := '{}'::jsonb;

  v_meezan_bal NUMERIC;
  v_alfalah_bal NUMERIC;
  v_hbl_bal NUMERIC;
  v_cash_bal NUMERIC;
  v_petty_bal NUMERIC;

  -- labelled bank movement plan (PKR)
  c_d1_cust_meezan   CONSTANT NUMERIC := 400000;
  c_d1_cust_alfalah  CONSTANT NUMERIC := 287500;
  c_d1_tp_agent      CONSTANT NUMERIC := 350000;
  c_d1_pay_meezan    CONSTANT NUMERIC := 700000;
  c_d1_pay_alfalah   CONSTANT NUMERIC := 500000;
  c_d1_pay_hbl       CONSTANT NUMERIC := 500000;
  c_d2_cust_meezan   CONSTANT NUMERIC := 140000;
  c_d2_cust_alfalah  CONSTANT NUMERIC := 140000;
  c_d2_pay_hbl       CONSTANT NUMERIC := 278000;
  c_d3_cust_meezan   CONSTANT NUMERIC := 382500;
  c_d3_pay_alfalah   CONSTANT NUMERIC := 380000;
  c_d4_cust_hbl      CONSTANT NUMERIC := 100000;
  c_d4_pay_meezan    CONSTANT NUMERIC := 200000;
  c_s6_adv_meezan    CONSTANT NUMERIC := 5000000;
  c_s7_pay_alfalah   CONSTANT NUMERIC := 100000;
  c_s7_pay_hbl       CONSTANT NUMERIC := 100000;
  c_xfer             CONSTANT NUMERIC := 20000;
  c_exp              CONSTANT NUMERIC := 2000;
BEGIN
  IF current_setting('fx_reconciliation.confirm', true)
       IS DISTINCT FROM 'APPLY_AM_TRAINING_20261023_V1' THEN
    RAISE EXCEPTION
      'BLOCKED: set fx_reconciliation.confirm=APPLY_AM_TRAINING_20261023_V1';
  END IF;

  IF EXISTS (SELECT 1 FROM fx_demo_seed_batches WHERE seed_version = v_seed) THEN
    RETURN (
      SELECT result_json || jsonb_build_object('idempotent', true)
      FROM fx_demo_seed_batches
      WHERE seed_version = v_seed
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM fx_companies WHERE id = v_co AND code = 'AM_DEMO') THEN
    RAISE EXCEPTION 'AM_DEMO company % missing — run M_demo_seed first', v_co;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM fx_branches WHERE id = v_br AND company_id = v_co) THEN
    RAISE EXCEPTION 'AM_DEMO branch % missing', v_br;
  END IF;

  PERFORM set_config('fx_seed.active', '1', true);
  PERFORM set_config('fx_seed.company_id', v_co::text, true);
  PERFORM set_config('fx_seed.branch_id', v_br::text, true);

  -- -------------------------------------------------------------------------
  -- Ensure COA prerequisites (idempotent)
  -- -------------------------------------------------------------------------
  SELECT id INTO v_pkr FROM fx_currencies WHERE code = 'PKR' LIMIT 1;

  INSERT INTO fx_accounts (company_id, code, name, account_type)
  SELECT v_co, x.code, x.name, x.atype::fx_account_type
  FROM (VALUES
    ('1000', 'Cash & Bank Control', 'asset'),
    ('1120', 'Cash USD / agent inventory', 'asset'),
    ('1130', 'Cash AED / agent inventory', 'asset'),
    ('1140', 'Cash CNY / agent inventory', 'asset'),
    ('1160', 'Customer Advances', 'liability'),
    ('1170', 'Delivery Clearing', 'asset'),
    ('1180', 'Agent Receivables / Advances', 'asset'),
    ('1190', 'Customer Receivable', 'asset'),
    ('2100', 'Agent Payable', 'liability'),
    ('3100', 'Opening Equity', 'equity'),
    ('4100', 'FX Spread Income', 'income'),
    ('5000', 'Expenses', 'expense'),
    ('5800', 'Office Expenses', 'expense')
  ) AS x(code, name, atype)
  ON CONFLICT (company_id, code) DO NOTHING;

  v_parent_1000 := fx_account_id_by_code(v_co, '1000');
  v_acc_equity := fx_account_id_by_code(v_co, '3100');
  v_acc_1180 := fx_account_id_by_code(v_co, '1180');
  v_acc_expense := fx_account_id_by_code(v_co, '5800');
  IF v_parent_1000 IS NULL OR v_acc_equity IS NULL THEN
    RAISE EXCEPTION 'Required COA 1000/3100 missing on AM_DEMO';
  END IF;
  IF v_acc_expense IS NULL THEN
    INSERT INTO fx_accounts (company_id, code, name, account_type, parent_id)
    VALUES (v_co, '5800', 'Office Expenses', 'expense', fx_account_id_by_code(v_co, '5000'))
    RETURNING id INTO v_acc_expense;
  END IF;

  -- -------------------------------------------------------------------------
  -- Parties (stable UUIDs; unique on company_id+code)
  -- -------------------------------------------------------------------------
  INSERT INTO fx_parties (id, company_id, branch_id, party_type, code, name, notes) VALUES
    (v_cli_a, v_co, v_br, 'customer', 'TRAIN_CLI_A', 'TRAINING Client A',
     'AM_TRAINING_20261023_V1'),
    (v_cli_b, v_co, v_br, 'customer', 'TRAIN_CLI_B', 'TRAINING Client B',
     'AM_TRAINING_20261023_V1'),
    (v_cli_c, v_co, v_br, 'customer', 'TRAIN_CLI_C', 'TRAINING Client C',
     'AM_TRAINING_20261023_V1'),
    (v_cli_d, v_co, v_br, 'customer', 'TRAIN_CLI_D', 'TRAINING Client D',
     'AM_TRAINING_20261023_V1'),
    (v_agt_a, v_co, v_br, 'agent', 'TRAIN_AGT_A', 'TRAINING Agent A',
     'AM_TRAINING_20261023_V1'),
    (v_agt_b, v_co, v_br, 'agent', 'TRAIN_AGT_B', 'TRAINING Agent B',
     'AM_TRAINING_20261023_V1')
  ON CONFLICT (company_id, code) DO NOTHING;

  SELECT id INTO v_cli_a FROM fx_parties WHERE company_id = v_co AND code = 'TRAIN_CLI_A';
  SELECT id INTO v_cli_b FROM fx_parties WHERE company_id = v_co AND code = 'TRAIN_CLI_B';
  SELECT id INTO v_cli_c FROM fx_parties WHERE company_id = v_co AND code = 'TRAIN_CLI_C';
  SELECT id INTO v_cli_d FROM fx_parties WHERE company_id = v_co AND code = 'TRAIN_CLI_D';
  SELECT id INTO v_agt_a FROM fx_parties WHERE company_id = v_co AND code = 'TRAIN_AGT_A';
  SELECT id INTO v_agt_b FROM fx_parties WHERE company_id = v_co AND code = 'TRAIN_AGT_B';

  -- Agent external bank details (SAMPLE synthetic)
  INSERT INTO fx_party_bank_accounts (
    company_id, party_id, bank_name, account_title, account_number, iban,
    currency_code, is_primary, is_active, notes
  )
  SELECT v_co, v_agt_a, 'SAMPLE Meezan External', 'TRAIN Agent A SAMPLE',
         'SAMPLE-AGT-A-001', 'PK00SAMPLE0000000000000001', 'PKR', TRUE, TRUE,
         'AM_TRAINING_20261023_V1 SAMPLE synthetic — not real bank details'
  WHERE NOT EXISTS (
    SELECT 1 FROM fx_party_bank_accounts
    WHERE party_id = v_agt_a AND account_number = 'SAMPLE-AGT-A-001'
  );

  INSERT INTO fx_party_bank_accounts (
    company_id, party_id, bank_name, account_title, account_number, iban,
    currency_code, is_primary, is_active, notes
  )
  SELECT v_co, v_agt_b, 'SAMPLE HBL External', 'TRAIN Agent B SAMPLE',
         'SAMPLE-AGT-B-001', 'PK00SAMPLE0000000000000002', 'PKR', TRUE, TRUE,
         'AM_TRAINING_20261023_V1 SAMPLE synthetic — not real bank details'
  WHERE NOT EXISTS (
    SELECT 1 FROM fx_party_bank_accounts
    WHERE party_id = v_agt_b AND account_number = 'SAMPLE-AGT-B-001'
  );

  -- -------------------------------------------------------------------------
  -- Cash/bank accounts via fx_create_cash_bank_account (fallback insert)
  -- -------------------------------------------------------------------------
  v_acc_cash := fx_account_id_by_code(v_co, '1113');
  IF v_acc_cash IS NULL THEN
    BEGIN
      v_acc_cash := (
        fx_create_cash_bank_account(
          'TRAINING Cash in Hand', 'PKR', 'cash',
          NULL, NULL, NULL, v_br, '1113',
          NULL, NULL, NULL, NULL,
          'SAMPLE synthetic — not real bank details',
          NULL,
          v_op_prefix || ':acct_1113'
        )->>'account_id'
      )::UUID;
    EXCEPTION WHEN OTHERS THEN
      INSERT INTO fx_accounts (
        company_id, branch_id, code, name, account_type, currency_id, parent_id,
        metadata_notes
      ) VALUES (
        v_co, v_br, '1113', 'TRAINING Cash in Hand', 'asset', v_pkr, v_parent_1000,
        'SAMPLE synthetic — not real bank details | AM_TRAINING_20261023_V1'
      )
      ON CONFLICT (company_id, code) DO NOTHING
      RETURNING id INTO v_acc_cash;
      IF v_acc_cash IS NULL THEN
        v_acc_cash := fx_account_id_by_code(v_co, '1113');
      END IF;
      INSERT INTO fx_client_operations (
        company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
      ) VALUES (
        v_co, v_op_prefix || ':acct_1113', 'cash_bank_create', 'fx_account', v_acc_cash,
        jsonb_build_object('account_id', v_acc_cash, 'code', '1113'), auth.uid()
      ) ON CONFLICT (company_id, operation_key) DO NOTHING;
    END;
  END IF;

  v_acc_petty := fx_account_id_by_code(v_co, '1114');
  IF v_acc_petty IS NULL THEN
    BEGIN
      v_acc_petty := (
        fx_create_cash_bank_account(
          'TRAINING Petty Cash', 'PKR', 'cash',
          NULL, NULL, NULL, v_br, '1114',
          NULL, NULL, NULL, NULL,
          'SAMPLE synthetic — not real bank details',
          NULL,
          v_op_prefix || ':acct_1114'
        )->>'account_id'
      )::UUID;
    EXCEPTION WHEN OTHERS THEN
      INSERT INTO fx_accounts (
        company_id, branch_id, code, name, account_type, currency_id, parent_id,
        metadata_notes
      ) VALUES (
        v_co, v_br, '1114', 'TRAINING Petty Cash', 'asset', v_pkr, v_parent_1000,
        'SAMPLE synthetic — not real bank details | AM_TRAINING_20261023_V1'
      )
      ON CONFLICT (company_id, code) DO NOTHING
      RETURNING id INTO v_acc_petty;
      IF v_acc_petty IS NULL THEN
        v_acc_petty := fx_account_id_by_code(v_co, '1114');
      END IF;
      INSERT INTO fx_client_operations (
        company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
      ) VALUES (
        v_co, v_op_prefix || ':acct_1114', 'cash_bank_create', 'fx_account', v_acc_petty,
        jsonb_build_object('account_id', v_acc_petty, 'code', '1114'), auth.uid()
      ) ON CONFLICT (company_id, operation_key) DO NOTHING;
    END;
  END IF;

  v_acc_meezan := fx_account_id_by_code(v_co, '1211');
  IF v_acc_meezan IS NULL THEN
    BEGIN
      v_acc_meezan := (
        fx_create_cash_bank_account(
          'TRAINING Meezan Bank', 'PKR', 'bank',
          'SAMPLE Meezan', 'TRAINING Meezan SAMPLE', 'SAMPLE-MZ-1211', v_br, '1211',
          'PK00SAMPLEMZ00000000001211', 'SAMPLE Branch', 'MZ01', NULL,
          'SAMPLE synthetic — not real bank details',
          NULL,
          v_op_prefix || ':acct_1211'
        )->>'account_id'
      )::UUID;
    EXCEPTION WHEN OTHERS THEN
      INSERT INTO fx_accounts (
        company_id, branch_id, code, name, account_type, currency_id, parent_id,
        bank_name, account_title, account_number, iban, metadata_notes
      ) VALUES (
        v_co, v_br, '1211', 'TRAINING Meezan Bank', 'asset', v_pkr, v_parent_1000,
        'SAMPLE Meezan', 'TRAINING Meezan SAMPLE', 'SAMPLE-MZ-1211',
        'PK00SAMPLEMZ00000000001211',
        'SAMPLE synthetic — not real bank details | AM_TRAINING_20261023_V1'
      )
      ON CONFLICT (company_id, code) DO NOTHING
      RETURNING id INTO v_acc_meezan;
      IF v_acc_meezan IS NULL THEN
        v_acc_meezan := fx_account_id_by_code(v_co, '1211');
      END IF;
      INSERT INTO fx_client_operations (
        company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
      ) VALUES (
        v_co, v_op_prefix || ':acct_1211', 'cash_bank_create', 'fx_account', v_acc_meezan,
        jsonb_build_object('account_id', v_acc_meezan, 'code', '1211'), auth.uid()
      ) ON CONFLICT (company_id, operation_key) DO NOTHING;
    END;
  END IF;

  v_acc_alfalah := fx_account_id_by_code(v_co, '1212');
  IF v_acc_alfalah IS NULL THEN
    BEGIN
      v_acc_alfalah := (
        fx_create_cash_bank_account(
          'TRAINING Bank Alfalah', 'PKR', 'bank',
          'SAMPLE Alfalah', 'TRAINING Alfalah SAMPLE', 'SAMPLE-AF-1212', v_br, '1212',
          'PK00SAMPLEAF00000000001212', 'SAMPLE Branch', 'AF01', NULL,
          'SAMPLE synthetic — not real bank details',
          NULL,
          v_op_prefix || ':acct_1212'
        )->>'account_id'
      )::UUID;
    EXCEPTION WHEN OTHERS THEN
      INSERT INTO fx_accounts (
        company_id, branch_id, code, name, account_type, currency_id, parent_id,
        bank_name, account_title, account_number, iban, metadata_notes
      ) VALUES (
        v_co, v_br, '1212', 'TRAINING Bank Alfalah', 'asset', v_pkr, v_parent_1000,
        'SAMPLE Alfalah', 'TRAINING Alfalah SAMPLE', 'SAMPLE-AF-1212',
        'PK00SAMPLEAF00000000001212',
        'SAMPLE synthetic — not real bank details | AM_TRAINING_20261023_V1'
      )
      ON CONFLICT (company_id, code) DO NOTHING
      RETURNING id INTO v_acc_alfalah;
      IF v_acc_alfalah IS NULL THEN
        v_acc_alfalah := fx_account_id_by_code(v_co, '1212');
      END IF;
      INSERT INTO fx_client_operations (
        company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
      ) VALUES (
        v_co, v_op_prefix || ':acct_1212', 'cash_bank_create', 'fx_account', v_acc_alfalah,
        jsonb_build_object('account_id', v_acc_alfalah, 'code', '1212'), auth.uid()
      ) ON CONFLICT (company_id, operation_key) DO NOTHING;
    END;
  END IF;

  v_acc_hbl := fx_account_id_by_code(v_co, '1213');
  IF v_acc_hbl IS NULL THEN
    BEGIN
      v_acc_hbl := (
        fx_create_cash_bank_account(
          'TRAINING HBL', 'PKR', 'bank',
          'SAMPLE HBL', 'TRAINING HBL SAMPLE', 'SAMPLE-HB-1213', v_br, '1213',
          'PK00SAMPLEHB00000000001213', 'SAMPLE Branch', 'HB01', NULL,
          'SAMPLE synthetic — not real bank details',
          NULL,
          v_op_prefix || ':acct_1213'
        )->>'account_id'
      )::UUID;
    EXCEPTION WHEN OTHERS THEN
      INSERT INTO fx_accounts (
        company_id, branch_id, code, name, account_type, currency_id, parent_id,
        bank_name, account_title, account_number, iban, metadata_notes
      ) VALUES (
        v_co, v_br, '1213', 'TRAINING HBL', 'asset', v_pkr, v_parent_1000,
        'SAMPLE HBL', 'TRAINING HBL SAMPLE', 'SAMPLE-HB-1213',
        'PK00SAMPLEHB00000000001213',
        'SAMPLE synthetic — not real bank details | AM_TRAINING_20261023_V1'
      )
      ON CONFLICT (company_id, code) DO NOTHING
      RETURNING id INTO v_acc_hbl;
      IF v_acc_hbl IS NULL THEN
        v_acc_hbl := fx_account_id_by_code(v_co, '1213');
      END IF;
      INSERT INTO fx_client_operations (
        company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
      ) VALUES (
        v_co, v_op_prefix || ':acct_1213', 'cash_bank_create', 'fx_account', v_acc_hbl,
        jsonb_build_object('account_id', v_acc_hbl, 'code', '1213'), auth.uid()
      ) ON CONFLICT (company_id, operation_key) DO NOTHING;
    END;
  END IF;

  v_acc_cash := fx_account_id_by_code(v_co, '1113');
  v_acc_petty := fx_account_id_by_code(v_co, '1114');
  v_acc_meezan := fx_account_id_by_code(v_co, '1211');
  v_acc_alfalah := fx_account_id_by_code(v_co, '1212');
  v_acc_hbl := fx_account_id_by_code(v_co, '1213');
  IF v_acc_cash IS NULL OR v_acc_petty IS NULL OR v_acc_meezan IS NULL
     OR v_acc_alfalah IS NULL OR v_acc_hbl IS NULL THEN
    RAISE EXCEPTION 'Training cash/bank accounts missing after create';
  END IF;

  -- -------------------------------------------------------------------------
  -- Opening balances (only if training OB not yet applied / accounts idle)
  -- -------------------------------------------------------------------------
  IF EXISTS (
    SELECT 1 FROM fx_client_operations
    WHERE company_id = v_co AND operation_key = v_op_prefix || ':ob_batch'
  ) THEN
    v_ob_done := TRUE;
  END IF;

  IF NOT v_ob_done THEN
    v_need_ob := NOT EXISTS (
      SELECT 1
      FROM fx_transaction_lines tl
      JOIN fx_transactions t ON t.id = tl.transaction_id
      WHERE t.company_id = v_co
        AND t.status = 'posted'
        AND tl.account_id IN (v_acc_cash, v_acc_petty, v_acc_meezan, v_acc_alfalah, v_acc_hbl)
    );
  END IF;

  IF v_need_ob AND NOT v_ob_done THEN
    -- Prefer batch RPC when branch has no posted opening; else per-account opening txs
    IF NOT EXISTS (
      SELECT 1 FROM fx_opening_balance_batches
      WHERE branch_id = v_br AND status = 'posted'
    ) THEN
      v_batch := (
        fx_save_opening_balance_batch(jsonb_build_object(
          'company_id', v_co,
          'branch_id', v_br,
          'opening_date', CURRENT_DATE,
          'base_currency_code', 'PKR',
          'description', 'AM_TRAINING_20261023_V1 opening',
          'notes', 'AM_TRAINING_20261023_V1 Debit cash/banks 14M / Credit equity 3100',
          'equity_account_id', v_acc_equity,
          'lines', jsonb_build_array(
            jsonb_build_object(
              'line_no', 1, 'line_kind', 'cash_bank', 'pkr_amount', 1800000,
              'currency_code', 'PKR', 'foreign_amount', 1800000, 'rate_used', 1,
              'account_id', v_acc_cash,
              'memo', 'AM_TRAINING_20261023_V1 OB Cash in Hand 1.8M'
            ),
            jsonb_build_object(
              'line_no', 2, 'line_kind', 'cash_bank', 'pkr_amount', 200000,
              'currency_code', 'PKR', 'foreign_amount', 200000, 'rate_used', 1,
              'account_id', v_acc_petty,
              'memo', 'AM_TRAINING_20261023_V1 OB Petty Cash 0.2M'
            ),
            jsonb_build_object(
              'line_no', 3, 'line_kind', 'cash_bank', 'pkr_amount', 6000000,
              'currency_code', 'PKR', 'foreign_amount', 6000000, 'rate_used', 1,
              'account_id', v_acc_meezan,
              'memo', 'AM_TRAINING_20261023_V1 OB Meezan 6M'
            ),
            jsonb_build_object(
              'line_no', 4, 'line_kind', 'cash_bank', 'pkr_amount', 3000000,
              'currency_code', 'PKR', 'foreign_amount', 3000000, 'rate_used', 1,
              'account_id', v_acc_alfalah,
              'memo', 'AM_TRAINING_20261023_V1 OB Alfalah 3M'
            ),
            jsonb_build_object(
              'line_no', 5, 'line_kind', 'cash_bank', 'pkr_amount', 3000000,
              'currency_code', 'PKR', 'foreign_amount', 3000000, 'rate_used', 1,
              'account_id', v_acc_hbl,
              'memo', 'AM_TRAINING_20261023_V1 OB HBL 3M'
            )
          )
        ))
      )#>>'{batch,id}';
      IF v_batch IS NULL THEN
        RAISE EXCEPTION 'Opening balance save returned no batch id';
      END IF;
      PERFORM fx_post_opening_balance_batch(v_batch);
      INSERT INTO fx_client_operations (
        company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
      ) VALUES (
        v_co, v_op_prefix || ':ob_batch', 'opening_balance_batch', 'fx_opening_balance_batch',
        v_batch,
        jsonb_build_object('batch_id', v_batch, 'total_pkr', 14000000),
        auth.uid()
      ) ON CONFLICT (company_id, operation_key) DO NOTHING;
    ELSE
      -- Branch already has a posted opening (e.g. DEMO_SEED_V1): post additive
      -- opening_balance txs for training accounts only (Dr cash/bank / Cr 3100).

      -- 1113
      IF NOT EXISTS (
        SELECT 1 FROM fx_client_operations
        WHERE company_id = v_co AND operation_key = v_op_prefix || ':ob_1113'
      ) THEN
        INSERT INTO fx_transactions (
          company_id, branch_id, transaction_type, status, transaction_date,
          currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
          description, created_by
        ) VALUES (
          v_co, v_br, 'opening_balance', 'draft', CURRENT_DATE,
          'PKR', 1800000, 1, 1800000,
          'AM_TRAINING_20261023_V1 OB Cash in Hand 1.8M', auth.uid()
        ) RETURNING id INTO v_tx;
        INSERT INTO fx_transaction_lines (
          transaction_id, line_no, account_id, currency_code,
          foreign_amount, rate_used, base_amount_pkr, debit_pkr, credit_pkr, memo
        ) VALUES
          (v_tx, 1, v_acc_cash, 'PKR', 1800000, 1, 1800000, 1800000, 0,
           'AM_TRAINING_20261023_V1 OB'),
          (v_tx, 2, v_acc_equity, 'PKR', 1800000, 1, 1800000, 0, 1800000,
           'AM_TRAINING_20261023_V1 Opening Equity');
        PERFORM fx_post_transaction(v_tx);
        INSERT INTO fx_client_operations (
          company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
        ) VALUES (
          v_co, v_op_prefix || ':ob_1113', 'opening_balance', 'fx_transaction', v_tx,
          jsonb_build_object('transaction_id', v_tx, 'code', '1113', 'pkr', 1800000), auth.uid()
        ) ON CONFLICT (company_id, operation_key) DO NOTHING;
      END IF;

      IF NOT EXISTS (
        SELECT 1 FROM fx_client_operations
        WHERE company_id = v_co AND operation_key = v_op_prefix || ':ob_1114'
      ) THEN
        INSERT INTO fx_transactions (
          company_id, branch_id, transaction_type, status, transaction_date,
          currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
          description, created_by
        ) VALUES (
          v_co, v_br, 'opening_balance', 'draft', CURRENT_DATE,
          'PKR', 200000, 1, 200000,
          'AM_TRAINING_20261023_V1 OB Petty Cash 0.2M', auth.uid()
        ) RETURNING id INTO v_tx;
        INSERT INTO fx_transaction_lines (
          transaction_id, line_no, account_id, currency_code,
          foreign_amount, rate_used, base_amount_pkr, debit_pkr, credit_pkr, memo
        ) VALUES
          (v_tx, 1, v_acc_petty, 'PKR', 200000, 1, 200000, 200000, 0,
           'AM_TRAINING_20261023_V1 OB'),
          (v_tx, 2, v_acc_equity, 'PKR', 200000, 1, 200000, 0, 200000,
           'AM_TRAINING_20261023_V1 Opening Equity');
        PERFORM fx_post_transaction(v_tx);
        INSERT INTO fx_client_operations (
          company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
        ) VALUES (
          v_co, v_op_prefix || ':ob_1114', 'opening_balance', 'fx_transaction', v_tx,
          jsonb_build_object('transaction_id', v_tx, 'code', '1114', 'pkr', 200000), auth.uid()
        ) ON CONFLICT (company_id, operation_key) DO NOTHING;
      END IF;

      IF NOT EXISTS (
        SELECT 1 FROM fx_client_operations
        WHERE company_id = v_co AND operation_key = v_op_prefix || ':ob_1211'
      ) THEN
        INSERT INTO fx_transactions (
          company_id, branch_id, transaction_type, status, transaction_date,
          currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
          description, created_by
        ) VALUES (
          v_co, v_br, 'opening_balance', 'draft', CURRENT_DATE,
          'PKR', 6000000, 1, 6000000,
          'AM_TRAINING_20261023_V1 OB Meezan 6M', auth.uid()
        ) RETURNING id INTO v_tx;
        INSERT INTO fx_transaction_lines (
          transaction_id, line_no, account_id, currency_code,
          foreign_amount, rate_used, base_amount_pkr, debit_pkr, credit_pkr, memo
        ) VALUES
          (v_tx, 1, v_acc_meezan, 'PKR', 6000000, 1, 6000000, 6000000, 0,
           'AM_TRAINING_20261023_V1 OB'),
          (v_tx, 2, v_acc_equity, 'PKR', 6000000, 1, 6000000, 0, 6000000,
           'AM_TRAINING_20261023_V1 Opening Equity');
        PERFORM fx_post_transaction(v_tx);
        INSERT INTO fx_client_operations (
          company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
        ) VALUES (
          v_co, v_op_prefix || ':ob_1211', 'opening_balance', 'fx_transaction', v_tx,
          jsonb_build_object('transaction_id', v_tx, 'code', '1211', 'pkr', 6000000), auth.uid()
        ) ON CONFLICT (company_id, operation_key) DO NOTHING;
      END IF;

      IF NOT EXISTS (
        SELECT 1 FROM fx_client_operations
        WHERE company_id = v_co AND operation_key = v_op_prefix || ':ob_1212'
      ) THEN
        INSERT INTO fx_transactions (
          company_id, branch_id, transaction_type, status, transaction_date,
          currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
          description, created_by
        ) VALUES (
          v_co, v_br, 'opening_balance', 'draft', CURRENT_DATE,
          'PKR', 3000000, 1, 3000000,
          'AM_TRAINING_20261023_V1 OB Alfalah 3M', auth.uid()
        ) RETURNING id INTO v_tx;
        INSERT INTO fx_transaction_lines (
          transaction_id, line_no, account_id, currency_code,
          foreign_amount, rate_used, base_amount_pkr, debit_pkr, credit_pkr, memo
        ) VALUES
          (v_tx, 1, v_acc_alfalah, 'PKR', 3000000, 1, 3000000, 3000000, 0,
           'AM_TRAINING_20261023_V1 OB'),
          (v_tx, 2, v_acc_equity, 'PKR', 3000000, 1, 3000000, 0, 3000000,
           'AM_TRAINING_20261023_V1 Opening Equity');
        PERFORM fx_post_transaction(v_tx);
        INSERT INTO fx_client_operations (
          company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
        ) VALUES (
          v_co, v_op_prefix || ':ob_1212', 'opening_balance', 'fx_transaction', v_tx,
          jsonb_build_object('transaction_id', v_tx, 'code', '1212', 'pkr', 3000000), auth.uid()
        ) ON CONFLICT (company_id, operation_key) DO NOTHING;
      END IF;

      IF NOT EXISTS (
        SELECT 1 FROM fx_client_operations
        WHERE company_id = v_co AND operation_key = v_op_prefix || ':ob_1213'
      ) THEN
        INSERT INTO fx_transactions (
          company_id, branch_id, transaction_type, status, transaction_date,
          currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
          description, created_by
        ) VALUES (
          v_co, v_br, 'opening_balance', 'draft', CURRENT_DATE,
          'PKR', 3000000, 1, 3000000,
          'AM_TRAINING_20261023_V1 OB HBL 3M', auth.uid()
        ) RETURNING id INTO v_tx;
        INSERT INTO fx_transaction_lines (
          transaction_id, line_no, account_id, currency_code,
          foreign_amount, rate_used, base_amount_pkr, debit_pkr, credit_pkr, memo
        ) VALUES
          (v_tx, 1, v_acc_hbl, 'PKR', 3000000, 1, 3000000, 3000000, 0,
           'AM_TRAINING_20261023_V1 OB'),
          (v_tx, 2, v_acc_equity, 'PKR', 3000000, 1, 3000000, 0, 3000000,
           'AM_TRAINING_20261023_V1 Opening Equity');
        PERFORM fx_post_transaction(v_tx);
        INSERT INTO fx_client_operations (
          company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
        ) VALUES (
          v_co, v_op_prefix || ':ob_1213', 'opening_balance', 'fx_transaction', v_tx,
          jsonb_build_object('transaction_id', v_tx, 'code', '1213', 'pkr', 3000000), auth.uid()
        ) ON CONFLICT (company_id, operation_key) DO NOTHING;
      END IF;

      INSERT INTO fx_client_operations (
        company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
      ) VALUES (
        v_co, v_op_prefix || ':ob_batch', 'opening_balance_additive', 'fx_client_operations',
        v_co,
        jsonb_build_object('mode', 'per_account_opening_balance', 'total_pkr', 14000000),
        auth.uid()
      ) ON CONFLICT (company_id, operation_key) DO NOTHING;
    END IF;
  END IF;

  -- =========================================================================
  -- DEAL 1 — Client A / Agent A: CNY 50000 @ 41.50 / source 41
  -- =========================================================================
  v_deal1 := fx_book_customer_deal_v2(jsonb_build_object(
    'branch_id', v_br,
    'customer_party_id', v_cli_a,
    'sell_currency_code', 'CNY',
    'sell_amount', 50000,
    'sale_rate_pkr', 41.50,
    'delivery_method', 'agent',
    'allow_short_position', true,
    'auto_source', false,
    'notes', 'AM_TRAINING_20261023_V1 DEAL1 Client A CNY50000@41.50'
  ));
  SELECT deal_no INTO v_deal1_no FROM fx_deals WHERE id = v_deal1;

  v_src1 := fx_add_deal_leg_v2(jsonb_build_object(
    'deal_id', v_deal1,
    'leg_type', 'agent_source',
    'counterparty_party_id', v_agt_a,
    'receive_currency', 'CNY',
    'receive_amount', 50000,
    'pay_currency', 'PKR',
    'pay_amount', 2050000,
    'rate_used', 41,
    'notes', 'AM_TRAINING_20261023_V1 DEAL1 source @41 = 2050000',
    'client_operation_id', v_op_prefix || ':d1_source'
  ));

  v_tx := fx_recognize_agent_source_payable(v_src1, v_op_prefix || ':d1_recognize');
  v_ops := v_ops || jsonb_build_object('d1_recognize', v_tx);

  v_tx := fx_record_deal_customer_payment(
    v_deal1, c_d1_cust_meezan,
    'AM_TRAINING_20261023_V1 DEAL1 cust pay Meezan 400000',
    v_acc_meezan, v_op_prefix || ':d1_cust_meezan'
  );
  v_ops := v_ops || jsonb_build_object('d1_cust_meezan', v_tx);

  v_tx := fx_record_deal_third_party_payment(
    v_deal1, c_d1_tp_agent, v_agt_a, v_src1,
    'SAMPLE Agent A external Meezan',
    'SAMPLE-TP-D1',
    'AM_TRAINING_20261023_V1 DEAL1 third-party 350000 to Agent A external',
    v_op_prefix || ':d1_third_party'
  );
  v_ops := v_ops || jsonb_build_object('d1_third_party', v_tx);

  v_tx := fx_record_deal_customer_payment(
    v_deal1, c_d1_cust_alfalah,
    'AM_TRAINING_20261023_V1 DEAL1 cust pay Alfalah 287500',
    v_acc_alfalah, v_op_prefix || ':d1_cust_alfalah'
  );
  v_ops := v_ops || jsonb_build_object('d1_cust_alfalah', v_tx);

  -- Remaining agent payable 1,700,000 split Meezan/Alfalah/HBL
  v_tx := fx_post_settlement_send(
    v_co, v_br, v_agt_a, c_d1_pay_meezan, '1211', '2100', v_deal1,
    'AM_TRAINING_20261023_V1 DEAL1 agent pay Meezan 700000 of remaining 1700000',
    v_op_prefix || ':d1_agent_meezan', TRUE
  );
  v_ops := v_ops || jsonb_build_object('d1_agent_meezan', v_tx);

  v_tx := fx_post_settlement_send(
    v_co, v_br, v_agt_a, c_d1_pay_alfalah, '1212', '2100', v_deal1,
    'AM_TRAINING_20261023_V1 DEAL1 agent pay Alfalah 500000 of remaining 1700000',
    v_op_prefix || ':d1_agent_alfalah', TRUE
  );
  v_ops := v_ops || jsonb_build_object('d1_agent_alfalah', v_tx);

  v_tx := fx_post_settlement_send(
    v_co, v_br, v_agt_a, c_d1_pay_hbl, '1213', '2100', v_deal1,
    'AM_TRAINING_20261023_V1 DEAL1 agent pay HBL 500000 of remaining 1700000',
    v_op_prefix || ':d1_agent_hbl', TRUE
  );
  v_ops := v_ops || jsonb_build_object('d1_agent_hbl', v_tx);

  v_rcpt := fx_add_deal_leg_v2(jsonb_build_object(
    'deal_id', v_deal1,
    'leg_type', 'currency_receipt',
    'parent_leg_id', v_src1,
    'counterparty_party_id', v_agt_a,
    'receive_currency', 'CNY',
    'receive_amount', 50000,
    'notes', 'AM_TRAINING_20261023_V1 DEAL1 full receipt 50000',
    'client_operation_id', v_op_prefix || ':d1_receipt_leg'
  ));
  v_tx := fx_post_currency_receipt_inventory(v_rcpt, v_op_prefix || ':d1_receipt_inv');
  v_ops := v_ops || jsonb_build_object('d1_receipt_inv', v_tx);

  -- Deliver 20000 cost 820000 (=20000*41); leave 30000 reserved/owned
  PERFORM fx_confirm_deal_delivery(
    v_deal1, 20000::numeric, 'direct_to_customer'::fx_delivery_target,
    820000::numeric, 'SAMPLE-DEL-D1',
    'AM_TRAINING_20261023_V1 DEAL1 deliver 20000 cost 820000',
    v_op_prefix || ':d1_deliver'
  );
  PERFORM fx_agent_balance_consume_reserve(v_co, v_br, v_agt_a, 'CNY', 20000);

  -- =========================================================================
  -- DEAL 2 — Client B / Agent B: USD 1000 @ 280 / buy 278
  -- =========================================================================
  v_deal2 := fx_book_customer_deal_v2(jsonb_build_object(
    'branch_id', v_br,
    'customer_party_id', v_cli_b,
    'sell_currency_code', 'USD',
    'sell_amount', 1000,
    'sale_rate_pkr', 280,
    'delivery_method', 'agent',
    'allow_short_position', true,
    'auto_source', false,
    'notes', 'AM_TRAINING_20261023_V1 DEAL2 Client B USD1000@280'
  ));
  SELECT deal_no INTO v_deal2_no FROM fx_deals WHERE id = v_deal2;

  v_src2 := fx_add_deal_leg_v2(jsonb_build_object(
    'deal_id', v_deal2,
    'leg_type', 'agent_source',
    'counterparty_party_id', v_agt_b,
    'receive_currency', 'USD',
    'receive_amount', 1000,
    'pay_currency', 'PKR',
    'pay_amount', 278000,
    'rate_used', 278,
    'notes', 'AM_TRAINING_20261023_V1 DEAL2 source @278',
    'client_operation_id', v_op_prefix || ':d2_source'
  ));
  v_tx := fx_recognize_agent_source_payable(v_src2, v_op_prefix || ':d2_recognize');
  v_ops := v_ops || jsonb_build_object('d2_recognize', v_tx);

  v_tx := fx_record_deal_customer_payment(
    v_deal2, c_d2_cust_meezan,
    'AM_TRAINING_20261023_V1 DEAL2 cust receipt1 Meezan 140000',
    v_acc_meezan, v_op_prefix || ':d2_cust1'
  );
  v_ops := v_ops || jsonb_build_object('d2_cust1', v_tx);

  v_tx := fx_record_deal_customer_payment(
    v_deal2, c_d2_cust_alfalah,
    'AM_TRAINING_20261023_V1 DEAL2 cust receipt2 Alfalah 140000',
    v_acc_alfalah, v_op_prefix || ':d2_cust2'
  );
  v_ops := v_ops || jsonb_build_object('d2_cust2', v_tx);

  v_tx := fx_post_settlement_send(
    v_co, v_br, v_agt_b, c_d2_pay_hbl, '1213', '2100', v_deal2,
    'AM_TRAINING_20261023_V1 DEAL2 pay agent 278000 from HBL',
    v_op_prefix || ':d2_agent_pay', TRUE
  );
  v_ops := v_ops || jsonb_build_object('d2_agent_pay', v_tx);

  v_rcpt := fx_add_deal_leg_v2(jsonb_build_object(
    'deal_id', v_deal2,
    'leg_type', 'currency_receipt',
    'parent_leg_id', v_src2,
    'counterparty_party_id', v_agt_b,
    'receive_currency', 'USD',
    'receive_amount', 1000,
    'notes', 'AM_TRAINING_20261023_V1 DEAL2 full receipt',
    'client_operation_id', v_op_prefix || ':d2_receipt_leg'
  ));
  v_tx := fx_post_currency_receipt_inventory(v_rcpt, v_op_prefix || ':d2_receipt_inv');
  v_ops := v_ops || jsonb_build_object('d2_receipt_inv', v_tx);

  PERFORM fx_confirm_deal_delivery(
    v_deal2, 1000::numeric, 'direct_to_customer'::fx_delivery_target,
    278000::numeric, 'SAMPLE-DEL-D2',
    'AM_TRAINING_20261023_V1 DEAL2 deliver all',
    v_op_prefix || ':d2_deliver'
  );
  PERFORM fx_agent_balance_consume_reserve(v_co, v_br, v_agt_b, 'USD', 1000);

  -- =========================================================================
  -- DEAL 3 — Client C / Agent A: AED 5000 @ 76.50 / 76
  -- =========================================================================
  v_deal3 := fx_book_customer_deal_v2(jsonb_build_object(
    'branch_id', v_br,
    'customer_party_id', v_cli_c,
    'sell_currency_code', 'AED',
    'sell_amount', 5000,
    'sale_rate_pkr', 76.50,
    'delivery_method', 'agent',
    'allow_short_position', true,
    'auto_source', false,
    'notes', 'AM_TRAINING_20261023_V1 DEAL3 Client C AED5000@76.50'
  ));
  SELECT deal_no INTO v_deal3_no FROM fx_deals WHERE id = v_deal3;

  v_src3 := fx_add_deal_leg_v2(jsonb_build_object(
    'deal_id', v_deal3,
    'leg_type', 'agent_source',
    'counterparty_party_id', v_agt_a,
    'receive_currency', 'AED',
    'receive_amount', 5000,
    'pay_currency', 'PKR',
    'pay_amount', 380000,
    'rate_used', 76,
    'notes', 'AM_TRAINING_20261023_V1 DEAL3 source @76',
    'client_operation_id', v_op_prefix || ':d3_source'
  ));
  v_tx := fx_recognize_agent_source_payable(v_src3, v_op_prefix || ':d3_recognize');
  v_ops := v_ops || jsonb_build_object('d3_recognize', v_tx);

  v_tx := fx_record_deal_customer_payment(
    v_deal3, c_d3_cust_meezan,
    'AM_TRAINING_20261023_V1 DEAL3 cust pay bank Meezan full 382500',
    v_acc_meezan, v_op_prefix || ':d3_cust'
  );
  v_ops := v_ops || jsonb_build_object('d3_cust', v_tx);

  v_tx := fx_post_settlement_send(
    v_co, v_br, v_agt_a, c_d3_pay_alfalah, '1212', '2100', v_deal3,
    'AM_TRAINING_20261023_V1 DEAL3 pay agent 380000 Alfalah',
    v_op_prefix || ':d3_agent_pay', TRUE
  );
  v_ops := v_ops || jsonb_build_object('d3_agent_pay', v_tx);

  v_rcpt := fx_add_deal_leg_v2(jsonb_build_object(
    'deal_id', v_deal3,
    'leg_type', 'currency_receipt',
    'parent_leg_id', v_src3,
    'counterparty_party_id', v_agt_a,
    'receive_currency', 'AED',
    'receive_amount', 5000,
    'notes', 'AM_TRAINING_20261023_V1 DEAL3 full receipt',
    'client_operation_id', v_op_prefix || ':d3_receipt_leg'
  ));
  v_tx := fx_post_currency_receipt_inventory(v_rcpt, v_op_prefix || ':d3_receipt_inv');
  v_ops := v_ops || jsonb_build_object('d3_receipt_inv', v_tx);

  PERFORM fx_confirm_deal_delivery(
    v_deal3, 5000::numeric, 'direct_to_customer'::fx_delivery_target,
    380000::numeric, 'SAMPLE-DEL-D3',
    'AM_TRAINING_20261023_V1 DEAL3 deliver all',
    v_op_prefix || ':d3_deliver'
  );
  PERFORM fx_agent_balance_consume_reserve(v_co, v_br, v_agt_a, 'AED', 5000);

  -- =========================================================================
  -- DEAL 4 — Client D / Agent B: CNY 10000 @ 42 / 41.60
  -- =========================================================================
  v_deal4 := fx_book_customer_deal_v2(jsonb_build_object(
    'branch_id', v_br,
    'customer_party_id', v_cli_d,
    'sell_currency_code', 'CNY',
    'sell_amount', 10000,
    'sale_rate_pkr', 42,
    'delivery_method', 'agent',
    'allow_short_position', true,
    'auto_source', false,
    'notes', 'AM_TRAINING_20261023_V1 DEAL4 Client D CNY10000@42'
  ));
  SELECT deal_no INTO v_deal4_no FROM fx_deals WHERE id = v_deal4;

  v_src4 := fx_add_deal_leg_v2(jsonb_build_object(
    'deal_id', v_deal4,
    'leg_type', 'agent_source',
    'counterparty_party_id', v_agt_b,
    'receive_currency', 'CNY',
    'receive_amount', 10000,
    'pay_currency', 'PKR',
    'pay_amount', 416000,
    'rate_used', 41.60,
    'notes', 'AM_TRAINING_20261023_V1 DEAL4 source @41.60',
    'client_operation_id', v_op_prefix || ':d4_source'
  ));
  v_tx := fx_recognize_agent_source_payable(v_src4, v_op_prefix || ':d4_recognize');
  v_ops := v_ops || jsonb_build_object('d4_recognize', v_tx);

  v_tx := fx_record_deal_customer_payment(
    v_deal4, c_d4_cust_hbl,
    'AM_TRAINING_20261023_V1 DEAL4 client pay 100000 HBL',
    v_acc_hbl, v_op_prefix || ':d4_cust'
  );
  v_ops := v_ops || jsonb_build_object('d4_cust', v_tx);

  v_tx := fx_post_settlement_send(
    v_co, v_br, v_agt_b, c_d4_pay_meezan, '1211', '2100', v_deal4,
    'AM_TRAINING_20261023_V1 DEAL4 pay agent 200000 Meezan',
    v_op_prefix || ':d4_agent_pay', TRUE
  );
  v_ops := v_ops || jsonb_build_object('d4_agent_pay', v_tx);

  v_rcpt := fx_add_deal_leg_v2(jsonb_build_object(
    'deal_id', v_deal4,
    'leg_type', 'currency_receipt',
    'parent_leg_id', v_src4,
    'counterparty_party_id', v_agt_b,
    'receive_currency', 'CNY',
    'receive_amount', 10000,
    'notes', 'AM_TRAINING_20261023_V1 DEAL4 full receipt inventory',
    'client_operation_id', v_op_prefix || ':d4_receipt_leg'
  ));
  v_tx := fx_post_currency_receipt_inventory(v_rcpt, v_op_prefix || ':d4_receipt_inv');
  v_ops := v_ops || jsonb_build_object('d4_receipt_inv', v_tx);

  -- Deliver 4000; cost proportional = 416000 * 0.4 = 166400
  PERFORM fx_confirm_deal_delivery(
    v_deal4, 4000::numeric, 'direct_to_customer'::fx_delivery_target,
    166400::numeric, 'SAMPLE-DEL-D4',
    'AM_TRAINING_20261023_V1 DEAL4 deliver 4000 cost proportional 166400',
    v_op_prefix || ':d4_deliver'
  );
  PERFORM fx_agent_balance_consume_reserve(v_co, v_br, v_agt_b, 'CNY', 4000);

  -- =========================================================================
  -- DEAL 5 — Remittance draft TT USD 2000 @ 281 Client A / Agent B
  -- =========================================================================
  BEGIN
    v_rem := fx_create_remittance(
      v_br, v_cli_a, 'TT Receiver SAMPLE', NULL, 'Sample City', 'US', v_agt_b,
      'PKR', 562000, 'USD', 2000, 281, 0,
      'AM_TRAINING_20261023_V1 DEAL5 TT draft indicative_rate=281 USD2000 ClientA→AgentB',
      'customer_paid', false
    );
  EXCEPTION WHEN OTHERS THEN
    -- 15-arg signature without commission_mode
    v_rem := fx_create_remittance(
      v_br, v_cli_a, 'TT Receiver SAMPLE', NULL, 'Sample City', 'US', v_agt_b,
      'PKR', 562000, 'USD', 2000, 281, 0,
      'AM_TRAINING_20261023_V1 DEAL5 TT draft indicative_rate=281 USD2000 ClientA→AgentB',
      false
    );
  END;
  UPDATE fx_remittances
  SET notes = COALESCE(notes, '') || ' | AM_TRAINING_20261023_V1 book_immediately=false'
  WHERE id = v_rem;
  v_ops := v_ops || jsonb_build_object('d5_remittance', v_rem);

  -- =========================================================================
  -- SCENARIO 6 — Agent B advance 5M then purchase_funded (advance)
  -- Remaining advance = 5000000 - 834000 - 820000 = 3346000
  -- =========================================================================
  IF v_acc_1180 IS NULL THEN
    RAISE EXCEPTION 'Account 1180 required for advance scenario';
  END IF;

  v_tx := fx_post_settlement_send(
    v_co, v_br, v_agt_b, c_s6_adv_meezan, '1211', '1180', NULL,
    'AM_TRAINING_20261023_V1 S6 advance 5M Meezan→1180 Agent B',
    v_op_prefix || ':s6_advance_5m', FALSE
  );
  v_ops := v_ops || jsonb_build_object('s6_advance_5m', v_tx);

  v_tx := fx_post_agent_currency_purchase_funded(
    v_co, v_br, v_agt_b, 'USD', 3000, 278, 'advance', '1180',
    'AM_TRAINING_20261023_V1 S6 purchase_funded USD3000@278 advance',
    v_op_prefix || ':s6_buy_usd'
  );
  v_ops := v_ops || jsonb_build_object('s6_buy_usd', v_tx);

  v_tx := fx_post_agent_currency_purchase_funded(
    v_co, v_br, v_agt_b, 'CNY', 20000, 41, 'advance', '1180',
    'AM_TRAINING_20261023_V1 S6 purchase_funded CNY20000@41 advance',
    v_op_prefix || ':s6_buy_cny'
  );
  v_ops := v_ops || jsonb_build_object('s6_buy_cny', v_tx);

  -- =========================================================================
  -- SCENARIO 7 — Agent A credit purchase + two 100k settlements
  -- Payable remains 556000 - 200000 = 356000
  -- =========================================================================
  v_tx := fx_post_agent_currency_purchase_funded(
    v_co, v_br, v_agt_a, 'USD', 2000, 278, 'credit', NULL,
    'AM_TRAINING_20261023_V1 S7 purchase_funded USD2000@278 credit Agent A',
    v_op_prefix || ':s7_buy_credit'
  );
  v_ops := v_ops || jsonb_build_object('s7_buy_credit', v_tx);

  v_tx := fx_post_settlement_send(
    v_co, v_br, v_agt_a, c_s7_pay_alfalah, '1212', '2100', NULL,
    'AM_TRAINING_20261023_V1 S7 settle Agent A 100000 Alfalah',
    v_op_prefix || ':s7_pay1', TRUE
  );
  v_ops := v_ops || jsonb_build_object('s7_pay1', v_tx);

  v_tx := fx_post_settlement_send(
    v_co, v_br, v_agt_a, c_s7_pay_hbl, '1213', '2100', NULL,
    'AM_TRAINING_20261023_V1 S7 settle Agent A 100000 HBL',
    v_op_prefix || ':s7_pay2', TRUE
  );
  v_ops := v_ops || jsonb_build_object('s7_pay2', v_tx);

  -- =========================================================================
  -- CASH: transfer 20000 Cash→Petty; expense 2000 from Petty
  -- =========================================================================
  IF NOT EXISTS (
    SELECT 1 FROM fx_client_operations
    WHERE company_id = v_co AND operation_key = v_op_prefix || ':cash_xfer'
  ) THEN
    INSERT INTO fx_transactions (
      company_id, branch_id, transaction_type, status, transaction_date,
      currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
      description, created_by
    ) VALUES (
      v_co, v_br, 'account_transfer', 'draft', CURRENT_DATE,
      'PKR', c_xfer, 1, c_xfer,
      'AM_TRAINING_20261023_V1 transfer 20000 Cash in Hand → Petty',
      auth.uid()
    ) RETURNING id INTO v_tx;
    INSERT INTO fx_transaction_lines (
      transaction_id, line_no, account_id, currency_code,
      foreign_amount, rate_used, base_amount_pkr, debit_pkr, credit_pkr, memo
    ) VALUES
      (v_tx, 1, v_acc_petty, 'PKR', c_xfer, 1, c_xfer, c_xfer, 0,
       'AM_TRAINING_20261023_V1 transfer in'),
      (v_tx, 2, v_acc_cash, 'PKR', c_xfer, 1, c_xfer, 0, c_xfer,
       'AM_TRAINING_20261023_V1 transfer out');
    PERFORM fx_post_transaction(v_tx);
    INSERT INTO fx_client_operations (
      company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
    ) VALUES (
      v_co, v_op_prefix || ':cash_xfer', 'account_transfer', 'fx_transaction', v_tx,
      jsonb_build_object('transaction_id', v_tx, 'amount', c_xfer), auth.uid()
    ) ON CONFLICT (company_id, operation_key) DO NOTHING;
    v_ops := v_ops || jsonb_build_object('cash_xfer', v_tx);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM fx_client_operations
    WHERE company_id = v_co AND operation_key = v_op_prefix || ':office_expense'
  ) THEN
    INSERT INTO fx_transactions (
      company_id, branch_id, transaction_type, status, transaction_date,
      currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
      description, created_by
    ) VALUES (
      v_co, v_br, 'expense', 'draft', CURRENT_DATE,
      'PKR', c_exp, 1, c_exp,
      'AM_TRAINING_20261023_V1 DEMO OFFICE EXPENSE 2000 from Petty',
      auth.uid()
    ) RETURNING id INTO v_tx;
    INSERT INTO fx_transaction_lines (
      transaction_id, line_no, account_id, currency_code,
      foreign_amount, rate_used, base_amount_pkr, debit_pkr, credit_pkr, memo
    ) VALUES
      (v_tx, 1, v_acc_expense, 'PKR', c_exp, 1, c_exp, c_exp, 0,
       'AM_TRAINING_20261023_V1 DEMO OFFICE EXPENSE'),
      (v_tx, 2, v_acc_petty, 'PKR', c_exp, 1, c_exp, 0, c_exp,
       'AM_TRAINING_20261023_V1 Petty out');
    PERFORM fx_post_transaction(v_tx);
    INSERT INTO fx_client_operations (
      company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
    ) VALUES (
      v_co, v_op_prefix || ':office_expense', 'expense', 'fx_transaction', v_tx,
      jsonb_build_object('transaction_id', v_tx, 'amount', c_exp), auth.uid()
    ) ON CONFLICT (company_id, operation_key) DO NOTHING;
    v_ops := v_ops || jsonb_build_object('office_expense', v_tx);
  END IF;

  -- -------------------------------------------------------------------------
  -- Expected owned bank totals (openings ± listed movements)
  -- -------------------------------------------------------------------------
  v_cash_bal := 1800000 - c_xfer;                 -- 1780000
  v_petty_bal := 200000 + c_xfer - c_exp;         -- 218000
  v_meezan_bal := 6000000
    + c_d1_cust_meezan - c_d1_pay_meezan
    + c_d2_cust_meezan
    + c_d3_cust_meezan
    - c_d4_pay_meezan
    - c_s6_adv_meezan;                            -- 1022500
  v_alfalah_bal := 3000000
    + c_d1_cust_alfalah - c_d1_pay_alfalah
    + c_d2_cust_alfalah
    - c_d3_pay_alfalah
    - c_s7_pay_alfalah;                           -- 2447500
  v_hbl_bal := 3000000
    - c_d1_pay_hbl
    - c_d2_pay_hbl
    + c_d4_cust_hbl
    - c_s7_pay_hbl;                               -- 2222000

  v_result := jsonb_build_object(
    'seed_version', v_seed,
    'idempotent', false,
    'company_id', v_co,
    'company_code', 'AM_DEMO',
    'branch_id', v_br,
    'parties', jsonb_build_object(
      'client_a', jsonb_build_object('id', v_cli_a, 'code', 'TRAIN_CLI_A'),
      'client_b', jsonb_build_object('id', v_cli_b, 'code', 'TRAIN_CLI_B'),
      'client_c', jsonb_build_object('id', v_cli_c, 'code', 'TRAIN_CLI_C'),
      'client_d', jsonb_build_object('id', v_cli_d, 'code', 'TRAIN_CLI_D'),
      'agent_a', jsonb_build_object('id', v_agt_a, 'code', 'TRAIN_AGT_A'),
      'agent_b', jsonb_build_object('id', v_agt_b, 'code', 'TRAIN_AGT_B')
    ),
    'accounts', jsonb_build_object(
      'cash_in_hand', jsonb_build_object('id', v_acc_cash, 'code', '1113'),
      'petty_cash', jsonb_build_object('id', v_acc_petty, 'code', '1114'),
      'meezan', jsonb_build_object('id', v_acc_meezan, 'code', '1211'),
      'alfalah', jsonb_build_object('id', v_acc_alfalah, 'code', '1212'),
      'hbl', jsonb_build_object('id', v_acc_hbl, 'code', '1213'),
      'expense_5800', jsonb_build_object('id', v_acc_expense, 'code', '5800'),
      'agent_advance_1180', jsonb_build_object('id', v_acc_1180, 'code', '1180')
    ),
    'deals', jsonb_build_object(
      'deal1', jsonb_build_object('id', v_deal1, 'deal_no', v_deal1_no, 'source_leg_id', v_src1),
      'deal2', jsonb_build_object('id', v_deal2, 'deal_no', v_deal2_no, 'source_leg_id', v_src2),
      'deal3', jsonb_build_object('id', v_deal3, 'deal_no', v_deal3_no, 'source_leg_id', v_src3),
      'deal4', jsonb_build_object('id', v_deal4, 'deal_no', v_deal4_no, 'source_leg_id', v_src4)
    ),
    'remittance_id', v_rem,
    'operation_ids', v_ops,
    'expected_totals', jsonb_build_object(
      'customer_batch_due_ex_tt', 1357500,
      'agent_b_advance_remaining', 3346000,
      'cash_in_hand', 1780000,
      'petty', 218000,
      'meezan_1211', v_meezan_bal,
      'alfalah_1212', v_alfalah_bal,
      'hbl_1213', v_hbl_bal,
      'agent_a_payable_remaining_s7', 356000,
      'deal1_customer_due', 1037500,
      'deal4_customer_due', 320000,
      'deal1_agent_cny_owned_remaining', 30000
    ),
    'bank_movement_plan', jsonb_build_object(
      'd1_agent_pay_split', jsonb_build_object(
        'meezan_1211', c_d1_pay_meezan,
        'alfalah_1212', c_d1_pay_alfalah,
        'hbl_1213', c_d1_pay_hbl
      ),
      'notes', 'AM_TRAINING_20261023_V1 labelled bank movements for training recon'
    )
  );

  INSERT INTO fx_training_manifest (seed_version, payload)
  VALUES (v_seed, v_result)
  ON CONFLICT (seed_version) DO UPDATE SET payload = EXCLUDED.payload;

  INSERT INTO fx_demo_seed_batches (seed_version, company_id, actor_user_id, result_json)
  VALUES (v_seed, v_co, auth.uid(), v_result);

  PERFORM set_config('fx_seed.active', '0', true);

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION fx_seed_am_training_20261023_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_seed_am_training_20261023_v1() TO service_role;
GRANT EXECUTE ON FUNCTION fx_seed_am_training_20261023_v1() TO authenticated;
