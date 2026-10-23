# Approved Figma implementation — working handoff

Source: https://www.figma.com/design/cbGKRRQZtyceFEiaDXDIP6  
Implementation branch: `feat/approved-figma-responsive-ui`

## Implemented

- Approved light/dark semantic palette, Manrope headings, Inter body, bundled open-license fonts.
- Saved appearance preference (System/Light/Dark) in Settings + header quick toggle.
- Shared desktop 224px sidebar, tablet 80px rail, mobile bottom navigation; Back/Home on flat detail routes.
- Dashboard semantic action colours, compact metrics, responsive action grid (honest KPI labels).
- Shared form sections / status / metric styling inherited by existing screens.
- Receive/Pay composer: bounded form width, persistent review, Bank/Cash method shown on review, account label retained; posting RPCs unchanged.
- Posted-transaction confirmation: success chrome only when `status=posted`; amount/currency, party, cash/bank account, public reference, deal remaining when applicable; Figma pulse + reduced-motion; View / Share (customer-redacted) / Done.
- Attachment failures after a successful post do not imply the payment must be posted again.

## Figma parity note

No Figma MCP/integration was available in the Mac continuation environment. Exact SVG icon downloads remain pending; Material icons are still used. Do not claim pixel parity for every frame.

## Verification status (Mac continuation)

| Check | Status |
|-------|--------|
| `flutter analyze --no-fatal-infos` | Run on continuation (infos only) |
| `flutter test` | Run on continuation |
| Release web build + OCR + cache-bust | Run before each AM web deploy |
| Public deploy identity | See `.last_build_id` / `?v=` on https://fx.ndmcore.com |
| Authenticated AM_DEMO confirmation + attachment E2E | Requires browser; reuse labelled receipt when present — do not duplicate |

## Guardrails

- No ERP / Dokploy / Cloudflare / Tailscale / shared-DB schema changes for UI work.
- Do not rerun previously applied SQL migrations.
- Financial UI testing only in **AM_DEMO**.
- Placeholder CI config must never be deployed as production `client_config.json`.
