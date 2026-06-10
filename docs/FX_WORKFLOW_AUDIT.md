# FX Deal Workflow Audit

**Project:** `ygidlcqhupmxvsdjmvnf` | **Date:** 2026-06-19

## Current UX

- Entry: General Hub → FX Deals → book at `/deals/new` → land on deal detail hub.
- Deal detail shows summary, flat action chips, timeline, P/L — **no guided next step**.
- Only `SourcingRequirementScreen` has explicit "Next steps" ListTiles.

## Status enum vs RPC reality

| Status | Set by backend today? |
|--------|----------------------|
| `booked`, `customer_partially_paid`, `customer_paid` | Yes — book + payment RPCs |
| `sourcing_required`, `sourcing_in_progress` | Yes — auto source + agent leg |
| `completed` | Yes — delivery RPC |
| `agent_partially_paid`, `agent_paid`, `currency_received`, `delivered` | **No — enum only** |
| `draft`, `quoted`, `cancelled`, `voided` | **No UI/RPC** |

## Leg types and gaps

| Leg type | UI | Posts journal? | Attachments today |
|----------|-----|----------------|-------------------|
| customer_order | Book RPC | No | None |
| sourcing_requirement | Auto | No | None |
| agent_source | Screen | No | Text notes only |
| cross_currency_source | Screen | No | proof_reference text |
| agent_payment | Screen | No | None |
| currency_receipt | Screen | No | None |
| customer_payment | Book / deal detail | Yes (linked tx) | Via transaction |
| delivery | Screen | Yes (linked tx) | Via transaction |

## Planned fix (this release)

- `DealWorkflowGuide` infers next action from deal + legs (no RPC change required initially).
- `DealWorkflowPanel` on deal detail: status banner, primary CTA, checklist.
- Per-leg attachments via `fx_attachments.deal_leg_id` migration.
