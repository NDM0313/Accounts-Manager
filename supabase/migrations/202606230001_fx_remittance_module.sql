-- PROPOSAL ONLY — do not apply without explicit approval.
-- Cloud project: ygidlcqhupmxvsdjmvnf (NOT supabase.dincouture.pk, NOT old ERP VPS)
-- FX Remittance / Hawala module — tables, enums, COA, RLS, basic RPCs

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE fx_remittance_status AS ENUM (
    'draft', 'booked', 'customer_paid', 'sent_to_agent', 'ready_for_payout',
    'paid_out', 'cancelled', 'refunded', 'disputed', 'completed'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE fx_remittance_settlement_status AS ENUM (
    'pending', 'partial', 'settled'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE fx_remittance_event_type AS ENUM (
    'created', 'customer_payment', 'sent_to_agent', 'payout_confirmed',
    'agent_settlement', 'refund', 'note', 'status_change'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE fx_remittance_tx_purpose AS ENUM (
    'customer_payment', 'agent_payout', 'agent_settlement', 'refund', 'commission'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fx_remittances (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id              UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id               UUID NOT NULL REFERENCES fx_branches (id) ON DELETE RESTRICT,
  remittance_no           TEXT,
  tracking_id             TEXT NOT NULL,
  sender_party_id         UUID NOT NULL REFERENCES fx_parties (id) ON DELETE RESTRICT,
  receiver_name           TEXT NOT NULL,
  receiver_phone          TEXT,
  receiver_city           TEXT,
  receiver_country        TEXT,
  payout_agent_party_id   UUID REFERENCES fx_parties (id) ON DELETE RESTRICT,
  receive_currency        TEXT NOT NULL,
  receive_amount          NUMERIC(20, 8) NOT NULL,
  payout_currency         TEXT NOT NULL,
  payout_amount           NUMERIC(20, 8) NOT NULL,
  exchange_rate           NUMERIC(20, 8) NOT NULL DEFAULT 1,
  commission_amount       NUMERIC(20, 8) NOT NULL DEFAULT 0,
  total_payable           NUMERIC(20, 8) NOT NULL,
  paid_amount             NUMERIC(20, 8) NOT NULL DEFAULT 0,
  status                  fx_remittance_status NOT NULL DEFAULT 'draft',
  payout_status           TEXT NOT NULL DEFAULT 'pending'
    CHECK (payout_status IN ('pending', 'partial', 'paid')),
  settlement_status       fx_remittance_settlement_status NOT NULL DEFAULT 'pending',
  notes                   TEXT,
  booked_at               TIMESTAMPTZ,
  completed_at            TIMESTAMPTZ,
  cancelled_at            TIMESTAMPTZ,
  created_by              UUID REFERENCES auth.users (id),
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (branch_id, remittance_no),
  UNIQUE (branch_id, tracking_id)
);

CREATE INDEX IF NOT EXISTS idx_fx_remittances_branch_status ON fx_remittances (branch_id, status);
CREATE INDEX IF NOT EXISTS idx_fx_remittances_sender ON fx_remittances (sender_party_id);
CREATE INDEX IF NOT EXISTS idx_fx_remittances_agent ON fx_remittances (payout_agent_party_id);

CREATE TABLE IF NOT EXISTS fx_remittance_events (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  remittance_id           UUID NOT NULL REFERENCES fx_remittances (id) ON DELETE CASCADE,
  event_no                INT NOT NULL,
  event_type              fx_remittance_event_type NOT NULL,
  status_after            fx_remittance_status,
  amount                  NUMERIC(20, 8),
  currency_code           TEXT,
  linked_transaction_id   UUID REFERENCES fx_transactions (id) ON DELETE SET NULL,
  proof_reference         TEXT,
  notes                   TEXT,
  created_by              UUID REFERENCES auth.users (id),
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (remittance_id, event_no)
);

CREATE TABLE IF NOT EXISTS fx_remittance_transactions (
  remittance_id           UUID NOT NULL REFERENCES fx_remittances (id) ON DELETE CASCADE,
  transaction_id          UUID NOT NULL REFERENCES fx_transactions (id) ON DELETE RESTRICT,
  purpose                 fx_remittance_tx_purpose NOT NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (remittance_id, transaction_id)
);

ALTER TABLE fx_transactions
  ADD COLUMN IF NOT EXISTS remittance_id UUID REFERENCES fx_remittances (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_fx_transactions_remittance ON fx_transactions (remittance_id);

-- ---------------------------------------------------------------------------
-- COA: Remittance Liability + Commission Income (per company, idempotent)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_seed_remittance_coa(p_company_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_liabilities UUID;
  v_income UUID;
BEGIN
  SELECT id INTO v_liabilities FROM fx_accounts
  WHERE company_id = p_company_id AND code = '2300' LIMIT 1;
  SELECT id INTO v_income FROM fx_accounts
  WHERE company_id = p_company_id AND code = '4000' LIMIT 1;

  IF v_liabilities IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM fx_accounts WHERE company_id = p_company_id AND code = '2350'
  ) THEN
    INSERT INTO fx_accounts (company_id, code, name, account_type, parent_id, is_active)
    VALUES (p_company_id, '2350', 'Remittance Liability', 'liability', v_liabilities, TRUE);
  END IF;

  IF v_income IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM fx_accounts WHERE company_id = p_company_id AND code = '4310'
  ) THEN
    INSERT INTO fx_accounts (company_id, code, name, account_type, parent_id, is_active)
    VALUES (p_company_id, '4310', 'Remittance Commission Income', 'income', v_income, TRUE);
  END IF;
END;
$$;

-- Seed for default demo company
SELECT fx_seed_remittance_coa('00000000-0000-4000-8000-000000000001');

-- ---------------------------------------------------------------------------
-- Number sequence
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_generate_remittance_no(p_branch_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_date TEXT := to_char(NOW() AT TIME ZONE 'UTC', 'YYYYMMDD');
  v_seq INT;
BEGIN
  SELECT COALESCE(MAX(
    NULLIF(regexp_replace(remittance_no, '^RM-' || v_date || '-', ''), remittance_no)::INT
  ), 0) + 1 INTO v_seq
  FROM fx_remittances
  WHERE branch_id = p_branch_id
    AND remittance_no LIKE 'RM-' || v_date || '-%';

  RETURN 'RM-' || v_date || '-' || lpad(v_seq::TEXT, 4, '0');
END;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE fx_remittances ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_remittance_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_remittance_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fx_remittances_select ON fx_remittances;
CREATE POLICY fx_remittances_select ON fx_remittances
  FOR SELECT TO authenticated
  USING (fx_same_branch(branch_id));

DROP POLICY IF EXISTS fx_remittances_insert ON fx_remittances;
CREATE POLICY fx_remittances_insert ON fx_remittances
  FOR INSERT TO authenticated
  WITH CHECK (fx_same_branch(branch_id));

DROP POLICY IF EXISTS fx_remittances_update ON fx_remittances;
CREATE POLICY fx_remittances_update ON fx_remittances
  FOR UPDATE TO authenticated
  USING (fx_same_branch(branch_id));

DROP POLICY IF EXISTS fx_remittance_events_select ON fx_remittance_events;
CREATE POLICY fx_remittance_events_select ON fx_remittance_events
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM fx_remittances r WHERE r.id = remittance_id AND fx_same_branch(r.branch_id)
  ));

DROP POLICY IF EXISTS fx_remittance_events_insert ON fx_remittance_events;
CREATE POLICY fx_remittance_events_insert ON fx_remittance_events
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM fx_remittances r WHERE r.id = remittance_id AND fx_same_branch(r.branch_id)
  ));

DROP POLICY IF EXISTS fx_remittance_tx_select ON fx_remittance_transactions;
CREATE POLICY fx_remittance_tx_select ON fx_remittance_transactions
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM fx_remittances r WHERE r.id = remittance_id AND fx_same_branch(r.branch_id)
  ));

-- ---------------------------------------------------------------------------
-- Permissions (additive)
-- ---------------------------------------------------------------------------

UPDATE fx_roles SET permissions = array_append(permissions, 'can_manage_remittance')
WHERE name IN ('admin', 'manager')
  AND NOT ('can_manage_remittance' = ANY (permissions));

UPDATE fx_roles SET permissions = array_append(permissions, 'can_view_remittance_reports')
WHERE name IN ('admin', 'manager', 'auditor')
  AND NOT ('can_view_remittance_reports' = ANY (permissions));

-- ---------------------------------------------------------------------------
-- fx_create_remittance
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_create_remittance(
  p_branch_id UUID,
  p_sender_party_id UUID,
  p_receiver_name TEXT,
  p_receiver_phone TEXT DEFAULT NULL,
  p_receiver_city TEXT DEFAULT NULL,
  p_receiver_country TEXT DEFAULT NULL,
  p_payout_agent_party_id UUID DEFAULT NULL,
  p_receive_currency TEXT DEFAULT 'PKR',
  p_receive_amount NUMERIC DEFAULT 0,
  p_payout_currency TEXT DEFAULT 'PKR',
  p_payout_amount NUMERIC DEFAULT 0,
  p_exchange_rate NUMERIC DEFAULT 1,
  p_commission_amount NUMERIC DEFAULT 0,
  p_notes TEXT DEFAULT NULL,
  p_book_immediately BOOLEAN DEFAULT TRUE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_id UUID;
  v_no TEXT;
  v_total NUMERIC(20, 8);
  v_status fx_remittance_status;
BEGIN
  IF NOT fx_has_permission('can_manage_remittance') AND NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_profile FROM fx_current_profile();
  IF NOT FOUND OR v_profile.branch_id <> p_branch_id THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;
  IF p_receive_amount <= 0 OR p_payout_amount <= 0 THEN
    RAISE EXCEPTION 'Receive and payout amounts must be positive';
  END IF;

  PERFORM fx_seed_remittance_coa(v_profile.company_id);

  v_total := p_receive_amount + COALESCE(p_commission_amount, 0);
  v_no := fx_generate_remittance_no(p_branch_id);
  v_status := CASE WHEN p_book_immediately THEN 'booked'::fx_remittance_status ELSE 'draft'::fx_remittance_status END;

  INSERT INTO fx_remittances (
    company_id, branch_id, remittance_no, tracking_id, sender_party_id,
    receiver_name, receiver_phone, receiver_city, receiver_country,
    payout_agent_party_id, receive_currency, receive_amount, payout_currency, payout_amount,
    exchange_rate, commission_amount, total_payable, status, notes, booked_at, created_by
  ) VALUES (
    v_profile.company_id, p_branch_id, v_no, v_no, p_sender_party_id,
    p_receiver_name, p_receiver_phone, p_receiver_city, p_receiver_country,
    p_payout_agent_party_id, upper(p_receive_currency), p_receive_amount,
    upper(p_payout_currency), p_payout_amount, p_exchange_rate, p_commission_amount,
    v_total, v_status, p_notes,
    CASE WHEN p_book_immediately THEN NOW() ELSE NULL END,
    auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, notes, created_by
  ) VALUES (
    v_id, 1, 'created', v_status, p_notes, auth.uid()
  );

  RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_list_remittances / fx_get_remittance_timeline
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_list_remittances(
  p_branch_id UUID,
  p_open_only BOOLEAN DEFAULT FALSE
)
RETURNS SETOF fx_remittances
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT r.*
  FROM fx_remittances r
  WHERE r.branch_id = p_branch_id
    AND fx_same_branch(p_branch_id)
    AND (NOT p_open_only OR r.status NOT IN ('completed', 'cancelled', 'refunded'))
  ORDER BY r.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION fx_get_remittance_timeline(p_remittance_id UUID)
RETURNS TABLE (
  event_id UUID,
  event_no INT,
  event_type fx_remittance_event_type,
  status_after fx_remittance_status,
  amount NUMERIC,
  currency_code TEXT,
  linked_transaction_id UUID,
  proof_reference TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT e.id, e.event_no, e.event_type, e.status_after, e.amount, e.currency_code,
         e.linked_transaction_id, e.proof_reference, e.notes, e.created_at
  FROM fx_remittance_events e
  JOIN fx_remittances r ON r.id = e.remittance_id
  WHERE e.remittance_id = p_remittance_id
    AND fx_same_branch(r.branch_id)
  ORDER BY e.event_no;
$$;

GRANT EXECUTE ON FUNCTION fx_generate_remittance_no(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_seed_remittance_coa(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_create_remittance(UUID, UUID, TEXT, TEXT, TEXT, TEXT, UUID, TEXT, NUMERIC, TEXT, NUMERIC, NUMERIC, NUMERIC, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_list_remittances(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_remittance_timeline(UUID) TO authenticated;
