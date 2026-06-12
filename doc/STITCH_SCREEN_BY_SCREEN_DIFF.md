# Stitch Premium UI — Screen-by-Screen Diff (A2Z)

**Source of truth:** `stitch_fx_ledger_premium_ui_ux/*/code.html` section order + `screen.png` visual QA  
**Tokens:** `stitch_fx_ledger_premium_ui_ux/executive_fx_ledger/DESIGN.md`  
**Updated:** 2026-06-12 — Stitch 4 Sub-Pages exact replica sprint

| # | Stitch mock | Flutter target | Status |
|---|-------------|----------------|--------|
| 1 | `login_screen` | `lib/features/auth/login_screen.dart` | **Pass** |
| 2 | `home_dashboard` | `lib/features/dashboard/dashboard_screen.dart` | **Pass** |
| 3 | `new_transaction_menu` | `lib/core/widgets/premium/fx_transaction_menu_sheet.dart` | **Pass** |
| 4 | `new_customer_fx_deal` | `lib/features/deals/new_customer_fx_order_screen.dart` | **Partial** |
| 5 | `deal_detail_workflow` | `lib/features/deals/deal_detail_screen.dart` | **Pass** |
| 6 | `agent_source_leg` | `lib/features/deals/agent_source_leg_screen.dart` | **Pass** |
| 7 | `receive_payment_1` | `lib/features/transactions/receive_payment_screen.dart` | **Pass** |
| 8 | `rate_board` | `lib/features/rates/rate_board_screen.dart` | **Pass** |
| 9 | `general_ledger_overview` | `lib/features/reports/general_ledger_screen.dart` | **Pass** |
| 10 | `reports_hub` | `lib/features/reports/reports_hub_screen.dart` | **Pass** |
| 11 | `settings_security` | `lib/features/settings/settings_screen.dart` | **Pass** |
| 12 | `opening_balance_wizard` | `lib/features/opening_balance/opening_balance_wizard_screen.dart` | **Pass** |
| 13 | `global_remittance_payout` | `lib/features/remittance/remittance_detail_screen.dart` | **Pass** |
| 14 | `share_export_options` | `lib/core/widgets/premium/fx_export_hub_sheet.dart` | **Pass** |
| 15 | `share_secure_link_configuration` | `lib/features/share/share_secure_link_screen.dart` | **Pass** |
| 16 | `internal_team_chat` | `lib/features/messaging/conversation_room_screen.dart` | **Pass** |
| 17 | `transaction_audit_chat` | `lib/features/transactions/transaction_audit_screen.dart` | **Pass** |
| 18 | `agent_statement` | `lib/features/parties/widgets/agent_ledger_stitch_view.dart` | **Pass** |
| 19 | `customer_statement` | `lib/features/parties/widgets/customer_ledger_stitch_view.dart` | **Pass** |
| 20 | `transaction_confirmation` | `lib/core/widgets/premium/fx_confirm_transaction_dialog.dart` | **Pass** |
| 21 | `attachment_proof_preview` | `lib/features/attachments/attachment_preview_screen.dart` | **Pass** |
| 22 | `executive_fx_ledger` | `lib/app/theme/*` + shell | **Pass** |

---

## home_dashboard

### Stitch sections
1. Shell app bar — FX Cash Ledger, refresh, avatar
2. Rate strip marquee
3. KPI grid 2×2 / 4-col — Cash, Receivables, Payables, Today's Profit
4. Quick Actions — 4 fixed circular buttons
5. Currency Position bento grid — wallet watermark, Actual/Committed/Required
6. Next Actions rows with icon circles

### PNG checklist
- [x] `DashboardKpiRow` 4 tiles + profit card styling
- [x] 4 quick actions `spaceBetween` (no horizontal scroll)
- [x] `FxCurrencyPositionCard` grid bento
- [x] `FxNextActionRow` with status-colored icon circles

### Status: **Pass**

---

## login_screen

### Stitch sections
1. Logo (no card wrapper)
2. Welcome Back + subtitle
3. Caps-label icon fields (email, password + forgot link)
4. Sign In CTA + OR SECURE ACCESS divider + Use Biometrics
5. Contact Admin footer + shield decoration

### PNG checklist
- [x] `FxStitchLoginForm` open layout on `#F8F9FF`
- [x] 48px rounded-xl bordered inputs with mail/lock icons
- [x] Biometric outlined button + footer link

### Status: **Pass**

---

## new_customer_fx_deal

### Stitch sections
1. Customer search field
2. Currency pair + booking date + large amount
3. Exchange Rates card (SPREAD badge, Reference vs Deal rate)
4. Delivery 3-segment control
5. Total Payable navy card
6. What happens next info card
7. Create Deal CTA

### PNG checklist
- [x] Drop `FxPageScaffold` / Obsidian panels
- [x] `FxStitchExchangeRatesCard`, delivery segments, total payable, what-happens-next
- [x] Full-width Create Deal bottom CTA
- [ ] Pixel-perfect rate boxes vs PNG

### Status: **Partial**

---

## deal_detail_workflow

### Stitch sections
1. App bar — deal no + IN PROGRESS pill + refresh
2. Summary 2x2 card
3. Bento row — Lifecycle (2/3) | Next Action + Deal Health (1/3)
4. Timeline steps — VIEW PROOF / ADD PROOF / LOCKED per step
5. Bottom 3 outlined buttons — View Statement | Share Deal | View Journal

### PNG checklist
- [x] `FxStitchDealSummaryCard` (2×2 summary)
- [x] `FxStitchWorkflowTimeline` with right-aligned proof actions (VIEW / ADD / LOCKED)
- [x] `FxStitchDealNextActionCard` + `FxStitchDealHealthCard` in sidebar column
- [x] `LayoutBuilder` wide 2-col / narrow stack
- [x] Status pill in AppBar actions (tertiary-container border)
- [x] `FxStitchDealBottomBar` — 3 equal outlined buttons
- [x] Proof tap handler (snackbar / route stub)

### Status: **Pass**

---

## customer_statement

### Stitch sections
1. AppBar — back + Customer Ledger + share
2. Hero — watermark, name, PREMIUM CLIENT pill, Active, Net Balance
3. Exposure Portfolio — horizontal flag chips
4. 2×2 bento — Opening / Debit / Credit / Closing
5. Statement Activity — filter, grouped white container, dashed debit/credit footer
6. Load Earlier Transactions
7. Bottom bar — vertical Receive Payment | Send Refund | Export PDF pill

### PNG checklist
- [x] `customer_ledger_stitch_view.dart` — section order per `code.html`
- [x] `FxStitchBalanceGrid` + `FxPartyHeroCard`
- [x] `FxStitchStatementListContainer` + embedded `FxStitchStatementRow`
- [x] `FxStitchStatementBottomBar` (vertical icons + Export PDF pill)
- [x] Removed open-deals section from customer tree

### Status: **Pass**

---

## agent_statement

### Stitch sections
1. AppBar — back + Agent Ledger + refresh + avatar
2. Institution block — INSTITUTION label, agent name, verified + Agent ID
3. 4 KPI bento — Currency Rcvd | Payable | Paid (navy) | Remaining (blue + progress)
4. Filter chips — All Deals / Pending / Disputed + FILTERS
5. Deal ledger rows (not transaction statement rows)
6. Transfer Lifecycle (Recent) — compact vertical timeline

### PNG checklist
- [x] `agent_ledger_stitch_view.dart` — distinct tree from customer
- [x] `FxStitchAgentInstitutionHeader`
- [x] `FxStitchAgentKpiBento` (4 colored cards)
- [x] `FxStitchAgentDealRow` + `FxStitchAgentTransferTimeline`
- [x] No customer hero / balance grid in agent mode

### Status: **Pass**

---

## settings_security → settings_screen

### Stitch sections
1. Profile tinted card
2. SECURITY / DATA MANAGEMENT / PREFERENCES / ABOUT
3. Red Sign Out
4. Extra: Workspace (Currencies, Opening Balance, Branch, Daily Closing)

### PNG checklist
- [x] `FxStitchSettingsSection` + tiles
- [x] Profile card `surfaceContainer` + secondary border avatar
- [x] Biometric toggle, export, theme
- [x] Red bordered Sign Out
- [x] Extra workspace sections same white card style
- [x] Pin change screen still separate route (unchanged)

### Status: **Pass**

---

## general_ledger_overview

### Stitch sections
1. Bento — Net Worth span-2 + Active Ledger + Last Settlement (sync badge)
2. Filter chips + Last 30 Days + More Filters
3. Two-column — Accounts (left border highlight) + Recent Ledger Activity table

### PNG checklist
- [x] `FxStitchGlBentoHeader`
- [x] `FxStitchGlFilterBar` + chips
- [x] `FxStitchAccountListColumn` selected left-border
- [x] `FxStitchGlActivityTable` table chrome

### Status: **Pass**

---

## receive_payment_1

### Stitch sections
1. AppBar — Receive Payment + refresh
2. Customer search field
3. 8+4 grid — amount/currency/method + allocation | Payment Summary sidebar
4. Post to Ledger CTA + Flow Analysis card
5. Narrow: stacked single column (approximates `receive_payment_2`)

### PNG checklist
- [x] `FxStitchReceivePaymentCustomerField` + amount/allocation cards
- [x] `FxStitchPaymentSummaryCard` navy sidebar + PARTIAL PAYMENT badge
- [x] `FxStitchReceivePaymentActions` Post to Ledger
- [x] Responsive 8+4 / stacked layout

### Status: **Pass**

---

## agent_source_leg

### Stitch sections
1. AppBar — Agent Sourcing + refresh + avatar initials
2. Workflow dots — Deal Setup → Agent Leg → Review
3. Bento — agent select + amount rows | Rate Comparison + PKR Equivalent + warning
4. Delivery Target — 3 radio cards
5. Footer CTAs — outlined Save Leg + filled Confirm Received
6. Proof upload section

### PNG checklist
- [x] `FxStitchAgentSourceForm` bento layout
- [x] Rate comparison navy card + PKR equivalent card
- [x] Delivery target radio cards (`FxDeliveryTarget`)
- [x] Dual CTAs (Save Leg / Confirm Received)
- [x] `FxPendingProofPicker` on create flow

### Status: **Pass**

---

## rate_board

### Stitch sections
1. AppBar — Live Rates + refresh
2. Status header — Last Updated + Manual Reference pill
3. 3-col BUY/SELL rate cards with edit icon
4. Derived cross pairs section

### PNG checklist
- [x] `FxStitchRateBoardHeader`
- [x] `FxStitchRateCard` BUY/SELL bento
- [x] `FxStitchDerivedRateChip` cross pairs
- [x] No FAB (edit per card)

### Status: **Pass**

---

## reports_hub

### Stitch sections
1. AppBar — Reports + refresh + avatar
2. Financial Intelligence hero + search
3. 3-col report cards with icon tiles + chevrons
4. Custom Analytics promo banner

### PNG checklist
- [x] `FxStitchReportsHero`
- [x] `FxStitchReportHubCard` grid
- [x] `FxStitchReportsCustomAnalyticsBanner`
- [x] Client-side search filter

### Status: **Pass**

---

## global_remittance_payout

### Stitch sections
1. MTCN header — copy + Ready for Payout pill
2. 7+5 bento — Transfer Summary, identity cards | Pickup/map/QR
3. Workflow actions + timeline + proofs
4. Compliance footer

### PNG checklist
- [x] `FxStitchRemittanceMtcnHeader`
- [x] `FxStitchRemittancePayoutLayout` wide 7:5 / narrow stack
- [x] Pickup location + map placeholder + Fast Track QR footer
- [x] `FxStitchRemittanceComplianceFooter`

### Status: **Pass**

---

## internal_team_chat

### Stitch sections
1. App bar — back + FX Cash Ledger + refresh + avatar
2. Day divider pill
3. Linked Transaction glass card
4. Chat bubbles (self navy / incoming with avatar)
5. Voice note bubble with waveform
6. Input dock — attach | pill input + emoji | send FAB

### PNG checklist
- [x] `FxStitchChatDayDivider`
- [x] `FxStitchLinkedTransactionCard` from conversation title
- [x] `FxChatBubble` + read receipt
- [x] `FxStitchVoiceNoteBubble` for file attachments
- [x] `FxStitchChatInputDock`

### Status: **Pass**

---

## attachment_proof_preview

### Stitch sections
1. AppBar — back + Preview Document + share / download / delete
2. 8+4 grid — preview (min-h 400/600, zoom/fullscreen) | sidebar
3. Sidebar — Attachment Info + Download + Share Secure Link
4. Document Audit compact timeline
5. Mobile metadata chips below preview

### PNG checklist
- [x] `FxStitchAttachmentSidebar` (info + actions + audit timeline)
- [x] Wide 8:4 `Row` / narrow stacked layout
- [x] AppBar share, download (`launchUrl`), delete confirm
- [x] Zoom + fullscreen overlay buttons on preview
- [x] Mobile deal/status meta chips

### Status: **Pass**

---

## new_transaction_menu → fx_transaction_menu_sheet

### Stitch sections
1. Backdrop blur + primary tint overlay
2. Bottom sheet — drag handle + headline-md title
3. Grouped white row cards (COMMON / FX DEALS / REMITTANCE / ADVANCED) with subtitles + chevrons

### PNG checklist
- [x] `FxStitchTransactionMenuList` + `FxStitchMenuEntryRow`
- [x] Backdrop tap-to-dismiss
- [x] White `surfaceContainerLowest` row cards

### Status: **Pass**

---

## opening_balance_wizard

### Stitch sections
1. AppBar — FX Cash Ledger + refresh + avatar
2. 5-step horizontal stepper (Setup → Review)
3. Warning alert on setup/currency steps
4. Currency position line cards
5. `FxStitchBottomActionBar` footer CTAs

### PNG checklist
- [x] `FxStitchOpeningBalanceStepper`
- [x] `FxStitchOpeningBalanceWarning`
- [x] `FxStitchOpeningBalanceCurrencyLine`
- [x] Obsidian shell removed

### Status: **Pass**

---

## share_export_options → fx_export_hub_sheet

### Stitch sections
1. Modal backdrop — blur + primary tint overlay
2. Bottom sheet — drag handle + “Share & Export” header + close
3. Optional context card — TRANSACTION REF + status pill + summary rows
4. Optional lifecycle timeline — check/pending vertical steps
5. Option rows — PDF / Print / Image / Email (48px circular icon, subtitle, chevron)
6. Footer — full-width **Copy Transaction Link** primary bar

### PNG checklist
- [x] `BackdropFilter` blur + semi-transparent overlay (matches transaction menu sheet)
- [x] `FxStitchExportSheetHeader` + drag handle
- [x] `FxStitchExportContextCard` when `refLabel` / `summaryLines` provided
- [x] `FxStitchExportLifecycleTimeline` when `lifecycleSteps` provided
- [x] `FxStitchExportOptionRow` — PDF, Print, Image, Email variants
- [x] `FxStitchExportCopyLinkButton` footer CTA (`shareUrl` or `textBody` fallback)
- [x] Existing export flows wired (`Printing.sharePdf`, `layoutPdf`, `share_plus`)

### Status: **Pass**

---

## share_secure_link_configuration → share_secure_link_screen

### Stitch sections
1. AppBar — Share Configuration + back + avatar initials
2. Summary card — document icon tile + deal title + generated date
3. Link Expiry — `FxExpirySegmentedControl` (1 Hour default) + schedule icon
4. Security Permissions — bordered cards with icon + toggle (Download, Password + field, Email verification)
5. Generated Link Preview — dashed border mono URL + Copy chip
6. Generate CTA — full-width secondary button with bolt icon
7. Audit footnote — “All shared links are logged in the Audit Ledger”

### PNG checklist
- [x] `FxStitchScaffold` replaces `FxPremiumScaffold` / `FxPremiumCard`
- [x] `FxStitchSecureShareSummaryCard`
- [x] `FxPermissionToggleRow` in bordered permission cards
- [x] `FxStitchSecureShareLinkPreview` dashed box + copy
- [x] `FxStitchSecureShareGenerateCta` bolt icon
- [x] Email verification toggle UI-only (no API / DB change)
- [x] `_generate()`, `_expiryFromIndex()`, password logic unchanged

### Status: **Pass**

---

## transaction_audit_chat → transaction_audit_screen

### Stitch sections
1. AppBar — transaction ref + status subtitle (green dot) + refresh + avatar
2. Audit trail badge — “Audit Trail Active • Thread ID: …”
3. Unified chat thread — received/sent bubbles, ledger ref card, system events, internal audit notes, voice attachments
4. Input dock — attach | pill input “Add a comment for audit…” | mic trailing

### PNG checklist
- [x] Removed `FxPremiumSegmentedTabs` Audit/Chat split
- [x] `FxStitchAuditTrailBadge`
- [x] Merged `auditLogsForEntityProvider` + `messagesListProvider` by timestamp
- [x] `FxStitchAuditReceivedBubble` / `FxStitchAuditSentBubble`
- [x] `FxStitchLedgerReferenceCard` inline in received bubble
- [x] `FxStitchInternalAuditNoteCard` left-border secondary note
- [x] `FxStitchSystemChatEvent` centered italic line
- [x] `FxStitchVoiceNoteBubble` for file attachments
- [x] `FxStitchChatInputDock` with `hintText` + `useMicTrailing`
- [x] Conversation via `getOrCreateEntityConversation` (same as conversation room)

### Status: **Pass**

---

## transaction_confirmation → fx_confirm_transaction_dialog

### Stitch sections
1. Modal backdrop — blur + dim overlay
2. Header — check-circle with ping ring + “Confirm Transaction” + subtitle
3. Summary card — Operation / Rate split + dashed divider + line items + info disclaimer
4. Actions — secondary-filled Confirm & Post + outlined Cancel
5. Gradient footer accent bar

### PNG checklist
- [x] Static ping ring around check-circle header (mock `animate-ping` approximated)
- [x] Dashed-style divider above line items in summary card
- [x] Confirm button `secondary` fill; Cancel outlined
- [x] Gradient footer bar retained
- [x] `FxConfirmTransactionDialog.show` API unchanged

### Status: **Pass**

---

## Shared Stitch component library

| Widget | Path |
|--------|------|
| `FxStitchCard` / `FxStitchScaffold` | `fx_stitch_scaffold.dart` |
| `FxStitchSettingsSection` | `stitch/fx_stitch_settings_section.dart` |
| `FxStitchBalanceGrid` | `stitch/fx_stitch_balance_grid.dart` |
| `FxStitchStatementRow` | `stitch/fx_stitch_statement_row.dart` |
| `FxStitchBottomActionBar` | `stitch/fx_stitch_bottom_action_bar.dart` |
| `FxStitchStatementBottomBar` | `stitch/fx_stitch_statement_bottom_bar.dart` |
| `FxStitchStatementListContainer` | `stitch/fx_stitch_statement_list_container.dart` |
| `FxStitchAgentInstitutionHeader` + KPI + deal rows | `stitch/fx_stitch_agent_widgets.dart` |
| `FxStitchDealBottomBar` | `stitch/fx_stitch_deal_bottom_bar.dart` |
| `FxStitchAgentSourceForm` | `stitch/fx_stitch_agent_source_form.dart` |
| `FxStitchAttachmentSidebar` | `stitch/fx_stitch_attachment_sidebar.dart` |
| `FxStitchDealSummaryCard` + timeline + health | `stitch/fx_stitch_deal_widgets.dart` |
| `FxStitchExchangeRatesCard` + form widgets | `stitch/fx_stitch_deal_form_widgets.dart` |
| `FxStitchAccountListColumn` | `stitch/fx_stitch_account_list_column.dart` |
| `FxStitchLoginForm` | `stitch/fx_stitch_login_form.dart` |
| `FxStitchGlBentoHeader` + filter + activity table | `stitch/fx_stitch_gl_widgets.dart` |
| `FxStitchRemittanceMtcnHeader` + payout layout | `stitch/fx_stitch_remittance_widgets.dart` |
| `FxStitchChatInputDock` + linked card + voice note | `stitch/fx_stitch_chat_widgets.dart` |
| `FxStitchTransactionMenuList` + menu rows | `stitch/fx_stitch_transaction_menu.dart` |
| `FxStitchOpeningBalanceStepper` + currency lines | `stitch/fx_stitch_opening_balance_widgets.dart` |
| `FxStitchRateCard` + rate board header | `stitch/fx_stitch_rate_card.dart` |
| Receive payment form + summary sidebar | `stitch/fx_stitch_receive_payment_widgets.dart` |
| Reports hub hero + cards | `stitch/fx_stitch_reports_hub_widgets.dart` |
| Export sheet context + option rows | `stitch/fx_stitch_export_widgets.dart` |
| Secure share summary + link preview + CTA | `stitch/fx_stitch_secure_share_widgets.dart` |
| Audit trail badge + ledger ref + audit note bubbles | `stitch/fx_stitch_transaction_audit_widgets.dart` |

---

## QA sign-off

- [x] Light mode default (`ThemeMode.light`)
- [x] Bottom nav: Home / Deals / Ledger / Reports / Settings (2px active border)
- [x] `flutter analyze` — clean
- [x] `flutter test` — 155 passed
- [x] Stitch 5 Pages replica — customer/agent ledger, deal detail, agent source, attachment preview
- [x] Stitch 6 Screens replica — login, dashboard, GL, remittance, team chat (+ executive tokens audit)
- [x] Stitch 7 Sub-Pages replica — transaction menu, opening balance, rate board, receive payment, reports hub, settings security
- [x] Stitch 4 Sub-Pages replica — share export, secure link, transaction audit chat, transaction confirmation
- [ ] Side-by-side 390px screenshot vs each P0 `screen.png` (manual visual QA)
- [x] Phase 5 backend wiring verification on new UI slots (messaging RPC smoke 2026-06-13; Team Chat / Transaction Audit / Secure Share wired)
