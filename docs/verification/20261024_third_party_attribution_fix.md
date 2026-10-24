# Third-party line-party attribution fix — 2026-10-24

Tip start: `07301d3`. Applied SQL: `AA_third_party_line_party_attribution.sql`.  
Corrected training tx: `75a8d9e1-13ed-4524-9871-bbf5a3edf7e3` (Deal1 third-party 350k).  
Backup: `fx_am_correction_backups` label `AM_AA_TP_ATTRIB_20261024_BEFORE`.

## Defect

`fx_record_deal_third_party_payment` posted Dr 2100 / Cr 1160 with **entire tx `party_id` = customer**. Party measures attributed both lines to Client A, so Agent A GL payable stayed +350k high and Client A control included a misattributed +350k Dr 2100. Company-wide net hid the split.

## Fix

1. `fx_transaction_lines.party_id` + `fx_journal_lines.party_id` (line subledger).
2. `fx_transactions.counterparty_party_id` (agent reference; primary `party_id` remains customer).
3. `fx_build_journal_from_transaction` copies `COALESCE(line.party_id, tx.party_id)`.
4. Directory balances/measures attribute via `COALESCE(jl.party_id, t.party_id)`.
5. Third-party RPC: 2100 line → agent; 1160 line → customer; company/branch checks; idempotency unchanged; payable reduce still records applied amount for void.
6. `fx_correct_third_party_line_attribution`: voids old journals, updates line parties, rebuilds journal, **does not unwind deal legs**; audited `edited`.

## Before → after (training)

| Metric | Before | After |
|--------|--------|-------|
| Deal1 paid / unpaid | 1,037,500 / 1,037,500 | **same** |
| Deal1 status | delivered | **delivered** |
| Agent A payable chip (2100) | 706,000 | **356,000** |
| Agent B payable | 216,000 | **216,000** |
| Training 2100 net (TRAIN_* only) | 572,000* | **572,000** |
| Client A control net | 142,500 | **−207,500** |
| Client A unpaid deals | 1,037,500 | **1,037,500** |
| Training owned banks/cash | 7,690,000 | **7,690,000** |
| 1180 Agent B | 3,346,000 | **3,346,000** |
| Agent A CNY custody payable | 0 | **0** (audit `AM_RECON_20261024…` retained) |

\*Before: 706 (A) − 350 (mis-tagged on Client A) + 216 (B) = 572.

### Client A control after fix (from live journals)

| Account | Net Dr | Role |
|---------|--------|------|
| 1190 | +415,000 | Delivery-slice AR |
| 1160 | −622,500 | Advances 1,037,500 − applied 415,000 |
| 2100 | 0 on customer | Moved to Agent A |
| **Control** | **−207,500** | Net credit (unapplied advances dominate) |

Unpaid deals **1,037,500** remains the deal cash measure — still distinct from control and from delivery recognition.

### Live journal parties on corrected tx

| Account | Amount | `jl.party_id` |
|---------|--------|---------------|
| 2100 Dr | 350,000 | **TRAIN_AGT_A** |
| 1160 Cr | 350,000 | **TRAIN_CLI_A** |

Voided prior journal retained (history).

## Regression (API + JWT; not browser)

| Test | Result |
|------|--------|
| Post + line parties | PASS |
| Same-key retry | PASS |
| Void + repeat void | PASS |
| Null JWT | PASS |
| Bad agent / cross-company | PASS |
| CNY payable 0 + audit durable | PASS |

## Remaining NOT RUN

Authenticated **browser** click-through for third-party compose; TT/bank/custody UI visibility.

## Deploy

DB-only AM change. Frontend unchanged (measures from RPC). No `fx_app_web` redeploy required for this fix.
