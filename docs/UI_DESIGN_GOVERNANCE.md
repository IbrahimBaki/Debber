# Dabber — UI / UX Design Governance

## Quality bar

Dabber must feel like a deliberately designed financial product, not a generic CRUD dashboard. The user app is mobile/PWA-first and should feel calm, trustworthy, fast, tactile and visually memorable. The admin app can be denser and more operational, but should still feel cohesive and finished.

## Design authority

The owner has delegated presentation-level UI/UX craft to **Impeccable**. Impeccable may choose and refine:

- visual hierarchy and layout;
- typography and readable financial-number treatment;
- spacing, density, shape, elevation and color usage;
- responsive behavior and mobile navigation presentation;
- component appearance and visual states;
- motion, transitions and micro-interactions;
- skeleton/loading, empty, success, warning and error presentation;
- progressive disclosure and presentation-level simplification that does not alter business meaning.

Impeccable does **not** have authority to change:

- financial/domain semantics;
- permissions, privacy boundaries, RLS or what data a user may access;
- MVP/product scope;
- destructive-action meaning;
- authentication/authorization strategy;
- data model or migration behavior;
- a major workflow change that changes what the user is required or allowed to do.

Those changes require owner approval through `docs/DECISIONS.md`.

## Impeccable setup

From the repository root:

```bash
node -v
npx impeccable install
```

The current Impeccable installer requires Node.js 22.18 or newer. The repository therefore targets Node >=22.18.

Initialize inside the coding-agent session after it has read the Dabber project docs:

**Codex**

```text
$impeccable init
```

**Claude Code**

```text
/impeccable init
```

`init` should inspect the project and write/update `PRODUCT.md`. Review it; uncertain product facts must stay marked as unresolved rather than being invented.

## Monorepo context

Use root `PRODUCT.md` for shared product truth. Impeccable supports app-level context in monorepos, so `apps/web/DESIGN.md` and `apps/admin/DESIGN.md` may diverge if the surfaces need different visual systems while still inheriting shared product context. Do not create divergence merely for novelty.

## Workflow for every significant new surface

1. **Read**: PRD, approved decisions, current `PRODUCT.md`, and applicable `DESIGN.md`.
2. **Shape**: ask Impeccable to shape the surface before implementation when the interaction/layout is non-trivial.
3. **Build**: implement the chosen design with reusable components and tokens.
4. **Inspect in browser**: verify real responsive behavior, not only source code.
5. **Critique**: hierarchy, clarity, information density, emotional tone, and task completion.
6. **Animate**: add purposeful motion where it improves orientation, feedback, continuity or delight.
7. **Harden**: loading, empty, error, offline-ish/network delay, long text/numbers, localization/RTL readiness, destructive confirmations and edge cases.
8. **Audit**: accessibility, responsive behavior, performance and implementation quality.
9. **Polish**: final consistency and finish pass.
10. **Document**: once a stable visual system exists, persist it through Impeccable `document` so later agents follow it.

Exact specialist commands are chosen by Impeccable/agent according to the task. In Codex commands use `$impeccable`; in Claude Code they use `/impeccable`.

## Motion rules

Motion is encouraged, but must have a job. Prefer small, responsive transitions and state continuity over decorative animation everywhere.

Required constraints:

- respect `prefers-reduced-motion`;
- avoid motion that obscures or delays financial information;
- do not animate numbers in a way that could imply a value different from the persisted value;
- preserve focus and keyboard behavior through transitions;
- avoid layout-shift-heavy effects;
- keep primary actions fast and responsive;
- destructive actions prioritize clarity over delight.

## Mobile/PWA experience

The Web app is expected to be used from the home screen like an app. Design for:

- touch-first controls and adequate target sizes;
- one-handed use where practical;
- safe-area insets;
- fast expense entry;
- legible monetary values and budget status at a glance;
- responsive keyboard/input behavior;
- clear optimistic/pending/success states where approved by the domain behavior;
- excellent empty-state/onboarding experience.

## Accessibility is part of visual quality

A visually striking implementation is not accepted if contrast, focus, labels, keyboard navigation, touch targets, reduced motion, screen-reader semantics, or responsive legibility regress. Accessibility fixes that preserve product behavior are implementation work, not optional polish.

## Anti-patterns

Avoid by default:

- generic admin-template composition for the consumer app;
- gratuitous glassmorphism/gradient decoration;
- excessive nested cards;
- every element having the same border radius/elevation;
- motion on every interaction;
- hiding complexity by removing needed financial context;
- desktop-first tables squeezed onto mobile;
- relying on color alone for financial status.

## Completion gate for user-facing milestones

A feature is not UI-complete merely because it works. Before marking a significant surface complete, report:

- viewport(s)/browser state inspected;
- Impeccable review/refinement passes used;
- responsive/mobile verification;
- accessibility issues found/fixed;
- motion/reduced-motion behavior if animations were added;
- remaining known UI/UX debt.
