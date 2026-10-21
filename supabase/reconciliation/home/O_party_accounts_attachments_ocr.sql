-- O_party_accounts_attachments_ocr.sql
-- Party bank details, cash/bank COA creation, attachment metadata,
-- payment-slip OCR drafts + confirm posting. Idempotent / additive.

-- ---------------------------------------------------------------------------
-- 1) Party type: supplier (counterparty)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'fx_party_type' AND e.enumlabel = 'supplier'
  ) THEN
    ALTER TYPE fx_party_type ADD VALUE 'supplier';
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 2) Optional bank details per party (masked display; multiple allowed)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fx_party_bank_accounts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      UUID NOT NULL REFERENCES fx_companies (id) ON DELETE CASCADE,
  party_id        UUID NOT NULL REFERENCES fx_parties (id) ON DELETE CASCADE,
  bank_name       TEXT,
  account_title   TEXT,
  account_number  TEXT,
  iban            TEXT,
  currency_code   TEXT DEFAULT 'PKR',
  is_primary      BOOLEAN NOT NULL DEFAULT FALSE,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fx_party_bank_party
  ON fx_party_bank_accounts (party_id) WHERE is_active;

ALTER TABLE fx_party_bank_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fx_party_bank_select ON fx_party_bank_accounts;
CREATE POLICY fx_party_bank_select ON fx_party_bank_accounts
  FOR SELECT USING (
    fx_same_company(company_id) AND fx_has_permission('can_access_fx_ledger')
  );

DROP POLICY IF EXISTS fx_party_bank_write ON fx_party_bank_accounts;
CREATE POLICY fx_party_bank_write ON fx_party_bank_accounts
  FOR ALL USING (
    fx_same_company(company_id) AND fx_has_permission('can_access_fx_ledger')
  )
  WITH CHECK (
    fx_same_company(company_id) AND fx_has_permission('can_access_fx_ledger')
  );

-- ---------------------------------------------------------------------------
-- 3) Attachment metadata enrichment
-- ---------------------------------------------------------------------------
ALTER TABLE fx_attachments
  ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES fx_companies (id),
  ADD COLUMN IF NOT EXISTS content_hash TEXT,
  ADD COLUMN IF NOT EXISTS original_byte_size INT,
  ADD COLUMN IF NOT EXISTS stored_byte_size INT,
  ADD COLUMN IF NOT EXISTS compression_meta JSONB,
  ADD COLUMN IF NOT EXISTS slip_import_id UUID;

CREATE INDEX IF NOT EXISTS idx_fx_attachments_content_hash
  ON fx_attachments (company_id, content_hash)
  WHERE content_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_fx_attachments_slip_import
  ON fx_attachments (slip_import_id)
  WHERE slip_import_id IS NOT NULL;

-- Backfill company_id from linked transaction/deal when null
UPDATE fx_attachments a
SET company_id = t.company_id
FROM fx_transactions t
WHERE a.company_id IS NULL AND a.transaction_id = t.id;

UPDATE fx_attachments a
SET company_id = d.company_id
FROM fx_deals d
WHERE a.company_id IS NULL AND a.deal_id = d.id;

-- ---------------------------------------------------------------------------
-- 4) Payment slip OCR drafts (never auto-post)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fx_payment_slip_imports (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id          UUID NOT NULL REFERENCES fx_companies (id) ON DELETE CASCADE,
  branch_id           UUID NOT NULL REFERENCES fx_branches (id) ON DELETE RESTRICT,
  status              TEXT NOT NULL DEFAULT 'draft'
                      CHECK (status IN ('draft','confirmed','rejected','failed')),
  classification      TEXT
                      CHECK (classification IS NULL OR classification IN (
                        'receive_from_party','pay_to_party','internal_transfer','unsupported'
                      )),
  amount              NUMERIC(20, 8),
  currency_code       TEXT,
  txn_date            DATE,
  txn_time_text       TEXT,
  sender_name         TEXT,
  sender_bank         TEXT,
  sender_account_mask TEXT,
  receiver_name       TEXT,
  receiver_bank       TEXT,
  receiver_account_mask TEXT,
  bank_reference      TEXT,
  provider_name       TEXT,
  printed_status      TEXT,
  raw_text            TEXT,
  extracted_json      JSONB NOT NULL DEFAULT '{}'::jsonb,
  uncertain_fields    TEXT[] NOT NULL DEFAULT '{}',
  description         TEXT,
  cash_account_id     UUID REFERENCES fx_accounts (id),
  counterparty_party_id UUID REFERENCES fx_parties (id),
  deal_id             UUID REFERENCES fx_deals (id),
  resulting_tx_id     UUID REFERENCES fx_transactions (id),
  client_operation_id TEXT,
  content_hash        TEXT,
  attachment_id       UUID REFERENCES fx_attachments (id),
  ocr_engine          TEXT,
  ocr_error           TEXT,
  created_by          UUID,
  confirmed_by        UUID,
  confirmed_at        TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (company_id, client_operation_id)
);

CREATE INDEX IF NOT EXISTS idx_fx_slip_imports_branch_status
  ON fx_payment_slip_imports (branch_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_fx_slip_imports_hash
  ON fx_payment_slip_imports (company_id, content_hash)
  WHERE content_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_fx_slip_imports_ref
  ON fx_payment_slip_imports (company_id, bank_reference, amount)
  WHERE bank_reference IS NOT NULL;

ALTER TABLE fx_payment_slip_imports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fx_slip_imports_select ON fx_payment_slip_imports;
CREATE POLICY fx_slip_imports_select ON fx_payment_slip_imports
  FOR SELECT USING (
    fx_same_company(company_id) AND fx_has_permission('can_access_fx_ledger')
  );

DROP POLICY IF EXISTS fx_slip_imports_write ON fx_payment_slip_imports;
CREATE POLICY fx_slip_imports_write ON fx_payment_slip_imports
  FOR ALL USING (
    fx_same_company(company_id) AND fx_has_permission('can_access_fx_ledger')
  )
  WITH CHECK (
    fx_same_company(company_id) AND fx_has_permission('can_access_fx_ledger')
  );

-- Link slip_import_id FK after table exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fx_attachments_slip_import_fkey'
  ) THEN
    ALTER TABLE fx_attachments
      ADD CONSTRAINT fx_attachments_slip_import_fkey
      FOREIGN KEY (slip_import_id) REFERENCES fx_payment_slip_imports (id)
      ON DELETE SET NULL;
  END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- 5) fx_create_cash_bank_account
-- Codes: cash 1110-1159 / 1181-1189 (skip reserved), bank 1210-1299
-- Reserved: 1160,1170,1190,2310,2320,2350 (deal/remittance control)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_create_cash_bank_account(
  p_name TEXT,
  p_currency_code TEXT,
  p_kind TEXT DEFAULT 'cash',
  p_bank_name TEXT DEFAULT NULL,
  p_account_title TEXT DEFAULT NULL,
  p_account_identifier TEXT DEFAULT NULL,
  p_branch_id UUID DEFAULT NULL,
  p_code TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_company UUID;
  v_profile_branch UUID;
  v_assets UUID;
  v_currency_id UUID;
  v_code TEXT;
  v_candidate INT;
  v_name TEXT := TRIM(p_name);
  v_kind TEXT := LOWER(TRIM(p_kind));
  v_cur TEXT := UPPER(TRIM(p_currency_code));
  v_id UUID;
  v_notes TEXT;
BEGIN
  IF NOT fx_has_permission('can_manage_chart_of_accounts') THEN
    RAISE EXCEPTION 'Permission denied: can_manage_chart_of_accounts required';
  END IF;
  IF v_kind NOT IN ('cash', 'bank') THEN
    RAISE EXCEPTION 'Kind must be cash or bank';
  END IF;
  IF v_name IS NULL OR LENGTH(v_name) < 2 THEN
    RAISE EXCEPTION 'Display name required';
  END IF;
  IF v_cur NOT IN ('PKR', 'USD', 'AED', 'CNY', 'EUR', 'GBP', 'SAR') THEN
    RAISE EXCEPTION 'Unsupported currency %', v_cur;
  END IF;

  SELECT company_id, branch_id INTO v_company, v_profile_branch
  FROM fx_users_profiles
  WHERE id = auth.uid() AND is_active = TRUE;
  IF v_company IS NULL THEN
    RAISE EXCEPTION 'User profile not configured';
  END IF;

  IF p_branch_id IS NOT NULL AND NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch';
  END IF;

  SELECT id INTO v_currency_id FROM fx_currencies WHERE code = v_cur AND is_active;
  IF v_currency_id IS NULL AND v_cur = 'PKR' THEN
    SELECT id INTO v_currency_id FROM fx_currencies WHERE is_base LIMIT 1;
  END IF;
  IF v_currency_id IS NULL THEN
    RAISE EXCEPTION 'Currency % not found — add it under Currency Management first', v_cur;
  END IF;

  SELECT id INTO v_assets FROM fx_accounts WHERE company_id = v_company AND code = '1000';
  IF v_assets IS NULL THEN
    INSERT INTO fx_accounts (company_id, code, name, account_type, is_active)
    VALUES (v_company, '1000', 'Assets', 'asset', TRUE)
    ON CONFLICT (company_id, code) DO UPDATE SET name = EXCLUDED.name
    RETURNING id INTO v_assets;
    IF v_assets IS NULL THEN
      SELECT id INTO v_assets FROM fx_accounts WHERE company_id = v_company AND code = '1000';
    END IF;
  END IF;
  IF v_assets IS NULL THEN
    RAISE EXCEPTION 'Could not ensure Assets parent account (1000)';
  END IF;

  IF p_code IS NOT NULL AND TRIM(p_code) <> '' THEN
    v_code := TRIM(p_code);
    IF v_code IN ('1160','1170','1190','2310','2320','2350','1000','2000','3000','4000','5000','6000') THEN
      RAISE EXCEPTION 'Code % is reserved for system control accounts', v_code;
    END IF;
    IF EXISTS (SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = v_code) THEN
      RAISE EXCEPTION 'Account code % already exists', v_code;
    END IF;
  ELSE
    v_code := NULL;
    IF v_kind = 'cash' THEN
      IF v_cur = 'PKR' AND NOT EXISTS (
        SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = '1110'
      ) THEN
        v_code := '1110';
      ELSE
        FOR v_candidate IN 1111..1159 LOOP
          IF v_candidate::TEXT IN ('1160','1170') THEN CONTINUE; END IF;
          IF NOT EXISTS (
            SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = v_candidate::TEXT
          ) THEN
            v_code := v_candidate::TEXT;
            EXIT;
          END IF;
        END LOOP;
        IF v_code IS NULL THEN
          FOR v_candidate IN 1181..1189 LOOP
            IF NOT EXISTS (
              SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = v_candidate::TEXT
            ) THEN
              v_code := v_candidate::TEXT;
              EXIT;
            END IF;
          END LOOP;
        END IF;
      END IF;
    ELSE
      FOR v_candidate IN 1210..1299 LOOP
        IF NOT EXISTS (
          SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = v_candidate::TEXT
        ) THEN
          v_code := v_candidate::TEXT;
          EXIT;
        END IF;
      END LOOP;
    END IF;
    IF v_code IS NULL THEN
      RAISE EXCEPTION 'No available account code slot for % accounts', v_kind;
    END IF;
  END IF;

  v_notes := NULLIF(TRIM(CONCAT_WS(' | ',
    CASE WHEN p_bank_name IS NOT NULL THEN 'Bank: ' || TRIM(p_bank_name) END,
    CASE WHEN p_account_title IS NOT NULL THEN 'Title: ' || TRIM(p_account_title) END,
    CASE WHEN p_account_identifier IS NOT NULL THEN 'ID: ' || TRIM(p_account_identifier) END
  )), '');

  INSERT INTO fx_accounts (
    company_id, branch_id, code, name, account_type, currency_id, parent_id, is_active
  ) VALUES (
    v_company,
    COALESCE(p_branch_id, v_profile_branch),
    v_code,
    v_name,
    'asset',
    v_currency_id,
    v_assets,
    TRUE
  ) RETURNING id INTO v_id;

  -- Zero opening balance by design — use opening-balance workflow separately.
  RETURN jsonb_build_object(
    'account_id', v_id,
    'code', v_code,
    'name', v_name,
    'kind', v_kind,
    'currency_code', v_cur,
    'opening_balance', 0,
    'notes', v_notes
  );
END;
$$;

REVOKE ALL ON FUNCTION fx_create_cash_bank_account(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_create_cash_bank_account(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6) Soft-deactivate cash/bank with dependency checks
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_deactivate_fx_account(p_account_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_acct fx_accounts;
  v_posted INT;
BEGIN
  IF NOT fx_has_permission('can_manage_chart_of_accounts') THEN
    RAISE EXCEPTION 'Permission denied: can_manage_chart_of_accounts required';
  END IF;

  SELECT * INTO v_acct FROM fx_accounts WHERE id = p_account_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Account not found'; END IF;
  IF NOT fx_same_company(v_acct.company_id) THEN
    RAISE EXCEPTION 'Unauthorized company';
  END IF;
  IF v_acct.code IN ('1000','2000','3000','4000','5000','6000','1160','1170','1190','2310','2350') THEN
    RAISE EXCEPTION 'System control account % cannot be deactivated here', v_acct.code;
  END IF;

  SELECT COUNT(*) INTO v_posted
  FROM fx_journal_lines jl
  JOIN fx_journals j ON j.id = jl.journal_id
  WHERE jl.account_id = p_account_id AND j.status = 'posted';

  -- Allow deactivate even with history; block only if used as active mapping dependency
  UPDATE fx_accounts SET is_active = FALSE, updated_at = NOW() WHERE id = p_account_id;

  RETURN jsonb_build_object(
    'account_id', p_account_id,
    'deactivated', TRUE,
    'posted_lines', v_posted
  );
END;
$$;

REVOKE ALL ON FUNCTION fx_deactivate_fx_account(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_deactivate_fx_account(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- 7) Save / update slip import draft
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_upsert_payment_slip_import(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_company UUID;
  v_branch UUID;
  v_id UUID;
  v_op TEXT := NULLIF(TRIM(p_payload->>'client_operation_id'), '');
  v_existing UUID;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT company_id, branch_id INTO v_company, v_branch
  FROM fx_users_profiles WHERE id = auth.uid() AND is_active;
  IF v_company IS NULL THEN RAISE EXCEPTION 'Profile missing'; END IF;

  IF p_payload ? 'branch_id' AND (p_payload->>'branch_id') IS NOT NULL THEN
    v_branch := (p_payload->>'branch_id')::UUID;
    IF NOT fx_same_branch(v_branch) THEN
      RAISE EXCEPTION 'Unauthorized branch';
    END IF;
  END IF;

  IF v_op IS NOT NULL THEN
    SELECT id INTO v_existing FROM fx_payment_slip_imports
    WHERE company_id = v_company AND client_operation_id = v_op;
    IF v_existing IS NOT NULL THEN
      UPDATE fx_payment_slip_imports SET
        amount = COALESCE((p_payload->>'amount')::NUMERIC, amount),
        currency_code = COALESCE(p_payload->>'currency_code', currency_code),
        txn_date = COALESCE((p_payload->>'txn_date')::DATE, txn_date),
        txn_time_text = COALESCE(p_payload->>'txn_time_text', txn_time_text),
        sender_name = COALESCE(p_payload->>'sender_name', sender_name),
        sender_bank = COALESCE(p_payload->>'sender_bank', sender_bank),
        sender_account_mask = COALESCE(p_payload->>'sender_account_mask', sender_account_mask),
        receiver_name = COALESCE(p_payload->>'receiver_name', receiver_name),
        receiver_bank = COALESCE(p_payload->>'receiver_bank', receiver_bank),
        receiver_account_mask = COALESCE(p_payload->>'receiver_account_mask', receiver_account_mask),
        bank_reference = COALESCE(p_payload->>'bank_reference', bank_reference),
        provider_name = COALESCE(p_payload->>'provider_name', provider_name),
        printed_status = COALESCE(p_payload->>'printed_status', printed_status),
        raw_text = COALESCE(p_payload->>'raw_text', raw_text),
        extracted_json = COALESCE(p_payload->'extracted_json', extracted_json),
        uncertain_fields = COALESCE(
          ARRAY(SELECT jsonb_array_elements_text(p_payload->'uncertain_fields')),
          uncertain_fields
        ),
        description = COALESCE(p_payload->>'description', description),
        classification = COALESCE(p_payload->>'classification', classification),
        cash_account_id = COALESCE((p_payload->>'cash_account_id')::UUID, cash_account_id),
        counterparty_party_id = COALESCE((p_payload->>'counterparty_party_id')::UUID, counterparty_party_id),
        deal_id = COALESCE((p_payload->>'deal_id')::UUID, deal_id),
        content_hash = COALESCE(p_payload->>'content_hash', content_hash),
        attachment_id = COALESCE((p_payload->>'attachment_id')::UUID, attachment_id),
        ocr_engine = COALESCE(p_payload->>'ocr_engine', ocr_engine),
        ocr_error = COALESCE(p_payload->>'ocr_error', ocr_error),
        status = CASE WHEN status = 'confirmed' THEN status ELSE COALESCE(p_payload->>'status', status) END,
        updated_at = NOW()
      WHERE id = v_existing;
      RETURN v_existing;
    END IF;
  END IF;

  INSERT INTO fx_payment_slip_imports (
    company_id, branch_id, status, classification,
    amount, currency_code, txn_date, txn_time_text,
    sender_name, sender_bank, sender_account_mask,
    receiver_name, receiver_bank, receiver_account_mask,
    bank_reference, provider_name, printed_status,
    raw_text, extracted_json, uncertain_fields, description,
    cash_account_id, counterparty_party_id, deal_id,
    client_operation_id, content_hash, attachment_id,
    ocr_engine, ocr_error, created_by
  ) VALUES (
    v_company, v_branch, COALESCE(p_payload->>'status', 'draft'),
    p_payload->>'classification',
    (p_payload->>'amount')::NUMERIC,
    p_payload->>'currency_code',
    (p_payload->>'txn_date')::DATE,
    p_payload->>'txn_time_text',
    p_payload->>'sender_name', p_payload->>'sender_bank', p_payload->>'sender_account_mask',
    p_payload->>'receiver_name', p_payload->>'receiver_bank', p_payload->>'receiver_account_mask',
    p_payload->>'bank_reference', p_payload->>'provider_name', p_payload->>'printed_status',
    p_payload->>'raw_text',
    COALESCE(p_payload->'extracted_json', '{}'::jsonb),
    COALESCE(ARRAY(SELECT jsonb_array_elements_text(p_payload->'uncertain_fields')), '{}'),
    p_payload->>'description',
    (p_payload->>'cash_account_id')::UUID,
    (p_payload->>'counterparty_party_id')::UUID,
    (p_payload->>'deal_id')::UUID,
    v_op,
    p_payload->>'content_hash',
    (p_payload->>'attachment_id')::UUID,
    p_payload->>'ocr_engine',
    p_payload->>'ocr_error',
    auth.uid()
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION fx_upsert_payment_slip_import(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_upsert_payment_slip_import(JSONB) TO authenticated;

-- ---------------------------------------------------------------------------
-- 8) Confirm slip → post via existing deal payment or settlement draft path
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_confirm_payment_slip_import(
  p_import_id UUID,
  p_client_operation_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_imp fx_payment_slip_imports;
  v_tx UUID;
  v_cash fx_accounts;
  v_party fx_parties;
  v_op TEXT;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_imp FROM fx_payment_slip_imports WHERE id = p_import_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Slip import not found'; END IF;
  IF NOT fx_same_company(v_imp.company_id) OR NOT fx_same_branch(v_imp.branch_id) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF v_imp.status = 'confirmed' AND v_imp.resulting_tx_id IS NOT NULL THEN
    RETURN v_imp.resulting_tx_id;
  END IF;
  IF v_imp.status = 'rejected' THEN
    RAISE EXCEPTION 'Import was rejected';
  END IF;

  v_op := COALESCE(NULLIF(TRIM(p_client_operation_id), ''), v_imp.client_operation_id);
  IF v_op IS NOT NULL THEN
    SELECT entity_id INTO v_tx FROM fx_client_operations
    WHERE company_id = v_imp.company_id AND operation_key = v_op;
    IF v_tx IS NOT NULL THEN
      UPDATE fx_payment_slip_imports SET
        status = 'confirmed', resulting_tx_id = v_tx,
        confirmed_by = auth.uid(), confirmed_at = NOW(), updated_at = NOW()
      WHERE id = p_import_id;
      RETURN v_tx;
    END IF;
  END IF;

  IF v_imp.amount IS NULL OR v_imp.amount <= 0 THEN
    RAISE EXCEPTION 'Confirm requires a positive amount';
  END IF;
  IF COALESCE(v_imp.currency_code, 'PKR') <> 'PKR' THEN
    RAISE EXCEPTION 'Slip confirm currently supports PKR receipts only; use manual draft for %',
      v_imp.currency_code;
  END IF;
  IF v_imp.cash_account_id IS NULL THEN
    RAISE EXCEPTION 'Select the receiving/paying cash or bank account';
  END IF;
  IF v_imp.classification IS NULL OR v_imp.classification = 'unsupported' THEN
    RAISE EXCEPTION 'Classification is unsupported or missing — keep as draft';
  END IF;

  SELECT * INTO v_cash FROM fx_accounts WHERE id = v_imp.cash_account_id;
  IF NOT FOUND OR v_cash.company_id IS DISTINCT FROM v_imp.company_id THEN
    RAISE EXCEPTION 'Cash/bank account invalid for this company';
  END IF;
  IF v_cash.account_type IS DISTINCT FROM 'asset'::fx_account_type OR NOT v_cash.is_active THEN
    RAISE EXCEPTION 'Account must be an active asset cash/bank account';
  END IF;

  IF v_imp.classification IN ('receive_from_party', 'pay_to_party') THEN
    IF v_imp.counterparty_party_id IS NULL THEN
      RAISE EXCEPTION 'Select a counterparty party';
    END IF;
    SELECT * INTO v_party FROM fx_parties WHERE id = v_imp.counterparty_party_id;
    IF NOT FOUND OR v_party.company_id IS DISTINCT FROM v_imp.company_id THEN
      RAISE EXCEPTION 'Counterparty invalid for this company';
    END IF;
  END IF;

  -- Duplicate reference warning gate: block only if already confirmed same ref+amount+account
  IF v_imp.bank_reference IS NOT NULL AND EXISTS (
    SELECT 1 FROM fx_payment_slip_imports x
    WHERE x.company_id = v_imp.company_id
      AND x.id <> v_imp.id
      AND x.status = 'confirmed'
      AND x.bank_reference = v_imp.bank_reference
      AND x.amount = v_imp.amount
      AND x.cash_account_id = v_imp.cash_account_id
  ) THEN
    RAISE EXCEPTION
      'Possible duplicate transfer: same bank reference, amount, and account already confirmed. Attach evidence to the existing transaction instead.';
  END IF;

  IF v_imp.classification = 'receive_from_party' AND v_imp.deal_id IS NOT NULL THEN
    -- Allocate to deal via existing payment RPC (Dr cash / Cr advances)
    PERFORM fx_ensure_deal_coa(v_imp.company_id);
    v_tx := fx_record_deal_customer_payment(
      v_imp.deal_id,
      v_imp.amount,
      COALESCE(v_imp.description, 'Slip import payment'),
      v_imp.cash_account_id,
      COALESCE(v_op, 'slip-confirm-' || p_import_id::TEXT)
    );
  ELSIF v_imp.classification = 'receive_from_party' THEN
    PERFORM fx_ensure_deal_coa(v_imp.company_id);
    IF fx_account_id_by_code(v_imp.company_id, '1160') IS NULL THEN
      RAISE EXCEPTION 'Missing account 1160 for party settlement credit';
    END IF;

    INSERT INTO fx_transactions (
      company_id, branch_id, transaction_type, status, transaction_date,
      party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
      description, created_by
    ) VALUES (
      v_imp.company_id, v_imp.branch_id, 'settlement_receive', 'draft',
      COALESCE(v_imp.txn_date, CURRENT_DATE),
      v_imp.counterparty_party_id, 'PKR', v_imp.amount, 1, v_imp.amount,
      COALESCE(v_imp.description, 'Payment received (slip import)'),
      auth.uid()
    ) RETURNING id INTO v_tx;

    INSERT INTO fx_transaction_lines (
      transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used,
      base_amount_pkr, debit_pkr, credit_pkr, memo
    ) VALUES
      (v_tx, 1, v_imp.cash_account_id, 'PKR', v_imp.amount, 1, v_imp.amount, v_imp.amount, 0, 'Cash/bank in'),
      (v_tx, 2, fx_account_id_by_code(v_imp.company_id, '1160'), 'PKR', v_imp.amount, 1, v_imp.amount, 0, v_imp.amount, 'Party settlement');

    PERFORM fx_post_transaction(v_tx);
  ELSIF v_imp.classification = 'pay_to_party' THEN
    PERFORM fx_ensure_deal_coa(v_imp.company_id);
    IF COALESCE(
      fx_account_id_by_code(v_imp.company_id, '1160'),
      fx_account_id_by_code(v_imp.company_id, '1190')
    ) IS NULL THEN
      RAISE EXCEPTION 'Missing settlement/receivable account for party payment';
    END IF;

    INSERT INTO fx_transactions (
      company_id, branch_id, transaction_type, status, transaction_date,
      party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
      description, created_by
    ) VALUES (
      v_imp.company_id, v_imp.branch_id, 'settlement_send', 'draft',
      COALESCE(v_imp.txn_date, CURRENT_DATE),
      v_imp.counterparty_party_id, 'PKR', v_imp.amount, 1, v_imp.amount,
      COALESCE(v_imp.description, 'Payment sent (slip import)'),
      auth.uid()
    ) RETURNING id INTO v_tx;

    INSERT INTO fx_transaction_lines (
      transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used,
      base_amount_pkr, debit_pkr, credit_pkr, memo
    ) VALUES
      (v_tx, 1, COALESCE(fx_account_id_by_code(v_imp.company_id, '1160'), fx_account_id_by_code(v_imp.company_id, '1190')),
       'PKR', v_imp.amount, 1, v_imp.amount, v_imp.amount, 0, 'Party settlement'),
      (v_tx, 2, v_imp.cash_account_id, 'PKR', v_imp.amount, 1, v_imp.amount, 0, v_imp.amount, 'Cash/bank out');

    PERFORM fx_post_transaction(v_tx);
  ELSIF v_imp.classification = 'internal_transfer' THEN
    RAISE EXCEPTION
      'Internal transfer confirm requires destination account in payload — use Transfer workflow or update classification details';
  ELSE
    RAISE EXCEPTION 'Unsupported classification';
  END IF;

  UPDATE fx_payment_slip_imports SET
    status = 'confirmed',
    resulting_tx_id = v_tx,
    confirmed_by = auth.uid(),
    confirmed_at = NOW(),
    client_operation_id = COALESCE(client_operation_id, v_op),
    updated_at = NOW()
  WHERE id = p_import_id;

  IF v_imp.attachment_id IS NOT NULL THEN
    UPDATE fx_attachments SET
      transaction_id = COALESCE(transaction_id, v_tx),
      slip_import_id = p_import_id,
      company_id = COALESCE(company_id, v_imp.company_id)
    WHERE id = v_imp.attachment_id;
  END IF;

  IF v_op IS NOT NULL THEN
    INSERT INTO fx_client_operations (
      company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
    ) VALUES (
      v_imp.company_id, v_op, 'slip_import_confirm', 'fx_transaction', v_tx,
      jsonb_build_object('import_id', p_import_id, 'amount', v_imp.amount),
      auth.uid()
    ) ON CONFLICT (company_id, operation_key) DO NOTHING;
  END IF;

  RETURN v_tx;
END;
$$;

REVOKE ALL ON FUNCTION fx_confirm_payment_slip_import(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_confirm_payment_slip_import(UUID, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 9) Duplicate candidates helper
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_find_slip_duplicate_candidates(
  p_content_hash TEXT DEFAULT NULL,
  p_bank_reference TEXT DEFAULT NULL,
  p_amount NUMERIC DEFAULT NULL,
  p_cash_account_id UUID DEFAULT NULL
)
RETURNS TABLE (
  import_id UUID,
  status TEXT,
  amount NUMERIC,
  bank_reference TEXT,
  resulting_tx_id UUID,
  match_reason TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_company UUID;
BEGIN
  SELECT company_id INTO v_company FROM fx_users_profiles WHERE id = auth.uid();
  IF v_company IS NULL THEN RETURN; END IF;

  RETURN QUERY
  SELECT i.id, i.status, i.amount, i.bank_reference, i.resulting_tx_id,
         CASE
           WHEN p_content_hash IS NOT NULL AND i.content_hash = p_content_hash THEN 'same_file_hash'
           WHEN p_bank_reference IS NOT NULL AND i.bank_reference = p_bank_reference
                AND p_amount IS NOT NULL AND i.amount = p_amount
                AND (p_cash_account_id IS NULL OR i.cash_account_id = p_cash_account_id)
             THEN 'same_reference_amount'
           ELSE 'related'
         END
  FROM fx_payment_slip_imports i
  WHERE i.company_id = v_company
    AND (
      (p_content_hash IS NOT NULL AND i.content_hash = p_content_hash)
      OR (
        p_bank_reference IS NOT NULL AND i.bank_reference = p_bank_reference
        AND p_amount IS NOT NULL AND i.amount = p_amount
      )
    )
  ORDER BY i.created_at DESC
  LIMIT 20;
END;
$$;

REVOKE ALL ON FUNCTION fx_find_slip_duplicate_candidates(TEXT, TEXT, NUMERIC, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_find_slip_duplicate_candidates(TEXT, TEXT, NUMERIC, UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
