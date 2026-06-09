# Supabase verify scripts

Run these in the Supabase SQL Editor (project `ygidlcqhupmxvsdjmvnf`) after applying migrations.

| Script | Purpose |
|--------|---------|
| [`verify_foundation.sql`](verify_foundation.sql) | Companies, branches, COA seed |
| [`verify_posting_engine.sql`](verify_posting_engine.sql) | Posting helpers and journal balance |
| [`verify_posting_smoke.sql`](verify_posting_smoke.sql) | Trial balance + recent posted txns |
| [`verify_reports.sql`](verify_reports.sql) | Report RPCs |
| [`verify_handoff_rpcs.sql`](verify_handoff_rpcs.sql) | Manual journal, repost, restore, attachments bucket |

## Apply migrations

```bash
supabase link --project-ref ygidlcqhupmxvsdjmvnf
supabase db push
```

Or paste [`../migrations/202606140001_fx_manual_journal_repost_restore_attachments.sql`](../migrations/202606140001_fx_manual_journal_repost_restore_attachments.sql) into SQL Editor.

## Bootstrap admin

[`bootstrap_admin_by_email.sql`](bootstrap_admin_by_email.sql) — assign profile + permissions for your auth user.

## RLS

Automated RLS tests require separate test auth users. Use verify scripts with an authenticated session in the app to confirm branch-scoped reads/writes.
