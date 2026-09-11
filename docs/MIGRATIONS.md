# Dabber Database Migration Workflow

## 1. Non-negotiable rule

> The Git repository is the source of truth for the database schema. Never make a production schema change directly in Supabase Studio, the Table Editor, or the remote SQL Editor once migration-based development starts.

This prevents remote schema drift and keeps a fresh clone able to reproduce the database.

## 2. Chosen approach: Declarative Schema + Versioned Migrations

Dabber maintains both:

```text
supabase/schemas/      # Desired schema, organized for humans
supabase/migrations/   # Ordered historical changes, used for deployment
```

The schema files make the current database easy to understand. Migrations preserve how production moved from one version to the next.

## 3. Initial bootstrap

Dabber installs the Supabase CLI as a pinned npm dev dependency and runs it with `npx supabase ...`. A Docker-compatible runtime is required for the approved local Supabase stack (Decision D-017). It is not a production runtime requirement.

For a new repo:

```bash
npx supabase init
npx supabase start
npm run db:reset
npm run db:test
```

`supabase init` creates `supabase/config.toml`. Commit `config.toml`; do not commit `.temp/` or `.branches/`.

This blueprint already contains a baseline migration and declarative schema files. The first real bootstrap gate is that `npm run db:reset` succeeds from a clean local stack.

## 4. Daily schema-change workflow

Example: add a notes field to recurring templates.

### Step 1 — branch

```bash
git checkout -b feat/recurring-template-notes
```

### Step 2 — edit declarative source

Edit the appropriate file under:

```text
supabase/schemas/
```

Do not edit remote production.

### Step 3 — generate migration

```bash
npx supabase db schema declarative sync --no-apply --file add_recurring_template_notes
```

This creates a timestamped SQL file in `supabase/migrations/` without touching the local
database (`--no-apply`); add `--apply` instead once you're ready to also apply it locally
(equivalent to following with `npm run db:reset`).

Do **not** use `npx supabase db diff` for this step. In the installed CLI (`supabase` 2.117.0),
`db diff` prints `WARNING: [db.migrations].schema_paths no longer changes the migrations
baseline used by db diff...` and always reports "No schema changes found" against
`supabase/schemas/`, even when the two have genuinely diverged — it now only diffs the local
database against another live database, not against declarative schema files. `db schema
declarative sync` is the command that actually reads `supabase/schemas/*.sql` and diffs it
against the migrations-derived database; verify with `--no-apply` (no `--file`) any time you
want to check for drift without generating a file.

Two things worth knowing about how `declarative sync` diffs functions:

- It flags a function as changed if its stored text differs from the schema file's text at
  all, including pure whitespace — write schema-file SQL with normal spacing around operators
  (`x = y`, not `x=y`) to avoid the tool re-issuing an unrelated `CREATE OR REPLACE FUNCTION`
  the next time you touch a nearby line.
- `schema_paths` in `[db.migrations]` is not read by this command (confirmed by testing with
  it set to `[]`) — it discovers `supabase/schemas/*.sql` on its own. The config value is kept
  set to `["./schemas/*.sql"]` anyway because it is still the documented value and may still
  matter to other tooling (e.g. migration-style `db pull`), but do not rely on it to make
  declarative diffing work.

### Step 4 — review generated SQL manually

`db diff` output is a draft. Check for:

- unintended drops;
- noisy revoke/grant churn;
- extension changes;
- missing data backfills;
- RLS policy behavior;
- locks on large tables;
- backwards compatibility with the currently deployed app.

Data changes (`INSERT/UPDATE/DELETE`) and some database objects are not fully captured by schema diffing, so add those statements manually when required.

### Step 5 — rebuild from zero

```bash
npm run db:reset
```

This destroys the local database, reapplies every migration in order, then applies seed data. If it fails, the migration chain is not reproducible and must not be merged.

### Step 6 — tests

```bash
npm run db:test
```

Add or update pgTAP tests, especially Allow/Deny RLS cases.

### Step 7 — regenerate TypeScript database types

```bash
npm run db:types
```

Commit the generated type change with the migration.

### Step 8 — commit together

```bash
git add supabase packages/database
git commit -m "db: add recurring template notes"
```

A database change is incomplete if the migration, declarative schema, relevant tests, and generated types are not committed together.

## 5. Migration file documentation standard

Every hand-written or materially edited migration should start with a header like:

```sql
-- Migration: 20260910190000_initial_dabber_schema
-- Purpose: Initial Dabber household budgeting schema, RLS and core RPCs.
-- Risk: New schema only; no existing production rows.
-- Data migration: None.
-- Rollback: Recreate a fresh environment from the previous migration chain.
-- Notes: Never manually roll back production by deleting migration history.
```

Use `docs/templates/migration.sql` for future hand-written migrations.

## 6. Remote deployment

Link once per environment:

```bash
npx supabase login
npx supabase link --project-ref <project-ref>
```

Before deployment:

```bash
npx supabase migration list
npx supabase db push --dry-run
```

Deploy pending migrations:

```bash
npx supabase db push
```

`db push` uses Supabase migration history and applies only migrations that have not been applied remotely.

Never use `npx supabase db reset --linked` on production; it is destructive.

## 7. CI/CD policy

### Pull requests

`.github/workflows/database-ci.yml`:

- starts a local Supabase database;
- rebuilds from migrations;
- runs database tests.

### Production

`.github/workflows/database-production.yml`:

- runs only when `supabase/**` changes reach `main` or via manual dispatch;
- uses encrypted GitHub secrets;
- performs a dry run first;
- pushes pending migrations;
- should use a protected GitHub `production` Environment with manual approval.

Recommended GitHub secrets:

```text
SUPABASE_ACCESS_TOKEN
SUPABASE_DB_PASSWORD
SUPABASE_PROJECT_ID
```

## 8. Staging

Before public beta, use a separate Supabase staging project. Never test risky migrations on production data first.

Recommended flow:

```text
feature branch → local database → CI
                          ↓
develop/main candidate → staging
                          ↓
approved main → production
```

Supabase Branching can create preview database environments, but preview branching is a separate paid-plan capability; the CLI/GitHub-based migration workflow itself does not require it.

## 9. Emergency rule

If production needs an urgent schema fix:

1. create a hotfix branch;
2. write/edit the schema file;
3. generate/review a migration;
4. run reset/tests locally;
5. merge through the protected production workflow.

Do not “fix it now in Studio and document it later.” That is precisely how migration histories drift.

## 10. References

- Supabase — Local development workflow: https://supabase.com/docs/guides/local-development/cli-workflows
- Supabase — Database migrations: https://supabase.com/docs/guides/local-development/database-migrations
- Supabase — Declarative database schemas: https://supabase.com/docs/guides/local-development/declarative-database-schemas
- Supabase — Managing environments: https://supabase.com/docs/guides/deployment/managing-environments
- Supabase — Database testing: https://supabase.com/docs/guides/database/testing
