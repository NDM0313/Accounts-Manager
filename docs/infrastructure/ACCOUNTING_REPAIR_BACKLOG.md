# Accounting repair backlog (updated)

**Gate:** Real-money use blocked until disposable PG17 scenarios PASS.  
**TTP:** unresolved (see `ACCOUNTING_POLICY_DECISIONS.md`).

| ID | Status | Where |
|---|---|---|
| A1 Per-agent USD/AED/CNY balances | **IMPLEMENTED (SQL)** | `H` → `fx_agent_currency_balances` |
| A2 Owned custody vs payable credit | **IMPLEMENTED (SQL)** | separate `owned_*` vs `payable_pkr` |
| A3 Reserve / release / consume | **IMPLEMENTED (SQL)** | `fx_agent_balance_*` helpers |
| A4 P&L component separation | **PARTIAL** | commission account tagging exists; cost/gain needs P2 |
| A5 Partial payment w/o duplicate commission | **IMPLEMENTED (SQL)** | `commission_recognized_pkr` |
| A6 Currency vs PKR recon report | **NOT IMPLEMENTED** (needs report RPC design) | — |
| A7 Partial settlement | **IMPLEMENTED (SQL)** | `settled_amount_pkr` + status rules |
| A8 Partial delivery proportion | **PARTIAL** | receipt path capped; full delivery RPC still legacy |
| A9 Receipt → specific source leg | **IMPLEMENTED (SQL+UI)** | H `fx_add_deal_leg_v2` + settlement screen |
| A10 Refund caps + idempotency | **IMPLEMENTED (SQL)** | `fx_refund_remittance` (+ UI still missing call) |
| A11 Locks + client_operation_id | **IMPLEMENTED (SQL+repo params)** | `FOR UPDATE` + `fx_client_operations` |

## Policy-dependent blockers

See `ACCOUNTING_POLICY_DECISIONS.md` (P1–P6). Independent fixes above do not invent cost=sale.
