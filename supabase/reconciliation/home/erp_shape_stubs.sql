-- Minimal ERP-owned object shapes for disposable validation (no business data).
-- Mirrors existence of home ERP purchase tables without importing production rows.

CREATE TABLE IF NOT EXISTS fx_currency_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID,
  purchase_date DATE,
  currency_code TEXT,
  amount NUMERIC(20,8),
  rate_pkr NUMERIC(20,8),
  total_pkr NUMERIC(20,8),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fx_currency_purchase_settlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_id UUID REFERENCES fx_currency_purchases(id),
  settled_amount_pkr NUMERIC(20,8),
  settled_at TIMESTAMPTZ DEFAULT NOW()
);

-- Marker views/functions ERP may expose (shape only)
CREATE OR REPLACE FUNCTION import_fx_noop_stub()
RETURNS VOID LANGUAGE sql AS $$ SELECT NULL; $$;
