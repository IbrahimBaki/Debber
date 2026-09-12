# Dabber Architecture v2.0

## 1. System shape

```text
                         GitHub Monorepo
                              │
                 ┌────────────┴────────────┐
                 │                         │
                 ▼                         ▼
        apps/web (Next.js)          apps/admin (Next.js)
        Household PWA               Super Admin Console
                 │                         │
        Vercel Project A            Vercel Project B
                 │                         │
       publishable key + JWT     server-only secret key
                 │                         │
                 └────────────┬────────────┘
                              ▼
                         Supabase
                 Auth + PostgreSQL + RLS
```

The two frontends are intentionally separate deployments. An ordinary household user never receives admin routes merely because a role check toggles UI elements.

## 2. Application boundaries

### User PWA — `apps/web`

Responsibilities:

- Authentication and onboarding.
- Household creation and invitations.
- Monthly planning.
- Shared sections and expense capture.
- Recurring monthly checklist.
- History and household settings.
- Permission-aware dashboards.

Security context:

- Uses the Supabase publishable key.
- Uses the logged-in user's access token.
- RLS is always expected to apply.
- Never uses the Secret Key.

### Super Admin — `apps/admin` (Admin v1 — see `docs/DECISIONS.md` D-034, `docs/SUPER_ADMIN.md`)

**Superseded:** an earlier draft of this section described a Households/Budgets/transactions
inspector and a privileged client used for ordinary database reads. Admin v1 does not do either;
the financial privacy wall means Admin never reads financial data, and the Secret Key client is
reserved for exactly five named Auth Admin operations, never for ordinary reads.

Responsibilities:

- Platform dashboard (non-financial operational counts only).
- Users list/detail, create/activate/disable/enable/change-password.
- Household invitations: list, create-on-behalf, accept-on-behalf, revoke.
- Admin audit log (read-only).

Security context:

- First authenticates the operator normally (its own `/login`, no public signup).
- Ordinary reads go through session-authenticated, security-definer RPCs (`admin_list_users`,
  `admin_get_user`, `admin_list_user_memberships`, `admin_list_invitations`,
  `admin_list_audit_logs`, `admin_dashboard_counts`) that each independently re-check
  `is_platform_admin()` — never a raw table grant, never solely a page/layout guard.
- The five privileged Auth Admin operations (create/activate/disable/enable/change-password) use
  a dedicated server-only module initialized with `SUPABASE_SECRET_KEY`. That module is never
  used for ordinary database reads and never receives an end-user access token.
- No RLS policy grants `super_admin` access to `period_income_items`, `transactions`,
  `period_fixed_commitments`, `period_section_budgets`, or `budget_periods.spending_budget`. A
  `super_admin` acting under their own JWT sees exactly the same (zero) financial rows as any
  other non-member.

## 3. Recommended monorepo

```text
apps/
  web/
  admin/
packages/
  ui/
  database/
  validation/
  config/
supabase/
  schemas/
  migrations/
  tests/
docs/
```

Both Next.js apps can be imported into Vercel from the same Git repository as separate Vercel projects with independent root directories, domains, and environment variables.

## 4. Environment variables

### `apps/web`

```env
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
NEXT_PUBLIC_APP_URL=
```

### `apps/admin`

```env
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
SUPABASE_SECRET_KEY=
NEXT_PUBLIC_ADMIN_URL=
```

Never prefix the Secret Key with `NEXT_PUBLIC_`.

## 5. Data access patterns

Prefer three explicit Supabase client factories:

```text
browser client  → publishable key + browser session + RLS
server client   → publishable key + request session + RLS
admin client    → secret key, server-only, no user token, BYPASSRLS
```

Name them explicitly; do not create one generic `supabase.ts` that can accidentally mix contexts.

## 6. Write strategy

Simple single-row writes may use the authenticated client + RLS.

Atomic domain operations use database RPCs, especially when a single user action touches more than one financial row. Initial RPC examples included in the schema:

- `ensure_budget_period`
- `mark_monthly_item_paid`
- `void_transaction`
- `set_monthly_item_skipped`
- `set_budget_period_status`
- `accept_household_invitation`
- `remove_household_member`

This keeps critical multi-row behavior transactional in PostgreSQL.

## 7. Month lifecycle

```text
Recurring Templates ─────┐
Income Sources ──────────┼─> ensure_budget_period()
Budget Sections ─────────┘          │
                                    ▼
                         Budget Period Snapshot
                         ├─ Period income items
                         ├─ Period section budgets
                         └─ Monthly recurring items
```

`ensure_budget_period()` is idempotent through unique constraints. It can be called lazily on first access; a scheduled pre-generation job may be added later but is not a correctness dependency.

## 8. PWA

The user app is mobile-first and installable. Initial PWA scope:

- Web App Manifest.
- Standalone display.
- Icons and Apple touch icon.
- Safe-area support.
- Online-first financial mutations.
- Conservative cache policy; do not cache private financial responses indiscriminately.

## 9. Observability

Do not send amounts, transaction descriptions, income labels, or private section names to third-party analytics. Technical events can include non-sensitive identifiers or coarse feature events.

## 10. Deployment environments

Minimum startup:

```text
Local → Production
```

Preferred before public beta:

```text
Local → Staging Supabase project → Production Supabase project
```

Database migrations are validated in CI and production pushes should use a GitHub Environment approval gate.
