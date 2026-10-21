-- =============================================================================
-- C) ACCOUNTS-MANAGER PRIVILEGES + RLS — NOT FOR DEFAULT EXECUTION
-- =============================================================================
-- Scope: allowlisted AM ledger tables ONLY.
-- Do NOT touch ERP fx_currency_purchases / settlements policies or grants
-- except to leave them untouched.
--
-- Activation:
--   SELECT set_config('fx_reconciliation.confirm', 'APPLY_AM_RLS_HOME_FX', true);
--
-- Design notes:
-- - RLS enabled without policies denies non-owner client row access.
-- - Table owner (postgres) and bypass roles (e.g. service_role) still need care.
-- - Broad GRANT including TRUNCATE on foundation tables should be narrowed for
--   AM tables; ERP purchase table grants/policies are out of scope here.
-- =============================================================================

DO $$
BEGIN
  IF current_setting('fx_reconciliation.confirm', true) IS DISTINCT FROM 'APPLY_AM_RLS_HOME_FX' THEN
    RAISE EXCEPTION 'BLOCKED: set fx_reconciliation.confirm = APPLY_AM_RLS_HOME_FX';
  END IF;
END $$;

-- Helpers (AM-owned names). search_path pinned. SECURITY DEFINER for profile reads.
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
    WHERE p.id = auth.uid() AND p.company_id = p_company_id AND p.is_active
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
    WHERE p.id = auth.uid() AND p.branch_id = p_branch_id AND p.is_active
  );
$$;

REVOKE ALL ON FUNCTION fx_current_profile() FROM PUBLIC;
REVOKE ALL ON FUNCTION fx_has_permission(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION fx_same_company(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION fx_same_branch(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_current_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION fx_has_permission(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_same_company(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_same_branch(UUID) TO authenticated;

-- Allowlisted AM tables for RLS enable + baseline SELECT policies
-- (full policy set from 202606100004 should be ported after clone test)
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'fx_companies','fx_branches','fx_users_profiles','fx_roles','fx_user_roles',
    'fx_currencies','fx_rates','fx_accounts','fx_parties',
    'fx_transactions','fx_transaction_lines','fx_transaction_versions',
    'fx_journal_entries','fx_journal_lines',
    'fx_daily_closings','fx_closing_lines','fx_attachments','fx_audit_logs'
  ]
  LOOP
    IF to_regclass('public.' || t) IS NULL THEN
      RAISE EXCEPTION 'BLOCKED: missing table % before RLS apply', t;
    END IF;
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;

-- Narrow client privileges on AM foundation + new ledger tables (allowlist).
-- Leave ERP purchase tables unchanged.
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'fx_companies','fx_branches','fx_users_profiles','fx_roles','fx_user_roles',
    'fx_currencies','fx_rates','fx_accounts','fx_parties',
    'fx_transactions','fx_transaction_lines','fx_transaction_versions',
    'fx_journal_entries','fx_journal_lines',
    'fx_daily_closings','fx_closing_lines','fx_attachments','fx_audit_logs'
  ]
  LOOP
    EXECUTE format('REVOKE ALL ON TABLE %I FROM anon', t);
    EXECUTE format(
      'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE %I TO authenticated',
      t
    );
    -- Explicitly no TRUNCATE/TRIGGER/REFERENCES to anon/authenticated
    EXECUTE format('REVOKE TRUNCATE, REFERENCES, TRIGGER ON TABLE %I FROM authenticated', t);
    EXECUTE format('REVOKE ALL ON TABLE %I FROM PUBLIC', t);
  END LOOP;
END $$;

-- Minimal select policies (extend from migration 202606100004 on clone)
DROP POLICY IF EXISTS fx_companies_select ON fx_companies;
CREATE POLICY fx_companies_select ON fx_companies
  FOR SELECT TO authenticated
  USING (fx_same_company(id));

DROP POLICY IF EXISTS fx_branches_select ON fx_branches;
CREATE POLICY fx_branches_select ON fx_branches
  FOR SELECT TO authenticated
  USING (fx_same_company(company_id));

DROP POLICY IF EXISTS fx_users_profiles_select_self ON fx_users_profiles;
CREATE POLICY fx_users_profiles_select_self ON fx_users_profiles
  FOR SELECT TO authenticated
  USING (id = auth.uid() OR fx_same_company(company_id));

-- NOTE: Full CRUD policies + remittance/deals policies must be ported from
-- supabase/migrations/202606100004_fx_rls_policies.sql and later modules
-- after disposable validation. Do not invent blanket fx_% policies.
