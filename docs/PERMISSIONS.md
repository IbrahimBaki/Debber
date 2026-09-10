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
| View hidden owner income | Yes | No | Yes via admin server |
| Configure section budgets | Yes | No | Support/admin action only |
| Add expense to shared contributable section | Yes | Yes | Not through user workflow |
| Change visibility | Yes | No | Support/admin action only |
| View platform-wide users | No | No | Yes |
| List `auth.users` | No | No | Yes, server-side Auth Admin API |
| Bypass RLS | No | No | Server Secret-Key client only |
| Write admin audit log | No | No | Yes |

## 4. No-inference rules

- Member dashboards never compute global totals from hidden inputs.
- A private fixed commitment is not represented as an unnamed hidden amount in a shared chart.
- Shared spending totals include only the spending scope intentionally shared by that section.
- A member cannot enumerate hidden rows by count, placeholder, route ID, search results, or error differences.
- Historical access follows current authorization unless a future explicit historical-lock feature is designed.

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
