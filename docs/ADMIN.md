# Dabber Admin v1 — Operations Guide

This document covers what `docs/SUPER_ADMIN.md` and `docs/DECISIONS.md` (D-034) do not: how to
actually bootstrap and operate the Admin v1 console. Read `docs/SUPER_ADMIN.md` first for the
approved model (one role, the financial privacy wall, what Admin may and may not do).

## 1. Bootstrapping the first super_admin

There is intentionally no in-app UI to promote a user to `super_admin` in v1 — this is a manual,
trusted database operation performed by whoever operates the Supabase project, not something
reachable from a browser.

1. Create (or identify) an ordinary Supabase Auth user for the operator, the same way any Dabber
   account is created (sign up normally, or have another trusted operator create one via the
   Admin console's "مستخدم جديد" once at least one super_admin already exists).
2. Insert an allowlist row directly against the database:

   ```sql
   insert into public.platform_admins (user_id, role, is_active, created_by)
   values ('<auth-user-uuid>', 'super_admin', true, null);
   ```

   Run this against the target Supabase project's database (local: via `psql`/Studio against the
   Supabase CLI-managed local stack; hosted: via the Supabase SQL editor or a direct `psql`
   connection with the project's Postgres credentials — never via a browser-reachable endpoint).
3. The user can now sign in at `/login` in `apps/admin`; every subsequent admin RPC re-verifies
   `is_platform_admin()` independently, so this one allowlist row is the entire trust boundary.

To revoke admin access, set `is_active = false` on that row (or delete it). Do not repurpose the
`role` column's other enum values (`support`, `read_only`) for v1 — they exist in the schema for
future use but nothing in Admin v1 checks or grants them; only `role = 'super_admin'` with
`is_active = true` is ever treated as an admin.

## 2. Environment variables (`apps/admin/.env.local`, never committed)

| Variable | Used by | Notes |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | ordinary session client | same value as `apps/web` |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | ordinary session client | same value as `apps/web` |
| `SUPABASE_URL` | `src/lib/supabase/admin-auth.ts` only | server-only |
| `SUPABASE_SECRET_KEY` | `src/lib/supabase/admin-auth.ts` only | server-only, never `NEXT_PUBLIC_`, never logged |

## 3. What Admin v1 can and cannot do

See `docs/SUPER_ADMIN.md` §2 for the authoritative list. In short: Auth user lifecycle
(create/activate/disable/enable/change password), Household invitations on behalf of an Owner
(create/accept/revoke — never an arbitrary membership), and a read-only audit log. Admin v1 never
reads income, transactions, budgets, or any financial aggregate, regardless of admin status.

## 4. System settings

No system-settings screen exists in Admin v1. None were approved, and none were invented —
`docs/DECISIONS.md` D-034 records this explicitly. Add one only after a genuine, owner-approved
settings requirement exists.

## 5. Auth account states (verified against the local Supabase Auth stack)

Admin v1 uses native Supabase Auth state directly — there is no second, parallel
active/disabled/needs-activation flag anywhere in the application schema:

- **Needs activation**: `email_confirmed_at is null`. Sign-in is rejected with
  `Email not confirmed`. `admin_get_user`/`admin_list_users` report this as `needs_activation`.
- **Active**: `email_confirmed_at` is set and the account is not banned. Sign-in succeeds.
- **Disabled**: `banned_until` is set in the future (Admin v1 uses `ban_duration: "876000h"`, ~100
  years). Sign-in is rejected with `User is banned`. Re-enabling sets `ban_duration: "none"`.
- **Password change**: setting a new password via the Auth Admin API also immediately invalidates
  any session issued before the change — a previously issued access token is rejected by GoTrue
  with `session_not_found`. No separate session-revocation step exists or is needed.

All four behaviors above were empirically verified against the local Supabase stack during this
feature's implementation, not assumed from documentation.
