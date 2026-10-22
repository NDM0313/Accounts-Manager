-- S_party_profile_openings.sql
-- Structured party profile fields, auto party codes, cash/bank metadata columns,
-- party photo attachment link, single-entity opening posts (after company OB).

-- ---------------------------------------------------------------------------
-- 1) Party profile columns (structured; not stuffed into notes)
-- ---------------------------------------------------------------------------
ALTER TABLE fx_parties
  ADD COLUMN IF NOT EXISTS contact_person TEXT,
  ADD COLUMN IF NOT EXISTS business_name TEXT,
  ADD COLUMN IF NOT EXISTS phone_e164 TEXT,
  ADD COLUMN IF NOT EXISTS phone_display TEXT,
  ADD COLUMN IF NOT EXISTS phone2_e164 TEXT,
  ADD COLUMN IF NOT EXISTS phone2_display TEXT,
  ADD COLUMN IF NOT EXISTS whatsapp_e164 TEXT,
  ADD COLUMN IF NOT EXISTS whatsapp_display TEXT,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS address_line1 TEXT,
  ADD COLUMN IF NOT EXISTS address_line2 TEXT,
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS province TEXT,
  ADD COLUMN IF NOT EXISTS postal_code TEXT,
  ADD COLUMN IF NOT EXISTS country_code TEXT,
  ADD COLUMN IF NOT EXISTS website TEXT,
  ADD COLUMN IF NOT EXISTS photo_attachment_id UUID,
  ADD COLUMN IF NOT EXISTS social_links JSONB NOT NULL DEFAULT '{}'::jsonb;

-- Backfill display phone from legacy phone
UPDATE fx_parties
SET phone_display = phone
WHERE phone_display IS NULL AND phone IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_fx_parties_phone_e164
  ON fx_parties (company_id, phone_e164)
  WHERE phone_e164 IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 2) Cash/bank structured metadata on fx_accounts
-- ---------------------------------------------------------------------------
ALTER TABLE fx_accounts
  ADD COLUMN IF NOT EXISTS bank_name TEXT,
  ADD COLUMN IF NOT EXISTS account_title TEXT,
  ADD COLUMN IF NOT EXISTS account_number TEXT,
  ADD COLUMN IF NOT EXISTS iban TEXT,
  ADD COLUMN IF NOT EXISTS branch_name TEXT,
  ADD COLUMN IF NOT EXISTS branch_code TEXT,
  ADD COLUMN IF NOT EXISTS swift_bic TEXT,
  ADD COLUMN IF NOT EXISTS metadata_notes TEXT;

-- ---------------------------------------------------------------------------
-- 3) Attachments may target a party (profile photo)
-- ---------------------------------------------------------------------------
ALTER TABLE fx_attachments
  ADD COLUMN IF NOT EXISTS party_id UUID REFERENCES fx_parties (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_fx_attachments_party
  ON fx_attachments (party_id)
  WHERE party_id IS NOT NULL;

ALTER TABLE fx_attachments DROP CONSTRAINT IF EXISTS fx_attachments_target_check;
ALTER TABLE fx_attachments ADD CONSTRAINT fx_attachments_target_check CHECK (
  transaction_id IS NOT NULL
  OR deal_id IS NOT NULL
  OR remittance_id IS NOT NULL
  OR message_id IS NOT NULL
  OR slip_import_id IS NOT NULL
  OR party_id IS NOT NULL
);

-- Party photo FK after attachments.party_id exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fx_parties_photo_attachment_fkey'
  ) THEN
    ALTER TABLE fx_parties
      ADD CONSTRAINT fx_parties_photo_attachment_fkey
      FOREIGN KEY (photo_attachment_id) REFERENCES fx_attachments (id)
      ON DELETE SET NULL;
  END IF;
END $$;

-- Allow attachment insert for party_id same-company
DROP POLICY IF EXISTS fx_attachments_insert ON fx_attachments;
CREATE POLICY fx_attachments_insert ON fx_attachments
  FOR INSERT WITH CHECK (
    company_id IS NOT NULL
    AND fx_same_company(company_id)
    AND fx_has_permission('can_access_fx_ledger')
    AND (
      (transaction_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_transactions t
        WHERE t.id = transaction_id AND fx_same_branch(t.branch_id)
      ))
      OR (deal_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id)
      ))
      OR (remittance_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_remittances r WHERE r.id = remittance_id AND fx_same_branch(r.branch_id)
      ))
      OR (message_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_messages msg
        JOIN fx_conversations c ON c.id = msg.conversation_id
        WHERE msg.id = message_id AND fx_same_branch(c.branch_id)
      ))
      OR (slip_import_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_payment_slip_imports i
        WHERE i.id = slip_import_id AND fx_same_company(i.company_id)
      ))
      OR (party_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_parties p
        WHERE p.id = party_id AND fx_same_company(p.company_id)
      ))
    )
  );

DROP POLICY IF EXISTS fx_attachments_select ON fx_attachments;
CREATE POLICY fx_attachments_select ON fx_attachments
  FOR SELECT USING (
    (company_id IS NOT NULL AND fx_same_company(company_id) AND fx_has_permission('can_access_fx_ledger'))
    OR (transaction_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM fx_transactions t WHERE t.id = transaction_id AND fx_same_branch(t.branch_id)
    ))
    OR (deal_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id)
    ))
    OR (remittance_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM fx_remittances r WHERE r.id = remittance_id AND fx_same_branch(r.branch_id)
    ))
    OR (message_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM fx_messages msg
      JOIN fx_conversations c ON c.id = msg.conversation_id
      WHERE msg.id = message_id AND fx_same_branch(c.branch_id)
    ))
    OR (slip_import_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM fx_payment_slip_imports i
      WHERE i.id = slip_import_id AND fx_same_company(i.company_id)
    ))
    OR (party_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM fx_parties p WHERE p.id = party_id AND fx_same_company(p.company_id)
    ))
  );

-- ---------------------------------------------------------------------------
-- 4) Supplier opening account mapping
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_ob_party_account_code(
  p_party_type TEXT,
  p_kind fx_opening_balance_line_kind
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_kind = 'party_receivable' THEN
    RETURN CASE p_party_type
      WHEN 'customer' THEN '1190'
      WHEN 'agent' THEN '1180'
      WHEN 'supplier' THEN '1190'
      WHEN 'settlement' THEN '1190'
      ELSE NULL
    END;
  END IF;
  IF p_kind = 'party_payable' THEN
    RETURN CASE p_party_type
      WHEN 'customer' THEN '2200'
      WHEN 'agent' THEN '2100'
      WHEN 'supplier' THEN '2200'
      WHEN 'settlement' THEN '2100'
      ELSE NULL
    END;
  END IF;
  RETURN NULL;
END;
$$;

-- ---------------------------------------------------------------------------
-- 5) Concurrency-safe party code allocation
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fx_party_code_sequences (
  company_id UUID NOT NULL REFERENCES fx_companies (id) ON DELETE CASCADE,
  party_type TEXT NOT NULL,
  next_n INT NOT NULL DEFAULT 1,
  PRIMARY KEY (company_id, party_type)
);

CREATE OR REPLACE FUNCTION fx_allocate_party_code(
  p_company_id UUID,
  p_party_type TEXT,
  p_requested TEXT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code TEXT;
  v_prefix TEXT;
  v_n INT;
  v_try INT := 0;
BEGIN
  IF NOT fx_same_company(p_company_id) THEN
    RAISE EXCEPTION 'Unauthorized company';
  END IF;

  v_code := NULLIF(btrim(COALESCE(p_requested, '')), '');
  IF v_code IS NOT NULL THEN
    v_code := upper(regexp_replace(v_code, '[^A-Za-z0-9_-]', '', 'g'));
    IF length(v_code) < 2 OR length(v_code) > 32 THEN
      RAISE EXCEPTION 'INVALID_CODE: custom code must be 2–32 letters, digits, _ or -';
    END IF;
    IF EXISTS (
      SELECT 1 FROM fx_parties WHERE company_id = p_company_id AND code = v_code
    ) THEN
      RAISE EXCEPTION 'DUPLICATE_CODE: party code % already exists in this company', v_code;
    END IF;
    RETURN v_code;
  END IF;

  v_prefix := CASE lower(p_party_type)
    WHEN 'customer' THEN 'C'
    WHEN 'agent' THEN 'A'
    WHEN 'supplier' THEN 'S'
    WHEN 'settlement' THEN 'X'
    ELSE 'P'
  END;

  INSERT INTO fx_party_code_sequences (company_id, party_type, next_n)
  VALUES (p_company_id, lower(p_party_type), 1)
  ON CONFLICT (company_id, party_type) DO NOTHING;

  LOOP
    UPDATE fx_party_code_sequences
    SET next_n = next_n + 1
    WHERE company_id = p_company_id AND party_type = lower(p_party_type)
    RETURNING next_n - 1 INTO v_n;

    v_code := v_prefix || lpad(v_n::TEXT, 4, '0');
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM fx_parties WHERE company_id = p_company_id AND code = v_code
    );
    v_try := v_try + 1;
    IF v_try > 5000 THEN
      RAISE EXCEPTION 'Could not allocate unique party code';
    END IF;
  END LOOP;

  RETURN v_code;
END;
$$;

REVOKE ALL ON FUNCTION fx_allocate_party_code(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_allocate_party_code(UUID, TEXT, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6) Post a single dated opening/adjustment journal (not a second company OB batch)
-- Date convention: amount is the OPENING balance AT THE START of p_as_of_date (PKT calendar date).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_post_entity_opening(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_company UUID := (p_payload->>'company_id')::UUID;
  v_branch UUID := (p_payload->>'branch_id')::UUID;
  v_kind TEXT := lower(COALESCE(p_payload->>'kind', ''));
  v_party UUID := NULLIF(p_payload->>'party_id', '')::UUID;
  v_account UUID := NULLIF(p_payload->>'account_id', '')::UUID;
  v_ccy TEXT := upper(COALESCE(NULLIF(p_payload->>'currency_code', ''), 'PKR'));
  v_amount NUMERIC := COALESCE((p_payload->>'amount')::NUMERIC, 0);
  v_rate NUMERIC := NULLIF(p_payload->>'rate_used', '')::NUMERIC;
  v_as_of DATE := COALESCE((p_payload->>'as_of_date')::DATE, CURRENT_DATE);
  v_direction TEXT := lower(COALESCE(p_payload->>'direction', ''));
  v_memo TEXT := COALESCE(NULLIF(p_payload->>'memo', ''), 'Opening balance');
  v_op TEXT := NULLIF(TRIM(p_payload->>'client_operation_id'), '');
  v_party_row fx_parties;
  v_acct fx_accounts;
  v_primary UUID;
  v_equity UUID;
  v_pkr NUMERIC;
  v_tx UUID;
  v_line_kind fx_opening_balance_line_kind;
  v_code TEXT;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'OPENING_FORBIDDEN: missing can_post_fx_transaction';
  END IF;
  IF NOT fx_same_company(v_company) OR NOT fx_same_branch(v_branch) THEN
    RAISE EXCEPTION 'Unauthorized company/branch';
  END IF;
  IF v_amount IS NULL OR v_amount <= 0 THEN
    RAISE EXCEPTION 'Opening amount must be greater than zero';
  END IF;
  IF fx_is_day_closed(v_branch, v_as_of) THEN
    RAISE EXCEPTION 'OPENING_DATE_CLOSED: % is on a closed day', v_as_of;
  END IF;

  IF v_op IS NOT NULL THEN
    SELECT entity_id INTO v_tx FROM fx_client_operations
    WHERE company_id = v_company AND operation_key = v_op;
    IF v_tx IS NOT NULL THEN RETURN v_tx; END IF;
  END IF;

  v_equity := fx_account_id_by_code(v_company, '3000');
  IF v_equity IS NULL THEN
    RAISE EXCEPTION 'Equity account 3000 missing — cannot post opening';
  END IF;

  IF v_ccy = 'PKR' THEN
    v_rate := 1;
    v_pkr := round(v_amount, 8);
  ELSE
    IF v_rate IS NULL OR v_rate <= 0 THEN
      RAISE EXCEPTION 'RATE_REQUIRED: non-PKR opening needs explicit historical rate (PKR per 1 %)', v_ccy;
    END IF;
    v_pkr := round(v_amount * v_rate, 8);
  END IF;

  IF v_kind = 'party' THEN
    IF v_party IS NULL THEN RAISE EXCEPTION 'party_id required'; END IF;
    SELECT * INTO v_party_row FROM fx_parties WHERE id = v_party FOR UPDATE;
    IF NOT FOUND OR v_party_row.company_id IS DISTINCT FROM v_company THEN
      RAISE EXCEPTION 'Party not found for company';
    END IF;
    IF v_direction NOT IN ('party_owes_us', 'we_owe_party') THEN
      RAISE EXCEPTION 'direction must be party_owes_us or we_owe_party';
    END IF;
    v_line_kind := CASE
      WHEN v_direction = 'party_owes_us' THEN 'party_receivable'::fx_opening_balance_line_kind
      ELSE 'party_payable'::fx_opening_balance_line_kind
    END;
    v_code := fx_ob_party_account_code(v_party_row.party_type::TEXT, v_line_kind);
    IF v_code IS NULL THEN
      RAISE EXCEPTION 'Unsupported party type for opening';
    END IF;
    v_primary := fx_account_id_by_code(v_company, v_code);
  ELSIF v_kind = 'cash_bank' THEN
    IF v_account IS NULL THEN RAISE EXCEPTION 'account_id required'; END IF;
    SELECT * INTO v_acct FROM fx_accounts WHERE id = v_account FOR UPDATE;
    IF NOT FOUND OR v_acct.company_id IS DISTINCT FROM v_company THEN
      RAISE EXCEPTION 'Account not found for company';
    END IF;
    IF v_acct.account_type IS DISTINCT FROM 'asset'::fx_account_type THEN
      RAISE EXCEPTION 'Opening cash/bank must be an asset account';
    END IF;
    -- Negative physical cash not allowed; bank overdraft not supported in this path
    IF v_direction = 'overdraft' THEN
      RAISE EXCEPTION
        'OVERDRAFT_UNSUPPORTED: create a liability account via journal; cash/bank openings are non-negative only';
    END IF;
    v_line_kind := 'cash_bank'::fx_opening_balance_line_kind;
    v_primary := v_acct.id;
  ELSE
    RAISE EXCEPTION 'Unsupported opening kind %', v_kind;
  END IF;

  IF v_primary IS NULL THEN
    RAISE EXCEPTION 'Control account missing for opening';
  END IF;

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, description, currency_code, total_foreign_amount, rate_used,
    total_base_amount_pkr, notes, created_by
  ) VALUES (
    v_company, v_branch, 'opening_balance', 'draft', v_as_of,
    v_party,
    'Entity opening (start of ' || v_as_of::TEXT || ' PKT)',
    v_ccy, v_amount, v_rate, v_pkr, v_memo, auth.uid()
  ) RETURNING id INTO v_tx;

  IF v_line_kind IN ('cash_bank', 'party_receivable') THEN
    INSERT INTO fx_transaction_lines (
      transaction_id, line_no, account_id, currency_code,
      foreign_amount, rate_used, base_amount_pkr, debit_pkr, credit_pkr, memo
    ) VALUES
      (v_tx, 1, v_primary, v_ccy, v_amount, v_rate, v_pkr, v_pkr, 0, v_memo),
      (v_tx, 2, v_equity, 'PKR', v_pkr, 1, v_pkr, 0, v_pkr, v_memo);
  ELSE
    INSERT INTO fx_transaction_lines (
      transaction_id, line_no, account_id, currency_code,
      foreign_amount, rate_used, base_amount_pkr, debit_pkr, credit_pkr, memo
    ) VALUES
      (v_tx, 1, v_equity, 'PKR', v_pkr, 1, v_pkr, v_pkr, 0, v_memo),
      (v_tx, 2, v_primary, v_ccy, v_amount, v_rate, v_pkr, 0, v_pkr, v_memo);
  END IF;

  PERFORM fx_post_transaction(v_tx);

  IF v_op IS NOT NULL THEN
    INSERT INTO fx_client_operations (
      company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
    ) VALUES (
      v_company, v_op, 'entity_opening', 'fx_transaction', v_tx,
      jsonb_build_object('transaction_id', v_tx), auth.uid()
    ) ON CONFLICT (company_id, operation_key) DO NOTHING;
  END IF;

  RETURN v_tx;
END;
$$;

REVOKE ALL ON FUNCTION fx_post_entity_opening(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_post_entity_opening(JSONB) TO authenticated;

-- ---------------------------------------------------------------------------
-- 7) Create/update party with optional opening (atomic)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fx_upsert_party_profile(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID := NULLIF(p_payload->>'id', '')::UUID;
  v_company UUID;
  v_branch UUID;
  v_type TEXT := lower(COALESCE(p_payload->>'party_type', 'customer'));
  v_name TEXT := btrim(COALESCE(p_payload->>'name', ''));
  v_code TEXT;
  v_op TEXT := NULLIF(TRIM(p_payload->>'client_operation_id'), '');
  v_existing UUID;
  v_opening JSONB := p_payload->'opening';
  v_tx UUID;
  v_row fx_parties;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF v_name = '' THEN RAISE EXCEPTION 'Name is required'; END IF;
  IF v_type NOT IN ('customer', 'agent', 'supplier', 'settlement') THEN
    RAISE EXCEPTION 'Invalid party type';
  END IF;

  IF v_id IS NOT NULL THEN
    SELECT * INTO v_row FROM fx_parties WHERE id = v_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Party not found'; END IF;
    IF NOT fx_same_company(v_row.company_id) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
    v_company := v_row.company_id;
    v_branch := v_row.branch_id;

    UPDATE fx_parties SET
      name = v_name,
      contact_person = NULLIF(btrim(COALESCE(p_payload->>'contact_person', '')), ''),
      business_name = NULLIF(btrim(COALESCE(p_payload->>'business_name', '')), ''),
      phone = NULLIF(btrim(COALESCE(p_payload->>'phone_display', p_payload->>'phone', '')), ''),
      phone_display = NULLIF(btrim(COALESCE(p_payload->>'phone_display', p_payload->>'phone', '')), ''),
      phone_e164 = NULLIF(btrim(COALESCE(p_payload->>'phone_e164', '')), ''),
      phone2_display = NULLIF(btrim(COALESCE(p_payload->>'phone2_display', '')), ''),
      phone2_e164 = NULLIF(btrim(COALESCE(p_payload->>'phone2_e164', '')), ''),
      whatsapp_display = NULLIF(btrim(COALESCE(p_payload->>'whatsapp_display', '')), ''),
      whatsapp_e164 = NULLIF(btrim(COALESCE(p_payload->>'whatsapp_e164', '')), ''),
      email = NULLIF(btrim(COALESCE(p_payload->>'email', '')), ''),
      address_line1 = NULLIF(btrim(COALESCE(p_payload->>'address_line1', '')), ''),
      address_line2 = NULLIF(btrim(COALESCE(p_payload->>'address_line2', '')), ''),
      city = NULLIF(btrim(COALESCE(p_payload->>'city', '')), ''),
      province = NULLIF(btrim(COALESCE(p_payload->>'province', '')), ''),
      postal_code = NULLIF(btrim(COALESCE(p_payload->>'postal_code', '')), ''),
      country_code = NULLIF(upper(btrim(COALESCE(p_payload->>'country_code', ''))), ''),
      website = NULLIF(btrim(COALESCE(p_payload->>'website', '')), ''),
      notes = NULLIF(btrim(COALESCE(p_payload->>'notes', '')), ''),
      social_links = COALESCE(p_payload->'social_links', social_links),
      photo_attachment_id = COALESCE(
        NULLIF(p_payload->>'photo_attachment_id', '')::UUID,
        photo_attachment_id
      ),
      updated_at = NOW()
    WHERE id = v_id
    RETURNING * INTO v_row;
  ELSE
    v_company := (p_payload->>'company_id')::UUID;
    v_branch := (p_payload->>'branch_id')::UUID;
    IF v_company IS NULL OR v_branch IS NULL THEN
      RAISE EXCEPTION 'company_id and branch_id required';
    END IF;
    IF NOT fx_same_company(v_company) OR NOT fx_same_branch(v_branch) THEN
      RAISE EXCEPTION 'Unauthorized company/branch';
    END IF;

    IF v_op IS NOT NULL THEN
      SELECT entity_id INTO v_existing FROM fx_client_operations
      WHERE company_id = v_company AND operation_key = v_op;
      IF v_existing IS NOT NULL THEN
        SELECT * INTO v_row FROM fx_parties WHERE id = v_existing;
        RETURN jsonb_build_object(
          'party_id', v_row.id,
          'code', v_row.code,
          'opening_tx_id', NULL,
          'idempotent', TRUE
        );
      END IF;
    END IF;

    v_code := fx_allocate_party_code(
      v_company, v_type, NULLIF(btrim(COALESCE(p_payload->>'code', '')), '')
    );

    INSERT INTO fx_parties (
      company_id, branch_id, party_type, code, name,
      phone, phone_display, phone_e164, phone2_display, phone2_e164,
      whatsapp_display, whatsapp_e164, email,
      contact_person, business_name,
      address_line1, address_line2, city, province, postal_code, country_code,
      website, notes, social_links, photo_attachment_id
    ) VALUES (
      v_company, v_branch, v_type::fx_party_type, v_code, v_name,
      NULLIF(btrim(COALESCE(p_payload->>'phone_display', p_payload->>'phone', '')), ''),
      NULLIF(btrim(COALESCE(p_payload->>'phone_display', p_payload->>'phone', '')), ''),
      NULLIF(btrim(COALESCE(p_payload->>'phone_e164', '')), ''),
      NULLIF(btrim(COALESCE(p_payload->>'phone2_display', '')), ''),
      NULLIF(btrim(COALESCE(p_payload->>'phone2_e164', '')), ''),
      NULLIF(btrim(COALESCE(p_payload->>'whatsapp_display', '')), ''),
      NULLIF(btrim(COALESCE(p_payload->>'whatsapp_e164', '')), ''),
      NULLIF(btrim(COALESCE(p_payload->>'email', '')), ''),
      NULLIF(btrim(COALESCE(p_payload->>'contact_person', '')), ''),
      NULLIF(btrim(COALESCE(p_payload->>'business_name', '')), ''),
      NULLIF(btrim(COALESCE(p_payload->>'address_line1', '')), ''),
      NULLIF(btrim(COALESCE(p_payload->>'address_line2', '')), ''),
      NULLIF(btrim(COALESCE(p_payload->>'city', '')), ''),
      NULLIF(btrim(COALESCE(p_payload->>'province', '')), ''),
      NULLIF(btrim(COALESCE(p_payload->>'postal_code', '')), ''),
      NULLIF(upper(btrim(COALESCE(p_payload->>'country_code', ''))), ''),
      NULLIF(btrim(COALESCE(p_payload->>'website', '')), ''),
      NULLIF(btrim(COALESCE(p_payload->>'notes', '')), ''),
      COALESCE(p_payload->'social_links', '{}'::jsonb),
      NULLIF(p_payload->>'photo_attachment_id', '')::UUID
    ) RETURNING * INTO v_row;

    IF v_op IS NOT NULL THEN
      INSERT INTO fx_client_operations (
        company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
      ) VALUES (
        v_company, v_op, 'party_create', 'fx_party', v_row.id,
        jsonb_build_object('party_id', v_row.id, 'code', v_row.code), auth.uid()
      ) ON CONFLICT (company_id, operation_key) DO NOTHING;
    END IF;
  END IF;

  IF v_opening IS NOT NULL AND v_opening <> 'null'::jsonb
     AND COALESCE((v_opening->>'amount')::NUMERIC, 0) > 0 THEN
    BEGIN
      v_tx := fx_post_entity_opening(jsonb_build_object(
        'company_id', v_row.company_id,
        'branch_id', COALESCE(v_row.branch_id, (p_payload->>'branch_id')::UUID),
        'kind', 'party',
        'party_id', v_row.id,
        'currency_code', COALESCE(v_opening->>'currency_code', 'PKR'),
        'amount', v_opening->>'amount',
        'rate_used', v_opening->>'rate_used',
        'as_of_date', v_opening->>'as_of_date',
        'direction', v_opening->>'direction',
        'memo', COALESCE(v_opening->>'memo', 'Party opening'),
        'client_operation_id', CASE
          WHEN v_op IS NULL THEN NULL
          ELSE v_op || ':opening'
        END
      ));
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM ILIKE 'OPENING_FORBIDDEN%' THEN
        RAISE EXCEPTION
          'PARTY_CREATED_OPENING_PENDING: party % (%) saved without opening — %',
          v_row.code, v_row.id, SQLERRM;
      END IF;
      RAISE;
    END;
  END IF;

  RETURN jsonb_build_object(
    'party_id', v_row.id,
    'code', v_row.code,
    'opening_tx_id', v_tx,
    'idempotent', FALSE
  );
END;
$$;

REVOKE ALL ON FUNCTION fx_upsert_party_profile(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_upsert_party_profile(JSONB) TO authenticated;

-- ---------------------------------------------------------------------------
-- 8) Extend cash/bank create: structured fields + optional opening
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fx_create_cash_bank_account(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID, TEXT);

CREATE OR REPLACE FUNCTION fx_create_cash_bank_account(
  p_name TEXT,
  p_currency_code TEXT,
  p_kind TEXT,
  p_bank_name TEXT DEFAULT NULL,
  p_account_title TEXT DEFAULT NULL,
  p_account_identifier TEXT DEFAULT NULL,
  p_branch_id UUID DEFAULT NULL,
  p_code TEXT DEFAULT NULL,
  p_iban TEXT DEFAULT NULL,
  p_branch_name TEXT DEFAULT NULL,
  p_branch_code TEXT DEFAULT NULL,
  p_swift_bic TEXT DEFAULT NULL,
  p_metadata_notes TEXT DEFAULT NULL,
  p_opening JSONB DEFAULT NULL,
  p_client_operation_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_company UUID;
  v_branch UUID;
  v_parent UUID;
  v_currency UUID;
  v_code TEXT;
  v_kind TEXT := lower(COALESCE(p_kind, 'cash'));
  v_ccy TEXT := upper(COALESCE(NULLIF(btrim(p_currency_code), ''), 'PKR'));
  v_id UUID;
  v_slot INT;
  v_op TEXT := NULLIF(TRIM(p_client_operation_id), '');
  v_existing UUID;
  v_tx UUID;
  v_iban TEXT := NULLIF(btrim(COALESCE(p_iban, '')), '');
  v_acct_no TEXT := NULLIF(btrim(COALESCE(p_account_identifier, '')), '');
BEGIN
  IF NOT fx_has_permission('can_manage_fx_coa')
     AND NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT company_id, branch_id INTO v_company, v_branch
  FROM fx_user_active_workspace WHERE user_id = auth.uid();
  IF v_company IS NULL THEN
    SELECT company_id, branch_id INTO v_company, v_branch
    FROM fx_users_profiles WHERE id = auth.uid();
  END IF;
  IF p_branch_id IS NOT NULL THEN v_branch := p_branch_id; END IF;
  IF v_company IS NULL OR v_branch IS NULL THEN
    RAISE EXCEPTION 'No active company/branch';
  END IF;
  IF NOT fx_same_company(v_company) OR NOT fx_same_branch(v_branch) THEN
    RAISE EXCEPTION 'Unauthorized company/branch';
  END IF;

  IF v_op IS NOT NULL THEN
    SELECT entity_id INTO v_existing FROM fx_client_operations
    WHERE company_id = v_company AND operation_key = v_op;
    IF v_existing IS NOT NULL THEN
      RETURN jsonb_build_object(
        'account_id', v_existing,
        'code', (SELECT code FROM fx_accounts WHERE id = v_existing),
        'name', (SELECT name FROM fx_accounts WHERE id = v_existing),
        'currency_code', v_ccy,
        'idempotent', TRUE
      );
    END IF;
  END IF;

  IF length(btrim(COALESCE(p_name, ''))) < 2 THEN
    RAISE EXCEPTION 'Display name required';
  END IF;
  IF v_kind NOT IN ('cash', 'bank') THEN
    RAISE EXCEPTION 'kind must be cash or bank';
  END IF;

  SELECT id INTO v_currency FROM fx_currencies WHERE code = v_ccy LIMIT 1;
  v_parent := fx_account_id_by_code(v_company, '1000');
  IF v_parent IS NULL THEN
    RAISE EXCEPTION 'Parent cash/bank control 1000 missing';
  END IF;

  IF NULLIF(btrim(COALESCE(p_code, '')), '') IS NOT NULL THEN
    v_code := btrim(p_code);
    IF v_code ~ '^(1[0-9]{3})$' AND v_code IN (
      '1000','1110','1160','1170','1180','1190','2000','2100','2200','2310','2350','3000','4000','4100','4310','5000'
    ) THEN
      RAISE EXCEPTION 'RESERVED_CODE: % is a protected system account', v_code;
    END IF;
    IF EXISTS (SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = v_code) THEN
      RAISE EXCEPTION 'DUPLICATE_CODE: account code % already exists', v_code;
    END IF;
  ELSE
    IF v_kind = 'cash' THEN
      FOR v_slot IN 1110..1159 LOOP
        v_code := v_slot::TEXT;
        EXIT WHEN NOT EXISTS (
          SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = v_code
        );
        v_code := NULL;
      END LOOP;
      IF v_code IS NULL THEN
        FOR v_slot IN 1181..1189 LOOP
          v_code := v_slot::TEXT;
          EXIT WHEN NOT EXISTS (
            SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = v_code
          );
          v_code := NULL;
        END LOOP;
      END IF;
    ELSE
      FOR v_slot IN 1210..1299 LOOP
        v_code := v_slot::TEXT;
        EXIT WHEN NOT EXISTS (
          SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = v_code
        );
        v_code := NULL;
      END LOOP;
    END IF;
    IF v_code IS NULL THEN
      RAISE EXCEPTION 'No free cash/bank code slots remaining';
    END IF;
  END IF;

  IF v_iban IS NULL AND v_acct_no IS NOT NULL AND v_acct_no ~* '^[A-Z]{2}[0-9]{2}' THEN
    v_iban := v_acct_no;
    v_acct_no := NULL;
  END IF;

  INSERT INTO fx_accounts (
    company_id, branch_id, code, name, account_type, currency_id, parent_id, is_active,
    bank_name, account_title, account_number, iban, branch_name, branch_code, swift_bic, metadata_notes
  ) VALUES (
    v_company, v_branch, v_code, btrim(p_name), 'asset', v_currency, v_parent, TRUE,
    NULLIF(btrim(COALESCE(p_bank_name, '')), ''),
    NULLIF(btrim(COALESCE(p_account_title, '')), ''),
    v_acct_no,
    v_iban,
    NULLIF(btrim(COALESCE(p_branch_name, '')), ''),
    NULLIF(btrim(COALESCE(p_branch_code, '')), ''),
    NULLIF(btrim(COALESCE(p_swift_bic, '')), ''),
    NULLIF(btrim(COALESCE(p_metadata_notes, '')), '')
  ) RETURNING id INTO v_id;

  IF v_op IS NOT NULL THEN
    INSERT INTO fx_client_operations (
      company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
    ) VALUES (
      v_company, v_op, 'cash_bank_create', 'fx_account', v_id,
      jsonb_build_object('account_id', v_id, 'code', v_code), auth.uid()
    ) ON CONFLICT (company_id, operation_key) DO NOTHING;
  END IF;

  IF p_opening IS NOT NULL AND p_opening <> 'null'::jsonb
     AND COALESCE((p_opening->>'amount')::NUMERIC, 0) > 0 THEN
    BEGIN
      v_tx := fx_post_entity_opening(jsonb_build_object(
        'company_id', v_company,
        'branch_id', v_branch,
        'kind', 'cash_bank',
        'account_id', v_id,
        'currency_code', COALESCE(p_opening->>'currency_code', v_ccy),
        'amount', p_opening->>'amount',
        'rate_used', p_opening->>'rate_used',
        'as_of_date', p_opening->>'as_of_date',
        'direction', COALESCE(p_opening->>'direction', 'asset'),
        'memo', COALESCE(p_opening->>'memo', 'Cash/bank opening'),
        'client_operation_id', CASE WHEN v_op IS NULL THEN NULL ELSE v_op || ':opening' END
      ));
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM ILIKE 'OPENING_FORBIDDEN%' THEN
        RAISE EXCEPTION
          'ACCOUNT_CREATED_OPENING_PENDING: account % (%) saved without opening — %',
          v_code, v_id, SQLERRM;
      END IF;
      RAISE;
    END;
  END IF;

  RETURN jsonb_build_object(
    'account_id', v_id,
    'code', v_code,
    'name', btrim(p_name),
    'currency_code', v_ccy,
    'opening_tx_id', v_tx,
    'idempotent', FALSE
  );
END;
$$;

REVOKE ALL ON FUNCTION fx_create_cash_bank_account(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_create_cash_bank_account(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT
) TO authenticated;

-- Keep older 8-arg signature working by wrapper if PostgREST still sees overload —
-- drop prior shorter overload if present after recreate.
DO $$
BEGIN
  -- Best-effort: drop old 8-parameter variant if it exists separately
  BEGIN
    EXECUTE $q$
      DROP FUNCTION IF EXISTS fx_create_cash_bank_account(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID, TEXT)
    $q$;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END $$;

NOTIFY pgrst, 'reload schema';
