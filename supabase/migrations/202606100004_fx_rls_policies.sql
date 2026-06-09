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
