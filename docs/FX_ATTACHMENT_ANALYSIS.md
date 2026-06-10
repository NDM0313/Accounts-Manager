# FX Attachment Support Analysis

## Current schema (`fx_attachments`)

| Column | Purpose |
|--------|---------|
| `transaction_id` | Required FK — only anchor today |
| `storage_path`, `file_name`, `mime_type`, `file_size_bytes` | File metadata |
| `uploaded_by`, `created_at` | Audit |

**Missing:** `deal_id`, `deal_leg_id`, `attachment_type`

## Coverage gap

- Payment/delivery legs: files attachable only via linked `fx_transactions`.
- Agent source, cross-currency, settlement legs: **no file support** — `proof_reference` TEXT only.

## Proposed migration (`202606190001`)

- Add nullable `deal_id`, `deal_leg_id`; make `transaction_id` nullable.
- CHECK: at least one of `transaction_id` or `deal_leg_id` set.
- Extend RLS via `fx_deals` → branch join.
- Storage path: `{branchId}/deals/{dealId}/legs/{legId}/{ts}_{file}`

## Flutter

- `AttachmentRepository.uploadForLeg`, `fetchForLeg`, `fetchLegIdsWithAttachments`
- `FxProofAttachmentsSection` on all leg screens + timeline badges on deal detail.
