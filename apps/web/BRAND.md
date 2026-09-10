# Dabber Brand v1

**Status:** Owner-approved visual reference based on the approved brand board generated on 2026-09-11.

## Core identity

Dabber / دبّر is an Arabic-first household money-management brand. The approved identity uses a strong dark-navy Arabic wordmark, a terracotta accent above the mark, and a warm paper background. The identity should feel clear, calm, trustworthy, human, and premium rather than bank-like or accounting-heavy.

## Approved logo

Use `public/brand/logo-primary.svg` as the default master logo. These production-ready SVG wrappers preserve the exact owner-approved generated artwork; the embedded artwork is raster-derived from the approved board to avoid changing its forms during automatic vector tracing. The standalone product mark is `public/brand/mark.svg`. The PWA/home-screen icon is `public/brand/app-icon.svg`.

Do not recreate the logo with a font. The wordmark artwork is custom visual artwork and should be used as an asset.

## Palette

| Token | Hex | Role |
|---|---|---|
| Deep Navy | `#0F1C2B` | Trust, primary text, core mark |
| Terracotta | `#BA6649` | Action, identity accent |
| Sand | `#E7DDD3` | Soft surfaces |
| Sage | `#6F837B` | Calm secondary / balance |
| Paper | `#FAF5EF` | Primary background |

These colors are implementation starting points extracted/normalized from the approved board; functional UI contrast must still meet the project's WCAG 2.2 AA target.

## Logo usage

- Preserve clear space around the logo; use at least the visual height of the terracotta accent as minimum clear space.
- Prefer the paper background for the primary logo.
- Use the light logo variant on Deep Navy or similarly dark backgrounds.
- Use the standalone mark for favicon, compact mobile navigation, loading, and PWA icon contexts.
- Do not stretch, rotate, outline, recolor individual logo pieces arbitrarily, or add drop shadows to the mark.
- Do not substitute a generic finance icon, wallet, coin, or house for the Dabber mark.

## Arabic and English

Arabic is the primary brand context. `wordmark-ar.svg` is the Arabic identity artwork. `wordmark-en.svg` is the English companion. Both can appear independently; they do not need to be locked together in every context.

## Motion direction

Motion should be short and purposeful: settle, reveal, confirm. Avoid playful bouncing or perpetual movement. Always respect `prefers-reduced-motion`.

## Accessibility

WCAG 2.2 AA is the product target. Brand colors are not automatically safe for every text/background pairing; UI implementation must test functional contrast, focus, keyboard interaction, touch targets, and reduced motion.

## Source of truth

- Visual reference board: `public/brand/brand-reference-board.png`
- Master logo: `public/brand/logo-primary.svg`
- Mark: `public/brand/mark.svg`
- App icon: `public/brand/app-icon.svg`
- Tokens: `src/styles/brand-tokens.css`

## Change control

The approved logo/brand assets are an owner-level brand decision. Coding agents and Impeccable may apply and polish the identity, but should not redesign or replace these assets without owner approval.

## Design-system relationship

`PRODUCT.md` remains the source of truth for product behavior. This file fixes the approved Dabber Brand Identity v1. A future `apps/web/DESIGN.md` will document the Web UI design system and must derive from this Brand Kit without contradicting its logo, mark, wordmark, palette, token, or change-control rules.


## Production note

The approved artwork originated as a generated visual identity board. This kit intentionally preserves its approved optical shapes instead of auto-tracing them into crude polygonal vectors. If a fully hand-redrawn vector master is commissioned later, it must visually match this reference and requires owner approval before replacing these assets.
