-- PROPOSAL ONLY — extend fx_attachments for remittance + messaging

ALTER TABLE fx_attachments
  ADD COLUMN IF NOT EXISTS remittance_id UUID REFERENCES fx_remittances (id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS remittance_event_id UUID REFERENCES fx_remittance_events (id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS message_id UUID REFERENCES fx_messages (id) ON DELETE CASCADE;

ALTER TABLE fx_attachments DROP CONSTRAINT IF EXISTS fx_attachments_target_check;
ALTER TABLE fx_attachments ADD CONSTRAINT fx_attachments_target_check CHECK (
  transaction_id IS NOT NULL
  OR deal_id IS NOT NULL
  OR remittance_id IS NOT NULL
  OR message_id IS NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_fx_attachments_remittance ON fx_attachments (remittance_id);
CREATE INDEX IF NOT EXISTS idx_fx_attachments_message ON fx_attachments (message_id);

-- Extend select policy (mirror deal pattern)
DROP POLICY IF EXISTS fx_attachments_select ON fx_attachments;
CREATE POLICY fx_attachments_select ON fx_attachments
  FOR SELECT TO authenticated
  USING (
    (transaction_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM fx_transactions t
      WHERE t.id = transaction_id AND fx_same_branch(t.branch_id)
    ))
    OR (deal_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id)
    ))
    OR (remittance_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM fx_remittances r WHERE r.id = remittance_id AND fx_same_branch(r.branch_id)
    ))
    OR (message_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM fx_messages msg
      JOIN fx_conversations c ON c.id = msg.conversation_id
      WHERE msg.id = message_id AND fx_same_branch(c.branch_id)
    ))
  );

DROP POLICY IF EXISTS fx_attachments_insert ON fx_attachments;
CREATE POLICY fx_attachments_insert ON fx_attachments
  FOR INSERT TO authenticated
  WITH CHECK (
    (transaction_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM fx_transactions t
      WHERE t.id = transaction_id AND fx_same_branch(t.branch_id)
    ))
    OR (deal_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM fx_deals d WHERE d.id = deal_id AND fx_same_branch(d.branch_id)
    ))
    OR (remittance_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM fx_remittances r WHERE r.id = remittance_id AND fx_same_branch(r.branch_id)
    ))
    OR (message_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM fx_messages msg
      JOIN fx_conversations c ON c.id = msg.conversation_id
      WHERE msg.id = message_id AND fx_same_branch(c.branch_id)
    ))
  );
