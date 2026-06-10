-- =============================================================================
-- FX Cash Ledger — Party Statement demo seed (MANUAL ONLY)
-- =============================================================================
-- Project: ygidlcqhupmxvsdjmvnf (Supabase Cloud ONLY)
-- Do NOT run against supabase.dincouture.pk or old ERP VPS.
-- Do NOT auto-run via migrations — execute manually in SQL Editor when approved.
--
-- Purpose: Ensure agent party WALI TT exists for statement UI testing.
-- Transactions must be created via the Flutter app (balanced posting) to keep
-- trial balance correct. This script only upserts the party record.
-- =============================================================================

-- Verify company (FXDEV seed)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM fx_companies WHERE code = 'FXDEV'
  ) THEN
    RAISE EXCEPTION 'Expected FXDEV company. Apply foundation migrations first.';
  END IF;
END $$;

-- Upsert WALI TT agent party (idempotent by company + code)
INSERT INTO fx_parties (company_id, branch_id, party_type, code, name, phone, is_active)
SELECT
  c.id,
  '00000000-0000-4000-8000-000000000002'::uuid,
  'agent'::fx_party_type,
  'WALI_TT',
  'WALI TT',
  NULL,
  true
FROM fx_companies c
WHERE c.code = 'FXDEV'
ON CONFLICT (company_id, code) DO UPDATE
SET name = EXCLUDED.name, updated_at = NOW();

-- =============================================================================
-- Manual demo steps (Flutter app — keeps ledger balanced):
-- =============================================================================
-- 1. Parties → WALI TT → Statement
-- 2. New Deal → Currency Buy → On credit → 500 USD @ rate → Post
-- 3. Send Payment → Settlement Send → partial PKR → Post
-- 4. Receive Payment → Settlement Receive → optional → Post
-- 5. Verify statement shows Dr/Cr columns and running balance
--
-- Re-run verify_posting_smoke.sql after posting to confirm trial balance.
-- =============================================================================

SELECT id, code, name, party_type
FROM fx_parties
WHERE code = 'WALI_TT';
