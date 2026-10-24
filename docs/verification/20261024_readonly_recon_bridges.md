# Read-only recon bridges — 2026-10-24 (tip `31f0c77` → post-fix `Z2_`)

Company AM_DEMO. Training batch `AM_TRAINING_20261023_V1` not reseeded.  
API tests use JWT claim impersonation of `ndm313` — **not** browser-click E2E.  
SQL/API does **not** prove TT draft / agent bank tab / custody expand UI visibility.

---

## 1. Client A: unpaid deals 1,037,500 → control ledger 142,500

Difference **895,000** explained in full (not waved away).

### Deal cash side (source of 1,037,500)

| Item | PKR |
|------|-----|
| Order `customer_payable_pkr` | 2,075,000 (CNY 50k @ 41.50) |
| Paid (400k Meezan + 350k third-party + 287.5k Alfalah) | 1,037,500 |
| **Unpaid field `customer_receivable_pkr`** | **1,037,500** |

### Live control journals on `TRAIN_CLI_A` (only)

| Tx | Accounts | Effect |
|----|----------|--------|
| Cust pay Meezan | Dr 1211 / **Cr 1160 400,000** | Advance |
| Third-party 350k `75a8d9e1-…` | **Dr 2100 350,000** / **Cr 1160 350,000** | Advance + agent payable allocation **tagged to customer** |
| Cust pay Alfalah | Dr 1212 / **Cr 1160 287,500** | Advance |
| Deliver 20k CNY `90209beb-…` | **Dr 1160 415,000** (clear advance) + **Dr 1190 415,000** (AR) / Cr 1140 820,000 + Cr 4100 10,000 | Delivery sell value 20k×41.5=**830,000**; paid-ratio 50% → half clears advance, half hits AR |

Active control sums: 1190 **+415,000**; 1160 **−622,500** (= Cr 1,037,500 − Dr 415,000); 2100 **+350,000**.  
**Control net = 415,000 − 622,500 + 350,000 = 142,500.**

### Bridge (every rupiah of the 895,000)

| Step | Description | Δ | Running |
|------|-------------|---|---------|
| 0 | Deal unpaid field | | **1,037,500** |
| 1 | Drop cash-due not sitting in 1190 — only delivered slice books AR (415k of 830k sell); undelivered 30k / unrecognised cash-due stays on the deal card only | **−622,500** | 415,000 |
| 2 | Recognise remaining unapplied advances on 1160 (receipts 1,037,500 − applied on delivery 415,000). Liability pulls control down | **−622,500** | −207,500 |
| 3 | Add third-party Dr 2100 on **customer** tag (not customer AR; mirrors agent payable allocation) | **+350,000** | **142,500** |

Check: 622,500 + 622,500 − 350,000 = **895,000**.

**Meaning:** Deal unpaid is cash settlement of the order. Control net mixes (a) partial delivery AR, (b) leftover advances, (c) third-party 2100 on the customer party. They are related but must not be forced equal. Postings above are consistent with training seed; **no journal repair**.

E2E third-party legs 12–15 are **reversed/voided** and excluded from live control.

---

## 2. Agent A payable: guide 356,000 vs chip 706,000

### Exact Agent A live 2100 rollup (party-tagged)

| Tx | Net Cr 2100 |
|----|-------------|
| Recognize Deal1 source | +2,050,000 |
| Agent bank pays 700+500+500 | −1,700,000 |
| **Deal1 residual on Agent A GL** | **+350,000** |
| Recognize Deal3 + pay | 0 |
| S7 credit buy 556k − pays 200k | **+356,000** |
| **Party chip / measures `agent_payable_pkr`** | **706,000** |

### Where the 350,000 direct payment went

Training third-party `75a8d9e1-…` / op `d1_third_party`:

- **Party on tx = Client A** (customer)
- Journal: Dr 2100 350k / Cr 1160 350k
- Deal legs 4–5 completed; agent_payment allocated to source
- Custody book: CNY payable reduced at post time (now **0** after repair below)

So company-wide training 2100 nets: Agent A +706k + Client A −350k + Agent B +216k = **572k** (= 356k + 216k), matching the guide’s training-only 2100 total.  
The **Agent A directory chip (706k)** is GL party attribution, not the guide’s **USD custody payable (356k)**. Extra **350k** is Deal1 source credit still on Agent A because the offsetting Dr 2100 was booked on the customer.

### E2E postings/voids

| Op | Tx | Result |
|----|-----|--------|
| `…:tp1` 1000 | `74a377fa-…` | voided; legs 12–13 reversed |
| `…:adv1` | `7452a2ad-…` | voided; 1180 restored |
| `…:r2_tp` 500 | `cf4692eb-…` | voided; legs 14–15 reversed |
| `…:r2_adv` | `605cf81f-…` | voided; USD owned 3000 restored |

**Phantom liability found:** after r2 void, Agent A **CNY `payable_pkr` = 500** (guide **0**).  
Cause: third-party used `GREATEST(0, payable − amt)` (no-op when already 0) then void restored **+amt** → phantom.  
**Correction applied (audited `edited` on balances row; journals untouched):** CNY payable 500 → **0**.  
**Code fix `Z2_`:** record `agent_payable_reduced_pkr` actually applied; void restores only that.

USD custody payable remains **356,000**. No extra live liability after repair.

---

## 3. Owned PKR: 9,059,201 vs training 7,690,000

| Bucket | Accounts | Amount |
|--------|----------|--------|
| Training | 1113, 1114, 1211, 1212, 1213 | **7,690,000** (matches manifest/guide) |
| Pre-existing DEMO | 1110 1,349,001 + 1112 500 + 1210 19,700 | **1,369,201** |
| **All owned (Y_ Actual PKR)** | 111x + 121x | **9,059,201** |

9,059,201 − 7,690,000 = **1,369,201** pre-training DEMO liquidity. Not a training defect.

---

## 4. Manifest / baseline vs current

| Metric | Expected | Actual | Status |
|--------|----------|--------|--------|
| Client A unpaid | 1,037,500 | 1,037,500 | PASS |
| Client A control (post-Y_) | 142,500 | 142,500 | PASS (explained) |
| Agent A USD custody payable | 356,000 | 356,000 | PASS |
| Agent A CNY custody payable | 0 | 0 (after repair; was 500) | PASS |
| Agent A GL 2100 party chip | 356k ≠ chip | 706,000 | **EXPLAINED** (350k customer-tagged TP) |
| Agent B 1180 | 3,346,000 | 3,346,000 | PASS |
| Agent B CNY payable | 216,000 | 216,000 | PASS |
| Training owned PKR | 7,690,000 | 7,690,000 | PASS |
| Custody A/B owned/reserved | guide table | match | PASS |
| Deal1 status | delivered | delivered | PASS |

Seed batch present with `operation_ids` including `d1_third_party=75a8d9e1-…`.

---

## 5. Z_ / Z2_ negative tests (API + JWT — not browser)

| Test | Result |
|------|--------|
| N1 null JWT `can_post`/`can_del` | **f / f** PASS |
| N2 null JWT third-party | Unauthorized PASS |
| N3 foreign company (before Z2) | Rejected as missing COA — **`fx_same_company` returned NULL** (bypass class) |
| N3 after Z2 | `fake=f`; **Unauthorized company/branch** PASS |
| N4 insufficient advance Agent A | PASS |
| N5 same-key retry voided op | Returns same voided id PASS |
| N6 different-key concurrent advance | 1 posts, 2nd insufficient; void cleanup; 1180=3,346,000 PASS |
| N7 repeat void | Already voided PASS |

**NOT RUN (genuine blockers for UI proof):** authenticated browser-click third-party / advance buy; remittance TT draft screen; party form SAMPLE bank tab; custody expand click; 390/834/1440 live screenshot matrix.

---

## Defects acted on this recon

1. **`fx_same_company` / `fx_same_branch` NULL OR-chain** → `Z2_same_company_payable_restore.sql`
2. **Third-party void payable phantom** → Z2 records applied reduction; audited balance edit clears CNY +500

## Remaining product/semantics (not silent bugs)

- Agent A **chip 706k** vs **custody USD 356k**: third-party Dr 2100 on customer by design; label chips accordingly (already multi-line). Optional future: also Dr Agent A 2100 or subledger allocation — would be a posting-model change, not done here.
- Client A unpaid vs control: delivery/advance accounting as bridged above.
- Browser UI visibility still unproven by this recon.
