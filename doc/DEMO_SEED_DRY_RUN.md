# FXDEV Demo Seed — Dry-Run Report

**Status: WORKFLOW POSTED** — 2026-06-10 on Supabase Cloud `ygidlcqhupmxvsdjmvnf` (FXDEV / MAIN only).

Target: company **FXDEV**, branch **MAIN**. Old ERP VPS untouched.

---

## Pre-flight (completed)

1. `dry_run_dev_data_counts.sql` — reviewed counts
2. `reset_dev_fx_data.sql` — **not run** (per guardrails)
3. `seed_realistic_fx_demo.sql` — 8 DEMO parties + reference rates
4. Migrations `202606210003` + `202606210004` — full `fx_seed_fxdev_demo` RPC
5. `SELECT fx_seed_fxdev_demo('FXDEV_DEMO_SEED');` — **posted**

---

## Dry-run plan (expected before posting)

### Parties used

| Code | Role | Scenarios |
|------|------|-----------|
| DEMO_CHINA_RMB | Agent | CNY buy (credit) |
| DEMO_ASAD | Customer | CNY sell + partial PKR payment |
| DEMO_DIN | Customer | USD deal order + TT |
| DEMO_WALI | Agent | USD sourcing + partial settlement |
| DEMO_KABUL_AFN | Agent | AFN buy |
| DEMO_KHAN | Customer | AFN sell |

### Opening balance (scenario 1)

| Item | Plan |
|------|------|
| PKR / USD / AED / CNY / AFN cash | Dr cash accounts → Cr Owner Capital (3100) |
| **Actual** | Branch already had **posted opening balance batch** (5 lines from wizard). Seed **skipped new OB** (`opening_balance: already_posted`). Existing OB provides PKR/USD/AED equity offset. |

### Transactions posted (`[DEMO]` marker)

| # | Type | Description | PKR impact (approx) |
|---|------|-------------|---------------------|
| 1 | currency_buy | Buy 50,000 CNY @ 39 from DEMO_CHINA_RMB (credit) | Dr 1140 / Cr 2100 — 1,950,000 |
| 2 | currency_sell | Sell 8,000 CNY @ 41.5 to DEMO_ASAD (credit) | Dr 1190 / Cr 1140 — 332,000 |
| 3 | settlement_receive | ASAD partial PKR payment | Dr 1110 / Cr 1190 — 150,000 |
| 4 | currency_buy | Receive 3,000 USD @ 278 from DEMO_WALI (credit) | Dr 1120 / Cr 2100 — 834,000 |
| 5 | settlement_send | Partial payment to DEMO_WALI | Dr 2100 / Cr 1110 — 250,000 |
| 6 | currency_sell | USD TT delivery (deal confirm) | Deal P/L + spread |
| 7–10 | expense | Bank, courier, agent commission, office | Dr 5xx0 / Cr 1110 — 28,500 |
| 11 | currency_buy | Buy 50,000 AFN @ 3.2 from DEMO_KABUL_AFN | Dr 1151 / Cr 1110 — 160,000 |
| 12 | currency_sell | Sell 20,000 AFN @ 3.35 to DEMO_KHAN | Dr 1110 / Cr 1151 — 67,000 |

### Deals

| Deal no | Customer | Flow |
|---------|----------|------|
| DEMO-DIN-USD-001 | DEMO_DIN | 3,000 USD @ 282, 500,000 PKR advance → sourcing leg (DEMO_WALI) → USD receipt → partial agent pay → **completed** TT |

### Expected trial balance

- Total debits = total credits (balanced)
- Agent payable (2100) credit balance remains after partial pay
- Customer receivable (1190) shows ASAD CNY sale balance + DIN deal receivable
- P&L expenses in 5200–5500; spread income in 4100

---

## Execution results (2026-06-10)

| Metric | Result |
|--------|--------|
| RPC status | `posted` |
| `[DEMO]` transactions | **12** posted |
| Demo deals | **1** (`DEMO-DIN-USD-001`, status **completed**) |
| Opening balance | Used existing posted batch |
| Trial balance | **Balanced** (Dr = Cr = 19,913,000 PKR) |
| AFN | Account **1151** — buy/sell posted |
| Admin actor | FXDEV profile (impersonated via JWT claim in RPC) |

### Key balances after seed (journal nets, PKR)

| Account | Net (Dr − Cr) |
|---------|----------------|
| 1110 Cash PKR | 778,500 |
| 1120 Cash USD | 3,058,000 |
| 1130 Cash AED | 3,787,500 |
| 1140 Cash CNY | 1,618,000 |
| 1151 Cash AFN | 93,000 |
| 1190 Customer receivable | 528,000 Dr |
| 2100 Agent payable | 3,034,000 Cr |
| 4100 Spread income | 12,000 Cr |

### Statements to test in app

1. **DEMO_ASAD** — CNY sell + partial PKR payment → running balance
2. **DEMO_WALI** — USD buy on credit + partial settlement → payable remaining
3. **DEMO-DIN-USD-001** — deal timeline: order → sourcing → delivery → completed
4. **Trial balance** — balanced toggle + export
5. **Currency position** — PKR, USD, AED, CNY, AFN tiles
6. **P&L** — expense lines 5200–5500

---

## How to re-run (idempotent)

```sql
-- Only runs if no [DEMO] posted transactions exist
SELECT fx_seed_fxdev_demo('FXDEV_DEMO_SEED');
```

Or: `supabase/scripts/run_demo_workflow_seed.sql`

---

## Safety checklist

- [x] Cloud project `ygidlcqhupmxvsdjmvnf` only
- [x] No old ERP VPS / SSH / `supabase.dincouture.pk`
- [x] No reset script
- [x] Admin user/profile/roles preserved
- [x] FXDEV / MAIN scope only
- [x] Balanced journals only (via `fx_post_transaction`)

---

## Migrations

| File | Purpose |
|------|---------|
| `202606210003_fx_seed_fxdev_demo_impl.sql` | Helpers + initial RPC |
| `202606210004_fx_seed_fxdev_demo_fix.sql` | Fix deal payment (avoid manual_journal RPC) |
