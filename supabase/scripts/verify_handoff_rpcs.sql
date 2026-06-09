-- Handoff RPC + storage smoke checks (run in Supabase SQL Editor after 202606140001 migration)
-- Project: ygidlcqhupmxvsdjmvnf · Branch MAIN: 00000000-0000-4000-8000-000000000002

-- 1) Functions exist
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'fx_post_manual_journal',
    'fx_repost_transaction',
    'fx_restore_deleted_transaction'
  )
ORDER BY routine_name;

-- 2) Storage bucket
SELECT id, name, public, file_size_limit
FROM storage.buckets
WHERE id = 'fx-attachments';

-- 3) Manual journal rejects unbalanced payload (expect ERROR when run as authenticated user)
-- SELECT fx_post_manual_journal('{"branch_id":"00000000-0000-4000-8000-000000000002","company_id":"<company_uuid>","lines":[]}'::jsonb);

-- 4) Recent manual journals (no transaction_id)
SELECT je.entry_no, je.entry_date, je.description, je.is_void
FROM fx_journal_entries je
WHERE je.branch_id = '00000000-0000-4000-8000-000000000002'::uuid
  AND je.transaction_id IS NULL
ORDER BY je.created_at DESC
LIMIT 5;

-- 5) Voided transactions eligible for restore
SELECT t.id, t.transaction_no, t.status, t.is_deleted
FROM fx_transactions t
WHERE t.branch_id = '00000000-0000-4000-8000-000000000002'::uuid
  AND (t.status = 'voided' OR t.is_deleted)
ORDER BY t.updated_at DESC
LIMIT 5;

-- 6) Attachments table + storage path sample
SELECT a.id, a.file_name, a.storage_path, a.transaction_id
FROM fx_attachments a
JOIN fx_transactions t ON t.id = a.transaction_id
WHERE t.branch_id = '00000000-0000-4000-8000-000000000002'::uuid
ORDER BY a.created_at DESC
LIMIT 5;
