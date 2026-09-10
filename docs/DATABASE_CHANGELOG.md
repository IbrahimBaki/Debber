# Database Change Log

This human-readable log complements the executable files in `supabase/migrations/`. The SQL migration remains the deployment source of truth.

| Migration | Date | Summary | Data Backfill | Risk/Notes |
| --- | --- | --- | --- | --- |
| `20260910190000_initial_dabber_schema.sql` | 2026-09-10 | Initial identity, household, finance, RLS, integrity, audit, indexes and core RPC baseline. | None | New schema baseline. Must pass clean local `db reset` before first production link/push. |

## Rule

Never edit a migration after it has been applied to production. Fixes are always new forward migrations and new entries in this changelog.
