# Dabber Database Design v2.0

## 1. Core principles

1. Historical month data is snapshotted; templates never rewrite history.
2. Money uses PostgreSQL `numeric(14,2)`, never floating point.
3. Financial records are scoped to a household and protected by RLS.
4. Privacy is primarily a section boundary for spending in MVP.
5. Closed periods are immutable to ordinary member workflows.
6. Critical cross-table scope relationships are validated by database triggers.
7. Destructive financial history uses void/archive semantics instead of silent hard deletion.

## 2. Identity and platform tables

| Table | Purpose |
| --- | --- |
| `profiles` | Application profile linked 1:1 to `auth.users`. |
| `households` | Shared financial workspace. |
| `household_members` | Household-level owner/member membership. |
| `household_invitations` | Invitation lifecycle using hashed tokens. |
| `platform_admins` | Platform-level operators; separate from household roles. |
| `resource_permissions` | Per-member custom grants for resources with `visibility_scope = custom`. |

## 3. Financial tables

| Table | Purpose |
| --- | --- |
| `budget_periods` | One financial cycle per household and start date. |
| `income_sources` | Recurring/default income source configuration. |
| `period_income_items` | Monthly income snapshots and one-off income. |
| `budget_sections` | Persistent section configuration and privacy boundary. |
| `period_section_budgets` | Monthly section snapshot with planned amount and historical name/kind. |
| `recurring_templates` | Persistent recurring obligation/item configuration. |
| `monthly_items` | Monthly recurring item snapshot with Pending/Paid/Skipped state. |
| `transactions` | Actual spending entries. |
| `audit_events` | Household-sensitive audit events. |
| `admin_audit_logs` | Super Admin privileged mutation log. |

## 4. Why sections are the spending privacy boundary

Suppose a shared section shows:

```text
Budget: 12,000
Spent: 8,000
Remaining: 4,000
```

If one transaction worth 2,000 were hidden while totals still included it, a partner could infer the hidden amount from balance changes. If totals excluded it, the displayed remaining budget would become operationally incorrect.

Therefore MVP rule:

> All spending that affects a shared section balance follows the section's visibility boundary.

Private commitments should be modeled in a private section. A future version may support separate permissions for aggregate visibility vs line-item detail, but only as an explicit product feature.

## 5. Snapshot semantics

Persistent configuration:

```text
income_sources
budget_sections
recurring_templates
```

Monthly history:

```text
budget_periods
period_income_items
period_section_budgets
monthly_items
transactions
```

Historical names and planned values are copied to monthly tables. Current privacy rules may still revoke historical access because the historical row remains linked to the persistent resource that owns the privacy boundary.

## 6. Important constraints

- `budget_periods(household_id, period_key)` unique.
- `household_members(household_id, user_id)` unique.
- `period_section_budgets(period_id, section_id)` unique.
- Only one monthly snapshot per recurring template per period.
- Only one posted transaction per monthly recurring item in MVP.
- Cross-household/period mismatches are rejected by validation triggers.
- `households.currency_code` is constrained to the MVP catalogue: `EGP`, `SAR`, `USD`, and `EUR`.
- `period_start_day` is constrained to 1–31. When the configured day is absent from a month, period calculation clamps to that month’s final valid day; a period ends one day before the next clamped start.
- Existing `budget_periods` retain their stored boundaries when a Household later changes `period_start_day`.

## 6.1 Onboarding domain operations

- `list_my_pending_household_invitations()` securely derives the authenticated user from `auth.uid()` and returns only safe onboarding display fields for that user’s non-expired pending invitations.
- `accept_household_invitation_by_id(uuid)` atomically validates the invitation recipient and creates an MVP `member` membership. The existing token-hash acceptance RPC remains available for invitation-link entry points.
- `create_initial_household(...)` is the only authenticated-client Household creation operation. It is serialized and retry-safe, returns an existing active Household on retry, and relies on the existing insert trigger to create the `owner` membership transactionally.

## 7. Money calculations

Owner full model:

```text
Total income
- Fixed commitments
- Flexible allocations
= Unallocated / reserve
```

Shared section model:

```text
Section planned amount
- Sum(posted transactions in section)
= Section remaining
```

Fixed commitment planned total can be computed from pending/paid monthly item planned amounts within fixed sections. Actual spending comes from posted transactions so a paid recurring item is not counted twice.

## 8. Future domains not created yet

Do not add unused tables simply because the roadmap mentions them. Add by migration when the feature is implemented:

- Savings goals.
- Goal contributions.
- Sinking funds.
- Debt/settlement.
- Attachments/receipts.
- Bank connections.
- Multi-currency ledger.

The current model leaves room for these without forcing them into MVP semantics.
