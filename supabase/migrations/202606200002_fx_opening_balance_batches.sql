-- Opening balance batch workflow — draft wizard, RPC post, branch lock
-- Project: ygidlcqhupmxvsdjmvnf only (fx_* tables). Do not apply without approval.

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

CREATE TYPE fx_opening_balance_batch_status AS ENUM ('draft', 'posted', 'voided');

CREATE TYPE fx_opening_balance_line_kind AS ENUM (
  'cash_bank',
  'currency_position',
  'party_receivable',
  'party_payable'
);

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

CREATE TABLE fx_opening_balance_batches (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id          UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id           UUID NOT NULL REFERENCES fx_branches (id) ON DELETE RESTRICT,
  batch_no            TEXT,
  opening_date        DATE NOT NULL DEFAULT CURRENT_DATE,
  base_currency_code  TEXT NOT NULL DEFAULT 'PKR',
  status              fx_opening_balance_batch_status NOT NULL DEFAULT 'draft',
  description         TEXT,
  notes               TEXT,
  total_debit_pkr     NUMERIC(20, 8) NOT NULL DEFAULT 0,
  total_credit_pkr    NUMERIC(20, 8) NOT NULL DEFAULT 0,
  equity_account_id   UUID REFERENCES fx_accounts (id) ON DELETE RESTRICT,
  posted_at           TIMESTAMPTZ,
  posted_by           UUID REFERENCES auth.users (id),
  voided_at           TIMESTAMPTZ,
  voided_by           UUID REFERENCES auth.users (id),
  void_reason         TEXT,
  created_by          UUID REFERENCES auth.users (id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_fx_ob_batches_one_posted_per_branch
  ON fx_opening_balance_batches (branch_id)
  WHERE status = 'posted';

CREATE INDEX idx_fx_ob_batches_branch_status ON fx_opening_balance_batches (branch_id, status);

CREATE TABLE fx_opening_balance_lines (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id        UUID NOT NULL REFERENCES fx_opening_balance_batches (id) ON DELETE CASCADE,
  line_no         INT NOT NULL,
  line_kind       fx_opening_balance_line_kind NOT NULL,
  account_id      UUID REFERENCES fx_accounts (id) ON DELETE RESTRICT,
  party_id        UUID REFERENCES fx_parties (id) ON DELETE RESTRICT,
  currency_code   TEXT NOT NULL DEFAULT 'PKR',
  foreign_amount  NUMERIC(20, 8) NOT NULL DEFAULT 0,
  rate_used       NUMERIC(20, 8) NOT NULL DEFAULT 1,
  pkr_amount      NUMERIC(20, 8) NOT NULL DEFAULT 0,
  location_label  TEXT,
  memo            TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (batch_id, line_no)
);

ALTER TABLE fx_transactions
  ADD COLUMN IF NOT EXISTS opening_balance_batch_id UUID
    REFERENCES fx_opening_balance_batches (id) ON DELETE RESTRICT;

CREATE INDEX idx_fx_transactions_ob_batch ON fx_transactions (opening_balance_batch_id)
  WHERE opening_balance_batch_id IS NOT NULL;

ALTER TABLE fx_branches
  ADD COLUMN IF NOT EXISTS opening_balance_posted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS opening_balance_batch_id UUID
    REFERENCES fx_opening_balance_batches (id) ON DELETE SET NULL;

CREATE TRIGGER trg_fx_ob_batches_updated_at
  BEFORE UPDATE ON fx_opening_balance_batches
  FOR EACH ROW EXECUTE FUNCTION fx_set_updated_at();

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_generate_opening_balance_batch_no(p_branch_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seq INT;
BEGIN
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  SELECT COALESCE(MAX(
    NULLIF(regexp_replace(batch_no, '\D', '', 'g'), '')::INT
  ), 0) + 1
  INTO v_seq
  FROM fx_opening_balance_batches
  WHERE branch_id = p_branch_id;

  RETURN 'OB-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(v_seq::TEXT, 4, '0');
END;
$$;

CREATE OR REPLACE FUNCTION fx_ob_line_debit_pkr(p_kind fx_opening_balance_line_kind, p_pkr NUMERIC)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_kind IN ('cash_bank', 'currency_position', 'party_receivable') THEN p_pkr
    WHEN p_kind = 'party_payable' THEN p_pkr
    ELSE 0
  END;
$$;

CREATE OR REPLACE FUNCTION fx_ob_line_credit_pkr(p_kind fx_opening_balance_line_kind, p_pkr NUMERIC)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_kind IN ('cash_bank', 'currency_position', 'party_receivable') THEN p_pkr
    WHEN p_kind = 'party_payable' THEN p_pkr
    ELSE 0
  END;
$$;

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
      ELSE NULL
    END;
  END IF;
  IF p_kind = 'party_payable' THEN
    RETURN CASE p_party_type
      WHEN 'customer' THEN '2200'
      WHEN 'agent' THEN '2100'
      ELSE NULL
    END;
  END IF;
  RETURN NULL;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_get_opening_balance_status
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_opening_balance_status(p_branch_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_batch fx_opening_balance_batches;
  v_lines JSONB;
BEGIN
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  SELECT * INTO v_batch
  FROM fx_opening_balance_batches
  WHERE branch_id = p_branch_id
    AND status IN ('draft', 'posted')
  ORDER BY CASE status WHEN 'posted' THEN 0 ELSE 1 END, created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'missing', 'batch', NULL, 'lines', '[]'::JSONB);
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', l.id,
      'line_no', l.line_no,
      'line_kind', l.line_kind,
      'account_id', l.account_id,
      'party_id', l.party_id,
      'currency_code', l.currency_code,
      'foreign_amount', l.foreign_amount,
      'rate_used', l.rate_used,
      'pkr_amount', l.pkr_amount,
      'location_label', l.location_label,
      'memo', l.memo
    ) ORDER BY l.line_no
  ), '[]'::JSONB)
  INTO v_lines
  FROM fx_opening_balance_lines l
  WHERE l.batch_id = v_batch.id;

  RETURN jsonb_build_object(
    'status', v_batch.status::TEXT,
    'batch', jsonb_build_object(
      'id', v_batch.id,
      'batch_no', v_batch.batch_no,
      'company_id', v_batch.company_id,
      'branch_id', v_batch.branch_id,
      'opening_date', v_batch.opening_date,
      'base_currency_code', v_batch.base_currency_code,
      'description', v_batch.description,
      'notes', v_batch.notes,
      'total_debit_pkr', v_batch.total_debit_pkr,
      'total_credit_pkr', v_batch.total_credit_pkr,
      'equity_account_id', v_batch.equity_account_id,
      'posted_at', v_batch.posted_at,
      'created_at', v_batch.created_at
    ),
    'lines', v_lines
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_save_opening_balance_batch
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_save_opening_balance_batch(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_batch_id UUID := NULLIF(p_payload->>'batch_id', '')::UUID;
  v_company_id UUID := (p_payload->>'company_id')::UUID;
  v_branch_id UUID := (p_payload->>'branch_id')::UUID;
  v_opening_date DATE := COALESCE((p_payload->>'opening_date')::DATE, CURRENT_DATE);
  v_base_currency TEXT := COALESCE(NULLIF(p_payload->>'base_currency_code', ''), 'PKR');
  v_description TEXT := NULLIF(p_payload->>'description', '');
  v_notes TEXT := NULLIF(p_payload->>'notes', '');
  v_equity_id UUID;
  v_batch fx_opening_balance_batches;
  v_line JSONB;
  v_line_no INT;
  v_kind fx_opening_balance_line_kind;
  v_pkr NUMERIC(20, 8);
  v_total_debit NUMERIC(20, 8) := 0;
  v_total_credit NUMERIC(20, 8) := 0;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Missing permission: can_access_fx_ledger';
  END IF;
  IF NOT fx_same_branch(v_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  v_equity_id := COALESCE(
    NULLIF(p_payload->>'equity_account_id', '')::UUID,
    fx_account_id_by_code(v_company_id, '3100')
  );

  IF v_equity_id IS NULL THEN
    RAISE EXCEPTION 'Owner Capital account (3100) not found';
  END IF;

  IF v_batch_id IS NOT NULL THEN
    SELECT * INTO v_batch FROM fx_opening_balance_batches WHERE id = v_batch_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Batch not found'; END IF;
    IF v_batch.status <> 'draft' THEN
      RAISE EXCEPTION 'Only draft batches can be edited';
    END IF;
    IF v_batch.branch_id <> v_branch_id THEN
      RAISE EXCEPTION 'Branch mismatch';
    END IF;
  ELSE
    IF EXISTS (
      SELECT 1 FROM fx_opening_balance_batches
      WHERE branch_id = v_branch_id AND status = 'posted'
    ) THEN
      RAISE EXCEPTION 'Opening balance already posted for this branch. Admin must void before creating a new batch.';
    END IF;

    INSERT INTO fx_opening_balance_batches (
      company_id, branch_id, batch_no, opening_date, base_currency_code,
      status, description, notes, equity_account_id, created_by
    ) VALUES (
      v_company_id, v_branch_id, fx_generate_opening_balance_batch_no(v_branch_id),
      v_opening_date, v_base_currency, 'draft', v_description, v_notes,
      v_equity_id, auth.uid()
    )
    RETURNING * INTO v_batch;
    v_batch_id := v_batch.id;
  END IF;

  UPDATE fx_opening_balance_batches
  SET
    opening_date = v_opening_date,
    base_currency_code = v_base_currency,
    description = v_description,
    notes = v_notes,
    equity_account_id = v_equity_id,
    updated_at = NOW()
  WHERE id = v_batch_id;

  DELETE FROM fx_opening_balance_lines WHERE batch_id = v_batch_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(COALESCE(p_payload->'lines', '[]'::JSONB))
  LOOP
    v_line_no := COALESCE((v_line->>'line_no')::INT, 0);
    v_kind := (v_line->>'line_kind')::fx_opening_balance_line_kind;
    v_pkr := COALESCE((v_line->>'pkr_amount')::NUMERIC, 0);

    IF v_pkr <= 0 THEN
      RAISE EXCEPTION 'Line %: pkr_amount must be positive', v_line_no;
    END IF;

    v_total_debit := v_total_debit + fx_ob_line_debit_pkr(v_kind, v_pkr);
    v_total_credit := v_total_credit + fx_ob_line_credit_pkr(v_kind, v_pkr);

    INSERT INTO fx_opening_balance_lines (
      batch_id, line_no, line_kind, account_id, party_id,
      currency_code, foreign_amount, rate_used, pkr_amount, location_label, memo
    ) VALUES (
      v_batch_id,
      v_line_no,
      v_kind,
      NULLIF(v_line->>'account_id', '')::UUID,
      NULLIF(v_line->>'party_id', '')::UUID,
      COALESCE(NULLIF(v_line->>'currency_code', ''), 'PKR'),
      COALESCE((v_line->>'foreign_amount')::NUMERIC, 0),
      COALESCE((v_line->>'rate_used')::NUMERIC, 1),
      v_pkr,
      NULLIF(v_line->>'location_label', ''),
      NULLIF(v_line->>'memo', '')
    );
  END LOOP;

  UPDATE fx_opening_balance_batches
  SET total_debit_pkr = v_total_debit, total_credit_pkr = v_total_credit
  WHERE id = v_batch_id;

  RETURN fx_get_opening_balance_status(v_branch_id);
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_post_opening_balance_batch — create & post opening_balance transactions
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_post_opening_balance_batch(p_batch_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_batch fx_opening_balance_batches;
  v_line RECORD;
  v_tx_id UUID;
  v_party fx_parties;
  v_primary_account UUID;
  v_account_code TEXT;
  v_equity UUID;
  v_memo TEXT;
  v_desc TEXT;
  v_rate NUMERIC(20, 8);
  v_fc NUMERIC(20, 8);
  v_pkr NUMERIC(20, 8);
  v_tx_count INT := 0;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_post_fx_transaction';
  END IF;

  SELECT * INTO v_batch FROM fx_opening_balance_batches WHERE id = p_batch_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Batch not found'; END IF;
  IF NOT fx_same_branch(v_batch.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;
  IF v_batch.status <> 'draft' THEN RAISE EXCEPTION 'Only draft batches can be posted'; END IF;

  IF EXISTS (
    SELECT 1 FROM fx_opening_balance_batches
    WHERE branch_id = v_batch.branch_id AND status = 'posted' AND id <> p_batch_id
  ) THEN
    RAISE EXCEPTION 'Opening balance already posted for this branch';
  END IF;

  IF v_batch.total_debit_pkr <> v_batch.total_credit_pkr OR v_batch.total_debit_pkr = 0 THEN
    RAISE EXCEPTION 'Batch not balanced: debit=% credit=%',
      v_batch.total_debit_pkr, v_batch.total_credit_pkr;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM fx_opening_balance_lines WHERE batch_id = p_batch_id) THEN
    RAISE EXCEPTION 'Batch has no lines';
  END IF;

  IF fx_is_day_closed(v_batch.branch_id, v_batch.opening_date) THEN
    RAISE EXCEPTION 'Opening date is on a closed day';
  END IF;

  v_equity := v_batch.equity_account_id;

  FOR v_line IN
    SELECT * FROM fx_opening_balance_lines WHERE batch_id = p_batch_id ORDER BY line_no
  LOOP
    v_pkr := v_line.pkr_amount;
    v_fc := v_line.foreign_amount;
    v_rate := v_line.rate_used;
    v_memo := COALESCE(v_line.memo, 'Opening balance');
    v_primary_account := v_line.account_id;

    IF v_line.line_kind IN ('party_receivable', 'party_payable') THEN
      IF v_line.party_id IS NULL THEN
        RAISE EXCEPTION 'Line %: party_id required', v_line.line_no;
      END IF;
      SELECT * INTO v_party FROM fx_parties WHERE id = v_line.party_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'Party not found for line %', v_line.line_no; END IF;

      v_account_code := fx_ob_party_account_code(v_party.party_type::TEXT, v_line.line_kind);
      IF v_account_code IS NULL THEN
        RAISE EXCEPTION 'Unsupported party type for line %', v_line.line_no;
      END IF;
      v_primary_account := fx_account_id_by_code(v_batch.company_id, v_account_code);
      IF v_primary_account IS NULL THEN
        RAISE EXCEPTION 'Account % not found', v_account_code;
      END IF;
    ELSE
      IF v_primary_account IS NULL THEN
        RAISE EXCEPTION 'Line %: account_id required', v_line.line_no;
      END IF;
    END IF;

    v_desc := COALESCE(
      v_batch.description,
      'Opening balance — ' || replace(v_line.line_kind::TEXT, '_', ' ')
    );

    INSERT INTO fx_transactions (
      company_id, branch_id, transaction_type, status, transaction_date,
      party_id, description, currency_code, total_foreign_amount, rate_used,
      total_base_amount_pkr, notes, opening_balance_batch_id, created_by
    ) VALUES (
      v_batch.company_id, v_batch.branch_id, 'opening_balance', 'draft',
      v_batch.opening_date,
      v_line.party_id,
      v_desc,
      v_line.currency_code,
      v_fc,
      v_rate,
      v_pkr,
      COALESCE(v_line.location_label, v_batch.notes),
      p_batch_id,
      auth.uid()
    )
    RETURNING id INTO v_tx_id;

    IF v_line.line_kind IN ('cash_bank', 'currency_position', 'party_receivable') THEN
      INSERT INTO fx_transaction_lines (
        transaction_id, line_no, account_id, currency_code,
        foreign_amount, rate_used, base_amount_pkr, debit_pkr, credit_pkr, memo
      ) VALUES
        (v_tx_id, 1, v_primary_account, v_line.currency_code, v_fc, v_rate, v_pkr, v_pkr, 0, v_memo),
        (v_tx_id, 2, v_equity, 'PKR', v_pkr, 1, v_pkr, 0, v_pkr, v_memo);
    ELSE
      INSERT INTO fx_transaction_lines (
        transaction_id, line_no, account_id, currency_code,
        foreign_amount, rate_used, base_amount_pkr, debit_pkr, credit_pkr, memo
      ) VALUES
        (v_tx_id, 1, v_equity, 'PKR', v_pkr, 1, v_pkr, v_pkr, 0, v_memo),
        (v_tx_id, 2, v_primary_account, v_line.currency_code, v_fc, v_rate, v_pkr, 0, v_pkr, v_memo);
    END IF;

    PERFORM fx_post_transaction(v_tx_id);
    v_tx_count := v_tx_count + 1;
  END LOOP;

  UPDATE fx_opening_balance_batches
  SET status = 'posted', posted_at = NOW(), posted_by = auth.uid()
  WHERE id = p_batch_id;

  UPDATE fx_branches
  SET opening_balance_posted_at = NOW(), opening_balance_batch_id = p_batch_id
  WHERE id = v_batch.branch_id;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, new_value, actor_id)
  VALUES (
    v_batch.company_id, v_batch.branch_id, 'fx_opening_balance_batches', p_batch_id, 'posted',
    jsonb_build_object('batch_id', p_batch_id, 'transactions_posted', v_tx_count),
    auth.uid()
  );

  RETURN fx_get_opening_balance_status(v_batch.branch_id);
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_void_opening_balance_batch — admin void linked transactions
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_void_opening_balance_batch(p_batch_id UUID, p_reason TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_batch fx_opening_balance_batches;
  v_tx RECORD;
BEGIN
  IF NOT fx_has_permission('can_delete_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_delete_fx_transaction';
  END IF;
  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required';
  END IF;

  SELECT * INTO v_batch FROM fx_opening_balance_batches WHERE id = p_batch_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Batch not found'; END IF;
  IF NOT fx_same_branch(v_batch.branch_id) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF v_batch.status <> 'posted' THEN
    RAISE EXCEPTION 'Only posted batches can be voided';
  END IF;

  FOR v_tx IN
    SELECT id FROM fx_transactions
    WHERE opening_balance_batch_id = p_batch_id AND status = 'posted' AND NOT is_deleted
  LOOP
    PERFORM fx_delete_transaction(v_tx.id, p_reason);
  END LOOP;

  UPDATE fx_opening_balance_batches
  SET status = 'voided', voided_at = NOW(), voided_by = auth.uid(), void_reason = p_reason
  WHERE id = p_batch_id;

  UPDATE fx_branches
  SET opening_balance_posted_at = NULL, opening_balance_batch_id = NULL
  WHERE id = v_batch.branch_id AND opening_balance_batch_id = p_batch_id;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, reason, actor_id)
  VALUES (v_batch.company_id, v_batch.branch_id, 'fx_opening_balance_batches', p_batch_id, 'voided', p_reason, auth.uid());

  RETURN fx_get_opening_balance_status(v_batch.branch_id);
END;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE fx_opening_balance_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_opening_balance_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY fx_ob_batches_select ON fx_opening_balance_batches
  FOR SELECT TO authenticated
  USING (fx_same_branch(branch_id) AND fx_has_permission('can_access_fx_ledger'));

CREATE POLICY fx_ob_batches_insert_draft ON fx_opening_balance_batches
  FOR INSERT TO authenticated
  WITH CHECK (
    fx_same_branch(branch_id)
    AND fx_has_permission('can_access_fx_ledger')
    AND status = 'draft'
  );

CREATE POLICY fx_ob_batches_update_draft ON fx_opening_balance_batches
  FOR UPDATE TO authenticated
  USING (fx_same_branch(branch_id) AND status = 'draft' AND fx_has_permission('can_access_fx_ledger'))
  WITH CHECK (fx_same_branch(branch_id) AND status = 'draft');

CREATE POLICY fx_ob_lines_select ON fx_opening_balance_lines
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM fx_opening_balance_batches b
      WHERE b.id = batch_id
        AND fx_same_branch(b.branch_id)
        AND fx_has_permission('can_access_fx_ledger')
    )
  );

CREATE POLICY fx_ob_lines_write_draft ON fx_opening_balance_lines
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM fx_opening_balance_batches b
      WHERE b.id = batch_id AND b.status = 'draft' AND fx_same_branch(b.branch_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM fx_opening_balance_batches b
      WHERE b.id = batch_id AND b.status = 'draft' AND fx_same_branch(b.branch_id)
    )
  );

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

GRANT EXECUTE ON FUNCTION fx_generate_opening_balance_batch_no(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_opening_balance_status(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_save_opening_balance_batch(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_post_opening_balance_batch(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_void_opening_balance_batch(UUID, TEXT) TO authenticated;
