# Dabber Permission Model

## 1. Two independent authorization layers

### Platform layer

`SUPER_ADMIN` is a Dabber platform operator. It is not a household role.

### Household layer

- `owner`: financial owner of a household.
- `member`: partner/household collaborator.

Never treat a household owner as a platform admin and never unlock the platform console through household data.

## 2. Visibility scopes

`owner_only`
: Only the household owner can access the resource.

`household`
: Active household members can view the resource.

`custom`
: Owner plus users listed in `resource_permissions` with `can_view = true`.

For budget sections, `member_access` separately controls whether a visible member can merely view or can contribute transactions/checklist actions.

## 3. Permission matrix

| Capability | Owner | Member | Super Admin |
| --- | ---: | ---: | ---: |
| View own household | Yes | If active member | Yes via admin server |
| View hidden owner income (individual rows) | Yes | No | Yes via admin server |
| View aggregate total planned income for a period | Yes | Only if `households.share_total_income_with_members = true` (else `NULL`, distinct from a real `0`) | Yes via admin server |
| Toggle total-income sharing for the household | Yes | No | Support/admin action only |
| Configure section budgets | Yes | No | Support/admin action only |
| Add expense to shared contributable section | Yes | Yes | Not through user workflow |
| Change visibility | Yes | No | Support/admin action only |
| View platform-wide users | No | No | Yes |
| List `auth.users` | No | No | Yes, server-side Auth Admin API |
| Bypass RLS | No | No | Server Secret-Key client only |
| Write admin audit log | No | No | Yes |

### 3.1 Total income sharing (MVP)

`households.share_total_income_with_members` is a single household-wide boolean, Owner-controlled, default `false`. It governs exactly one narrow read path — `get_member_visible_total_income(p_period_id)` — and nothing else:

- The Owner toggles it through the existing Household `update` RLS policy (`is_household_owner(...)` / `owner_user_id = auth.uid()`); no dedicated RPC exists solely for this write.
- Any active household member (Owner or Member) may read the boolean itself via the existing Household `select` policy — the setting's current state is not sensitive.
- The RPC returns the real summed `planned_amount` to the Owner unconditionally, and to a Member only when the flag is `true`. `NULL` strictly means "not shared with this caller"; `0` strictly means "shared, and currently zero." These are never conflated.
- A non-member of the period's household always receives `not_authorized` (`42501`), regardless of the flag — never `NULL`, so a rejected caller can never be mistaken for a member with sharing off.
- Enabling this flag never exposes individual `income_sources` or `period_income_items` rows to a Member; their existing `owner_only`-by-default RLS is untouched by this feature.

### 3.2 Section sharing modes (MVP Web UI)

The Owner's `/app/plan` Sections step exposes exactly three sharing modes over the existing `visibility_scope`/`member_access` columns: `خاص بيا` (`owner_only`), `مشترك — مشاهدة` (`household`/`view`), and `مشترك — مساهمة` (`household`/`contribute`). `custom` is not offered by this control and is never silently rewritten to one of the three modes; an existing `custom` section renders as a plain, non-destructive unsupported state until the Owner explicitly picks one of the three. Because MVP evaluates section access against **current** authorization (see §4 below), broadening a section from `owner_only` (or an existing `custom` grant) into either `household` mode can make that section's previously recorded transactions newly visible to Members — the UI shows a lightweight confirmation before that specific transition, and only that one; narrowing access, or moving between the two `household` submodes, applies immediately.

## 4. No-inference rules

- Member dashboards never compute global totals from hidden inputs.
- A private fixed commitment is not represented as an unnamed hidden amount in a shared chart.
- Shared spending totals include only the spending scope intentionally shared by that section.
- A member cannot enumerate hidden rows by count, placeholder, route ID, search results, or error differences.
- **Historical access follows current authorization (intentionally accepted MVP limitation).** A Member's visibility of `spending_budget` and of a section's allocation/spent/remaining/overspend and transactions is evaluated against the section's *current* `visibility_scope`/`member_access`, not a point-in-time record of what was authorized when that historical period was open. If the Owner later widens or narrows a section's visibility, that change is retroactively visible (or invisible) across all of that section's historical periods, not just future ones. This is a deliberately accepted MVP simplification for launch (see D-031 in `docs/DECISIONS.md`), not an unknown bug and not something already mitigated by a historical-snapshot mechanism — no `visibility_scope_snapshot`/`member_access_snapshot` migration exists in this codebase. A dedicated historical-permission-lock feature remains explicitly deferred hardening work, to be designed and approved separately if the owner decides it is needed post-MVP.

## 5. RLS rules

Every table exposed through the public API schema has RLS enabled. Grants and RLS are treated together; a policy alone is not sufficient if the database grants are too broad.

Authorization helper functions are `security definer` but expose only boolean/scoping decisions and use an empty `search_path` with fully-qualified relation names.

## 6. Super Admin flow

```text
Admin browser
  ↓ normal login
Next.js admin server
  ↓ verify session
platform_admins self-check under RLS
  ↓ require active super_admin
create server-only Secret-Key Supabase client
  ↓ no end-user access token attached
platform-wide query/Auth Admin API
```

The Secret Key never appears in client JavaScript, HTML, local storage, or a `NEXT_PUBLIC_*` environment variable.

## 7. Testing requirement

For every RLS-protected table, add at least:

- owner allow case;
- authorized member allow case where applicable;
- unauthorized member deny case;
- unrelated household deny case;
- anonymous deny case.

The repository starts with structural pgTAP checks. Behavioral policy tests should be added alongside each feature milestone before beta.
