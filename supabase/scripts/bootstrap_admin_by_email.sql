-- Bootstrap admin by email (SQL Editor safe)
-- Project: ygidlcqhupmxvsdjmvnf only
-- User must exist in auth.users (sign up in app first).

DO $$
DECLARE
  v_email TEXT := 'ndm313@yahoo.com';
  v_user_id UUID;
  v_company_id UUID := '00000000-0000-4000-8000-000000000001';  -- FXDEV
  v_branch_id UUID := '00000000-0000-4000-8000-000000000002';   -- MAIN
  v_admin_role_id UUID := '00000000-0000-4000-8000-000000000010';
BEGIN
  SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No auth user for %. Sign up in the Flutter app first.', v_email;
  END IF;

  INSERT INTO fx_users_profiles (id, company_id, branch_id, full_name, email, is_active)
  VALUES (v_user_id, v_company_id, v_branch_id, 'Admin User', v_email, TRUE)
  ON CONFLICT (id) DO UPDATE SET
    company_id = EXCLUDED.company_id,
    branch_id = EXCLUDED.branch_id,
    email = EXCLUDED.email,
    is_active = TRUE,
    updated_at = NOW();

  INSERT INTO fx_user_roles (user_id, role_id)
  VALUES (v_user_id, v_admin_role_id)
  ON CONFLICT (user_id, role_id) DO NOTHING;

  RAISE NOTICE 'Bootstrap complete for % (%)', v_email, v_user_id;
END $$;

SELECT u.email, p.branch_id, r.name AS role
FROM auth.users u
JOIN fx_users_profiles p ON p.id = u.id
JOIN fx_user_roles ur ON ur.user_id = u.id
JOIN fx_roles r ON r.id = ur.role_id
WHERE u.email = 'ndm313@yahoo.com';
