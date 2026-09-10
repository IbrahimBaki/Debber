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

### Super Admin — `apps/admin`

Responsibilities:

- Platform dashboard.
- Users inspector.
- Households inspector.
- Budgets/transactions inspector.
- Support and account administration.
- Platform/admin audit logs.

Security context:

- First authenticates the operator normally.
- Verifies `platform_admins` server-side.
- Privileged database and Auth Admin calls use a dedicated server-only client initialized with `SUPABASE_SECRET_KEY`.
- The privileged client must not carry an end-user access token, because that would cause the request to run under user RLS context instead of bypassing RLS.

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
