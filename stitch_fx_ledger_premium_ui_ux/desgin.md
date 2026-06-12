# FX Cash Ledger - Design Specification

## Overview
A premium, mobile-first private internal multi-currency accounting and FX deal management application. Designed for clarity, professional utility, and an executive financial feel.

---

## 1. Brand Identity & Theme

### Visual Direction
- **Style**: Modern Fintech, Clean Accounting Dashboard.
- **Atmosphere**: Premium, professional, business-friendly, and non-technical.
- **Surface**: Warm off-white backgrounds with soft-rounded white cards.

### Color Palette (Light Theme)
- **Primary**: `#1A365D` (Deep Navy) - Used for brand identity, primary actions, and headers.
- **Secondary**: `#0056D2` (Royal Blue) - Used for navigation and interactive elements.
- **Success**: `#00875A` (Emerald Green) - Profits, positive balances, completed statuses.
- **Warning**: `#FFAB00` (Amber) - Insufficient balance, pending actions, risk alerts.
- **Danger**: `#DE350B` (Soft Red) - Negative balances, errors, critical warnings.
- **Surface**: `#F8F9FF` (Warm Off-white) - Main background.
- **Surface-Variant**: `#FFFFFF` (Pure White) - Card backgrounds.
- **Text Primary**: `#1E293B` (Dark Slate) - Headings and main body text.
- **Text Secondary**: `#64748B` (Slate Grey) - Labels, hints, and de-emphasized info.

### Typography
- **Primary Font**: Manrope (Sans-serif)
- **Scale**:
  - **Headlines**: Semi-bold to Bold.
  - **Body**: Regular.
  - **Numbers**: Tabular lining figures for scanability in ledgers.
  - **Labels**: Small uppercase with 0.05em letter spacing.

### Spacing & Shape
- **Grid**: 4px base unit.
- **Card Roundness**: 16px (Extra Large).
- **Button Roundness**: 8px to Full.
- **Container Margins**: 16px (Mobile).

---

## 2. Shared Components

- **Top App Bar**: Title, Back button, User Profile/Avatar, Refresh/Action icons.
- **Bottom Navigation**: 5 Tabs (Home, Deals, Ledger, Reports, Settings).
- **KPI Cards**: Elevated white cards with consistent padding (16px) and iconography.
- **Status Pills**: Rounded badges with background-opacity for status context (Paid, Pending, Warning).

---

## 3. Screen Inventory & UX Detail

### 1. Home Dashboard
- **Top**: Real-time multi-currency rate strip.
- **KPIs**: Total Cash, Receivables, Payables, Today's Profit.
- **Section**: Currency Position cards (PKR, USD, AED, CNY).
- **Section**: "Next Actions" task list.

### 2. New Customer FX Deal
- **Purpose**: Intake form for new transactions.
- **Key UX**: Visual separation between "Reference Rate" and "Deal Rate". Spread badge shown if rates differ. "What happens next?" explanation card.

### 3. Deal Detail & Workflow Timeline
- **Purpose**: Core operational screen.
- **Key UX**: Vertical step-by-step timeline (Customer Order -> Payment -> Sourcing -> Completion). Actionable "Next Step" primary button.

### 4. General Ledger Overview
- **Purpose**: Organization-wide liquidity view.
- **Content**: Net worth (USD Eq.), active currency count, detailed transaction log with multi-currency filtering.

### 5. Customer / Agent Statements
- **Format**: Professional financial document style.
- **Detail**: "Sold 10,000 CNY @ 42.50" style row descriptions. Running balance column. Export to PDF integration.

### 6. Global Remittance (Payout)
- **Purpose**: Western Union style cross-border transfer.
- **Content**: MTCN tracking number, Sender/Recipient details, Map-based pickup location, and secure bank-grade encryption notices.

### 7. Internal Collaboration
- **Internal Team Chat**: Treasury-wide messaging with voice note support.
- **Transaction Audit Chat**: Deal-specific chat threads for compliance and verification.

### 8. Security & Utility
- **Login**: Clean entry with Biometric (FaceID/Fingerprint) support.
- **Settings**: Security controls, Cloud backup, and Data export (JSON/CSV).
- **Opening Balance Wizard**: Multi-step onboarding for legacy data migration.
- **Rate Board**: Real-time rate management with history timelines.

---

## 4. Interaction Guidelines
- **Numbers**: Always format with appropriate currency symbols and decimal places (e.g., PKR 1.2M, USD 10,000.00).
- **Feedback**: Every critical action (Post to Ledger, Create Deal) requires a confirmation step and a success feedback state.
- **Navigation**: Persistent Bottom Nav for primary destinations; standard top-left Back arrow for sub-pages.
