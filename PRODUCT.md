# Dabber Product Context

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

- Household Owners plan a shared monthly budget, control resource visibility, and manage household membership.
- Household Members, such as a partner or collaborator, record and follow only the shared financial resources they are authorized to access.
- Platform Super Admins are distinct Dabber operators who use the separate Admin application for support and platform administration; they are not household roles.

The MVP is designed primarily for two people in a shared household or partnership. The database does not prevent additional members in a future product scope.

## Product Purpose

Dabber is a shared monthly budgeting workspace for households and partners. It makes monthly planning, recurring commitments, shared spending, and day-to-day expense capture understandable without requiring every participant to see every financial number.

Success means an owner can plan a monthly period and a permitted collaborator can reliably act on the shared budget without being able to infer private income, commitments, or transactions.

## Positioning

Share the budget, not necessarily every number. Dabber combines collaborative household budgeting with database-enforced selective visibility and safeguards against revealing hidden amounts through derived totals.

## Operating Context

- The household application is a mobile-first installable PWA from the first release, designed for monthly planning and frequent daily expense capture.
- Financial planning uses household time zones and monthly budget periods with Draft, Open, and Closed states.
- Persistent income, section, and recurring-item configuration is copied into immutable monthly snapshots so later template edits do not rewrite financial history.
- The Super Admin console is a separate application and deployment from the household application.

## Experience Commitments

- Dabber must feel like a polished consumer product, not an internal financial dashboard.
- The household experience is mobile-first and optimized for fast, repeated daily expense capture.
- The interface should feel calm, trustworthy, approachable, and financially clear rather than intimidating.
- The visual direction should be distinctive and memorable rather than a generic SaaS or dashboard template.
- High-quality motion, transitions, and micro-interactions are part of the intended product experience when they improve hierarchy, feedback, continuity, or delight.
- Motion must remain purposeful, responsive, and respectful of reduced-motion preferences.
- Arabic RTL is a first-class design context, not a translated adaptation of an LTR interface.
- Impeccable has delegated authority over visual craft and interaction polish, while product behavior, permissions, privacy, architecture, and financial semantics remain owner-controlled.

## Capabilities and Constraints

- A Household Owner can create and configure a household, plan income and sections, manage invitations, set visibility, and close or reopen periods according to the documented rules.
- Permitted members can view and contribute only within their authorized household and section scopes; RLS and server-side authorization are mandatory.
- Spending privacy is section-level in the MVP: transactions inherit their section visibility boundary to prevent aggregate inference.
- The MVP uses one currency per household and decimal database money values; it does not include bank connections, multi-currency, offline mutation queues, savings automation, or financial transfers.
- Monthly recurring items use Pending, Paid, and Skipped states. A paid recurring item must not double-count spending.
- The household application uses the Supabase publishable key and RLS. Elevated Supabase credentials are server-only, Admin-only, and used only after a separate active Platform Super Admin authorization check.
- The approved stack is Next.js App Router with TypeScript in separate `apps/web` and `apps/admin` npm workspaces, backed by Supabase Auth, PostgreSQL, and RLS.
- Arabic RTL is required from the first release; the architecture must allow English later.
- Production Supabase region, production email delivery behavior, additional state libraries, analytics, and error-monitoring providers remain explicitly open decisions.

## Brand Commitments

- Product name: Dabber.
- Dabber Brand Identity v1 is owner-approved. The approved Brand Kit and its usage rules in `apps/web/BRAND.md` are the source of truth for the Web brand.
- The core logo, mark, wordmarks, palette, and brand tokens are fixed unless the owner explicitly reopens branding. Detailed product UI and design-system decisions remain delegated to Impeccable and must derive from, rather than contradict, the approved Brand Kit.

## Evidence on Hand

- Product requirements: `docs/PRD.md`
- Approved decisions: `docs/DECISIONS.md`
- Architecture and app boundaries: `docs/ARCHITECTURE.md`, `docs/SUPER_ADMIN.md`
- Permission and privacy rules: `docs/PERMISSIONS.md`
- Data relationships: `docs/ERD.md`
- UI governance and accessibility expectations: `docs/UI_DESIGN_GOVERNANCE.md`

## Product Principles

1. Share the budget without requiring full financial disclosure.
2. Treat privacy, authorization, and non-inference as product correctness requirements.
3. Preserve trustworthy monthly history through snapshots and auditable financial transitions.
4. Keep common household expense capture fast while allowing the owner to maintain the full plan.
5. Keep platform administration separate from household participation and privilege.

## Accessibility & Inclusion

WCAG 2.2 AA is the accessibility target for both the household Web application and the Admin application. Interfaces must maintain contrast, focus visibility, labels, keyboard navigation, touch targets, screen-reader semantics, reduced-motion support, and responsive legibility. This target does not claim formal certification or legal compliance.
