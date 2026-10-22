-- R_profile_self_select.sql
-- Users must always be able to read their own fx_users_profiles row.
-- fx_same_company(company_id) alone fails when active workspace != profile
-- company (e.g. after manual workspace updates or mid-switch), which the app
-- incorrectly treats as "profile not configured".

DROP POLICY IF EXISTS fx_users_profiles_select_self ON fx_users_profiles;
CREATE POLICY fx_users_profiles_select_self ON fx_users_profiles
  FOR SELECT TO authenticated
  USING (id = auth.uid());

NOTIFY pgrst, 'reload schema';
