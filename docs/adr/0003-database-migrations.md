# ADR-0003 — Database changes are Git-first migrations

Status: Accepted — 2026-09-10

## Decision

Use Supabase declarative schema files plus timestamped migrations. Production database changes are applied from version control using Supabase CLI/CI, not manually through remote Studio.

## Required gate

Every database change must include, where applicable:

- changed `supabase/schemas/*.sql`;
- generated/reviewed `supabase/migrations/*.sql`;
- database/RLS tests;
- regenerated TypeScript database types;
- migration documentation.
