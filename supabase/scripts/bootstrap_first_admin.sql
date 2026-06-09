-- FX Cash Ledger — Bootstrap first admin user
-- Run in Supabase Dashboard → SQL Editor (project ygidlcqhupmxvsdjmvnf)
-- NOT for old ERP VPS / supabase.dincouture.pk
--
-- Steps:
--   1. Sign up in the Flutter app once (creates auth.users row).
--   2. Copy your User UID from Authentication → Users (or from the app setup screen).
--   3. Replace YOUR_AUTH_USER_UUID_HERE below (both occurrences).
--   4. Run this script.

DO $$
DECLARE
  v_user_id_text TEXT := 'YOUR_AUTH_USER_UUID_HERE';  -- ← paste auth.users.id here
  v_user_id UUID;
  v_company_id UUID := '00000000-0000-4000-8000-000000000001';  -- FXDEV
  v_branch_id UUID := '00000000-0000-4000-8000-000000000002';   -- MAIN
  v_admin_role_id UUID := '00000000-0000-4000-8000-000000000010';
  v_email TEXT;
BEGIN
  IF v_user_id_text = 'YOUR_AUTH_USER_UUID_HERE' THEN
    RAISE EXCEPTION 'Replace YOUR_AUTH_USER_UUID_HERE with your auth.users.id';
  END IF;

  v_user_id := v_user_id_text::uuid;

  SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;
  IF v_email IS NULL THEN
    RAISE EXCEPTION 'No auth.users row for id %. Sign up in the app first.', v_user_id;
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

-- Verification queries (replace UUID before running)
-- SELECT * FROM fx_users_profiles WHERE id = 'YOUR_AUTH_USER_UUID_HERE';
-- SELECT r.name FROM fx_user_roles ur JOIN fx_roles r ON r.id = ur.role_id WHERE ur.user_id = 'YOUR_AUTH_USER_UUID_HERE';
