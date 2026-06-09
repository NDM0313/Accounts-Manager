-- FX Cash Ledger — transactions, journal, version history

CREATE TABLE fx_transactions (
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

CREATE TABLE fx_transaction_lines (
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

CREATE TABLE fx_transaction_versions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id        UUID NOT NULL REFERENCES fx_transactions (id) ON DELETE CASCADE,
  version               INT NOT NULL,
  snapshot              JSONB NOT NULL,
  change_reason         TEXT,
  changed_by            UUID REFERENCES auth.users (id),
  changed_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (transaction_id, version)
);

CREATE TABLE fx_journal_entries (
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

CREATE TABLE fx_journal_lines (
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

CREATE INDEX idx_fx_transactions_branch_date ON fx_transactions (branch_id, transaction_date DESC);
CREATE INDEX idx_fx_transactions_status ON fx_transactions (status) WHERE NOT is_deleted;
CREATE INDEX idx_fx_journal_entries_branch_date ON fx_journal_entries (branch_id, entry_date DESC);
CREATE INDEX idx_fx_journal_lines_account ON fx_journal_lines (account_id);

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
