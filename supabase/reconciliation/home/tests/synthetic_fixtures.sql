-- Synthetic fixtures ONLY — no production PII.
-- Requires AM schema (G+H) applied. Uses fixed UUIDs for determinism.

SET statement_timeout = '30s';

-- Stub auth.uid if missing (disposable fixture helper — NOT for production)
CREATE SCHEMA IF NOT EXISTS auth;
CREATE TABLE IF NOT EXISTS auth.users (
  id UUID PRIMARY KEY,
  email TEXT
);

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

-- Fixed IDs
-- company 11111111-1111-4111-8111-111111111111
-- branch  22222222-2222-4222-8222-222222222222
-- admin   33333333-3333-4333-8333-333333333333
-- erpuser 44444444-4444-4444-8444-444444444444 (no FX profile)
-- agents  A1/A2, customers C1/C2

INSERT INTO auth.users (id, email) VALUES
  ('33333333-3333-4333-8333-333333333333', 'fx.admin@example.test'),
  ('44444444-4444-4444-8444-444444444444', 'erp.only@example.test')
ON CONFLICT (id) DO NOTHING;

INSERT INTO fx_companies (id, name, code, base_currency_code)
VALUES ('11111111-1111-4111-8111-111111111111', 'Synthetic FX Co', 'SYNTHFX', 'PKR')
ON CONFLICT (id) DO NOTHING;

INSERT INTO fx_branches (id, company_id, name, code)
VALUES ('22222222-2222-4222-8222-222222222222', '11111111-1111-4111-8111-111111111111', 'Main', 'MAIN')
ON CONFLICT (id) DO NOTHING;

INSERT INTO fx_currencies (code, name, symbol, decimal_places, is_base, is_active) VALUES
  ('PKR', 'Pakistani Rupee', 'Rs', 2, true, true),
  ('USD', 'US Dollar', '$', 2, false, true),
  ('AED', 'UAE Dirham', 'د.إ', 2, false, true),
  ('CNY', 'Chinese Yuan', '¥', 2, false, true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO fx_roles (id, company_id, name, permissions)
VALUES (
  '55555555-5555-4555-8555-555555555555',
  '11111111-1111-4111-8111-111111111111',
  'admin',
  ARRAY[
    'can_access_fx_ledger','can_post_fx_transaction','can_manage_remittance',
    'can_upload_fx_attachment','can_delete_fx_attachment'
  ]
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO fx_users_profiles (id, company_id, branch_id, full_name, email, is_active)
VALUES (
  '33333333-3333-4333-8333-333333333333',
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
  'FX Admin', 'fx.admin@example.test', true
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO fx_user_roles (user_id, role_id)
VALUES ('33333333-3333-4333-8333-333333333333', '55555555-5555-4555-8555-555555555555')
ON CONFLICT DO NOTHING;

-- Minimal cash/liability/commission/payable accounts
INSERT INTO fx_accounts (id, company_id, branch_id, code, name, account_type, currency_id)
SELECT 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', c.id, b.id, '1110', 'Cash PKR', 'asset', cur.id
FROM fx_companies c, fx_branches b, fx_currencies cur
WHERE c.id='11111111-1111-4111-8111-111111111111' AND b.id='22222222-2222-4222-8222-222222222222' AND cur.code='PKR'
ON CONFLICT DO NOTHING;

INSERT INTO fx_accounts (company_id, code, name, account_type)
SELECT '11111111-1111-4111-8111-111111111111', x.code, x.name, x.atype::fx_account_type
FROM (VALUES
  ('2100','Agent Payable','liability'),
  ('2350','Remittance Liability','liability'),
  ('4310','Commission Income','income'),
  ('1120','Cash USD','asset'),
  ('1130','Cash AED','asset'),
  ('1140','Cash CNY','asset')
) AS x(code,name,atype)
ON CONFLICT DO NOTHING;

INSERT INTO fx_parties (id, company_id, branch_id, party_type, code, name) VALUES
  ('b1111111-b111-4111-8111-b11111111111','11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','agent','AGENT1','Agent One'),
  ('b2222222-b222-4222-8222-b22222222222','11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','agent','AGENT2','Agent Two'),
  ('c1111111-c111-4111-8111-c11111111111','11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','customer','CUST1','Customer One'),
  ('c2222222-c222-4222-8222-c22222222222','11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','customer','CUST2','Customer Two')
ON CONFLICT DO NOTHING;

-- Agent One holds owned USD/AED/CNY (custody ≠ payable)
INSERT INTO fx_agent_currency_balances (company_id, branch_id, agent_party_id, currency_code, owned_amount, reserved_amount, payable_pkr)
VALUES
  ('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','b1111111-b111-4111-8111-b11111111111','USD',10000,0,0),
  ('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','b1111111-b111-4111-8111-b11111111111','AED',5000,0,0),
  ('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','b1111111-b111-4111-8111-b11111111111','CNY',20000,0,0)
ON CONFLICT DO NOTHING;

-- Session as FX admin for subsequent scenario scripts
SELECT set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', false);
