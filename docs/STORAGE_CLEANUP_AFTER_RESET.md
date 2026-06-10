# Storage Cleanup After FXDEV Reset

After running `reset_dev_fx_data.sql`, **database attachment rows are deleted** but **Storage objects remain** until manually removed.

## Bucket

- Name: `fx-attachments` (private)
- Paths:
  - Transactions: `{branchId}/{transactionId}/...`
  - Deal legs (after migration): `{branchId}/deals/{dealId}/legs/{legId}/...`

## Manual cleanup (Supabase Dashboard)

1. Open project `ygidlcqhupmxvsdjmvnf` → Storage → `fx-attachments`
2. Delete folder for MAIN branch: `00000000-0000-4000-8000-000000000002/`
3. Or delete entire bucket contents if this is dev-only

## CLI (optional)

```bash
npx supabase storage ls ss:///fx-attachments --linked
# Delete objects via dashboard or storage API — no bulk SQL delete
```

## Safety

- Do not delete the bucket itself — only objects inside.
- Re-upload proofs on new real deals after clean start.
