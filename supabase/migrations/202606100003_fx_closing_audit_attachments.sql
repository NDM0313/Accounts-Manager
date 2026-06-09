-- FX Cash Ledger — daily closing, attachments, audit logs

CREATE TYPE fx_audit_action AS ENUM (
  'created',
  'edited',
  'posted',
  'voided',
  'deleted',
  'restored',
  'approved',
  'closed_day'
);

CREATE TABLE fx_daily_closings (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id            UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id             UUID NOT NULL REFERENCES fx_branches (id) ON DELETE RESTRICT,
  closing_date          DATE NOT NULL,
  status                TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed', 'approved')),
  notes                 TEXT,
  closed_by             UUID REFERENCES auth.users (id),
  closed_at             TIMESTAMPTZ,
  approved_by           UUID REFERENCES auth.users (id),
  approved_at           TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (branch_id, closing_date)
);

CREATE TABLE fx_closing_lines (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  daily_closing_id      UUID NOT NULL REFERENCES fx_daily_closings (id) ON DELETE CASCADE,
  account_id            UUID NOT NULL REFERENCES fx_accounts (id) ON DELETE RESTRICT,
  currency_code         TEXT NOT NULL,
  system_balance        NUMERIC(20, 8) NOT NULL DEFAULT 0,
  counted_balance       NUMERIC(20, 8),
  difference            NUMERIC(20, 8) NOT NULL DEFAULT 0,
  memo                  TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (daily_closing_id, account_id)
);

CREATE TABLE fx_attachments (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id        UUID NOT NULL REFERENCES fx_transactions (id) ON DELETE CASCADE,
  storage_path          TEXT NOT NULL,
  file_name             TEXT NOT NULL,
  mime_type             TEXT,
  file_size_bytes       BIGINT,
  uploaded_by           UUID REFERENCES auth.users (id),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE fx_audit_logs (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id            UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id             UUID REFERENCES fx_branches (id) ON DELETE RESTRICT,
  entity_type           TEXT NOT NULL,
  entity_id             UUID NOT NULL,
  action                fx_audit_action NOT NULL,
  reason                TEXT,
  old_value             JSONB,
  new_value             JSONB,
  actor_id              UUID REFERENCES auth.users (id),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_fx_daily_closings_branch_date ON fx_daily_closings (branch_id, closing_date DESC);
CREATE INDEX idx_fx_audit_logs_entity ON fx_audit_logs (entity_type, entity_id, created_at DESC);
CREATE INDEX idx_fx_attachments_transaction ON fx_attachments (transaction_id);

CREATE TRIGGER trg_fx_daily_closings_updated_at
  BEFORE UPDATE ON fx_daily_closings FOR EACH ROW EXECUTE FUNCTION fx_set_updated_at();

-- Block edits to posted transactions on closed days (used by RPC)
CREATE OR REPLACE FUNCTION fx_is_day_closed(p_branch_id UUID, p_date DATE)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM fx_daily_closings
    WHERE branch_id = p_branch_id
      AND closing_date = p_date
      AND status IN ('closed', 'approved')
  );
$$;
