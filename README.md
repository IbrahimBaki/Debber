# Dabber — Product & Technical Blueprint v2.0

Dabber is a privacy-aware shared monthly budgeting product for couples/partners. The product is intentionally split into two applications:

- `apps/web`: the household-facing Next.js PWA.
- `apps/admin`: a separate Super Admin Next.js application.
- `supabase/`: PostgreSQL schema, migrations, RLS, tests, and local-development assets.

## Locked architecture

- Next.js App Router + TypeScript
- Vercel for both web apps as two independent Vercel projects from one monorepo
- Supabase Auth + PostgreSQL + RLS
- Supabase Secret Key **server-side only** in the Admin app
- Supabase CLI migrations committed to Git
- Household permissions are distinct from platform Super Admin permissions

## Repository map

```text
dabber/
├── apps/
│   ├── web/                  # User/household PWA
│   └── admin/                # Separate Super Admin dashboard
├── packages/
│   └── database/             # Generated database TypeScript types
├── docs/
│   ├── PRD.md
│   ├── ARCHITECTURE.md
│   ├── DATABASE.md
│   ├── PERMISSIONS.md
│   ├── MIGRATIONS.md
│   ├── DATABASE_CHANGELOG.md
│   ├── SUPER_ADMIN.md
│   ├── ERD.md
│   └── adr/
├── supabase/
│   ├── schemas/              # Declarative source of truth
│   ├── migrations/           # Immutable migration history
│   ├── tests/database/       # pgTAP database/RLS tests
│   └── seed.sql
└── .github/workflows/        # Migration validation and production deploy
```

## Database rule

> Once migrations are enabled, production schema changes are never made directly in Supabase Studio/SQL Editor. Every change starts in Git and ends as a committed migration.

Typical workflow:

```bash
supabase start
# edit supabase/schemas/*.sql
supabase db diff -f add_something
supabase db reset
supabase test db
supabase gen types --lang typescript --local > packages/database/src/database.types.ts
git add supabase packages/database
```

Deploy only pending migrations:

```bash
supabase db push --dry-run
supabase db push
```

See `docs/MIGRATIONS.md` before changing the database.

## Important privacy rule

For MVP, transaction visibility follows its Budget Section. Do not create a hidden transaction inside a section whose `Spent` / `Remaining` is shared, because the amount can be inferred from the aggregate. Private obligations belong in a private section.

## Admin security rule

The Admin browser never receives the Supabase Secret Key. The flow is:

1. Verify the signed-in user using the normal authenticated Supabase client.
2. Confirm an active `platform_admins` row with `role = super_admin`.
3. Only then create/use a server-only Secret-Key client.
4. Log privileged mutations in `admin_audit_logs`.

## Current status of this blueprint

The included SQL is an implementation-ready baseline, but it has not been executed in a real Supabase local stack in this generated package. Run `supabase db reset` and `supabase test db` as the first repository bootstrap gate before linking production.

## Design tooling

Dabber uses Impeccable as the approved visual/UI craft authority. See `docs/UI_DESIGN_GOVERNANCE.md`. Install from the repo root with `npx impeccable install`, then initialize in Codex with `$impeccable init` or Claude Code with `/impeccable init`.

## Shared Docker host

The development machine contains unrelated projects. See `docs/LOCAL_ENVIRONMENT.md`. Never run global prune/down commands or edit shared parent infrastructure without explicit owner approval.



## Current local development decision

Local Supabase is approved to run as an isolated CLI-managed stack via `npx supabase start` on the existing shared Docker daemon (D-017). Do not modify the parent shared Compose for Dabber.
