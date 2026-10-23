# Approved Figma — route-to-design matrix

Source file: https://www.figma.com/design/cbGKRRQZtyceFEiaDXDIP6  
Branch: `feat/approved-figma-responsive-ui`  
Figma MCP / `use_figma`: **unavailable** in this Mac environment — frame node IDs are not claimed. Status uses checked-in system widgets + live screens.

Legend:
- **A** = Approved layout implemented (structure/hierarchy, not pixel claim)
- **B** = Legacy body with theme/chrome only
- **C** = No matching Figma frame; extended from approved components

| Route | Widget | Class | m/t/d | Gaps / notes | Verify |
|-------|--------|-------|-------|--------------|--------|
| `/` dashboard | `DashboardScreen` | A/B | yes | Semantic actions; KPI honesty | PASS (prior) |
| Shell nav | `FxWorkspaceNavigation` / `FxMainNavBar` | A | yes | Material icons (SVG pending) | PASS |
| `/transactions/money` Receive/Pay | `MoneyMovementComposerScreen` | **A** | yes | Searchable party/deal/account; amount chip; focused flow; draft discard | PASS unit / browser pending redeploy |
| `/transactions/receive-payment` | same composer | A | yes | Alias of money receive | same |
| Review step | composer `_buildReview` | A | yes | Retains method/account/ref | PASS (prior live) |
| `/transactions/:id/complete` | `TransactionCompleteScreen` | A | yes | Posted-only success | PASS (prior live) |
| `/transactions/:id` | `TransactionDetailScreen` | B | yes | Theme + actions; not full frame rebuild | PARTIAL |
| `/slips/import` OCR | `ImportPaymentSlipScreen` | **A** | yes | Progressive Capture→Review→Action | PASS unit / browser pending |
| Buy/Sell / transfer draft | `DraftTransactionScreen` | B | yes | Needs layout pass | NOT RUN |
| `/deals*` | deal screens | B | yes | Chrome applied | PARTIAL |
| `/expenses` | `ExpenseListScreen` | B | yes | | PARTIAL |
| Opening balances | wizard | B | yes | | PARTIAL |
| `/parties*` | list/form/ledger | B→mixed | yes | Ledger data OK | PARTIAL |
| `/accounts*` COA / new cash | accounts | B | yes | | PARTIAL |
| Reports / GL / roznamcha | reports | B | yes | No take() truncation on GL | PARTIAL |
| Attachments preview | `AttachmentPreviewScreen` | B | yes | | PARTIAL |
| Settings / audit / messages | various | B | yes | | PARTIAL |
| Dialogs / pickers | Material + system | C | — | Extended | — |

## This iteration (layout replacements)

- Shared: `FxSearchableSelect`, `FxAmountEntry`, `FxSettlementMethodToggle`, `FxFormBlock`, `FxFocusedFlowScope`
- Receive/Pay: replaced search+dropdown stacks with searchable selectors; amount+currency chip; denser blocks; hide mobile bottom nav on focused routes; unsaved draft warning
- OCR: capture-first progressive phases; action/party/account after review; composer handoff with `attachmentId`

## Remaining (honest)

- Exact Figma SVG icons / node-level parity: blocked without Figma tool access
- Full B→A rebuild for deals, draft buy/sell, expenses, reports bodies
- Authenticated screenshot matrix 390/834/1440 × light/dark after redeploy
