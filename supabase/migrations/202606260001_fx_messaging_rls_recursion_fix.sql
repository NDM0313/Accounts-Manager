-- Fix infinite RLS recursion between fx_conversations and fx_conversation_members (42P17)
-- Project: ygidlcqhupmxvsdjmvnf only

-- ---------------------------------------------------------------------------
-- SECURITY DEFINER helpers (bypass RLS for internal membership / branch checks)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fx_is_conversation_member(
  p_conversation_id UUID,
  p_user_id UUID DEFAULT auth.uid()
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM fx_conversation_members m
    WHERE m.conversation_id = p_conversation_id
      AND m.user_id = p_user_id
  );
$$;

CREATE OR REPLACE FUNCTION fx_conversation_branch_id(p_conversation_id UUID)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.branch_id
  FROM fx_conversations c
  WHERE c.id = p_conversation_id
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION fx_is_conversation_member(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fx_conversation_branch_id(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- Replace circular policies
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS fx_conversations_select ON fx_conversations;
CREATE POLICY fx_conversations_select ON fx_conversations
  FOR SELECT TO authenticated
  USING (
    fx_same_branch(branch_id)
    AND (
      fx_has_permission('can_manage_messaging')
      OR fx_is_conversation_member(id)
    )
  );

DROP POLICY IF EXISTS fx_conversation_members_select ON fx_conversation_members;
CREATE POLICY fx_conversation_members_select ON fx_conversation_members
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR (
      fx_has_permission('can_manage_messaging')
      AND fx_same_branch(fx_conversation_branch_id(conversation_id))
    )
  );

DROP POLICY IF EXISTS fx_messages_select ON fx_messages;
CREATE POLICY fx_messages_select ON fx_messages
  FOR SELECT TO authenticated
  USING (
    fx_is_conversation_member(conversation_id)
    AND fx_same_branch(fx_conversation_branch_id(conversation_id))
  );

DROP POLICY IF EXISTS fx_messages_insert ON fx_messages;
CREATE POLICY fx_messages_insert ON fx_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND fx_is_conversation_member(conversation_id)
    AND fx_same_branch(fx_conversation_branch_id(conversation_id))
  );
