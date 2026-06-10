-- Per-leg deal attachments — fx_attachments.deal_id / deal_leg_id
-- Project: ygidlcqhupmxvsdjmvnf only

ALTER TABLE fx_attachments
  ADD COLUMN IF NOT EXISTS deal_id UUID REFERENCES fx_deals(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS deal_leg_id UUID REFERENCES fx_deal_legs(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS attachment_type TEXT;

ALTER TABLE fx_attachments ALTER COLUMN transaction_id DROP NOT NULL;

ALTER TABLE fx_attachments DROP CONSTRAINT IF EXISTS fx_attachments_target_check;
ALTER TABLE fx_attachments ADD CONSTRAINT fx_attachments_target_check
  CHECK (transaction_id IS NOT NULL OR deal_leg_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_fx_attachments_deal_leg ON fx_attachments(deal_leg_id);
CREATE INDEX IF NOT EXISTS idx_fx_attachments_deal ON fx_attachments(deal_id);

-- RLS: extend select/insert for deal-leg attachments
DROP POLICY IF EXISTS fx_attachments_select ON fx_attachments;
CREATE POLICY fx_attachments_select ON fx_attachments
  FOR SELECT TO authenticated
  USING (
    fx_has_permission('can_access_fx_ledger')
    AND (
      (transaction_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_transactions t
        WHERE t.id = transaction_id AND fx_same_branch(t.branch_id)
      ))
      OR (deal_leg_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_deal_legs l
        JOIN fx_deals d ON d.id = l.deal_id
        WHERE l.id = deal_leg_id AND fx_same_branch(d.branch_id)
      ))
    )
  );

DROP POLICY IF EXISTS fx_attachments_insert ON fx_attachments;
CREATE POLICY fx_attachments_insert ON fx_attachments
  FOR INSERT TO authenticated
  WITH CHECK (
    fx_has_permission('can_access_fx_ledger')
    AND (
      (transaction_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_transactions t
        WHERE t.id = transaction_id AND fx_same_branch(t.branch_id)
      ))
      OR (deal_leg_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_deal_legs l
        JOIN fx_deals d ON d.id = l.deal_id
        WHERE l.id = deal_leg_id AND fx_same_branch(d.branch_id)
      ))
    )
  );

DROP POLICY IF EXISTS fx_attachments_delete ON fx_attachments;
CREATE POLICY fx_attachments_delete ON fx_attachments
  FOR DELETE TO authenticated
  USING (
    fx_has_permission('can_access_fx_ledger')
    AND (
      (transaction_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_transactions t
        WHERE t.id = transaction_id AND fx_same_branch(t.branch_id)
      ))
      OR (deal_leg_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_deal_legs l
        JOIN fx_deals d ON d.id = l.deal_id
        WHERE l.id = deal_leg_id AND fx_same_branch(d.branch_id)
      ))
    )
  );

-- Timeline: attachment count per leg (drop required — return type change)
DROP FUNCTION IF EXISTS public.fx_get_deal_timeline(UUID);

CREATE OR REPLACE FUNCTION fx_get_deal_timeline(p_deal_id UUID)
RETURNS TABLE (
  leg_id UUID,
  leg_no INT,
  leg_type fx_deal_leg_type,
  leg_status fx_deal_leg_status,
  counterparty_name TEXT,
  receive_currency TEXT,
  receive_amount NUMERIC,
  pay_currency TEXT,
  pay_amount NUMERIC,
  paid_amount NUMERIC,
  remaining_amount NUMERIC,
  proof_reference TEXT,
  notes TEXT,
  linked_transaction_no TEXT,
  created_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  attachment_count BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deal fx_deals;
BEGIN
  SELECT * INTO v_deal FROM fx_deals WHERE id = p_deal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deal not found'; END IF;
  IF NOT fx_same_branch(v_deal.branch_id) THEN RAISE EXCEPTION 'Unauthorized branch access'; END IF;

  RETURN QUERY
  SELECT
    l.id, l.leg_no, l.leg_type, l.status,
    p.name,
    l.receive_currency, l.receive_amount,
    l.pay_currency, l.pay_amount,
    l.paid_amount, l.remaining_amount,
    l.proof_reference, l.notes,
    t.transaction_no,
    l.created_at, l.completed_at,
    (SELECT COUNT(*) FROM fx_attachments a WHERE a.deal_leg_id = l.id)::BIGINT
  FROM fx_deal_legs l
  LEFT JOIN fx_parties p ON p.id = l.counterparty_party_id
  LEFT JOIN fx_transactions t ON t.id = l.linked_transaction_id
  WHERE l.deal_id = p_deal_id
  ORDER BY l.leg_no;
END;
$$;

GRANT EXECUTE ON FUNCTION fx_get_deal_timeline(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
