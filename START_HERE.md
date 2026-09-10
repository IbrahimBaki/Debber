# Dabber — START HERE (npm + Codex + Claude Code)

This runbook starts Dabber from the project blueprint without making unapproved product/architecture decisions.

## 0. Rules before commands

Approved stack and decisions live in `docs/DECISIONS.md`.

Agents:

- OpenAI Codex reads root `AGENTS.md`.
- Claude Code reads root `CLAUDE.md`, which imports `AGENTS.md`.
- Both must follow the Owner Approval Gate.

Package manager:

- npm only.
- commit `package-lock.json`.
- do not introduce pnpm/yarn/bun files.

## 1. Machine prerequisites that are already approved

From the repository root:

```bash
node -v
npm -v
git --version
```

Use Node >= 22.18.0. This keeps Next.js/Supabase tooling supported and satisfies the current Impeccable installer requirement. A current Node LTS meeting that floor is preferred.

Install project dependencies:

```bash
npm install
```

Verify the project-scoped Supabase CLI:

```bash
npx supabase --version
```

The repository pins the CLI version in `devDependencies`; `package-lock.json` must be committed after installation.

## 2. Impeccable project setup — approved

Impeccable is the approved visual/UI design authority. Read `docs/UI_DESIGN_GOVERNANCE.md`.

Install the project integration from the repo root:

```bash
npx impeccable install
```

Then initialize from the agent session after the agent has read the project docs:

Codex:

```text
$impeccable init
```

Claude Code:

```text
/impeccable init
```

Review the resulting `PRODUCT.md`. Impeccable may own presentation-level UI decisions, but unresolved product/domain/security decisions must remain open and go through the Owner Approval Gate.

Do not build application UI before this context is initialized. A stable `DESIGN.md` can be created/documented after the first design direction is established.

## 3. Approved local Supabase strategy — isolated CLI-managed stack

**STOP HERE until the owner chooses.** Do not silently choose either branch.

### Approved — Supabase CLI-managed isolated local stack on the existing Docker daemon

The host already has Docker and other projects. Keep the parent shared Compose untouched. Run the Supabase CLI from the Dabber repository so it creates its own project-scoped local containers on the same Docker daemon. Before starting, inspect active published ports. Do not stop/prune unrelated services. See `docs/LOCAL_ENVIRONMENT.md`.

This is owner-approved under D-017. Verify Docker access, then:

```bash
npx supabase init
npx supabase start
npm run db:reset
npm run db:test
npm run db:types
```

If `supabase/config.toml` already exists, do not reinitialize without inspecting it first.

Pass gate:

```text
db:reset  PASS
db:test   PASS
db:types  PASS
```

Do not create or link production Supabase until this gate passes.

### Rejected for the current architecture — manual merge into the shared parent Compose

Do not merge Supabase services into the parent shared Compose unless the owner later changes D-017 explicitly.

## 4. Database baseline

The first engineering milestone is database reproducibility, not UI.

Required outcome:

- existing baseline migration can be applied using the approved environment strategy;
- RLS/integrity tests pass where supported by that strategy;
- generated TypeScript database types are current;
- no production database has been touched.

Only implementation bugs that clearly contradict the already-approved schema/spec may be fixed without a new design decision. If the fix changes domain meaning, permissions, schema behavior or architecture, stop and ask.

Commit baseline after it is green:

```bash
git add .
git commit -m "chore: bootstrap dabber baseline"
```

## 5. Next.js monorepo bootstrap — only after database baseline

Target applications:

```text
apps/web    user/household app, localhost:3000
apps/admin  separate Platform Super Admin app, localhost:3001
```

Scaffold using current stable create-next-app at execution time and npm:

```bash
npx create-next-app@latest apps/web --ts --tailwind --eslint --app --src-dir --use-npm --import-alias "@/*"
npx create-next-app@latest apps/admin --ts --tailwind --eslint --app --src-dir --use-npm --import-alias "@/*"
```

If placeholder directories prevent scaffolding, inspect/preserve useful notes and remove only the placeholders required to scaffold.

Do not add optional UI/state libraries without owner approval unless already approved in `docs/DECISIONS.md`.

Supabase packages required for the approved architecture may then be installed in each workspace:

```bash
npm install --workspace=web @supabase/supabase-js @supabase/ssr
npm install --workspace=admin @supabase/supabase-js @supabase/ssr
```

Before implementing auth, verify the current official Supabase SSR and current Next.js conventions. Do not copy stale middleware/auth examples from old tutorials.

Run locally:

```bash
npm run dev --workspace=web
npm run dev --workspace=admin -- --port 3001
```

Expected:

- Web: http://localhost:3000
- Admin: http://localhost:3001

Before implementing significant user-facing surfaces, use the Impeccable workflow in `docs/UI_DESIGN_GOVERNANCE.md`. Visual/UI craft is delegated to Impeccable; product/financial/security behavior is not.

## 6. Environment variable boundary

User app:

```env
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

Admin app:

```env
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
NEXT_PUBLIC_SITE_URL=http://localhost:3001
SUPABASE_URL=
SUPABASE_SECRET_KEY=
```

Rules:

- `.env.local` is never committed;
- commit `.env.example` placeholders only;
- `SUPABASE_SECRET_KEY` never enters the user app or any Client Component;
- never prefix the secret with `NEXT_PUBLIC_`.

## 7. Auth milestone

Implement only after the bootstrap/build gates are green.

User app foundation:

```text
/login
/signup
/auth/confirm
/dashboard
/logout
```

Admin app foundation:

```text
/login
/dashboard
/users
/households
```

Admin must remain a separate application. Platform Super Admin authorization is checked server-side before elevated queries.

The first Super Admin must be bootstrapped through a committed server-side script using environment input, not by hard-coding a personal email into a migration.

## 8. Product milestone 1

After Auth/Admin foundation works, implement the smallest end-to-end product slice:

```text
Owner creates Household
→ current Budget Period
→ one Budget Section
→ allocation
→ expense
→ spent/remaining
```

Then add Partner invitation and test with two different accounts against actual RLS.

Any unresolved UX/business behavior discovered here is an owner decision and must go through `docs/DECISIONS.md`.

## 9. Hosted Supabase — later, not during bootstrap

Before creating production, ask the owner to approve the production region (D-104) and any staging strategy.

Typical CLI flow after a hosted project is intentionally created:

```bash
npx supabase login
npx supabase link --project-ref <PROJECT_REF>
npx supabase migration list
npx supabase db push --dry-run
```

A real remote `db push` is a remote mutation. Show the dry-run and ask for approval before the first production push or any risky migration.

Never run destructive reset commands against production.

## 10. Vercel — after hosted Supabase and production builds

Use two separate Vercel projects from the same Git repository:

```text
Dabber Web   root: apps/web
Dabber Admin root: apps/admin
```

The Web project must never contain the Supabase Secret key.

The Admin project may contain the server-only Secret key after the Platform Admin authorization boundary is implemented and reviewed.

Exact domains, redirect URLs, and production environment choices are owner decisions if not already approved.

## 11. Database-change workflow

For every schema/RLS/function/index change:

```bash
# 1. edit declarative source
supabase/schemas/*.sql

# 2. generate migration
npx supabase db diff -f <meaningful_change_name>

# 3. manually review SQL

# 4. rebuild locally
npm run db:reset

# 5. tests
npm run db:test

# 6. generated TS types
npm run db:types

# 7. commit schema + migration + tests + generated types together
git add supabase packages/database docs/DATABASE_CHANGELOG.md
git commit -m "db: <meaningful change>"
```

If a schema change itself is a new business/data/security decision, get owner approval **before step 1**.

## 11. Useful npm commands

When the approved local Supabase stack is running:

```bash
npm run db:start
npm run db:stop
npm run db:status
npm run db:reset
npm run db:test
npm run db:types
```

Direct Supabase CLI commands use `npx supabase ...`.

After apps are scaffolded:

```bash
npm run dev --workspace=web
npm run dev --workspace=admin -- --port 3001
npm run lint --workspace=web
npm run build --workspace=web
npm run lint --workspace=admin
npm run build --workspace=admin
```

## 12. Definition of Done for an agent task

The agent reports:

- what it changed;
- exact commands it executed;
- exact test/build results;
- assumptions it verified;
- decisions it intentionally did not make;
- any owner approval needed next.

Never claim success for a command that was not actually run.
