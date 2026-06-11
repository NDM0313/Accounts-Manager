-- PROPOSAL ONLY — do not apply without explicit approval.
-- FX Internal messaging module

DO $$ BEGIN
  CREATE TYPE fx_conversation_type AS ENUM (
    'direct', 'deal', 'party', 'transaction', 'company'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE fx_message_type AS ENUM (
    'text', 'image', 'file', 'link', 'voice',
    'deal_ref', 'transaction_ref', 'party_ref', 'system'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS fx_conversations (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id              UUID NOT NULL REFERENCES fx_companies (id) ON DELETE RESTRICT,
  branch_id               UUID NOT NULL REFERENCES fx_branches (id) ON DELETE RESTRICT,
  conversation_type       fx_conversation_type NOT NULL,
  title                   TEXT,
  context_deal_id         UUID REFERENCES fx_deals (id) ON DELETE SET NULL,
  context_party_id        UUID REFERENCES fx_parties (id) ON DELETE SET NULL,
  context_transaction_id  UUID REFERENCES fx_transactions (id) ON DELETE SET NULL,
  last_message_at         TIMESTAMPTZ,
  created_by              UUID REFERENCES auth.users (id),
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fx_conversations_branch ON fx_conversations (branch_id, last_message_at DESC);

CREATE TABLE IF NOT EXISTS fx_conversation_members (
  conversation_id         UUID NOT NULL REFERENCES fx_conversations (id) ON DELETE CASCADE,
  user_id                 UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  role                    TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'admin')),
  last_read_at            TIMESTAMPTZ,
  unread_count            INT NOT NULL DEFAULT 0,
  joined_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS fx_messages (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id         UUID NOT NULL REFERENCES fx_conversations (id) ON DELETE CASCADE,
  sender_id               UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  message_type            fx_message_type NOT NULL DEFAULT 'text',
  body                    TEXT NOT NULL DEFAULT '',
  metadata                JSONB NOT NULL DEFAULT '{}',
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  edited_at               TIMESTAMPTZ,
  deleted_at              TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_fx_messages_conversation ON fx_messages (conversation_id, created_at);

-- RLS
ALTER TABLE fx_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE fx_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fx_conversations_select ON fx_conversations;
CREATE POLICY fx_conversations_select ON fx_conversations
  FOR SELECT TO authenticated
  USING (
    fx_same_branch(branch_id)
    AND (
      fx_has_permission('can_manage_messaging')
      OR EXISTS (
        SELECT 1 FROM fx_conversation_members m
        WHERE m.conversation_id = id AND m.user_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS fx_conversation_members_select ON fx_conversation_members;
CREATE POLICY fx_conversation_members_select ON fx_conversation_members
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM fx_conversations c
      WHERE c.id = conversation_id AND fx_same_branch(c.branch_id)
        AND fx_has_permission('can_manage_messaging')
    )
  );

DROP POLICY IF EXISTS fx_messages_select ON fx_messages;
CREATE POLICY fx_messages_select ON fx_messages
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM fx_conversation_members m
    JOIN fx_conversations c ON c.id = m.conversation_id
    WHERE m.conversation_id = fx_messages.conversation_id
      AND m.user_id = auth.uid()
      AND fx_same_branch(c.branch_id)
  ));

DROP POLICY IF EXISTS fx_messages_insert ON fx_messages;
CREATE POLICY fx_messages_insert ON fx_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM fx_conversation_members m
      JOIN fx_conversations c ON c.id = m.conversation_id
      WHERE m.conversation_id = fx_messages.conversation_id
        AND m.user_id = auth.uid()
        AND fx_same_branch(c.branch_id)
    )
  );

UPDATE fx_roles SET permissions = array_append(permissions, 'can_manage_messaging')
WHERE name = 'admin' AND NOT ('can_manage_messaging' = ANY (permissions));

-- RPCs
CREATE OR REPLACE FUNCTION fx_list_conversations(p_branch_id UUID)
RETURNS TABLE (
  conversation_id UUID,
  conversation_type fx_conversation_type,
  title TEXT,
  last_message_at TIMESTAMPTZ,
  unread_count INT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.id, c.conversation_type, c.title, c.last_message_at, COALESCE(m.unread_count, 0)
  FROM fx_conversations c
  JOIN fx_conversation_members m ON m.conversation_id = c.id AND m.user_id = auth.uid()
  WHERE c.branch_id = p_branch_id AND fx_same_branch(p_branch_id)
  ORDER BY c.last_message_at DESC NULLS LAST;
$$;

CREATE OR REPLACE FUNCTION fx_get_or_create_entity_conversation(
  p_branch_id UUID,
  p_type fx_conversation_type,
  p_context_deal_id UUID DEFAULT NULL,
  p_context_party_id UUID DEFAULT NULL,
  p_context_transaction_id UUID DEFAULT NULL,
  p_title TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile fx_users_profiles;
  v_id UUID;
BEGIN
  SELECT * INTO v_profile FROM fx_current_profile();
  IF v_profile.branch_id <> p_branch_id THEN RAISE EXCEPTION 'Unauthorized branch'; END IF;

  SELECT c.id INTO v_id FROM fx_conversations c
  WHERE c.branch_id = p_branch_id
    AND c.conversation_type = p_type
    AND (p_context_deal_id IS NULL OR c.context_deal_id = p_context_deal_id)
    AND (p_context_party_id IS NULL OR c.context_party_id = p_context_party_id)
    AND (p_context_transaction_id IS NULL OR c.context_transaction_id = p_context_transaction_id)
  LIMIT 1;

  IF v_id IS NOT NULL THEN RETURN v_id; END IF;

  INSERT INTO fx_conversations (
    company_id, branch_id, conversation_type, title,
    context_deal_id, context_party_id, context_transaction_id, created_by
  ) VALUES (
    v_profile.company_id, p_branch_id, p_type, p_title,
    p_context_deal_id, p_context_party_id, p_context_transaction_id, auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO fx_conversation_members (conversation_id, user_id, role)
  VALUES (v_id, auth.uid(), 'admin')
  ON CONFLICT DO NOTHING;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION fx_send_message(
  p_conversation_id UUID,
  p_body TEXT,
  p_message_type fx_message_type DEFAULT 'text',
  p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM fx_conversation_members m
    JOIN fx_conversations c ON c.id = m.conversation_id
    WHERE m.conversation_id = p_conversation_id AND m.user_id = auth.uid()
      AND fx_same_branch(c.branch_id)
  ) THEN
    RAISE EXCEPTION 'Not a conversation member';
  END IF;

  INSERT INTO fx_messages (conversation_id, sender_id, message_type, body, metadata)
  VALUES (p_conversation_id, auth.uid(), p_message_type, p_body, p_metadata)
  RETURNING id INTO v_id;

  UPDATE fx_conversations SET last_message_at = NOW(), updated_at = NOW()
  WHERE id = p_conversation_id;

  UPDATE fx_conversation_members SET unread_count = unread_count + 1
  WHERE conversation_id = p_conversation_id AND user_id <> auth.uid();

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION fx_mark_conversation_read(p_conversation_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE fx_conversation_members SET unread_count = 0, last_read_at = NOW()
  WHERE conversation_id = p_conversation_id AND user_id = auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION fx_list_messages(p_conversation_id UUID, p_limit INT DEFAULT 100)
RETURNS SETOF fx_messages
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT m.*
  FROM fx_messages m
  JOIN fx_conversation_members cm ON cm.conversation_id = m.conversation_id AND cm.user_id = auth.uid()
  WHERE m.conversation_id = p_conversation_id AND m.deleted_at IS NULL
  ORDER BY m.created_at ASC
  LIMIT p_limit;
$$;

-- Realtime (requires replication enabled in dashboard for fx_messages)
ALTER PUBLICATION supabase_realtime ADD TABLE fx_messages;

GRANT EXECUTE ON FUNCTION fx_list_conversations(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_get_or_create_entity_conversation(UUID, fx_conversation_type, UUID, UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_send_message(UUID, TEXT, fx_message_type, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_mark_conversation_read(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_list_messages(UUID, INT) TO authenticated;
