# Dabber — Agent Bootstrap Prompts

Use the same repository with Codex or Claude Code. Both must obey `AGENTS.md`; Claude also loads `CLAUDE.md`.

## Prompt 00 — inspect only, no changes

```text
Read AGENTS.md, CLAUDE.md if applicable, START_HERE.md, docs/DECISIONS.md, docs/LOCAL_ENVIRONMENT.md, docs/UI_DESIGN_GOVERNANCE.md, and the task-relevant product/architecture/database docs.

Do not modify anything yet. Inspect the repository and local environment relevant to Dabber. Do not stop, recreate, prune, or alter unrelated Docker services.

Report:
1. repository state and prerequisites;
2. active decision gates that block implementation;
3. any detected port/tooling conflict;
4. the exact next safe commands you recommend.

Do not make an unapproved product, schema, permission, dependency, deployment, or infrastructure decision.
```

## Impeccable initialization — after installation

Codex:

```text
$impeccable init
```

Claude Code:

```text
/impeccable init
```

After init, inspect `PRODUCT.md` and do not silently resolve facts marked open.

## Prompt 01 — local database bootstrap

Option A is approved under D-017. Use this prompt to bootstrap the local Dabber database.

```text
Execute only the local Dabber database bootstrap described in START_HERE.md using the existing Docker daemon. Do not edit or bring down the shared parent docker-compose stack.

Before starting Supabase, inspect active published ports and confirm the required Supabase local ports are available.

Then initialize config.toml if missing, start the project-scoped Supabase stack, rebuild the database from migrations, run database tests, and generate TypeScript database types.

Use npm/npx only.

Do not scaffold Next.js yet.
Do not create/link a hosted Supabase project.
Do not deploy.
Do not weaken RLS or change domain semantics to make a test pass.

If a failure requires a product/schema/security decision rather than an obvious implementation correction, stop and ask the owner.

At the end report exact commands, pass/fail results, Dabber containers created, files changed, and any unresolved issue.
```

## UI feature prompt template

Use after the app scaffold and Impeccable init exist.

```text
Implement only the approved feature/surface described in the current task. First read product decisions and Impeccable context. Use Impeccable as the authority for presentation-level UI/UX decisions.

Target a premium, distinctive, mobile-first result with excellent hierarchy, responsive financial information, purposeful motion and polished interaction states. Avoid generic dashboard aesthetics.

Use the appropriate Impeccable shaping/design workflow before non-trivial UI implementation, inspect the rendered result in the browser, and run suitable critique, animate, harden, audit and polish passes before calling it UI-complete. Respect reduced motion and accessibility.

Do not let UI changes alter financial semantics, privacy/RLS, permissions, authentication, MVP scope, or destructive behavior. If the design exposes a product decision, stop and ask the owner.

Report the design passes used, viewports checked, accessibility/responsive findings, tests/builds, and files changed.
```
