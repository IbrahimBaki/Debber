# Dabber Household Onboarding

## Scope

This document records the approved domain behavior used by the future authenticated Web onboarding flow. It does not define onboarding UI or household setup beyond the first Household record.

## Authenticated entry priority

The future server-side entry router must use this order:

1. An active Household membership routes the user to that Household’s application landing state.
2. Without an active membership, valid pending invitations for the authenticated user take priority.
3. Only a user with neither an active membership nor a valid pending invitation is offered initial Household creation.

One pending invitation is presented for an explicit accept action. Multiple pending invitations are presented as a choice. Invitations are never auto-accepted. Acceptance of one invitation does not alter other pending invitations.

## Invitation domain operations

`public.list_my_pending_household_invitations()` derives identity exclusively from `auth.uid()` and the authenticated user’s authoritative `auth.users.email`. It returns only onboarding display data: invitation and Household identifiers, Household name, inviter display name, creation time, and expiration time. It never returns `token_hash`, financial data, or unrelated invitations.

`public.accept_household_invitation_by_id(uuid)` atomically validates the authenticated identity, invitation recipient email, pending state, expiry, and active target Household before it creates or restores the membership. MVP acceptance always assigns the `member` role, updates the invitation to `accepted`, and records the existing Household audit event. Same-user retries safely return the resulting Household without duplicating membership.

`public.accept_household_invitation(text)` remains available for token-based invitation-email entry points. It shares the same protected acceptance logic.

## Initial Household creation

`public.create_initial_household(text, varchar, integer, text)` derives the creator only from `auth.uid()`. It serializes concurrent/retried first-creation attempts using a transaction-scoped advisory lock, returns an existing active Household membership when one already exists, and refuses to bypass a valid pending invitation.

The Household insert and its existing owner-membership trigger occur in one database transaction. The creator is always the Household `owner`; this role is unrelated to Platform Super Admin. This onboarding operation does not impose a permanent one-Household-per-user rule, preserving future multi-Household product options.

Authenticated browser clients do not have direct `INSERT` access to `households`; they must use this narrow domain operation.

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
- Invitation sending and management UI
- Partner permission configuration
- Household financial setup, budgeting, recurring items, and expense capture
- Co-owner and ownership-transfer workflows
