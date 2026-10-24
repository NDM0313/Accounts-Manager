# Verification — mobile density + account-statement PDF

**Repo:** NDM0313/Accounts-Manager  
**Branch:** `feat/approved-figma-responsive-ui`  
**Local / remote HEAD:** (see deploy section; tip after FAB clearance follow-up)  
**Previous deployed:** `855e4c7` → first UI deploy `2af912c`  
**Public deployed:** tip SHA after FAB list-clearance follow-up  
**Rollback:** prior `fx_app_web_rollback_*` under `/home/ndm313/`

## Root causes

1. **GL mobile density:** decorative Cash & Bank hero + nested filter chrome consumed most of the viewport; desktop-style amount columns wrapped/clipped on narrow widths.
2. **Accounts chrome / FAB strip:** ledger hub reserved a full-width bottom inset panel for the + control instead of a true `FloatingActionButton` above bottom nav.
3. **Account-statement export:** Share/Export followed a plain/old transaction export path instead of the professional party-statement A4 renderer (wrong title/print wording).

## Screens changed

- `lib/features/reports/general_ledger_screen.dart` — compact summary, filter/account sheets, one scroll surface, mobile activity rows
- `lib/features/ledger/ledger_hub_screen.dart` — real FAB `endFloat`, no full-width strip
- `lib/features/ledger/transaction_list_screen.dart` (+ related stitch) — tighter chrome/chips/demo banner
- `lib/core/export/account_statement_pdf.dart` (new) — professional A4 account statement
- `lib/features/ledger/account_statement_export_sheet.dart` (new) — Simple/Detailed, audience, Print statement wording
- Model/export wiring for company meta, format, audience, period totals

## Before / after (mobile ~390)

| Surface | Before (problem screenshots) | After (`2af912c`) |
|--------|------------------------------|-------------------|
| Transactions | Full-width empty + strip; large title chrome | Compact DEMO banner; tabs+search; **~6 fully visible TX rows**; FAB `New transaction` (no reserved strip) |
| General Ledger | Large decorative Cash & Bank card; tiny data area; wrapped amounts | Compact summary + Filters sheet + account picker; **~4 fully visible activity rows** with Movement / Debit·Credit labels; amounts readable |
| FAB | Full-width bottom panel | Scaffold FAB above bottom nav; list paints behind |

Evidence: `tmp/mobile_density_evidence_20261024/after_{tx,gl,tx_fab}_390.png`

## PDF evidence (opened + rendered)

Files: `tmp/account_statement_pdf_review/account_1110_{simple,detailed}.pdf`  
Rasters (pdftoppm): `tmp/account_statement_pdf_review/renders/{simple,detailed}-{1..3}.png`  
Text extract (`pdftotext`) confirms headers/table/DEMO/page numbers.

| Check | Simple | Detailed |
|-------|--------|----------|
| Magic / pages | `%PDF` / **3 pages** | `%PDF` / **3 pages** |
| Title | Account statement · Internal · Simple | Account statement · External · Detailed |
| Account | Cash PKR · 1110 · Asset · debit-normal | same |
| Totals | O 100,000.00 / D 29,290.50 / C 22,071.50 / Cl 107,219.00 | same |
| Recon | closing = opening + debits − credits | **PASS** (fixture + PDF match) |
| FX narrative | — | e.g. `· 15.00 USD` on detailed lines (recorded qty; no invented rates) |
| Repeated headers / page # | Page 1–3 of 3; continued header on p2–3 | same |
| DEMO banner | present | present |

## Tests / build

- `flutter test test/domain/account_statement_pdf_generate_test.dart` — PASS
- `flutter analyze` on touched GL/ledger/export — No issues (prior run)
- `flutter build web` — artifact deployed (`main.dart.js` 5,509,997 bytes)

## NOT RUN / PARTIAL

- Widget golden matrix for every width 360/430/834/1440 + large text — **PARTIAL** (390 + 360 captured; tablet/desktop visual pass not fully screenshot-matrixed this turn)
- In-app Share sheet interaction screenshot on device — **NOT RUN** (code path + wording verified in source; PDF generation verified offline)
- `Printing.raster` in unit tests on Windows — **NOT RUN** (MissingPlugin); substituted remote `pdftoppm` + visual PNG inspect
- Demo reseed / financial postings / SQL migrations — **intentionally NOT RUN**
- ERP / Dokploy / DB records — **untouched**

## Rollback

```bash
# on dinserver
rsync -a /home/ndm313/fx_app_web_rollback_20261024T142441Z/ /home/ndm313/fx_app_web/
```
