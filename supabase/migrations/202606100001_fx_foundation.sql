-- FX Cash Ledger — foundation tables (isolated fx_* namespace only)
-- Base currency: PKR

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

CREATE TYPE fx_account_type AS ENUM (
  'asset',
  'liability',
  'equity',
  'income',
  'expense',
  'adjustment'
);

CREATE TYPE fx_party_type AS ENUM (
  'customer',
  'agent',
  'settlement'
);

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

CREATE TYPE fx_transaction_status AS ENUM (
  'draft',
  'posted',
  'voided'
);

-- ---------------------------------------------------------------------------
-- Org / access
-- ---------------------------------------------------------------------------

CREATE TABLE fx_companies (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  code          TEXT NOT NULL UNIQUE,
  base_currency_code TEXT NOT NULL DEFAULT 'PKR',
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE fx_branches (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id    UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  name          TEXT NOT NULL,
  code          TEXT NOT NULL,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (company_id, code)
);

CREATE TABLE fx_users_profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  company_id    UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id     UUID NOT NULL REFERENCES fx_branches (id) ON DELETE RESTRICT,
  full_name     TEXT,
  email         TEXT,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE fx_roles (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id    UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  name          TEXT NOT NULL,
  permissions   TEXT[] NOT NULL DEFAULT '{}',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (company_id, name)
);

CREATE TABLE fx_user_roles (
  user_id       UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  role_id       UUID NOT NULL REFERENCES fx_roles (id) ON DELETE CASCADE,
  assigned_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, role_id)
);

-- ---------------------------------------------------------------------------
-- Master data
-- ---------------------------------------------------------------------------

CREATE TABLE fx_currencies (
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

CREATE TABLE fx_rates (
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

CREATE TABLE fx_accounts (
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

CREATE TABLE fx_parties (
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

CREATE INDEX idx_fx_branches_company ON fx_branches (company_id);
CREATE INDEX idx_fx_users_profiles_company_branch ON fx_users_profiles (company_id, branch_id);
CREATE INDEX idx_fx_rates_branch_currency ON fx_rates (branch_id, currency_id, effective_at DESC);
CREATE INDEX idx_fx_accounts_company_type ON fx_accounts (company_id, account_type);
CREATE INDEX idx_fx_parties_company_type ON fx_parties (company_id, party_type);

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
