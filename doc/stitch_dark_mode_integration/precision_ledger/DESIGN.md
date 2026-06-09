---
name: Precision Ledger
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#45464d'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#76777d'
  outline-variant: '#c6c6cd'
  surface-tint: '#565e74'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#131b2e'
  on-primary-container: '#7c839b'
  inverse-primary: '#bec6e0'
  secondary: '#006c49'
  on-secondary: '#ffffff'
  secondary-container: '#6cf8bb'
  on-secondary-container: '#00714d'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#2a1700'
  on-tertiary-container: '#b87500'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dae2fd'
  primary-fixed-dim: '#bec6e0'
  on-primary-fixed: '#131b2e'
  on-primary-fixed-variant: '#3f465c'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#ffddb8'
  tertiary-fixed-dim: '#ffb95f'
  on-tertiary-fixed: '#2a1700'
  on-tertiary-fixed-variant: '#653e00'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
  danger-soft: '#EF4444'
  background-dark: '#0F172A'
  surface-dark: '#1E293B'
  emerald-tint: '#ECFDF5'
  amber-tint: '#FFFBEB'
  red-tint: '#FEF2F2'
typography:
  currency-display:
    fontFamily: Hanken Grotesk
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  currency-display-mobile:
    fontFamily: Hanken Grotesk
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Hanken Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Hanken Grotesk
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-mono:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.05em
  label-caps:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.08em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  container-max: 1280px
  margin-desktop: 32px
  margin-mobile: 16px
  gutter: 20px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 24px
---

## Brand & Style

The brand personality is authoritative yet approachable, designed for financial professionals who require high precision without unnecessary cognitive load. This design system bridges the gap between traditional accounting rigor and modern fintech fluidity.

The design style is **Corporate / Modern** with a focus on **Tonal Layering**. It prioritizes information density and legibility, using a structured grid to instill a sense of security and mathematical accuracy. The aesthetic is "Clean-Industrial"—utilizing subtle borders, generous negative space to separate distinct financial entities, and high-contrast typography for critical data points like currency balances and conversion rates.

**Key Brand Pillars:**
- **Clarity over Decoration:** Visual elements must serve a functional purpose; decoration is minimized to avoid distracting from the ledger data.
- **Trust through Consistency:** Every interaction follows a strict logic to ensure the user feels in control of the underlying financial data.
- **Actionable Feedback:** Success, warning, and error states are distinct and immediate, providing a safety net for complex data entry.

## Colors

The palette is anchored by **Deep Navy (#0F172A)**, providing a stable, professional foundation that signals institutional reliability. 

### Functional Color Logic
- **Primary (Deep Navy):** Used for structural elements, headers, and primary navigation to ground the UI.
- **Success (Emerald Green):** Reserved for positive balances, completed transactions, and "Save" actions. In dark mode, this is used as a vibrant accent to draw the eye to positive outcomes.
- **Warning (Amber):** Utilized exclusively for system alerts, pending approvals, and locked closing warnings.
- **Delete/Danger (Soft Red):** A deliberate, non-aggressive red used for destructive actions (Delete) and error states. 

### Mode Implementation
- **Light Mode:** Uses a white background (`#FFFFFF`) with light gray borders (`#E2E8F0`). Secondary/Tertiary colors use soft tinted backgrounds for card highlights.
- **Dark Mode:** Transitions to a deep charcoal/navy background. Surface containers use elevated shades of navy (`#1E293B`) to maintain depth without losing the brand's core identity. Text contrast is pushed to maximum for high readability against dark backgrounds.

## Typography

This design system employs a three-tier font strategy to handle the diverse data requirements of an accounting ledger.

- **Headlines (Hanken Grotesk):** A sharp, contemporary Sans-Serif used for branding, page titles, and large currency displays. It provides a technical yet modern feel.
- **Body (Inter):** The workhorse for all UI labels, table data, and descriptions. Chosen for its exceptional legibility and neutral tone.
- **Labels (JetBrains Mono):** A monospaced font used specifically for transaction IDs, audit timestamps, and numerical data that requires vertical alignment in lists.

For **Large Currency Displays**, use the `currency-display` role. It features tight letter spacing and a heavy weight to command attention. On mobile devices, this automatically scales down to ensure the full amount remains visible without horizontal scrolling.

## Layout & Spacing

The system follows a **12-column Fixed Grid** for desktop views, centering content within a 1280px container to ensure financial tables don't become excessively wide and difficult to scan.

### Spacing Philosophy
- **Rhythm:** An 8px-based spacing system governs all margins and paddings, ensuring mathematical harmony across the UI.
- **Information Density:** For ledger tables, use "Compact" spacing (8px vertical padding). For detail screens and forms (like the Edit Transaction screen), use "Comfortable" spacing (16px to 24px) to reduce user fatigue during data entry.
- **Mobile Reflow:** On mobile, the 12-column grid collapses into a single-column stack. Horizontal margins reduce from 32px to 16px to maximize the space for numerical data. Cards should utilize full-width on mobile to avoid double-padding "traps."

## Elevation & Depth

Hierarchy is established through **Tonal Layering** rather than heavy shadows. This keeps the interface feeling "flat" and efficient, suitable for accounting software.

- **Level 0 (Background):** The base canvas. White in Light mode, Deep Navy in Dark mode.
- **Level 1 (Cards/Surfaces):** These are the primary containers for transactions and ledger entries. They use a subtle 1px border (`#E2E8F0` or dark equivalent) to define their boundaries.
- **Level 2 (Modals/Pop-overs):** Used for Delete Confirmations and Edit screens. These employ a soft, diffused shadow (15% opacity of the Primary color) with an 8px blur to lift the element above the workspace.
- **Interaction States:** Elements do not "lift" on hover; instead, they use a subtle background color shift (e.g., from White to a 2% Navy tint) to indicate interactivity.

## Shapes

The shape language is **Rounded**, striking a balance between the precision of a "Sharp" style and the friendliness of "Pill-shaped" designs.

- **Standard Components:** Buttons, Input fields, and Cards use a 0.5rem (8px) radius. This softens the technical nature of the ledger while maintaining a professional structure.
- **Currency Chips:** Use `rounded-lg` (1rem) to differentiate them from standard input fields, making them feel like distinct, touch-friendly objects.
- **Timeline Nodes:** In the Audit History screen, timeline indicators should be fully circular to provide a clear visual path for the user’s eye.

## Components

### Buttons
- **Primary (Edit/Save):** Solid Deep Navy with white text.
- **Success (Complete):** Solid Emerald Green.
- **Danger (Delete):** Solid Soft Red. Note: The Delete button in the confirmation modal should use a subtle shadow to emphasize the gravity of the action.
- **Secondary (Print/Share):** Transparent background with a 1px Navy border.

### Chips & Tags
- **Currency Chips:** High-contrast background (e.g., Emerald Green for positive, Soft Red for negative) with bold, monospaced text.
- **Status Tags:** Use tinted backgrounds (e.g., Amber-tint for "Pending") with darker text of the same hue for maximum readability and a clean "accounting" look.

### Input Fields
- **Accounting Inputs:** Large font sizes for Amount and Rate fields. Use a 1px border that turns Emerald Green when focused.
- **Reason Fields:** Multi-line text areas should always include a placeholder "e.g., Correction of entry error" to encourage detailed audit logs.

### Cards
- **Transaction Cards:** Group data logically with the Currency Display in the top right and Party details in the top left.
- **Audit Timeline Cards:** Use a left-aligned vertical line to connect cards. Highlight "Old Value" vs "New Value" using a strike-through for old values and a subtle green background for new values.

### Modals
- **Delete Confirmation:** Header text should be Soft Red. The primary action (Delete) must be on the right, with Cancel on the left to prevent accidental clicks.