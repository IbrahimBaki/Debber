# Dabber Household Onboarding

## Scope

This document records the approved domain behavior used by the future authenticated Web onboarding flow. It does not define onboarding UI or household setup beyond the first Household record.

## Authenticated entry priority

The future server-side entry router must use this order:

1. An active Household membership routes the user to that Household’s application landing state.
2. Without an active membership, valid pending invitations for the authenticated user take priority.
3. Only a user with neither an active membership nor a valid pending invitation is offered initial Household creation.

The Web implementation uses `/app` as this server-side entry route. Unauthenticated visitors are redirected to `/login?next=/app`. `/app/invitations` and `/app/new-household` repeat the relevant server checks so a stale or manually entered nested URL cannot bypass the priority order.

One pending invitation is presented for an explicit accept action. Multiple pending invitations are presented as a choice. Invitations are never auto-accepted. Acceptance of one invitation does not alter other pending invitations.

## Invitation domain operations

`public.list_my_pending_household_invitations()` derives identity exclusively from `auth.uid()` and the authenticated user’s authoritative `auth.users.email`. It returns only onboarding display data: invitation and Household identifiers, Household name, inviter display name, creation time, and expiration time. It never returns `token_hash`, financial data, or unrelated invitations.

`public.accept_household_invitation_by_id(uuid)` atomically validates the authenticated identity, invitation recipient email, pending state, expiry, and active target Household before it creates or restores the membership. MVP acceptance always assigns the `member` role, updates the invitation to `accepted`, and records the existing Household audit event. Same-user retries safely return the resulting Household without duplicating membership.

`public.accept_household_invitation(text)` remains available for token-based invitation-email entry points. It shares the same protected acceptance logic.

## Partner invitation creation (MVP v1)

`public.create_household_invitation(p_household_id uuid, p_email text)` is the sole authoritative path for an Owner to invite someone by email; the invited role is always `member` — `household_invitations` carries no role column, so none can be spoofed regardless of how a row is created. It derives the caller from `auth.uid()`, requires active Household ownership of `p_household_id`, and normalizes the email (trim + lowercase) before any comparison or storage.

Three product rules are enforced authoritatively, not left to the client:

- **Self-invite** (the Owner's own authoritative `auth.users.email`) is rejected (`self_invite_not_allowed`).
- **Existing active Member**: inviting an email that already belongs to an active Member of that Household is rejected (`already_active_member`). The rejection carries no information about whether an unrelated email has a Dabber account elsewhere — only Household-scoped active membership is checked.
- **Duplicate pending invite**: for the same Household and normalized email, an unexpired `pending` invitation makes the call idempotent — it returns the existing invitation rather than creating a duplicate, and writes no additional audit event. A stale `pending` row whose `expires_at` has passed does not block a fresh invitation; it is lazily transitioned to `expired` first. A `revoked` or `accepted` invitation never blocks a new one either.

Expiration is fixed at 7 days from creation, computed server-side; the client cannot supply `expires_at`. `token_hash` is generated server-side from cryptographically random bytes (`extensions.gen_random_bytes(32)`), is never accepted as a parameter, and is never returned to any caller — the function's return row exposes only `invitation_id`, the normalized `email`, `expires_at`, and a `created` flag distinguishing a new row from an idempotent reuse. Concurrent/retried calls for the same Household+email are serialized with a transaction-scoped advisory lock (the same pattern `create_initial_household(...)` already uses), so a race can never produce two simultaneous pending rows for one recipient.

`household_invitations` has **no direct client grant at all** (`select`/`insert`/`update`/`delete` are all revoked from `authenticated`; RLS stays enabled with zero policies). The previous generic Owner-scoped CRUD grant was removed because it could never enforce email normalization, the 7-day expiration window, server-generated tokens, self-invite/existing-member rejection, idempotency, or an audit trail — and it allowed `token_hash` to be selected directly. All access now goes through `create_household_invitation(...)`, `list_my_pending_household_invitations()`, and `accept_household_invitation(_by_id)(...)`, none of which need a table grant since they are `security definer`.

### No outbound invitation email in MVP

There is no configured email provider or invitation-email template (see `docs/AUTH.md`; D-105 remains open/deferred). Creating an invitation only ever produces a database record — the Web UI must say the invitation exists/is ready ("الدعوة جاهزة"), never that anything was sent. The Owner is expected to tell the invited partner, outside Dabber, to sign up or log in using that exact email address within the 7-day window; once authenticated, the existing discovery/acceptance flow above takes over automatically. Resend, a revoke UI, an invitation-history dashboard, and role selection are explicitly out of scope for this milestone.

## Initial Household creation

`public.create_initial_household(text, varchar, integer, text)` derives the creator only from `auth.uid()`. It serializes concurrent/retried first-creation attempts using a transaction-scoped advisory lock, returns an existing active Household membership when one already exists, and refuses to bypass a valid pending invitation.

The Household insert and its existing owner-membership trigger occur in one database transaction. The creator is always the Household `owner`; this role is unrelated to Platform Super Admin. This onboarding operation does not impose a permanent one-Household-per-user rule, preserving future multi-Household product options.

Authenticated browser clients do not have direct `INSERT` access to `households`; they must use this narrow domain operation.

The Web form collects only the approved initial values: Household name, one supported currency, period start day, and timezone. It detects a non-empty browser IANA timezone with `Intl.DateTimeFormat().resolvedOptions().timeZone`, displays it for review, and allows a dependency-free native selection fallback. If detection fails, explicit selection is required; no location or timezone is assumed.

## Current Household landing

An active member is routed directly to the minimal `/app` landing placeholder. It displays only the Household name, the current user’s Household role, stored currency, and period-start day plus a deferred-setup message. It deliberately does not expose financial data or act as a budget dashboard.

## Household configuration invariants

- A Household has exactly one canonical currency: `EGP`, `SAR`, `USD`, or `EUR`.
- Currency conversion and mixed-currency Household data are outside MVP.
- `period_start_day` accepts 1 through 31 and defaults to 1.
- Missing calendar days clamp to the target month’s final valid day.
- A period ends one day before the next calculated/clamped start.
- Existing `budget_periods.start_date` and `end_date` are immutable historical snapshots. Updating `households.period_start_day` affects only subsequently created periods.
- Existing Household timezone storage is preserved; onboarding supplies the existing timezone field without introducing a new timezone model.

## Security boundaries

The onboarding operations are narrowly scoped `SECURITY DEFINER` functions with an empty `search_path`, server-derived identity, explicit execution grants only to `authenticated`, and no caller-controlled identity, email, role, owner, or Household selection beyond an invitation ID. Table RLS remains enabled and is not loosened for invitation discovery.

## Deferred work

- Web onboarding UI and server routing
- Invitation resend, revoke UI, and an invitation-history dashboard (creation itself now exists; see "Partner invitation creation (MVP v1)" above)
- Partner permission configuration
- Household financial setup, budgeting, recurring items, and expense capture
- Co-owner and ownership-transfer workflows
