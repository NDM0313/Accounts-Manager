-- =============================================================================
-- D) STORAGE BUCKET + POLICIES (PROPOSAL) — NOT FOR DEFAULT EXECUTION
-- =============================================================================
-- Separate AM attachments from ERP buckets (sale-attachments, etc.).
-- Activation:
--   SELECT set_config('fx_reconciliation.confirm', 'APPLY_FX_STORAGE_HOME', true);
-- =============================================================================

DO $$
BEGIN
  IF current_setting('fx_reconciliation.confirm', true) IS DISTINCT FROM 'APPLY_FX_STORAGE_HOME' THEN
    RAISE EXCEPTION 'BLOCKED: set fx_reconciliation.confirm = APPLY_FX_STORAGE_HOME';
  END IF;
END $$;

INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('fx-attachments', 'fx-attachments', false, 10485760)
ON CONFLICT (id) DO NOTHING;

-- Object path convention (enforced in policies + app):
--   {company_id}/{branch_id}/{transaction_id}/{filename}

DROP POLICY IF EXISTS fx_attachments_storage_select ON storage.objects;
CREATE POLICY fx_attachments_storage_select ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'fx-attachments'
    AND fx_same_company( (storage.foldername(name))[1]::uuid )
  );

DROP POLICY IF EXISTS fx_attachments_storage_insert ON storage.objects;
CREATE POLICY fx_attachments_storage_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'fx-attachments'
    AND fx_same_company( (storage.foldername(name))[1]::uuid )
    AND fx_has_permission('can_upload_fx_attachment')
  );

DROP POLICY IF EXISTS fx_attachments_storage_update ON storage.objects;
CREATE POLICY fx_attachments_storage_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'fx-attachments'
    AND fx_same_company( (storage.foldername(name))[1]::uuid )
  );

DROP POLICY IF EXISTS fx_attachments_storage_delete ON storage.objects;
CREATE POLICY fx_attachments_storage_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'fx-attachments'
    AND fx_same_company( (storage.foldername(name))[1]::uuid )
    AND fx_has_permission('can_delete_fx_attachment')
  );

-- Do not modify ERP buckets: sale-attachments, purchase-attachments, etc.
