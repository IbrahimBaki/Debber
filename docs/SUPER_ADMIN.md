# Dabber Super Admin Architecture

## 1. Product requirement

The Super Admin console is a separate application and deployment. The household app does not reveal admin controls based on a conditional role check.

Recommended domains:

```text
app.dabber.example    → Household PWA
admin.dabber.example  → Platform Super Admin
```

## 2. Super Admin capabilities (Admin v1 — see D-034)

**Superseded:** an earlier draft of this section described Admin reading household budget
periods, income data, sections, and transactions directly. That was never implemented and is no
longer the approved model. D-034 (`docs/DECISIONS.md`) is authoritative.

### The financial privacy wall (the single most important Admin v1 requirement)

Admin must **never** see: individual income rows, total household income, expenses/transaction
descriptions or amounts, the spending budget, section allocations, section spent/remaining, fixed
commitment amounts, or any financial summary/aggregate derived from these. No RLS policy grants
`super_admin` broad `SELECT` on any financial table, and none of the admin RPCs below read one. A
`super_admin` acting under their own JWT gets exactly the same (zero) financial rows as any other
authenticated user who is not a member of that household — being in the admin allowlist changes
nothing about what a financial table or financial RPC returns.

### MVP admin read access (v1, all via narrow RPCs — never a raw table grant)

- Safe Auth user fields: id, email, derived status (`active`/`needs_activation`/`disabled`),
  `email_confirmed_at`, `banned_until`, `last_sign_in_at`, `created_at`. Never a password hash or
  any Auth token column.
- A user's Household memberships: household id/name, role, status, joined_at. Never
  `currency_code`, `share_total_income_with_members`, or anything from `budget_periods`.
- Household invitations: household, email, status, inviter display name, timestamps. Never
  `token_hash`.
- Admin audit log entries (see §7).
- Non-financial operational counts (users, active/archived households, pending invitations,
  active memberships) for the dashboard.

### Privileged actions (v1)

- Create an Auth user (active-immediately or needs-activation), activate, disable, re-enable,
  change password — all native Supabase Auth Admin API operations, audited.
- Create a Household invitation on behalf of the Household's Owner (existing invitation
  semantics preserved exactly; `invited_by` stays the Owner, the real admin actor is recorded in
  the audit log separately).
- Accept an existing, valid invitation on behalf of its invitee, resolved strictly by the
  invitation's own normalized email against an existing Auth user. There is no path to create an
  arbitrary membership directly ("Add Member" does not exist); acceptance always goes through a
  real invitation.
- Revoke a pending invitation. An accepted invitation can never be revoked (no un-accepting a
  real membership) and nothing is ever hard-deleted.

Household archival, member removal outside the invitation flow, and any financial/corrective
action are **not** part of Admin v1 and are not implemented.

## 3. Authentication and authorization

The admin app uses ordinary Supabase Auth for operator login, then verifies platform authorization separately.

Source of truth:

```text
platform_admins
  user_id
  role
  is_active
```

Do not rely on email matching. Do not use user-editable `user_metadata` for authorization.

## 4. Secret Key usage

The Supabase Secret Key bypasses RLS and has broad data access. It must:

- exist only in the admin Vercel project's server environment;
- never be returned to browser code;
- never be stored in Git;
- never be used by `apps/web`;
- be instantiated in a dedicated server-only module;
- not be combined with an end-user access token.

## 5. Request flow (Admin v1)

Two distinct paths, never mixed:

```text
GET /users   (an ordinary DB read)
     │
     ├─ validate normal user session (authenticated client, cookie-based)
     ├─ call admin_list_users(...) -- a security-definer RPC that itself
     │  re-checks is_platform_admin() before returning any row
     └─ render only the safe fields the RPC returned

POST create user   (a privileged Auth mutation)
     │
     ├─ validate normal user session + is_platform_admin() (same check, via a
     │  narrow RPC or a server-side guard backed by the same allowlist query)
     ├─ only then instantiate the server-only privileged Auth-admin module
     ├─ call exactly one named operation (createAuthUser/activateAuthUser/
     │  disableAuthUser/enableAuthUser/setAuthUserPassword)
     └─ record the mutation via admin_record_audit_event(...)
```

The privileged client (Secret Key) is never used for ordinary reads — all reads go through
session-authenticated RPCs that independently re-verify `is_platform_admin()`. This matters
because a page/layout guard is not authorization; every RPC and every server action re-checks.

## 6. Admin dashboard information architecture (v1)

```text
الرئيسية (dashboard: non-financial operational counts only)
المستخدمون (users)
الدعوات (invitations)
سجل الإدارة (audit log)
```

No "Budgets", "Transactions", "Recurring Items", or "Households" nav item exists in v1 — there is
no dedicated households screen; household context (name, membership) is surfaced only from a
user's detail page, since discovering a household still requires knowing a user in it.

User detail page:

```text
Email / status (active, needs activation, disabled)
Created at / last sign-in
Household memberships (household name, role, status) -- no financial data
Admin actions: activate, disable, re-enable, change password (each confirmed, each audited)
```

There is no household inspector, budgets view, transactions view, or recurring-items view in
Admin v1 — these would require the financial privacy wall to be broken, and it is not.

## 7. Audit requirements

Every privileged mutation writes `admin_audit_logs` with:

- admin user;
- action;
- target type/id;
- reason for high-risk actions;
- metadata that does not contain secrets;
- timestamp.

Admin audit logs are not available to normal authenticated clients.

## 8. Defense-in-depth

Before production:

- protect `admin.*` with its own deployment/environment variables;
- consider MFA for platform admins;
- add rate limiting to sensitive admin actions;
- require re-authentication for destructive account operations if appropriate;
- use protected production deployments;
- keep Secret Key rotation documented;
- add alerting for repeated admin authorization failures.
