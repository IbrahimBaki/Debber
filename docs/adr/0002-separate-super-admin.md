# ADR-0002 — Separate Super Admin application

Status: Accepted — 2026-09-10

## Decision

The platform Super Admin dashboard is a separate Next.js app and Vercel project from the household-facing PWA.

## Rationale

A separate application creates a clearer security and deployment boundary, prevents accidental admin UI exposure, and allows the Supabase Secret Key to exist only in the admin project's server environment.

## Consequences

- Same monorepo, separate Vercel projects.
- Separate environment variables and domain.
- Shared UI/types may live in packages, but privileged data modules must remain admin-only.
