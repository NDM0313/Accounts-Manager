# Accounting policy decisions (P1–P6)

| ID | Decision | Classification | Implementation stance |
|---|---|---|---|
| P1 | Meaning of **“TTP”** | **Unresolved business rule** | No code assumes TTP meaning. Delivery proof field remains free-text. |
| P2 | FX inventory **cost basis** (FIFO / WA / explicit lots) | **Partially established** by user: never default cost to sale / zero profit. Method choice still business. | Delivery requires explicit `cost_basis_pkr` per slice. `fx_accounting_policies.cost_basis_method` persisted; NULL = not configured. |
| P3 | Whether **refund** reverses commission | **Unresolved business rule** | `fx_accounting_policies.refund_reverses_commission` nullable; refund RPC currently reverses cash/liability only — commission reversal **disabled** until configured. |
| P4 | Agent settlement **due basis** | **Unresolved business rule** | `settlement_due_basis` nullable on policy table; partial settlement uses explicit `p_amount` (no silent receive≠payout conversion). |
| P5 | Unrealized FX revaluation | **Unresolved business rule** | Revaluation posting not enabled in this release. |
| P6 | Cross-currency leg fees bearer | **Unresolved business rule** | Fee auto-allocation not implemented. |

**Technical choices (autonomous):** idempotent `client_operation_id` + `request_hash`; proportional partial delivery; A6 currency↔PKR recon RPC; FOR UPDATE on money RPCs.

**Rule:** reports and RPCs must **not** default missing purchase cost to sale value.
