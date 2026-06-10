# Deal Workflow Guide — UI Spec

## Panel placement

Deal detail screen, above action chips:

1. **Status banner** — human label + deal status color
2. **Next action** — title + primary button (one CTA)
3. **Warning** — e.g. "USD not available in own balance"
4. **Checklist** — expandable step list

## Checklist steps

1. Customer Order
2. Customer Payment (if receivable)
3. Sourcing Requirement
4. Agent Source
5. Cross-Currency Source (optional)
6. Agent Payment
7. Currency Receipt
8. Delivery / TT Confirmation
9. Profit/Loss Finalization
10. Completed

Each row: pending | completed | partial, amount/currency, party, attachment count badge.

## Next-action rules

| Condition | Primary CTA |
|-----------|-------------|
| Open + sourcing leg pending | Source Currency → `/legs/agent-source` |
| agent_source, no agent_payment | Pay Agent → `/legs/agent-payment` |
| agent paid pending, no receipt | Currency Receipt → `/legs/currency-receipt` |
| Sourced, not delivered | Confirm Delivery → `/delivery` |
| customerReceivablePkr > 0 | Receive Payment (dialog) |
| completed | Review P/L |

Secondary actions move to overflow menu on panel.
