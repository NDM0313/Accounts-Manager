-- P_slip_ocr_gaps_fix.sql
-- Internal transfer confirm, destination account, attach-to-existing,
-- party role-aware receive/pay, stronger duplicate helpers,
-- company-scoped attachment metadata + storage object policies.

CREATE OR REPLACE FUNCTION fx_account_currency_code(p_account fx_accounts)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (SELECT code FROM fx_currencies WHERE id = p_account.currency_id),
    'PKR'
  );
$$;

ALTER TABLE fx_payment_slip_imports
  ADD COLUMN IF NOT EXISTS destination_account_id UUID REFERENCES fx_accounts (id),
  ADD COLUMN IF NOT EXISTS party_flow TEXT
    CHECK (party_flow IS NULL OR party_flow IN (
      'customer_receipt','supplier_refund','supplier_payment',
      'agent_settlement','agent_to_beneficiary','unspecified'
    ));

CREATE INDEX IF NOT EXISTS idx_fx_slip_confirmed_ref_amt_acct
  ON fx_payment_slip_imports (company_id, bank_reference, amount, cash_account_id)
  WHERE status = 'confirmed' AND bank_reference IS NOT NULL;

-- Attach evidence to an already-posted transaction without posting money again.
CREATE OR REPLACE FUNCTION fx_attach_slip_to_existing_transaction(
  p_import_id UUID,
  p_transaction_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_imp fx_payment_slip_imports;
  v_tx fx_transactions;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_imp FROM fx_payment_slip_imports WHERE id = p_import_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Slip import not found'; END IF;
  IF NOT fx_same_company(v_imp.company_id) THEN
    RAISE EXCEPTION 'Unauthorized company';
  END IF;

  SELECT * INTO v_tx FROM fx_transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found'; END IF;
  IF v_tx.company_id IS DISTINCT FROM v_imp.company_id THEN
    RAISE EXCEPTION 'Cannot link slip to another company transaction';
  END IF;
  IF NOT fx_same_branch(v_tx.branch_id) THEN
    RAISE EXCEPTION 'Unauthorized branch';
  END IF;

  IF v_imp.attachment_id IS NOT NULL THEN
    UPDATE fx_attachments SET
      transaction_id = p_transaction_id,
      company_id = COALESCE(company_id, v_imp.company_id),
      slip_import_id = p_import_id
    WHERE id = v_imp.attachment_id;
  END IF;

  UPDATE fx_payment_slip_imports SET
    status = 'confirmed',
    resulting_tx_id = p_transaction_id,
    confirmed_by = auth.uid(),
    confirmed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_import_id;

  RETURN p_transaction_id;
END;
$$;

REVOKE ALL ON FUNCTION fx_attach_slip_to_existing_transaction(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_attach_slip_to_existing_transaction(UUID, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION fx_confirm_payment_slip_import(
  p_import_id UUID,
  p_client_operation_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_imp fx_payment_slip_imports;
  v_tx UUID;
  v_cash fx_accounts;
  v_dest fx_accounts;
  v_party fx_parties;
  v_op TEXT;
  v_flow TEXT;
  v_credit UUID;
  v_debit UUID;
  v_rate NUMERIC := 1;
  v_base NUMERIC;
BEGIN
  IF NOT fx_has_permission('can_post_fx_transaction') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_imp FROM fx_payment_slip_imports WHERE id = p_import_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Slip import not found'; END IF;
  IF NOT fx_same_company(v_imp.company_id) OR NOT fx_same_branch(v_imp.branch_id) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF v_imp.status = 'confirmed' AND v_imp.resulting_tx_id IS NOT NULL THEN
    RETURN v_imp.resulting_tx_id;
  END IF;
  IF v_imp.status = 'rejected' THEN
    RAISE EXCEPTION 'Import was rejected';
  END IF;

  v_op := COALESCE(NULLIF(TRIM(p_client_operation_id), ''), v_imp.client_operation_id);
  IF v_op IS NOT NULL THEN
    SELECT entity_id INTO v_tx FROM fx_client_operations
    WHERE company_id = v_imp.company_id AND operation_key = v_op;
    IF v_tx IS NOT NULL THEN
      UPDATE fx_payment_slip_imports SET
        status = 'confirmed', resulting_tx_id = v_tx,
        confirmed_by = auth.uid(), confirmed_at = NOW(), updated_at = NOW()
      WHERE id = p_import_id;
      RETURN v_tx;
    END IF;
  END IF;

  IF v_imp.amount IS NULL OR v_imp.amount <= 0 THEN
    RAISE EXCEPTION 'Confirm requires a positive amount';
  END IF;
  IF v_imp.cash_account_id IS NULL THEN
    RAISE EXCEPTION 'Select the receiving/paying cash or bank account';
  END IF;
  IF v_imp.classification IS NULL OR v_imp.classification = 'unsupported' THEN
    RAISE EXCEPTION 'Classification is unsupported or missing — keep as draft';
  END IF;

  SELECT * INTO v_cash FROM fx_accounts WHERE id = v_imp.cash_account_id;
  IF NOT FOUND OR v_cash.company_id IS DISTINCT FROM v_imp.company_id THEN
    RAISE EXCEPTION 'Cash/bank account invalid for this company';
  END IF;
  IF v_cash.account_type IS DISTINCT FROM 'asset'::fx_account_type OR NOT v_cash.is_active THEN
    RAISE EXCEPTION 'Account must be an active asset cash/bank account';
  END IF;

  v_flow := COALESCE(v_imp.party_flow, 'unspecified');
  IF v_flow = 'agent_to_beneficiary' THEN
    RAISE EXCEPTION
      'Agent-to-beneficiary slips do not enter our bank. Keep as draft and use agent settlement/delivery workflow.';
  END IF;

  -- Scoped duplicate: same company + reference + amount + cash account already confirmed
  IF v_imp.bank_reference IS NOT NULL AND EXISTS (
    SELECT 1 FROM fx_payment_slip_imports x
    WHERE x.company_id = v_imp.company_id
      AND x.id <> v_imp.id
      AND x.status = 'confirmed'
      AND x.bank_reference = v_imp.bank_reference
      AND x.amount = v_imp.amount
      AND x.cash_account_id = v_imp.cash_account_id
  ) THEN
    RAISE EXCEPTION
      'DUPLICATE_TRANSFER: same bank reference, amount, and account already confirmed. Use attach-to-existing instead of posting again.';
  END IF;

  IF v_imp.classification = 'internal_transfer' THEN
    IF v_imp.destination_account_id IS NULL THEN
      RAISE EXCEPTION 'Internal transfer requires destination cash/bank account';
    END IF;
    IF v_imp.destination_account_id = v_imp.cash_account_id THEN
      RAISE EXCEPTION 'Source and destination accounts must differ';
    END IF;
    SELECT * INTO v_dest FROM fx_accounts WHERE id = v_imp.destination_account_id;
    IF NOT FOUND OR v_dest.company_id IS DISTINCT FROM v_imp.company_id THEN
      RAISE EXCEPTION 'Destination account invalid for this company';
    END IF;
    IF v_dest.account_type IS DISTINCT FROM 'asset'::fx_account_type OR NOT v_dest.is_active THEN
      RAISE EXCEPTION 'Destination must be an active asset cash/bank account';
    END IF;

    -- Same-currency only unless explicit rate provided in extracted_json.transfer_rate.
    -- NULL account.currency_id is treated as PKR (legacy cash/bank rows).
    IF COALESCE(fx_account_currency_code(v_cash), 'PKR')
         IS DISTINCT FROM COALESCE(fx_account_currency_code(v_dest), 'PKR') THEN
      v_rate := NULLIF((v_imp.extracted_json->>'transfer_rate')::NUMERIC, 0);
      IF v_rate IS NULL THEN
        RAISE EXCEPTION
          'Cross-currency internal transfer requires explicit transfer_rate in the draft. Do not guess conversion.';
      END IF;
    ELSE
      v_rate := 1;
    END IF;
    v_base := ROUND(v_imp.amount * v_rate, 8);

    INSERT INTO fx_transactions (
      company_id, branch_id, transaction_type, status, transaction_date,
      currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
      description, created_by
    ) VALUES (
      v_imp.company_id, v_imp.branch_id, 'account_transfer', 'draft',
      COALESCE(v_imp.txn_date, CURRENT_DATE),
      COALESCE(v_imp.currency_code, 'PKR'), v_imp.amount, v_rate, v_base,
      COALESCE(v_imp.description, 'Internal transfer (slip import)'),
      auth.uid()
    ) RETURNING id INTO v_tx;

    -- Dr destination, Cr source
    INSERT INTO fx_transaction_lines (
      transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used,
      base_amount_pkr, debit_pkr, credit_pkr, memo
    ) VALUES
      (v_tx, 1, v_dest.id, COALESCE(v_imp.currency_code, 'PKR'), v_imp.amount, v_rate, v_base, v_base, 0, 'Transfer in'),
      (v_tx, 2, v_cash.id, COALESCE(v_imp.currency_code, 'PKR'), v_imp.amount, v_rate, v_base, 0, v_base, 'Transfer out');

    PERFORM fx_post_transaction(v_tx);

  ELSIF v_imp.classification IN ('receive_from_party', 'pay_to_party') THEN
    IF COALESCE(v_imp.currency_code, 'PKR') <> 'PKR' THEN
      RAISE EXCEPTION 'Party receive/pay confirm currently supports PKR only; use manual draft for %',
        v_imp.currency_code;
    END IF;
    IF v_imp.counterparty_party_id IS NULL THEN
      RAISE EXCEPTION 'Select a counterparty party';
    END IF;
    SELECT * INTO v_party FROM fx_parties WHERE id = v_imp.counterparty_party_id;
    IF NOT FOUND OR v_party.company_id IS DISTINCT FROM v_imp.company_id THEN
      RAISE EXCEPTION 'Counterparty invalid for this company';
    END IF;

    PERFORM fx_ensure_deal_coa(v_imp.company_id);

    IF v_imp.classification = 'receive_from_party' AND v_imp.deal_id IS NOT NULL THEN
      v_tx := fx_record_deal_customer_payment(
        v_imp.deal_id,
        v_imp.amount,
        COALESCE(v_imp.description, 'Slip import payment'),
        v_imp.cash_account_id,
        COALESCE(v_op, 'slip-confirm-' || p_import_id::TEXT)
      );
    ELSIF v_imp.classification = 'receive_from_party' THEN
      -- Customer receipt / supplier refund: Dr cash, Cr advances (not income)
      v_credit := fx_account_id_by_code(v_imp.company_id, '1160');
      IF v_credit IS NULL THEN
        RAISE EXCEPTION 'Missing account 1160 for party settlement credit';
      END IF;
      INSERT INTO fx_transactions (
        company_id, branch_id, transaction_type, status, transaction_date,
        party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
        description, created_by
      ) VALUES (
        v_imp.company_id, v_imp.branch_id, 'settlement_receive', 'draft',
        COALESCE(v_imp.txn_date, CURRENT_DATE),
        v_imp.counterparty_party_id, 'PKR', v_imp.amount, 1, v_imp.amount,
        COALESCE(v_imp.description,
          CASE v_flow
            WHEN 'supplier_refund' THEN 'Supplier refund received (slip import)'
            ELSE 'Payment received (slip import)'
          END),
        auth.uid()
      ) RETURNING id INTO v_tx;
      INSERT INTO fx_transaction_lines (
        transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used,
        base_amount_pkr, debit_pkr, credit_pkr, memo
      ) VALUES
        (v_tx, 1, v_imp.cash_account_id, 'PKR', v_imp.amount, 1, v_imp.amount, v_imp.amount, 0, 'Cash/bank in'),
        (v_tx, 2, v_credit, 'PKR', v_imp.amount, 1, v_imp.amount, 0, v_imp.amount, 'Party settlement');
      PERFORM fx_post_transaction(v_tx);
    ELSE
      -- pay_to_party: supplier payment / agent settlement — Dr advances/payable, Cr cash (not expense)
      v_debit := COALESCE(
        fx_account_id_by_code(v_imp.company_id, '1160'),
        fx_account_id_by_code(v_imp.company_id, '1190'),
        fx_account_id_by_code(v_imp.company_id, '2100')
      );
      IF v_debit IS NULL THEN
        RAISE EXCEPTION 'Missing settlement/payable account for party payment';
      END IF;
      INSERT INTO fx_transactions (
        company_id, branch_id, transaction_type, status, transaction_date,
        party_id, currency_code, total_foreign_amount, rate_used, total_base_amount_pkr,
        description, created_by
      ) VALUES (
        v_imp.company_id, v_imp.branch_id, 'settlement_send', 'draft',
        COALESCE(v_imp.txn_date, CURRENT_DATE),
        v_imp.counterparty_party_id, 'PKR', v_imp.amount, 1, v_imp.amount,
        COALESCE(v_imp.description,
          CASE v_flow
            WHEN 'agent_settlement' THEN 'Agent settlement payment (slip import)'
            WHEN 'supplier_payment' THEN 'Supplier payment (slip import)'
            ELSE 'Payment sent (slip import)'
          END),
        auth.uid()
      ) RETURNING id INTO v_tx;
      INSERT INTO fx_transaction_lines (
        transaction_id, line_no, account_id, currency_code, foreign_amount, rate_used,
        base_amount_pkr, debit_pkr, credit_pkr, memo
      ) VALUES
        (v_tx, 1, v_debit, 'PKR', v_imp.amount, 1, v_imp.amount, v_imp.amount, 0, 'Party settlement'),
        (v_tx, 2, v_imp.cash_account_id, 'PKR', v_imp.amount, 1, v_imp.amount, 0, v_imp.amount, 'Cash/bank out');
      PERFORM fx_post_transaction(v_tx);
    END IF;
  ELSE
    RAISE EXCEPTION 'Unsupported classification';
  END IF;

  UPDATE fx_payment_slip_imports SET
    status = 'confirmed',
    resulting_tx_id = v_tx,
    confirmed_by = auth.uid(),
    confirmed_at = NOW(),
    client_operation_id = COALESCE(client_operation_id, v_op),
    updated_at = NOW()
  WHERE id = p_import_id;

  IF v_imp.attachment_id IS NOT NULL THEN
    UPDATE fx_attachments SET
      transaction_id = COALESCE(transaction_id, v_tx),
      slip_import_id = p_import_id,
      company_id = COALESCE(company_id, v_imp.company_id)
    WHERE id = v_imp.attachment_id;
  END IF;

  IF v_op IS NOT NULL THEN
    INSERT INTO fx_client_operations (
      company_id, operation_key, operation_type, entity_type, entity_id, result_json, created_by
    ) VALUES (
      v_imp.company_id, v_op, 'slip_import_confirm', 'fx_transaction', v_tx,
      jsonb_build_object('import_id', p_import_id, 'amount', v_imp.amount),
      auth.uid()
    ) ON CONFLICT (company_id, operation_key) DO NOTHING;
  END IF;

  RETURN v_tx;
END;
$$;

-- Soft-deactivate party (no hard delete)
CREATE OR REPLACE FUNCTION fx_deactivate_party(p_party_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_party fx_parties;
BEGIN
  IF NOT fx_has_permission('can_access_fx_ledger') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  SELECT * INTO v_party FROM fx_parties WHERE id = p_party_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Party not found'; END IF;
  IF NOT fx_same_company(v_party.company_id) THEN
    RAISE EXCEPTION 'Unauthorized company';
  END IF;
  UPDATE fx_parties SET is_active = FALSE, updated_at = NOW() WHERE id = p_party_id;
  RETURN jsonb_build_object('party_id', p_party_id, 'deactivated', TRUE);
END;
$$;

REVOKE ALL ON FUNCTION fx_deactivate_party(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fx_deactivate_party(UUID) TO authenticated;

-- Slip-only attachments must satisfy target check (was missing slip_import_id).
ALTER TABLE fx_attachments DROP CONSTRAINT IF EXISTS fx_attachments_target_check;
ALTER TABLE fx_attachments ADD CONSTRAINT fx_attachments_target_check CHECK (
  transaction_id IS NOT NULL
  OR deal_id IS NOT NULL
  OR remittance_id IS NOT NULL
  OR message_id IS NOT NULL
  OR slip_import_id IS NOT NULL
);

-- ---------------------------------------------------------------------------
-- Attachment metadata: company_id + slip_import access (same-company only)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS fx_attachments_select ON fx_attachments;
CREATE POLICY fx_attachments_select ON fx_attachments
  FOR SELECT USING (
    (
      company_id IS NOT NULL
      AND fx_same_company(company_id)
      AND fx_has_permission('can_access_fx_ledger')
    )
    OR (
      transaction_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_transactions t
        WHERE t.id = fx_attachments.transaction_id AND fx_same_branch(t.branch_id)
      )
    )
    OR (
      deal_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_deals d
        WHERE d.id = fx_attachments.deal_id AND fx_same_branch(d.branch_id)
      )
    )
    OR (
      remittance_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_remittances r
        WHERE r.id = fx_attachments.remittance_id AND fx_same_branch(r.branch_id)
      )
    )
    OR (
      message_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_messages msg
        JOIN fx_conversations c ON c.id = msg.conversation_id
        WHERE msg.id = fx_attachments.message_id AND fx_same_branch(c.branch_id)
      )
    )
    OR (
      slip_import_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM fx_payment_slip_imports i
        WHERE i.id = fx_attachments.slip_import_id
          AND fx_same_company(i.company_id)
          AND fx_has_permission('can_access_fx_ledger')
      )
    )
  );

DROP POLICY IF EXISTS fx_attachments_insert ON fx_attachments;
CREATE POLICY fx_attachments_insert ON fx_attachments
  FOR INSERT WITH CHECK (
    (
      company_id IS NOT NULL
      AND fx_same_company(company_id)
      AND fx_has_permission('can_access_fx_ledger')
    )
    AND (
      (
        transaction_id IS NOT NULL AND EXISTS (
          SELECT 1 FROM fx_transactions t
          WHERE t.id = transaction_id AND fx_same_branch(t.branch_id)
        )
      )
      OR (
        deal_id IS NOT NULL AND EXISTS (
          SELECT 1 FROM fx_deals d
          WHERE d.id = deal_id AND fx_same_branch(d.branch_id)
        )
      )
      OR (
        remittance_id IS NOT NULL AND EXISTS (
          SELECT 1 FROM fx_remittances r
          WHERE r.id = remittance_id AND fx_same_branch(r.branch_id)
        )
      )
      OR (
        message_id IS NOT NULL AND EXISTS (
          SELECT 1 FROM fx_messages msg
          JOIN fx_conversations c ON c.id = msg.conversation_id
          WHERE msg.id = message_id AND fx_same_branch(c.branch_id)
        )
      )
      OR (
        slip_import_id IS NOT NULL AND EXISTS (
          SELECT 1 FROM fx_payment_slip_imports i
          WHERE i.id = slip_import_id
            AND fx_same_company(i.company_id)
            AND fx_has_permission('can_access_fx_ledger')
        )
      )
    )
  );

DROP POLICY IF EXISTS fx_attachments_delete ON fx_attachments;
CREATE POLICY fx_attachments_delete ON fx_attachments
  FOR DELETE USING (
    fx_has_permission('can_access_fx_ledger')
    AND company_id IS NOT NULL
    AND fx_same_company(company_id)
  );

-- Storage objects: first path segment must be caller's active company UUID.
-- Paths are written as {companyId}/{branchId}/...
DROP POLICY IF EXISTS fx_attachments_storage_select ON storage.objects;
CREATE POLICY fx_attachments_storage_select ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'fx-attachments'
    AND (storage.foldername(name))[1] IS NOT NULL
    AND fx_same_company(((storage.foldername(name))[1])::uuid)
  );

DROP POLICY IF EXISTS fx_attachments_storage_insert ON storage.objects;
CREATE POLICY fx_attachments_storage_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'fx-attachments'
    AND (storage.foldername(name))[1] IS NOT NULL
    AND fx_same_company(((storage.foldername(name))[1])::uuid)
  );

DROP POLICY IF EXISTS fx_attachments_storage_update ON storage.objects;
CREATE POLICY fx_attachments_storage_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'fx-attachments'
    AND (storage.foldername(name))[1] IS NOT NULL
    AND fx_same_company(((storage.foldername(name))[1])::uuid)
  )
  WITH CHECK (
    bucket_id = 'fx-attachments'
    AND (storage.foldername(name))[1] IS NOT NULL
    AND fx_same_company(((storage.foldername(name))[1])::uuid)
  );

DROP POLICY IF EXISTS fx_attachments_storage_delete ON storage.objects;
CREATE POLICY fx_attachments_storage_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'fx-attachments'
    AND (storage.foldername(name))[1] IS NOT NULL
    AND fx_same_company(((storage.foldername(name))[1])::uuid)
  );

NOTIFY pgrst, 'reload schema';
