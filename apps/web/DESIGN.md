---
name: Dabber Web Design System v1
description: Arabic-first financial clarity derived from the approved Dabber Brand v1.
status: APPROVED — DABBER WEB DESIGN SYSTEM v1
colors:
  paper: "#FAF5EF"
  navy: "#0F1C2B"
  terracotta: "#BA6649"
  sand: "#E7DDD3"
  sage: "#6F837B"
  success: "#416B60"
  warning: "#8A5B23"
  danger: "#A0443B"
typography:
  display:
    fontFamily: "Noto Sans Arabic, Tahoma, Arial, sans-serif"
    fontSize: "clamp(1.7rem, 6vw, 2.35rem)"
    fontWeight: 700
    lineHeight: 1.2
  body:
    fontFamily: "Noto Sans Arabic, Tahoma, Arial, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.6
  financial:
    fontFamily: "DM Sans, Noto Sans Arabic, sans-serif"
    fontFeature: "tabular-nums"
rounded:
  sm: "12px"
  md: "18px"
  lg: "28px"
spacing:
  2: "8px"
  4: "16px"
  6: "24px"
  8: "32px"
components:
  button-primary:
    backgroundColor: "{colors.terracotta}"
    textColor: "#FFFAF5"
    rounded: "999px"
    height: "56px"
  financial-track:
    backgroundColor: "{colors.navy}"
    rounded: "{rounded.lg}"
---

# Design System: Dabber Web

**STATUS: APPROVED — DABBER WEB DESIGN SYSTEM v1**

## Overview

**Creative North Star: "The Calm Allocation"**

Dabber's interface makes a shared month legible as a set of deliberate allocations, not as a stack of finance widgets. Paper, ink, and measured divisions carry the Brand v1 sense of calm trust; terracotta identifies intentional action, while sage identifies money that remains available. The system is compact enough for repeated phone use and deliberately avoids the generic dashboard habit of making every datum a floating card.

**Key characteristics:** Arabic-first hierarchy; dark financial anchor; divided linear progress; quiet, tonal surfaces; a persistent thumb-reachable action; and states that communicate in words and icons as well as color. `PRODUCT.md` owns behavior and `BRAND.md` owns the fixed identity; this document records only the resulting Web presentation system.

## Colors

Core brand colors remain unchanged in `src/styles/brand-tokens.css`. `src/styles/design-tokens.css` maps them to UI roles; application code uses semantic `--ui-*` tokens rather than hard-coded palette values.

- **Paper** (`#FAF5EF`): default canvas and calm visual breathing room.
- **Navy** (`#0F1C2B`): financial summary surface, primary text, and structural anchor.
- **Terracotta** (`#BA6649`): scarce intentional action and spent-progress signal; never a general warning color.
- **Sage** (`#6F837B` / semantic success): remaining/balanced progress and paid confirmation.
- **Sand** (`#E7DDD3`): quiet grouping and empty-state ground.
- **Semantic warning/danger**: `--ui-warning` and `--ui-danger` pair a label and icon with hue, so no state relies on color alone.

**The Deliberate Accent Rule.** Terracotta is reserved for the primary expense action, active selection, and actual spent progress. It does not wash large surfaces or decorate every control.

## Typography

**Arabic UI font:** Noto Sans Arabic via `next/font`; **Latin/numerals:** DM Sans via `next/font` with tabular figures for monetary values. Arabic stays primary, with English able to enter without reordering the hierarchy.

- **Display:** 700, `clamp(1.7rem, 6vw, 2.35rem)`, 1.2 line-height for concise page meaning.
- **Section title:** 700, 1.25rem for content regions.
- **Body:** 400, 1rem / 1.6 for readable Arabic text.
- **Labels/captions:** 700, .66–.84rem; labels are quiet but never the only explanation of a state.
- **Financial amounts:** 750 DM Sans, tabular numbers, RTL/plaintext isolation, with a smaller `ج.م` suffix. Values stay unbroken and align predictably across a list.

## Layout

The phone canvas is one vertical, 46rem-max reading column with information before ornament: month, financial position, budget section, recurring obligations, then activity. At 48rem the navigation becomes a compact fixed rail and the financial summary re-composes into two columns. At 72rem, the available canvas is explicitly offset from the RTL rail: the summary spans the planning width, budget sections and recurring obligations form two proportional columns, and activity runs beneath them. Desktop is a composed planning canvas, not a stretched phone column.

Spacing is a 4px base rhythm (`--space-1` through `--space-12`), with larger separation above a new financial topic than below its heading. The header-to-summary rhythm is intentionally compact on tablet and desktop. On mobile, the fixed action occupies an opaque action dock above the tab controls; scrollable content reserves the full dock, navigation, and safe-area stack so no final interactive content is obscured.

## Elevation & Depth

Tonal layering is the default. Paper, warm white, sand, and navy establish regions; borders describe list continuity. Only the primary financial anchor and floating expense action use diffuse offset shadows (`--shadow-lift`, `--shadow-float`), so depth means priority rather than decoration.

## Shapes

The system uses 12px controls, 18px working surfaces, and a 28px financial anchor. Progress is not circular: it is a single divided allocation line with an intentional narrow gap between spent and remaining portions. This mirrors the brand's controlled division without recreating or altering the official mark.

## Components

### Navigation

Mobile uses four labeled tabs with authored line icons and an obvious active terracotta state. Desktop uses the same labels in a compact warm-paper rail with a restrained sand selected surface and a single terracotta node; keyboard focus remains a separate visible ring. The official mark occupies a small raised home in the rail, so the desktop header does not repeat the wordmark. Navigation labels remain visible; an icon is never the sole meaning.

### Primary expense action

A fixed, 56px terracotta-derived pill sits above mobile navigation. On desktop it sits beside household context in the header as a conventional, clearly labeled contextual action rather than imitating a mobile floating action button. It has a plus icon and a complete Arabic action label; hover/pressed movement is a short 160ms lift/settle only.

### Financial summary and progress

The navy summary gives the actual available-to-spend amount the highest visual weight, then identifies section allocation and spent-to-date as supporting values. The allocation track always has accompanying numeric labels and textual percentages; its two deliberately separated segments express spent versus remaining without becoming a donut chart or color-only meter.

### Section and list surfaces

Sections are grouped in warm white bordered surfaces, while recurring and expense data uses contiguous rows to preserve scan rhythm. The design avoids a deck of identical cards.

### States

Paid, pending, skipped, success, warning, error, empty, and skeleton states each pair a tone with an icon and direct Arabic copy. Loading uses a limited shimmer; successful completion uses a settle motion rather than an attention-grabbing celebration.

## Motion

Motion has two jobs: active navigation settles into place, and loading communicates pending work. The shared standard is `--ease-out` over 160–260ms; all state motion is reduced to near-instant feedback under `prefers-reduced-motion`. Numeric values do not animate through intermediate values.

## RTL, accessibility, and ergonomics

The root document is `lang="ar" dir="rtl"`. Text and controls follow RTL flow; financial figures use an isolated tabular treatment to prevent mixed-direction instability. Focus has a visible 3px navy-compatible ring, controls retain at least 44px practical targets, and state meaning is repeated in text/icons. Contrast remains a WCAG 2.2 AA implementation target and must be checked against real content on every new surface.

## Do's and Don'ts

### Do:

- **Do** derive UI color through semantic `--ui-*` roles while preserving the fixed Brand v1 palette.
- **Do** present shared financial status as clear allocated/spent/remaining text beside linear progress.
- **Do** keep expense capture explicit, labeled, and reachable from the mobile thumb zone.
- **Do** use the official mark and wordmark assets directly; give them the clear space set by `BRAND.md`.
- **Do** maintain Arabic-first layout and test mixed Arabic/Latin financial text.

### Don't:

- **Don't** redraw, recolor, or substitute the approved Brand v1 mark or wordmarks.
- **Don't** use pie/donut charts, generic finance glyphs, or a field of equal floating cards as default financial language.
- **Don't** use terracotta as an undifferentiated alert color or rely on color alone for status.
- **Don't** let decoration delay the monthly status or primary expense action.
- **Don't** make motion decorative, blocking, or active under reduced-motion preferences.
