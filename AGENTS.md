# AGENTS.md — Dabber shared engineering instructions

This file is the shared instruction source for coding agents. Codex reads `AGENTS.md`; Claude Code imports it from root `CLAUDE.md`.

## Start every task here

1. Read `docs/DECISIONS.md`.
2. Read the files relevant to the task:
   - `docs/PRD.md`
   - `docs/ARCHITECTURE.md`
   - `docs/DATABASE.md`
   - `docs/PERMISSIONS.md`
   - `docs/MIGRATIONS.md`
   - `docs/SUPER_ADMIN.md`
   - `docs/ERD.md`
   - `docs/adr/*`
3. Inspect current code before proposing changes.
4. Use npm only.
5. For any user-facing UI task, read `docs/UI_DESIGN_GOVERNANCE.md` and the current Impeccable context (`PRODUCT.md`, `DESIGN.md`, and relevant `.impeccable/surfaces/*`) if present.

## Owner Approval Gate — mandatory

Do NOT make a new product, architecture, security, data-model, permissions, dependency, deployment, or UX behavior decision without explicit owner approval unless that decision is already marked `APPROVED` in `docs/DECISIONS.md`.

When approval is needed:

- stop before implementation;
- explain the decision and why it is needed;
- provide 2–3 options with trade-offs;
- provide a recommendation;
- wait for explicit owner approval;
- after approval, update `docs/DECISIONS.md` and any affected ADR/docs before or with the implementation.

Examples that REQUIRE approval:

- adding/replacing a major library or hosted service;
- changing a table/entity relationship, financial meaning, permission behavior, or privacy boundary;
- changing authentication strategy;
- adding a new user-visible feature or changing MVP scope;
- choosing a production region/provider/domain strategy;
- changing user/admin application boundaries;
- changing migration strategy;
- destructive or hard-to-reverse remote operations.

Examples that do NOT normally require approval if behavior is preserved:

- fixing a syntax/type/lint error;
- fixing an obvious implementation bug to match an already-approved spec;
- formatting/refactoring with no observable behavior or schema change;
- regenerating documented generated artifacts;
- running non-destructive tests/builds/status commands;
- updating documentation to match an already-approved implementation.

If unsure whether something is a decision, ask.

## UI / UX authority — Impeccable is approved

The owner has explicitly delegated visual/UI craft decisions to Impeccable. For user-facing UI work:

- Impeccable may decide visual hierarchy, typography, spacing, color application, component styling, density, responsive presentation, motion, micro-interactions, transitions, loading/empty states, and other presentation-level details without a separate owner approval.
- The target quality is premium, distinctive, polished product UI — not a generic dashboard or obvious AI-generated SaaS template.
- Motion should be purposeful and should improve feedback, orientation, continuity, or delight. Respect `prefers-reduced-motion`; do not sacrifice responsiveness or accessibility for spectacle.
- Mobile/PWA UX is first-class for `apps/web`, including thumb reach, touch targets, keyboard behavior, safe areas, and responsive financial data presentation.
- `apps/admin` may be denser and operational, but must still be coherent and polished.
- Impeccable may NOT change product semantics, financial rules, permissions/privacy, routes that materially change the approved workflow, or MVP scope without the Owner Approval Gate. UI styling authority is not product authority.
- If a proposed UX change changes what a user can do, when money is mutated, what data is revealed, or how authorization works, stop and ask the owner.

Approved Impeccable workflow:

- Install project integration from the repository root with `npx impeccable install`.
- Initialize product context once the project docs are present:
  - Codex: `$impeccable init`
  - Claude Code: `/impeccable init`
- Review the generated `PRODUCT.md`; unresolved product facts remain explicitly open.
- For new surfaces, use Impeccable to shape/design before implementation.
- Before calling a user-facing milestone complete, use appropriate Impeccable critique/audit/harden/polish passes, and use `animate` when motion can improve the experience.
- Once the visual system is established, use `document` to persist it in `DESIGN.md`.
- In this monorepo, root product context can be shared while app-specific `DESIGN.md` files may be used where the Web and Admin visual systems intentionally differ.

## Shared Docker environment safety

The development host already runs a shared Docker environment containing other projects. Treat it as protected infrastructure.

Without explicit owner approval, NEVER run destructive/global Docker commands such as:

```bash
docker system prune
docker volume prune
docker network prune
docker container prune
docker compose down   # against the shared parent compose
```

Do not stop, rename, recreate, or modify unrelated containers, networks, ports, bind mounts, or volumes. Before introducing any new published port, inspect current listeners/containers. Local Supabase strategy D-017 is approved: use the Supabase CLI-managed Dabber project stack on the existing Docker daemon. Do not manually merge Supabase services into the shared parent compose unless the owner explicitly changes that decision.

## Approved core architecture

- Next.js App Router + TypeScript.
- npm workspaces monorepo.
- `apps/web` = household/user application and eventual PWA.
- `apps/admin` = completely separate Platform Super Admin Next.js app.
- Both deploy as separate Vercel projects from one Git repository.
- Supabase = Auth + PostgreSQL + RLS.
- Household permissions and Platform Super Admin permissions are separate concepts.

## Package-management rules

- Use `npm` and `npx` only.
- Root workspaces are declared in root `package.json`.
- Commit `package-lock.json`.
- Do not create `pnpm-lock.yaml`, `yarn.lock`, `bun.lock`, or `pnpm-workspace.yaml`.
- Before adding a new runtime dependency not already approved/documented, use the Owner Approval Gate.
- Prefer current stable releases, but do not perform broad dependency upgrades incidentally during feature work.

## Database rules

- `supabase/schemas/*.sql` = declarative desired schema.
- `supabase/migrations/*.sql` = ordered deployment history.
- Never make a production schema change only in Supabase Studio/Table Editor/SQL Editor.
- Once a migration is deployed remotely, never rewrite it; create a forward migration.
- Every DB/RLS change must update tests and generated TS types when applicable.
- Review generated diffs manually; schema diff tools do not capture every kind of change.
- Never run destructive linked/production database commands unless the owner explicitly approves the exact action.

For the approved local Supabase mode, the standard schema loop is:

```bash
# edit supabase/schemas/*.sql
npx supabase db diff -f <meaningful_name>
npm run db:reset
npm run db:test
npm run db:types
```

## Supabase credentials

Normal web/client access:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- RLS mandatory.

Admin server only:

- `SUPABASE_URL`
- `SUPABASE_SECRET_KEY`

Never expose an elevated Secret/service-role key in client code, browser bundles, logs, screenshots, or committed files. Never prefix it with `NEXT_PUBLIC_`. Admin privileged client modules must be server-only.

## Authentication and authorization

- Use the current official Supabase SSR approach for Next.js at implementation time; verify docs before introducing auth plumbing.
- Enforce authorization server-side/RLS, never only by hiding UI.
- Do not trust user-editable metadata for authorization.
- Never make Household Owner imply Platform Super Admin.

## Super Admin boundary

Before a privileged admin operation:

1. verify signed-in identity;
2. verify active Platform Super Admin authorization;
3. only then use the server-only elevated Supabase client;
4. audit privileged mutations.

The user app must not receive elevated credentials or hidden platform-wide data.

## Privacy and financial integrity

- Never fetch hidden financial fields merely to hide them in React.
- Prevent derived-data leakage where visible totals reconstruct a hidden value.
- Historical monthly snapshots remain immutable with respect to later recurring-template edits.
- Use documented domain functions/RPCs for atomic money-changing transitions where they exist.
- Do not weaken RLS or integrity constraints merely to make a UI implementation easier.

## Scope discipline

Implement the current milestone only. Do not silently add realtime, offline mutation queues, bank integrations, savings automation, AI features, analytics, or other future scope.

## Verification and reporting

Run every applicable check before claiming completion. Current root DB scripts use npm:

```bash
npm run db:reset
npm run db:test
npm run db:types
```

After apps exist, run their declared lint/build/test scripts through npm workspaces. Report:

- exact commands executed;
- pass/fail result;
- files changed;
- any unverified assumptions;
- any decision that still requires owner approval.

Never claim a command passed unless it actually ran successfully.
