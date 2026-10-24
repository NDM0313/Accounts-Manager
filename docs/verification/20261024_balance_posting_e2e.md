# Verification — 2026-10-24 balance measures, currency Actual, posting E2E

Tip started: `44bca1e` (`Wire third-party receive and advance-funded Buy FX through existing RPCs.`).  
Company: AM_DEMO `a1111111-1111-4111-8111-111111111101`.  
Training seed: `AM_TRAINING_20261023_V1` (not reseeded).

## 1. Party chip vs ledger vs deal outstanding

### Root cause

**Different valid measures, plus a labelling/query defect — not a posting defect.**

| Measure | Source | Client A (TRAIN_CLI_A) | Agent A | Agent B |
|---------|--------|------------------------|---------|---------|
| Unpaid deal amount | `SUM(fx_deals.customer_receivable_pkr)` | **1,037,500** | 0 | 0 |
| Control ledger net | Party-tagged posted journals on 1160/1180/1190/2100/2200/2300 | **142,500** | **706,000** (payable) | **−3,130,000** net |
| Agent advance 1180 | Same rollup, code 1180 only | 0 | 0 | **3,346,000** |
| Agent payable 2100 | Same rollup, code 2100 only | 0* | **706,000** | **216,000** |

\*Client A journals include Dr **2100** 350,000 from training third-party (tagged to customer) and Cr **1160** 1,037,500 − Dr 415,000; plus Dr **1190** 415,000 → net **142,500**.

**Pre-Y_ chip bug:** balances RPC omitted **1160**, so Client A chip was **765,000** (= 415k receivable + 350k third-party Dr 2100) while unpaid deals stayed **1,037,500**. Including 1160 corrects the control net; it still must **not** be forced equal to deal outstanding.

**Agent B chip −3.13M:** valid net of advance asset vs payable (3,346,000 − 216,000) under agent sign convention — confusing when shown as one number. UI now labels Advance / Payable separately.

Deal DL-20261023-0001: `customer_payable_pkr=2,075,000`, `customer_paid_pkr=1,037,500`, `customer_receivable_pkr=1,037,500`, status **delivered**.

### Fix shipped

- SQL: `Y_party_measures_currency_position.sql` — balances include 1160; new `fx_party_directory_measures`.
- Flutter: multi-line labelled chips; directory disclaimer.

## 2. Currency Actual PKR / banks

### Root cause

Extended Actual previously scanned vault-ish **1110** + FX inventory **1120–1150**, omitting TRAINING **1113/1114** and all **121x** banks. Legend called FX “vault” while 1120–1150 also hold agent-booked inventory.

### Definitions (after Y_)

| Metric | Meaning |
|--------|---------|
| Actual PKR | Owned **cash 111x + banks 121x** (physical/company liquidity). Excludes **1180** agent advance. |
| Actual FX | Company inventory GL **1120–1150** (may include agent-held stock booked there). ≠ `fx_agent_currency_balances` custody UI. |
| Committed / Required | Open customer_sale commitments vs actual / on_order. |

### Expected vs actual (branch AM_DEMO)

| CCY | Actual |
|-----|--------|
| PKR | **9,059,201** (= 1,349,001 1110 + 500 + 1,780,000 + 218,000 + 19,700 + 1,022,500 + 2,447,500 + 2,222,000) |
| CNY | **64,500** (GL 1140; includes agent inventory portion) |
| USD | **7,000** |
| AED | **4,000** |

No double-count of 1180 into PKR Actual. Agent custody remains a separate expand/ledger surface.

## 3. Posting E2E (AM_E2E_20261024_UI)

Authenticated as `ndm313@yahoo.com` / `50512623-c99f-4829-a566-01239f1effb6` via JWT claim in SQL (transaction-local `set_config`).

### Round 1 (pre-Z_)

| Check | Result |
|-------|--------|
| Oversized third-party | PASS reject (exceeds outstanding) |
| Third-party 1000 idempotent | PASS `74a377fa-…` |
| Journal balanced; accounts only 2100/1160 | PASS |
| Owned 111x+121x unchanged | PASS (9,059,201) |
| Advance buy USD1@278 idempotent | PASS `7452a2ad-…`; 1180 3,346,000→3,345,722 |
| Huge advance numeric overflow | Soft (overflow, not business rule) |
| Concurrent same op key | PASS |
| Void journals | PASS; audit retained |
| Agent B USD custody / agent_payment leg / deal status | **FAIL residual** — void incomplete |

### Defects found & fixed in `Z_void_auth_advance_ceiling.sql`

1. **`fx_has_permission`:** `current_setting('fx_seed.active')` NULL made OR-chain NULL → `IF NOT permission` skipped → **Unauthorized bypass** when `auth.uid()` null. Fixed with COALESCE + require non-null uid on legacy role path.
2. **Void unwind:** only reversed `customer_payment` legs; left `agent_payment` completed; did not restore agent payable / currency_buy owned qty. Extended unwind + `fx_unwind_agent_currency_buy_for_voided_tx`.
3. **`fx_recompute_deal_status`:** delivery early-return left status stuck at `customer_partially_paid` after third-party overwrite. Now restores **delivered** when a live delivery leg exists.
4. **Advance ceiling:** advance mode now refuses when party-tagged 1180 < required PKR.

### Repair of training after round 1

Manual reverse of leftover agent_payment leg 13; Agent B USD −1 / −278 carrying; recompute → **delivered**. Training GL measures restored to pre-E2E.

### Round 2 (post-Z_)

| Check | Result |
|-------|--------|
| No-JWT third-party | PASS `Unauthorized` (`can_post=f`) |
| Agent A insufficient advance | PASS `available 0 required 100` |
| Third-party 500 + advance buy + void | PASS txs `cf4692eb-…` / `605cf81f-…` |
| After void: Agent B USD=3000, deal=delivered, legs reversed | PASS |

Browser-authenticated create via Flutter UI: **NOT RUN** this session (SQL RPC path exercised with same auth.uid() + permissions). UI wiring was already at `44bca1e`.

## 4. UI checks

| Item | Evidence | Status |
|------|----------|--------|
| TT draft RM-20261023-0001 | SQL `status=draft`, payout 2000 USD | PASS (data) |
| Agent SAMPLE external banks | SQL SAMPLE Meezan/HBL + IBAN | PASS (data); form tab browser **NOT RUN** |
| Custody expand / list API | `fx_list_agent_custody` + list-tile expand code | PASS (API+code); interactive expand **NOT RUN** |
| 390/834/1440 × light/dark | — | **NOT RUN** (no authenticated browser matrix this session) |
| Deals / Buy FX B→A | Stitch widgets already on deal detail; Buy Advance wired; Figma MCP **unavailable** | No pixel claim; layout polish remaining |

## 5. SHAs / deploy

Filled at release time in the final report section below / git tags.

### SQL apply markers

- Y_: `APPLY_OK_20261024T083452Z` (prior turn)
- Z_: applied 2026-10-24 with this verification

## Honest remaining

- Authenticated Flutter browser posting / viewport screenshot matrix
- Full Figma node parity for deals/draft bodies
- Global 1180 ceiling (party-tagged only) — agents without party-tagged advance lines still edge-case
