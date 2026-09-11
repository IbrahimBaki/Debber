# Dabber — Decision Register

This file records owner-approved project decisions. Coding agents may rely on **APPROVED** decisions without asking again. Anything marked **OPEN** or not covered here must follow the Owner Approval Gate in `AGENTS.md`.

## Approved decisions

| ID | Status | Decision |
|---|---|---|
| D-001 | APPROVED | Product name/workspace: Dabber. |
| D-002 | APPROVED | Frontend/full-stack framework: Next.js App Router + TypeScript. |
| D-003 | APPROVED | Hosting target: Vercel. |
| D-004 | APPROVED | Backend platform: Supabase Auth + PostgreSQL + RLS. |
| D-005 | APPROVED | `apps/web` and `apps/admin` are separate Next.js applications and separate Vercel projects in one monorepo. |
| D-006 | APPROVED | Platform Super Admin is distinct from Household Owner/Member roles. |
| D-007 | APPROVED | Platform Super Admin must have server-side controlled access to all operational/auth data required to administer the platform. Elevated Supabase credentials must never reach the browser. |
| D-008 | APPROVED | Database schema changes are version-controlled. Production schema must not be changed manually outside the migration workflow. |
| D-009 | APPROVED | Declarative schema lives in `supabase/schemas`; ordered deployment history lives in `supabase/migrations`. |
| D-010 | APPROVED | Package manager: npm. Do not introduce pnpm/yarn/bun lockfiles or commands. |
| D-011 | APPROVED | Repository instructions support both OpenAI Codex (`AGENTS.md`) and Claude Code (`CLAUDE.md`). |
| D-012 | APPROVED | A new architectural/product/security/schema behavior decision requires owner approval before implementation. |
| D-013 | APPROVED | Impeccable is the design authority for visual/UI craft across Dabber. It may make presentation-level UI decisions without separate owner approval while preserving approved product behavior, privacy, security, accessibility and financial semantics. |
| D-014 | APPROVED | User-facing UI must target a premium, distinctive, highly polished mobile-first experience with purposeful motion and micro-interactions; avoid generic AI/SaaS dashboard aesthetics. |
| D-015 | APPROVED | Impeccable is initialized and maintained at project scope; root product context is shared and app-specific design context may be used for Web vs Admin when appropriate. |
| D-016 | APPROVED | The existing shared Docker environment is protected infrastructure. Agents must not stop/prune/reconfigure unrelated services or modify the parent shared Compose without explicit owner approval. |
| D-017 | APPROVED | Local Supabase uses Option A: `npx supabase start` manages an isolated Dabber Supabase stack on the existing Docker daemon. The parent/shared `docker-compose.yml` is not modified for Dabber. |
| D-018 | APPROVED | The household Web application is an installable PWA from the first release. |
| D-019 | APPROVED | WCAG 2.2 AA is the accessibility target for both the household Web application and the Admin application; this is a product quality target, not a claim of formal certification or legal compliance. |
| D-020 | APPROVED | Dabber Brand Identity v1 is owner-approved. The approved Brand Kit under `apps/web` is the visual source of truth. The core logo, mark, and wordmarks must not be redesigned or replaced without explicit owner approval. Impeccable may apply and extend the brand across the product but may not replace the core identity; the future Web UI and `apps/web/DESIGN.md` must derive from this Brand Kit. |
| D-021 | APPROVED | Dabber Auth v1 uses Email + Password with mandatory email verification and email password recovery. Google OAuth, social login, Magic Link login, and email OTP login are outside MVP Auth v1. Sessions remain cookie-backed through Supabase SSR; authentication never replaces household authorization, which remains server-enforced with RLS. |
| D-022 | APPROVED | A Household has one selected currency, chosen by its Owner at Household creation. After authentication, active membership takes priority; otherwise pending invitations must be resolved before new-Household creation. One pending invitation is presented first; multiple pending invitations are presented as an explicit choice. Invitations are never auto-accepted. |
| D-023 | APPROVED | MVP Household invitations always create the `member` role; invitations do not carry a selectable role, and co-owner/ownership-transfer functionality is deferred. Secure in-app invitation discovery and ID-based acceptance are authenticated, atomic database operations; token-based acceptance remains supported separately. |
| D-024 | APPROVED | MVP Household currencies are exactly `EGP`, `SAR`, `USD`, and `EUR`. A Household stores one canonical uppercase currency code; unsupported or lowercase values are rejected at the database/domain layer. No currency conversion or mixed-currency Household data is supported. |
| D-025 | APPROVED | Household `period_start_day` supports 1–31 and defaults to 1. For a month without that calendar day, the effective boundary clamps to the month’s last valid day. Periods run until the day before the next clamped boundary; existing budget-period rows remain immutable if the Household setting later changes. Initial Household creation is an atomic, retry-safe authenticated domain operation and always creates an `owner` membership. |
| D-026 | APPROVED | During initial Household creation, the Web app auto-detects a non-empty browser IANA timezone and shows it for review. The user may change it. If detection fails, explicit timezone selection is required; the application never silently assumes a country or timezone. |
| D-027 | APPROVED | A budget period supports multiple planned income sources. Fixed commitments are separate from variable spending sections. The Owner explicitly sets the monthly spending budget; it may leave unallocated income or create a valid planned deficit. Flexible section allocations may be partial but must not exceed that spending budget. Actual section and total-variable-budget overspending are valid and negative remaining values are meaningful. A paid fixed commitment is recorded once as fixed actual outflow and never counted as variable spending. New periods start with a zero spending budget and zero section allocations; section defaults are reusable suggestions only. |
| D-028 | APPROVED | Financial setup ends with an explicit Draft → Open "ابدأ الشهر" (start month) action using the existing `set_budget_period_status(...)` operation; entering planning data never auto-opens a period. The Owner may continue editing the plan while a period is Open, subject to existing validation and audit rules; Closed remains protected and month-closing UX is not implemented yet. Income remains monthly/non-recurring only in MVP. A new fixed commitment defaults to `يتكرر شهريًا` (monthly recurring); the Owner may instead choose `هذا الشهر فقط` (this month only). No weekly/yearly/custom recurrence schedules exist in MVP. |
| D-029 | APPROVED | Three atomic, Owner-authorized, Draft/Open-only creation operations close the financial-setup write gap: `create_recurring_fixed_commitment(...)` (template + current-period snapshot in one transaction), `create_one_time_fixed_commitment(...)` (current-period snapshot only, no template), and `create_flexible_budget_section(...)` (section + current-period snapshot at zero allocation, never auto-applying `default_planned_amount`). Idempotency uses an optional caller-supplied entity UUID plus the existing natural unique keys already relied on by `ensure_budget_period()`; no new idempotency table or column was introduced. |
| D-030 | APPROVED | Quick Expense Entry v1: an Owner may record a variable expense in any legitimate flexible section of their Household; a Member may record one only in a section where `can_contribute_to_section(...)` already grants contribution (i.e. `member_access = 'contribute'` on a visible section, or an owner-granted `custom` edit permission) — viewing a section never implies expense authority. The expense date defaults to today and may be changed only to another date inside the current Open Budget Period, evaluated in the Household's IANA timezone; future dates and Draft/Closed periods are rejected authoritatively. Correction is void (`void_transaction(...)`, already-established authorization: Owner may void any Household transaction, a Member may void only a transaction they created) followed by recording a new correct expense; there is no in-place transaction editing and no hard delete in v1. Overspending a section allocation or the total spending budget remains valid and must never block a legitimate expense. The sole authoritative creation path is `record_expense(...)`, a narrow `security definer` operation (see `docs/FINANCIAL_MODEL.md`); the prior direct-insert RLS policy for ordinary transactions was removed because it did not authoritatively enforce Open-only status or date bounds. |
| D-031 | APPROVED | MVP simplification, superseding any prior direction toward a historical section-permission-snapshot migration: for MVP launch, Member visibility of `spending_budget` and of currently-authorized sections' allocation/spent/remaining/overspend and transactions is governed by **current** section authorization (`can_view_section(...)`/`can_contribute_to_section(...)`), not by a point-in-time snapshot of what was authorized when a historical period was open. `visibility_scope_snapshot`/`member_access_snapshot`, per-section historical-permission columns, and a corresponding migration are explicitly deferred, not implemented. Fixed commitments remain strictly Owner-only regardless of this decision — no RPC or view exposes them to a Member. Custom per-member permission UI (`resource_permissions`) remains deferred. Total planned income is independently Owner-controlled via the new `households.share_total_income_with_members` boolean (default `false`); reusing the existing Household `update` RLS policy is the Owner write path, and no new RPC exists solely to toggle it. When enabled, a Member may obtain only the aggregate total planned income for a period, via `get_member_visible_total_income(p_period_id)`; individual `income_sources`/`period_income_items` rows are never exposed to a Member through this or any other path, in any state of the toggle. `docs/PERMISSIONS.md` records "historical access follows current authorization" as an intentionally accepted MVP limitation and deferred hardening area, not an unknown bug. |

## Open decisions — stop and ask the owner

| ID | Status | Decision needed | Current recommendation |
|---|---|---|---|
| D-102 | DELEGATED | Presentation-level component/design-system choice beyond Tailwind defaults. | Delegated to Impeccable under D-013; adding a major runtime dependency still follows the dependency approval rule unless already approved. |
| D-103 | OPEN | Client/server state libraries beyond native Next.js/React primitives. | Add only when a concrete requirement justifies one. |
| D-104 | OPEN | Production Supabase region. | Choose based on expected primary users before creating the hosted project. |
| D-105 | OPEN | Email delivery/provider and production auth email behavior. | Decide before public invitation flow. |
| D-106 | OPEN | Analytics/error monitoring providers. | Defer until core MVP works. |

## Decision process

When a new decision is required, the agent must:

1. Stop before implementing the decision.
2. Explain the question in plain language.
3. Give 2–3 viable options.
4. State trade-offs, cost/security/maintenance impact where relevant.
5. Give a recommendation, clearly labeled as a recommendation rather than a decision.
6. Wait for explicit owner approval.
7. Record the approved outcome in this file and, for architecture-level changes, add/update an ADR.

The agent must not interpret silence as approval.
