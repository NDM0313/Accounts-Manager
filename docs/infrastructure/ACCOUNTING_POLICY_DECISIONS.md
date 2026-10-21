# Unresolved accounting policy decisions

Do **not** invent these in code. Independent repairs in `H_accounting_repairs.sql` proceed without resolving them.

| ID | Decision needed | Risk if guessed |
|---|---|---|
| P1 | Meaning of **“TTP”** | Wrong product workflow |
| P2 | FX inventory **cost basis** (FIFO / weighted average / explicit lots) | Silent zero/wrong profit if sale used as cost |
| P3 | Whether **refund** reverses commission (and order vs liability) | P&L distortion |
| P4 | Agent settlement **due basis** (receive_amount PKR vs payout currency) | Over/under settlement |
| P5 | Unrealized FX revaluation rules/accounts | Balance sheet misstatement |
| P6 | Fees on cross-currency legs — who bears cost | Misallocated expense |

**Rule:** reports and RPCs must **not** default missing purchase cost to sale value.
