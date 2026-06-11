-- Non-destructive verification for messaging module (run after migration apply)
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name IN ('fx_conversations', 'fx_conversation_members', 'fx_messages')
ORDER BY table_name;

SELECT proname FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND proname LIKE 'fx_%message%' OR proname LIKE 'fx_%conversation%'
ORDER BY proname;
