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
| `fixed_commitment_templates` | Reusable Owner-only fixed-commitment configuration, independent of spending sections. |
| `period_fixed_commitments` | Monthly fixed-commitment snapshots and their single fixed actual outflow. |
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
fixed_commitment_templates
```

Monthly history:

```text
budget_periods
period_income_items
period_section_budgets
monthly_items
period_fixed_commitments
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

## 6.2 Financial setup creation operations

`period_fixed_commitments` and `period_section_budgets` have no client `insert` grant; `fixed_commitment_templates` and `budget_sections` do, but a template/section row alone does not create the current-period snapshot the setup UI needs, and doing that as two separate browser calls is not atomic. Three narrow, Owner-authorized, `security definer` operations close this gap in one transaction each, valid only while the target period is `draft` or `open`:

- `create_recurring_fixed_commitment(p_period_id, p_name, p_planned_amount, p_due_day default null, p_template_id default null)` creates a reusable `fixed_commitment_templates` row and exactly one current-period `period_fixed_commitments` snapshot linked to it.
- `create_one_time_fixed_commitment(p_period_id, p_name, p_planned_amount, p_due_date default null, p_commitment_id default null)` creates exactly one current-period `period_fixed_commitments` snapshot with `fixed_commitment_template_id = null`; it never creates a template, so future periods never inherit it.
- `create_flexible_budget_section(p_period_id, p_name, p_visibility_scope default 'owner_only', p_member_access default 'view', p_section_id default null)` creates a reusable `budget_sections` row (`kind = 'flexible'`) and exactly one current-period `period_section_budgets` snapshot with `planned_amount = 0`; `default_planned_amount` is never copied into that snapshot.

All three derive the Household from the supplied period (never from a client-supplied Household id), require `is_household_owner(...)`, and combine the owner check with `is_period_open_for_writes(...)` into a single `not_authorized` (42501) rejection, matching the convention already used by `set_period_spending_budget(...)` and its siblings.

**Idempotency.** Each operation accepts an optional caller-supplied entity UUID (`p_template_id`, `p_commitment_id`, `p_section_id`). If omitted, the function generates one. The persistent row is inserted with `on conflict (id) do nothing`; a retry with the same id returns the existing row after verifying it belongs to the same Household (a mismatch raises `template_id_conflict` / `commitment_id_conflict` / `section_id_conflict`, SQLSTATE `23505`). The current-period snapshot then relies on the *existing* natural unique keys `period_fixed_commitments(period_id, fixed_commitment_template_id)` and `period_section_budgets(period_id, section_id)` — the same keys `ensure_budget_period(...)` already uses — so a retried recurring/section creation and a subsequent `ensure_budget_period()` call can never produce a duplicate current snapshot. The one-time commitment has no template to key off, so its own row id is the idempotency key. No new idempotency table or column was introduced. Same-id-with-different-payload is treated as the same logical operation: the pre-existing row wins and the new payload is discarded, not merged.

An audit event (`fixed_commitment.created` / `budget_section.created`) is written only on first creation, not on an idempotent retry, matching the pattern already used by `mark_period_fixed_commitment_paid(...)`.

## 6.3 Scope-immutability coverage

`enforce_immutable_scope_fields()` (`supabase/schemas/026_immutability.sql`) is a single `before update` trigger function, attached per table, that blocks a row's scope/identity columns from being reassigned after creation — it exists so a legitimate write path can never move a historical or scoped row across a security boundary. Every persistent/monthly-snapshot table pair carries it: `income_sources`/`period_income_items`, `budget_sections`/`period_section_budgets`, `recurring_templates`/`monthly_items`, and — as of the fixed-commitment domain's forward migration — `fixed_commitment_templates`/`period_fixed_commitments`. Frozen columns follow the same shape as their sibling pair in each case:

- `fixed_commitment_templates`: `household_id`, `created_by` (same set as `recurring_templates`, `income_sources`, `budget_sections`).
- `period_fixed_commitments`: `period_id`, `fixed_commitment_template_id`, `created_by` (same shape as `period_income_items`).

Mutable financial fields are deliberately excluded, mirroring `monthly_items`' and `period_income_items`' choice not to freeze their equivalent columns: `planned_amount`, `actual_amount`, `status`, `name_snapshot`, and `due_date`/`due_day` all remain writable through the approved RPCs (`set_period_fixed_commitment_planned_amount(...)`, `set_period_fixed_commitment_skipped(...)`, `mark_period_fixed_commitment_paid(...)`) and, on `fixed_commitment_templates`, through the existing Owner `update` grant. The trigger only rejects a write when a frozen column's value would actually change (`is distinct from`); writing back the same value is not blocked.

`period_fixed_commitments` (like `period_section_budgets`) has no client `update` grant at all, so its trigger is unreachable through ordinary RLS-governed access — its purpose is to guard the table's only write path, the `security definer` RPCs above, which run with elevated privileges that bypass table grants. Test it accordingly (directly, not through the `authenticated` role) — see `supabase/tests/database/fixed_commitment_immutability.test.sql`.

## 6.4 Ordinary expense creation

`record_expense(p_period_section_budget_id, p_amount, p_occurred_at, p_description, p_transaction_id)` is the sole authoritative path for creating an ordinary (non-recurring-linked) `transactions` row. `public.transactions` has **no client `insert` grant**: the RLS policy that previously allowed a direct authenticated insert (`"Contributors can create ordinary transactions"`) was dropped because its only lifecycle check, `is_period_open_for_writes(...)`, is true for `draft` *or* `open` — it did not authoritatively require `open` specifically, and nothing validated `occurred_at` against the period's date range or the future. Both are now enforced inside the function (see `docs/FINANCIAL_MODEL.md`, "Recording a variable expense," for the full check sequence and idempotency mechanism, which follows the same caller-supplied-UUID pattern as §6.2).

`mark_monthly_item_paid(...)` (the separate legacy linked-recurring-payment path, which inserts a `transactions` row with `monthly_item_id` set) is unaffected: it is already `security definer` and never relied on the removed policy. The `transactions` `select` and `update` grants/policies are also unchanged; only ordinary-transaction `insert` was narrowed.

## 7. Money calculations

Owner planning model:

```text
total planned income
- total planned fixed commitments
= available after commitments

available after commitments
- owner-defined spending budget
= plan balance

positive plan balance = unallocated income
negative plan balance = planned deficit
```

Variable spending model:

```text
spending budget
- flexible section allocations
= unallocated spending budget

section allocation
- Sum(posted transactions in section)
= Section remaining
```

Flexible allocations must not exceed the spending budget, but may be lower. Actual variable spending may exceed either a section allocation or the spending budget; negative remaining values are retained rather than clamped.

Fixed commitment planned total is the sum of `pending` and `paid` `period_fixed_commitments`; `skipped` excludes the commitment for that month, matching the existing monthly-item convention. `mark_period_fixed_commitment_paid(...)` records the one fixed actual outflow directly on its monthly snapshot. It does not create a variable-section transaction, preventing double counting.

`budget_sections.default_planned_amount` remains reusable configuration only. `ensure_budget_period(...)` creates new period section snapshots at zero and sets `budget_periods.spending_budget` to zero; an Owner must explicitly establish that month’s variable plan.

`period_section_budgets.section_kind_snapshot = fixed` and `monthly_items` remain in the schema for existing historical/legacy recurring section data. New fixed-commitment planning and payment flows use `fixed_commitment_templates` and `period_fixed_commitments`; they do not require a budget section and do not contribute to variable spending.

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
