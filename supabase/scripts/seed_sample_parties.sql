-- Sample parties for settlement testing (idempotent by code)
-- Replace company_id with your seed company UUID if different.

INSERT INTO fx_parties (company_id, branch_id, party_type, code, name, phone, is_active)
SELECT
  c.id,
  '00000000-0000-4000-8000-000000000002'::uuid,
  v.party_type::fx_party_type,
  v.code,
  v.name,
  v.phone,
  true
FROM fx_companies c
CROSS JOIN (
  VALUES
    ('customer', 'CUST001', 'Walk-in Customer', NULL),
    ('agent', 'AGT001', 'Main Street Agent', '+92-300-0000001'),
    ('settlement', 'SET001', 'Dubai Settlement Partner', NULL)
) AS v(party_type, code, name, phone)
WHERE c.code = 'MAINCO'
ON CONFLICT (company_id, code) DO UPDATE
SET name = EXCLUDED.name, phone = EXCLUDED.phone, updated_at = NOW();
