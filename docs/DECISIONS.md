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
