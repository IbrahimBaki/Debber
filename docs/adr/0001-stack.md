# ADR-0001 — Use Next.js + Supabase + Vercel

Status: Accepted — 2026-09-10

## Decision

Use Next.js App Router + TypeScript for application code, Supabase for Auth/PostgreSQL/RLS, and Vercel for application hosting.

## Consequences

- One primary language across frontend/server UI code.
- Database remains authoritative for row-level authorization.
- Local Supabase CLI becomes mandatory for reproducible database development.
- No Laravel backend is part of the selected architecture.
