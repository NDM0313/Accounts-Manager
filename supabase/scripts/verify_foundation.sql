-- Verify seed foundation exists (run anytime in SQL Editor)
-- Project: ygidlcqhupmxvsdjmvnf

SELECT 'company' AS entity, code, name FROM fx_companies;
SELECT 'branch' AS entity, code, name FROM fx_branches;
SELECT 'role' AS entity, name, permissions FROM fx_roles ORDER BY name;
SELECT 'currency' AS entity, code, is_base FROM fx_currencies ORDER BY code;
SELECT 'coa_count' AS entity, COUNT(*)::text AS value FROM fx_accounts;

-- After bootstrap, replace UUID:
-- SELECT 'user_profile' AS entity, id::text, email FROM fx_users_profiles WHERE id = 'YOUR_AUTH_USER_UUID_HERE';
