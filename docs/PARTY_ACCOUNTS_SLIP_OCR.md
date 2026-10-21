# Party / Cash-Bank / Slip OCR / Attachments

## What users can create

| Item | Where | Notes |
|------|--------|------|
| Customer / Agent / Supplier / Settlement party | General Hub → Parties → New | Soft-deactivate only; history preserved |
| Cash account | COA → Add Cash, or `/accounts/new-cash` | Zero opening; needs `can_manage_chart_of_accounts` |
| Bank account | COA → Add Bank | Codes `1210+`; bank metadata in notes |
| Payment slip import | New Transaction → Import Payment Slip, or `/slips/import` | OCR draft only until Confirm |

## Accounting linkage

- Parties use control accounts + party subledger (no GL account per party).
- Cash/bank via `fx_create_cash_bank_account` under Assets `1000` (auto-ensured).
- Reserved codes `1160/1170/1190/2310/2350` blocked.
- Opening balances: existing Opening Balances workflow only.

## OCR

- Engine: **Tesseract.js v5** loaded from jsDelivr CDN in Flutter **web** only.
- Parser: Dart port of PK bank slip heuristics (`PakBankSlipParser`).
- No paid third-party OCR subscription; credentials never in Flutter.
- PDF: attached as-is; manual field entry (no flatten).

## Slip workflow

Upload → compress (images) → private `fx-attachments` → OCR draft in `fx_payment_slip_imports` → human edit → classify → select cash/bank + party → **Confirm** → `fx_confirm_payment_slip_import` (idempotent).

## Attachments

- Multi-file pick on proof / remittance / transaction sections.
- Compression target ~160 KB JPEG; EXIF stripped; metadata on row.
- Storage path: `{company_id}/{branch_id}/...` + UUID filename.
- Short-lived signed URLs only.

## SQL package

`supabase/reconciliation/home/O_party_accounts_attachments_ocr.sql`
