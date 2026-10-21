-- Fail on unexpected existing foundation definitions before applying G.
-- Does not alter objects; raises if required columns/types are missing.

DO $guard$
DECLARE
  v_missing TEXT := '';
BEGIN
  IF to_regclass('public.fx_currencies') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='fx_currencies' AND column_name='id'
        AND data_type='uuid'
    ) THEN
      v_missing := v_missing || ' fx_currencies.id(uuid)';
    END IF;
  END IF;

  IF to_regclass('public.fx_companies') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='fx_companies' AND column_name='id'
        AND data_type='uuid'
    ) THEN
      v_missing := v_missing || ' fx_companies.id(uuid)';
    END IF;
  END IF;

  IF v_missing <> '' THEN
    RAISE EXCEPTION 'BLOCKED unexpected foundation shape:% — refuse silent IF NOT EXISTS skip', v_missing;
  END IF;
END
$guard$;
