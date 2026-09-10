# Dabber — Shared Local Docker Environment

The development host already runs multiple unrelated projects through a shared Docker Compose environment. This file records only the non-secret integration facts relevant to Dabber. It must not copy credentials from the parent environment.

## Observed published ports in the shared Compose

| Service | Host ports observed | Dabber rule |
|---|---:|---|
| Apache/webserver | 80, 443 | Do not modify/rebind without owner approval. |
| Existing MySQL | 3306 bound to localhost | Not used by Dabber; Dabber uses Supabase PostgreSQL. |
| Existing local mail UI/SMTP | 8025, 1025 | Do not reuse unless separately approved. |
| MCP service | 4000 | Preserve. |
| n8n | 5678 | Preserve. |

Current Supabase CLI local defaults occupy a different range (API 54321, DB 54322, Studio 54323, local mail 54324-54326, plus shadow DB 54320), so there is no observed direct published-port collision at the time this document was created. Always re-check before starting because the shared host can change.

## Safety rule

Dabber tooling must be scoped to Dabber. Never run global Docker cleanup/prune commands or `docker compose down` against the parent shared environment.

## Approved local Supabase decision — D-017

The owner still needs to approve how local Supabase joins this host:

### A — Supabase CLI-managed isolated stack on the existing Docker daemon (recommended)

Run `npx supabase start` from the Dabber repository. Supabase owns its project-specific local containers. Keep the parent Compose unchanged. This preserves the normal Supabase CLI migration/reset/test workflow.

### B — Manually integrate Supabase services into the parent Compose

Not recommended. It couples Dabber to shared infrastructure and creates substantially more Compose/config/upgrade responsibility. Only do this if the owner explicitly selects it.
