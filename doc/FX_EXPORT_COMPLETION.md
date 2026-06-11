# FX Export / Share / Print Completion

**Packages (already installed):** `share_plus`, `pdf`, `printing`  
**Unified UI:** `lib/core/export/fx_document_export.dart`

## Coverage matrix

| Document | Text | CSV | PDF | Print | Customer copy | Status |
|----------|------|-----|-----|-------|---------------|--------|
| Deal Statement | Y | — | Y | Y | Y | Done |
| Customer Statement | Y | Y | Y | Y | **S1: UI button** | In progress |
| Agent Statement | Y | Y | Y | Y | **S1: UI button** | In progress |
| Remittance Receipt | Y | — | Y | Y | Y | S1 (after H2) |
| Payment Receipt | Y | — | Y | Y | **S1: redaction** | In progress |
| Agent Payment Receipt | Y | — | Y | Y | Partial | S1 new builder |
| Trial Balance | Y | Y | Y | Y | N/A | Done |
| P&L | Y | Y | Y | Y | N/A | Done |
| Balance Sheet | Y | Y | Y | Y | N/A | Done |
| Currency Position | Y | Y | Y | Y | N/A | Done |
| Daily Closing | Y | Y | Y | Y | N/A | Done |

## Customer vs internal redaction

Central module: `lib/core/export/receipt_redaction.dart`

**Customer copy hides:**

- Journal line details (Dr/Cr account codes)
- Internal notes
- Profit/loss, cost basis
- Audit references

**Customer copy shows:**

- Reference / tracking ID
- Party names, amounts, dates
- Customer-relevant rate

## S1 deliverables

1. Party ledger: "Share customer copy" action
2. `formatTransactionReceipt(tx, mode: customer|internal)`
3. `formatAgentPaymentReceipt` for settlement_send / agent payment legs
4. `formatRemittanceReceipt` + PDF via `remittance_receipt_builder.dart`
5. Transaction detail: choose customer vs internal receipt

## S2 deliverables

1. PDF headers include company/branch from profile where available
2. Export icon on any report screen missing share action
3. `buildSimpleReportPdf` optional `companyName` / `branchName` params

## No new packages required

Do not add packages without explicit approval.
