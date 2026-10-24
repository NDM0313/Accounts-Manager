# AM Training Dataset Guide — `AM_TRAINING_20261023_V1`

Synthetic training data for **AM_DEMO only** (company `a1111111-1111-4111-8111-111111111101`).  
Not ERP. No real IBANs, account numbers, or personal information. Slip refs use `SAMPLE — NOT A REAL BANK RECEIPT` wording.

## Status (applied home Supabase via `dinserver-cf`)

| Check | Result |
|--------|--------|
| Batch present in `fx_demo_seed_batches` / `fx_training_manifest` | **PASS** (applied 2026-10-23) |
| Idempotent re-run returns `idempotent: true`, no duplicates | **PASS** |
| Training journals balanced | **PASS** (0 unbalanced) |
| Customer batch due (excl. draft TT) = **1,357,500** | **PASS** |
| Agent B 1180 advance remaining = **3,346,000** | **PASS** |
| Cash in Hand **1,780,000** / Petty **218,000** | **PASS** |
| Owned banks match computed plan | **PASS** (see below) |
| Third-party receipt Dr 2100 / Cr 1160 only (no bank) | **PASS** |
| DEAL5 remittance **draft**, paid_amount 0 | **PASS** |
| Browser UI walkthrough of training screens | **PASS** (authenticated AM_DEMO 2026-10-24; evidence `tmp/training_ui_evidence_20261024/`) |
| Frontend redeploy for auth hang fix | **PASS** (`cb8d6c3`; superseded by create-flow + deep-link deploy below) |
| UI create: third-party client→agent payment | **WIRED** (Receive Money → deal allocate → settlement **Agent external** → `fx_record_deal_third_party_payment`) |
| UI create: agent-advance funded FX purchase | **WIRED** (Buy FX → **Advance** → `fx_post_agent_currency_purchase_funded` mode=advance / 1180) |

## Files

| File | Role |
|------|------|
| `supabase/reconciliation/home/X_training_third_party_and_funding.sql` | Additive RPCs: third-party deal payment, funded purchase (`cash`/`credit`/`advance`), recognize payable, settlement helpers |
| `supabase/reconciliation/home/X_am_training_20261023_v1_seed.sql` | Idempotent seed function `fx_seed_am_training_20261023_v1()` |
| This guide | Chronology, IDs, expected balances, UI nav, safe cleanup |

## Apply (AM_DEMO only)

```sql
-- 1) Load RPC pack once (or after updates)
\i supabase/reconciliation/home/X_training_third_party_and_funding.sql

-- 2) Load / refresh seed function
\i supabase/reconciliation/home/X_am_training_20261023_v1_seed.sql

-- 3) Apply inside one transaction (GUC is transaction-local)
BEGIN;
SELECT set_config('fx_reconciliation.confirm', 'APPLY_AM_TRAINING_20261023_V1', true);
SELECT fx_seed_am_training_20261023_v1();
COMMIT;
```

If the batch already exists, the function returns the stored manifest with `"idempotent": true` and posts nothing new.

**Do not** delete or rewrite unrelated demo/real rows. Openings are skipped when TRAINING cash/bank openings already exist.

---

## Parties & owned accounts

| Label | Name in DB | UUID |
|-------|------------|------|
| Client A–D | `TRAINING Client A` … `D` | `…1401` … `…1404` |
| Agent A / B | `TRAINING Agent A` / `B` | `…1411` / `…1412` |

Company-owned PKR assets (synthetic names, no real bank numbers):

| Account | Code | Account id |
|---------|------|------------|
| TRAINING Cash in Hand | 1113 | `064df8bf-e0a1-4b99-9c88-2f39dbfab4ea` |
| TRAINING Petty Cash | 1114 | `12c66740-c713-4da5-8c17-136ef77fbdc8` |
| TRAINING Meezan Bank | 1211 | `7fde816f-9737-412d-9643-62ccd129422d` |
| TRAINING Bank Alfalah | 1212 | `3ef68f3e-ac52-475d-a560-5ff4b6e8d98b` |
| TRAINING HBL | 1213 | `a8765a20-bf77-48ef-8de5-b4bdce8e5e61` |
| Agent Receivable / advance (1180) | 1180 | `4c8e5cc8-0c08-4a49-88d2-c50e74269375` |

**Opening (fresh only):** Cash 1.8M + Petty 0.2M + Meezan 6M + Alfalah 3M + HBL 3M = **14,000,000** PKR via balanced opening workflow (Dr assets / Cr equity 3100). Not re-applied if already present.

### Agent external recipient banks (not company-owned)

| Agent | Bank title | Account # | IBAN (synthetic) |
|-------|------------|-----------|------------------|
| Agent A | SAMPLE Meezan External | SAMPLE-AGT-A-001 | PK00SAMPLE0000000000000001 |
| Agent B | SAMPLE HBL External | SAMPLE-AGT-B-001 | PK00SAMPLE0000000000000002 |

These never appear in owned-bank balances.

---

## Deals (canonical numbers)

| Scenario | Deal no | Id | Notes |
|----------|---------|-----|-------|
| DEAL 1 | `DL-20261023-0001` | `e4457820-974b-46a1-bffc-0149ab13c471` | Client A / Agent A CNY |
| DEAL 2 | `DL-20261023-0002` | `9025e1f9-cef6-4f17-8fb4-ba3f45101a2b` | Client B / Agent B USD completed |
| DEAL 3 | `DL-20261023-0003` | `01d82ca2-6103-4df7-9207-56bee76598a6` | Client C / Agent A AED completed |
| DEAL 4 | `DL-20261023-0004` | `dff737d9-11ef-4257-949c-6aded57f9654` | Client D / Agent B CNY partial |
| DEAL 5 | Remittance `RM-20261023-0001` | `4c0a232f-e34d-492d-ab9a-a154fc672dc6` | Draft TT only |

Readable labels live in `notes` / descriptions prefixed `AM_TRAINING_20261023_V1`. System numbering is preserved separately from scenario labels.

---

## Chronological story (what to teach)

1. **Open TRAINING cash & banks** — company owns 14M PKR across five asset accounts.
2. **DEAL 1** — Sell CNY 50k @ 41.50 (= 2,075,000). Source @ 41.00 (= 2,050,000). Customer pays 400k Meezan + **350k direct to Agent A external** + 287.5k Alfalah (total paid 1,037,500; due 1,037,500). Third-party payment reduces customer AR and Agent A payable once; **owned banks unchanged**. Pay remaining agent 1,700,000 from Meezan/Alfalah/HBL (700/500/500). Source inventory; deliver 20k CNY; **30k CNY remains owned, reserved with Agent A** (not vault).
3. **DEAL 2** — USD 1k sell 280 / buy 278; two 140k receipts; pay agent 278k; source+deliver all; dues zero.
4. **DEAL 3** — AED 5k sell 76.50 / buy 76; customer pays Meezan; pay agent Alfalah; receive+deliver; complete.
5. **DEAL 4** — CNY 10k partial money and partial delivery: client 100k, agent paid 200k (payable left 216k), deliver 4k (6k remaining reserved). Settlement and FX delivery stay independent.
6. **DEAL 5** — USD 2k TT draft @ indicative 281 (= 562,000 PKR). **Draft only** — no payment, inventory, revenue, or receivable. Remittance policy for full TT booking may still be product-constrained; draft is preserved.
7. **S6** — Transfer 5,000,000 Meezan → Agent B as **1180 advance** (asset, not expense). Buy for inventory (no customer): USD 3k @ 278 (834k) + CNY 20k @ 41 (820k) applying advance. Remaining advance **3,346,000**. Currency stays in **agent custody** (available unless reserved). **Do not** auto-net Deal 4 payable against this advance.
8. **S7** — Buy USD 2k from Agent A on credit (556k); pay 200k in two bank instalments; payable left **356,000**. Stock before sale; no invented customer.
9. **Cash demo** — Transfer 20k Cash→Petty (not income/expense); 2k labelled demo office expense from Petty.

---

## Expected vs actual owned PKR (training accounts)

Computed from the posting manifest (not the old V1 bank total):

| Account | Expected | Actual (GL) |
|---------|----------|-------------|
| Cash in Hand 1113 | 1,780,000 | **1,780,000** |
| Petty Cash 1114 | 218,000 | **218,000** |
| Meezan 1211 | 1,022,500 | **1,022,500** |
| Alfalah 1212 | 2,447,500 | **2,447,500** |
| HBL 1213 | 2,222,000 | **2,222,000** |
| **Owned banks+cash total** | **7,690,000** | **7,690,000** |
| Agent advance 1180 (S6 residual) | 3,346,000 | **3,346,000** |

### Bank movement plan (PKR)

| Flow | Meezan | Alfalah | HBL |
|------|--------|---------|-----|
| Opening | +6,000,000 | +3,000,000 | +3,000,000 |
| D1 cust | +400,000 | +287,500 | — |
| D1 agent pay | −700,000 | −500,000 | −500,000 |
| D2 cust | +140,000 | +140,000 | — |
| D2 agent | — | — | −278,000 |
| D3 cust / agent | +382,500 | −380,000 | — |
| D4 cust / agent | −200,000 | — | +100,000 |
| S6 advance | −5,000,000 | — | — |
| S7 pays | — | −100,000 | −100,000 |
| **Closing** | **1,022,500** | **2,447,500** | **2,222,000** |

Third-party 350k is **absent** from this table by design.

---

## Agent PKR vs FX custody (keep separate)

### 1) PKR payable / advance

| Agent | Book | Amount | Meaning |
|-------|------|--------|---------|
| Agent A | `payable_pkr` on USD row | **356,000** | S7 remaining |
| Agent A | CNY/AED payable | **0** | Deal 1 & 3 settled |
| Agent B | CNY `payable_pkr` | **216,000** | Deal 4 remaining |
| Agent B | GL **1180** | **3,346,000** | S6 prepaid funds left |

Training-only GL **2100** net credit = **572,000** (= 356k + 216k). Company-wide 2100 also includes older DEMO/orphan lines — do not treat company-wide 2100 as the training payable total.

Deal 4 payable is **not** netted against S6 advance in the seed. A supported net view would require an explicit allocation/settlement RPC later; until then show both figures separately.

### 2) Owned FX in agent custody (`fx_agent_currency_balances`)

| Agent | CCY | Owned | Reserved | Available |
|-------|-----|-------|----------|-----------|
| A | CNY | 30,000 | 30,000 | 0 | Deal 1 undelivered |
| A | USD | 2,000 | 0 | 2,000 | S7 stock |
| A | AED | 0 | 0 | 0 | Delivered |
| B | USD | 3,000 | 0 | 3,000 | S6 inventory |
| B | CNY | 26,000 | 6,000 | 20,000 | S6 20k avail + Deal4 6k reserved |

**Never** sum USD+CNY+AED into one “inventory” total. Agent custody ≠ physical vault receipt.

### 3) Physical company vault

This dataset does **not** post foreign currency into a company vault location. Undelivered Deal 1 CNY and S6/S7 stock are recorded as **agent-held owned** balances only.

---

## Third-party payment rules (implemented)

RPC: `fx_record_deal_third_party_payment` (see funding SQL).

- Reduces customer/deal outstanding **once**.
- Reduces allocated agent payable (or can create advance when no payable) **once**.
- Journal: **Dr 2100 / Cr 1160** — **no** owned-bank debit/credit.
- Preserves payer, recipient agent, external bank label, amount, currency, date, reference, deal, allocation.
- Atomic + `fx_client_operations` idempotency + permission check.

Manifest op: `d1_third_party` → tx `75a8d9e1-13ed-4524-9871-bbf5a3edf7e3`  
Ref: `SAMPLE-TP-D1`.

---

## Key operation IDs (from manifest)

Full map: `SELECT result_json->'operation_ids' FROM fx_demo_seed_batches WHERE seed_version='AM_TRAINING_20261023_V1';`

| Op key | Transaction / entity id |
|--------|-------------------------|
| d1_third_party | `75a8d9e1-13ed-4524-9871-bbf5a3edf7e3` |
| s6_advance_5m | `a832891f-8e1d-41e1-ac66-f0d8e609bbcc` |
| s6_buy_usd / s6_buy_cny | `589f4e65-…` / `01ed5846-…` |
| s7_buy_credit | `456a5285-dd43-4862-88ed-11bf901e8990` |
| cash_xfer / office_expense | `b88778b5-…` / `92a4a080-…` |
| d5_remittance | `4c0a232f-e34d-492d-ab9a-a154fc672dc6` |

Deliveries use client-operation keys `AM_TRAINING_20261023_V1:dN_deliver` (idempotent); UUIDs may not be duplicated in `operation_ids` JSON.

---

## UI navigation (AM_DEMO)

1. Sign in to workspace **AM_DEMO**.
2. **Directory / Parties** — filter `TRAINING Client` / `TRAINING Agent`; open Agent A/B → bank details show SAMPLE external accounts.
3. **Chart of accounts / Cash & banks** — TRAINING 1113–1114, 1211–1213; confirm balances above.
4. **Deals** — open `DL-20261023-0001` … `0004`; check paid/due, delivery remaining, legs.
5. **Receive / Pay** — historical TRAINING movements appear with `AM_TRAINING_20261023_V1` descriptions; third-party line must not move bank.
6. **Agent balances / custody** — Agent A/B currency rows as in the table above.
7. **Remittances** — `RM-20261023-0001` status **draft**, paid 0.
8. **Reports / trial balance** — training journals balance; compare 1180 and TRAINING banks.

### Authenticated UI walkthrough (2026-10-23, deploy `cb8d6c3`)

Read-only; **no new financial posts**. Compared to SQL + this guide.

| Surface | Result vs guide/SQL | Notes |
|---------|----------------------|-------|
| Home KPIs (desktop + mobile) | **PASS** | Assets **18,470,100** / Equity **16,001,500** / Liabilities **1,807,000** match `fx_get_balance_sheet` |
| Currency Position Actual | **PARTIAL** | CNY **64,500** = vault 8,500 + agent-owned 56,000 (sums custody into “Actual”); PKR Actual **1,349,001** is vault cash only — **excludes** TRAINING banks 1211–1213 |
| Deals list 0001–0004 | **PASS** | Amounts/rates/status match; list “Recv” = **remaining receivable** (not paid) |
| Deal 1 detail + third-party line | **PASS** | Shows 400k + **350k third-party** + 287.5k; remaining due **1,037,500**; text includes `NO owned-bank movement [third_party]` |
| Parties TRAINING A–D / Agents A–B | **PASS** (visibility) | Present with codes `TRAIN_CLI_*` / `TRAIN_AGT_*` |
| Party directory PKR chips | **MISMATCH** | Control-account rollup ≠ deal dues / raw 1180: e.g. Agent B shows **3,130,000** (≈ 3,346,000 − 216,000 Deal4 payable netting); Client A **765,000** ≠ deal1 due **1,037,500**. Do not “fix” postings to match chips |
| Remittance list TT draft | **PASS** | `RM-20261023-0001` **DRAFT**, PKR 562,000 → USD 2,000 |
| Agent SAMPLE external banks in UI | **NOT RUN** | Party form bank tab not opened this session (API confirms SAMPLE rows) |
| Chart of accounts TRAINING bank balances | **NOT RUN** | Covered by home BS + SQL |
| Agent custody FX grid in UI | **NOT RUN** | “Show FX balances” expand not exercised; SQL custody table verified |
| Receive composer create UI | **EXERCISED** | Bank/Cash only — **no** third-party settlement method |
| Buy FX / advance-funded purchase UI | **NOT RUN** / **MISSING** | Hash to `currency_buy` did not land on buy form; code path is Pay later→2100 only (no 1180 advance funding) |

Evidence screenshots (local, not committed): `tmp/training_ui_evidence_20261023/`.

### Create-flow gap (separate from existing-data visibility)

| Workflow | Backend | UI create |
|----------|---------|-----------|
| Client pays agent’s external account (cashless third-party) | `fx_record_deal_third_party_payment` | **Missing** — MoneyMovementComposer `FxSettlementMethodToggle` is Bank/Cash only |
| Buy FX applying agent PKR advance (1180) | `fx_purchase_currency_funded` / advance funding in training SQL | **Missing** — draft Buy FX supports cash vs **credit (2100)** only |

Existing training rows **are** visible on deal detail / remittance / parties without those create UIs.

---

## Accounting notes & honesty

- Advances (1180) are **assets**, not expenses.
- Internal cash transfer is neither income nor expense.
- DEAL5 stays draft; full TT posting policy may remain product-limited — do not invent revenue/AR.
- Cost basis / rates used are exactly those in the scenarios; no invented rates.
- Pre-existing DEMO rows (e.g. DEMO agents, orphan 2100 debit 250k from 2026-10-21) remain untouched.

---

## Safe future reversal / cleanup (do **not** run now)

1. Prefer supported reverse/void RPCs per transaction in **reverse chronological** order within the training set only (filter descriptions / `client_operation_id` prefix `AM_TRAINING_20261023_V1`).
2. Never `DELETE` posted journal lines; use reversals so audit trail remains.
3. After all training txs reversed: remove TRAINING-only COA rows only if unused; clear `fx_demo_seed_batches` / `fx_training_manifest` row for `AM_TRAINING_20261023_V1` to allow a clean re-seed.
4. Leave DEMO_SEED_V1 and any real/non-training data alone.
5. Take a DB backup before any cleanup batch.

---

## Re-verify SQL (smoke)

```sql
-- Batch due
SELECT SUM(customer_receivable_pkr) FROM fx_deals
WHERE deal_no LIKE 'DL-20261023-000%';  -- expect 1357500

-- Banks + cash + 1180
SELECT a.code, a.name,
  SUM(jl.debit_pkr)-SUM(jl.credit_pkr) bal
FROM fx_accounts a
JOIN fx_journal_lines jl ON jl.account_id=a.id
WHERE a.company_id='a1111111-1111-4111-8111-111111111101'
  AND a.code IN ('1113','1114','1211','1212','1213','1180')
GROUP BY 1,2 ORDER BY 1;

-- Idempotent
BEGIN;
SELECT set_config('fx_reconciliation.confirm','APPLY_AM_TRAINING_20261023_V1',true);
SELECT fx_seed_am_training_20261023_v1()->>'idempotent';
COMMIT;
```
