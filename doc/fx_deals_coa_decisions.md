# FX Deals — COA & Configuration Decisions

Approved as part of FX Deal workflow implementation (Cloud project `ygidlcqhupmxvsdjmvnf` only).

| Decision | Choice |
|----------|--------|
| Customer advance account | **1160 Customer Advances** (new liability) — not repurposing 2200 |
| RMB display | Maps to existing **CNY** currency code and cash account **1140** |
| Short position | **Default false** — `allow_short_position` on deal must be explicitly set |
| Clearing accounts | **1170** FX Delivery Clearing, **2310** Agent Settlement Clearing, **2320** Cross-Currency Clearing |
| Deal statuses | 14 values as specified in workflow analysis |
| Leg statuses | `pending`, `partial`, `completed`, `failed`, `reversed` |
