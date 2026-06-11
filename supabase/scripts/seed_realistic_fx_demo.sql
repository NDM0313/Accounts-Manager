-- =============================================================================
-- FX Cash Ledger — Realistic demo seed (PARTIES + RATES ONLY)
-- =============================================================================
-- Project: ygidlcqhupmxvsdjmvnf ONLY. FXDEV company. Manual run — NOT auto-applied.
-- Does NOT delete admin user. Does NOT post unbalanced journals.
-- Idempotent party/rate upserts. Posting via Flutter wizard or fx_seed_fxdev_demo RPC.
-- See doc/DEMO_SEED_DRY_RUN.md
-- =============================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM fx_companies WHERE code = 'FXDEV') THEN
    RAISE EXCEPTION 'ABORT: FXDEV company not found';
  END IF;
END $$;

INSERT INTO fx_parties (company_id, branch_id, party_type, code, name, is_active)
SELECT c.id, b.id, 'customer', v.code, v.name, true
FROM fx_companies c
JOIN fx_branches b ON b.company_id = c.id AND b.code = 'MAIN'
CROSS JOIN (VALUES
  ('DEMO_ASAD', 'ASAD TRADERS'),
  ('DEMO_DIN', 'DIN IMPORTS'),
  ('DEMO_KHAN', 'KHAN GARMENTS'),
  ('DEMO_WALKIN', 'WALK-IN CUSTOMER')
) AS v(code, name)
WHERE c.code = 'FXDEV'
ON CONFLICT (company_id, code) DO UPDATE SET name = EXCLUDED.name, updated_at = NOW();

INSERT INTO fx_parties (company_id, branch_id, party_type, code, name, is_active)
SELECT c.id, b.id, 'agent', v.code, v.name, true
FROM fx_companies c
JOIN fx_branches b ON b.company_id = c.id AND b.code = 'MAIN'
CROSS JOIN (VALUES
  ('DEMO_WALI', 'WALI TT'),
  ('DEMO_DUBAI_AED', 'Dubai AED Agent'),
  ('DEMO_CHINA_RMB', 'China RMB Agent'),
  ('DEMO_KABUL_AFN', 'Kabul AFN Agent')
) AS v(code, name)
WHERE c.code = 'FXDEV'
ON CONFLICT (company_id, code) DO UPDATE SET name = EXCLUDED.name, updated_at = NOW();

-- Demo reference rates (skip if branch already has rate today for currency)
INSERT INTO fx_rates (branch_id, currency_id, buy_rate, sell_rate, mid_rate, effective_at, rate_source, notes)
SELECT b.id, cur.id, r.buy_rate, r.buy_rate + 1, r.buy_rate + 0.5, NOW(), 'demo_seed', 'DEMO reference rate'
FROM fx_companies c
JOIN fx_branches b ON b.company_id = c.id AND b.code = 'MAIN'
JOIN (VALUES
  ('USD', 280.0),
  ('AED', 76.0),
  ('CNY', 39.0),
  ('AFN', 3.2)
) AS r(code, buy_rate) ON true
JOIN fx_currencies cur ON cur.code = r.code
WHERE c.code = 'FXDEV'
  AND NOT EXISTS (
    SELECT 1 FROM fx_rates fr
    WHERE fr.branch_id = b.id AND fr.currency_id = cur.id
      AND fr.effective_at >= CURRENT_DATE
  );

SELECT code, name, party_type FROM fx_parties
WHERE company_id = (SELECT id FROM fx_companies WHERE code = 'FXDEV')
  AND code LIKE 'DEMO_%'
ORDER BY party_type, code;
