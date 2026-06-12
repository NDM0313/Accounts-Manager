---
name: Executive FX Ledger
colors:
  surface: '#f8f9ff'
  surface-dim: '#ccdbf4'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e6eeff'
  surface-container-high: '#dde9ff'
  surface-container-highest: '#d5e3fd'
  on-surface: '#0d1c2f'
  on-surface-variant: '#43474e'
  inverse-surface: '#233144'
  inverse-on-surface: '#ebf1ff'
  outline: '#74777f'
  outline-variant: '#c4c6cf'
  surface-tint: '#455f88'
  primary: '#002045'
  on-primary: '#ffffff'
  primary-container: '#1a365d'
  on-primary-container: '#86a0cd'
  inverse-primary: '#adc7f7'
  secondary: '#0058be'
  on-secondary: '#ffffff'
  secondary-container: '#2170e4'
  on-secondary-container: '#fefcff'
  tertiary: '#002617'
  on-tertiary: '#ffffff'
  tertiary-container: '#003e28'
  on-tertiary-container: '#00b47d'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d6e3ff'
  primary-fixed-dim: '#adc7f7'
  on-primary-fixed: '#001b3c'
  on-primary-fixed-variant: '#2d476f'
  secondary-fixed: '#d8e2ff'
  secondary-fixed-dim: '#adc6ff'
  on-secondary-fixed: '#001a42'
  on-secondary-fixed-variant: '#004395'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#f8f9ff'
  on-background: '#0d1c2f'
  surface-variant: '#d5e3fd'
typography:
  display-lg:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Manrope
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
  body-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  data-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  data-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
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
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  container-margin: 16px
  gutter: 12px
---

## Brand & Style
The design system is engineered for high-stakes financial environments where clarity, precision, and trust are paramount. It targets finance professionals and treasury managers who require a premium, mobile-first experience that feels as stable as a desktop accounting suite but as fluid as a modern consumer app.

The aesthetic is **Corporate Modern** with a lean toward **Minimalism**. It prioritizes a "data-first" hierarchy, using significant whitespace to prevent cognitive overload during complex FX deal management. The interface leverages soft rounded surfaces to humanize the technical data, creating an approachable yet authoritative atmosphere. The emotional response is one of controlled efficiency—stable, high-end, and meticulously organized.

## Colors
This design system utilizes a dual-mode palette optimized for varying environments. In Light Mode, the "Warm Off-White" background reduces eye strain during long accounting sessions, while the "Deep Navy" primary color establishes professional authority. 

Dark Mode shifts to a "Deep Charcoal" base to maintain depth, swapping the navy for "Electric Blue" to ensure high-visibility interactive elements against the dark surfaces. Success, Warning, and Danger colors remain consistent across both modes to maintain semantic meaning, though their background tints (for pills and alerts) should be adjusted for appropriate contrast ratios against the respective card colors.

## Typography
The typography strategy distinguishes between "Narrative" and "Data." **Manrope** is used for headlines to provide a modern, balanced character. **Inter** is used for all functional text. 

For financial ledgers and currency amounts, the `data` roles must explicitly enable `tabular lining` (tnum, lnum) CSS features to ensure that decimals and digits align perfectly in vertical columns, facilitating quick visual scanning of debits and credits. Small labels use heavy-weight uppercase with increased letter spacing to provide clear section headers without occupying excessive vertical space.

## Layout & Spacing
This design system follows a **Fluid Grid** model with a strict 4px baseline rhythm. On mobile, the system uses a 4-column layout with 16px side margins. As the viewport scales to tablet and desktop, the grid expands to 12 columns with a maximum container width of 1140px to maintain readability.

Information density is "Compact" but not crowded. Elements within a card use `sm` (8px) spacing, while the gap between separate card components uses `md` (16px). This creates a clear visual grouping where related financial data points are tightly bound, and distinct transactions are clearly separated.

## Elevation & Depth
Depth is communicated through **Tonal Layers** rather than heavy shadows. The background is the lowest level, followed by cards which sit on a subtle elevation.

- **Level 0 (Background):** Warm off-white or Deep Charcoal.
- **Level 1 (Cards):** White or Dark Graphite with a 1px solid border (#E9ECEF / #2D2D2D). 
- **Level 2 (Overlays/Modals):** Subtle ambient shadow (Y: 4px, Blur: 12px, 5% opacity black) to lift the element above the primary content.

The use of "Subtle Borders" is the primary method of containment, ensuring the UI remains crisp and "accounting-grade" rather than overly soft or pillowy.

## Shapes
The shape language is defined by a consistent **16px (1rem)** radius for all primary containers and cards. This specific roundedness bridges the gap between professional rigidity and modern app aesthetics. Smaller interactive elements like buttons and input fields inherit a 8px radius to maintain internal harmony within the larger 16px cards. Status pills use a full "Pill" radius for maximum distinction from other rectangular data blocks.

## Components
- **Buttons:** Primary buttons use the Deep Navy (Light) or Electric Blue (Dark) with white text. Height is fixed at 48px for mobile tap targets.
- **Status Pills:** Small, semi-transparent background fills with high-contrast text (e.g., Success green text on a 10% opacity green background).
- **Timeline Workflow:** Vertical lines connecting 24x24px nodes, using primary color for completed states and neutral grey for pending.
- **Statement Rows:** Use a 3-column distribution for Amount, Status, and Balance. Amount and Balance must use the `data-md` typography role for alignment.
- **Bottom Navigation:** 56px height, using 24px line-art icons. The active state is indicated by a color shift to the primary brand color and a 2px top-bar indicator.
- **Top Bar:** Fixed at 64px. Contains a centered branding element or title, with a 32px circular avatar on the right for user profile access.
- **Input Fields:** 1px border, 12px horizontal padding. Floating labels are preferred to maintain context in a compact layout.