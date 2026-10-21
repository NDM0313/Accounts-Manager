-- =============================================================================
-- B) ADDITIVE SCHEMA RECONCILIATION — NOT FOR DEFAULT EXECUTION
-- =============================================================================
-- Target: home shared supabase-db / postgres (PG17) ONLY after disposable clone
-- validation. Never ERP staging (PG16). Never blind historical migration replay.
--
-- PRESERVE (do not CREATE/DROP/ALTER/TRUNCATE):
--   public.fx_currency_purchases
--   public.fx_currency_purchase_settlements
--   public.import_fx_*
--
-- REUSE (must already exist; assert only — do not recreate):
--   fx_companies, fx_branches, fx_users_profiles, fx_roles, fx_user_roles,
--   fx_currencies, fx_rates, fx_accounts, fx_parties,
--   enums fx_account_type, fx_party_type, fx_transaction_type, fx_transaction_status,
--   function fx_set_updated_at()
--
-- EXCLUDE from production preparation:
--   fx_seed_fxdev_demo*, fx_demo_*, DEMO party seeds, realistic demo SQL
--
-- Activation (required):
--   SELECT set_config('fx_reconciliation.confirm', 'APPLY_ADDITIVE_HOME_FX', true);
-- =============================================================================

DO $$
BEGIN
  IF current_setting('fx_reconciliation.confirm', true) IS DISTINCT FROM 'APPLY_ADDITIVE_HOME_FX' THEN
    RAISE EXCEPTION
      'BLOCKED: set fx_reconciliation.confirm = APPLY_ADDITIVE_HOME_FX (session) before additive apply';
  END IF;

  IF current_database() <> 'postgres' THEN
    RAISE EXCEPTION 'BLOCKED: expected database postgres, got %', current_database();
  END IF;

  IF split_part(current_setting('server_version'), '.', 1)::int < 17 THEN
    RAISE EXCEPTION 'BLOCKED: expected PostgreSQL 17+, got %', current_setting('server_version');
  END IF;

  IF to_regclass('public.fx_currency_purchases') IS NULL
     OR to_regclass('public.fx_currency_purchase_settlements') IS NULL THEN
    RAISE EXCEPTION 'BLOCKED: ERP currency-purchase tables missing — aborting';
  END IF;

  IF to_regclass('public.fx_companies') IS NULL
     OR to_regclass('public.fx_branches') IS NULL
     OR to_regclass('public.fx_accounts') IS NULL THEN
    RAISE EXCEPTION 'BLOCKED: foundation fx_* tables missing — unexpected target';
  END IF;

  -- Column smoke asserts (fail on unexpected drift)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='fx_companies'
      AND column_name='base_currency_code'
  ) THEN
    RAISE EXCEPTION 'BLOCKED: fx_companies.base_currency_code missing';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='fx_currency_purchases'
      AND column_name='agent_contact_id'
  ) IS NOT TRUE THEN
    RAISE EXCEPTION 'BLOCKED: ERP fx_currency_purchases shape unexpected';
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Allowlisted NEW objects only (CREATE IF NOT EXISTS / DO blocks)
-- Source of truth for columns: supabase/migrations/202606100002 + 202606100003
-- IF NOT EXISTS is NOT sufficient compatibility proof — preflight + matrix required.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fx_transactions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id            UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id             UUID NOT NULL REFERENCES fx_branches (id) ON DELETE RESTRICT,
  transaction_no        TEXT,
  transaction_type      fx_transaction_type NOT NULL,
  status                fx_transaction_status NOT NULL DEFAULT 'draft',
  transaction_date      DATE NOT NULL DEFAULT CURRENT_DATE,
  party_id              UUID REFERENCES fx_parties (id) ON DELETE RESTRICT,
  description           TEXT,
  currency_code         TEXT NOT NULL DEFAULT 'PKR',
  total_foreign_amount  NUMERIC(20, 8) NOT NULL DEFAULT 0,
  rate_used             NUMERIC(20, 8) NOT NULL DEFAULT 1,
  total_base_amount_pkr NUMERIC(20, 8) NOT NULL DEFAULT 0,
  fee_amount            NUMERIC(20, 8) NOT NULL DEFAULT 0,
  notes                 TEXT,
  version               INT NOT NULL DEFAULT 1,
  is_deleted            BOOLEAN NOT NULL DEFAULT FALSE,
  delete_reason         TEXT,
  posted_at             TIMESTAMPTZ,
  voided_at             TIMESTAMPTZ,
  posted_by             UUID REFERENCES auth.users (id),
  voided_by             UUID REFERENCES auth.users (id),
  created_by            UUID REFERENCES auth.users (id),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (branch_id, transaction_no)
);

CREATE TABLE IF NOT EXISTS fx_transaction_lines (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id        UUID NOT NULL REFERENCES fx_transactions (id) ON DELETE CASCADE,
  line_no               INT NOT NULL,
  account_id            UUID REFERENCES fx_accounts (id) ON DELETE RESTRICT,
  currency_code         TEXT NOT NULL DEFAULT 'PKR',
  foreign_amount        NUMERIC(20, 8) NOT NULL DEFAULT 0,
  rate_used             NUMERIC(20, 8) NOT NULL DEFAULT 1,
  base_amount_pkr       NUMERIC(20, 8) NOT NULL DEFAULT 0,
  debit_pkr             NUMERIC(20, 8) NOT NULL DEFAULT 0,
  credit_pkr            NUMERIC(20, 8) NOT NULL DEFAULT 0,
  memo                  TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (transaction_id, line_no)
);

CREATE TABLE IF NOT EXISTS fx_transaction_versions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id        UUID NOT NULL REFERENCES fx_transactions (id) ON DELETE CASCADE,
  version               INT NOT NULL,
  snapshot              JSONB NOT NULL,
  change_reason         TEXT,
  changed_by            UUID REFERENCES auth.users (id),
  changed_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (transaction_id, version)
);

CREATE TABLE IF NOT EXISTS fx_journal_entries (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id            UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id             UUID NOT NULL REFERENCES fx_branches (id) ON DELETE RESTRICT,
  transaction_id        UUID REFERENCES fx_transactions (id) ON DELETE RESTRICT,
  entry_no              TEXT NOT NULL,
  entry_date            DATE NOT NULL DEFAULT CURRENT_DATE,
  description           TEXT,
  is_void               BOOLEAN NOT NULL DEFAULT FALSE,
  voided_at             TIMESTAMPTZ,
  voided_by             UUID REFERENCES auth.users (id),
  posted_by             UUID REFERENCES auth.users (id),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (branch_id, entry_no)
);

CREATE TABLE IF NOT EXISTS fx_journal_lines (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  journal_entry_id      UUID NOT NULL REFERENCES fx_journal_entries (id) ON DELETE CASCADE,
  line_no               INT NOT NULL,
  account_id            UUID NOT NULL REFERENCES fx_accounts (id) ON DELETE RESTRICT,
  currency_code         TEXT NOT NULL DEFAULT 'PKR',
  foreign_amount        NUMERIC(20, 8) NOT NULL DEFAULT 0,
  rate_used             NUMERIC(20, 8) NOT NULL DEFAULT 1,
  debit_pkr             NUMERIC(20, 8) NOT NULL DEFAULT 0,
  credit_pkr            NUMERIC(20, 8) NOT NULL DEFAULT 0,
  memo                  TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (journal_entry_id, line_no),
  CONSTRAINT fx_journal_lines_debit_credit_check CHECK (
    (debit_pkr > 0 AND credit_pkr = 0) OR (credit_pkr > 0 AND debit_pkr = 0)
  )
);

DO $$ BEGIN
  CREATE TYPE fx_audit_action AS ENUM (
    'created','edited','posted','voided','deleted','restored','approved','closed_day'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS fx_daily_closings (
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

CREATE TABLE IF NOT EXISTS fx_closing_lines (
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

CREATE TABLE IF NOT EXISTS fx_attachments (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id        UUID NOT NULL REFERENCES fx_transactions (id) ON DELETE CASCADE,
  storage_path          TEXT NOT NULL,
  file_name             TEXT NOT NULL,
  mime_type             TEXT,
  file_size_bytes       BIGINT,
  uploaded_by           UUID REFERENCES auth.users (id),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fx_audit_logs (
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

CREATE INDEX IF NOT EXISTS idx_fx_transactions_branch_date
  ON fx_transactions (branch_id, transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_fx_transactions_status
  ON fx_transactions (status) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_fx_journal_entries_branch_date
  ON fx_journal_entries (branch_id, entry_date DESC);
CREATE INDEX IF NOT EXISTS idx_fx_journal_lines_account
  ON fx_journal_lines (account_id);
CREATE INDEX IF NOT EXISTS idx_fx_daily_closings_branch_date
  ON fx_daily_closings (branch_id, closing_date DESC);
CREATE INDEX IF NOT EXISTS idx_fx_audit_logs_entity
  ON fx_audit_logs (entity_type, entity_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fx_attachments_transaction
  ON fx_attachments (transaction_id);

-- Triggers (idempotent via drop/create on allowlisted names only)
DROP TRIGGER IF EXISTS trg_fx_transactions_updated_at ON fx_transactions;
CREATE TRIGGER trg_fx_transactions_updated_at
  BEFORE UPDATE ON fx_transactions FOR EACH ROW EXECUTE FUNCTION fx_set_updated_at();

DROP TRIGGER IF EXISTS trg_fx_journal_entries_updated_at ON fx_journal_entries;
CREATE TRIGGER trg_fx_journal_entries_updated_at
  BEFORE UPDATE ON fx_journal_entries FOR EACH ROW EXECUTE FUNCTION fx_set_updated_at();

DROP TRIGGER IF EXISTS trg_fx_daily_closings_updated_at ON fx_daily_closings;
CREATE TRIGGER trg_fx_daily_closings_updated_at
  BEFORE UPDATE ON fx_daily_closings FOR EACH ROW EXECUTE FUNCTION fx_set_updated_at();

-- ---------------------------------------------------------------------------
-- REMAINING ALLOWLIST (port in follow-up additive files after clone validation)
-- Do NOT auto-include demo/seed migrations.
-- ---------------------------------------------------------------------------
-- From supabase/migrations (review each; column-diff vs live):
--   202606170001_fx_deals_workflow.sql (+ later deal fixes)
--   202606200002_fx_opening_balance_batches.sql
--   202606230001_fx_remittance_module.sql (+ H4–H7 workflow)
--   202606230003_fx_messaging_module.sql
--   202606240001_fx_secure_share_links.sql
--   RPC files: 202606100006, 202606110001, 202606120001, remittance posting, etc.
-- Explicitly EXCLUDE:
--   202606210002/003/004 fx_seed_fxdev_demo*
--   any INSERT demo business data
--
-- DO NOT INSERT INTO supabase_migrations.schema_migrations for historical
-- AM versions unless every statement effect is independently verified.
