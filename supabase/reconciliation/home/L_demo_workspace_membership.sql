-- =============================================================================
-- L) Multi-company membership + active workspace (server-enforced)
-- Activation: set fx_reconciliation.confirm = 'APPLY_DEMO_WORKSPACE'
-- =============================================================================

DO $guard$
BEGIN
  IF current_setting('fx_reconciliation.confirm', true) IS DISTINCT FROM 'APPLY_DEMO_WORKSPACE' THEN
    RAISE EXCEPTION 'BLOCKED: set fx_reconciliation.confirm=APPLY_DEMO_WORKSPACE';
  END IF;
  IF to_regclass('public.fx_companies') IS NULL THEN
    RAISE EXCEPTION 'BLOCKED: fx_companies missing';
  END IF;
END
$guard$;

CREATE TABLE IF NOT EXISTS fx_user_company_memberships (
  user_id     UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  company_id  UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id   UUID NOT NULL REFERENCES fx_branches (id) ON DELETE RESTRICT,
  role_id     UUID NOT NULL REFERENCES fx_roles (id) ON DELETE RESTRICT,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, company_id)
);

CREATE INDEX IF NOT EXISTS idx_fx_memberships_user
  ON fx_user_company_memberships (user_id) WHERE is_active;

ALTER TABLE fx_user_company_memberships ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS fx_memberships_select_own ON fx_user_company_memberships;
CREATE POLICY fx_memberships_select_own ON fx_user_company_memberships
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE TABLE IF NOT EXISTS fx_user_active_workspace (
  user_id     UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  company_id  UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id   UUID NOT NULL REFERENCES fx_branches (id) ON DELETE RESTRICT,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE fx_user_active_workspace ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS fx_active_workspace_select_own ON fx_user_active_workspace;
CREATE POLICY fx_active_workspace_select_own ON fx_user_active_workspace
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());
DROP POLICY IF EXISTS fx_active_workspace_upsert_own ON fx_user_active_workspace;
CREATE POLICY fx_active_workspace_upsert_own ON fx_user_active_workspace
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Backfill: existing profiles become memberships
INSERT INTO fx_user_company_memberships (user_id, company_id, branch_id, role_id, is_active)
SELECT p.id, p.company_id, p.branch_id, ur.role_id, p.is_active
FROM fx_users_profiles p
JOIN fx_user_roles ur ON ur.user_id = p.id
ON CONFLICT (user_id, company_id) DO NOTHING;

INSERT INTO fx_user_active_workspace (user_id, company_id, branch_id)
SELECT p.id, p.company_id, p.branch_id
FROM fx_users_profiles p
ON CONFLICT (user_id) DO NOTHING;

CREATE OR REPLACE FUNCTION fx_current_profile()
RETURNS fx_users_profiles
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_out fx_users_profiles;
  v_ws fx_user_active_workspace;
BEGIN
  -- Narrow demo seed operator (no forged login): profile scoped to seed company/branch
  IF current_setting('fx_seed.active', true) = '1' THEN
    v_out.id := COALESCE(auth.uid(), 'a1111111-1111-4111-8111-111111111199'::uuid);
    v_out.company_id := current_setting('fx_seed.company_id', true)::uuid;
    v_out.branch_id := current_setting('fx_seed.branch_id', true)::uuid;
    v_out.full_name := 'Demo Seed Operator';
    v_out.email := 'fx-demo-seed@ndmcore.local';
    v_out.is_active := TRUE;
    v_out.created_at := NOW();
    v_out.updated_at := NOW();
    v_out.display_currency_code := 'PKR';
    RETURN v_out;
  END IF;

  SELECT * INTO v_out FROM fx_users_profiles WHERE id = auth.uid() AND is_active;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_ws FROM fx_user_active_workspace WHERE user_id = auth.uid();
  IF FOUND THEN
    IF EXISTS (
      SELECT 1 FROM fx_user_company_memberships m
      WHERE m.user_id = auth.uid()
        AND m.company_id = v_ws.company_id
        AND m.branch_id = v_ws.branch_id
        AND m.is_active
    ) THEN
      v_out.company_id := v_ws.company_id;
      v_out.branch_id := v_ws.branch_id;
    END IF;
  END IF;
  RETURN v_out;
END;
$$;

CREATE OR REPLACE FUNCTION fx_same_company(p_company_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    (
      current_setting('fx_seed.active', true) = '1'
      AND current_setting('fx_seed.company_id', true) = p_company_id::text
    )
    OR EXISTS (
      SELECT 1
      FROM fx_user_active_workspace w
      JOIN fx_user_company_memberships m
        ON m.user_id = w.user_id AND m.company_id = w.company_id AND m.is_active
      WHERE w.user_id = auth.uid() AND w.company_id = p_company_id
    )
    OR EXISTS (
      SELECT 1 FROM fx_users_profiles p
      WHERE p.id = auth.uid() AND p.company_id = p_company_id AND p.is_active
        AND NOT EXISTS (SELECT 1 FROM fx_user_active_workspace w WHERE w.user_id = auth.uid())
    );
$$;

CREATE OR REPLACE FUNCTION fx_same_branch(p_branch_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    (
      current_setting('fx_seed.active', true) = '1'
      AND current_setting('fx_seed.branch_id', true) = p_branch_id::text
    )
    OR EXISTS (
      SELECT 1
      FROM fx_user_active_workspace w
      JOIN fx_user_company_memberships m
        ON m.user_id = w.user_id AND m.company_id = w.company_id
       AND m.branch_id = w.branch_id AND m.is_active
      WHERE w.user_id = auth.uid() AND w.branch_id = p_branch_id
    )
    OR EXISTS (
      SELECT 1 FROM fx_users_profiles p
      WHERE p.id = auth.uid() AND p.branch_id = p_branch_id AND p.is_active
        AND NOT EXISTS (SELECT 1 FROM fx_user_active_workspace w WHERE w.user_id = auth.uid())
    );
$$;

CREATE OR REPLACE FUNCTION fx_has_permission(p_permission TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    (current_setting('fx_seed.active', true) = '1')
    OR EXISTS (
      SELECT 1
      FROM fx_user_active_workspace w
      JOIN fx_user_company_memberships m
        ON m.user_id = w.user_id AND m.company_id = w.company_id AND m.is_active
      JOIN fx_roles r ON r.id = m.role_id
      WHERE w.user_id = auth.uid()
        AND p_permission = ANY (r.permissions)
    )
    OR (
      NOT EXISTS (SELECT 1 FROM fx_user_active_workspace w WHERE w.user_id = auth.uid())
      AND EXISTS (
        SELECT 1 FROM fx_user_roles ur
        JOIN fx_roles r ON r.id = ur.role_id
        WHERE ur.user_id = auth.uid() AND p_permission = ANY (r.permissions)
      )
    );
$$;

CREATE OR REPLACE FUNCTION fx_list_my_workspaces()
RETURNS TABLE (
  company_id UUID,
  company_code TEXT,
  company_name TEXT,
  branch_id UUID,
  branch_code TEXT,
  branch_name TEXT,
  is_demo BOOLEAN,
  is_active_workspace BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    c.id, c.code, c.name,
    b.id, b.code, b.name,
    (c.code = 'AM_DEMO'),
    EXISTS (
      SELECT 1 FROM fx_user_active_workspace w
      WHERE w.user_id = auth.uid() AND w.company_id = c.id AND w.branch_id = b.id
    )
  FROM fx_user_company_memberships m
  JOIN fx_companies c ON c.id = m.company_id
  JOIN fx_branches b ON b.id = m.branch_id
  WHERE m.user_id = auth.uid() AND m.is_active
  ORDER BY (c.code = 'AM_DEMO'), c.code;
$$;

CREATE OR REPLACE FUNCTION fx_switch_workspace(p_company_id UUID, p_branch_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_m fx_user_company_memberships;
  v_code TEXT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT * INTO v_m
  FROM fx_user_company_memberships
  WHERE user_id = auth.uid()
    AND company_id = p_company_id
    AND branch_id = p_branch_id
    AND is_active
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No membership for requested workspace';
  END IF;

  INSERT INTO fx_user_active_workspace (user_id, company_id, branch_id, updated_at)
  VALUES (auth.uid(), p_company_id, p_branch_id, NOW())
  ON CONFLICT (user_id) DO UPDATE
    SET company_id = EXCLUDED.company_id,
        branch_id = EXCLUDED.branch_id,
        updated_at = NOW();

  -- Keep legacy profile columns pointing at active workspace for clients that still read the table
  UPDATE fx_users_profiles
  SET company_id = p_company_id, branch_id = p_branch_id, updated_at = NOW()
  WHERE id = auth.uid();

  SELECT code INTO v_code FROM fx_companies WHERE id = p_company_id;
  RETURN jsonb_build_object(
    'company_id', p_company_id,
    'branch_id', p_branch_id,
    'company_code', v_code,
    'is_demo', v_code = 'AM_DEMO'
  );
END;
$$;

REVOKE ALL ON FUNCTION fx_list_my_workspaces() FROM PUBLIC;
REVOKE ALL ON FUNCTION fx_switch_workspace(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_list_my_workspaces() TO authenticated;
GRANT EXECUTE ON FUNCTION fx_switch_workspace(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_current_profile() TO authenticated;
