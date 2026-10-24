# Approved Figma implementation — working handoff

Source: https://www.figma.com/design/cbGKRRQZtyceFEiaDXDIP6  
Implementation branch: `feat/approved-figma-responsive-ui`  
Route matrix: [APPROVED_FIGMA_ROUTE_MATRIX.md](./APPROVED_FIGMA_ROUTE_MATRIX.md)

## Implemented (layout, not theme-only)

- Approved light/dark semantic palette, Manrope/Inter, system form tokens.
- Shared desktop sidebar / tablet rail / mobile bottom nav; **focused** money & OCR routes hide mobile bottom nav.
- **Receive/Pay composer (A):** single searchable party selector (Add new → auto-select), prominent amount + currency chip (no fake currency dropdown), Bank/Cash toggle that filters accounts, searchable vault picker, denser `FxFormBlock` layout, review retains method/account/ref, draft discard warning, double-post guard, slip `attachmentId` handoff.
- **OCR import (A):** progressive Capture → Review extracted fields → Choose action → composer/post. Capture-first (no full legacy form before image). Printed Pending/Failed stays visible and is not settlement proof. Bank name never auto-selects internal account. Raw OCR in expandable section; re-extract respects manual edits.
- Posted confirmation: success only when `status=posted`; customer-redacted share.

## Figma parity note

No Figma MCP/`use_figma` in this environment. Do **not** claim pixel/node parity. Material icons remain; approved SVG downloads pending.

## Verification

| Check | Status |
|-------|--------|
| `dart analyze` on touched files | infos/warnings only |
| Widget tests (`fx_searchable_select`, `fx_amount_entry`) | run before ship |
| `flutter test` suite | run before ship |
| Release web + OCR + cache-bust deploy | run before ship |
| Authenticated AM_DEMO layout screenshots 390/834/1440 | after redeploy |
| Prior labelled receipt `AM_UI_VERIFY_6287431_20261023` | reuse; do not duplicate |

## Guardrails

- No ERP / Dokploy / Cloudflare / Tailscale / shared-DB schema changes for UI work.
- Do not rerun previously applied SQL migrations.
- Financial UI testing only in **AM_DEMO**.
