-- Fix deal number generation — sequence overflow on ::INT cast
-- Bug: stripping all non-digits from 'DL-20260610-0001' → 202606100001 (> INT max)
-- Same fix pattern as 202606120002 (transaction/journal numbers)
-- Project: ygidlcqhupmxvsdjmvnf only

CREATE OR REPLACE FUNCTION fx_generate_deal_no(p_branch_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prefix TEXT;
  v_seq INT;
BEGIN
  v_prefix := TO_CHAR(NOW(), 'YYYYMMDD');

  SELECT COALESCE(MAX((regexp_match(deal_no, '-(\d+)$'))[1]::INT), 0) + 1
  INTO v_seq
  FROM fx_deals
  WHERE branch_id = p_branch_id
    AND deal_no LIKE 'DL-' || v_prefix || '-%';

  RETURN 'DL-' || v_prefix || '-' || LPAD(v_seq::TEXT, 4, '0');
END;
$$;

GRANT EXECUTE ON FUNCTION fx_generate_deal_no(UUID) TO authenticated;
