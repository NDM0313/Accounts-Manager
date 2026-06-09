-- Fix transaction/journal number generation — sequence overflow on ::INT cast
-- Bug: stripping all non-digits from '20260609-00001' → 2026060900001 (> INT max)
-- Project: ygidlcqhupmxvsdjmvnf only

CREATE OR REPLACE FUNCTION fx_generate_transaction_no(p_branch_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prefix TEXT;
  v_seq INT;
BEGIN
  IF NOT fx_same_branch(p_branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch access';
  END IF;

  v_prefix := TO_CHAR(NOW(), 'YYYYMMDD');

  SELECT COALESCE(MAX((regexp_match(transaction_no, '-(\d+)$'))[1]::INT), 0) + 1
  INTO v_seq
  FROM fx_transactions
  WHERE branch_id = p_branch_id
    AND transaction_no LIKE v_prefix || '-%';

  RETURN v_prefix || '-' || LPAD(v_seq::TEXT, 5, '0');
END;
$$;

CREATE OR REPLACE FUNCTION fx_generate_entry_no(p_branch_id UUID)
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

  SELECT COALESCE(MAX((regexp_match(entry_no, '-(\d+)$'))[1]::INT), 0) + 1
  INTO v_seq
  FROM fx_journal_entries
  WHERE branch_id = p_branch_id
    AND entry_no LIKE v_prefix || '-JE-%';

  RETURN v_prefix || '-JE-' || LPAD(v_seq::TEXT, 5, '0');
END;
$$;
