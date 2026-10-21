-- Bootstrap a single verified FX user membership (not all ERP users).
-- Activation: fx_reconciliation.confirm = APPLY_FX_USER_BOOTSTRAP
-- Requires: p_email set via set_config('fx_bootstrap.email', '...', false)

DO $guard$
BEGIN
  IF current_setting('fx_reconciliation.confirm', true) IS DISTINCT FROM 'APPLY_FX_USER_BOOTSTRAP' THEN
    RAISE EXCEPTION 'BLOCKED: set fx_reconciliation.confirm=APPLY_FX_USER_BOOTSTRAP';
  END IF;
  IF NULLIF(current_setting('fx_bootstrap.email', true), '') IS NULL THEN
    RAISE EXCEPTION 'BLOCKED: set fx_bootstrap.email to the verified user email';
  END IF;
END
$guard$;

DO $$
DECLARE
  v_email TEXT := lower(trim(current_setting('fx_bootstrap.email', true)));
  v_uid UUID;
  v_company UUID;
  v_branch UUID;
  v_role UUID;
  v_matches INT;
BEGIN
  SELECT COUNT(*) INTO v_matches FROM auth.users WHERE lower(email) = v_email;
  IF v_matches <> 1 THEN
    RAISE EXCEPTION 'BLOCKED: email % matches % auth.users rows (need exactly 1)', v_email, v_matches;
  END IF;
  SELECT id INTO v_uid FROM auth.users WHERE lower(email) = v_email;

  SELECT id INTO v_company FROM fx_companies ORDER BY created_at LIMIT 1;
  IF v_company IS NULL THEN RAISE EXCEPTION 'No fx_companies row'; END IF;
  SELECT id INTO v_branch FROM fx_branches WHERE company_id = v_company ORDER BY created_at LIMIT 1;
  IF v_branch IS NULL THEN RAISE EXCEPTION 'No fx_branches row'; END IF;

  INSERT INTO fx_roles (company_id, name, permissions)
  VALUES (
    v_company,
    'admin',
    ARRAY[
      'can_access_fx_ledger','can_manage_fx_rates','can_post_fx_transaction',
      'can_edit_fx_transaction','can_delete_fx_transaction','can_view_fx_reports',
      'can_view_fx_audit','can_manage_chart_of_accounts','can_close_day',
      'can_manage_remittance','can_upload_fx_attachment','can_delete_fx_attachment'
    ]
  )
  ON CONFLICT (company_id, name) DO UPDATE SET permissions = EXCLUDED.permissions
  RETURNING id INTO v_role;
  IF v_role IS NULL THEN
    SELECT id INTO v_role FROM fx_roles WHERE company_id = v_company AND name = 'admin';
  END IF;

  INSERT INTO fx_users_profiles (id, company_id, branch_id, full_name, email, is_active)
  VALUES (v_uid, v_company, v_branch, split_part(v_email, '@', 1), v_email, true)
  ON CONFLICT (id) DO UPDATE SET
    company_id = EXCLUDED.company_id,
    branch_id = EXCLUDED.branch_id,
    email = EXCLUDED.email,
    is_active = true,
    updated_at = NOW();

  INSERT INTO fx_user_roles (user_id, role_id)
  VALUES (v_uid, v_role)
  ON CONFLICT DO NOTHING;

  RAISE NOTICE 'Bootstrapped FX admin uid=% email=% company=% branch=%', v_uid, v_email, v_company, v_branch;
END $$;
