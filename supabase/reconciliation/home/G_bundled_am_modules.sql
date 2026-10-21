-- =============================================================================
-- G) BUNDLED ACCOUNTS-MANAGER MODULES (FROM MIGRATIONS) — NOT DEFAULT-RUNNABLE
-- Generated locally for review. Do NOT mark schema_migrations rows for these
-- historical versions unless every statement effect is verified on a clone.
-- Excludes demo seed migrations and unsafe demo backfills.
-- ERP fx_currency_purchases* / import_fx_* are never referenced here for DROP.
-- =============================================================================
-- Activation (required):
--   SELECT set_config('fx_reconciliation.confirm', 'APPLY_BUNDLED_AM_MODULES', true);
-- Identity (required — independently checked):
--   current_database() = postgres
--   server_version major >= 17
--   inet_server_addr() IS NULL OR localhost-only disposable (operator check)
-- =============================================================================

DO $guard$
BEGIN
  IF current_setting('fx_reconciliation.confirm', true) IS DISTINCT FROM 'APPLY_BUNDLED_AM_MODULES' THEN
    RAISE EXCEPTION 'BLOCKED: set fx_reconciliation.confirm=APPLY_BUNDLED_AM_MODULES';
  END IF;
  IF current_database() <> 'postgres' THEN
    RAISE EXCEPTION 'BLOCKED: expected database postgres, got %', current_database();
  END IF;
  IF split_part(current_setting('server_version'), '.', 1)::int < 17 THEN
    RAISE EXCEPTION 'BLOCKED: expected PostgreSQL 17+, got %', current_setting('server_version');
  END IF;
  -- Preserve ERP purchase objects
  IF to_regclass('public.fx_currency_purchases') IS NULL
     OR to_regclass('public.fx_currency_purchase_settlements') IS NULL THEN
    -- On disposable empty fixture these may be stubbed; require operator override
    IF current_setting('fx_reconciliation.allow_missing_erp_purchase', true) IS DISTINCT FROM '1' THEN
      RAISE EXCEPTION 'BLOCKED: ERP currency-purchase tables missing (set fx_reconciliation.allow_missing_erp_purchase=1 only on synthetic fixture)';
    END IF;
  END IF;
  PERFORM set_config('lock_timeout', '5s', true);
  PERFORM set_config('statement_timeout', '120s', true);
END
$guard$;

-- Included migration files (41):
--   202606100001_fx_foundation.sql
--   202606100002_fx_transactions_journal.sql
--   202606100003_fx_closing_audit_attachments.sql
--   202606100004_fx_rls_policies.sql
--   202606100005_fx_seed_currencies_coa.sql
--   202606100006_fx_rpc_posting.sql
--   202606110001_fx_posting_engine.sql
--   202606120001_fx_edit_delete_engine.sql
--   202606120002_fx_fix_number_sequences.sql
--   202606130001_fx_reports_and_closing.sql
--   202606130002_fx_report_rpc_grants.sql
--   202606140001_fx_manual_journal_repost_restore_attachments.sql
--   202606150001_fx_post_all_transaction_types.sql
--   202606160001_fx_currency_crud_exchange_group.sql
--   202606170001_fx_deals_workflow.sql
--   202606170002_fx_deals_coa_fix_completion.sql
--   202606170003_fx_deals_enum_cast_fix.sql
--   202606180001_fx_rates_reference_snapshot.sql
--   202606180002_fx_rates_versioning_and_snapshots.sql
--   202606180005_fx_deal_rpc_v2_consolidation.sql
--   202606190001_fx_deal_leg_attachments.sql
--   202606190002_fx_seed_afn_currency.sql
--   202606200001_fx_fix_deal_number_sequence.sql
--   202606200002_fx_opening_balance_batches.sql
--   202606210001_fx_display_currency.sql
--   202606210006_fx_deal_leg_edit_delete.sql
--   202606210007_fx_deal_leg_edit_delete_fix.sql
--   202606210008_fx_deal_leg_edit_delete_fix2.sql
--   202606220001_fx_deal_customer_payment_posting_fix.sql
--   202606230001_fx_remittance_module.sql
--   202606230002_fx_remittance_posting.sql
--   202606230003_fx_messaging_module.sql
--   202606230004_fx_attachments_remittance_message.sql
--   202606240001_fx_secure_share_links.sql
--   202606240002_fx_remittance_posting_type_fix.sql
--   202606250001_fx_remittance_workflow_h4.sql
--   202606250002_fx_remittance_agent_h5.sql
--   202606250003_fx_remittance_notifications_audit_h6.sql
--   202606250004_fx_remittance_reports_h7.sql
--   202606250005_fx_remittance_agent_detail_access.sql
--   202606260001_fx_messaging_rls_recursion_fix.sql


-- >>>>> BEGIN 202606100001_fx_foundation.sql
-- FX Cash Ledger — foundation tables (isolated fx_* namespace only)
-- Base currency: PKR

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

DO $$ BEGIN
CREATE TYPE fx_account_type AS ENUM (
  'asset',
  'liability',
  'equity',
  'income',
  'expense',
  'adjustment'
);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;

DO $$ BEGIN
CREATE TYPE fx_party_type AS ENUM (
  'customer',
  'agent',
  'settlement'
);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;

DO $$ BEGIN
CREATE TYPE fx_transaction_type AS ENUM (
  'currency_buy',
  'currency_sell',
  'cross_currency',
  'account_transfer',
  'expense',
  'settlement_send',
  'settlement_receive',
  'manual_journal',
  'revaluation',
  'opening_balance',
  'daily_closing_adjustment'
);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;

DO $$ BEGIN
CREATE TYPE fx_transaction_status AS ENUM (
  'draft',
  'posted',
  'voided'
);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;

-- ---------------------------------------------------------------------------
-- Org / access
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fx_companies (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  code          TEXT NOT NULL UNIQUE,
  base_currency_code TEXT NOT NULL DEFAULT 'PKR',
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fx_branches (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id    UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  name          TEXT NOT NULL,
  code          TEXT NOT NULL,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (company_id, code)
);

CREATE TABLE IF NOT EXISTS fx_users_profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  company_id    UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id     UUID NOT NULL REFERENCES fx_branches (id) ON DELETE RESTRICT,
  full_name     TEXT,
  email         TEXT,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fx_roles (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id    UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  name          TEXT NOT NULL,
  permissions   TEXT[] NOT NULL DEFAULT '{}',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (company_id, name)
);

CREATE TABLE IF NOT EXISTS fx_user_roles (
  user_id       UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  role_id       UUID NOT NULL REFERENCES fx_roles (id) ON DELETE CASCADE,
  assigned_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, role_id)
);

-- ---------------------------------------------------------------------------
-- Master data
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fx_currencies (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code            TEXT NOT NULL UNIQUE,
  name            TEXT NOT NULL,
  symbol          TEXT NOT NULL DEFAULT '',
  decimal_places  INT NOT NULL DEFAULT 2,
  is_base         BOOLEAN NOT NULL DEFAULT FALSE,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fx_rates (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id       UUID NOT NULL REFERENCES fx_branches (id) ON DELETE RESTRICT,
  currency_id     UUID NOT NULL REFERENCES fx_currencies (id) ON DELETE RESTRICT,
  effective_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  buy_rate        NUMERIC(20, 8) NOT NULL,
  sell_rate       NUMERIC(20, 8) NOT NULL,
  mid_rate        NUMERIC(20, 8),
  created_by      UUID REFERENCES auth.users (id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (branch_id, currency_id, effective_at)
);

CREATE TABLE IF NOT EXISTS fx_accounts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id       UUID REFERENCES fx_branches (id) ON DELETE RESTRICT,
  code            TEXT NOT NULL,
  name            TEXT NOT NULL,
  account_type    fx_account_type NOT NULL,
  currency_id     UUID REFERENCES fx_currencies (id) ON DELETE RESTRICT,
  parent_id       UUID REFERENCES fx_accounts (id) ON DELETE RESTRICT,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (company_id, code)
);

CREATE TABLE IF NOT EXISTS fx_parties (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id       UUID REFERENCES fx_branches (id) ON DELETE RESTRICT,
  party_type      fx_party_type NOT NULL,
  code            TEXT NOT NULL,
  name            TEXT NOT NULL,
  phone           TEXT,
  notes           TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (company_id, code)
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_fx_branches_company ON fx_branches (company_id);
CREATE INDEX IF NOT EXISTS idx_fx_users_profiles_company_branch ON fx_users_profiles (company_id, branch_id);
CREATE INDEX IF NOT EXISTS idx_fx_rates_branch_currency ON fx_rates (branch_id, currency_id, effective_at DESC);
CREATE INDEX IF NOT EXISTS idx_fx_accounts_company_type ON fx_accounts (company_id, account_type);
CREATE INDEX IF NOT EXISTS idx_fx_parties_company_type ON fx_parties (company_id, party_type);

-- ---------------------------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_fx_companies_updated_at
  BEFORE UPDATE ON fx_companies FOR EACH ROW EXECUTE FUNCTION fx_set_updated_at();

CREATE TRIGGER trg_fx_branches_updated_at
  BEFORE UPDATE ON fx_branches FOR EACH ROW EXECUTE FUNCTION fx_set_updated_at();

CREATE TRIGGER trg_fx_users_profiles_updated_at
  BEFORE UPDATE ON fx_users_profiles FOR EACH ROW EXECUTE FUNCTION fx_set_updated_at();

CREATE TRIGGER trg_fx_roles_updated_at
  BEFORE UPDATE ON fx_roles FOR EACH ROW EXECUTE FUNCTION fx_set_updated_at();

CREATE TRIGGER trg_fx_currencies_updated_at
  BEFORE UPDATE ON fx_currencies FOR EACH ROW EXECUTE FUNCTION fx_set_updated_at();

CREATE TRIGGER trg_fx_accounts_updated_at
  BEFORE UPDATE ON fx_accounts FOR EACH ROW EXECUTE FUNCTION fx_set_updated_at();

CREATE TRIGGER trg_fx_parties_updated_at
  BEFORE UPDATE ON fx_parties FOR EACH ROW EXECUTE FUNCTION fx_set_updated_at();
-- <<<<< END 202606100001_fx_foundation.sql

-- >>>>> BEGIN 202606100002_fx_transactions_journal.sql
-- FX Cash Ledger — transactions, journal, version history

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

CREATE INDEX IF NOT EXISTS idx_fx_transactions_branch_date ON fx_transactions (branch_id, transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_fx_transactions_status ON fx_transactions (status) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_fx_journal_entries_branch_date ON fx_journal_entries (branch_id, entry_date DESC);
CREATE INDEX IF NOT EXISTS idx_fx_journal_lines_account ON fx_journal_lines (account_id);

CREATE TRIGGER trg_fx_transactions_updated_at
  BEFORE UPDATE ON fx_transactions FOR EACH ROW EXECUTE FUNCTION fx_set_updated_at();

CREATE TRIGGER trg_fx_journal_entries_updated_at
  BEFORE UPDATE ON fx_journal_entries FOR EACH ROW EXECUTE FUNCTION fx_set_updated_at();

-- Validate balanced journal entry (base currency PKR)
CREATE OR REPLACE FUNCTION fx_assert_journal_balanced(p_journal_entry_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_debit  NUMERIC(20, 8);
  v_credit NUMERIC(20, 8);
BEGIN
  SELECT COALESCE(SUM(debit_pkr), 0), COALESCE(SUM(credit_pkr), 0)
  INTO v_debit, v_credit
  FROM fx_journal_lines
  WHERE journal_entry_id = p_journal_entry_id;

  IF v_debit <> v_credit THEN
    RAISE EXCEPTION 'Journal entry % is not balanced: debit=% credit=%',
      p_journal_entry_id, v_debit, v_credit;
  END IF;
END;
$$;
-- <<<<< END 202606100002_fx_transactions_journal.sql

-- >>>>> BEGIN 202606100003_fx_closing_audit_attachments.sql
-- FX Cash Ledger — daily closing, attachments, audit logs

DO $$ BEGIN
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
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;

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

CREATE INDEX IF NOT EXISTS idx_fx_daily_closings_branch_date ON fx_daily_closings (branch_id, closing_date DESC);
CREATE INDEX IF NOT EXISTS idx_fx_audit_logs_entity ON fx_audit_logs (entity_type, entity_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fx_attachments_transaction ON fx_attachments (transaction_id);

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
-- <<<<< END 202606100003_fx_closing_audit_attachments.sql

-- >>>>> BEGIN 202606100004_fx_rls_policies.sql
-- FX Cash Ledger — RLS policies (all fx_* tables)

-- ---------------------------------------------------------------------------
-- Helper functions
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_current_profile()
RETURNS fx_users_profiles
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.*
  FROM fx_users_profiles p
  WHERE p.id = auth.uid()
    AND p.is_active = TRUE
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fx_has_permission(p_permission TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM fx_user_roles ur
    JOIN fx_roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid()
      AND p_permission = ANY (r.permissions)
  );
$$;

CREATE OR REPLACE FUNCTION fx_same_company(p_company_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM fx_users_profiles p
    WHERE p.id = auth.uid() AND p.company_id = p_company_id
  );
$$;

CREATE OR REPLACE FUNCTION fx_same_branch(p_branch_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM fx_users_profiles p
    WHERE p.id = auth.uid() AND p.branch_id = p_branch_id
  );
$$;

-- ---------------------------------------------------------------------------
-- Enable RLS on all fx_* tables
-- ---------------------------------------------------------------------------

ALTER TABLE fx_companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_users_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_currencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_parties ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_transaction_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_transaction_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_journal_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_daily_closings ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_closing_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_audit_logs ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- fx_companies / fx_branches — read own company
-- ---------------------------------------------------------------------------

CREATE POLICY fx_companies_select ON fx_companies
  FOR SELECT TO authenticated
  USING (fx_same_company(id));

CREATE POLICY fx_branches_select ON fx_branches
  FOR SELECT TO authenticated
  USING (fx_same_company(company_id));

-- ---------------------------------------------------------------------------
-- fx_users_profiles — read own profile + same company
-- ---------------------------------------------------------------------------

CREATE POLICY fx_users_profiles_select ON fx_users_profiles
  FOR SELECT TO authenticated
  USING (fx_same_company(company_id));

CREATE POLICY fx_users_profiles_update_self ON fx_users_profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ---------------------------------------------------------------------------
-- fx_roles / fx_user_roles
-- ---------------------------------------------------------------------------

CREATE POLICY fx_roles_select ON fx_roles
  FOR SELECT TO authenticated
  USING (fx_same_company(company_id));

CREATE POLICY fx_user_roles_select ON fx_user_roles
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM fx_roles r
      WHERE r.id = role_id AND fx_same_company(r.company_id)
    )
  );

-- ---------------------------------------------------------------------------
-- fx_currencies — global read for authenticated
-- ---------------------------------------------------------------------------

CREATE POLICY fx_currencies_select ON fx_currencies
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY fx_currencies_manage ON fx_currencies
  FOR ALL TO authenticated
  USING (fx_has_permission('can_manage_chart_of_accounts'))
  WITH CHECK (fx_has_permission('can_manage_chart_of_accounts'));

-- ---------------------------------------------------------------------------
-- fx_rates
-- ---------------------------------------------------------------------------

CREATE POLICY fx_rates_select ON fx_rates
  FOR SELECT TO authenticated
  USING (fx_same_branch(branch_id));

CREATE POLICY fx_rates_insert ON fx_rates
  FOR INSERT TO authenticated
  WITH CHECK (
    fx_same_branch(branch_id)
    AND fx_has_permission('can_manage_fx_rates')
  );

CREATE POLICY fx_rates_update ON fx_rates
  FOR UPDATE TO authenticated
  USING (fx_same_branch(branch_id) AND fx_has_permission('can_manage_fx_rates'))
  WITH CHECK (fx_same_branch(branch_id) AND fx_has_permission('can_manage_fx_rates'));

-- ---------------------------------------------------------------------------
-- fx_accounts (Chart of Accounts)
-- ---------------------------------------------------------------------------

CREATE POLICY fx_accounts_select ON fx_accounts
  FOR SELECT TO authenticated
  USING (fx_same_company(company_id) AND fx_has_permission('can_access_fx_ledger'));

CREATE POLICY fx_accounts_manage ON fx_accounts
  FOR ALL TO authenticated
  USING (
    fx_same_company(company_id)
    AND fx_has_permission('can_manage_chart_of_accounts')
  )
  WITH CHECK (
    fx_same_company(company_id)
    AND fx_has_permission('can_manage_chart_of_accounts')
  );

-- ---------------------------------------------------------------------------
-- fx_parties
-- ---------------------------------------------------------------------------

CREATE POLICY fx_parties_select ON fx_parties
  FOR SELECT TO authenticated
  USING (fx_same_company(company_id) AND fx_has_permission('can_access_fx_ledger'));

CREATE POLICY fx_parties_write ON fx_parties
  FOR ALL TO authenticated
  USING (fx_same_company(company_id) AND fx_has_permission('can_access_fx_ledger'))
  WITH CHECK (fx_same_company(company_id) AND fx_has_permission('can_access_fx_ledger'));

-- ---------------------------------------------------------------------------
-- fx_transactions — draft CRUD by cashier; posted rows immutable via client
-- ---------------------------------------------------------------------------

CREATE POLICY fx_transactions_select ON fx_transactions
  FOR SELECT TO authenticated
  USING (
    fx_same_branch(branch_id)
    AND fx_has_permission('can_access_fx_ledger')
  );

CREATE POLICY fx_transactions_insert_draft ON fx_transactions
  FOR INSERT TO authenticated
  WITH CHECK (
    fx_same_branch(branch_id)
    AND fx_has_permission('can_access_fx_ledger')
    AND status = 'draft'
  );

CREATE POLICY fx_transactions_update_draft ON fx_transactions
  FOR UPDATE TO authenticated
  USING (
    fx_same_branch(branch_id)
    AND status = 'draft'
    AND fx_has_permission('can_access_fx_ledger')
  )
  WITH CHECK (
    fx_same_branch(branch_id)
    AND status = 'draft'
  );

CREATE POLICY fx_transactions_delete_draft ON fx_transactions
  FOR DELETE TO authenticated
  USING (
    fx_same_branch(branch_id)
    AND status = 'draft'
    AND fx_has_permission('can_access_fx_ledger')
  );

-- ---------------------------------------------------------------------------
-- fx_transaction_lines — draft only via client
-- ---------------------------------------------------------------------------

CREATE POLICY fx_transaction_lines_select ON fx_transaction_lines
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM fx_transactions t
      WHERE t.id = transaction_id
        AND fx_same_branch(t.branch_id)
        AND fx_has_permission('can_access_fx_ledger')
    )
  );

CREATE POLICY fx_transaction_lines_write_draft ON fx_transaction_lines
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM fx_transactions t
      WHERE t.id = transaction_id
        AND t.status = 'draft'
        AND fx_same_branch(t.branch_id)
        AND fx_has_permission('can_access_fx_ledger')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM fx_transactions t
      WHERE t.id = transaction_id
        AND t.status = 'draft'
        AND fx_same_branch(t.branch_id)
    )
  );

-- ---------------------------------------------------------------------------
-- fx_transaction_versions — read only via client
-- ---------------------------------------------------------------------------

CREATE POLICY fx_transaction_versions_select ON fx_transaction_versions
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM fx_transactions t
      WHERE t.id = transaction_id
        AND fx_same_branch(t.branch_id)
        AND fx_has_permission('can_view_fx_audit')
    )
  );

-- ---------------------------------------------------------------------------
-- fx_journal — read only via client; writes via RPC only
-- ---------------------------------------------------------------------------

CREATE POLICY fx_journal_entries_select ON fx_journal_entries
  FOR SELECT TO authenticated
  USING (
    fx_same_branch(branch_id)
    AND fx_has_permission('can_view_fx_reports')
  );

CREATE POLICY fx_journal_lines_select ON fx_journal_lines
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM fx_journal_entries e
      WHERE e.id = journal_entry_id
        AND fx_same_branch(e.branch_id)
        AND fx_has_permission('can_view_fx_reports')
    )
  );

-- ---------------------------------------------------------------------------
-- fx_daily_closings / fx_closing_lines
-- ---------------------------------------------------------------------------

CREATE POLICY fx_daily_closings_select ON fx_daily_closings
  FOR SELECT TO authenticated
  USING (fx_same_branch(branch_id) AND fx_has_permission('can_view_fx_reports'));

CREATE POLICY fx_closing_lines_select ON fx_closing_lines
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM fx_daily_closings c
      WHERE c.id = daily_closing_id
        AND fx_same_branch(c.branch_id)
        AND fx_has_permission('can_view_fx_reports')
    )
  );

-- ---------------------------------------------------------------------------
-- fx_attachments
-- ---------------------------------------------------------------------------

CREATE POLICY fx_attachments_select ON fx_attachments
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM fx_transactions t
      WHERE t.id = transaction_id
        AND fx_same_branch(t.branch_id)
        AND fx_has_permission('can_access_fx_ledger')
    )
  );

CREATE POLICY fx_attachments_insert ON fx_attachments
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM fx_transactions t
      WHERE t.id = transaction_id
        AND fx_same_branch(t.branch_id)
        AND fx_has_permission('can_access_fx_ledger')
    )
  );

-- ---------------------------------------------------------------------------
-- fx_audit_logs — read only
-- ---------------------------------------------------------------------------

CREATE POLICY fx_audit_logs_select ON fx_audit_logs
  FOR SELECT TO authenticated
  USING (
    fx_same_company(company_id)
    AND fx_has_permission('can_view_fx_audit')
  );
-- <<<<< END 202606100004_fx_rls_policies.sql

-- >>>>> BEGIN 202606100005_fx_seed_currencies_coa.sql
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
-- <<<<< END 202606100005_fx_seed_currencies_coa.sql

-- >>>>> BEGIN 202606100006_fx_rpc_posting.sql
-- FX Cash Ledger — RPC skeletons (posting/edit/delete/reports)
-- All functions: SECURITY DEFINER, permission-checked, fx_* tables only.

-- ---------------------------------------------------------------------------
-- fx_generate_transaction_no
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_generate_transaction_no(p_branch_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prefix TEXT;
  v_seq INT;
BEGIN
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  SELECT COALESCE(MAX(
    NULLIF(regexp_replace(transaction_no, '\D', '', 'g'), '')::INT
  ), 0) + 1
  INTO v_seq
  FROM fx_transactions
  WHERE branch_id = p_branch_id;

  v_prefix := TO_CHAR(NOW(), 'YYYYMMDD');
  RETURN v_prefix || '-' || LPAD(v_seq::TEXT, 5, '0');
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_post_transaction — skeleton: validates draft, assigns number, marks posted
-- Full journal logic to be implemented in Phase 2.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_post_transaction(p_transaction_id UUID)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_post_fx_transaction';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transaction not found: %', p_transaction_id;
  END IF;

  IF NOT fx_same_branch(v_tx.branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  IF v_tx.status <> 'draft' THEN
    RAISE EXCEPTION 'Only draft transactions can be posted';
  END IF;

  IF fx_is_day_closed(v_tx.branch_id, v_tx.transaction_date) THEN
    RAISE EXCEPTION 'Day is closed. Posting requires admin approval.';
  END IF;

  IF v_tx.transaction_no IS NULL OR v_tx.transaction_no = '' THEN
    v_tx.transaction_no := fx_generate_transaction_no(v_tx.branch_id);
  END IF;

  UPDATE fx_transactions
  SET
    status = 'posted',
    transaction_no = v_tx.transaction_no,
    posted_at = NOW(),
    posted_by = auth.uid(),
    updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, new_value, actor_id)
  VALUES (v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'posted', to_jsonb(v_tx), auth.uid());

  -- TODO Phase 2: create balanced fx_journal_entries + fx_journal_lines

  RETURN v_tx;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_edit_transaction — skeleton: version snapshot + reason required
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_edit_transaction(
  p_transaction_id UUID,
  p_payload JSONB,
  p_reason TEXT
)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_new_version INT;
BEGIN
  IF NOT fx_has_permission('can_edit_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_edit_fx_transaction';
  END IF;

  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required for editing posted transactions';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found'; END IF;
  IF NOT fx_same_branch(v_tx.branch_id) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF v_tx.is_deleted THEN RAISE EXCEPTION 'Cannot edit deleted transaction'; END IF;

  IF fx_is_day_closed(v_tx.branch_id, v_tx.transaction_date) THEN
    RAISE EXCEPTION 'Day is closed. Edit requires admin approval.';
  END IF;

  v_new_version := v_tx.version + 1;

  INSERT INTO fx_transaction_versions (transaction_id, version, snapshot, change_reason, changed_by)
  VALUES (v_tx.id, v_tx.version, to_jsonb(v_tx), p_reason, auth.uid());

  UPDATE fx_transactions
  SET
    transaction_date = COALESCE((p_payload->>'transaction_date')::DATE, transaction_date),
    description = COALESCE(p_payload->>'description', description),
    notes = COALESCE(p_payload->>'notes', notes),
    version = v_new_version,
    updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, reason, old_value, new_value, actor_id)
  VALUES (v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'edited', p_reason,
    (SELECT snapshot FROM fx_transaction_versions WHERE transaction_id = v_tx.id AND version = v_new_version - 1),
    to_jsonb(v_tx), auth.uid());

  -- TODO Phase 2: void/repost journal entries

  RETURN v_tx;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_delete_transaction — soft void (not physical delete)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_delete_transaction(
  p_transaction_id UUID,
  p_reason TEXT
)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
BEGIN
  IF NOT fx_has_permission('can_delete_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_delete_fx_transaction';
  END IF;

  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required for delete/void';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found'; END IF;
  IF NOT fx_same_branch(v_tx.branch_id) THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  IF v_tx.status = 'draft' THEN
    DELETE FROM fx_transactions WHERE id = p_transaction_id;
    RETURN v_tx;
  END IF;

  IF fx_is_day_closed(v_tx.branch_id, v_tx.transaction_date) THEN
    RAISE EXCEPTION 'Day is closed. Delete requires admin approval.';
  END IF;

  UPDATE fx_transactions
  SET
    status = 'voided',
    is_deleted = TRUE,
    voided_at = NOW(),
    voided_by = auth.uid(),
    delete_reason = p_reason,
    updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, reason, old_value, new_value, actor_id)
  VALUES (v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'deleted', p_reason, NULL, to_jsonb(v_tx), auth.uid());

  -- TODO Phase 2: void journal entries via fx_assert_journal_balanced

  RETURN v_tx;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_restore_deleted_transaction
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_restore_deleted_transaction(p_transaction_id UUID, p_reason TEXT)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
BEGIN
  IF NOT fx_has_permission('can_edit_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found'; END IF;

  UPDATE fx_transactions
  SET is_deleted = FALSE, status = 'posted', voided_at = NULL, voided_by = NULL,
      delete_reason = NULL, updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, reason, actor_id)
  VALUES (v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'restored', p_reason, auth.uid());

  RETURN v_tx;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_post_manual_journal — skeleton
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_post_manual_journal(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_post_fx_transaction';
  END IF;
  -- TODO Phase 2: insert fx_journal_entries + balanced fx_journal_lines from p_payload
  RAISE EXCEPTION 'fx_post_manual_journal not yet implemented';
END;
$$;

-- ---------------------------------------------------------------------------
-- Report RPCs — skeletons returning empty sets until Phase 2
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_trial_balance(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  account_code TEXT,
  account_name TEXT,
  debit_pkr NUMERIC,
  credit_pkr NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN
    RAISE EXCEPTION 'Missing permission: can_view_fx_reports';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT a.code, a.name, COALESCE(SUM(jl.debit_pkr), 0), COALESCE(SUM(jl.credit_pkr), 0)
  FROM fx_accounts a
  LEFT JOIN fx_journal_lines jl ON jl.account_id = a.id
  LEFT JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    AND je.branch_id = p_branch_id
    AND je.entry_date <= p_as_of
    AND NOT je.is_void
  WHERE a.company_id = (SELECT company_id FROM fx_branches WHERE id = p_branch_id)
  GROUP BY a.code, a.name
  ORDER BY a.code;
END;
$$;

CREATE OR REPLACE FUNCTION fx_get_profit_and_loss(
  p_branch_id UUID,
  p_from DATE,
  p_to DATE
)
RETURNS TABLE (account_code TEXT, account_name TEXT, amount_pkr NUMERIC)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  RETURN QUERY SELECT NULL::TEXT, NULL::TEXT, NULL::NUMERIC WHERE FALSE;
  -- TODO Phase 2
END;
$$;

CREATE OR REPLACE FUNCTION fx_get_balance_sheet(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (account_code TEXT, account_name TEXT, balance_pkr NUMERIC)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  RETURN QUERY SELECT NULL::TEXT, NULL::TEXT, NULL::NUMERIC WHERE FALSE;
  -- TODO Phase 2
END;
$$;

CREATE OR REPLACE FUNCTION fx_get_currency_position(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (currency_code TEXT, foreign_balance NUMERIC, base_equivalent_pkr NUMERIC)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  RETURN QUERY SELECT NULL::TEXT, NULL::NUMERIC, NULL::NUMERIC WHERE FALSE;
  -- TODO Phase 2
END;
$$;

CREATE OR REPLACE FUNCTION fx_close_day(
  p_branch_id UUID,
  p_closing_date DATE,
  p_notes TEXT DEFAULT NULL
)
RETURNS fx_daily_closings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_closing fx_daily_closings;
BEGIN
  IF NOT fx_has_permission('can_close_day') THEN
    RAISE EXCEPTION 'Missing permission: can_close_day';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  INSERT INTO fx_daily_closings (company_id, branch_id, closing_date, status, notes, closed_by, closed_at)
  SELECT b.company_id, p_branch_id, p_closing_date, 'closed', p_notes, auth.uid(), NOW()
  FROM fx_branches b WHERE b.id = p_branch_id
  ON CONFLICT (branch_id, closing_date)
  DO UPDATE SET status = 'closed', notes = EXCLUDED.notes, closed_by = auth.uid(), closed_at = NOW(), updated_at = NOW()
  RETURNING * INTO v_closing;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, actor_id)
  VALUES (v_closing.company_id, v_closing.branch_id, 'fx_daily_closings', v_closing.id, 'closed_day', auth.uid());

  -- TODO Phase 2: populate fx_closing_lines with system balances

  RETURN v_closing;
END;
$$;

-- Grant execute to authenticated users (RLS enforced inside functions)
GRANT EXECUTE ON FUNCTION fx_generate_transaction_no(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_post_transaction(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_edit_transaction(UUID, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_delete_transaction(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_restore_deleted_transaction(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_post_manual_journal(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_trial_balance(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_profit_and_loss(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_balance_sheet(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_currency_position(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_close_day(UUID, DATE, TEXT) TO authenticated;
-- <<<<< END 202606100006_fx_rpc_posting.sql

-- >>>>> BEGIN 202606110001_fx_posting_engine.sql
-- Phase 3: Posting engine — balanced journal creation from draft transaction lines
-- Project: ygidlcqhupmxvsdjmvnf only (fx_* tables)

DROP FUNCTION IF EXISTS fx_get_trial_balance(UUID, DATE);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_generate_entry_no(p_branch_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seq INT;
BEGIN
  SELECT COALESCE(MAX(
    NULLIF(regexp_replace(entry_no, '\D', '', 'g'), '')::INT
  ), 0) + 1
  INTO v_seq
  FROM fx_journal_entries
  WHERE branch_id = p_branch_id;

  RETURN TO_CHAR(NOW(), 'YYYYMMDD') || '-JE-' || LPAD(v_seq::TEXT, 5, '0');
END;
$$;

CREATE OR REPLACE FUNCTION fx_account_id_by_code(p_company_id UUID, p_code TEXT)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM fx_accounts WHERE company_id = p_company_id AND code = p_code LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fx_validate_transaction_lines_balanced(p_transaction_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_debit NUMERIC(20, 8);
  v_credit NUMERIC(20, 8);
  v_line_count INT;
BEGIN
  SELECT COUNT(*), COALESCE(SUM(debit_pkr), 0), COALESCE(SUM(credit_pkr), 0)
  INTO v_line_count, v_debit, v_credit
  FROM fx_transaction_lines
  WHERE transaction_id = p_transaction_id;

  IF v_line_count < 2 THEN
    RAISE EXCEPTION 'Draft requires at least 2 transaction lines';
  END IF;

  IF v_debit <> v_credit OR v_debit = 0 THEN
    RAISE EXCEPTION 'Transaction lines not balanced: debit=% credit=%', v_debit, v_credit;
  END IF;
END;
$$;

-- Copy balanced draft lines → journal; returns journal_entry_id
CREATE OR REPLACE FUNCTION fx_build_journal_from_transaction(p_transaction_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_entry_id UUID;
  v_line RECORD;
  v_line_no INT := 0;
BEGIN
  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transaction not found';
  END IF;

  PERFORM fx_validate_transaction_lines_balanced(p_transaction_id);

  INSERT INTO fx_journal_entries (
    company_id, branch_id, transaction_id, entry_no, entry_date, description, posted_by
  ) VALUES (
    v_tx.company_id,
    v_tx.branch_id,
    v_tx.id,
    fx_generate_entry_no(v_tx.branch_id),
    v_tx.transaction_date,
    COALESCE(v_tx.description, v_tx.transaction_type::TEXT),
    auth.uid()
  )
  RETURNING id INTO v_entry_id;

  FOR v_line IN
    SELECT * FROM fx_transaction_lines
    WHERE transaction_id = p_transaction_id
    ORDER BY line_no
  LOOP
    IF v_line.account_id IS NULL THEN
      RAISE EXCEPTION 'Line % missing account_id', v_line.line_no;
    END IF;

    v_line_no := v_line_no + 1;
    INSERT INTO fx_journal_lines (
      journal_entry_id, line_no, account_id, currency_code,
      foreign_amount, rate_used, debit_pkr, credit_pkr, memo
    ) VALUES (
      v_entry_id, v_line_no, v_line.account_id, v_line.currency_code,
      v_line.foreign_amount, v_line.rate_used, v_line.debit_pkr, v_line.credit_pkr, v_line.memo
    );
  END LOOP;

  PERFORM fx_assert_journal_balanced(v_entry_id);
  RETURN v_entry_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_post_transaction — full posting with journal
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_post_transaction(p_transaction_id UUID)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_journal_id UUID;
  v_allowed_types TEXT[] := ARRAY[
    'opening_balance', 'account_transfer', 'expense', 'currency_buy', 'currency_sell'
  ];
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_post_fx_transaction';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transaction not found: %', p_transaction_id;
  END IF;

  IF NOT fx_same_branch(v_tx.branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  IF v_tx.status <> 'draft' THEN
    RAISE EXCEPTION 'Only draft transactions can be posted';
  END IF;

  IF NOT (v_tx.transaction_type::TEXT = ANY (v_allowed_types)) THEN
    RAISE EXCEPTION 'Transaction type % not enabled in Phase 3', v_tx.transaction_type;
  END IF;

  IF fx_is_day_closed(v_tx.branch_id, v_tx.transaction_date) THEN
    RAISE EXCEPTION 'Day is closed. Posting requires admin approval.';
  END IF;

  IF v_tx.transaction_no IS NULL OR v_tx.transaction_no = '' THEN
    v_tx.transaction_no := fx_generate_transaction_no(v_tx.branch_id);
  END IF;

  v_journal_id := fx_build_journal_from_transaction(p_transaction_id);

  UPDATE fx_transactions
  SET
    status = 'posted',
    transaction_no = v_tx.transaction_no,
    posted_at = NOW(),
    posted_by = auth.uid(),
    updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, new_value, actor_id)
  VALUES (
    v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'posted',
    jsonb_build_object('transaction', to_jsonb(v_tx), 'journal_entry_id', v_journal_id),
    auth.uid()
  );

  RETURN v_tx;
END;
$$;

-- ---------------------------------------------------------------------------
-- Cash balances for dashboard (asset cash accounts 1110–1150)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_cash_balances(p_branch_id UUID)
RETURNS TABLE (
  account_code TEXT,
  account_name TEXT,
  currency_code TEXT,
  balance_pkr NUMERIC,
  foreign_balance NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') AND NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT
    a.code,
    a.name,
    COALESCE(c.code, jl.currency_code, 'PKR') AS currency_code,
    COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0) AS balance_pkr,
    COALESCE(SUM(
      CASE
        WHEN jl.debit_pkr > 0 THEN jl.foreign_amount
        WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount
        ELSE 0
      END
    ), 0) AS foreign_balance
  FROM fx_accounts a
  LEFT JOIN fx_currencies c ON c.id = a.currency_id
  LEFT JOIN fx_journal_lines jl ON jl.account_id = a.id
  LEFT JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    AND je.branch_id = p_branch_id
    AND NOT je.is_void
  WHERE a.company_id = (SELECT company_id FROM fx_branches WHERE id = p_branch_id)
    AND a.code IN ('1110', '1120', '1130', '1140', '1150')
  GROUP BY a.code, a.name, c.code, jl.currency_code
  HAVING COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0) <> 0
     OR COALESCE(SUM(
       CASE WHEN jl.debit_pkr > 0 THEN jl.foreign_amount WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount ELSE 0 END
     ), 0) <> 0
  ORDER BY a.code;
END;
$$;

-- Trial balance with net column; hide all-zero rows
CREATE OR REPLACE FUNCTION fx_get_trial_balance(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  account_code TEXT,
  account_name TEXT,
  debit_pkr NUMERIC,
  credit_pkr NUMERIC,
  net_pkr NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN
    RAISE EXCEPTION 'Missing permission: can_view_fx_reports';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT
    a.code,
    a.name,
    COALESCE(SUM(jl.debit_pkr), 0) AS debit_pkr,
    COALESCE(SUM(jl.credit_pkr), 0) AS credit_pkr,
    COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0) AS net_pkr
  FROM fx_accounts a
  LEFT JOIN fx_journal_lines jl ON jl.account_id = a.id
  LEFT JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    AND je.branch_id = p_branch_id
    AND je.entry_date <= p_as_of
    AND NOT je.is_void
  WHERE a.company_id = (SELECT company_id FROM fx_branches WHERE id = p_branch_id)
  GROUP BY a.code, a.name
  HAVING COALESCE(SUM(jl.debit_pkr), 0) <> 0 OR COALESCE(SUM(jl.credit_pkr), 0) <> 0
  ORDER BY a.code;
END;
$$;

CREATE OR REPLACE FUNCTION fx_get_trial_balance_totals(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (total_debit NUMERIC, total_credit NUMERIC, is_balanced BOOLEAN)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_debit NUMERIC;
  v_credit NUMERIC;
BEGIN
  SELECT COALESCE(SUM(t.debit_pkr), 0), COALESCE(SUM(t.credit_pkr), 0)
  INTO v_debit, v_credit
  FROM fx_get_trial_balance(p_branch_id, p_as_of) t;

  RETURN QUERY SELECT v_debit, v_credit, (v_debit = v_credit);
END;
$$;

GRANT EXECUTE ON FUNCTION fx_generate_entry_no(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_account_id_by_code(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_validate_transaction_lines_balanced(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_build_journal_from_transaction(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_cash_balances(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_trial_balance_totals(UUID, DATE) TO authenticated;
-- <<<<< END 202606110001_fx_posting_engine.sql

-- >>>>> BEGIN 202606120001_fx_edit_delete_engine.sql
-- Phase 4: Complete edit/delete — void linked journals, audit trail
-- Project: ygidlcqhupmxvsdjmvnf only (fx_* tables)

-- Void all active journal entries for a posted transaction
CREATE OR REPLACE FUNCTION fx_void_journals_for_transaction(p_transaction_id UUID)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT;
BEGIN
  UPDATE fx_journal_entries
  SET
    is_void = TRUE,
    voided_at = NOW(),
    voided_by = auth.uid(),
    updated_at = NOW()
  WHERE transaction_id = p_transaction_id
    AND NOT is_void;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_delete_transaction — draft hard delete; posted soft void + journal void
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_delete_transaction(
  p_transaction_id UUID,
  p_reason TEXT
)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_voided INT;
BEGIN
  IF NOT fx_has_permission('can_delete_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_delete_fx_transaction';
  END IF;

  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required for delete/void';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found'; END IF;
  IF NOT fx_same_branch(v_tx.branch_id) THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  IF v_tx.status = 'draft' THEN
    DELETE FROM fx_transactions WHERE id = p_transaction_id;
    INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, reason, old_value, actor_id)
    VALUES (v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'deleted', p_reason, to_jsonb(v_tx), auth.uid());
    RETURN v_tx;
  END IF;

  IF v_tx.is_deleted OR v_tx.status = 'voided' THEN
    RAISE EXCEPTION 'Transaction already voided';
  END IF;

  IF fx_is_day_closed(v_tx.branch_id, v_tx.transaction_date) THEN
    RAISE EXCEPTION 'Day is closed. Delete requires admin approval.';
  END IF;

  v_voided := fx_void_journals_for_transaction(p_transaction_id);

  UPDATE fx_transactions
  SET
    status = 'voided',
    is_deleted = TRUE,
    voided_at = NOW(),
    voided_by = auth.uid(),
    delete_reason = p_reason,
    updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, reason, old_value, new_value, actor_id)
  VALUES (
    v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'deleted', p_reason,
    NULL,
    jsonb_build_object('transaction', to_jsonb(v_tx), 'journals_voided', v_voided),
    auth.uid()
  );

  RETURN v_tx;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_edit_transaction — metadata edit on posted (description/date/notes)
-- Line/journal repost deferred to Phase 4B
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_edit_transaction(
  p_transaction_id UUID,
  p_payload JSONB,
  p_reason TEXT
)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_old JSONB;
  v_new_version INT;
BEGIN
  IF NOT fx_has_permission('can_edit_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_edit_fx_transaction';
  END IF;

  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required for editing posted transactions';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found'; END IF;
  IF NOT fx_same_branch(v_tx.branch_id) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF v_tx.is_deleted OR v_tx.status = 'voided' THEN
    RAISE EXCEPTION 'Cannot edit voided transaction';
  END IF;
  IF v_tx.status = 'draft' THEN
    RAISE EXCEPTION 'Use client draft update for draft transactions';
  END IF;

  IF fx_is_day_closed(v_tx.branch_id, v_tx.transaction_date) THEN
    RAISE EXCEPTION 'Day is closed. Edit requires admin approval.';
  END IF;

  v_old := to_jsonb(v_tx);
  v_new_version := v_tx.version + 1;

  INSERT INTO fx_transaction_versions (transaction_id, version, snapshot, change_reason, changed_by)
  VALUES (v_tx.id, v_tx.version, v_old, p_reason, auth.uid());

  UPDATE fx_transactions
  SET
    transaction_date = COALESCE((p_payload->>'transaction_date')::DATE, transaction_date),
    description = COALESCE(NULLIF(p_payload->>'description', ''), description),
    notes = COALESCE(NULLIF(p_payload->>'notes', ''), notes),
    version = v_new_version,
    updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  -- Sync journal entry header description/date when present
  UPDATE fx_journal_entries
  SET
    entry_date = v_tx.transaction_date,
    description = COALESCE(v_tx.description, description),
    updated_at = NOW()
  WHERE transaction_id = p_transaction_id
    AND NOT is_void;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, reason, old_value, new_value, actor_id)
  VALUES (v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'edited', p_reason, v_old, to_jsonb(v_tx), auth.uid());

  RETURN v_tx;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_void_journals_for_transaction(UUID) TO authenticated;
-- <<<<< END 202606120001_fx_edit_delete_engine.sql

-- >>>>> BEGIN 202606120002_fx_fix_number_sequences.sql
-- Fix transaction/journal number generation — sequence overflow on ::INT cast
-- Bug: stripping all non-digits from '20260609-00001' → 2026060900001 (> INT max)
-- Project: ygidlcqhupmxvsdjmvnf only

CREATE OR REPLACE FUNCTION fx_generate_transaction_no(p_branch_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prefix TEXT;
  v_seq INT;
BEGIN
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  v_prefix := TO_CHAR(NOW(), 'YYYYMMDD');

  SELECT COALESCE(MAX((regexp_match(transaction_no, '-(\d+)$'))[1]::INT), 0) + 1
  INTO v_seq
  FROM fx_transactions
  WHERE branch_id = p_branch_id
    AND transaction_no LIKE v_prefix || '-%';

  RETURN v_prefix || '-' || LPAD(v_seq::TEXT, 5, '0');
END;
$$;

CREATE OR REPLACE FUNCTION fx_generate_entry_no(p_branch_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prefix TEXT;
  v_seq INT;
BEGIN
  v_prefix := TO_CHAR(NOW(), 'YYYYMMDD');

  SELECT COALESCE(MAX((regexp_match(entry_no, '-(\d+)$'))[1]::INT), 0) + 1
  INTO v_seq
  FROM fx_journal_entries
  WHERE branch_id = p_branch_id
    AND entry_no LIKE v_prefix || '-JE-%';

  RETURN v_prefix || '-JE-' || LPAD(v_seq::TEXT, 5, '0');
END;
$$;
-- <<<<< END 202606120002_fx_fix_number_sequences.sql

-- >>>>> BEGIN 202606130001_fx_reports_and_closing.sql
-- Phase 5: Reports engine + daily closing lines
-- Project: ygidlcqhupmxvsdjmvnf only

DROP FUNCTION IF EXISTS fx_get_profit_and_loss(UUID, DATE, DATE);
DROP FUNCTION IF EXISTS fx_get_balance_sheet(UUID, DATE);
DROP FUNCTION IF EXISTS fx_get_currency_position(UUID, DATE);
DROP FUNCTION IF EXISTS fx_close_day(UUID, DATE, TEXT);
DROP FUNCTION IF EXISTS fx_is_day_closed(UUID, DATE);

-- ---------------------------------------------------------------------------
-- General Ledger
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_general_ledger(
  p_branch_id UUID,
  p_from DATE DEFAULT date_trunc('month', CURRENT_DATE)::DATE,
  p_to DATE DEFAULT CURRENT_DATE,
  p_account_code TEXT DEFAULT NULL
)
RETURNS TABLE (
  entry_date DATE,
  entry_no TEXT,
  account_code TEXT,
  account_name TEXT,
  description TEXT,
  debit_pkr NUMERIC,
  credit_pkr NUMERIC,
  currency_code TEXT,
  foreign_amount NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN
    RAISE EXCEPTION 'Missing permission: can_view_fx_reports';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT
    je.entry_date,
    je.entry_no,
    a.code,
    a.name,
    COALESCE(jl.memo, je.description),
    jl.debit_pkr,
    jl.credit_pkr,
    jl.currency_code,
    jl.foreign_amount
  FROM fx_journal_entries je
  JOIN fx_journal_lines jl ON jl.journal_entry_id = je.id
  JOIN fx_accounts a ON a.id = jl.account_id
  WHERE je.branch_id = p_branch_id
    AND NOT je.is_void
    AND je.entry_date BETWEEN p_from AND p_to
    AND (p_account_code IS NULL OR a.code = p_account_code)
  ORDER BY je.entry_date, je.entry_no, jl.line_no;
END;
$$;

-- ---------------------------------------------------------------------------
-- Profit & Loss (income + expense leaf accounts)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_profit_and_loss(
  p_branch_id UUID,
  p_from DATE,
  p_to DATE
)
RETURNS TABLE (account_code TEXT, account_name TEXT, account_type TEXT, amount_pkr NUMERIC)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT
    a.code,
    a.name,
    a.account_type::TEXT,
    CASE
      WHEN a.account_type = 'income' THEN COALESCE(SUM(jl.credit_pkr - jl.debit_pkr), 0)
      ELSE COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0)
    END AS amount_pkr
  FROM fx_accounts a
  LEFT JOIN fx_journal_lines jl ON jl.account_id = a.id
  LEFT JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    AND je.branch_id = p_branch_id
    AND je.entry_date BETWEEN p_from AND p_to
    AND NOT je.is_void
  WHERE a.company_id = (SELECT company_id FROM fx_branches WHERE id = p_branch_id)
    AND a.account_type IN ('income', 'expense')
    AND char_length(a.code) >= 4
  GROUP BY a.code, a.name, a.account_type
  HAVING COALESCE(SUM(jl.debit_pkr), 0) <> 0 OR COALESCE(SUM(jl.credit_pkr), 0) <> 0
  ORDER BY a.code;
END;
$$;

-- ---------------------------------------------------------------------------
-- Balance Sheet
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_balance_sheet(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (account_code TEXT, account_name TEXT, account_type TEXT, balance_pkr NUMERIC)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT
    a.code,
    a.name,
    a.account_type::TEXT,
    CASE
      WHEN a.account_type IN ('asset', 'expense') THEN COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0)
      ELSE COALESCE(SUM(jl.credit_pkr - jl.debit_pkr), 0)
    END AS balance_pkr
  FROM fx_accounts a
  LEFT JOIN fx_journal_lines jl ON jl.account_id = a.id
  LEFT JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    AND je.branch_id = p_branch_id
    AND je.entry_date <= p_as_of
    AND NOT je.is_void
  WHERE a.company_id = (SELECT company_id FROM fx_branches WHERE id = p_branch_id)
    AND a.account_type IN ('asset', 'liability', 'equity')
    AND char_length(a.code) >= 4
  GROUP BY a.code, a.name, a.account_type
  HAVING COALESCE(SUM(jl.debit_pkr), 0) <> 0 OR COALESCE(SUM(jl.credit_pkr), 0) <> 0
  ORDER BY a.code;
END;
$$;

-- ---------------------------------------------------------------------------
-- Currency Position
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_currency_position(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (currency_code TEXT, foreign_balance NUMERIC, base_equivalent_pkr NUMERIC)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT
    jl.currency_code,
    COALESCE(SUM(
      CASE
        WHEN jl.debit_pkr > 0 THEN jl.foreign_amount
        WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount
        ELSE 0
      END
    ), 0) AS foreign_balance,
    COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0) AS base_equivalent_pkr
  FROM fx_journal_lines jl
  JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
  JOIN fx_accounts a ON a.id = jl.account_id
  WHERE je.branch_id = p_branch_id
    AND NOT je.is_void
    AND je.entry_date <= p_as_of
    AND a.code IN ('1110', '1120', '1130', '1140', '1150')
  GROUP BY jl.currency_code
  HAVING COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0) <> 0
      OR COALESCE(SUM(
        CASE WHEN jl.debit_pkr > 0 THEN jl.foreign_amount WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount ELSE 0 END
      ), 0) <> 0
  ORDER BY jl.currency_code;
END;
$$;

-- ---------------------------------------------------------------------------
-- Closing preview + enhanced fx_close_day
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_closing_preview(
  p_branch_id UUID,
  p_closing_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  account_code TEXT,
  account_name TEXT,
  currency_code TEXT,
  system_balance NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_close_day') AND NOT fx_has_permission('can_view_fx_reports') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  SELECT cb.account_code, cb.account_name, cb.currency_code, cb.foreign_balance
  FROM fx_get_cash_balances(p_branch_id) cb;
END;
$$;

CREATE OR REPLACE FUNCTION fx_is_day_closed(p_branch_id UUID, p_date DATE)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM fx_daily_closings
    WHERE branch_id = p_branch_id
      AND closing_date = p_date
      AND status IN ('closed', 'approved')
  );
$$;

CREATE OR REPLACE FUNCTION fx_close_day(
  p_branch_id UUID,
  p_closing_date DATE,
  p_notes TEXT DEFAULT NULL
)
RETURNS fx_daily_closings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_closing fx_daily_closings;
  v_row RECORD;
BEGIN
  IF NOT fx_has_permission('can_close_day') THEN
    RAISE EXCEPTION 'Missing permission: can_close_day';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  INSERT INTO fx_daily_closings (company_id, branch_id, closing_date, status, notes, closed_by, closed_at)
  SELECT b.company_id, p_branch_id, p_closing_date, 'closed', p_notes, auth.uid(), NOW()
  FROM fx_branches b WHERE b.id = p_branch_id
  ON CONFLICT (branch_id, closing_date)
  DO UPDATE SET status = 'closed', notes = EXCLUDED.notes, closed_by = auth.uid(), closed_at = NOW(), updated_at = NOW()
  RETURNING * INTO v_closing;

  DELETE FROM fx_closing_lines WHERE daily_closing_id = v_closing.id;

  FOR v_row IN
    SELECT a.id AS account_id, cb.currency_code, cb.foreign_balance AS system_balance
    FROM fx_get_cash_balances(p_branch_id) cb
    JOIN fx_accounts a ON a.code = cb.account_code
      AND a.company_id = v_closing.company_id
  LOOP
    INSERT INTO fx_closing_lines (daily_closing_id, account_id, currency_code, system_balance, difference)
    VALUES (v_closing.id, v_row.account_id, v_row.currency_code, v_row.system_balance, 0);
  END LOOP;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, actor_id)
  VALUES (v_closing.company_id, v_closing.branch_id, 'fx_daily_closings', v_closing.id, 'closed_day', auth.uid());

  RETURN v_closing;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_get_general_ledger(UUID, DATE, DATE, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_closing_preview(UUID, DATE) TO authenticated;
-- <<<<< END 202606130001_fx_reports_and_closing.sql

-- >>>>> BEGIN 202606130002_fx_report_rpc_grants.sql
-- Re-grant report RPCs after signature changes in 202606130001

GRANT EXECUTE ON FUNCTION fx_get_profit_and_loss(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_balance_sheet(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_currency_position(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_is_day_closed(UUID, DATE) TO authenticated;
-- <<<<< END 202606130002_fx_report_rpc_grants.sql

-- >>>>> BEGIN 202606140001_fx_manual_journal_repost_restore_attachments.sql
-- Manual journal, repost transaction, restore with journal repost, attachments storage bucket

-- ---------------------------------------------------------------------------
-- fx_post_manual_journal
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_post_manual_journal(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_branch_id UUID := (p_payload->>'branch_id')::UUID;
  v_company_id UUID := (p_payload->>'company_id')::UUID;
  v_entry_date DATE := COALESCE((p_payload->>'entry_date')::DATE, CURRENT_DATE);
  v_description TEXT := NULLIF(p_payload->>'description', '');
  v_entry_id UUID;
  v_line JSONB;
  v_line_no INT := 0;
  v_debit NUMERIC(20, 8) := 0;
  v_credit NUMERIC(20, 8) := 0;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_post_fx_transaction';
  END IF;
  IF NOT fx_same_branch(v_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;
  IF fx_is_day_closed(v_branch_id, v_entry_date) THEN
    RAISE EXCEPTION 'Day is closed';
  END IF;

  FOR v_line IN SELECT * FROM jsonb_array_elements(COALESCE(p_payload->'lines', '[]'::JSONB))
  LOOP
    v_debit := v_debit + COALESCE((v_line->>'debit_pkr')::NUMERIC, 0);
    v_credit := v_credit + COALESCE((v_line->>'credit_pkr')::NUMERIC, 0);
  END LOOP;

  IF v_debit <> v_credit OR v_debit = 0 THEN
    RAISE EXCEPTION 'Manual journal lines not balanced: debit=% credit=%', v_debit, v_credit;
  END IF;

  INSERT INTO fx_journal_entries (
    company_id, branch_id, transaction_id, entry_no, entry_date, description, posted_by
  ) VALUES (
    v_company_id, v_branch_id, NULL, fx_generate_entry_no(v_branch_id), v_entry_date,
    COALESCE(v_description, 'Manual journal'), auth.uid()
  )
  RETURNING id INTO v_entry_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_payload->'lines')
  LOOP
    v_line_no := v_line_no + 1;
    INSERT INTO fx_journal_lines (
      journal_entry_id, line_no, account_id, currency_code,
      foreign_amount, rate_used, debit_pkr, credit_pkr, memo
    ) VALUES (
      v_entry_id,
      COALESCE((v_line->>'line_no')::INT, v_line_no),
      (v_line->>'account_id')::UUID,
      v_line->>'currency_code',
      COALESCE((v_line->>'foreign_amount')::NUMERIC, 0),
      COALESCE((v_line->>'rate_used')::NUMERIC, 1),
      COALESCE((v_line->>'debit_pkr')::NUMERIC, 0),
      COALESCE((v_line->>'credit_pkr')::NUMERIC, 0),
      NULLIF(v_line->>'memo', '')
    );
  END LOOP;

  PERFORM fx_assert_journal_balanced(v_entry_id);

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, actor_id)
  VALUES (v_company_id, v_branch_id, 'fx_journal_entries', v_entry_id, 'posted', auth.uid());

  RETURN v_entry_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_repost_transaction — void journals, replace lines, rebuild journal
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_repost_transaction(
  p_transaction_id UUID,
  p_reason TEXT,
  p_lines JSONB,
  p_currency_code TEXT,
  p_foreign_amount NUMERIC,
  p_rate_used NUMERIC,
  p_base_amount_pkr NUMERIC,
  p_description TEXT DEFAULT NULL
)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_old JSONB;
  v_line JSONB;
  v_line_no INT := 0;
  v_voided INT;
BEGIN
  IF NOT fx_has_permission('can_edit_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_edit_fx_transaction';
  END IF;
  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found'; END IF;
  IF NOT fx_same_branch(v_tx.branch_id) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  IF v_tx.status <> 'posted' OR v_tx.is_deleted THEN
    RAISE EXCEPTION 'Only posted transactions can be reposted';
  END IF;
  IF fx_is_day_closed(v_tx.branch_id, v_tx.transaction_date) THEN
    RAISE EXCEPTION 'Day is closed';
  END IF;

  v_old := to_jsonb(v_tx);
  v_voided := fx_void_journals_for_transaction(p_transaction_id);

  UPDATE fx_transactions
  SET
    currency_code = p_currency_code,
    total_foreign_amount = p_foreign_amount,
    rate_used = p_rate_used,
    total_base_amount_pkr = p_base_amount_pkr,
    description = COALESCE(NULLIF(p_description, ''), description),
    version = version + 1,
    updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  DELETE FROM fx_transaction_lines WHERE transaction_id = p_transaction_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines)
  LOOP
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (
      transaction_id, line_no, account_id, currency_code,
      foreign_amount, rate_used, base_amount_pkr, debit_pkr, credit_pkr, memo
    ) VALUES (
      p_transaction_id,
      COALESCE((v_line->>'line_no')::INT, v_line_no),
      (v_line->>'account_id')::UUID,
      v_line->>'currency_code',
      COALESCE((v_line->>'foreign_amount')::NUMERIC, 0),
      COALESCE((v_line->>'rate_used')::NUMERIC, 1),
      COALESCE((v_line->>'base_amount_pkr')::NUMERIC, 0),
      COALESCE((v_line->>'debit_pkr')::NUMERIC, 0),
      COALESCE((v_line->>'credit_pkr')::NUMERIC, 0),
      NULLIF(v_line->>'memo', '')
    );
  END LOOP;

  PERFORM fx_validate_transaction_lines_balanced(p_transaction_id);
  PERFORM fx_build_journal_from_transaction(p_transaction_id);

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, reason, old_value, new_value, actor_id)
  VALUES (
    v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'edited', p_reason,
    jsonb_build_object('transaction', v_old, 'journals_voided', v_voided),
    to_jsonb(v_tx),
    auth.uid()
  );

  RETURN v_tx;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_restore_deleted_transaction — restore status + repost journal if missing
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_restore_deleted_transaction(p_transaction_id UUID, p_reason TEXT)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_active_journal INT;
BEGIN
  IF NOT fx_has_permission('can_edit_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission';
  END IF;
  IF p_reason IS NULL OR trim(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason is required';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found'; END IF;
  IF NOT fx_same_branch(v_tx.branch_id) THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  UPDATE fx_transactions
  SET is_deleted = FALSE, status = 'posted', voided_at = NULL, voided_by = NULL,
      delete_reason = NULL, updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  SELECT COUNT(*) INTO v_active_journal
  FROM fx_journal_entries
  WHERE transaction_id = p_transaction_id AND NOT is_void;

  IF v_active_journal = 0 THEN
    PERFORM fx_validate_transaction_lines_balanced(p_transaction_id);
    PERFORM fx_build_journal_from_transaction(p_transaction_id);
  END IF;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, reason, actor_id)
  VALUES (v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'restored', p_reason, auth.uid());

  RETURN v_tx;
END;
$$;

-- ---------------------------------------------------------------------------
-- Storage bucket for attachments
-- ---------------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'fx-attachments',
  'fx-attachments',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']::TEXT[]
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS fx_attachments_storage_select ON storage.objects;
CREATE POLICY fx_attachments_storage_select ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'fx-attachments');

DROP POLICY IF EXISTS fx_attachments_storage_insert ON storage.objects;
CREATE POLICY fx_attachments_storage_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'fx-attachments');

DROP POLICY IF EXISTS fx_attachments_storage_delete ON storage.objects;
CREATE POLICY fx_attachments_storage_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'fx-attachments');

GRANT EXECUTE ON FUNCTION fx_post_manual_journal(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_repost_transaction(UUID, TEXT, JSONB, TEXT, NUMERIC, NUMERIC, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_restore_deleted_transaction(UUID, TEXT) TO authenticated;
-- <<<<< END 202606140001_fx_manual_journal_repost_restore_attachments.sql

-- >>>>> BEGIN 202606150001_fx_post_all_transaction_types.sql
-- Enable posting for all transaction types supported by draft line builder
-- Project: ygidlcqhupmxvsdjmvnf only (fx_* tables)

CREATE OR REPLACE FUNCTION fx_post_transaction(p_transaction_id UUID)
RETURNS fx_transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx fx_transactions;
  v_journal_id UUID;
  v_allowed_types TEXT[] := ARRAY[
    'opening_balance', 'account_transfer', 'expense',
    'currency_buy', 'currency_sell', 'cross_currency',
    'settlement_send', 'settlement_receive',
    'revaluation', 'daily_closing_adjustment'
  ];
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Missing permission: can_post_fx_transaction';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transaction not found: %', p_transaction_id;
  END IF;

  IF NOT fx_same_branch(v_tx.branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  IF v_tx.status <> 'draft' THEN
    RAISE EXCEPTION 'Only draft transactions can be posted';
  END IF;

  IF NOT (v_tx.transaction_type::TEXT = ANY (v_allowed_types)) THEN
    RAISE EXCEPTION 'Transaction type % not enabled for posting', v_tx.transaction_type;
  END IF;

  IF fx_is_day_closed(v_tx.branch_id, v_tx.transaction_date) THEN
    RAISE EXCEPTION 'Day is closed. Posting requires admin approval.';
  END IF;

  IF v_tx.transaction_no IS NULL OR v_tx.transaction_no = '' THEN
    v_tx.transaction_no := fx_generate_transaction_no(v_tx.branch_id);
  END IF;

  v_journal_id := fx_build_journal_from_transaction(p_transaction_id);

  UPDATE fx_transactions
  SET
    status = 'posted',
    transaction_no = v_tx.transaction_no,
    posted_at = NOW(),
    posted_by = auth.uid(),
    updated_at = NOW()
  WHERE id = p_transaction_id
  RETURNING * INTO v_tx;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, new_value, actor_id)
  VALUES (
    v_tx.company_id, v_tx.branch_id, 'fx_transactions', v_tx.id, 'posted',
    jsonb_build_object('transaction', to_jsonb(v_tx), 'journal_entry_id', v_journal_id),
    auth.uid()
  );

  RETURN v_tx;
END;
$$;
-- <<<<< END 202606150001_fx_post_all_transaction_types.sql

-- >>>>> BEGIN 202606160001_fx_currency_crud_exchange_group.sql
-- Currency CRUD RPC + exchange_group_id for chained exchange wizard

ALTER TABLE fx_transactions
  ADD COLUMN IF NOT EXISTS exchange_group_id UUID;

CREATE INDEX IF NOT EXISTS idx_fx_transactions_exchange_group
  ON fx_transactions (exchange_group_id)
  WHERE exchange_group_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- fx_create_currency — insert currency + cash COA account for caller's company
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_create_currency(
  p_code TEXT,
  p_name TEXT,
  p_symbol TEXT DEFAULT '',
  p_decimal_places INT DEFAULT 2
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_company UUID;
  v_assets UUID;
  v_currency_id UUID;
  v_account_code TEXT;
  v_candidate INT;
  v_code_upper TEXT := UPPER(TRIM(p_code));
BEGIN
  IF NOT fx_has_permission('can_manage_chart_of_accounts') THEN
    RAISE EXCEPTION 'Permission denied: can_manage_chart_of_accounts required';
  END IF;

  IF v_code_upper = 'PKR' THEN
    RAISE EXCEPTION 'PKR is the base currency and cannot be added again';
  END IF;

  IF LENGTH(v_code_upper) < 2 OR LENGTH(v_code_upper) > 5 THEN
    RAISE EXCEPTION 'Currency code must be 2–5 characters';
  END IF;

  SELECT company_id INTO v_company
  FROM fx_users_profiles
  WHERE id = auth.uid() AND is_active = TRUE;

  IF v_company IS NULL THEN
    RAISE EXCEPTION 'User profile not configured';
  END IF;

  IF EXISTS (SELECT 1 FROM fx_currencies WHERE code = v_code_upper) THEN
    RAISE EXCEPTION 'Currency % already exists', v_code_upper;
  END IF;

  INSERT INTO fx_currencies (code, name, symbol, decimal_places, is_base, is_active)
  VALUES (v_code_upper, TRIM(p_name), COALESCE(NULLIF(TRIM(p_symbol), ''), v_code_upper), p_decimal_places, FALSE, TRUE)
  RETURNING id INTO v_currency_id;

  SELECT id INTO v_assets FROM fx_accounts WHERE company_id = v_company AND code = '1000';
  IF v_assets IS NULL THEN
    RAISE EXCEPTION 'Assets parent account (1000) not found for company';
  END IF;

  -- Next cash account code: prefer 1151–1159, then 1181–1189
  v_account_code := NULL;
  FOR v_candidate IN 1151..1159 LOOP
    IF NOT EXISTS (
      SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = v_candidate::TEXT
    ) THEN
      v_account_code := v_candidate::TEXT;
      EXIT;
    END IF;
  END LOOP;

  IF v_account_code IS NULL THEN
    FOR v_candidate IN 1181..1189 LOOP
      IF NOT EXISTS (
        SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = v_candidate::TEXT
      ) THEN
        v_account_code := v_candidate::TEXT;
        EXIT;
      END IF;
    END LOOP;
  END IF;

  IF v_account_code IS NULL THEN
    RAISE EXCEPTION 'No available cash account code slot for new currency';
  END IF;

  INSERT INTO fx_accounts (company_id, code, name, account_type, currency_id, parent_id)
  VALUES (
    v_company,
    v_account_code,
    'Cash ' || v_code_upper,
    'asset',
    v_currency_id,
    v_assets
  );

  RETURN jsonb_build_object(
    'currency_id', v_currency_id,
    'code', v_code_upper,
    'account_code', v_account_code
  );
END;
$$;

GRANT EXECUTE ON FUNCTION fx_create_currency(TEXT, TEXT, TEXT, INT) TO authenticated;

-- ---------------------------------------------------------------------------
-- fx_deactivate_currency — soft-disable (no delete if used)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_deactivate_currency(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code_upper TEXT := UPPER(TRIM(p_code));
BEGIN
  IF NOT fx_has_permission('can_manage_chart_of_accounts') THEN
    RAISE EXCEPTION 'Permission denied: can_manage_chart_of_accounts required';
  END IF;

  IF v_code_upper = 'PKR' THEN
    RAISE EXCEPTION 'Cannot deactivate base currency PKR';
  END IF;

  UPDATE fx_currencies SET is_active = FALSE, updated_at = NOW()
  WHERE code = v_code_upper AND is_base = FALSE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Currency % not found or is base currency', v_code_upper;
  END IF;

  RETURN jsonb_build_object('code', v_code_upper, 'is_active', FALSE);
END;
$$;

GRANT EXECUTE ON FUNCTION fx_deactivate_currency(TEXT) TO authenticated;
-- <<<<< END 202606160001_fx_currency_crud_exchange_group.sql

-- >>>>> BEGIN 202606170001_fx_deals_workflow.sql
-- FX Deals workflow: customer order first, multi-agent sourcing, commitment tracking
-- Cloud only: ygidlcqhupmxvsdjmvnf — do NOT apply to old ERP/VPS
-- COA: 1160 Customer Advances, 1170 Delivery Clearing, 2310 Agent Settlement, 2320 Cross-Currency
-- RMB = CNY (1140); allow_short_position default false

-- ---------------------------------------------------------------------------
-- Enums (idempotent — safe after partial SQL Editor apply)
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  DO $$ BEGIN
CREATE TYPE fx_deal_status AS ENUM (
    'draft', 'quoted', 'booked', 'customer_partially_paid', 'customer_paid',
    'sourcing_required', 'sourcing_in_progress', 'agent_partially_paid', 'agent_paid',
    'currency_received', 'delivered', 'completed', 'cancelled', 'voided'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  DO $$ BEGIN
CREATE TYPE fx_deal_leg_type AS ENUM (
    'customer_order', 'customer_payment', 'sourcing_requirement', 'agent_source',
    'cross_currency_source', 'agent_payment', 'currency_receipt', 'delivery', 'adjustment'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  DO $$ BEGIN
CREATE TYPE fx_deal_leg_status AS ENUM (
    'pending', 'partial', 'completed', 'failed', 'reversed'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  DO $$ BEGIN
CREATE TYPE fx_delivery_method AS ENUM (
    'own_balance', 'agent', 'tt', 'later'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  DO $$ BEGIN
CREATE TYPE fx_commitment_type AS ENUM (
    'customer_sale', 'sourcing_required', 'on_order_inbound'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  DO $$ BEGIN
CREATE TYPE fx_delivery_target AS ENUM (
    'our_account', 'direct_to_customer', 'tt'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  DO $$ BEGIN
CREATE TYPE fx_settlement_link_type AS ENUM (
    'aed_to_agent', 'pkr_settlement', 'tt_reference'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fx_deals (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id              UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id               UUID NOT NULL REFERENCES fx_branches (id) ON DELETE RESTRICT,
  deal_no                 TEXT,
  customer_party_id       UUID NOT NULL REFERENCES fx_parties (id) ON DELETE RESTRICT,
  sell_currency_code      TEXT NOT NULL,
  sell_amount             NUMERIC(20, 8) NOT NULL,
  sale_rate_pkr           NUMERIC(20, 8) NOT NULL,
  customer_payable_pkr    NUMERIC(20, 8) NOT NULL,
  customer_paid_pkr       NUMERIC(20, 8) NOT NULL DEFAULT 0,
  customer_receivable_pkr NUMERIC(20, 8) NOT NULL DEFAULT 0,
  delivery_method         fx_delivery_method NOT NULL DEFAULT 'later',
  status                  fx_deal_status NOT NULL DEFAULT 'draft',
  estimated_profit_pkr    NUMERIC(20, 8),
  actual_profit_pkr       NUMERIC(20, 8),
  cost_basis_pkr          NUMERIC(20, 8),
  allow_short_position    BOOLEAN NOT NULL DEFAULT FALSE,
  notes                   TEXT,
  booked_at               TIMESTAMPTZ,
  completed_at            TIMESTAMPTZ,
  cancelled_at            TIMESTAMPTZ,
  created_by              UUID REFERENCES auth.users (id),
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (branch_id, deal_no)
);

CREATE TABLE IF NOT EXISTS fx_deal_legs (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id                 UUID NOT NULL REFERENCES fx_deals (id) ON DELETE CASCADE,
  leg_no                  INT NOT NULL,
  leg_type                fx_deal_leg_type NOT NULL,
  status                  fx_deal_leg_status NOT NULL DEFAULT 'pending',
  counterparty_party_id   UUID REFERENCES fx_parties (id) ON DELETE RESTRICT,
  receive_currency        TEXT,
  receive_amount          NUMERIC(20, 8) NOT NULL DEFAULT 0,
  pay_currency            TEXT,
  pay_amount              NUMERIC(20, 8) NOT NULL DEFAULT 0,
  rate_used               NUMERIC(20, 8),
  paid_amount             NUMERIC(20, 8) NOT NULL DEFAULT 0,
  remaining_amount        NUMERIC(20, 8) NOT NULL DEFAULT 0,
  delivery_target         fx_delivery_target,
  linked_transaction_id   UUID REFERENCES fx_transactions (id) ON DELETE SET NULL,
  parent_leg_id           UUID REFERENCES fx_deal_legs (id) ON DELETE SET NULL,
  proof_reference         TEXT,
  notes                   TEXT,
  completed_at            TIMESTAMPTZ,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (deal_id, leg_no)
);

CREATE TABLE IF NOT EXISTS fx_currency_commitments (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id           UUID NOT NULL REFERENCES fx_deals (id) ON DELETE CASCADE,
  leg_id            UUID REFERENCES fx_deal_legs (id) ON DELETE SET NULL,
  currency_code     TEXT NOT NULL,
  commitment_type   fx_commitment_type NOT NULL,
  committed_amount  NUMERIC(20, 8) NOT NULL DEFAULT 0,
  sourced_amount    NUMERIC(20, 8) NOT NULL DEFAULT 0,
  delivered_amount  NUMERIC(20, 8) NOT NULL DEFAULT 0,
  released_amount   NUMERIC(20, 8) NOT NULL DEFAULT 0,
  is_open           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fx_settlement_links (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id         UUID NOT NULL REFERENCES fx_deals (id) ON DELETE CASCADE,
  from_leg_id     UUID NOT NULL REFERENCES fx_deal_legs (id) ON DELETE CASCADE,
  to_leg_id       UUID NOT NULL REFERENCES fx_deal_legs (id) ON DELETE CASCADE,
  link_type       fx_settlement_link_type NOT NULL,
  currency_code   TEXT NOT NULL,
  amount          NUMERIC(20, 8) NOT NULL,
  status          fx_deal_leg_status NOT NULL DEFAULT 'pending',
  proof_reference TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE fx_transactions
  ADD COLUMN IF NOT EXISTS deal_id UUID REFERENCES fx_deals (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS leg_id UUID REFERENCES fx_deal_legs (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_fx_deals_branch_status ON fx_deals (branch_id, status);
CREATE INDEX IF NOT EXISTS idx_fx_deal_legs_deal ON fx_deal_legs (deal_id, leg_no);
CREATE INDEX IF NOT EXISTS idx_fx_commitments_currency ON fx_currency_commitments (currency_code, is_open);
CREATE INDEX IF NOT EXISTS idx_fx_transactions_deal ON fx_transactions (deal_id) WHERE deal_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- COA additions (idempotent per company)
-- ---------------------------------------------------------------------------

DO $$
DECLARE
  v_company UUID;
  v_assets UUID;
  v_liabilities UUID;
BEGIN
  FOR v_company IN SELECT id FROM fx_companies LOOP
    SELECT id INTO v_assets FROM fx_accounts WHERE company_id = v_company AND code = '1000' LIMIT 1;
    SELECT id INTO v_liabilities FROM fx_accounts WHERE company_id = v_company AND code = '2000' LIMIT 1;

    INSERT INTO fx_accounts (company_id, code, name, account_type, currency_id, parent_id)
    VALUES
      (v_company, '1160', 'Customer Advances', 'liability', NULL, v_liabilities),
      (v_company, '1170', 'FX Delivery Clearing', 'asset', NULL, v_assets),
      (v_company, '2310', 'Agent Settlement Clearing', 'liability', NULL, v_liabilities),
      (v_company, '2320', 'Cross-Currency Clearing', 'liability', NULL, v_liabilities)
    ON CONFLICT (company_id, code) DO NOTHING;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_normalize_currency_code(p_code TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE WHEN UPPER(TRIM(p_code)) IN ('RMB', 'CNY') THEN 'CNY' ELSE UPPER(TRIM(p_code)) END;
$$;

CREATE OR REPLACE FUNCTION fx_generate_deal_no(p_branch_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seq INT;
BEGIN
  SELECT COALESCE(MAX(
    NULLIF(regexp_replace(deal_no, '\D', '', 'g'), '')::INT
  ), 0) + 1
  INTO v_seq
  FROM fx_deals
  WHERE branch_id = p_branch_id;

  RETURN 'DL-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(v_seq::TEXT, 4, '0');
END;
$$;

CREATE OR REPLACE FUNCTION fx_deal_open_commitment(
  p_branch_id UUID,
  p_currency_code TEXT,
  p_commitment_type fx_commitment_type
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(SUM(
    c.committed_amount - c.sourced_amount - c.released_amount
  ), 0)
  FROM fx_currency_commitments c
  JOIN fx_deals d ON d.id = c.deal_id
  WHERE d.branch_id = p_branch_id
    AND c.is_open
    AND c.commitment_type = p_commitment_type
    AND fx_normalize_currency_code(c.currency_code) = fx_normalize_currency_code(p_currency_code);
$$;

CREATE OR REPLACE FUNCTION fx_deal_actual_balance(
  p_branch_id UUID,
  p_currency_code TEXT,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(SUM(
    CASE
      WHEN jl.debit_pkr > 0 THEN jl.foreign_amount
      WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount
      ELSE 0
    END
  ), 0)
  FROM fx_journal_lines jl
  JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
  JOIN fx_accounts a ON a.id = jl.account_id
  WHERE je.branch_id = p_branch_id
    AND NOT je.is_void
    AND je.entry_date <= p_as_of
    AND a.code IN ('1110', '1120', '1130', '1140', '1150')
    AND fx_normalize_currency_code(jl.currency_code) = fx_normalize_currency_code(p_currency_code);
$$;

-- ---------------------------------------------------------------------------
-- fx_get_currency_position_extended
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_currency_position_extended(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  currency_code TEXT,
  actual_balance NUMERIC,
  committed_balance NUMERIC,
  on_order_balance NUMERIC,
  required_balance NUMERIC,
  available_balance NUMERIC,
  base_equivalent_pkr NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  WITH currencies AS (
    SELECT DISTINCT fx_normalize_currency_code(c.code) AS code
    FROM fx_currencies c
    WHERE c.is_active
    UNION
    SELECT DISTINCT fx_normalize_currency_code(jl.currency_code)
    FROM fx_journal_lines jl
    JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    JOIN fx_accounts a ON a.id = jl.account_id
    WHERE je.branch_id = p_branch_id
      AND NOT je.is_void
      AND je.entry_date <= p_as_of
      AND a.code IN ('1110', '1120', '1130', '1140', '1150')
  ),
  actuals AS (
    SELECT
      fx_normalize_currency_code(jl.currency_code) AS code,
      COALESCE(SUM(
        CASE WHEN jl.debit_pkr > 0 THEN jl.foreign_amount WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount ELSE 0 END
      ), 0) AS actual_bal,
      COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0) AS pkr_eq
    FROM fx_journal_lines jl
    JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    JOIN fx_accounts a ON a.id = jl.account_id
    WHERE je.branch_id = p_branch_id
      AND NOT je.is_void
      AND je.entry_date <= p_as_of
      AND a.code IN ('1110', '1120', '1130', '1140', '1150')
    GROUP BY 1
  ),
  committed AS (
    SELECT
      fx_normalize_currency_code(c.currency_code) AS code,
      COALESCE(SUM(c.committed_amount - c.sourced_amount - c.released_amount), 0) AS amt
    FROM fx_currency_commitments c
    JOIN fx_deals d ON d.id = c.deal_id
    WHERE d.branch_id = p_branch_id
      AND c.is_open
      AND c.commitment_type = 'customer_sale'
    GROUP BY 1
  ),
  on_order AS (
    SELECT
      fx_normalize_currency_code(c.currency_code) AS code,
      COALESCE(SUM(c.committed_amount - c.sourced_amount - c.released_amount), 0) AS amt
    FROM fx_currency_commitments c
    JOIN fx_deals d ON d.id = c.deal_id
    WHERE d.branch_id = p_branch_id
      AND c.is_open
      AND c.commitment_type = 'on_order_inbound'
    GROUP BY 1
  )
  SELECT
    cur.code,
    COALESCE(a.actual_bal, 0),
    COALESCE(cm.amt, 0),
    COALESCE(oo.amt, 0),
    GREATEST(0, COALESCE(cm.amt, 0) - COALESCE(a.actual_bal, 0) - COALESCE(oo.amt, 0)),
    COALESCE(a.actual_bal, 0) - COALESCE(cm.amt, 0) + COALESCE(oo.amt, 0),
    COALESCE(a.pkr_eq, 0)
  FROM currencies cur
  LEFT JOIN actuals a ON a.code = cur.code
  LEFT JOIN committed cm ON cm.code = cur.code
  LEFT JOIN on_order oo ON oo.code = cur.code
  WHERE COALESCE(a.actual_bal, 0) <> 0
     OR COALESCE(cm.amt, 0) <> 0
     OR COALESCE(oo.amt, 0) <> 0
  ORDER BY cur.code;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_book_customer_deal
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_book_customer_deal(
  p_branch_id UUID,
  p_customer_party_id UUID,
  p_sell_currency_code TEXT,
  p_sell_amount NUMERIC,
  p_sale_rate_pkr NUMERIC,
  p_customer_paid_now_pkr NUMERIC DEFAULT 0,
  p_delivery_method fx_delivery_method DEFAULT 'later',
  p_allow_short_position BOOLEAN DEFAULT FALSE,
  p_notes TEXT DEFAULT NULL,
  p_auto_source BOOLEAN DEFAULT TRUE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_deal_id UUID;
  v_leg_id UUID;
  v_payable NUMERIC(20, 8);
  v_currency TEXT;
  v_available NUMERIC;
  v_required NUMERIC;
  v_status fx_deal_status;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_profile FROM fx_current_profile();
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  v_currency := fx_normalize_currency_code(p_sell_currency_code);
  v_payable := ROUND(p_sell_amount * p_sale_rate_pkr, 8);

  INSERT INTO fx_deals (
    company_id, branch_id, customer_party_id,
    sell_currency_code, sell_amount, sale_rate_pkr,
    customer_payable_pkr, customer_paid_pkr, customer_receivable_pkr,
    delivery_method, status, allow_short_position, notes,
    booked_at, created_by
  ) VALUES (
    v_profile.company_id, p_branch_id, p_customer_party_id,
    v_currency, p_sell_amount, p_sale_rate_pkr,
    v_payable, COALESCE(p_customer_paid_now_pkr, 0),
    GREATEST(0, v_payable - COALESCE(p_customer_paid_now_pkr, 0)),
    p_delivery_method,
    (CASE
      WHEN COALESCE(p_customer_paid_now_pkr, 0) >= v_payable THEN 'customer_paid'
      WHEN COALESCE(p_customer_paid_now_pkr, 0) > 0 THEN 'customer_partially_paid'
      ELSE 'booked'
    END)::fx_deal_status,
    COALESCE(p_allow_short_position, FALSE),
    p_notes,
    NOW(), auth.uid()
  )
  RETURNING id INTO v_deal_id;

  UPDATE fx_deals SET deal_no = fx_generate_deal_no(p_branch_id) WHERE id = v_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    remaining_amount, notes
  ) VALUES (
    v_deal_id, 1, 'customer_order'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, p_customer_party_id,
    v_currency, p_sell_amount, 'PKR', v_payable, p_sale_rate_pkr,
    0, 'Customer FX order booked'
  );

  INSERT INTO fx_currency_commitments (
    deal_id, leg_id, currency_code, commitment_type, committed_amount
  ) VALUES (
    v_deal_id,
    (SELECT id FROM fx_deal_legs WHERE deal_id = v_deal_id AND leg_no = 1),
    v_currency, 'customer_sale'::fx_commitment_type, p_sell_amount
  );

  v_available := fx_deal_actual_balance(p_branch_id, v_currency) - fx_deal_open_commitment(p_branch_id, v_currency, 'customer_sale'::fx_commitment_type) + p_sell_amount;
  v_required := GREATEST(0, p_sell_amount - v_available);

  IF v_required > 0 AND p_auto_source THEN
    v_status := 'sourcing_required'::fx_deal_status;
    INSERT INTO fx_deal_legs (
      deal_id, leg_no, leg_type, status,
      receive_currency, receive_amount, remaining_amount, notes
    ) VALUES (
      v_deal_id, 2, 'sourcing_requirement'::fx_deal_leg_type, 'pending'::fx_deal_leg_status,
      v_currency, v_required, v_required,
      'Auto-created: insufficient available balance'
    );
    INSERT INTO fx_currency_commitments (
      deal_id, currency_code, commitment_type, committed_amount
    ) VALUES (
      v_deal_id, v_currency, 'sourcing_required'::fx_commitment_type, v_required
    );
    UPDATE fx_deals SET status = v_status WHERE id = v_deal_id;
  ELSIF v_required > 0 AND NOT COALESCE(p_allow_short_position, FALSE) THEN
    UPDATE fx_deals SET status = 'sourcing_required'::fx_deal_status WHERE id = v_deal_id;
  END IF;

  RETURN v_deal_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_record_deal_customer_payment — Dr PKR Cash / Cr Customer Advances
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_record_deal_customer_payment(
  p_deal_id UUID,
  p_amount_pkr NUMERIC,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_tx_id UUID;
  v_leg_no INT;
  v_leg_id UUID;
  v_pkr_cash UUID;
  v_advances UUID;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;
  IF p_amount_pkr <= 0 THEN RAISE EXCEPTION 'Payment amount must be positive'; END IF;

  v_pkr_cash := fx_account_id_by_code(v_deal.company_id, '1110');
  v_advances := fx_account_id_by_code(v_deal.company_id, '1160');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, created_by
  ) VALUES (
    v_deal.company_id, v_deal.branch_id, 'manual_journal', 'draft', CURRENT_DATE,
    v_deal.customer_party_id, 'PKR', p_amount_pkr, 1, p_amount_pkr,
    COALESCE(p_notes, 'Customer payment — deal ' || v_deal.deal_no),
    p_deal_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_pkr_cash, 'PKR', p_amount_pkr, 1, p_amount_pkr, 0, 'Customer payment received'),
    (v_tx_id, 2, v_advances, 'PKR', p_amount_pkr, 1, 0, p_amount_pkr, 'Customer advance');

  PERFORM fx_post_transaction(v_tx_id);

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    pay_currency, pay_amount, paid_amount, remaining_amount,
    linked_transaction_id, notes
  ) VALUES (
    p_deal_id, v_leg_no, 'customer_payment'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, v_deal.customer_party_id,
    'PKR', p_amount_pkr, p_amount_pkr, 0,
    v_tx_id, p_notes
  ) RETURNING id INTO v_leg_id;

  UPDATE fx_transactions SET leg_id = v_leg_id WHERE id = v_tx_id;

  UPDATE fx_deals SET
    customer_paid_pkr = customer_paid_pkr + p_amount_pkr,
    customer_receivable_pkr = GREATEST(0, customer_payable_pkr - customer_paid_pkr - p_amount_pkr),
    status = (CASE
      WHEN customer_paid_pkr + p_amount_pkr >= customer_payable_pkr THEN 'customer_paid'
      WHEN customer_paid_pkr + p_amount_pkr > 0 THEN 'customer_partially_paid'
      ELSE status::text
    END)::fx_deal_status,
    updated_at = NOW()
  WHERE id = p_deal_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_add_deal_leg — generic leg append
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_add_deal_leg(
  p_deal_id UUID,
  p_leg_type fx_deal_leg_type,
  p_counterparty_party_id UUID DEFAULT NULL,
  p_receive_currency TEXT DEFAULT NULL,
  p_receive_amount NUMERIC DEFAULT 0,
  p_pay_currency TEXT DEFAULT NULL,
  p_pay_amount NUMERIC DEFAULT 0,
  p_rate_used NUMERIC DEFAULT NULL,
  p_delivery_target fx_delivery_target DEFAULT NULL,
  p_parent_leg_id UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_leg_no INT;
  v_leg_id UUID;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    paid_amount, remaining_amount, delivery_target, parent_leg_id, notes
  ) VALUES (
    p_deal_id, v_leg_no, p_leg_type, 'pending'::fx_deal_leg_status, p_counterparty_party_id,
    CASE WHEN p_receive_currency IS NOT NULL THEN fx_normalize_currency_code(p_receive_currency) ELSE NULL END,
    COALESCE(p_receive_amount, 0),
    CASE WHEN p_pay_currency IS NOT NULL THEN fx_normalize_currency_code(p_pay_currency) ELSE NULL END,
    COALESCE(p_pay_amount, 0), p_rate_used,
    0, COALESCE(p_pay_amount, p_receive_amount, 0),
    p_delivery_target, p_parent_leg_id, p_notes
  ) RETURNING id INTO v_leg_id;

  IF p_leg_type = 'agent_source' THEN
    UPDATE fx_deals SET status = 'sourcing_in_progress'::fx_deal_status, updated_at = NOW() WHERE id = p_deal_id;
    INSERT INTO fx_currency_commitments (deal_id, leg_id, currency_code, commitment_type, committed_amount)
    VALUES (p_deal_id, v_leg_id, fx_normalize_currency_code(p_receive_currency), 'on_order_inbound'::fx_commitment_type, p_receive_amount);
  END IF;

  RETURN v_leg_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_add_settlement_link
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_add_settlement_link(
  p_deal_id UUID,
  p_from_leg_id UUID,
  p_to_leg_id UUID,
  p_link_type fx_settlement_link_type,
  p_currency_code TEXT,
  p_amount NUMERIC,
  p_proof_reference TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_deal fx_deals;
BEGIN
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  INSERT INTO fx_settlement_links (deal_id, from_leg_id, to_leg_id, link_type, currency_code, amount, proof_reference)
  VALUES (p_deal_id, p_from_leg_id, p_to_leg_id, p_link_type, fx_normalize_currency_code(p_currency_code), p_amount, p_proof_reference)
  RETURNING id INTO v_id;

  UPDATE fx_settlement_links SET status = 'completed'::fx_deal_leg_status, updated_at = NOW() WHERE id = v_id;
  RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_confirm_deal_delivery — final delivery + P/L recognition
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_confirm_deal_delivery(
  p_deal_id UUID,
  p_delivered_amount NUMERIC,
  p_delivery_target fx_delivery_target DEFAULT 'direct_to_customer',
  p_cost_basis_pkr NUMERIC DEFAULT NULL,
  p_proof_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_tx_id UUID;
  v_leg_no INT;
  v_leg_id UUID;
  v_cost NUMERIC;
  v_profit NUMERIC;
  v_foreign_cash UUID;
  v_advances UUID;
  v_receivable UUID;
  v_spread UUID;
  v_clearing UUID;
  v_line_no INT := 0;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  v_cost := COALESCE(p_cost_basis_pkr, v_deal.cost_basis_pkr, v_deal.customer_payable_pkr);
  v_profit := v_deal.customer_payable_pkr - v_cost;

  v_foreign_cash := fx_account_id_by_code(v_deal.company_id,
    CASE fx_normalize_currency_code(v_deal.sell_currency_code)
      WHEN 'PKR' THEN '1110' WHEN 'USD' THEN '1120' WHEN 'AED' THEN '1130'
      WHEN 'CNY' THEN '1140' WHEN 'SAR' THEN '1150' ELSE '1110'
    END);
  v_advances := fx_account_id_by_code(v_deal.company_id, '1160');
  v_receivable := fx_account_id_by_code(v_deal.company_id, '1190');
  v_spread := fx_account_id_by_code(v_deal.company_id, '4100');
  v_clearing := fx_account_id_by_code(v_deal.company_id, '1170');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, created_by
  ) VALUES (
    v_deal.company_id, v_deal.branch_id, 'currency_sell', 'draft', CURRENT_DATE,
    v_deal.customer_party_id, v_deal.sell_currency_code, p_delivered_amount,
    v_deal.sale_rate_pkr, v_deal.customer_payable_pkr,
    COALESCE(p_notes, 'Delivery — deal ' || v_deal.deal_no),
    p_deal_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  -- Dr Customer Advance (paid portion) + Dr Receivable (unpaid) / Cr Foreign cash at cost + Cr Spread
  IF v_deal.customer_paid_pkr > 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_advances, 'PKR', v_deal.customer_paid_pkr, 1, v_deal.customer_paid_pkr, 0, 'Clear customer advance');
  END IF;

  IF v_deal.customer_receivable_pkr > 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_receivable, 'PKR', v_deal.customer_receivable_pkr, 1, v_deal.customer_receivable_pkr, 0, 'Customer receivable');
  END IF;

  v_line_no := v_line_no + 1;
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, v_line_no, v_foreign_cash, v_deal.sell_currency_code, p_delivered_amount, v_deal.sale_rate_pkr, 0, v_cost, 'RMB delivered at cost');

  IF v_profit <> 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_spread, 'PKR', ABS(v_profit), 1, CASE WHEN v_profit < 0 THEN ABS(v_profit) ELSE 0 END, CASE WHEN v_profit > 0 THEN v_profit ELSE 0 END, 'FX spread income');
  END IF;

  PERFORM fx_post_transaction(v_tx_id);

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;
  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, delivery_target,
    linked_transaction_id, proof_reference, notes, completed_at
  ) VALUES (
    p_deal_id, v_leg_no, 'delivery'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, v_deal.customer_party_id,
    v_deal.sell_currency_code, p_delivered_amount, p_delivery_target,
    v_tx_id, p_proof_reference, p_notes, NOW()
  ) RETURNING id INTO v_leg_id;

  UPDATE fx_transactions SET leg_id = v_leg_id WHERE id = v_tx_id;

  UPDATE fx_currency_commitments SET
    delivered_amount = delivered_amount + p_delivered_amount,
    is_open = CASE WHEN delivered_amount + p_delivered_amount >= committed_amount THEN FALSE ELSE is_open END,
    updated_at = NOW()
  WHERE deal_id = p_deal_id AND commitment_type = 'customer_sale'::fx_commitment_type;

  UPDATE fx_deals SET
    status = 'completed'::fx_deal_status,
    actual_profit_pkr = v_profit,
    cost_basis_pkr = v_cost,
    completed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_deal_id;

  RETURN v_leg_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_get_deal_timeline
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_deal_timeline(p_deal_id UUID)
RETURNS TABLE (
  leg_id UUID,
  leg_no INT,
  leg_type fx_deal_leg_type,
  leg_status fx_deal_leg_status,
  counterparty_name TEXT,
  receive_currency TEXT,
  receive_amount NUMERIC,
  pay_currency TEXT,
  pay_amount NUMERIC,
  paid_amount NUMERIC,
  remaining_amount NUMERIC,
  proof_reference TEXT,
  notes TEXT,
  linked_transaction_no TEXT,
  created_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
BEGIN
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  RETURN QUERY
  SELECT
    l.id, l.leg_no, l.leg_type, l.status,
    p.name,
    l.receive_currency, l.receive_amount,
    l.pay_currency, l.pay_amount,
    l.paid_amount, l.remaining_amount,
    l.proof_reference, l.notes,
    t.transaction_no,
    l.created_at, l.completed_at
  FROM fx_deal_legs l
  LEFT JOIN fx_parties p ON p.id = l.counterparty_party_id
  LEFT JOIN fx_transactions t ON t.id = l.linked_transaction_id
  WHERE l.deal_id = p_deal_id
  ORDER BY l.leg_no;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_get_party_deal_open_items
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_party_deal_open_items(p_party_id UUID)
RETURNS TABLE (
  deal_id UUID,
  deal_no TEXT,
  deal_status fx_deal_status,
  sell_currency TEXT,
  sell_amount NUMERIC,
  customer_payable_pkr NUMERIC,
  customer_receivable_pkr NUMERIC,
  role TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id, d.deal_no, d.status,
    d.sell_currency_code, d.sell_amount,
    d.customer_payable_pkr, d.customer_receivable_pkr,
    'customer'::TEXT
  FROM fx_deals d
  WHERE d.customer_party_id = p_party_id
    AND d.status NOT IN ('completed', 'cancelled', 'voided')
    AND fx_same_branch(d.branch_id)
  UNION ALL
  SELECT
    d.id, d.deal_no, d.status,
    l.receive_currency, l.receive_amount,
    l.pay_amount, l.remaining_amount,
    'agent'::TEXT
  FROM fx_deal_legs l
  JOIN fx_deals d ON d.id = l.deal_id
  WHERE l.counterparty_party_id = p_party_id
    AND l.status IN ('pending', 'partial')
    AND d.status NOT IN ('cancelled', 'voided')
    AND fx_same_branch(d.branch_id);
END;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE fx_deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_deal_legs ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_currency_commitments ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_settlement_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fx_deals_select ON fx_deals;
DROP POLICY IF EXISTS fx_deals_write ON fx_deals;
DROP POLICY IF EXISTS fx_deal_legs_select ON fx_deal_legs;
DROP POLICY IF EXISTS fx_deal_legs_write ON fx_deal_legs;
DROP POLICY IF EXISTS fx_commitments_select ON fx_currency_commitments;
DROP POLICY IF EXISTS fx_commitments_write ON fx_currency_commitments;
DROP POLICY IF EXISTS fx_settlement_links_select ON fx_settlement_links;
DROP POLICY IF EXISTS fx_settlement_links_write ON fx_settlement_links;

CREATE POLICY fx_deals_select ON fx_deals
  FOR SELECT TO authenticated
  USING (fx_same_branch(branch_id) AND fx_has_permission('can_access_fx_ledger'));

CREATE POLICY fx_deals_write ON fx_deals
  FOR ALL TO authenticated
  USING (fx_same_branch(branch_id) AND fx_has_permission('can_access_fx_ledger'))
  WITH CHECK (fx_same_branch(branch_id) AND fx_has_permission('can_access_fx_ledger'));

CREATE POLICY fx_deal_legs_select ON fx_deal_legs
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  );

CREATE POLICY fx_deal_legs_write ON fx_deal_legs
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id))
  );

CREATE POLICY fx_commitments_select ON fx_currency_commitments
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  );

CREATE POLICY fx_commitments_write ON fx_currency_commitments
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id))
  );

CREATE POLICY fx_settlement_links_select ON fx_settlement_links
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  );

CREATE POLICY fx_settlement_links_write ON fx_settlement_links
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id))
  );

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

GRANT EXECUTE ON FUNCTION fx_generate_deal_no(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_currency_position_extended(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_book_customer_deal(UUID, UUID, TEXT, NUMERIC, NUMERIC, NUMERIC, fx_delivery_method, BOOLEAN, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_record_deal_customer_payment(UUID, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_add_deal_leg(UUID, fx_deal_leg_type, UUID, TEXT, NUMERIC, TEXT, NUMERIC, NUMERIC, fx_delivery_target, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_add_settlement_link(UUID, UUID, UUID, fx_settlement_link_type, TEXT, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_confirm_deal_delivery(UUID, NUMERIC, fx_delivery_target, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_deal_timeline(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_party_deal_open_items(UUID) TO authenticated;
-- <<<<< END 202606170001_fx_deals_workflow.sql

-- >>>>> BEGIN 202606170002_fx_deals_coa_fix_completion.sql
﻿-- FX Deals completion patch: fixed COA (currency_id) + RPCs/RLS/grants
-- Safe when 202606170001 partially applied via SQL Editor (enums/tables exist, COA/RPCs missing)
-- Cloud only: ygidlcqhupmxvsdjmvnf
-- ---------------------------------------------------------------------------
-- COA additions (idempotent per company)
-- ---------------------------------------------------------------------------

DO $$
DECLARE
  v_company UUID;
  v_assets UUID;
  v_liabilities UUID;
BEGIN
  FOR v_company IN SELECT id FROM fx_companies LOOP
    SELECT id INTO v_assets FROM fx_accounts WHERE company_id = v_company AND code = '1000' LIMIT 1;
    SELECT id INTO v_liabilities FROM fx_accounts WHERE company_id = v_company AND code = '2000' LIMIT 1;

    INSERT INTO fx_accounts (company_id, code, name, account_type, currency_id, parent_id)
    VALUES
      (v_company, '1160', 'Customer Advances', 'liability', NULL, v_liabilities),
      (v_company, '1170', 'FX Delivery Clearing', 'asset', NULL, v_assets),
      (v_company, '2310', 'Agent Settlement Clearing', 'liability', NULL, v_liabilities),
      (v_company, '2320', 'Cross-Currency Clearing', 'liability', NULL, v_liabilities)
    ON CONFLICT (company_id, code) DO NOTHING;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_normalize_currency_code(p_code TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE WHEN UPPER(TRIM(p_code)) IN ('RMB', 'CNY') THEN 'CNY' ELSE UPPER(TRIM(p_code)) END;
$$;

CREATE OR REPLACE FUNCTION fx_generate_deal_no(p_branch_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seq INT;
BEGIN
  SELECT COALESCE(MAX(
    NULLIF(regexp_replace(deal_no, '\D', '', 'g'), '')::INT
  ), 0) + 1
  INTO v_seq
  FROM fx_deals
  WHERE branch_id = p_branch_id;

  RETURN 'DL-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(v_seq::TEXT, 4, '0');
END;
$$;

CREATE OR REPLACE FUNCTION fx_deal_open_commitment(
  p_branch_id UUID,
  p_currency_code TEXT,
  p_commitment_type fx_commitment_type
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(SUM(
    c.committed_amount - c.sourced_amount - c.released_amount
  ), 0)
  FROM fx_currency_commitments c
  JOIN fx_deals d ON d.id = c.deal_id
  WHERE d.branch_id = p_branch_id
    AND c.is_open
    AND c.commitment_type = p_commitment_type
    AND fx_normalize_currency_code(c.currency_code) = fx_normalize_currency_code(p_currency_code);
$$;

CREATE OR REPLACE FUNCTION fx_deal_actual_balance(
  p_branch_id UUID,
  p_currency_code TEXT,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(SUM(
    CASE
      WHEN jl.debit_pkr > 0 THEN jl.foreign_amount
      WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount
      ELSE 0
    END
  ), 0)
  FROM fx_journal_lines jl
  JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
  JOIN fx_accounts a ON a.id = jl.account_id
  WHERE je.branch_id = p_branch_id
    AND NOT je.is_void
    AND je.entry_date <= p_as_of
    AND a.code IN ('1110', '1120', '1130', '1140', '1150')
    AND fx_normalize_currency_code(jl.currency_code) = fx_normalize_currency_code(p_currency_code);
$$;

-- ---------------------------------------------------------------------------
-- fx_get_currency_position_extended
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_currency_position_extended(
  p_branch_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  currency_code TEXT,
  actual_balance NUMERIC,
  committed_balance NUMERIC,
  on_order_balance NUMERIC,
  required_balance NUMERIC,
  available_balance NUMERIC,
  base_equivalent_pkr NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT fx_has_permission('can_view_fx_reports') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  RETURN QUERY
  WITH currencies AS (
    SELECT DISTINCT fx_normalize_currency_code(c.code) AS code
    FROM fx_currencies c
    WHERE c.is_active
    UNION
    SELECT DISTINCT fx_normalize_currency_code(jl.currency_code)
    FROM fx_journal_lines jl
    JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    JOIN fx_accounts a ON a.id = jl.account_id
    WHERE je.branch_id = p_branch_id
      AND NOT je.is_void
      AND je.entry_date <= p_as_of
      AND a.code IN ('1110', '1120', '1130', '1140', '1150')
  ),
  actuals AS (
    SELECT
      fx_normalize_currency_code(jl.currency_code) AS code,
      COALESCE(SUM(
        CASE WHEN jl.debit_pkr > 0 THEN jl.foreign_amount WHEN jl.credit_pkr > 0 THEN -jl.foreign_amount ELSE 0 END
      ), 0) AS actual_bal,
      COALESCE(SUM(jl.debit_pkr - jl.credit_pkr), 0) AS pkr_eq
    FROM fx_journal_lines jl
    JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
    JOIN fx_accounts a ON a.id = jl.account_id
    WHERE je.branch_id = p_branch_id
      AND NOT je.is_void
      AND je.entry_date <= p_as_of
      AND a.code IN ('1110', '1120', '1130', '1140', '1150')
    GROUP BY 1
  ),
  committed AS (
    SELECT
      fx_normalize_currency_code(c.currency_code) AS code,
      COALESCE(SUM(c.committed_amount - c.sourced_amount - c.released_amount), 0) AS amt
    FROM fx_currency_commitments c
    JOIN fx_deals d ON d.id = c.deal_id
    WHERE d.branch_id = p_branch_id
      AND c.is_open
      AND c.commitment_type = 'customer_sale'
    GROUP BY 1
  ),
  on_order AS (
    SELECT
      fx_normalize_currency_code(c.currency_code) AS code,
      COALESCE(SUM(c.committed_amount - c.sourced_amount - c.released_amount), 0) AS amt
    FROM fx_currency_commitments c
    JOIN fx_deals d ON d.id = c.deal_id
    WHERE d.branch_id = p_branch_id
      AND c.is_open
      AND c.commitment_type = 'on_order_inbound'
    GROUP BY 1
  )
  SELECT
    cur.code,
    COALESCE(a.actual_bal, 0),
    COALESCE(cm.amt, 0),
    COALESCE(oo.amt, 0),
    GREATEST(0, COALESCE(cm.amt, 0) - COALESCE(a.actual_bal, 0) - COALESCE(oo.amt, 0)),
    COALESCE(a.actual_bal, 0) - COALESCE(cm.amt, 0) + COALESCE(oo.amt, 0),
    COALESCE(a.pkr_eq, 0)
  FROM currencies cur
  LEFT JOIN actuals a ON a.code = cur.code
  LEFT JOIN committed cm ON cm.code = cur.code
  LEFT JOIN on_order oo ON oo.code = cur.code
  WHERE COALESCE(a.actual_bal, 0) <> 0
     OR COALESCE(cm.amt, 0) <> 0
     OR COALESCE(oo.amt, 0) <> 0
  ORDER BY cur.code;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_book_customer_deal
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_book_customer_deal(
  p_branch_id UUID,
  p_customer_party_id UUID,
  p_sell_currency_code TEXT,
  p_sell_amount NUMERIC,
  p_sale_rate_pkr NUMERIC,
  p_customer_paid_now_pkr NUMERIC DEFAULT 0,
  p_delivery_method fx_delivery_method DEFAULT 'later',
  p_allow_short_position BOOLEAN DEFAULT FALSE,
  p_notes TEXT DEFAULT NULL,
  p_auto_source BOOLEAN DEFAULT TRUE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_deal_id UUID;
  v_leg_id UUID;
  v_payable NUMERIC(20, 8);
  v_currency TEXT;
  v_available NUMERIC;
  v_required NUMERIC;
  v_status fx_deal_status;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_profile FROM fx_current_profile();
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  v_currency := fx_normalize_currency_code(p_sell_currency_code);
  v_payable := ROUND(p_sell_amount * p_sale_rate_pkr, 8);

  INSERT INTO fx_deals (
    company_id, branch_id, customer_party_id,
    sell_currency_code, sell_amount, sale_rate_pkr,
    customer_payable_pkr, customer_paid_pkr, customer_receivable_pkr,
    delivery_method, status, allow_short_position, notes,
    booked_at, created_by
  ) VALUES (
    v_profile.company_id, p_branch_id, p_customer_party_id,
    v_currency, p_sell_amount, p_sale_rate_pkr,
    v_payable, COALESCE(p_customer_paid_now_pkr, 0),
    GREATEST(0, v_payable - COALESCE(p_customer_paid_now_pkr, 0)),
    p_delivery_method,
    (CASE
      WHEN COALESCE(p_customer_paid_now_pkr, 0) >= v_payable THEN 'customer_paid'
      WHEN COALESCE(p_customer_paid_now_pkr, 0) > 0 THEN 'customer_partially_paid'
      ELSE 'booked'
    END)::fx_deal_status,
    COALESCE(p_allow_short_position, FALSE),
    p_notes,
    NOW(), auth.uid()
  )
  RETURNING id INTO v_deal_id;

  UPDATE fx_deals SET deal_no = fx_generate_deal_no(p_branch_id) WHERE id = v_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    remaining_amount, notes
  ) VALUES (
    v_deal_id, 1, 'customer_order'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, p_customer_party_id,
    v_currency, p_sell_amount, 'PKR', v_payable, p_sale_rate_pkr,
    0, 'Customer FX order booked'
  );

  INSERT INTO fx_currency_commitments (
    deal_id, leg_id, currency_code, commitment_type, committed_amount
  ) VALUES (
    v_deal_id,
    (SELECT id FROM fx_deal_legs WHERE deal_id = v_deal_id AND leg_no = 1),
    v_currency, 'customer_sale'::fx_commitment_type, p_sell_amount
  );

  v_available := fx_deal_actual_balance(p_branch_id, v_currency) - fx_deal_open_commitment(p_branch_id, v_currency, 'customer_sale'::fx_commitment_type) + p_sell_amount;
  v_required := GREATEST(0, p_sell_amount - v_available);

  IF v_required > 0 AND p_auto_source THEN
    v_status := 'sourcing_required'::fx_deal_status;
    INSERT INTO fx_deal_legs (
      deal_id, leg_no, leg_type, status,
      receive_currency, receive_amount, remaining_amount, notes
    ) VALUES (
      v_deal_id, 2, 'sourcing_requirement'::fx_deal_leg_type, 'pending'::fx_deal_leg_status,
      v_currency, v_required, v_required,
      'Auto-created: insufficient available balance'
    );
    INSERT INTO fx_currency_commitments (
      deal_id, currency_code, commitment_type, committed_amount
    ) VALUES (
      v_deal_id, v_currency, 'sourcing_required'::fx_commitment_type, v_required
    );
    UPDATE fx_deals SET status = v_status WHERE id = v_deal_id;
  ELSIF v_required > 0 AND NOT COALESCE(p_allow_short_position, FALSE) THEN
    UPDATE fx_deals SET status = 'sourcing_required'::fx_deal_status WHERE id = v_deal_id;
  END IF;

  RETURN v_deal_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_record_deal_customer_payment â€” Dr PKR Cash / Cr Customer Advances
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_record_deal_customer_payment(
  p_deal_id UUID,
  p_amount_pkr NUMERIC,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_tx_id UUID;
  v_leg_no INT;
  v_leg_id UUID;
  v_pkr_cash UUID;
  v_advances UUID;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;
  IF p_amount_pkr <= 0 THEN RAISE EXCEPTION 'Payment amount must be positive'; END IF;

  v_pkr_cash := fx_account_id_by_code(v_deal.company_id, '1110');
  v_advances := fx_account_id_by_code(v_deal.company_id, '1160');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, created_by
  ) VALUES (
    v_deal.company_id, v_deal.branch_id, 'manual_journal', 'draft', CURRENT_DATE,
    v_deal.customer_party_id, 'PKR', p_amount_pkr, 1, p_amount_pkr,
    COALESCE(p_notes, 'Customer payment â€” deal ' || v_deal.deal_no),
    p_deal_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_pkr_cash, 'PKR', p_amount_pkr, 1, p_amount_pkr, 0, 'Customer payment received'),
    (v_tx_id, 2, v_advances, 'PKR', p_amount_pkr, 1, 0, p_amount_pkr, 'Customer advance');

  PERFORM fx_post_transaction(v_tx_id);

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    pay_currency, pay_amount, paid_amount, remaining_amount,
    linked_transaction_id, notes
  ) VALUES (
    p_deal_id, v_leg_no, 'customer_payment'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, v_deal.customer_party_id,
    'PKR', p_amount_pkr, p_amount_pkr, 0,
    v_tx_id, p_notes
  ) RETURNING id INTO v_leg_id;

  UPDATE fx_transactions SET leg_id = v_leg_id WHERE id = v_tx_id;

  UPDATE fx_deals SET
    customer_paid_pkr = customer_paid_pkr + p_amount_pkr,
    customer_receivable_pkr = GREATEST(0, customer_payable_pkr - customer_paid_pkr - p_amount_pkr),
    status = (CASE
      WHEN customer_paid_pkr + p_amount_pkr >= customer_payable_pkr THEN 'customer_paid'
      WHEN customer_paid_pkr + p_amount_pkr > 0 THEN 'customer_partially_paid'
      ELSE status::text
    END)::fx_deal_status,
    updated_at = NOW()
  WHERE id = p_deal_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_add_deal_leg â€” generic leg append
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_add_deal_leg(
  p_deal_id UUID,
  p_leg_type fx_deal_leg_type,
  p_counterparty_party_id UUID DEFAULT NULL,
  p_receive_currency TEXT DEFAULT NULL,
  p_receive_amount NUMERIC DEFAULT 0,
  p_pay_currency TEXT DEFAULT NULL,
  p_pay_amount NUMERIC DEFAULT 0,
  p_rate_used NUMERIC DEFAULT NULL,
  p_delivery_target fx_delivery_target DEFAULT NULL,
  p_parent_leg_id UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_leg_no INT;
  v_leg_id UUID;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    paid_amount, remaining_amount, delivery_target, parent_leg_id, notes
  ) VALUES (
    p_deal_id, v_leg_no, p_leg_type, 'pending'::fx_deal_leg_status, p_counterparty_party_id,
    CASE WHEN p_receive_currency IS NOT NULL THEN fx_normalize_currency_code(p_receive_currency) ELSE NULL END,
    COALESCE(p_receive_amount, 0),
    CASE WHEN p_pay_currency IS NOT NULL THEN fx_normalize_currency_code(p_pay_currency) ELSE NULL END,
    COALESCE(p_pay_amount, 0), p_rate_used,
    0, COALESCE(p_pay_amount, p_receive_amount, 0),
    p_delivery_target, p_parent_leg_id, p_notes
  ) RETURNING id INTO v_leg_id;

  IF p_leg_type = 'agent_source' THEN
    UPDATE fx_deals SET status = 'sourcing_in_progress'::fx_deal_status, updated_at = NOW() WHERE id = p_deal_id;
    INSERT INTO fx_currency_commitments (deal_id, leg_id, currency_code, commitment_type, committed_amount)
    VALUES (p_deal_id, v_leg_id, fx_normalize_currency_code(p_receive_currency), 'on_order_inbound'::fx_commitment_type, p_receive_amount);
  END IF;

  RETURN v_leg_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_add_settlement_link
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_add_settlement_link(
  p_deal_id UUID,
  p_from_leg_id UUID,
  p_to_leg_id UUID,
  p_link_type fx_settlement_link_type,
  p_currency_code TEXT,
  p_amount NUMERIC,
  p_proof_reference TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_deal fx_deals;
BEGIN
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  INSERT INTO fx_settlement_links (deal_id, from_leg_id, to_leg_id, link_type, currency_code, amount, proof_reference)
  VALUES (p_deal_id, p_from_leg_id, p_to_leg_id, p_link_type, fx_normalize_currency_code(p_currency_code), p_amount, p_proof_reference)
  RETURNING id INTO v_id;

  UPDATE fx_settlement_links SET status = 'completed'::fx_deal_leg_status, updated_at = NOW() WHERE id = v_id;
  RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_confirm_deal_delivery â€” final delivery + P/L recognition
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_confirm_deal_delivery(
  p_deal_id UUID,
  p_delivered_amount NUMERIC,
  p_delivery_target fx_delivery_target DEFAULT 'direct_to_customer',
  p_cost_basis_pkr NUMERIC DEFAULT NULL,
  p_proof_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_tx_id UUID;
  v_leg_no INT;
  v_leg_id UUID;
  v_cost NUMERIC;
  v_profit NUMERIC;
  v_foreign_cash UUID;
  v_advances UUID;
  v_receivable UUID;
  v_spread UUID;
  v_clearing UUID;
  v_line_no INT := 0;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  v_cost := COALESCE(p_cost_basis_pkr, v_deal.cost_basis_pkr, v_deal.customer_payable_pkr);
  v_profit := v_deal.customer_payable_pkr - v_cost;

  v_foreign_cash := fx_account_id_by_code(v_deal.company_id,
    CASE fx_normalize_currency_code(v_deal.sell_currency_code)
      WHEN 'PKR' THEN '1110' WHEN 'USD' THEN '1120' WHEN 'AED' THEN '1130'
      WHEN 'CNY' THEN '1140' WHEN 'SAR' THEN '1150' ELSE '1110'
    END);
  v_advances := fx_account_id_by_code(v_deal.company_id, '1160');
  v_receivable := fx_account_id_by_code(v_deal.company_id, '1190');
  v_spread := fx_account_id_by_code(v_deal.company_id, '4100');
  v_clearing := fx_account_id_by_code(v_deal.company_id, '1170');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, created_by
  ) VALUES (
    v_deal.company_id, v_deal.branch_id, 'currency_sell', 'draft', CURRENT_DATE,
    v_deal.customer_party_id, v_deal.sell_currency_code, p_delivered_amount,
    v_deal.sale_rate_pkr, v_deal.customer_payable_pkr,
    COALESCE(p_notes, 'Delivery â€” deal ' || v_deal.deal_no),
    p_deal_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  -- Dr Customer Advance (paid portion) + Dr Receivable (unpaid) / Cr Foreign cash at cost + Cr Spread
  IF v_deal.customer_paid_pkr > 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_advances, 'PKR', v_deal.customer_paid_pkr, 1, v_deal.customer_paid_pkr, 0, 'Clear customer advance');
  END IF;

  IF v_deal.customer_receivable_pkr > 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_receivable, 'PKR', v_deal.customer_receivable_pkr, 1, v_deal.customer_receivable_pkr, 0, 'Customer receivable');
  END IF;

  v_line_no := v_line_no + 1;
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, v_line_no, v_foreign_cash, v_deal.sell_currency_code, p_delivered_amount, v_deal.sale_rate_pkr, 0, v_cost, 'RMB delivered at cost');

  IF v_profit <> 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_spread, 'PKR', ABS(v_profit), 1, CASE WHEN v_profit < 0 THEN ABS(v_profit) ELSE 0 END, CASE WHEN v_profit > 0 THEN v_profit ELSE 0 END, 'FX spread income');
  END IF;

  PERFORM fx_post_transaction(v_tx_id);

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;
  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, delivery_target,
    linked_transaction_id, proof_reference, notes, completed_at
  ) VALUES (
    p_deal_id, v_leg_no, 'delivery'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, v_deal.customer_party_id,
    v_deal.sell_currency_code, p_delivered_amount, p_delivery_target,
    v_tx_id, p_proof_reference, p_notes, NOW()
  ) RETURNING id INTO v_leg_id;

  UPDATE fx_transactions SET leg_id = v_leg_id WHERE id = v_tx_id;

  UPDATE fx_currency_commitments SET
    delivered_amount = delivered_amount + p_delivered_amount,
    is_open = CASE WHEN delivered_amount + p_delivered_amount >= committed_amount THEN FALSE ELSE is_open END,
    updated_at = NOW()
  WHERE deal_id = p_deal_id AND commitment_type = 'customer_sale'::fx_commitment_type;

  UPDATE fx_deals SET
    status = 'completed'::fx_deal_status,
    actual_profit_pkr = v_profit,
    cost_basis_pkr = v_cost,
    completed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_deal_id;

  RETURN v_leg_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_get_deal_timeline
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_deal_timeline(p_deal_id UUID)
RETURNS TABLE (
  leg_id UUID,
  leg_no INT,
  leg_type fx_deal_leg_type,
  leg_status fx_deal_leg_status,
  counterparty_name TEXT,
  receive_currency TEXT,
  receive_amount NUMERIC,
  pay_currency TEXT,
  pay_amount NUMERIC,
  paid_amount NUMERIC,
  remaining_amount NUMERIC,
  proof_reference TEXT,
  notes TEXT,
  linked_transaction_no TEXT,
  created_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
BEGIN
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  RETURN QUERY
  SELECT
    l.id, l.leg_no, l.leg_type, l.status,
    p.name,
    l.receive_currency, l.receive_amount,
    l.pay_currency, l.pay_amount,
    l.paid_amount, l.remaining_amount,
    l.proof_reference, l.notes,
    t.transaction_no,
    l.created_at, l.completed_at
  FROM fx_deal_legs l
  LEFT JOIN fx_parties p ON p.id = l.counterparty_party_id
  LEFT JOIN fx_transactions t ON t.id = l.linked_transaction_id
  WHERE l.deal_id = p_deal_id
  ORDER BY l.leg_no;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_get_party_deal_open_items
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_party_deal_open_items(p_party_id UUID)
RETURNS TABLE (
  deal_id UUID,
  deal_no TEXT,
  deal_status fx_deal_status,
  sell_currency TEXT,
  sell_amount NUMERIC,
  customer_payable_pkr NUMERIC,
  customer_receivable_pkr NUMERIC,
  role TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id, d.deal_no, d.status,
    d.sell_currency_code, d.sell_amount,
    d.customer_payable_pkr, d.customer_receivable_pkr,
    'customer'::TEXT
  FROM fx_deals d
  WHERE d.customer_party_id = p_party_id
    AND d.status NOT IN ('completed', 'cancelled', 'voided')
    AND fx_same_branch(d.branch_id)
  UNION ALL
  SELECT
    d.id, d.deal_no, d.status,
    l.receive_currency, l.receive_amount,
    l.pay_amount, l.remaining_amount,
    'agent'::TEXT
  FROM fx_deal_legs l
  JOIN fx_deals d ON d.id = l.deal_id
  WHERE l.counterparty_party_id = p_party_id
    AND l.status IN ('pending', 'partial')
    AND d.status NOT IN ('cancelled', 'voided')
    AND fx_same_branch(d.branch_id);
END;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE fx_deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_deal_legs ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_currency_commitments ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_settlement_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fx_deals_select ON fx_deals;
DROP POLICY IF EXISTS fx_deals_write ON fx_deals;
DROP POLICY IF EXISTS fx_deal_legs_select ON fx_deal_legs;
DROP POLICY IF EXISTS fx_deal_legs_write ON fx_deal_legs;
DROP POLICY IF EXISTS fx_commitments_select ON fx_currency_commitments;
DROP POLICY IF EXISTS fx_commitments_write ON fx_currency_commitments;
DROP POLICY IF EXISTS fx_settlement_links_select ON fx_settlement_links;
DROP POLICY IF EXISTS fx_settlement_links_write ON fx_settlement_links;

CREATE POLICY fx_deals_select ON fx_deals
  FOR SELECT TO authenticated
  USING (fx_same_branch(branch_id) AND fx_has_permission('can_access_fx_ledger'));

CREATE POLICY fx_deals_write ON fx_deals
  FOR ALL TO authenticated
  USING (fx_same_branch(branch_id) AND fx_has_permission('can_access_fx_ledger'))
  WITH CHECK (fx_same_branch(branch_id) AND fx_has_permission('can_access_fx_ledger'));

CREATE POLICY fx_deal_legs_select ON fx_deal_legs
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  );

CREATE POLICY fx_deal_legs_write ON fx_deal_legs
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id))
  );

CREATE POLICY fx_commitments_select ON fx_currency_commitments
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  );

CREATE POLICY fx_commitments_write ON fx_currency_commitments
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id))
  );

CREATE POLICY fx_settlement_links_select ON fx_settlement_links
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  );

CREATE POLICY fx_settlement_links_write ON fx_settlement_links
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id) AND fx_has_permission('can_access_fx_ledger'))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id))
  );

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

GRANT EXECUTE ON FUNCTION fx_generate_deal_no(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_currency_position_extended(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_book_customer_deal(UUID, UUID, TEXT, NUMERIC, NUMERIC, NUMERIC, fx_delivery_method, BOOLEAN, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_record_deal_customer_payment(UUID, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_add_deal_leg(UUID, fx_deal_leg_type, UUID, TEXT, NUMERIC, TEXT, NUMERIC, NUMERIC, fx_delivery_target, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_add_settlement_link(UUID, UUID, UUID, fx_settlement_link_type, TEXT, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_confirm_deal_delivery(UUID, NUMERIC, fx_delivery_target, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_deal_timeline(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_party_deal_open_items(UUID) TO authenticated;
-- <<<<< END 202606170002_fx_deals_coa_fix_completion.sql

-- >>>>> BEGIN 202606170003_fx_deals_enum_cast_fix.sql
-- FX Deals: explicit enum casts for deal RPCs (fixes PostgreSQL 42804)
-- Replaces fx_book_customer_deal, fx_record_deal_customer_payment,
-- fx_add_deal_leg, fx_add_settlement_link, fx_confirm_deal_delivery
-- ---------------------------------------------------------------------------
-- fx_book_customer_deal
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_book_customer_deal(
  p_branch_id UUID,
  p_customer_party_id UUID,
  p_sell_currency_code TEXT,
  p_sell_amount NUMERIC,
  p_sale_rate_pkr NUMERIC,
  p_customer_paid_now_pkr NUMERIC DEFAULT 0,
  p_delivery_method fx_delivery_method DEFAULT 'later',
  p_allow_short_position BOOLEAN DEFAULT FALSE,
  p_notes TEXT DEFAULT NULL,
  p_auto_source BOOLEAN DEFAULT TRUE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_deal_id UUID;
  v_leg_id UUID;
  v_payable NUMERIC(20, 8);
  v_currency TEXT;
  v_available NUMERIC;
  v_required NUMERIC;
  v_status fx_deal_status;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_profile FROM fx_current_profile();
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  v_currency := fx_normalize_currency_code(p_sell_currency_code);
  v_payable := ROUND(p_sell_amount * p_sale_rate_pkr, 8);

  INSERT INTO fx_deals (
    company_id, branch_id, customer_party_id,
    sell_currency_code, sell_amount, sale_rate_pkr,
    customer_payable_pkr, customer_paid_pkr, customer_receivable_pkr,
    delivery_method, status, allow_short_position, notes,
    booked_at, created_by
  ) VALUES (
    v_profile.company_id, p_branch_id, p_customer_party_id,
    v_currency, p_sell_amount, p_sale_rate_pkr,
    v_payable, COALESCE(p_customer_paid_now_pkr, 0),
    GREATEST(0, v_payable - COALESCE(p_customer_paid_now_pkr, 0)),
    p_delivery_method,
    (CASE
      WHEN COALESCE(p_customer_paid_now_pkr, 0) >= v_payable THEN 'customer_paid'
      WHEN COALESCE(p_customer_paid_now_pkr, 0) > 0 THEN 'customer_partially_paid'
      ELSE 'booked'
    END)::fx_deal_status,
    COALESCE(p_allow_short_position, FALSE),
    p_notes,
    NOW(), auth.uid()
  )
  RETURNING id INTO v_deal_id;

  UPDATE fx_deals SET deal_no = fx_generate_deal_no(p_branch_id) WHERE id = v_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    remaining_amount, notes
  ) VALUES (
    v_deal_id, 1, 'customer_order'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, p_customer_party_id,
    v_currency, p_sell_amount, 'PKR', v_payable, p_sale_rate_pkr,
    0, 'Customer FX order booked'
  );

  INSERT INTO fx_currency_commitments (
    deal_id, leg_id, currency_code, commitment_type, committed_amount
  ) VALUES (
    v_deal_id,
    (SELECT id FROM fx_deal_legs WHERE deal_id = v_deal_id AND leg_no = 1),
    v_currency, 'customer_sale'::fx_commitment_type, p_sell_amount
  );

  v_available := fx_deal_actual_balance(p_branch_id, v_currency) - fx_deal_open_commitment(p_branch_id, v_currency, 'customer_sale'::fx_commitment_type) + p_sell_amount;
  v_required := GREATEST(0, p_sell_amount - v_available);

  IF v_required > 0 AND p_auto_source THEN
    v_status := 'sourcing_required'::fx_deal_status;
    INSERT INTO fx_deal_legs (
      deal_id, leg_no, leg_type, status,
      receive_currency, receive_amount, remaining_amount, notes
    ) VALUES (
      v_deal_id, 2, 'sourcing_requirement'::fx_deal_leg_type, 'pending'::fx_deal_leg_status,
      v_currency, v_required, v_required,
      'Auto-created: insufficient available balance'
    );
    INSERT INTO fx_currency_commitments (
      deal_id, currency_code, commitment_type, committed_amount
    ) VALUES (
      v_deal_id, v_currency, 'sourcing_required'::fx_commitment_type, v_required
    );
    UPDATE fx_deals SET status = v_status WHERE id = v_deal_id;
  ELSIF v_required > 0 AND NOT COALESCE(p_allow_short_position, FALSE) THEN
    UPDATE fx_deals SET status = 'sourcing_required'::fx_deal_status WHERE id = v_deal_id;
  END IF;

  RETURN v_deal_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_record_deal_customer_payment — Dr PKR Cash / Cr Customer Advances
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_record_deal_customer_payment(
  p_deal_id UUID,
  p_amount_pkr NUMERIC,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_tx_id UUID;
  v_leg_no INT;
  v_leg_id UUID;
  v_pkr_cash UUID;
  v_advances UUID;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;
  IF p_amount_pkr <= 0 THEN RAISE EXCEPTION 'Payment amount must be positive'; END IF;

  v_pkr_cash := fx_account_id_by_code(v_deal.company_id, '1110');
  v_advances := fx_account_id_by_code(v_deal.company_id, '1160');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, created_by
  ) VALUES (
    v_deal.company_id, v_deal.branch_id, 'manual_journal', 'draft', CURRENT_DATE,
    v_deal.customer_party_id, 'PKR', p_amount_pkr, 1, p_amount_pkr,
    COALESCE(p_notes, 'Customer payment — deal ' || v_deal.deal_no),
    p_deal_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_pkr_cash, 'PKR', p_amount_pkr, 1, p_amount_pkr, 0, 'Customer payment received'),
    (v_tx_id, 2, v_advances, 'PKR', p_amount_pkr, 1, 0, p_amount_pkr, 'Customer advance');

  PERFORM fx_post_transaction(v_tx_id);

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    pay_currency, pay_amount, paid_amount, remaining_amount,
    linked_transaction_id, notes
  ) VALUES (
    p_deal_id, v_leg_no, 'customer_payment'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, v_deal.customer_party_id,
    'PKR', p_amount_pkr, p_amount_pkr, 0,
    v_tx_id, p_notes
  ) RETURNING id INTO v_leg_id;

  UPDATE fx_transactions SET leg_id = v_leg_id WHERE id = v_tx_id;

  UPDATE fx_deals SET
    customer_paid_pkr = customer_paid_pkr + p_amount_pkr,
    customer_receivable_pkr = GREATEST(0, customer_payable_pkr - customer_paid_pkr - p_amount_pkr),
    status = (CASE
      WHEN customer_paid_pkr + p_amount_pkr >= customer_payable_pkr THEN 'customer_paid'
      WHEN customer_paid_pkr + p_amount_pkr > 0 THEN 'customer_partially_paid'
      ELSE status::text
    END)::fx_deal_status,
    updated_at = NOW()
  WHERE id = p_deal_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_add_deal_leg — generic leg append
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_add_deal_leg(
  p_deal_id UUID,
  p_leg_type fx_deal_leg_type,
  p_counterparty_party_id UUID DEFAULT NULL,
  p_receive_currency TEXT DEFAULT NULL,
  p_receive_amount NUMERIC DEFAULT 0,
  p_pay_currency TEXT DEFAULT NULL,
  p_pay_amount NUMERIC DEFAULT 0,
  p_rate_used NUMERIC DEFAULT NULL,
  p_delivery_target fx_delivery_target DEFAULT NULL,
  p_parent_leg_id UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_leg_no INT;
  v_leg_id UUID;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    paid_amount, remaining_amount, delivery_target, parent_leg_id, notes
  ) VALUES (
    p_deal_id, v_leg_no, p_leg_type, 'pending'::fx_deal_leg_status, p_counterparty_party_id,
    CASE WHEN p_receive_currency IS NOT NULL THEN fx_normalize_currency_code(p_receive_currency) ELSE NULL END,
    COALESCE(p_receive_amount, 0),
    CASE WHEN p_pay_currency IS NOT NULL THEN fx_normalize_currency_code(p_pay_currency) ELSE NULL END,
    COALESCE(p_pay_amount, 0), p_rate_used,
    0, COALESCE(p_pay_amount, p_receive_amount, 0),
    p_delivery_target, p_parent_leg_id, p_notes
  ) RETURNING id INTO v_leg_id;

  IF p_leg_type = 'agent_source' THEN
    UPDATE fx_deals SET status = 'sourcing_in_progress'::fx_deal_status, updated_at = NOW() WHERE id = p_deal_id;
    INSERT INTO fx_currency_commitments (deal_id, leg_id, currency_code, commitment_type, committed_amount)
    VALUES (p_deal_id, v_leg_id, fx_normalize_currency_code(p_receive_currency), 'on_order_inbound'::fx_commitment_type, p_receive_amount);
  END IF;

  RETURN v_leg_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_add_settlement_link
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_add_settlement_link(
  p_deal_id UUID,
  p_from_leg_id UUID,
  p_to_leg_id UUID,
  p_link_type fx_settlement_link_type,
  p_currency_code TEXT,
  p_amount NUMERIC,
  p_proof_reference TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_deal fx_deals;
BEGIN
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  INSERT INTO fx_settlement_links (deal_id, from_leg_id, to_leg_id, link_type, currency_code, amount, proof_reference)
  VALUES (p_deal_id, p_from_leg_id, p_to_leg_id, p_link_type, fx_normalize_currency_code(p_currency_code), p_amount, p_proof_reference)
  RETURNING id INTO v_id;

  UPDATE fx_settlement_links SET status = 'completed'::fx_deal_leg_status, updated_at = NOW() WHERE id = v_id;
  RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_confirm_deal_delivery — final delivery + P/L recognition
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_confirm_deal_delivery(
  p_deal_id UUID,
  p_delivered_amount NUMERIC,
  p_delivery_target fx_delivery_target DEFAULT 'direct_to_customer',
  p_cost_basis_pkr NUMERIC DEFAULT NULL,
  p_proof_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_tx_id UUID;
  v_leg_no INT;
  v_leg_id UUID;
  v_cost NUMERIC;
  v_profit NUMERIC;
  v_foreign_cash UUID;
  v_advances UUID;
  v_receivable UUID;
  v_spread UUID;
  v_clearing UUID;
  v_line_no INT := 0;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  v_cost := COALESCE(p_cost_basis_pkr, v_deal.cost_basis_pkr, v_deal.customer_payable_pkr);
  v_profit := v_deal.customer_payable_pkr - v_cost;

  v_foreign_cash := fx_account_id_by_code(v_deal.company_id,
    CASE fx_normalize_currency_code(v_deal.sell_currency_code)
      WHEN 'PKR' THEN '1110' WHEN 'USD' THEN '1120' WHEN 'AED' THEN '1130'
      WHEN 'CNY' THEN '1140' WHEN 'SAR' THEN '1150' ELSE '1110'
    END);
  v_advances := fx_account_id_by_code(v_deal.company_id, '1160');
  v_receivable := fx_account_id_by_code(v_deal.company_id, '1190');
  v_spread := fx_account_id_by_code(v_deal.company_id, '4100');
  v_clearing := fx_account_id_by_code(v_deal.company_id, '1170');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, created_by
  ) VALUES (
    v_deal.company_id, v_deal.branch_id, 'currency_sell', 'draft', CURRENT_DATE,
    v_deal.customer_party_id, v_deal.sell_currency_code, p_delivered_amount,
    v_deal.sale_rate_pkr, v_deal.customer_payable_pkr,
    COALESCE(p_notes, 'Delivery — deal ' || v_deal.deal_no),
    p_deal_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  -- Dr Customer Advance (paid portion) + Dr Receivable (unpaid) / Cr Foreign cash at cost + Cr Spread
  IF v_deal.customer_paid_pkr > 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_advances, 'PKR', v_deal.customer_paid_pkr, 1, v_deal.customer_paid_pkr, 0, 'Clear customer advance');
  END IF;

  IF v_deal.customer_receivable_pkr > 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_receivable, 'PKR', v_deal.customer_receivable_pkr, 1, v_deal.customer_receivable_pkr, 0, 'Customer receivable');
  END IF;

  v_line_no := v_line_no + 1;
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, v_line_no, v_foreign_cash, v_deal.sell_currency_code, p_delivered_amount, v_deal.sale_rate_pkr, 0, v_cost, 'RMB delivered at cost');

  IF v_profit <> 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, v_line_no, v_spread, 'PKR', ABS(v_profit), 1, CASE WHEN v_profit < 0 THEN ABS(v_profit) ELSE 0 END, CASE WHEN v_profit > 0 THEN v_profit ELSE 0 END, 'FX spread income');
  END IF;

  PERFORM fx_post_transaction(v_tx_id);

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;
  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, delivery_target,
    linked_transaction_id, proof_reference, notes, completed_at
  ) VALUES (
    p_deal_id, v_leg_no, 'delivery'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, v_deal.customer_party_id,
    v_deal.sell_currency_code, p_delivered_amount, p_delivery_target,
    v_tx_id, p_proof_reference, p_notes, NOW()
  ) RETURNING id INTO v_leg_id;

  UPDATE fx_transactions SET leg_id = v_leg_id WHERE id = v_tx_id;

  UPDATE fx_currency_commitments SET
    delivered_amount = delivered_amount + p_delivered_amount,
    is_open = CASE WHEN delivered_amount + p_delivered_amount >= committed_amount THEN FALSE ELSE is_open END,
    updated_at = NOW()
  WHERE deal_id = p_deal_id AND commitment_type = 'customer_sale'::fx_commitment_type;

  UPDATE fx_deals SET
    status = 'completed'::fx_deal_status,
    actual_profit_pkr = v_profit,
    cost_basis_pkr = v_cost,
    completed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_deal_id;

  RETURN v_leg_id;
END;
$$;
-- <<<<< END 202606170003_fx_deals_enum_cast_fix.sql

-- >>>>> BEGIN 202606180001_fx_rates_reference_snapshot.sql
-- DRAFT: Reference rate snapshot columns (DO NOT deploy until approved)
-- SUPERSEDED BY: 202606180002_fx_rates_versioning_and_snapshots.sql
-- Project: ygidlcqhupmxvsdjmvnf only
--
-- Phase 1 ships UI-only reference display; this migration enables persisting
-- reference snapshots at deal/transaction booking time.

-- fx_rates: optional source metadata (manual / SBP / market / api)
ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS rate_source TEXT NOT NULL DEFAULT 'manual';

-- fx_deal_legs: reference snapshot at leg creation
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate NUMERIC(20, 8);
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_pair TEXT;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_source TEXT;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_at TIMESTAMPTZ;

-- fx_transactions: reference snapshot for draft/posted transactions
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate NUMERIC(20, 8);
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_pair TEXT;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_source TEXT;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_at TIMESTAMPTZ;

-- NOTE: After approval, update fx_add_deal_leg and transaction insert RPCs
-- to accept optional reference snapshot params. Posting continues to use rate_used only.
-- <<<<< END 202606180001_fx_rates_reference_snapshot.sql

-- >>>>> BEGIN 202606180002_fx_rates_versioning_and_snapshots.sql
-- DRAFT: Rate versioning metadata + reference rate snapshots (DO NOT deploy until approved)
-- Supersedes partial draft 202606180001_fx_rates_reference_snapshot.sql
-- Project: ygidlcqhupmxvsdjmvnf only
--
-- After approval: npx supabase db push, then set FeatureFlags.rateSnapshotColumnsEnabled = true

-- ---------------------------------------------------------------------------
-- fx_rates versioning metadata
-- ---------------------------------------------------------------------------

ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS rate_source TEXT NOT NULL DEFAULT 'manual';
ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS superseded_at TIMESTAMPTZ;

-- ---------------------------------------------------------------------------
-- fx_transactions reference snapshots (audit-only; posting uses rate_used)
-- ---------------------------------------------------------------------------

ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate NUMERIC(20, 8);
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_source TEXT;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_pair TEXT;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_at TIMESTAMPTZ;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_is_stale BOOLEAN;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS deal_rate_spread NUMERIC(20, 8);
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS deal_rate_spread_percent NUMERIC(10, 4);
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS rate_locked_at TIMESTAMPTZ;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS rate_locked_by UUID REFERENCES auth.users(id);
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_id UUID REFERENCES fx_rates(id);

-- ---------------------------------------------------------------------------
-- fx_deal_legs reference snapshots
-- ---------------------------------------------------------------------------

ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate NUMERIC(20, 8);
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_source TEXT;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_pair TEXT;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_at TIMESTAMPTZ;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_is_stale BOOLEAN;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS deal_rate_spread NUMERIC(20, 8);
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS deal_rate_spread_percent NUMERIC(10, 4);
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS rate_locked_at TIMESTAMPTZ;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS rate_locked_by UUID REFERENCES auth.users(id);
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_id UUID REFERENCES fx_rates(id);

-- ---------------------------------------------------------------------------
-- fx_deals reference snapshots (customer order booking)
-- ---------------------------------------------------------------------------

ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate NUMERIC(20, 8);
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate_source TEXT;
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate_pair TEXT;
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate_at TIMESTAMPTZ;
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate_is_stale BOOLEAN;
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS deal_rate_spread NUMERIC(20, 8);
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS deal_rate_spread_percent NUMERIC(10, 4);
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS rate_locked_at TIMESTAMPTZ;
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS rate_locked_by UUID REFERENCES auth.users(id);
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate_id UUID REFERENCES fx_rates(id);

-- ---------------------------------------------------------------------------
-- fx_book_customer_deal — optional snapshot params
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_book_customer_deal(
  p_branch_id UUID,
  p_customer_party_id UUID,
  p_sell_currency_code TEXT,
  p_sell_amount NUMERIC,
  p_sale_rate_pkr NUMERIC,
  p_customer_paid_now_pkr NUMERIC DEFAULT 0,
  p_delivery_method fx_delivery_method DEFAULT 'later',
  p_allow_short_position BOOLEAN DEFAULT FALSE,
  p_notes TEXT DEFAULT NULL,
  p_auto_source BOOLEAN DEFAULT TRUE,
  p_reference_rate NUMERIC DEFAULT NULL,
  p_reference_rate_pair TEXT DEFAULT NULL,
  p_reference_rate_source TEXT DEFAULT NULL,
  p_reference_rate_at TIMESTAMPTZ DEFAULT NULL,
  p_reference_rate_is_stale BOOLEAN DEFAULT NULL,
  p_deal_rate_spread NUMERIC DEFAULT NULL,
  p_deal_rate_spread_percent NUMERIC DEFAULT NULL,
  p_reference_rate_id UUID DEFAULT NULL,
  p_rate_locked_at TIMESTAMPTZ DEFAULT NULL,
  p_rate_locked_by UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_deal_id UUID;
  v_leg_id UUID;
  v_payable NUMERIC(20, 8);
  v_currency TEXT;
  v_available NUMERIC;
  v_required NUMERIC;
  v_status fx_deal_status;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_profile FROM fx_current_profile();
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  v_currency := fx_normalize_currency_code(p_sell_currency_code);
  v_payable := ROUND(p_sell_amount * p_sale_rate_pkr, 8);

  INSERT INTO fx_deals (
    company_id, branch_id, customer_party_id,
    sell_currency_code, sell_amount, sale_rate_pkr,
    customer_payable_pkr, customer_paid_pkr, customer_receivable_pkr,
    delivery_method, status, allow_short_position, notes,
    booked_at, created_by,
    reference_rate, reference_rate_pair, reference_rate_source, reference_rate_at,
    reference_rate_is_stale, deal_rate_spread, deal_rate_spread_percent,
    reference_rate_id, rate_locked_at, rate_locked_by
  ) VALUES (
    v_profile.company_id, p_branch_id, p_customer_party_id,
    v_currency, p_sell_amount, p_sale_rate_pkr,
    v_payable, COALESCE(p_customer_paid_now_pkr, 0),
    GREATEST(0, v_payable - COALESCE(p_customer_paid_now_pkr, 0)),
    p_delivery_method,
    (CASE
      WHEN COALESCE(p_customer_paid_now_pkr, 0) >= v_payable THEN 'customer_paid'
      WHEN COALESCE(p_customer_paid_now_pkr, 0) > 0 THEN 'customer_partially_paid'
      ELSE 'booked'
    END)::fx_deal_status,
    COALESCE(p_allow_short_position, FALSE),
    p_notes,
    NOW(), auth.uid(),
    p_reference_rate, p_reference_rate_pair, p_reference_rate_source, p_reference_rate_at,
    p_reference_rate_is_stale, p_deal_rate_spread, p_deal_rate_spread_percent,
    p_reference_rate_id, p_rate_locked_at, p_rate_locked_by
  )
  RETURNING id INTO v_deal_id;

  UPDATE fx_deals SET deal_no = fx_generate_deal_no(p_branch_id) WHERE id = v_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    remaining_amount, notes,
    reference_rate, reference_rate_pair, reference_rate_source, reference_rate_at,
    reference_rate_is_stale, deal_rate_spread, deal_rate_spread_percent,
    reference_rate_id, rate_locked_at, rate_locked_by
  ) VALUES (
    v_deal_id, 1, 'customer_order'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, p_customer_party_id,
    v_currency, p_sell_amount, 'PKR', v_payable, p_sale_rate_pkr,
    0, 'Customer FX order booked',
    p_reference_rate, p_reference_rate_pair, p_reference_rate_source, p_reference_rate_at,
    p_reference_rate_is_stale, p_deal_rate_spread, p_deal_rate_spread_percent,
    p_reference_rate_id, p_rate_locked_at, p_rate_locked_by
  );

  INSERT INTO fx_currency_commitments (
    deal_id, leg_id, currency_code, commitment_type, committed_amount
  ) VALUES (
    v_deal_id,
    (SELECT id FROM fx_deal_legs WHERE deal_id = v_deal_id AND leg_no = 1),
    v_currency, 'customer_sale'::fx_commitment_type, p_sell_amount
  );

  v_available := fx_deal_actual_balance(p_branch_id, v_currency) - fx_deal_open_commitment(p_branch_id, v_currency, 'customer_sale'::fx_commitment_type) + p_sell_amount;
  v_required := GREATEST(0, p_sell_amount - v_available);

  IF v_required > 0 AND p_auto_source THEN
    v_status := 'sourcing_required'::fx_deal_status;
    INSERT INTO fx_deal_legs (
      deal_id, leg_no, leg_type, status,
      receive_currency, receive_amount, remaining_amount, notes
    ) VALUES (
      v_deal_id, 2, 'sourcing_requirement'::fx_deal_leg_type, 'pending'::fx_deal_leg_status,
      v_currency, v_required, v_required,
      'Auto-created: insufficient available balance'
    );
    INSERT INTO fx_currency_commitments (
      deal_id, currency_code, commitment_type, committed_amount
    ) VALUES (
      v_deal_id, v_currency, 'sourcing_required'::fx_commitment_type, v_required
    );
    UPDATE fx_deals SET status = v_status WHERE id = v_deal_id;
  ELSIF v_required > 0 AND NOT COALESCE(p_allow_short_position, FALSE) THEN
    UPDATE fx_deals SET status = 'sourcing_required'::fx_deal_status WHERE id = v_deal_id;
  END IF;

  RETURN v_deal_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_add_deal_leg — optional snapshot params
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_add_deal_leg(
  p_deal_id UUID,
  p_leg_type fx_deal_leg_type,
  p_counterparty_party_id UUID DEFAULT NULL,
  p_receive_currency TEXT DEFAULT NULL,
  p_receive_amount NUMERIC DEFAULT 0,
  p_pay_currency TEXT DEFAULT NULL,
  p_pay_amount NUMERIC DEFAULT 0,
  p_rate_used NUMERIC DEFAULT NULL,
  p_delivery_target fx_delivery_target DEFAULT NULL,
  p_parent_leg_id UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_reference_rate NUMERIC DEFAULT NULL,
  p_reference_rate_pair TEXT DEFAULT NULL,
  p_reference_rate_source TEXT DEFAULT NULL,
  p_reference_rate_at TIMESTAMPTZ DEFAULT NULL,
  p_reference_rate_is_stale BOOLEAN DEFAULT NULL,
  p_deal_rate_spread NUMERIC DEFAULT NULL,
  p_deal_rate_spread_percent NUMERIC DEFAULT NULL,
  p_reference_rate_id UUID DEFAULT NULL,
  p_rate_locked_at TIMESTAMPTZ DEFAULT NULL,
  p_rate_locked_by UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_leg_no INT;
  v_leg_id UUID;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    paid_amount, remaining_amount, delivery_target, parent_leg_id, notes,
    reference_rate, reference_rate_pair, reference_rate_source, reference_rate_at,
    reference_rate_is_stale, deal_rate_spread, deal_rate_spread_percent,
    reference_rate_id, rate_locked_at, rate_locked_by
  ) VALUES (
    p_deal_id, v_leg_no, p_leg_type, 'pending'::fx_deal_leg_status, p_counterparty_party_id,
    CASE WHEN p_receive_currency IS NOT NULL THEN fx_normalize_currency_code(p_receive_currency) ELSE NULL END,
    COALESCE(p_receive_amount, 0),
    CASE WHEN p_pay_currency IS NOT NULL THEN fx_normalize_currency_code(p_pay_currency) ELSE NULL END,
    COALESCE(p_pay_amount, 0), p_rate_used,
    0, COALESCE(p_pay_amount, p_receive_amount, 0),
    p_delivery_target, p_parent_leg_id, p_notes,
    p_reference_rate, p_reference_rate_pair, p_reference_rate_source, p_reference_rate_at,
    p_reference_rate_is_stale, p_deal_rate_spread, p_deal_rate_spread_percent,
    p_reference_rate_id, p_rate_locked_at, p_rate_locked_by
  )
  RETURNING id INTO v_leg_id;

  RETURN v_leg_id;
END;
$$;
-- <<<<< END 202606180002_fx_rates_versioning_and_snapshots.sql

-- >>>>> BEGIN 202606180005_fx_deal_rpc_v2_consolidation.sql
-- FX Deal RPC v2 consolidation — resolves PostgREST PGRST203 overload ambiguity
-- Project: ygidlcqhupmxvsdjmvnf only
--
-- Drops ALL legacy fx_add_deal_leg / fx_book_customer_deal overloads.
-- Creates single JSONB entry points: fx_add_deal_leg_v2, fx_book_customer_deal_v2
-- Business logic merged from 202606170003 + optional rate snapshot columns from 180002.
--
-- Rule: never add positional overloads to deal RPCs; extend JSONB keys only.

-- ---------------------------------------------------------------------------
-- Snapshot / rate metadata columns (idempotent)
-- ---------------------------------------------------------------------------

ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS rate_source TEXT NOT NULL DEFAULT 'manual';
ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE fx_rates ADD COLUMN IF NOT EXISTS superseded_at TIMESTAMPTZ;

ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate NUMERIC(20, 8);
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_source TEXT;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_pair TEXT;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_at TIMESTAMPTZ;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_is_stale BOOLEAN;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS deal_rate_spread NUMERIC(20, 8);
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS deal_rate_spread_percent NUMERIC(10, 4);
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS rate_locked_at TIMESTAMPTZ;
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS rate_locked_by UUID REFERENCES auth.users(id);
ALTER TABLE fx_transactions ADD COLUMN IF NOT EXISTS reference_rate_id UUID REFERENCES fx_rates(id);

ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate NUMERIC(20, 8);
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_source TEXT;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_pair TEXT;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_at TIMESTAMPTZ;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_is_stale BOOLEAN;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS deal_rate_spread NUMERIC(20, 8);
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS deal_rate_spread_percent NUMERIC(10, 4);
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS rate_locked_at TIMESTAMPTZ;
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS rate_locked_by UUID REFERENCES auth.users(id);
ALTER TABLE fx_deal_legs ADD COLUMN IF NOT EXISTS reference_rate_id UUID REFERENCES fx_rates(id);

ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate NUMERIC(20, 8);
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate_source TEXT;
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate_pair TEXT;
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate_at TIMESTAMPTZ;
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate_is_stale BOOLEAN;
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS deal_rate_spread NUMERIC(20, 8);
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS deal_rate_spread_percent NUMERIC(10, 4);
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS rate_locked_at TIMESTAMPTZ;
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS rate_locked_by UUID REFERENCES auth.users(id);
ALTER TABLE fx_deals ADD COLUMN IF NOT EXISTS reference_rate_id UUID REFERENCES fx_rates(id);

-- ---------------------------------------------------------------------------
-- Drop legacy overloaded RPCs (explicit signatures)
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.fx_add_deal_leg(
  uuid, fx_deal_leg_type, uuid, text, numeric, text, numeric, numeric,
  fx_delivery_target, uuid, text
);

DROP FUNCTION IF EXISTS public.fx_add_deal_leg(
  uuid, fx_deal_leg_type, uuid, text, numeric, text, numeric, numeric,
  fx_delivery_target, uuid, text,
  numeric, text, text, timestamptz, boolean, numeric, numeric, uuid, timestamptz, uuid
);

DROP FUNCTION IF EXISTS public.fx_book_customer_deal(
  uuid, uuid, text, numeric, numeric, numeric,
  fx_delivery_method, boolean, text, boolean
);

DROP FUNCTION IF EXISTS public.fx_book_customer_deal(
  uuid, uuid, text, numeric, numeric, numeric,
  fx_delivery_method, boolean, text, boolean,
  numeric, text, text, timestamptz, boolean, numeric, numeric, uuid, timestamptz, uuid
);

DROP FUNCTION IF EXISTS public.fx_add_deal_leg_v2(jsonb);
DROP FUNCTION IF EXISTS public.fx_book_customer_deal_v2(jsonb);

-- ---------------------------------------------------------------------------
-- fx_book_customer_deal_v2 — JSONB payload
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_book_customer_deal_v2(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_deal_id UUID;
  v_payable NUMERIC(20, 8);
  v_currency TEXT;
  v_available NUMERIC;
  v_required NUMERIC;
  v_status fx_deal_status;
  v_branch_id UUID := (p_payload->>'branch_id')::UUID;
  v_customer_party_id UUID := (p_payload->>'customer_party_id')::UUID;
  v_sell_amount NUMERIC := COALESCE((p_payload->>'sell_amount')::NUMERIC, 0);
  v_sale_rate_pkr NUMERIC := COALESCE((p_payload->>'sale_rate_pkr')::NUMERIC, 0);
  v_paid_now NUMERIC := COALESCE((p_payload->>'customer_paid_now_pkr')::NUMERIC, 0);
  v_delivery_method fx_delivery_method := COALESCE(
    NULLIF(p_payload->>'delivery_method', '')::fx_delivery_method, 'later'::fx_delivery_method
  );
  v_allow_short BOOLEAN := COALESCE((p_payload->>'allow_short_position')::BOOLEAN, FALSE);
  v_notes TEXT := NULLIF(p_payload->>'notes', '');
  v_auto_source BOOLEAN := COALESCE((p_payload->>'auto_source')::BOOLEAN, TRUE);
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_profile FROM fx_current_profile();
  IF NOT fx_same_branch(v_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  v_currency := fx_normalize_currency_code(p_payload->>'sell_currency_code');
  v_payable := ROUND(v_sell_amount * v_sale_rate_pkr, 8);

  INSERT INTO fx_deals (
    company_id, branch_id, customer_party_id,
    sell_currency_code, sell_amount, sale_rate_pkr,
    customer_payable_pkr, customer_paid_pkr, customer_receivable_pkr,
    delivery_method, status, allow_short_position, notes,
    booked_at, created_by,
    reference_rate, reference_rate_pair, reference_rate_source, reference_rate_at,
    reference_rate_is_stale, deal_rate_spread, deal_rate_spread_percent,
    reference_rate_id, rate_locked_at, rate_locked_by
  ) VALUES (
    v_profile.company_id, v_branch_id, v_customer_party_id,
    v_currency, v_sell_amount, v_sale_rate_pkr,
    v_payable, v_paid_now,
    GREATEST(0, v_payable - v_paid_now),
    v_delivery_method,
    (CASE
      WHEN v_paid_now >= v_payable THEN 'customer_paid'
      WHEN v_paid_now > 0 THEN 'customer_partially_paid'
      ELSE 'booked'
    END)::fx_deal_status,
    v_allow_short,
    v_notes,
    NOW(), auth.uid(),
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
  )
  RETURNING id INTO v_deal_id;

  UPDATE fx_deals SET deal_no = fx_generate_deal_no(v_branch_id) WHERE id = v_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    receive_currency, receive_amount, pay_currency, pay_amount, rate_used,
    remaining_amount, notes,
    reference_rate, reference_rate_pair, reference_rate_source, reference_rate_at,
    reference_rate_is_stale, deal_rate_spread, deal_rate_spread_percent,
    reference_rate_id, rate_locked_at, rate_locked_by
  ) VALUES (
    v_deal_id, 1, 'customer_order'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, v_customer_party_id,
    v_currency, v_sell_amount, 'PKR', v_payable, v_sale_rate_pkr,
    0, 'Customer FX order booked',
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
  );

  INSERT INTO fx_currency_commitments (
    deal_id, leg_id, currency_code, commitment_type, committed_amount
  ) VALUES (
    v_deal_id,
    (SELECT id FROM fx_deal_legs WHERE deal_id = v_deal_id AND leg_no = 1),
    v_currency, 'customer_sale'::fx_commitment_type, v_sell_amount
  );

  v_available := fx_deal_actual_balance(v_branch_id, v_currency)
    - fx_deal_open_commitment(v_branch_id, v_currency, 'customer_sale'::fx_commitment_type)
    + v_sell_amount;
  v_required := GREATEST(0, v_sell_amount - v_available);

  IF v_required > 0 AND v_auto_source THEN
    v_status := 'sourcing_required'::fx_deal_status;
    INSERT INTO fx_deal_legs (
      deal_id, leg_no, leg_type, status,
      receive_currency, receive_amount, remaining_amount, notes
    ) VALUES (
      v_deal_id, 2, 'sourcing_requirement'::fx_deal_leg_type, 'pending'::fx_deal_leg_status,
      v_currency, v_required, v_required,
      'Auto-created: insufficient available balance'
    );
    INSERT INTO fx_currency_commitments (
      deal_id, currency_code, commitment_type, committed_amount
    ) VALUES (
      v_deal_id, v_currency, 'sourcing_required'::fx_commitment_type, v_required
    );
    UPDATE fx_deals SET status = v_status WHERE id = v_deal_id;
  ELSIF v_required > 0 AND NOT v_allow_short THEN
    UPDATE fx_deals SET status = 'sourcing_required'::fx_deal_status WHERE id = v_deal_id;
  END IF;

  RETURN v_deal_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_add_deal_leg_v2 — JSONB payload (full 170003 logic + snapshots)
-- ---------------------------------------------------------------------------

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
    reference_rate, reference_rate_pair, reference_rate_source, reference_rate_at,
    reference_rate_is_stale, deal_rate_spread, deal_rate_spread_percent,
    reference_rate_id, rate_locked_at, rate_locked_by
  ) VALUES (
    v_deal_id, v_leg_no, v_leg_type, 'pending'::fx_deal_leg_status, v_counterparty,
    CASE WHEN v_receive_currency IS NOT NULL THEN fx_normalize_currency_code(v_receive_currency) ELSE NULL END,
    v_receive_amount,
    CASE WHEN v_pay_currency IS NOT NULL THEN fx_normalize_currency_code(v_pay_currency) ELSE NULL END,
    v_pay_amount, v_rate_used,
    0, COALESCE(v_pay_amount, v_receive_amount, 0),
    v_delivery_target, v_parent_leg_id, v_notes,
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
  END IF;

  RETURN v_leg_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- Grants (v2 only — legacy names removed from PostgREST)
-- ---------------------------------------------------------------------------

GRANT EXECUTE ON FUNCTION fx_book_customer_deal_v2(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_add_deal_leg_v2(JSONB) TO authenticated;

NOTIFY pgrst, 'reload schema';
-- <<<<< END 202606180005_fx_deal_rpc_v2_consolidation.sql

-- >>>>> BEGIN 202606190001_fx_deal_leg_attachments.sql
-- Per-leg deal attachments — fx_attachments.deal_id / deal_leg_id
-- Project: ygidlcqhupmxvsdjmvnf only

ALTER TABLE fx_attachments
  ADD COLUMN IF NOT EXISTS deal_id UUID REFERENCES fx_deals(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS deal_leg_id UUID REFERENCES fx_deal_legs(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS attachment_type TEXT;

ALTER TABLE fx_attachments ALTER COLUMN transaction_id DROP NOT NULL;

ALTER TABLE fx_attachments DROP CONSTRAINT IF EXISTS fx_attachments_target_check;
ALTER TABLE fx_attachments ADD CONSTRAINT fx_attachments_target_check
  CHECK (transaction_id IS NOT NULL OR deal_leg_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_fx_attachments_deal_leg ON fx_attachments(deal_leg_id);
CREATE INDEX IF NOT EXISTS idx_fx_attachments_deal ON fx_attachments(deal_id);

-- RLS: extend select/insert for deal-leg attachments
DROP POLICY IF EXISTS fx_attachments_select ON fx_attachments;
CREATE POLICY fx_attachments_select ON fx_attachments
  FOR SELECT TO authenticated
  USING (
    fx_has_permission('can_access_fx_ledger')
    AND (
      (transaction_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_transactions t
        WHERE t.id = transaction_id AND fx_same_branch(t.branch_id)
      ))
      OR (deal_leg_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_deal_legs l
        JOIN fx_deals d ON d.id = l.deal_id
        WHERE l.id = deal_leg_id AND fx_same_branch(d.branch_id)
      ))
    )
  );

DROP POLICY IF EXISTS fx_attachments_insert ON fx_attachments;
CREATE POLICY fx_attachments_insert ON fx_attachments
  FOR INSERT TO authenticated
  WITH CHECK (
    fx_has_permission('can_access_fx_ledger')
    AND (
      (transaction_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_transactions t
        WHERE t.id = transaction_id AND fx_same_branch(t.branch_id)
      ))
      OR (deal_leg_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_deal_legs l
        JOIN fx_deals d ON d.id = l.deal_id
        WHERE l.id = deal_leg_id AND fx_same_branch(d.branch_id)
      ))
    )
  );

DROP POLICY IF EXISTS fx_attachments_delete ON fx_attachments;
CREATE POLICY fx_attachments_delete ON fx_attachments
  FOR DELETE TO authenticated
  USING (
    fx_has_permission('can_access_fx_ledger')
    AND (
      (transaction_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_transactions t
        WHERE t.id = transaction_id AND fx_same_branch(t.branch_id)
      ))
      OR (deal_leg_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_deal_legs l
        JOIN fx_deals d ON d.id = l.deal_id
        WHERE l.id = deal_leg_id AND fx_same_branch(d.branch_id)
      ))
    )
  );

-- Timeline: attachment count per leg (drop required — return type change)
DROP FUNCTION IF EXISTS public.fx_get_deal_timeline(UUID);

CREATE OR REPLACE FUNCTION fx_get_deal_timeline(p_deal_id UUID)
RETURNS TABLE (
  leg_id UUID,
  leg_no INT,
  leg_type fx_deal_leg_type,
  leg_status fx_deal_leg_status,
  counterparty_name TEXT,
  receive_currency TEXT,
  receive_amount NUMERIC,
  pay_currency TEXT,
  pay_amount NUMERIC,
  paid_amount NUMERIC,
  remaining_amount NUMERIC,
  proof_reference TEXT,
  notes TEXT,
  linked_transaction_no TEXT,
  created_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  attachment_count BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
BEGIN
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  RETURN QUERY
  SELECT
    l.id, l.leg_no, l.leg_type, l.status,
    p.name,
    l.receive_currency, l.receive_amount,
    l.pay_currency, l.pay_amount,
    l.paid_amount, l.remaining_amount,
    l.proof_reference, l.notes,
    t.transaction_no,
    l.created_at, l.completed_at,
    (SELECT COUNT(*) FROM fx_attachments a WHERE a.deal_leg_id = l.id)::BIGINT
  FROM fx_deal_legs l
  LEFT JOIN fx_parties p ON p.id = l.counterparty_party_id
  LEFT JOIN fx_transactions t ON t.id = l.linked_transaction_id
  WHERE l.deal_id = p_deal_id
  ORDER BY l.leg_no;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_get_deal_timeline(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
-- <<<<< END 202606190001_fx_deal_leg_attachments.sql

-- >>>>> BEGIN 202606190002_fx_seed_afn_currency.sql
-- Seed AFN (Afghan Afghani) default currency + cash COA account
-- PKR remains base. SAR retained.

INSERT INTO fx_currencies (code, name, symbol, decimal_places, is_base, is_active)
VALUES ('AFN', 'Afghan Afghani', '؋', 2, FALSE, TRUE)
ON CONFLICT (code) DO NOTHING;

DO $$
DECLARE
  v_company UUID := '00000000-0000-4000-8000-000000000001';
  v_afn UUID;
  v_assets UUID;
  v_acct_code TEXT;
  v_slot INT;
BEGIN
  SELECT id INTO v_company FROM fx_companies WHERE code = 'FXDEV';
  IF v_company IS NULL THEN
    SELECT id INTO v_company FROM fx_companies LIMIT 1;
  END IF;
  IF v_company IS NULL THEN RETURN; END IF;

  SELECT id INTO v_afn FROM fx_currencies WHERE code = 'AFN';
  IF v_afn IS NULL THEN RETURN; END IF;

  SELECT id INTO v_assets FROM fx_accounts WHERE company_id = v_company AND code = '1000';
  IF v_assets IS NULL THEN RETURN; END IF;

  IF EXISTS (SELECT 1 FROM fx_accounts WHERE company_id = v_company AND currency_id = v_afn) THEN
    RETURN;
  END IF;

  v_acct_code := NULL;
  FOR v_slot IN 1151..1159 LOOP
    IF NOT EXISTS (SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = v_slot::TEXT) THEN
      v_acct_code := v_slot::TEXT;
      EXIT;
    END IF;
  END LOOP;

  IF v_acct_code IS NULL THEN
    FOR v_slot IN 1181..1189 LOOP
      IF NOT EXISTS (SELECT 1 FROM fx_accounts WHERE company_id = v_company AND code = v_slot::TEXT) THEN
        v_acct_code := v_slot::TEXT;
        EXIT;
      END IF;
    END LOOP;
  END IF;

  IF v_acct_code IS NOT NULL THEN
    INSERT INTO fx_accounts (company_id, parent_id, code, name, account_type, currency_id)
    VALUES (v_company, v_assets, v_acct_code, 'Cash AFN', 'asset', v_afn)
    ON CONFLICT (company_id, code) DO NOTHING;
  END IF;
END $$;
-- <<<<< END 202606190002_fx_seed_afn_currency.sql

-- >>>>> BEGIN 202606200001_fx_fix_deal_number_sequence.sql
-- Fix deal number generation — sequence overflow on ::INT cast
-- Bug: stripping all non-digits from 'DL-20260610-0001' → 202606100001 (> INT max)
-- Same fix pattern as 202606120002 (transaction/journal numbers)
-- Project: ygidlcqhupmxvsdjmvnf only

CREATE OR REPLACE FUNCTION fx_generate_deal_no(p_branch_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prefix TEXT;
  v_seq INT;
BEGIN
  v_prefix := TO_CHAR(NOW(), 'YYYYMMDD');

  SELECT COALESCE(MAX((regexp_match(deal_no, '-(\d+)$'))[1]::INT), 0) + 1
  INTO v_seq
  FROM fx_deals
  WHERE branch_id = p_branch_id
    AND deal_no LIKE 'DL-' || v_prefix || '-%';

  RETURN 'DL-' || v_prefix || '-' || LPAD(v_seq::TEXT, 4, '0');
END;
$$;

GRANT EXECUTE ON FUNCTION fx_generate_deal_no(UUID) TO authenticated;
-- <<<<< END 202606200001_fx_fix_deal_number_sequence.sql

-- >>>>> BEGIN 202606200002_fx_opening_balance_batches.sql
-- Opening balance batch workflow — draft wizard, RPC post, branch lock
-- Project: ygidlcqhupmxvsdjmvnf only (fx_* tables). Do not apply without approval.

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

DO $$ BEGIN
CREATE TYPE fx_opening_balance_batch_status AS ENUM ('draft', 'posted', 'voided');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;

DO $$ BEGIN
CREATE TYPE fx_opening_balance_line_kind AS ENUM (
  'cash_bank',
  'currency_position',
  'party_receivable',
  'party_payable'
);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fx_opening_balance_batches (
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

CREATE UNIQUE INDEX IF NOT EXISTS idx_fx_ob_batches_one_posted_per_branch
  ON fx_opening_balance_batches (branch_id)
  WHERE status = 'posted';

CREATE INDEX IF NOT EXISTS idx_fx_ob_batches_branch_status ON fx_opening_balance_batches (branch_id, status);

CREATE TABLE IF NOT EXISTS fx_opening_balance_lines (
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

CREATE INDEX IF NOT EXISTS idx_fx_transactions_ob_batch ON fx_transactions (opening_balance_batch_id)
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
-- <<<<< END 202606200002_fx_opening_balance_batches.sql

-- >>>>> BEGIN 202606210001_fx_display_currency.sql
-- Display currency preference on user profile
-- Project: ygidlcqhupmxvsdjmvnf — applied 2026-06-10

ALTER TABLE fx_users_profiles
  ADD COLUMN IF NOT EXISTS display_currency_code TEXT NOT NULL DEFAULT 'PKR';

COMMENT ON COLUMN fx_users_profiles.display_currency_code IS
  'User preferred reporting/display currency; accounting remains in company base currency.';

CREATE OR REPLACE FUNCTION fx_update_display_currency(p_code TEXT)
RETURNS fx_users_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Missing permission';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM fx_currencies WHERE code = p_code AND is_active) THEN
    RAISE EXCEPTION 'Invalid or inactive currency: %', p_code;
  END IF;
  UPDATE fx_users_profiles
  SET display_currency_code = p_code, updated_at = NOW()
  WHERE id = auth.uid()
  RETURNING * INTO v_profile;
  RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_update_display_currency(TEXT) TO authenticated;
-- <<<<< END 202606210001_fx_display_currency.sql

-- >>>>> BEGIN 202606210006_fx_deal_leg_edit_delete.sql
-- Safe edit/delete for pending deal legs (no linked posted transactions)

CREATE OR REPLACE FUNCTION fx_recompute_deal_status(p_deal_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_has_delivery BOOLEAN;
  v_has_agent_source BOOLEAN;
  v_has_pending_agent_source BOOLEAN;
  v_has_currency_receipt BOOLEAN;
  v_has_sourcing_req BOOLEAN;
BEGIN
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RETURN; END IF;

  IF v_deal.status IN ('completed', 'cancelled', 'voided', 'delivered') THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM fx_deal_legs
    WHERE deal_id = p_deal_id AND leg_type = 'delivery'::fx_deal_leg_type
  ) INTO v_has_delivery;

  IF v_has_delivery THEN RETURN; END IF;

  SELECT EXISTS (
    SELECT 1 FROM fx_deal_legs
    WHERE deal_id = p_deal_id AND leg_type = 'agent_source'::fx_deal_leg_type
  ) INTO v_has_agent_source;

  SELECT EXISTS (
    SELECT 1 FROM fx_deal_legs
    WHERE deal_id = p_deal_id
      AND leg_type = 'agent_source'::fx_deal_leg_type
      AND status = 'pending'::fx_deal_leg_status
  ) INTO v_has_pending_agent_source;

  SELECT EXISTS (
    SELECT 1 FROM fx_deal_legs
    WHERE deal_id = p_deal_id AND leg_type = 'currency_receipt'::fx_deal_leg_type
  ) INTO v_has_currency_receipt;

  SELECT EXISTS (
    SELECT 1 FROM fx_deal_legs
    WHERE deal_id = p_deal_id AND leg_type = 'sourcing_requirement'::fx_deal_leg_type
  ) INTO v_has_sourcing_req;

  IF v_has_currency_receipt THEN
    UPDATE fx_deals SET status = 'currency_received'::fx_deal_status, updated_at = NOW()
    WHERE id = p_deal_id;
  ELSIF v_has_agent_source AND NOT v_has_pending_agent_source THEN
    UPDATE fx_deals SET status = 'sourcing_in_progress'::fx_deal_status, updated_at = NOW()
    WHERE id = p_deal_id;
  ELSIF v_has_sourcing_req OR v_deal.status IN ('sourcing_required', 'sourcing_in_progress') THEN
    UPDATE fx_deals SET status = 'sourcing_required'::fx_deal_status, updated_at = NOW()
    WHERE id = p_deal_id;
  ELSIF v_deal.customer_receivable_pkr <= 0 THEN
    UPDATE fx_deals SET status = 'customer_paid'::fx_deal_status, updated_at = NOW()
    WHERE id = p_deal_id;
  ELSIF v_deal.customer_paid_pkr > 0 THEN
    UPDATE fx_deals SET status = 'customer_partially_paid'::fx_deal_status, updated_at = NOW()
    WHERE id = p_deal_id;
  ELSE
    UPDATE fx_deals SET status = 'booked'::fx_deal_status, updated_at = NOW()
    WHERE id = p_deal_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION fx_assert_deal_leg_mutable(p_leg_id UUID)
RETURNS TABLE (leg fx_deal_legs, deal fx_deals)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_leg fx_deal_legs;
  v_deal fx_deals;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_leg FROM fx_deal_legs WHERE id = p_leg_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal leg not found'; END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = v_leg.deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  IF v_deal.status IN ('completed', 'cancelled', 'voided') THEN
    RAISE EXCEPTION 'Cannot modify legs on a % deal', v_deal.status;
  END IF;

  IF v_leg.status <> 'pending'::fx_deal_leg_status THEN
    RAISE EXCEPTION 'Only pending legs can be edited or deleted';
  END IF;

  IF v_leg.linked_transaction_id IS NOT NULL THEN
    RAISE EXCEPTION 'Leg is linked to a posted transaction';
  END IF;

  IF v_leg.leg_type IN (
    'customer_order'::fx_deal_leg_type,
    'customer_payment'::fx_deal_leg_type,
    'delivery'::fx_deal_leg_type
  ) THEN
    RAISE EXCEPTION 'Leg type % cannot be edited or deleted', v_leg.leg_type;
  END IF;

  RETURN QUERY SELECT v_leg, v_deal;
END;
$$;

CREATE OR REPLACE FUNCTION fx_delete_deal_leg_v2(p_leg_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row RECORD;
  v_deal_id UUID;
BEGIN
  SELECT * INTO v_row FROM fx_assert_deal_leg_mutable(p_leg_id);
  v_deal_id := v_row.deal.id;

  DELETE FROM fx_settlement_links
  WHERE from_leg_id = p_leg_id OR to_leg_id = p_leg_id;

  DELETE FROM fx_currency_commitments WHERE leg_id = p_leg_id;

  DELETE FROM fx_deal_legs WHERE id = p_leg_id;

  PERFORM fx_recompute_deal_status(v_deal_id);

  RETURN p_leg_id;
END;
$$;

CREATE OR REPLACE FUNCTION fx_update_deal_leg_v2(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row RECORD;
  v_leg_id UUID := (p_payload->>'leg_id')::UUID;
  v_receive_currency TEXT := NULLIF(p_payload->>'receive_currency', '');
  v_receive_amount NUMERIC := COALESCE((p_payload->>'receive_amount')::NUMERIC, 0);
  v_pay_currency TEXT := NULLIF(p_payload->>'pay_currency', '');
  v_pay_amount NUMERIC := COALESCE((p_payload->>'pay_amount')::NUMERIC, 0);
  v_rate_used NUMERIC := NULLIF(p_payload->>'rate_used', '')::NUMERIC;
  v_delivery_target fx_delivery_target := NULLIF(p_payload->>'delivery_target', '')::fx_delivery_target;
  v_counterparty UUID := NULLIF(p_payload->>'counterparty_party_id', '')::UUID;
  v_notes TEXT := NULLIF(p_payload->>'notes', '');
  v_remaining NUMERIC;
BEGIN
  SELECT * INTO v_row FROM fx_assert_deal_leg_mutable(v_leg_id);

  v_remaining := COALESCE(NULLIF(v_pay_amount, 0), NULLIF(v_receive_amount, 0), v_row.leg.remaining_amount);

  UPDATE fx_deal_legs SET
    counterparty_party_id = COALESCE(v_counterparty, counterparty_party_id),
    receive_currency = CASE
      WHEN p_payload ? 'receive_currency' THEN
        CASE WHEN v_receive_currency IS NOT NULL THEN fx_normalize_currency_code(v_receive_currency) ELSE NULL END
      ELSE receive_currency
    END,
    receive_amount = CASE WHEN p_payload ? 'receive_amount' THEN v_receive_amount ELSE receive_amount END,
    pay_currency = CASE
      WHEN p_payload ? 'pay_currency' THEN
        CASE WHEN v_pay_currency IS NOT NULL THEN fx_normalize_currency_code(v_pay_currency) ELSE NULL END
      ELSE pay_currency
    END,
    pay_amount = CASE WHEN p_payload ? 'pay_amount' THEN v_pay_amount ELSE pay_amount END,
    rate_used = CASE WHEN p_payload ? 'rate_used' THEN v_rate_used ELSE rate_used END,
    remaining_amount = v_remaining,
    delivery_target = CASE WHEN p_payload ? 'delivery_target' THEN v_delivery_target ELSE delivery_target END,
    notes = CASE WHEN p_payload ? 'notes' THEN v_notes ELSE notes END,
    reference_rate = CASE WHEN p_payload ? 'reference_rate' THEN NULLIF(p_payload->>'reference_rate', '')::NUMERIC ELSE reference_rate END,
    reference_rate_pair = CASE WHEN p_payload ? 'reference_rate_pair' THEN NULLIF(p_payload->>'reference_rate_pair', '') ELSE reference_rate_pair END,
    reference_rate_source = CASE WHEN p_payload ? 'reference_rate_source' THEN NULLIF(p_payload->>'reference_rate_source', '') ELSE reference_rate_source END,
    reference_rate_at = CASE WHEN p_payload ? 'reference_rate_at' THEN NULLIF(p_payload->>'reference_rate_at', '')::TIMESTAMPTZ ELSE reference_rate_at END,
    reference_rate_is_stale = CASE WHEN p_payload ? 'reference_rate_is_stale' THEN (p_payload->>'reference_rate_is_stale')::BOOLEAN ELSE reference_rate_is_stale END,
    deal_rate_spread = CASE WHEN p_payload ? 'deal_rate_spread' THEN NULLIF(p_payload->>'deal_rate_spread', '')::NUMERIC ELSE deal_rate_spread END,
    deal_rate_spread_percent = CASE WHEN p_payload ? 'deal_rate_spread_percent' THEN NULLIF(p_payload->>'deal_rate_spread_percent', '')::NUMERIC ELSE deal_rate_spread_percent END,
    reference_rate_id = CASE WHEN p_payload ? 'reference_rate_id' THEN NULLIF(p_payload->>'reference_rate_id', '')::UUID ELSE reference_rate_id END,
    rate_locked_at = CASE WHEN p_payload ? 'rate_locked_at' THEN NULLIF(p_payload->>'rate_locked_at', '')::TIMESTAMPTZ ELSE rate_locked_at END,
    rate_locked_by = CASE WHEN p_payload ? 'rate_locked_by' THEN NULLIF(p_payload->>'rate_locked_by', '')::UUID ELSE rate_locked_by END,
    updated_at = NOW()
  WHERE id = v_leg_id;

  IF v_row.leg.leg_type = 'agent_source'::fx_deal_leg_type THEN
    UPDATE fx_currency_commitments SET
      currency_code = COALESCE(fx_normalize_currency_code(v_receive_currency), currency_code),
      committed_amount = CASE WHEN p_payload ? 'receive_amount' THEN v_receive_amount ELSE committed_amount END,
      updated_at = NOW()
    WHERE leg_id = v_leg_id;

    IF NOT FOUND AND v_receive_currency IS NOT NULL THEN
      INSERT INTO fx_currency_commitments (deal_id, leg_id, currency_code, commitment_type, committed_amount)
      VALUES (
        v_row.deal.id, v_leg_id,
        fx_normalize_currency_code(v_receive_currency),
        'on_order_inbound'::fx_commitment_type,
        v_receive_amount
      );
    END IF;
  END IF;

  PERFORM fx_recompute_deal_status(v_row.deal.id);

  RETURN v_leg_id;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_recompute_deal_status(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_delete_deal_leg_v2(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_update_deal_leg_v2(JSONB) TO authenticated;

NOTIFY pgrst, 'reload schema';
-- <<<<< END 202606210006_fx_deal_leg_edit_delete.sql

-- >>>>> BEGIN 202606210007_fx_deal_leg_edit_delete_fix.sql
-- Fix 42P01: output column "deal" conflicted with SQL table reference in v_row.deal.id

DROP FUNCTION IF EXISTS fx_delete_deal_leg_v2(UUID);
DROP FUNCTION IF EXISTS fx_update_deal_leg_v2(JSONB);
DROP FUNCTION IF EXISTS fx_assert_deal_leg_mutable(UUID);

CREATE OR REPLACE FUNCTION fx_assert_deal_leg_mutable(p_leg_id UUID)
RETURNS TABLE (leg fx_deal_legs, deal_row fx_deals)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_leg fx_deal_legs;
  v_deal fx_deals;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_leg FROM fx_deal_legs WHERE id = p_leg_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal leg not found'; END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = v_leg.deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  IF v_deal.status IN ('completed', 'cancelled', 'voided') THEN
    RAISE EXCEPTION 'Cannot modify legs on a % deal', v_deal.status;
  END IF;

  IF v_leg.status <> 'pending'::fx_deal_leg_status THEN
    RAISE EXCEPTION 'Only pending legs can be edited or deleted';
  END IF;

  IF v_leg.linked_transaction_id IS NOT NULL THEN
    RAISE EXCEPTION 'Leg is linked to a posted transaction';
  END IF;

  IF v_leg.leg_type IN (
    'customer_order'::fx_deal_leg_type,
    'customer_payment'::fx_deal_leg_type,
    'delivery'::fx_deal_leg_type
  ) THEN
    RAISE EXCEPTION 'Leg type % cannot be edited or deleted', v_leg.leg_type;
  END IF;

  RETURN QUERY SELECT v_leg, v_deal;
END;
$$;

CREATE OR REPLACE FUNCTION fx_delete_deal_leg_v2(p_leg_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check RECORD;
  v_deal fx_deals;
  v_deal_id UUID;
BEGIN
  SELECT * INTO v_check FROM fx_assert_deal_leg_mutable(p_leg_id);
  v_deal := v_check.deal_row;
  v_deal_id := v_deal.id;

  DELETE FROM fx_settlement_links
  WHERE from_leg_id = p_leg_id OR to_leg_id = p_leg_id;

  DELETE FROM fx_currency_commitments WHERE leg_id = p_leg_id;

  DELETE FROM fx_deal_legs WHERE id = p_leg_id;

  PERFORM fx_recompute_deal_status(v_deal_id);

  RETURN p_leg_id;
END;
$$;

CREATE OR REPLACE FUNCTION fx_update_deal_leg_v2(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check RECORD;
  v_leg fx_deal_legs;
  v_deal fx_deals;
  v_leg_id UUID := (p_payload->>'leg_id')::UUID;
  v_receive_currency TEXT := NULLIF(p_payload->>'receive_currency', '');
  v_receive_amount NUMERIC := COALESCE((p_payload->>'receive_amount')::NUMERIC, 0);
  v_pay_currency TEXT := NULLIF(p_payload->>'pay_currency', '');
  v_pay_amount NUMERIC := COALESCE((p_payload->>'pay_amount')::NUMERIC, 0);
  v_rate_used NUMERIC := NULLIF(p_payload->>'rate_used', '')::NUMERIC;
  v_delivery_target fx_delivery_target := NULLIF(p_payload->>'delivery_target', '')::fx_delivery_target;
  v_counterparty UUID := NULLIF(p_payload->>'counterparty_party_id', '')::UUID;
  v_notes TEXT := NULLIF(p_payload->>'notes', '');
  v_remaining NUMERIC;
BEGIN
  SELECT * INTO v_check FROM fx_assert_deal_leg_mutable(v_leg_id);
  v_leg := v_check.leg;
  v_deal := v_check.deal_row;

  v_remaining := COALESCE(NULLIF(v_pay_amount, 0), NULLIF(v_receive_amount, 0), v_leg.remaining_amount);

  UPDATE fx_deal_legs SET
    counterparty_party_id = COALESCE(v_counterparty, counterparty_party_id),
    receive_currency = CASE
      WHEN p_payload ? 'receive_currency' THEN
        CASE WHEN v_receive_currency IS NOT NULL THEN fx_normalize_currency_code(v_receive_currency) ELSE NULL END
      ELSE receive_currency
    END,
    receive_amount = CASE WHEN p_payload ? 'receive_amount' THEN v_receive_amount ELSE receive_amount END,
    pay_currency = CASE
      WHEN p_payload ? 'pay_currency' THEN
        CASE WHEN v_pay_currency IS NOT NULL THEN fx_normalize_currency_code(v_pay_currency) ELSE NULL END
      ELSE pay_currency
    END,
    pay_amount = CASE WHEN p_payload ? 'pay_amount' THEN v_pay_amount ELSE pay_amount END,
    rate_used = CASE WHEN p_payload ? 'rate_used' THEN v_rate_used ELSE rate_used END,
    remaining_amount = v_remaining,
    delivery_target = CASE WHEN p_payload ? 'delivery_target' THEN v_delivery_target ELSE delivery_target END,
    notes = CASE WHEN p_payload ? 'notes' THEN v_notes ELSE notes END,
    reference_rate = CASE WHEN p_payload ? 'reference_rate' THEN NULLIF(p_payload->>'reference_rate', '')::NUMERIC ELSE reference_rate END,
    reference_rate_pair = CASE WHEN p_payload ? 'reference_rate_pair' THEN NULLIF(p_payload->>'reference_rate_pair', '') ELSE reference_rate_pair END,
    reference_rate_source = CASE WHEN p_payload ? 'reference_rate_source' THEN NULLIF(p_payload->>'reference_rate_source', '') ELSE reference_rate_source END,
    reference_rate_at = CASE WHEN p_payload ? 'reference_rate_at' THEN NULLIF(p_payload->>'reference_rate_at', '')::TIMESTAMPTZ ELSE reference_rate_at END,
    reference_rate_is_stale = CASE WHEN p_payload ? 'reference_rate_is_stale' THEN (p_payload->>'reference_rate_is_stale')::BOOLEAN ELSE reference_rate_is_stale END,
    deal_rate_spread = CASE WHEN p_payload ? 'deal_rate_spread' THEN NULLIF(p_payload->>'deal_rate_spread', '')::NUMERIC ELSE deal_rate_spread END,
    deal_rate_spread_percent = CASE WHEN p_payload ? 'deal_rate_spread_percent' THEN NULLIF(p_payload->>'deal_rate_spread_percent', '')::NUMERIC ELSE deal_rate_spread_percent END,
    reference_rate_id = CASE WHEN p_payload ? 'reference_rate_id' THEN NULLIF(p_payload->>'reference_rate_id', '')::UUID ELSE reference_rate_id END,
    rate_locked_at = CASE WHEN p_payload ? 'rate_locked_at' THEN NULLIF(p_payload->>'rate_locked_at', '')::TIMESTAMPTZ ELSE rate_locked_at END,
    rate_locked_by = CASE WHEN p_payload ? 'rate_locked_by' THEN NULLIF(p_payload->>'rate_locked_by', '')::UUID ELSE rate_locked_by END,
    updated_at = NOW()
  WHERE id = v_leg_id;

  IF v_leg.leg_type = 'agent_source'::fx_deal_leg_type THEN
    UPDATE fx_currency_commitments SET
      currency_code = COALESCE(fx_normalize_currency_code(v_receive_currency), currency_code),
      committed_amount = CASE WHEN p_payload ? 'receive_amount' THEN v_receive_amount ELSE committed_amount END,
      updated_at = NOW()
    WHERE leg_id = v_leg_id;

    IF NOT FOUND AND v_receive_currency IS NOT NULL THEN
      INSERT INTO fx_currency_commitments (deal_id, leg_id, currency_code, commitment_type, committed_amount)
      VALUES (
        v_deal.id, v_leg_id,
        fx_normalize_currency_code(v_receive_currency),
        'on_order_inbound'::fx_commitment_type,
        v_receive_amount
      );
    END IF;
  END IF;

  PERFORM fx_recompute_deal_status(v_deal.id);

  RETURN v_leg_id;
END;
$$;

NOTIFY pgrst, 'reload schema';
-- <<<<< END 202606210007_fx_deal_leg_edit_delete_fix.sql

-- >>>>> BEGIN 202606210008_fx_deal_leg_edit_delete_fix2.sql
-- Fix PL/pgSQL composite access: v_check.deal_row.id parsed as table reference

CREATE OR REPLACE FUNCTION fx_delete_deal_leg_v2(p_leg_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check RECORD;
  v_deal fx_deals;
  v_deal_id UUID;
BEGIN
  SELECT * INTO v_check FROM fx_assert_deal_leg_mutable(p_leg_id);
  v_deal := v_check.deal_row;
  v_deal_id := v_deal.id;

  DELETE FROM fx_settlement_links
  WHERE from_leg_id = p_leg_id OR to_leg_id = p_leg_id;

  DELETE FROM fx_currency_commitments WHERE leg_id = p_leg_id;

  DELETE FROM fx_deal_legs WHERE id = p_leg_id;

  PERFORM fx_recompute_deal_status(v_deal_id);

  RETURN p_leg_id;
END;
$$;

CREATE OR REPLACE FUNCTION fx_update_deal_leg_v2(p_payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check RECORD;
  v_leg fx_deal_legs;
  v_deal fx_deals;
  v_leg_id UUID := (p_payload->>'leg_id')::UUID;
  v_receive_currency TEXT := NULLIF(p_payload->>'receive_currency', '');
  v_receive_amount NUMERIC := COALESCE((p_payload->>'receive_amount')::NUMERIC, 0);
  v_pay_currency TEXT := NULLIF(p_payload->>'pay_currency', '');
  v_pay_amount NUMERIC := COALESCE((p_payload->>'pay_amount')::NUMERIC, 0);
  v_rate_used NUMERIC := NULLIF(p_payload->>'rate_used', '')::NUMERIC;
  v_delivery_target fx_delivery_target := NULLIF(p_payload->>'delivery_target', '')::fx_delivery_target;
  v_counterparty UUID := NULLIF(p_payload->>'counterparty_party_id', '')::UUID;
  v_notes TEXT := NULLIF(p_payload->>'notes', '');
  v_remaining NUMERIC;
BEGIN
  SELECT * INTO v_check FROM fx_assert_deal_leg_mutable(v_leg_id);
  v_leg := v_check.leg;
  v_deal := v_check.deal_row;

  v_remaining := COALESCE(NULLIF(v_pay_amount, 0), NULLIF(v_receive_amount, 0), v_leg.remaining_amount);

  UPDATE fx_deal_legs SET
    counterparty_party_id = COALESCE(v_counterparty, counterparty_party_id),
    receive_currency = CASE
      WHEN p_payload ? 'receive_currency' THEN
        CASE WHEN v_receive_currency IS NOT NULL THEN fx_normalize_currency_code(v_receive_currency) ELSE NULL END
      ELSE receive_currency
    END,
    receive_amount = CASE WHEN p_payload ? 'receive_amount' THEN v_receive_amount ELSE receive_amount END,
    pay_currency = CASE
      WHEN p_payload ? 'pay_currency' THEN
        CASE WHEN v_pay_currency IS NOT NULL THEN fx_normalize_currency_code(v_pay_currency) ELSE NULL END
      ELSE pay_currency
    END,
    pay_amount = CASE WHEN p_payload ? 'pay_amount' THEN v_pay_amount ELSE pay_amount END,
    rate_used = CASE WHEN p_payload ? 'rate_used' THEN v_rate_used ELSE rate_used END,
    remaining_amount = v_remaining,
    delivery_target = CASE WHEN p_payload ? 'delivery_target' THEN v_delivery_target ELSE delivery_target END,
    notes = CASE WHEN p_payload ? 'notes' THEN v_notes ELSE notes END,
    reference_rate = CASE WHEN p_payload ? 'reference_rate' THEN NULLIF(p_payload->>'reference_rate', '')::NUMERIC ELSE reference_rate END,
    reference_rate_pair = CASE WHEN p_payload ? 'reference_rate_pair' THEN NULLIF(p_payload->>'reference_rate_pair', '') ELSE reference_rate_pair END,
    reference_rate_source = CASE WHEN p_payload ? 'reference_rate_source' THEN NULLIF(p_payload->>'reference_rate_source', '') ELSE reference_rate_source END,
    reference_rate_at = CASE WHEN p_payload ? 'reference_rate_at' THEN NULLIF(p_payload->>'reference_rate_at', '')::TIMESTAMPTZ ELSE reference_rate_at END,
    reference_rate_is_stale = CASE WHEN p_payload ? 'reference_rate_is_stale' THEN (p_payload->>'reference_rate_is_stale')::BOOLEAN ELSE reference_rate_is_stale END,
    deal_rate_spread = CASE WHEN p_payload ? 'deal_rate_spread' THEN NULLIF(p_payload->>'deal_rate_spread', '')::NUMERIC ELSE deal_rate_spread END,
    deal_rate_spread_percent = CASE WHEN p_payload ? 'deal_rate_spread_percent' THEN NULLIF(p_payload->>'deal_rate_spread_percent', '')::NUMERIC ELSE deal_rate_spread_percent END,
    reference_rate_id = CASE WHEN p_payload ? 'reference_rate_id' THEN NULLIF(p_payload->>'reference_rate_id', '')::UUID ELSE reference_rate_id END,
    rate_locked_at = CASE WHEN p_payload ? 'rate_locked_at' THEN NULLIF(p_payload->>'rate_locked_at', '')::TIMESTAMPTZ ELSE rate_locked_at END,
    rate_locked_by = CASE WHEN p_payload ? 'rate_locked_by' THEN NULLIF(p_payload->>'rate_locked_by', '')::UUID ELSE rate_locked_by END,
    updated_at = NOW()
  WHERE id = v_leg_id;

  IF v_leg.leg_type = 'agent_source'::fx_deal_leg_type THEN
    UPDATE fx_currency_commitments SET
      currency_code = COALESCE(fx_normalize_currency_code(v_receive_currency), currency_code),
      committed_amount = CASE WHEN p_payload ? 'receive_amount' THEN v_receive_amount ELSE committed_amount END,
      updated_at = NOW()
    WHERE leg_id = v_leg_id;

    IF NOT FOUND AND v_receive_currency IS NOT NULL THEN
      INSERT INTO fx_currency_commitments (deal_id, leg_id, currency_code, commitment_type, committed_amount)
      VALUES (
        v_deal.id, v_leg_id,
        fx_normalize_currency_code(v_receive_currency),
        'on_order_inbound'::fx_commitment_type,
        v_receive_amount
      );
    END IF;
  END IF;

  PERFORM fx_recompute_deal_status(v_deal.id);

  RETURN v_leg_id;
END;
$$;

NOTIFY pgrst, 'reload schema';
-- <<<<< END 202606210008_fx_deal_leg_edit_delete_fix2.sql

-- >>>>> BEGIN 202606220001_fx_deal_customer_payment_posting_fix.sql
-- Fix deal customer payment posting: use settlement_receive instead of manual_journal
-- Project: ygidlcqhupmxvsdjmvnf only
--
-- manual_journal is not in fx_post_transaction allowlist; customer deal payments
-- must post via settlement_receive (Dr PKR Cash / Cr Customer Advances).

CREATE OR REPLACE FUNCTION fx_record_deal_customer_payment(
  p_deal_id UUID,
  p_amount_pkr NUMERIC,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
  v_tx_id UUID;
  v_leg_no INT;
  v_leg_id UUID;
  v_pkr_cash UUID;
  v_advances UUID;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;
  IF p_amount_pkr <= 0 THEN RAISE EXCEPTION 'Payment amount must be positive'; END IF;

  v_pkr_cash := fx_account_id_by_code(v_deal.company_id, '1110');
  v_advances := fx_account_id_by_code(v_deal.company_id, '1160');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, deal_id, created_by
  ) VALUES (
    v_deal.company_id, v_deal.branch_id, 'settlement_receive', 'draft', CURRENT_DATE,
    v_deal.customer_party_id, 'PKR', p_amount_pkr, 1, p_amount_pkr,
    COALESCE(p_notes, 'Customer payment — deal ' || v_deal.deal_no),
    p_deal_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_pkr_cash, 'PKR', p_amount_pkr, 1, p_amount_pkr, 0, 'Customer payment received'),
    (v_tx_id, 2, v_advances, 'PKR', p_amount_pkr, 1, 0, p_amount_pkr, 'Customer advance');

  PERFORM fx_post_transaction(v_tx_id);

  SELECT COALESCE(MAX(leg_no), 0) + 1 INTO v_leg_no FROM fx_deal_legs WHERE deal_id = p_deal_id;

  INSERT INTO fx_deal_legs (
    deal_id, leg_no, leg_type, status, counterparty_party_id,
    pay_currency, pay_amount, paid_amount, remaining_amount,
    linked_transaction_id, notes
  ) VALUES (
    p_deal_id, v_leg_no, 'customer_payment'::fx_deal_leg_type, 'completed'::fx_deal_leg_status, v_deal.customer_party_id,
    'PKR', p_amount_pkr, p_amount_pkr, 0,
    v_tx_id, p_notes
  ) RETURNING id INTO v_leg_id;

  UPDATE fx_transactions SET leg_id = v_leg_id WHERE id = v_tx_id;

  UPDATE fx_deals SET
    customer_paid_pkr = customer_paid_pkr + p_amount_pkr,
    customer_receivable_pkr = GREATEST(0, customer_payable_pkr - customer_paid_pkr - p_amount_pkr),
    status = (CASE
      WHEN customer_paid_pkr + p_amount_pkr >= customer_payable_pkr THEN 'customer_paid'
      WHEN customer_paid_pkr + p_amount_pkr > 0 THEN 'customer_partially_paid'
      ELSE status::text
    END)::fx_deal_status,
    updated_at = NOW()
  WHERE id = p_deal_id;

  RETURN v_tx_id;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_record_deal_customer_payment(UUID, NUMERIC, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
-- <<<<< END 202606220001_fx_deal_customer_payment_posting_fix.sql

-- >>>>> BEGIN 202606230001_fx_remittance_module.sql
-- PROPOSAL ONLY — do not apply without explicit approval.
-- Cloud project: ygidlcqhupmxvsdjmvnf (NOT supabase.dincouture.pk, NOT old ERP VPS)
-- FX Remittance / Hawala module — tables, enums, COA, RLS, basic RPCs

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  DO $$ BEGIN
CREATE TYPE fx_remittance_status AS ENUM (
    'draft', 'booked', 'customer_paid', 'sent_to_agent', 'ready_for_payout',
    'paid_out', 'cancelled', 'refunded', 'disputed', 'completed'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  DO $$ BEGIN
CREATE TYPE fx_remittance_settlement_status AS ENUM (
    'pending', 'partial', 'settled'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  DO $$ BEGIN
CREATE TYPE fx_remittance_event_type AS ENUM (
    'created', 'customer_payment', 'sent_to_agent', 'payout_confirmed',
    'agent_settlement', 'refund', 'note', 'status_change'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  DO $$ BEGIN
CREATE TYPE fx_remittance_tx_purpose AS ENUM (
    'customer_payment', 'agent_payout', 'agent_settlement', 'refund', 'commission'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;
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
-- <<<<< END 202606230001_fx_remittance_module.sql

-- >>>>> BEGIN 202606230002_fx_remittance_posting.sql
-- PROPOSAL ONLY — do not apply without explicit approval.
-- FX Remittance posting RPCs — balanced journals via fx_post_transaction

-- Helper: cash account for currency
CREATE OR REPLACE FUNCTION fx_cash_account_for_currency(p_company_id UUID, p_currency TEXT)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT a.id FROM fx_accounts a
  JOIN fx_currencies c ON c.id = a.currency_id
  WHERE a.company_id = p_company_id
    AND a.is_active
    AND a.account_type = 'asset'
    AND c.code = upper(p_currency)
    AND a.code LIKE '11%'
  ORDER BY a.code
  LIMIT 1;
$$;

-- ---------------------------------------------------------------------------
-- fx_record_remittance_customer_payment
-- Dr Cash, Cr Remittance Liability (+ Cr Commission Income)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_record_remittance_customer_payment(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_cash UUID;
  v_liability UUID;
  v_commission UUID;
  v_pay NUMERIC(20, 8);
  v_comm NUMERIC(20, 8);
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status NOT IN ('booked', 'customer_paid') THEN
    RAISE EXCEPTION 'Invalid status for customer payment: %', v_r.status;
  END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  v_cash := CASE
    WHEN p_cash_account_code IS NOT NULL THEN fx_account_id_by_code(v_r.company_id, p_cash_account_code)
    ELSE COALESCE(fx_cash_account_for_currency(v_r.company_id, v_r.receive_currency), fx_account_id_by_code(v_r.company_id, '1110'))
  END;
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_commission := fx_account_id_by_code(v_r.company_id, '4310');

  v_comm := LEAST(p_amount, v_r.commission_amount);
  v_pay := p_amount - v_comm;

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, remittance_id, created_by
  ) VALUES (
    v_r.company_id, v_r.branch_id, 'manual_journal', 'draft', CURRENT_DATE,
    v_r.sender_party_id, v_r.receive_currency, p_amount, 1, p_amount,
    COALESCE(p_notes, 'Remittance customer payment ' || v_r.tracking_id),
    p_remittance_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, 1, v_cash, v_r.receive_currency, p_amount, 1, p_amount, 0, 'Customer payment received');

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, 2, v_liability, v_r.receive_currency, v_pay, 1, 0, v_pay, 'Remittance liability');

  IF v_comm > 0 THEN
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, 3, v_commission, v_r.receive_currency, v_comm, 1, 0, v_comm, 'Commission income');
  END IF;

  PERFORM fx_post_transaction(v_tx_id);

  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose)
  VALUES (p_remittance_id, v_tx_id, 'customer_payment');

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, amount, currency_code,
    linked_transaction_id, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'customer_payment', 'customer_paid', p_amount, v_r.receive_currency,
    v_tx_id, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET
    paid_amount = paid_amount + p_amount,
    status = CASE
      WHEN paid_amount + p_amount >= total_payable THEN 'customer_paid'::fx_remittance_status
      ELSE 'customer_paid'::fx_remittance_status
    END,
    updated_at = NOW()
  WHERE id = p_remittance_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_send_remittance_to_agent (status + assign agent)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_send_remittance_to_agent(
  p_remittance_id UUID,
  p_agent_party_id UUID,
  p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_event_no INT;
BEGIN
  IF NOT fx_has_permission('can_manage_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status <> 'customer_paid' THEN RAISE EXCEPTION 'Customer must pay before sending to agent'; END IF;

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  UPDATE fx_remittances SET
    payout_agent_party_id = p_agent_party_id,
    status = 'sent_to_agent',
    updated_at = NOW()
  WHERE id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'sent_to_agent', 'sent_to_agent', p_notes, auth.uid()
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_confirm_remittance_payout
-- Dr Remittance Liability, Cr Agent Payable
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_confirm_remittance_payout(
  p_remittance_id UUID,
  p_proof_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_liability UUID;
  v_agent_pay UUID;
  v_amount NUMERIC(20, 8);
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF v_r.payout_agent_party_id IS NULL THEN RAISE EXCEPTION 'Payout agent required'; END IF;
  IF v_r.status NOT IN ('sent_to_agent', 'ready_for_payout') THEN
    RAISE EXCEPTION 'Invalid status for payout: %', v_r.status;
  END IF;

  v_amount := v_r.receive_amount;
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, remittance_id, created_by
  ) VALUES (
    v_r.company_id, v_r.branch_id, 'manual_journal', 'draft', CURRENT_DATE,
    v_r.payout_agent_party_id, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate,
    v_amount, COALESCE(p_notes, 'Remittance payout ' || v_r.tracking_id),
    p_remittance_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_liability, v_r.receive_currency, v_amount, 1, v_amount, 0, 'Clear remittance liability'),
    (v_tx_id, 2, v_agent_pay, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, 0, v_amount, 'Agent payable');

  PERFORM fx_post_transaction(v_tx_id);

  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose)
  VALUES (p_remittance_id, v_tx_id, 'agent_payout');

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, amount, currency_code,
    linked_transaction_id, proof_reference, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'payout_confirmed', 'paid_out', v_r.payout_amount, v_r.payout_currency,
    v_tx_id, p_proof_reference, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET
    status = 'paid_out',
    payout_status = 'paid',
    updated_at = NOW()
  WHERE id = p_remittance_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_settle_remittance_agent — Dr Agent Payable, Cr Cash
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_settle_remittance_agent(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT '1110',
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_cash UUID;
  v_agent_pay UUID;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  v_cash := fx_account_id_by_code(v_r.company_id, p_cash_account_code);
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, remittance_id, created_by
  ) VALUES (
    v_r.company_id, v_r.branch_id, 'manual_journal', 'draft', CURRENT_DATE,
    v_r.payout_agent_party_id, 'PKR', p_amount, 1, p_amount,
    COALESCE(p_notes, 'Agent settlement ' || v_r.tracking_id),
    p_remittance_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_agent_pay, 'PKR', p_amount, 1, p_amount, 0, 'Settle agent payable'),
    (v_tx_id, 2, v_cash, 'PKR', p_amount, 1, 0, p_amount, 'Cash paid to agent');

  PERFORM fx_post_transaction(v_tx_id);

  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose)
  VALUES (p_remittance_id, v_tx_id, 'agent_settlement');

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, amount, currency_code,
    linked_transaction_id, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'agent_settlement', 'completed', p_amount, 'PKR',
    v_tx_id, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET
    settlement_status = 'settled',
    status = 'completed',
    completed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_remittance_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_refund_remittance / fx_cancel_remittance
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_refund_remittance(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT '1110',
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_cash UUID;
  v_liability UUID;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  v_cash := fx_account_id_by_code(v_r.company_id, p_cash_account_code);
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, remittance_id, created_by
  ) VALUES (
    v_r.company_id, v_r.branch_id, 'manual_journal', 'draft', CURRENT_DATE,
    v_r.sender_party_id, v_r.receive_currency, p_amount, 1, p_amount,
    COALESCE(p_notes, 'Remittance refund ' || v_r.tracking_id),
    p_remittance_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_liability, v_r.receive_currency, p_amount, 1, p_amount, 0, 'Reverse liability'),
    (v_tx_id, 2, v_cash, v_r.receive_currency, p_amount, 1, 0, p_amount, 'Refund cash');

  PERFORM fx_post_transaction(v_tx_id);

  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose)
  VALUES (p_remittance_id, v_tx_id, 'refund');

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, amount, currency_code,
    linked_transaction_id, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'refund', 'refunded', p_amount, v_r.receive_currency,
    v_tx_id, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET status = 'refunded', updated_at = NOW() WHERE id = p_remittance_id;
  RETURN v_tx_id;
END;
$$;

CREATE OR REPLACE FUNCTION fx_cancel_remittance(
  p_remittance_id UUID,
  p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_event_no INT;
BEGIN
  IF NOT fx_has_permission('can_manage_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF v_r.status NOT IN ('draft', 'booked') THEN
    RAISE EXCEPTION 'Can only cancel draft or booked remittances';
  END IF;

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  UPDATE fx_remittances SET status = 'cancelled', cancelled_at = NOW(), updated_at = NOW()
  WHERE id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'status_change', 'cancelled', p_notes, auth.uid()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION fx_cash_account_for_currency(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_record_remittance_customer_payment(UUID, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_send_remittance_to_agent(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_confirm_remittance_payout(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_settle_remittance_agent(UUID, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_refund_remittance(UUID, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_cancel_remittance(UUID, TEXT) TO authenticated;
-- <<<<< END 202606230002_fx_remittance_posting.sql

-- >>>>> BEGIN 202606230003_fx_messaging_module.sql
-- PROPOSAL ONLY — do not apply without explicit approval.
-- FX Internal messaging module

DO $$ BEGIN
  DO $$ BEGIN
CREATE TYPE fx_conversation_type AS ENUM (
    'direct', 'deal', 'party', 'transaction', 'company'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  DO $$ BEGIN
CREATE TYPE fx_message_type AS ENUM (
    'text', 'image', 'file', 'link', 'voice',
    'deal_ref', 'transaction_ref', 'party_ref', 'system'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS fx_conversations (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id              UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id               UUID NOT NULL REFERENCES fx_branches (id) ON DELETE RESTRICT,
  conversation_type       fx_conversation_type NOT NULL,
  title                   TEXT,
  context_deal_id         UUID REFERENCES fx_deals (id) ON DELETE SET NULL,
  context_party_id        UUID REFERENCES fx_parties (id) ON DELETE SET NULL,
  context_transaction_id  UUID REFERENCES fx_transactions (id) ON DELETE SET NULL,
  last_message_at         TIMESTAMPTZ,
  created_by              UUID REFERENCES auth.users (id),
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fx_conversations_branch ON fx_conversations (branch_id, last_message_at DESC);

CREATE TABLE IF NOT EXISTS fx_conversation_members (
  conversation_id         UUID NOT NULL REFERENCES fx_conversations (id) ON DELETE CASCADE,
  user_id                 UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  role                    TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'admin')),
  last_read_at            TIMESTAMPTZ,
  unread_count            INT NOT NULL DEFAULT 0,
  joined_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS fx_messages (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id         UUID NOT NULL REFERENCES fx_conversations (id) ON DELETE CASCADE,
  sender_id               UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  message_type            fx_message_type NOT NULL DEFAULT 'text',
  body                    TEXT NOT NULL DEFAULT '',
  metadata                JSONB NOT NULL DEFAULT '{}',
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  edited_at               TIMESTAMPTZ,
  deleted_at              TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_fx_messages_conversation ON fx_messages (conversation_id, created_at);

-- RLS
ALTER TABLE fx_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fx_conversations_select ON fx_conversations;
CREATE POLICY fx_conversations_select ON fx_conversations
  FOR SELECT TO authenticated
  USING (
    fx_same_branch(branch_id)
    AND (
      fx_has_permission('can_manage_messaging')
      OR EXISTS (
        SELECT 1 FROM fx_conversation_members m
        WHERE m.conversation_id = id AND m.user_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS fx_conversation_members_select ON fx_conversation_members;
CREATE POLICY fx_conversation_members_select ON fx_conversation_members
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM fx_conversations c
      WHERE c.id = conversation_id AND fx_same_branch(c.branch_id)
        AND fx_has_permission('can_manage_messaging')
    )
  );

DROP POLICY IF EXISTS fx_messages_select ON fx_messages;
CREATE POLICY fx_messages_select ON fx_messages
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM fx_conversation_members m
    JOIN fx_conversations c ON c.id = m.conversation_id
    WHERE m.conversation_id = fx_messages.conversation_id
      AND m.user_id = auth.uid()
      AND fx_same_branch(c.branch_id)
  ));

DROP POLICY IF EXISTS fx_messages_insert ON fx_messages;
CREATE POLICY fx_messages_insert ON fx_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM fx_conversation_members m
      JOIN fx_conversations c ON c.id = m.conversation_id
      WHERE m.conversation_id = fx_messages.conversation_id
        AND m.user_id = auth.uid()
        AND fx_same_branch(c.branch_id)
    )
  );

UPDATE fx_roles SET permissions = array_append(permissions, 'can_manage_messaging')
WHERE name = 'admin' AND NOT ('can_manage_messaging' = ANY (permissions));

-- RPCs
CREATE OR REPLACE FUNCTION fx_list_conversations(p_branch_id UUID)
RETURNS TABLE (
  conversation_id UUID,
  conversation_type fx_conversation_type,
  title TEXT,
  last_message_at TIMESTAMPTZ,
  unread_count INT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.id, c.conversation_type, c.title, c.last_message_at, COALESCE(m.unread_count, 0)
  FROM fx_conversations c
  JOIN fx_conversation_members m ON m.conversation_id = c.id AND m.user_id = auth.uid()
  WHERE c.branch_id = p_branch_id AND fx_same_branch(p_branch_id)
  ORDER BY c.last_message_at DESC NULLS LAST;
$$;

CREATE OR REPLACE FUNCTION fx_get_or_create_entity_conversation(
  p_branch_id UUID,
  p_type fx_conversation_type,
  p_context_deal_id UUID DEFAULT NULL,
  p_context_party_id UUID DEFAULT NULL,
  p_context_transaction_id UUID DEFAULT NULL,
  p_title TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_id UUID;
BEGIN
  SELECT * INTO v_profile FROM fx_current_profile();
  IF v_profile.branch_id <> p_branch_id THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;

  SELECT c.id INTO v_id FROM fx_conversations c
  WHERE c.branch_id = p_branch_id
    AND c.conversation_type = p_type
    AND (p_context_deal_id IS NULL OR c.context_deal_id = p_context_deal_id)
    AND (p_context_party_id IS NULL OR c.context_party_id = p_context_party_id)
    AND (p_context_transaction_id IS NULL OR c.context_transaction_id = p_context_transaction_id)
  LIMIT 1;

  IF v_id IS NOT NULL THEN RETURN v_id; END IF;

  INSERT INTO fx_conversations (
    company_id, branch_id, conversation_type, title,
    context_deal_id, context_party_id, context_transaction_id, created_by
  ) VALUES (
    v_profile.company_id, p_branch_id, p_type, p_title,
    p_context_deal_id, p_context_party_id, p_context_transaction_id, auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO fx_conversation_members (conversation_id, user_id, role)
  VALUES (v_id, auth.uid(), 'admin')
  ON CONFLICT DO NOTHING;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION fx_send_message(
  p_conversation_id UUID,
  p_body TEXT,
  p_message_type fx_message_type DEFAULT 'text',
  p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM fx_conversation_members m
    JOIN fx_conversations c ON c.id = m.conversation_id
    WHERE m.conversation_id = p_conversation_id AND m.user_id = auth.uid()
      AND fx_same_branch(c.branch_id)
  ) THEN
    RAISE EXCEPTION 'Not a conversation member';
  END IF;

  INSERT INTO fx_messages (conversation_id, sender_id, message_type, body, metadata)
  VALUES (p_conversation_id, auth.uid(), p_message_type, p_body, p_metadata)
  RETURNING id INTO v_id;

  UPDATE fx_conversations SET last_message_at = NOW(), updated_at = NOW()
  WHERE id = p_conversation_id;

  UPDATE fx_conversation_members SET unread_count = unread_count + 1
  WHERE conversation_id = p_conversation_id AND user_id <> auth.uid();

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION fx_mark_conversation_read(p_conversation_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE fx_conversation_members SET unread_count = 0, last_read_at = NOW()
  WHERE conversation_id = p_conversation_id AND user_id = auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION fx_list_messages(p_conversation_id UUID, p_limit INT DEFAULT 100)
RETURNS SETOF fx_messages
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT m.*
  FROM fx_messages m
  JOIN fx_conversation_members cm ON cm.conversation_id = m.conversation_id AND cm.user_id = auth.uid()
  WHERE m.conversation_id = p_conversation_id AND m.deleted_at IS NULL
  ORDER BY m.created_at ASC
  LIMIT p_limit;
$$;

-- Realtime (requires replication enabled in dashboard for fx_messages)
ALTER PUBLICATION supabase_realtime ADD TABLE fx_messages;

GRANT EXECUTE ON FUNCTION fx_list_conversations(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_or_create_entity_conversation(UUID, fx_conversation_type, UUID, UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_send_message(UUID, TEXT, fx_message_type, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_mark_conversation_read(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_list_messages(UUID, INT) TO authenticated;
-- <<<<< END 202606230003_fx_messaging_module.sql

-- >>>>> BEGIN 202606230004_fx_attachments_remittance_message.sql
-- PROPOSAL ONLY — extend fx_attachments for remittance + messaging

ALTER TABLE fx_attachments
  ADD COLUMN IF NOT EXISTS remittance_id UUID REFERENCES fx_remittances (id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS remittance_event_id UUID REFERENCES fx_remittance_events (id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS message_id UUID REFERENCES fx_messages (id) ON DELETE CASCADE;

ALTER TABLE fx_attachments DROP CONSTRAINT IF EXISTS fx_attachments_target_check;
ALTER TABLE fx_attachments ADD CONSTRAINT fx_attachments_target_check CHECK (
  transaction_id IS NOT NULL
  OR deal_id IS NOT NULL
  OR remittance_id IS NOT NULL
  OR message_id IS NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_fx_attachments_remittance ON fx_attachments (remittance_id);
CREATE INDEX IF NOT EXISTS idx_fx_attachments_message ON fx_attachments (message_id);

-- Extend select policy (mirror deal pattern)
DROP POLICY IF EXISTS fx_attachments_select ON fx_attachments;
CREATE POLICY fx_attachments_select ON fx_attachments
  FOR SELECT TO authenticated
  USING (
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
  );

DROP POLICY IF EXISTS fx_attachments_insert ON fx_attachments;
CREATE POLICY fx_attachments_insert ON fx_attachments
  FOR INSERT TO authenticated
  WITH CHECK (
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
  );
-- <<<<< END 202606230004_fx_attachments_remittance_message.sql

-- >>>>> BEGIN 202606240001_fx_secure_share_links.sql
-- Secure share links for statements, deals, attachments (Stitch share_secure_link_configuration)
-- Prerequisite: fx_users_profiles (from fx_foundation). fx_same_branch is created below if missing.
-- branch_id FK to fx_branches is added below only when that table already exists.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS fx_secure_share_links (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id       UUID NOT NULL,
  entity_type     TEXT NOT NULL CHECK (entity_type IN (
    'party_ledger', 'deal', 'transaction', 'attachment', 'report'
  )),
  entity_id       UUID NOT NULL,
  token           TEXT NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(24), 'hex'),
  expires_at      TIMESTAMPTZ NOT NULL,
  allow_download  BOOLEAN NOT NULL DEFAULT true,
  password_hash   TEXT,
  created_by      UUID REFERENCES auth.users (id),
  revoked_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fx_secure_share_links_branch
  ON fx_secure_share_links (branch_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_fx_secure_share_links_token
  ON fx_secure_share_links (token) WHERE revoked_at IS NULL;

DO $$
BEGIN
  IF to_regclass('public.fx_branches') IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM pg_constraint
       WHERE conname = 'fx_secure_share_links_branch_id_fkey'
     ) THEN
    ALTER TABLE fx_secure_share_links
      ADD CONSTRAINT fx_secure_share_links_branch_id_fkey
      FOREIGN KEY (branch_id) REFERENCES fx_branches (id) ON DELETE CASCADE;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS fx_secure_share_access_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  link_id     UUID NOT NULL REFERENCES fx_secure_share_links (id) ON DELETE CASCADE,
  accessed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  user_agent  TEXT
);

-- RLS helper (idempotent — same as 202606100004_fx_rls_policies.sql)
CREATE OR REPLACE FUNCTION fx_same_branch(p_branch_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM fx_users_profiles p
    WHERE p.id = auth.uid() AND p.branch_id = p_branch_id
  );
$$;

ALTER TABLE fx_secure_share_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_secure_share_access_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fx_secure_share_links_select ON fx_secure_share_links;
CREATE POLICY fx_secure_share_links_select ON fx_secure_share_links
  FOR SELECT USING (fx_same_branch(branch_id));

DROP POLICY IF EXISTS fx_secure_share_links_insert ON fx_secure_share_links;
CREATE POLICY fx_secure_share_links_insert ON fx_secure_share_links
  FOR INSERT WITH CHECK (fx_same_branch(branch_id));

DROP POLICY IF EXISTS fx_secure_share_links_update ON fx_secure_share_links;
CREATE POLICY fx_secure_share_links_update ON fx_secure_share_links
  FOR UPDATE USING (fx_same_branch(branch_id));

DROP POLICY IF EXISTS fx_secure_share_access_log_select ON fx_secure_share_access_log;
CREATE POLICY fx_secure_share_access_log_select ON fx_secure_share_access_log
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM fx_secure_share_links l
      WHERE l.id = link_id AND fx_same_branch(l.branch_id)
    )
  );

CREATE OR REPLACE FUNCTION fx_create_secure_share_link(
  p_entity_type TEXT,
  p_entity_id UUID,
  p_expires_at TIMESTAMPTZ,
  p_allow_download BOOLEAN DEFAULT true,
  p_password TEXT DEFAULT NULL
)
RETURNS TABLE (
  link_id UUID,
  token TEXT,
  share_url TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_branch_id UUID;
  v_token TEXT;
  v_link_id UUID;
  v_hash TEXT;
BEGIN
  SELECT branch_id INTO v_branch_id
  FROM fx_users_profiles
  WHERE id = auth.uid()
  LIMIT 1;

  IF v_branch_id IS NULL THEN
    RAISE EXCEPTION 'No branch context for user';
  END IF;

  v_token := encode(gen_random_bytes(24), 'hex');
  v_hash := CASE
    WHEN p_password IS NOT NULL AND length(trim(p_password)) > 0
    THEN crypt(p_password, gen_salt('bf'))
    ELSE NULL
  END;

  INSERT INTO fx_secure_share_links (
    branch_id, entity_type, entity_id, token,
    expires_at, allow_download, password_hash, created_by
  )
  VALUES (
    v_branch_id, p_entity_type, p_entity_id, v_token,
    p_expires_at, p_allow_download, v_hash, auth.uid()
  )
  RETURNING id, fx_secure_share_links.token INTO v_link_id, v_token;

  RETURN QUERY SELECT v_link_id, v_token, '/share/' || v_token;
END;
$$;

CREATE OR REPLACE FUNCTION fx_revoke_secure_share_link(p_link_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE fx_secure_share_links
  SET revoked_at = now()
  WHERE id = p_link_id
    AND branch_id IN (
      SELECT branch_id FROM fx_users_profiles WHERE id = auth.uid()
    );
END;
$$;

CREATE OR REPLACE FUNCTION fx_validate_share_token(
  p_token TEXT,
  p_password TEXT DEFAULT NULL
)
RETURNS TABLE (
  entity_type TEXT,
  entity_id UUID,
  allow_download BOOLEAN,
  branch_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row fx_secure_share_links%ROWTYPE;
BEGIN
  SELECT * INTO v_row
  FROM fx_secure_share_links
  WHERE token = p_token
    AND revoked_at IS NULL
    AND expires_at > now();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid or expired link';
  END IF;

  IF v_row.password_hash IS NOT NULL THEN
    IF p_password IS NULL OR crypt(p_password, v_row.password_hash) != v_row.password_hash THEN
      RAISE EXCEPTION 'Password required or incorrect';
    END IF;
  END IF;

  INSERT INTO fx_secure_share_access_log (link_id) VALUES (v_row.id);

  RETURN QUERY SELECT
    v_row.entity_type,
    v_row.entity_id,
    v_row.allow_download,
    v_row.branch_id;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_create_secure_share_link(
  TEXT, UUID, TIMESTAMPTZ, BOOLEAN, TEXT
) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_revoke_secure_share_link(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_validate_share_token(TEXT, TEXT) TO anon, authenticated;
-- <<<<< END 202606240001_fx_secure_share_links.sql

-- >>>>> BEGIN 202606240002_fx_remittance_posting_type_fix.sql
-- Fix remittance posting: use settlement_receive / settlement_send instead of manual_journal
-- Project: ygidlcqhupmxvsdjmvnf only
--
-- manual_journal is not in fx_post_transaction allowlist (see 202606220001 deal payment fix).
-- Journal lines unchanged; fx_build_journal_from_transaction copies draft lines for allowed types.

-- ---------------------------------------------------------------------------
-- fx_record_remittance_customer_payment — settlement_receive
-- Dr Cash, Cr Remittance Liability (+ Cr Commission Income)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_record_remittance_customer_payment(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_cash UUID;
  v_liability UUID;
  v_commission UUID;
  v_pay NUMERIC(20, 8);
  v_comm NUMERIC(20, 8);
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status NOT IN ('booked', 'customer_paid') THEN
    RAISE EXCEPTION 'Invalid status for customer payment: %', v_r.status;
  END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  v_cash := CASE
    WHEN p_cash_account_code IS NOT NULL THEN fx_account_id_by_code(v_r.company_id, p_cash_account_code)
    ELSE COALESCE(fx_cash_account_for_currency(v_r.company_id, v_r.receive_currency), fx_account_id_by_code(v_r.company_id, '1110'))
  END;
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_commission := fx_account_id_by_code(v_r.company_id, '4310');

  v_comm := LEAST(p_amount, v_r.commission_amount);
  v_pay := p_amount - v_comm;

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, remittance_id, created_by
  ) VALUES (
    v_r.company_id, v_r.branch_id, 'settlement_receive', 'draft', CURRENT_DATE,
    v_r.sender_party_id, v_r.receive_currency, p_amount, 1, p_amount,
    COALESCE(p_notes, 'Remittance customer payment ' || v_r.tracking_id),
    p_remittance_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, 1, v_cash, v_r.receive_currency, p_amount, 1, p_amount, 0, 'Customer payment received');

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, 2, v_liability, v_r.receive_currency, v_pay, 1, 0, v_pay, 'Remittance liability');

  IF v_comm > 0 THEN
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, 3, v_commission, v_r.receive_currency, v_comm, 1, 0, v_comm, 'Commission income');
  END IF;

  PERFORM fx_post_transaction(v_tx_id);

  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose)
  VALUES (p_remittance_id, v_tx_id, 'customer_payment');

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, amount, currency_code,
    linked_transaction_id, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'customer_payment', 'customer_paid', p_amount, v_r.receive_currency,
    v_tx_id, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET
    paid_amount = paid_amount + p_amount,
    status = CASE
      WHEN paid_amount + p_amount >= total_payable THEN 'customer_paid'::fx_remittance_status
      ELSE 'customer_paid'::fx_remittance_status
    END,
    updated_at = NOW()
  WHERE id = p_remittance_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_confirm_remittance_payout — settlement_send
-- Dr Remittance Liability, Cr Agent Payable
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_confirm_remittance_payout(
  p_remittance_id UUID,
  p_proof_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_liability UUID;
  v_agent_pay UUID;
  v_amount NUMERIC(20, 8);
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF v_r.payout_agent_party_id IS NULL THEN RAISE EXCEPTION 'Payout agent required'; END IF;
  IF v_r.status NOT IN ('sent_to_agent', 'ready_for_payout') THEN
    RAISE EXCEPTION 'Invalid status for payout: %', v_r.status;
  END IF;

  v_amount := v_r.receive_amount;
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, remittance_id, created_by
  ) VALUES (
    v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', CURRENT_DATE,
    v_r.payout_agent_party_id, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate,
    v_amount, COALESCE(p_notes, 'Remittance payout ' || v_r.tracking_id),
    p_remittance_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_liability, v_r.receive_currency, v_amount, 1, v_amount, 0, 'Clear remittance liability'),
    (v_tx_id, 2, v_agent_pay, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, 0, v_amount, 'Agent payable');

  PERFORM fx_post_transaction(v_tx_id);

  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose)
  VALUES (p_remittance_id, v_tx_id, 'agent_payout');

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, amount, currency_code,
    linked_transaction_id, proof_reference, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'payout_confirmed', 'paid_out', v_r.payout_amount, v_r.payout_currency,
    v_tx_id, p_proof_reference, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET
    status = 'paid_out',
    payout_status = 'paid',
    updated_at = NOW()
  WHERE id = p_remittance_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_settle_remittance_agent — settlement_send
-- Dr Agent Payable, Cr Cash
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_settle_remittance_agent(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT '1110',
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_cash UUID;
  v_agent_pay UUID;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  v_cash := fx_account_id_by_code(v_r.company_id, p_cash_account_code);
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, remittance_id, created_by
  ) VALUES (
    v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', CURRENT_DATE,
    v_r.payout_agent_party_id, 'PKR', p_amount, 1, p_amount,
    COALESCE(p_notes, 'Agent settlement ' || v_r.tracking_id),
    p_remittance_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_agent_pay, 'PKR', p_amount, 1, p_amount, 0, 'Settle agent payable'),
    (v_tx_id, 2, v_cash, 'PKR', p_amount, 1, 0, p_amount, 'Cash paid to agent');

  PERFORM fx_post_transaction(v_tx_id);

  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose)
  VALUES (p_remittance_id, v_tx_id, 'agent_settlement');

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, amount, currency_code,
    linked_transaction_id, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'agent_settlement', 'completed', p_amount, 'PKR',
    v_tx_id, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET
    settlement_status = 'settled',
    status = 'completed',
    completed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_remittance_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_refund_remittance — settlement_send
-- Dr Remittance Liability, Cr Cash
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_refund_remittance(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT '1110',
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_cash UUID;
  v_liability UUID;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  v_cash := fx_account_id_by_code(v_r.company_id, p_cash_account_code);
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, remittance_id, created_by
  ) VALUES (
    v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', CURRENT_DATE,
    v_r.sender_party_id, v_r.receive_currency, p_amount, 1, p_amount,
    COALESCE(p_notes, 'Remittance refund ' || v_r.tracking_id),
    p_remittance_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_liability, v_r.receive_currency, p_amount, 1, p_amount, 0, 'Reverse liability'),
    (v_tx_id, 2, v_cash, v_r.receive_currency, p_amount, 1, 0, p_amount, 'Refund cash');

  PERFORM fx_post_transaction(v_tx_id);

  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose)
  VALUES (p_remittance_id, v_tx_id, 'refund');

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, amount, currency_code,
    linked_transaction_id, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'refund', 'refunded', p_amount, v_r.receive_currency,
    v_tx_id, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET status = 'refunded', updated_at = NOW() WHERE id = p_remittance_id;
  RETURN v_tx_id;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_record_remittance_customer_payment(UUID, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_confirm_remittance_payout(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_settle_remittance_agent(UUID, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_refund_remittance(UUID, NUMERIC, TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
-- <<<<< END 202606240002_fx_remittance_posting_type_fix.sql

-- >>>>> BEGIN 202606250001_fx_remittance_workflow_h4.sql
-- H4: Remittance workflow — commission mode, payment guards, detail/timeline RPCs
-- Project: ygidlcqhupmxvsdjmvnf only

ALTER TABLE fx_remittances
  ADD COLUMN IF NOT EXISTS commission_mode TEXT NOT NULL DEFAULT 'customer_paid'
    CHECK (commission_mode IN ('customer_paid', 'internal')),
  ADD COLUMN IF NOT EXISTS payout_code TEXT,
  ADD COLUMN IF NOT EXISTS payout_method TEXT,
  ADD COLUMN IF NOT EXISTS payout_confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users (id);

CREATE INDEX IF NOT EXISTS idx_fx_remittances_payout_code ON fx_remittances (payout_code) WHERE payout_code IS NOT NULL;

-- ---------------------------------------------------------------------------
-- fx_create_remittance — commission_mode + total_payable logic
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
  p_commission_mode TEXT DEFAULT 'customer_paid',
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
  v_mode TEXT;
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

  v_mode := CASE WHEN p_commission_mode = 'internal' THEN 'internal' ELSE 'customer_paid' END;
  PERFORM fx_seed_remittance_coa(v_profile.company_id);

  v_total := p_receive_amount + CASE WHEN v_mode = 'customer_paid' THEN COALESCE(p_commission_amount, 0) ELSE 0 END;
  v_no := fx_generate_remittance_no(p_branch_id);
  v_status := CASE WHEN p_book_immediately THEN 'booked'::fx_remittance_status ELSE 'draft'::fx_remittance_status END;

  INSERT INTO fx_remittances (
    company_id, branch_id, remittance_no, tracking_id, sender_party_id,
    receiver_name, receiver_phone, receiver_city, receiver_country,
    payout_agent_party_id, receive_currency, receive_amount, payout_currency, payout_amount,
    exchange_rate, commission_amount, commission_mode, total_payable, status, notes, booked_at, created_by
  ) VALUES (
    v_profile.company_id, p_branch_id, v_no, v_no, p_sender_party_id,
    p_receiver_name, p_receiver_phone, p_receiver_city, p_receiver_country,
    p_payout_agent_party_id, upper(p_receive_currency), p_receive_amount,
    upper(p_payout_currency), p_payout_amount, p_exchange_rate, p_commission_amount, v_mode,
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
-- fx_record_remittance_customer_payment — partial payment stays booked
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_record_remittance_customer_payment(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_cash UUID;
  v_liability UUID;
  v_commission UUID;
  v_pay NUMERIC(20, 8);
  v_comm NUMERIC(20, 8);
  v_new_paid NUMERIC(20, 8);
  v_new_status fx_remittance_status;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status NOT IN ('booked', 'customer_paid') THEN
    RAISE EXCEPTION 'Invalid status for customer payment: %', v_r.status;
  END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  v_cash := CASE
    WHEN p_cash_account_code IS NOT NULL THEN fx_account_id_by_code(v_r.company_id, p_cash_account_code)
    ELSE COALESCE(fx_cash_account_for_currency(v_r.company_id, v_r.receive_currency), fx_account_id_by_code(v_r.company_id, '1110'))
  END;
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_commission := fx_account_id_by_code(v_r.company_id, '4310');

  v_comm := CASE WHEN v_r.commission_mode = 'customer_paid' THEN LEAST(p_amount, v_r.commission_amount) ELSE 0 END;
  v_pay := p_amount - v_comm;
  v_new_paid := v_r.paid_amount + p_amount;
  v_new_status := CASE
    WHEN v_new_paid >= v_r.total_payable THEN 'customer_paid'::fx_remittance_status
    ELSE 'booked'::fx_remittance_status
  END;

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, remittance_id, created_by
  ) VALUES (
    v_r.company_id, v_r.branch_id, 'settlement_receive', 'draft', CURRENT_DATE,
    v_r.sender_party_id, v_r.receive_currency, p_amount, 1, p_amount,
    COALESCE(p_notes, 'Remittance customer payment ' || v_r.tracking_id),
    p_remittance_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, 1, v_cash, v_r.receive_currency, p_amount, 1, p_amount, 0, 'Customer payment received');

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, 2, v_liability, v_r.receive_currency, v_pay, 1, 0, v_pay, 'Remittance liability');

  IF v_comm > 0 THEN
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, 3, v_commission, v_r.receive_currency, v_comm, 1, 0, v_comm, 'Commission income');
  END IF;

  PERFORM fx_post_transaction(v_tx_id);

  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose)
  VALUES (p_remittance_id, v_tx_id, 'customer_payment');

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, amount, currency_code,
    linked_transaction_id, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'customer_payment', v_new_status, p_amount, v_r.receive_currency,
    v_tx_id, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET
    paid_amount = v_new_paid,
    status = v_new_status,
    updated_by = auth.uid(),
    updated_at = NOW()
  WHERE id = p_remittance_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_send_remittance_to_agent — full payment required + payout code
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_send_remittance_to_agent(
  p_remittance_id UUID,
  p_agent_party_id UUID,
  p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_event_no INT;
  v_code TEXT;
BEGIN
  IF NOT fx_has_permission('can_manage_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status IN ('cancelled', 'refunded', 'completed') THEN
    RAISE EXCEPTION 'Remittance is % — cannot send to agent', v_r.status;
  END IF;
  IF v_r.status <> 'customer_paid' THEN
    RAISE EXCEPTION 'Customer must fully pay before sending to agent (status: %)', v_r.status;
  END IF;
  IF v_r.paid_amount < v_r.total_payable THEN
    RAISE EXCEPTION 'Payment incomplete: paid % of % required', v_r.paid_amount, v_r.total_payable;
  END IF;

  v_code := COALESCE(v_r.payout_code, LPAD((FLOOR(random() * 1000000))::TEXT, 6, '0'));

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  UPDATE fx_remittances SET
    payout_agent_party_id = p_agent_party_id,
    payout_code = v_code,
    status = 'sent_to_agent',
    updated_by = auth.uid(),
    updated_at = NOW()
  WHERE id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'sent_to_agent', 'sent_to_agent', p_notes, auth.uid()
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_confirm_remittance_payout — duplicate guard + payout metadata
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_confirm_remittance_payout(
  p_remittance_id UUID,
  p_proof_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_payout_method TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_liability UUID;
  v_agent_pay UUID;
  v_amount NUMERIC(20, 8);
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status IN ('cancelled', 'refunded') THEN
    RAISE EXCEPTION 'Cannot confirm payout — remittance is %', v_r.status;
  END IF;
  IF v_r.status IN ('paid_out', 'completed') THEN
    RAISE EXCEPTION 'Payout already confirmed for this remittance';
  END IF;
  IF v_r.payout_agent_party_id IS NULL THEN RAISE EXCEPTION 'Payout agent required'; END IF;
  IF v_r.status NOT IN ('sent_to_agent', 'ready_for_payout') THEN
    RAISE EXCEPTION 'Invalid status for payout: %', v_r.status;
  END IF;

  v_amount := v_r.receive_amount;
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');

  INSERT INTO fx_transactions (
    company_id, branch_id, transaction_type, status, transaction_date,
    party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
    description, remittance_id, created_by
  ) VALUES (
    v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', CURRENT_DATE,
    v_r.payout_agent_party_id, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate,
    v_amount, COALESCE(p_notes, 'Remittance payout ' || v_r.tracking_id),
    p_remittance_id, auth.uid()
  ) RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES
    (v_tx_id, 1, v_liability, v_r.receive_currency, v_amount, 1, v_amount, 0, 'Clear remittance liability'),
    (v_tx_id, 2, v_agent_pay, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, 0, v_amount, 'Agent payable');

  PERFORM fx_post_transaction(v_tx_id);

  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose)
  VALUES (p_remittance_id, v_tx_id, 'agent_payout');

  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;

  INSERT INTO fx_remittance_events (
    remittance_id, event_no, event_type, status_after, amount, currency_code,
    linked_transaction_id, proof_reference, notes, created_by
  ) VALUES (
    p_remittance_id, v_event_no, 'payout_confirmed', 'paid_out', v_r.payout_amount, v_r.payout_currency,
    v_tx_id, p_proof_reference, p_notes, auth.uid()
  );

  UPDATE fx_remittances SET
    status = 'paid_out',
    payout_status = 'paid',
    payout_method = COALESCE(p_payout_method, payout_method),
    payout_confirmed_at = NOW(),
    updated_by = auth.uid(),
    updated_at = NOW()
  WHERE id = p_remittance_id;

  RETURN v_tx_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_get_remittance_detail
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_get_remittance_detail(p_remittance_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'id', r.id,
    'remittance_no', r.remittance_no,
    'tracking_id', r.tracking_id,
    'sender_party_id', r.sender_party_id,
    'sender_name', sp.name,
    'receiver_name', r.receiver_name,
    'receiver_phone', r.receiver_phone,
    'receiver_city', r.receiver_city,
    'receiver_country', r.receiver_country,
    'payout_agent_party_id', r.payout_agent_party_id,
    'payout_agent_name', ap.name,
    'branch_id', r.branch_id,
    'branch_name', b.name,
    'receive_currency', r.receive_currency,
    'receive_amount', r.receive_amount,
    'payout_currency', r.payout_currency,
    'payout_amount', r.payout_amount,
    'exchange_rate', r.exchange_rate,
    'commission_amount', r.commission_amount,
    'commission_mode', r.commission_mode,
    'total_payable', r.total_payable,
    'paid_amount', r.paid_amount,
    'balance_due', GREATEST(0, r.total_payable - r.paid_amount),
    'status', r.status,
    'payout_status', r.payout_status,
    'settlement_status', r.settlement_status,
    'payout_code', r.payout_code,
    'payout_method', r.payout_method,
    'payout_confirmed_at', r.payout_confirmed_at,
    'notes', r.notes,
    'booked_at', r.booked_at,
    'completed_at', r.completed_at,
    'created_by', r.created_by,
    'created_by_name', cp.full_name,
    'created_at', r.created_at,
    'updated_at', r.updated_at
  ) INTO v_result
  FROM fx_remittances r
  JOIN fx_branches b ON b.id = r.branch_id
  JOIN fx_parties sp ON sp.id = r.sender_party_id
  LEFT JOIN fx_parties ap ON ap.id = r.payout_agent_party_id
  LEFT JOIN fx_users_profiles cp ON cp.id = r.created_by
  WHERE r.id = p_remittance_id
    AND fx_same_branch(r.branch_id);

  IF v_result IS NULL THEN
    RAISE EXCEPTION 'Remittance not found or unauthorized';
  END IF;

  RETURN v_result;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_get_remittance_timeline — enriched
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS fx_get_remittance_timeline(UUID);

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
  created_at TIMESTAMPTZ,
  created_by UUID,
  created_by_name TEXT,
  branch_name TEXT,
  actor_role TEXT,
  attachment_count BIGINT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    e.id,
    e.event_no,
    e.event_type,
    e.status_after,
    e.amount,
    e.currency_code,
    e.linked_transaction_id,
    e.proof_reference,
    e.notes,
    e.created_at,
    e.created_by,
    p.full_name,
    b.name,
    COALESCE(
      (SELECT r.name FROM fx_user_roles ur JOIN fx_roles r ON r.id = ur.role_id
       WHERE ur.user_id = e.created_by LIMIT 1),
      'staff'
    ),
    (SELECT COUNT(*) FROM fx_attachments a WHERE a.remittance_event_id = e.id)
  FROM fx_remittance_events e
  JOIN fx_remittances rem ON rem.id = e.remittance_id
  JOIN fx_branches b ON b.id = rem.branch_id
  LEFT JOIN fx_users_profiles p ON p.id = e.created_by
  WHERE e.remittance_id = p_remittance_id
    AND fx_same_branch(rem.branch_id)
  ORDER BY e.event_no;
$$;

GRANT EXECUTE ON FUNCTION fx_create_remittance(UUID, UUID, TEXT, TEXT, TEXT, TEXT, UUID, TEXT, NUMERIC, TEXT, NUMERIC, NUMERIC, NUMERIC, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_record_remittance_customer_payment(UUID, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_send_remittance_to_agent(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_confirm_remittance_payout(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_remittance_detail(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_remittance_timeline(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
-- <<<<< END 202606250001_fx_remittance_workflow_h4.sql

-- >>>>> BEGIN 202606250002_fx_remittance_agent_h5.sql
-- H5: Agent remittance workspace — linked party + agent RPCs
-- Project: ygidlcqhupmxvsdjmvnf only

ALTER TABLE fx_users_profiles
  ADD COLUMN IF NOT EXISTS linked_party_id UUID REFERENCES fx_parties (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_fx_users_profiles_linked_party ON fx_users_profiles (linked_party_id) WHERE linked_party_id IS NOT NULL;

UPDATE fx_roles SET permissions = array_append(permissions, 'can_agent_remittance')
WHERE name IN ('admin', 'manager', 'agent')
  AND NOT ('can_agent_remittance' = ANY (permissions));

DROP POLICY IF EXISTS fx_remittances_agent_select ON fx_remittances;
CREATE POLICY fx_remittances_agent_select ON fx_remittances
  FOR SELECT TO authenticated
  USING (
    payout_agent_party_id IS NOT NULL
    AND payout_agent_party_id = (SELECT linked_party_id FROM fx_users_profiles WHERE id = auth.uid())
    AND fx_has_permission('can_agent_remittance')
  );

CREATE OR REPLACE FUNCTION fx_list_agent_remittances(p_query TEXT DEFAULT NULL)
RETURNS SETOF fx_remittances
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_party UUID;
  v_q TEXT;
BEGIN
  IF NOT fx_has_permission('can_agent_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT linked_party_id INTO v_party FROM fx_users_profiles WHERE id = auth.uid();
  IF v_party IS NULL THEN RAISE EXCEPTION 'No agent party linked to your profile'; END IF;
  v_q := NULLIF(trim(p_query), '');
  RETURN QUERY
  SELECT r.* FROM fx_remittances r
  WHERE r.payout_agent_party_id = v_party
    AND (v_q IS NULL OR r.remittance_no ILIKE '%' || v_q || '%' OR r.tracking_id ILIKE '%' || v_q || '%'
      OR r.receiver_name ILIKE '%' || v_q || '%' OR r.receiver_phone ILIKE '%' || v_q || '%' OR r.payout_code = v_q)
  ORDER BY r.updated_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION fx_agent_confirm_remittance_payout(
  p_remittance_id UUID,
  p_amount NUMERIC DEFAULT NULL,
  p_payout_method TEXT DEFAULT NULL,
  p_payout_at TIMESTAMPTZ DEFAULT NULL,
  p_proof_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_liability UUID;
  v_agent_pay UUID;
  v_amount NUMERIC(20, 8);
  v_payout_at TIMESTAMPTZ;
BEGIN
  IF NOT fx_has_permission('can_agent_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_profile FROM fx_current_profile();
  IF v_profile.linked_party_id IS NULL THEN RAISE EXCEPTION 'No agent party linked'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF v_r.payout_agent_party_id IS DISTINCT FROM v_profile.linked_party_id THEN RAISE EXCEPTION 'Not assigned to your agent account'; END IF;
  IF v_r.status IN ('cancelled', 'refunded') THEN RAISE EXCEPTION 'Cannot confirm — remittance is %', v_r.status; END IF;
  IF v_r.status IN ('paid_out', 'completed') THEN RAISE EXCEPTION 'Payout already confirmed'; END IF;
  IF v_r.status NOT IN ('sent_to_agent', 'ready_for_payout') THEN RAISE EXCEPTION 'Invalid status: %', v_r.status; END IF;
  v_amount := v_r.receive_amount;
  v_payout_at := COALESCE(p_payout_at, NOW());
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');
  INSERT INTO fx_transactions (company_id, branch_id, transaction_type, status, transaction_date, party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr, description, remittance_id, created_by)
  VALUES (v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', (v_payout_at AT TIME ZONE 'UTC')::DATE, v_r.payout_agent_party_id, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, v_amount, COALESCE(p_notes, 'Agent payout ' || v_r.tracking_id), p_remittance_id, auth.uid()) RETURNING id INTO v_tx_id;
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo) VALUES
    (v_tx_id, 1, v_liability, v_r.receive_currency, v_amount, 1, v_amount, 0, 'Clear remittance liability'),
    (v_tx_id, 2, v_agent_pay, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, 0, v_amount, 'Agent payable');
  PERFORM fx_post_transaction(v_tx_id);
  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose) VALUES (p_remittance_id, v_tx_id, 'agent_payout');
  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, amount, currency_code, linked_transaction_id, proof_reference, notes, created_by)
  VALUES (p_remittance_id, v_event_no, 'payout_confirmed', 'paid_out', v_r.payout_amount, v_r.payout_currency, v_tx_id, p_proof_reference, p_notes, auth.uid());
  UPDATE fx_remittances SET status = 'paid_out', payout_status = 'paid', payout_method = COALESCE(p_payout_method, payout_method), payout_confirmed_at = v_payout_at, updated_by = auth.uid(), updated_at = NOW() WHERE id = p_remittance_id;
  RETURN v_tx_id;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_list_agent_remittances(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_agent_confirm_remittance_payout(UUID, NUMERIC, TEXT, TIMESTAMPTZ, TEXT, TEXT) TO authenticated;
NOTIFY pgrst, 'reload schema';
-- <<<<< END 202606250002_fx_remittance_agent_h5.sql

-- >>>>> BEGIN 202606250003_fx_remittance_notifications_audit_h6.sql
-- H6: Remittance notifications + audit trail
-- Project: ygidlcqhupmxvsdjmvnf only

CREATE TABLE IF NOT EXISTS fx_notifications (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id          UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id           UUID REFERENCES fx_branches (id) ON DELETE RESTRICT,
  recipient_user_id   UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  remittance_id       UUID REFERENCES fx_remittances (id) ON DELETE CASCADE,
  event_type          TEXT NOT NULL,
  title               TEXT NOT NULL,
  body                TEXT NOT NULL,
  payload             JSONB NOT NULL DEFAULT '{}',
  read_at             TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fx_notifications_recipient ON fx_notifications (recipient_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fx_notifications_remittance ON fx_notifications (remittance_id);

ALTER TABLE fx_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fx_notifications_select ON fx_notifications;
CREATE POLICY fx_notifications_select ON fx_notifications
  FOR SELECT TO authenticated
  USING (
    recipient_user_id = auth.uid()
    OR (branch_id IS NOT NULL AND fx_same_branch(branch_id) AND fx_has_permission('can_manage_remittance'))
  );

DROP POLICY IF EXISTS fx_notifications_update ON fx_notifications;
CREATE POLICY fx_notifications_update ON fx_notifications
  FOR UPDATE TO authenticated
  USING (recipient_user_id = auth.uid())
  WITH CHECK (recipient_user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_remittance_write_audit(
  p_remittance_id UUID,
  p_action fx_audit_action,
  p_old_status TEXT,
  p_new_status TEXT,
  p_amount NUMERIC DEFAULT NULL,
  p_note TEXT DEFAULT NULL,
  p_proof_reference TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_role TEXT;
BEGIN
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RETURN; END IF;

  SELECT r.name INTO v_role
  FROM fx_user_roles ur
  JOIN fx_roles r ON r.id = ur.role_id
  WHERE ur.user_id = auth.uid()
  LIMIT 1;

  INSERT INTO fx_audit_logs (company_id, branch_id, entity_type, entity_id, action, old_value, new_value, actor_id)
  VALUES (
    v_r.company_id,
    v_r.branch_id,
    'fx_remittances',
    p_remittance_id,
    p_action,
    jsonb_build_object('status', p_old_status, 'amount', p_amount, 'note', p_note, 'proof', p_proof_reference),
    jsonb_build_object('status', p_new_status, 'amount', p_amount, 'note', p_note, 'proof', p_proof_reference, 'role', v_role),
    auth.uid()
  );
END;
$$;

CREATE OR REPLACE FUNCTION fx_remittance_notify_branch(
  p_remittance_id UUID,
  p_event_type TEXT,
  p_title TEXT,
  p_body TEXT,
  p_payload JSONB DEFAULT '{}'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_user RECORD;
BEGIN
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id;
  IF NOT FOUND THEN RETURN; END IF;

  FOR v_user IN
    SELECT DISTINCT u.id AS user_id
    FROM (
      SELECT v_r.created_by AS id WHERE v_r.created_by IS NOT NULL
      UNION
      SELECT p.id FROM fx_users_profiles p
      JOIN fx_user_roles ur ON ur.user_id = p.id
      JOIN fx_roles r ON r.id = ur.role_id
      WHERE p.branch_id = v_r.branch_id
        AND p.is_active
        AND ('can_manage_remittance' = ANY (r.permissions) OR 'can_post_fx_transaction' = ANY (r.permissions))
    ) u
    WHERE u.id IS NOT NULL
  LOOP
    INSERT INTO fx_notifications (
      company_id, branch_id, recipient_user_id, remittance_id,
      event_type, title, body, payload
    ) VALUES (
      v_r.company_id, v_r.branch_id, v_user.user_id, p_remittance_id,
      p_event_type, p_title, p_body, p_payload
    );
  END LOOP;
END;
$$;

-- Patch payment RPC with audit + notify
CREATE OR REPLACE FUNCTION fx_record_remittance_customer_payment(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_cash UUID;
  v_liability UUID;
  v_commission UUID;
  v_pay NUMERIC(20, 8);
  v_comm NUMERIC(20, 8);
  v_new_paid NUMERIC(20, 8);
  v_new_status fx_remittance_status;
  v_old_status TEXT;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status NOT IN ('booked', 'customer_paid') THEN RAISE EXCEPTION 'Invalid status for customer payment: %', v_r.status; END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;

  v_old_status := v_r.status::TEXT;
  v_cash := CASE WHEN p_cash_account_code IS NOT NULL THEN fx_account_id_by_code(v_r.company_id, p_cash_account_code)
    ELSE COALESCE(fx_cash_account_for_currency(v_r.company_id, v_r.receive_currency), fx_account_id_by_code(v_r.company_id, '1110')) END;
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_commission := fx_account_id_by_code(v_r.company_id, '4310');
  v_comm := CASE WHEN v_r.commission_mode = 'customer_paid' THEN LEAST(p_amount, v_r.commission_amount) ELSE 0 END;
  v_pay := p_amount - v_comm;
  v_new_paid := v_r.paid_amount + p_amount;
  v_new_status := CASE WHEN v_new_paid >= v_r.total_payable THEN 'customer_paid'::fx_remittance_status ELSE 'booked'::fx_remittance_status END;

  INSERT INTO fx_transactions (company_id, branch_id, transaction_type, status, transaction_date, party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr, description, remittance_id, created_by)
  VALUES (v_r.company_id, v_r.branch_id, 'settlement_receive', 'draft', CURRENT_DATE, v_r.sender_party_id, v_r.receive_currency, p_amount, 1, p_amount,
    COALESCE(p_notes, 'Remittance customer payment ' || v_r.tracking_id), p_remittance_id, auth.uid())
  RETURNING id INTO v_tx_id;

  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, 1, v_cash, v_r.receive_currency, p_amount, 1, p_amount, 0, 'Customer payment received');
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
  VALUES (v_tx_id, 2, v_liability, v_r.receive_currency, v_pay, 1, 0, v_pay, 'Remittance liability');
  IF v_comm > 0 THEN
    INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo)
    VALUES (v_tx_id, 3, v_commission, v_r.receive_currency, v_comm, 1, 0, v_comm, 'Commission income');
  END IF;

  PERFORM fx_post_transaction(v_tx_id);
  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose) VALUES (p_remittance_id, v_tx_id, 'customer_payment');
  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, amount, currency_code, linked_transaction_id, notes, created_by)
  VALUES (p_remittance_id, v_event_no, 'customer_payment', v_new_status, p_amount, v_r.receive_currency, v_tx_id, p_notes, auth.uid());

  UPDATE fx_remittances SET paid_amount = v_new_paid, status = v_new_status, updated_by = auth.uid(), updated_at = NOW() WHERE id = p_remittance_id;

  PERFORM fx_remittance_write_audit(p_remittance_id, 'posted', v_old_status, v_new_status::TEXT, p_amount, p_notes, NULL);
  PERFORM fx_remittance_notify_branch(p_remittance_id, 'payment_received', 'Payment received — ' || v_r.tracking_id,
    'Customer payment of ' || p_amount::TEXT || ' ' || v_r.receive_currency,
    jsonb_build_object('amount', p_amount, 'status', v_new_status::TEXT));

  RETURN v_tx_id;
END;
$$;

-- Patch send to agent
CREATE OR REPLACE FUNCTION fx_send_remittance_to_agent(
  p_remittance_id UUID,
  p_agent_party_id UUID,
  p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_event_no INT;
  v_code TEXT;
  v_old_status TEXT;
  v_agent_name TEXT;
BEGIN
  IF NOT fx_has_permission('can_manage_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status IN ('cancelled', 'refunded', 'completed') THEN RAISE EXCEPTION 'Remittance is % — cannot send to agent', v_r.status; END IF;
  IF v_r.status <> 'customer_paid' THEN RAISE EXCEPTION 'Customer must fully pay before sending to agent'; END IF;
  IF v_r.paid_amount < v_r.total_payable THEN RAISE EXCEPTION 'Payment incomplete'; END IF;

  v_old_status := v_r.status::TEXT;
  v_code := COALESCE(v_r.payout_code, LPAD((FLOOR(random() * 1000000))::TEXT, 6, '0'));
  SELECT name INTO v_agent_name FROM fx_parties WHERE id = p_agent_party_id;

  UPDATE fx_remittances SET payout_agent_party_id = p_agent_party_id, payout_code = v_code, status = 'sent_to_agent', updated_by = auth.uid(), updated_at = NOW() WHERE id = p_remittance_id;
  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, notes, created_by) VALUES (p_remittance_id, v_event_no, 'sent_to_agent', 'sent_to_agent', p_notes, auth.uid());

  PERFORM fx_remittance_write_audit(p_remittance_id, 'edited', v_old_status, 'sent_to_agent', NULL, p_notes, v_code);
  PERFORM fx_remittance_notify_branch(p_remittance_id, 'sent_to_agent', 'Sent to agent — ' || v_r.tracking_id,
    'Assigned to ' || COALESCE(v_agent_name, 'agent') || '. Payout code: ' || v_code,
    jsonb_build_object('agent_party_id', p_agent_party_id, 'payout_code', v_code));
END;
$$;

-- Patch branch confirm payout with audit + notify
CREATE OR REPLACE FUNCTION fx_confirm_remittance_payout(
  p_remittance_id UUID,
  p_proof_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_payout_method TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_liability UUID;
  v_agent_pay UUID;
  v_amount NUMERIC(20, 8);
  v_old_status TEXT;
  v_agent_name TEXT;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF NOT fx_same_branch(v_r.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;
  IF v_r.status IN ('cancelled', 'refunded') THEN RAISE EXCEPTION 'Cannot confirm payout — remittance is %', v_r.status; END IF;
  IF v_r.status IN ('paid_out', 'completed') THEN RAISE EXCEPTION 'Payout already confirmed'; END IF;
  IF v_r.payout_agent_party_id IS NULL THEN RAISE EXCEPTION 'Payout agent required'; END IF;
  IF v_r.status NOT IN ('sent_to_agent', 'ready_for_payout') THEN RAISE EXCEPTION 'Invalid status for payout: %', v_r.status; END IF;

  v_old_status := v_r.status::TEXT;
  v_amount := v_r.receive_amount;
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');
  SELECT name INTO v_agent_name FROM fx_parties WHERE id = v_r.payout_agent_party_id;

  INSERT INTO fx_transactions (company_id, branch_id, transaction_type, status, transaction_date, party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr, description, remittance_id, created_by)
  VALUES (v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', CURRENT_DATE, v_r.payout_agent_party_id, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, v_amount,
    COALESCE(p_notes, 'Remittance payout ' || v_r.tracking_id), p_remittance_id, auth.uid()) RETURNING id INTO v_tx_id;
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo) VALUES
    (v_tx_id, 1, v_liability, v_r.receive_currency, v_amount, 1, v_amount, 0, 'Clear remittance liability'),
    (v_tx_id, 2, v_agent_pay, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, 0, v_amount, 'Agent payable');
  PERFORM fx_post_transaction(v_tx_id);
  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose) VALUES (p_remittance_id, v_tx_id, 'agent_payout');
  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, amount, currency_code, linked_transaction_id, proof_reference, notes, created_by)
  VALUES (p_remittance_id, v_event_no, 'payout_confirmed', 'paid_out', v_r.payout_amount, v_r.payout_currency, v_tx_id, p_proof_reference, p_notes, auth.uid());
  UPDATE fx_remittances SET status = 'paid_out', payout_status = 'paid', payout_method = COALESCE(p_payout_method, payout_method), payout_confirmed_at = NOW(), updated_by = auth.uid(), updated_at = NOW() WHERE id = p_remittance_id;

  PERFORM fx_remittance_write_audit(p_remittance_id, 'posted', v_old_status, 'paid_out', v_r.payout_amount, p_notes, p_proof_reference);
  PERFORM fx_remittance_notify_branch(p_remittance_id, 'payout_confirmed', 'Payout confirmed — ' || v_r.tracking_id,
    COALESCE(v_agent_name, 'Agent') || ' confirmed payout ' || v_r.payout_amount::TEXT || ' ' || v_r.payout_currency,
    jsonb_build_object('amount', v_r.payout_amount, 'payout_confirmed_at', NOW()));

  RETURN v_tx_id;
END;
$$;

-- Patch agent confirm with notify
CREATE OR REPLACE FUNCTION fx_agent_confirm_remittance_payout(
  p_remittance_id UUID,
  p_amount NUMERIC DEFAULT NULL,
  p_payout_method TEXT DEFAULT NULL,
  p_payout_at TIMESTAMPTZ DEFAULT NULL,
  p_proof_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_liability UUID;
  v_agent_pay UUID;
  v_amount NUMERIC(20, 8);
  v_payout_at TIMESTAMPTZ;
  v_old_status TEXT;
  v_agent_name TEXT;
BEGIN
  IF NOT fx_has_permission('can_agent_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_profile FROM fx_current_profile();
  IF v_profile.linked_party_id IS NULL THEN RAISE EXCEPTION 'No agent party linked'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF v_r.payout_agent_party_id IS DISTINCT FROM v_profile.linked_party_id THEN RAISE EXCEPTION 'Not assigned to your agent account'; END IF;
  IF v_r.status IN ('cancelled', 'refunded') THEN RAISE EXCEPTION 'Cannot confirm — remittance is %', v_r.status; END IF;
  IF v_r.status IN ('paid_out', 'completed') THEN RAISE EXCEPTION 'Payout already confirmed'; END IF;
  IF v_r.status NOT IN ('sent_to_agent', 'ready_for_payout') THEN RAISE EXCEPTION 'Invalid status: %', v_r.status; END IF;

  v_old_status := v_r.status::TEXT;
  v_amount := v_r.receive_amount;
  v_payout_at := COALESCE(p_payout_at, NOW());
  v_liability := fx_account_id_by_code(v_r.company_id, '2350');
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');
  SELECT name INTO v_agent_name FROM fx_parties WHERE id = v_profile.linked_party_id;

  INSERT INTO fx_transactions (company_id, branch_id, transaction_type, status, transaction_date, party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr, description, remittance_id, created_by)
  VALUES (v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', (v_payout_at AT TIME ZONE 'UTC')::DATE, v_r.payout_agent_party_id, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, v_amount,
    COALESCE(p_notes, 'Agent payout ' || v_r.tracking_id), p_remittance_id, auth.uid()) RETURNING id INTO v_tx_id;
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo) VALUES
    (v_tx_id, 1, v_liability, v_r.receive_currency, v_amount, 1, v_amount, 0, 'Clear remittance liability'),
    (v_tx_id, 2, v_agent_pay, v_r.payout_currency, v_r.payout_amount, v_r.exchange_rate, 0, v_amount, 'Agent payable');
  PERFORM fx_post_transaction(v_tx_id);
  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose) VALUES (p_remittance_id, v_tx_id, 'agent_payout');
  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, amount, currency_code, linked_transaction_id, proof_reference, notes, created_by)
  VALUES (p_remittance_id, v_event_no, 'payout_confirmed', 'paid_out', v_r.payout_amount, v_r.payout_currency, v_tx_id, p_proof_reference, p_notes, auth.uid());
  UPDATE fx_remittances SET status = 'paid_out', payout_status = 'paid', payout_method = COALESCE(p_payout_method, payout_method), payout_confirmed_at = v_payout_at, updated_by = auth.uid(), updated_at = NOW() WHERE id = p_remittance_id;

  PERFORM fx_remittance_write_audit(p_remittance_id, 'posted', v_old_status, 'paid_out', v_r.payout_amount, p_notes, p_proof_reference);
  PERFORM fx_remittance_notify_branch(p_remittance_id, 'payout_confirmed', 'Agent payout — ' || v_r.tracking_id,
    COALESCE(v_agent_name, 'Agent') || ' paid ' || v_r.payout_amount::TEXT || ' ' || v_r.payout_currency || ' at ' || v_payout_at::TEXT,
    jsonb_build_object('agent_name', v_agent_name, 'amount', v_r.payout_amount, 'payout_at', v_payout_at));

  RETURN v_tx_id;
END;
$$;

-- Patch settlement + cancel with audit/notify
CREATE OR REPLACE FUNCTION fx_settle_remittance_agent(
  p_remittance_id UUID,
  p_amount NUMERIC,
  p_cash_account_code TEXT DEFAULT '1110',
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_tx_id UUID;
  v_event_no INT;
  v_cash UUID;
  v_agent_pay UUID;
  v_old_status TEXT;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;
  v_old_status := v_r.status::TEXT;
  v_cash := fx_account_id_by_code(v_r.company_id, p_cash_account_code);
  v_agent_pay := fx_account_id_by_code(v_r.company_id, '2100');
  INSERT INTO fx_transactions (company_id, branch_id, transaction_type, status, transaction_date, party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr, description, remittance_id, created_by)
  VALUES (v_r.company_id, v_r.branch_id, 'settlement_send', 'draft', CURRENT_DATE, v_r.payout_agent_party_id, 'PKR', p_amount, 1, p_amount, COALESCE(p_notes, 'Agent settlement ' || v_r.tracking_id), p_remittance_id, auth.uid()) RETURNING id INTO v_tx_id;
  INSERT INTO fx_transaction_lines (transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used, debit_pkr, credit_pkr, memo) VALUES
    (v_tx_id, 1, v_agent_pay, 'PKR', p_amount, 1, p_amount, 0, 'Settle agent payable'),
    (v_tx_id, 2, v_cash, 'PKR', p_amount, 1, 0, p_amount, 'Cash paid to agent');
  PERFORM fx_post_transaction(v_tx_id);
  INSERT INTO fx_remittance_transactions (remittance_id, transaction_id, purpose) VALUES (p_remittance_id, v_tx_id, 'agent_settlement');
  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, amount, currency_code, linked_transaction_id, notes, created_by)
  VALUES (p_remittance_id, v_event_no, 'agent_settlement', 'completed', p_amount, 'PKR', v_tx_id, p_notes, auth.uid());
  UPDATE fx_remittances SET settlement_status = 'settled', status = 'completed', completed_at = NOW(), updated_by = auth.uid(), updated_at = NOW() WHERE id = p_remittance_id;
  PERFORM fx_remittance_write_audit(p_remittance_id, 'posted', v_old_status, 'completed', p_amount, p_notes, NULL);
  PERFORM fx_remittance_notify_branch(p_remittance_id, 'settlement_completed', 'Settlement complete — ' || v_r.tracking_id, 'Agent settlement of PKR ' || p_amount::TEXT, jsonb_build_object('amount', p_amount));
  RETURN v_tx_id;
END;
$$;

CREATE OR REPLACE FUNCTION fx_cancel_remittance(
  p_remittance_id UUID,
  p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_r fx_remittances;
  v_event_no INT;
  v_old_status TEXT;
BEGIN
  IF NOT fx_has_permission('can_manage_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT * INTO v_r FROM fx_remittances WHERE id = p_remittance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Remittance not found'; END IF;
  IF v_r.status NOT IN ('draft', 'booked') THEN RAISE EXCEPTION 'Can only cancel draft or booked remittances'; END IF;
  v_old_status := v_r.status::TEXT;
  SELECT COALESCE(MAX(event_no), 0) + 1 INTO v_event_no FROM fx_remittance_events WHERE remittance_id = p_remittance_id;
  UPDATE fx_remittances SET status = 'cancelled', cancelled_at = NOW(), updated_by = auth.uid(), updated_at = NOW() WHERE id = p_remittance_id;
  INSERT INTO fx_remittance_events (remittance_id, event_no, event_type, status_after, notes, created_by) VALUES (p_remittance_id, v_event_no, 'status_change', 'cancelled', p_notes, auth.uid());
  PERFORM fx_remittance_write_audit(p_remittance_id, 'voided', v_old_status, 'cancelled', NULL, p_notes, NULL);
  PERFORM fx_remittance_notify_branch(p_remittance_id, 'cancellation', 'Cancelled — ' || v_r.tracking_id, COALESCE(p_notes, 'Remittance cancelled'), jsonb_build_object('status', 'cancelled'));
END;
$$;

CREATE OR REPLACE FUNCTION fx_list_notifications(p_unread_only BOOLEAN DEFAULT FALSE)
RETURNS SETOF fx_notifications
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT n.*
  FROM fx_notifications n
  WHERE n.recipient_user_id = auth.uid()
    AND (NOT p_unread_only OR n.read_at IS NULL)
  ORDER BY n.created_at DESC
  LIMIT 100;
$$;

CREATE OR REPLACE FUNCTION fx_mark_notification_read(p_notification_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE fx_notifications SET read_at = NOW() WHERE id = p_notification_id AND recipient_user_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION fx_remittance_write_audit(UUID, fx_audit_action, TEXT, TEXT, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_list_notifications(BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_mark_notification_read(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_record_remittance_customer_payment(UUID, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_send_remittance_to_agent(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_confirm_remittance_payout(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_agent_confirm_remittance_payout(UUID, NUMERIC, TEXT, TIMESTAMPTZ, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_settle_remittance_agent(UUID, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_cancel_remittance(UUID, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
-- <<<<< END 202606250003_fx_remittance_notifications_audit_h6.sql

-- >>>>> BEGIN 202606250004_fx_remittance_reports_h7.sql
-- H7: Remittance reports — cash flow + statements (read-only aggregation)
-- Project: ygidlcqhupmxvsdjmvnf only

-- ---------------------------------------------------------------------------
-- fx_remittance_cash_flow_summary
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_remittance_cash_flow_summary(
  p_branch_id UUID,
  p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_company UUID;
  v_liability UUID;
  v_agent_pay UUID;
  v_commission UUID;
  v_result JSONB;
BEGIN
  IF NOT fx_has_permission('can_view_remittance_reports') AND NOT fx_has_permission('can_manage_remittance') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  SELECT company_id INTO v_company FROM fx_branches WHERE id = p_branch_id;
  v_liability := fx_account_id_by_code(v_company, '2350');
  v_agent_pay := fx_account_id_by_code(v_company, '2100');
  v_commission := fx_account_id_by_code(v_company, '4310');

  SELECT jsonb_build_object(
    'branch_id', p_branch_id,
    'date', p_date,
    'customer_received_today', COALESCE((
      SELECT SUM(e.amount)
      FROM fx_remittance_events e
      JOIN fx_remittances r ON r.id = e.remittance_id
      WHERE r.branch_id = p_branch_id
        AND e.event_type = 'customer_payment'
        AND (e.created_at AT TIME ZONE 'UTC')::DATE = p_date
    ), 0),
    'agent_payouts_today', COALESCE((
      SELECT SUM(e.amount)
      FROM fx_remittance_events e
      JOIN fx_remittances r ON r.id = e.remittance_id
      WHERE r.branch_id = p_branch_id
        AND e.event_type = 'payout_confirmed'
        AND (e.created_at AT TIME ZONE 'UTC')::DATE = p_date
    ), 0),
    'commission_earned_today', COALESCE((
      SELECT SUM(jl.credit_pkr - jl.debit_pkr)
      FROM fx_journal_lines jl
      JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
      JOIN fx_transactions t ON t.id = je.source_transaction_id
      WHERE je.branch_id = p_branch_id
        AND NOT je.is_void
        AND je.entry_date = p_date
        AND jl.account_id = v_commission
        AND t.remittance_id IS NOT NULL
    ), 0),
    'pending_payout_liability', COALESCE((
      SELECT SUM(jl.credit_pkr - jl.debit_pkr)
      FROM fx_journal_lines jl
      JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
      WHERE je.branch_id = p_branch_id
        AND NOT je.is_void
        AND je.entry_date <= p_date
        AND jl.account_id = v_liability
    ), 0),
    'pending_agent_settlement', COALESCE((
      SELECT SUM(jl.credit_pkr - jl.debit_pkr)
      FROM fx_journal_lines jl
      JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
      WHERE je.branch_id = p_branch_id
        AND NOT je.is_void
        AND je.entry_date <= p_date
        AND jl.account_id = v_agent_pay
    ), 0),
    'remittances_created_today', (
      SELECT COUNT(*)
      FROM fx_remittances r
      WHERE r.branch_id = p_branch_id
        AND (r.created_at AT TIME ZONE 'UTC')::DATE = p_date
    ),
    'remittances_paid_out_today', (
      SELECT COUNT(*)
      FROM fx_remittances r
      WHERE r.branch_id = p_branch_id
        AND r.payout_confirmed_at IS NOT NULL
        AND (r.payout_confirmed_at AT TIME ZONE 'UTC')::DATE = p_date
    ),
    'remittances_pending_payout', (
      SELECT COUNT(*)
      FROM fx_remittances r
      WHERE r.branch_id = p_branch_id
        AND r.status IN ('sent_to_agent', 'ready_for_payout')
    ),
    'total_receive_volume_today', COALESCE((
      SELECT SUM(r.receive_amount)
      FROM fx_remittances r
      WHERE r.branch_id = p_branch_id
        AND (r.created_at AT TIME ZONE 'UTC')::DATE = p_date
    ), 0),
    'cash_accounts', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'account_code', cb.account_code,
        'account_name', cb.account_name,
        'currency_code', cb.currency_code,
        'balance_pkr', cb.balance_pkr,
        'foreign_balance', cb.foreign_balance
      ) ORDER BY cb.account_code, cb.currency_code)
      FROM fx_get_cash_balances(p_branch_id) cb
    ), '[]'::JSONB)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_remittance_agent_statement
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_remittance_agent_statement(
  p_agent_party_id UUID,
  p_from DATE DEFAULT date_trunc('month', CURRENT_DATE)::DATE,
  p_to DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_agent_name TEXT;
  v_company UUID;
  v_agent_pay UUID;
  v_balance NUMERIC(20, 8);
  v_remittances JSONB;
BEGIN
  SELECT * INTO v_profile FROM fx_current_profile();
  IF fx_has_permission('can_agent_remittance')
     AND v_profile.linked_party_id IS NOT NULL
     AND v_profile.linked_party_id = p_agent_party_id THEN
    NULL;
  ELSIF fx_has_permission('can_view_remittance_reports') OR fx_has_permission('can_manage_remittance') THEN
    IF NOT EXISTS (
      SELECT 1 FROM fx_remittances r
      WHERE r.payout_agent_party_id = p_agent_party_id
        AND fx_same_branch(r.branch_id)
    ) THEN
      RAISE EXCEPTION 'Unauthorized agent access';
    END IF;
  ELSE
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT name INTO v_agent_name FROM fx_parties WHERE id = p_agent_party_id;
  SELECT company_id INTO v_company FROM fx_parties WHERE id = p_agent_party_id;
  v_agent_pay := fx_account_id_by_code(v_company, '2100');

  SELECT COALESCE(SUM(jl.credit_pkr - jl.debit_pkr), 0) INTO v_balance
  FROM fx_journal_lines jl
  JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
  JOIN fx_transactions t ON t.id = je.source_transaction_id
  JOIN fx_remittances r ON r.id = t.remittance_id
  WHERE jl.account_id = v_agent_pay
    AND NOT je.is_void
    AND je.entry_date <= p_to
    AND r.payout_agent_party_id = p_agent_party_id
    AND fx_same_branch(r.branch_id);

  SELECT COALESCE(jsonb_agg(row_to_json(x)::JSONB ORDER BY x.booked_at DESC NULLS LAST, x.remittance_no DESC), '[]'::JSONB)
  INTO v_remittances
  FROM (
    SELECT
      r.id,
      r.remittance_no,
      r.tracking_id,
      r.receiver_name,
      r.receive_currency,
      r.receive_amount,
      r.payout_currency,
      r.payout_amount,
      r.status,
      r.payout_status,
      r.settlement_status,
      r.booked_at,
      r.payout_confirmed_at,
      r.completed_at,
      b.name AS branch_name
    FROM fx_remittances r
    JOIN fx_branches b ON b.id = r.branch_id
    WHERE r.payout_agent_party_id = p_agent_party_id
      AND fx_same_branch(r.branch_id)
      AND COALESCE(r.booked_at, r.created_at)::DATE BETWEEN p_from AND p_to
  ) x;

  RETURN jsonb_build_object(
    'agent_party_id', p_agent_party_id,
    'agent_name', v_agent_name,
    'from', p_from,
    'to', p_to,
    'summary', jsonb_build_object(
      'assigned_count', (
        SELECT COUNT(*) FROM fx_remittances r
        WHERE r.payout_agent_party_id = p_agent_party_id
          AND fx_same_branch(r.branch_id)
          AND COALESCE(r.booked_at, r.created_at)::DATE BETWEEN p_from AND p_to
      ),
      'assigned_payout_amount', COALESCE((
        SELECT SUM(r.payout_amount) FROM fx_remittances r
        WHERE r.payout_agent_party_id = p_agent_party_id
          AND fx_same_branch(r.branch_id)
          AND COALESCE(r.booked_at, r.created_at)::DATE BETWEEN p_from AND p_to
      ), 0),
      'payouts_completed_count', (
        SELECT COUNT(*) FROM fx_remittances r
        WHERE r.payout_agent_party_id = p_agent_party_id
          AND fx_same_branch(r.branch_id)
          AND r.status IN ('paid_out', 'completed')
          AND COALESCE(r.payout_confirmed_at, r.updated_at)::DATE BETWEEN p_from AND p_to
      ),
      'payouts_completed_amount', COALESCE((
        SELECT SUM(r.payout_amount) FROM fx_remittances r
        WHERE r.payout_agent_party_id = p_agent_party_id
          AND fx_same_branch(r.branch_id)
          AND r.status IN ('paid_out', 'completed')
          AND COALESCE(r.payout_confirmed_at, r.updated_at)::DATE BETWEEN p_from AND p_to
      ), 0),
      'settlement_pending_count', (
        SELECT COUNT(*) FROM fx_remittances r
        WHERE r.payout_agent_party_id = p_agent_party_id
          AND fx_same_branch(r.branch_id)
          AND r.status IN ('paid_out', 'completed')
          AND r.settlement_status <> 'settled'
      ),
      'settlement_pending_amount', COALESCE((
        SELECT SUM(r.payout_amount) FROM fx_remittances r
        WHERE r.payout_agent_party_id = p_agent_party_id
          AND fx_same_branch(r.branch_id)
          AND r.status IN ('paid_out', 'completed')
          AND r.settlement_status <> 'settled'
      ), 0),
      'settled_amount', COALESCE((
        SELECT SUM(e.amount)
        FROM fx_remittance_events e
        JOIN fx_remittances r ON r.id = e.remittance_id
        WHERE r.payout_agent_party_id = p_agent_party_id
          AND fx_same_branch(r.branch_id)
          AND e.event_type = 'agent_settlement'
          AND e.created_at::DATE BETWEEN p_from AND p_to
      ), 0),
      'balance', v_balance
    ),
    'remittances', v_remittances
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_remittance_customer_statement
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_remittance_customer_statement(
  p_party_id UUID,
  p_from DATE DEFAULT date_trunc('month', CURRENT_DATE)::DATE,
  p_to DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_party_name TEXT;
  v_remittances JSONB;
  v_receipts JSONB;
BEGIN
  IF NOT fx_has_permission('can_view_remittance_reports') AND NOT fx_has_permission('can_manage_remittance') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM fx_remittances r
    WHERE r.sender_party_id = p_party_id
      AND fx_same_branch(r.branch_id)
  ) THEN
    RAISE EXCEPTION 'Unauthorized party access';
  END IF;

  SELECT name INTO v_party_name FROM fx_parties WHERE id = p_party_id;

  SELECT COALESCE(jsonb_agg(row_to_json(x)::JSONB ORDER BY x.created_at DESC), '[]'::JSONB)
  INTO v_remittances
  FROM (
    SELECT
      r.id,
      r.remittance_no,
      r.tracking_id,
      r.receiver_name,
      r.receiver_phone,
      r.receiver_city,
      r.receiver_country,
      r.receive_currency,
      r.receive_amount,
      r.payout_currency,
      r.payout_amount,
      r.commission_amount,
      r.total_payable,
      r.paid_amount,
      r.status,
      r.booked_at,
      r.completed_at,
      r.created_at,
      b.name AS branch_name,
      ap.name AS payout_agent_name
    FROM fx_remittances r
    JOIN fx_branches b ON b.id = r.branch_id
    LEFT JOIN fx_parties ap ON ap.id = r.payout_agent_party_id
    WHERE r.sender_party_id = p_party_id
      AND fx_same_branch(r.branch_id)
      AND COALESCE(r.booked_at, r.created_at)::DATE BETWEEN p_from AND p_to
  ) x;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'remittance_id', rt.remittance_id,
    'transaction_id', rt.transaction_id,
    'purpose', rt.purpose,
    'amount', e.amount,
    'currency_code', e.currency_code,
    'paid_at', e.created_at,
    'tracking_id', r.tracking_id,
    'remittance_no', r.remittance_no
  ) ORDER BY e.created_at DESC), '[]'::JSONB)
  INTO v_receipts
  FROM fx_remittance_transactions rt
  JOIN fx_remittances r ON r.id = rt.remittance_id
  JOIN fx_remittance_events e ON e.remittance_id = rt.remittance_id
    AND e.linked_transaction_id = rt.transaction_id
    AND e.event_type = 'customer_payment'
  WHERE r.sender_party_id = p_party_id
    AND fx_same_branch(r.branch_id)
    AND rt.purpose = 'customer_payment'
    AND e.created_at::DATE BETWEEN p_from AND p_to;

  RETURN jsonb_build_object(
    'party_id', p_party_id,
    'party_name', v_party_name,
    'from', p_from,
    'to', p_to,
    'summary', jsonb_build_object(
      'remittance_count', jsonb_array_length(v_remittances),
      'total_sent', COALESCE((
        SELECT SUM(r.receive_amount) FROM fx_remittances r
        WHERE r.sender_party_id = p_party_id
          AND fx_same_branch(r.branch_id)
          AND COALESCE(r.booked_at, r.created_at)::DATE BETWEEN p_from AND p_to
      ), 0),
      'total_paid', COALESCE((
        SELECT SUM(r.paid_amount) FROM fx_remittances r
        WHERE r.sender_party_id = p_party_id
          AND fx_same_branch(r.branch_id)
          AND COALESCE(r.booked_at, r.created_at)::DATE BETWEEN p_from AND p_to
      ), 0),
      'total_commission', COALESCE((
        SELECT SUM(r.commission_amount) FROM fx_remittances r
        WHERE r.sender_party_id = p_party_id
          AND fx_same_branch(r.branch_id)
          AND COALESCE(r.booked_at, r.created_at)::DATE BETWEEN p_from AND p_to
      ), 0),
      'open_count', (
        SELECT COUNT(*) FROM fx_remittances r
        WHERE r.sender_party_id = p_party_id
          AND fx_same_branch(r.branch_id)
          AND r.status NOT IN ('completed', 'cancelled', 'refunded')
      )
    ),
    'remittances', v_remittances,
    'receipts', v_receipts
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- fx_remittance_branch_statement
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_remittance_branch_statement(
  p_branch_id UUID,
  p_from DATE DEFAULT date_trunc('month', CURRENT_DATE)::DATE,
  p_to DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_branch_name TEXT;
  v_company UUID;
  v_liability UUID;
  v_commission UUID;
BEGIN
  IF NOT fx_has_permission('can_view_remittance_reports') AND NOT fx_has_permission('can_manage_remittance') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  SELECT name, company_id INTO v_branch_name, v_company FROM fx_branches WHERE id = p_branch_id;
  v_liability := fx_account_id_by_code(v_company, '2350');
  v_commission := fx_account_id_by_code(v_company, '4310');

  RETURN jsonb_build_object(
    'branch_id', p_branch_id,
    'branch_name', v_branch_name,
    'from', p_from,
    'to', p_to,
    'summary', jsonb_build_object(
      'collections', COALESCE((
        SELECT SUM(e.amount)
        FROM fx_remittance_events e
        JOIN fx_remittances r ON r.id = e.remittance_id
        WHERE r.branch_id = p_branch_id
          AND e.event_type = 'customer_payment'
          AND e.created_at::DATE BETWEEN p_from AND p_to
      ), 0),
      'commission', COALESCE((
        SELECT SUM(jl.credit_pkr - jl.debit_pkr)
        FROM fx_journal_lines jl
        JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
        JOIN fx_transactions t ON t.id = je.source_transaction_id
        WHERE je.branch_id = p_branch_id
          AND NOT je.is_void
          AND je.entry_date BETWEEN p_from AND p_to
          AND jl.account_id = v_commission
          AND t.remittance_id IS NOT NULL
      ), 0),
      'pending_payouts_count', (
        SELECT COUNT(*) FROM fx_remittances r
        WHERE r.branch_id = p_branch_id
          AND r.status IN ('sent_to_agent', 'ready_for_payout')
      ),
      'pending_payouts_amount', COALESCE((
        SELECT SUM(r.payout_amount) FROM fx_remittances r
        WHERE r.branch_id = p_branch_id
          AND r.status IN ('sent_to_agent', 'ready_for_payout')
      ), 0),
      'paid_out_count', (
        SELECT COUNT(*) FROM fx_remittances r
        WHERE r.branch_id = p_branch_id
          AND r.status IN ('paid_out', 'completed')
          AND COALESCE(r.payout_confirmed_at, r.updated_at)::DATE BETWEEN p_from AND p_to
      ),
      'paid_out_amount', COALESCE((
        SELECT SUM(r.payout_amount) FROM fx_remittances r
        WHERE r.branch_id = p_branch_id
          AND r.status IN ('paid_out', 'completed')
          AND COALESCE(r.payout_confirmed_at, r.updated_at)::DATE BETWEEN p_from AND p_to
      ), 0),
      'pending_liability', COALESCE((
        SELECT SUM(jl.credit_pkr - jl.debit_pkr)
        FROM fx_journal_lines jl
        JOIN fx_journal_entries je ON je.id = jl.journal_entry_id
        WHERE je.branch_id = p_branch_id
          AND NOT je.is_void
          AND je.entry_date <= p_to
          AND jl.account_id = v_liability
      ), 0),
      'remittance_count', (
        SELECT COUNT(*) FROM fx_remittances r
        WHERE r.branch_id = p_branch_id
          AND COALESCE(r.booked_at, r.created_at)::DATE BETWEEN p_from AND p_to
      ),
      'completed_count', (
        SELECT COUNT(*) FROM fx_remittances r
        WHERE r.branch_id = p_branch_id
          AND r.status = 'completed'
          AND COALESCE(r.completed_at, r.updated_at)::DATE BETWEEN p_from AND p_to
      )
    ),
    'daily_collections', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'date', d.day,
        'collections', d.collections,
        'commission', d.commission,
        'payouts', d.payouts
      ) ORDER BY d.day)
      FROM (
        SELECT
          e.created_at::DATE AS day,
          SUM(CASE WHEN e.event_type = 'customer_payment' THEN e.amount ELSE 0 END) AS collections,
          0::NUMERIC AS commission,
          SUM(CASE WHEN e.event_type = 'payout_confirmed' THEN e.amount ELSE 0 END) AS payouts
        FROM fx_remittance_events e
        JOIN fx_remittances r ON r.id = e.remittance_id
        WHERE r.branch_id = p_branch_id
          AND e.created_at::DATE BETWEEN p_from AND p_to
          AND e.event_type IN ('customer_payment', 'payout_confirmed')
        GROUP BY e.created_at::DATE
      ) d
    ), '[]'::JSONB)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION fx_remittance_cash_flow_summary(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_remittance_agent_statement(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_remittance_customer_statement(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_remittance_branch_statement(UUID, DATE, DATE) TO authenticated;

NOTIFY pgrst, 'reload schema';
-- <<<<< END 202606250004_fx_remittance_reports_h7.sql

-- >>>>> BEGIN 202606250005_fx_remittance_agent_detail_access.sql
-- Agent cross-branch read access for detail + timeline

CREATE OR REPLACE FUNCTION fx_get_agent_remittance_detail(p_remittance_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_party UUID;
  v_result JSONB;
BEGIN
  IF NOT fx_has_permission('can_agent_remittance') THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT linked_party_id INTO v_party FROM fx_users_profiles WHERE id = auth.uid();
  IF v_party IS NULL THEN RAISE EXCEPTION 'No agent party linked'; END IF;

  SELECT jsonb_build_object(
    'id', r.id, 'remittance_no', r.remittance_no, 'tracking_id', r.tracking_id,
    'sender_party_id', r.sender_party_id, 'sender_name', sp.name,
    'receiver_name', r.receiver_name, 'receiver_phone', r.receiver_phone,
    'receiver_city', r.receiver_city, 'receiver_country', r.receiver_country,
    'payout_agent_party_id', r.payout_agent_party_id, 'payout_agent_name', ap.name,
    'branch_id', r.branch_id, 'branch_name', b.name,
    'receive_currency', r.receive_currency, 'receive_amount', r.receive_amount,
    'payout_currency', r.payout_currency, 'payout_amount', r.payout_amount,
    'exchange_rate', r.exchange_rate, 'commission_amount', r.commission_amount,
    'commission_mode', r.commission_mode, 'total_payable', r.total_payable,
    'paid_amount', r.paid_amount, 'balance_due', GREATEST(0, r.total_payable - r.paid_amount),
    'status', r.status, 'payout_status', r.payout_status, 'settlement_status', r.settlement_status,
    'payout_code', r.payout_code, 'payout_method', r.payout_method,
    'payout_confirmed_at', r.payout_confirmed_at, 'notes', r.notes,
    'booked_at', r.booked_at, 'completed_at', r.completed_at,
    'created_by_name', cp.full_name, 'created_at', r.created_at, 'updated_at', r.updated_at
  ) INTO v_result
  FROM fx_remittances r
  JOIN fx_branches b ON b.id = r.branch_id
  JOIN fx_parties sp ON sp.id = r.sender_party_id
  LEFT JOIN fx_parties ap ON ap.id = r.payout_agent_party_id
  LEFT JOIN fx_users_profiles cp ON cp.id = r.created_by
  WHERE r.id = p_remittance_id AND r.payout_agent_party_id = v_party;

  IF v_result IS NULL THEN RAISE EXCEPTION 'Remittance not found or not assigned to you'; END IF;
  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_get_agent_remittance_detail(UUID) TO authenticated;
NOTIFY pgrst, 'reload schema';
-- <<<<< END 202606250005_fx_remittance_agent_detail_access.sql

-- >>>>> BEGIN 202606260001_fx_messaging_rls_recursion_fix.sql
-- Fix infinite RLS recursion between fx_conversations and fx_conversation_members (42P17)
-- Project: ygidlcqhupmxvsdjmvnf only

-- ---------------------------------------------------------------------------
-- SECURITY DEFINER helpers (bypass RLS for internal membership / branch checks)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_is_conversation_member(
  p_conversation_id UUID,
  p_user_id UUID DEFAULT auth.uid()
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM fx_conversation_members m
    WHERE m.conversation_id = p_conversation_id
      AND m.user_id = p_user_id
  );
$$;

CREATE OR REPLACE FUNCTION fx_conversation_branch_id(p_conversation_id UUID)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.branch_id
  FROM fx_conversations c
  WHERE c.id = p_conversation_id
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION fx_is_conversation_member(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_conversation_branch_id(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- Replace circular policies
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS fx_conversations_select ON fx_conversations;
CREATE POLICY fx_conversations_select ON fx_conversations
  FOR SELECT TO authenticated
  USING (
    fx_same_branch(branch_id)
    AND (
      fx_has_permission('can_manage_messaging')
      OR fx_is_conversation_member(id)
    )
  );

DROP POLICY IF EXISTS fx_conversation_members_select ON fx_conversation_members;
CREATE POLICY fx_conversation_members_select ON fx_conversation_members
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR (
      fx_has_permission('can_manage_messaging')
      AND fx_same_branch(fx_conversation_branch_id(conversation_id))
    )
  );

DROP POLICY IF EXISTS fx_messages_select ON fx_messages;
CREATE POLICY fx_messages_select ON fx_messages
  FOR SELECT TO authenticated
  USING (
    fx_is_conversation_member(conversation_id)
    AND fx_same_branch(fx_conversation_branch_id(conversation_id))
  );

DROP POLICY IF EXISTS fx_messages_insert ON fx_messages;
CREATE POLICY fx_messages_insert ON fx_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND fx_is_conversation_member(conversation_id)
    AND fx_same_branch(fx_conversation_branch_id(conversation_id))
  );
-- <<<<< END 202606260001_fx_messaging_rls_recursion_fix.sql
