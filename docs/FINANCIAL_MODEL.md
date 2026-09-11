# Dabber Financial Model

## Planning and actuals are distinct

All values in a Household use its one configured currency and PostgreSQL `numeric(14,2)`.

### Planned income

A budget period can contain multiple `period_income_items`. Total planned income is their sum.

### Planned fixed commitments

Fixed commitments are Owner-only monthly snapshots in `period_fixed_commitments`. They are not spending sections and do not consume a flexible section allocation. Pending and paid snapshots contribute to planned commitments; skipped snapshots are excluded for that month.

### Variable spending plan

The Owner explicitly sets `budget_periods.spending_budget`. New periods start at zero. Reusable `budget_sections.default_planned_amount` values are suggestions and are never automatically applied.

Flexible `period_section_budgets` receive allocations from the spending budget. Their total may be lower than the budget but cannot exceed it. Reducing the spending budget below existing allocations is rejected atomically.

```text
available_after_commitments = total_planned_income - total_planned_commitments
plan_balance = available_after_commitments - spending_budget
unallocated_income = max(plan_balance, 0)
planned_deficit = max(-plan_balance, 0)
unallocated_spending_budget = spending_budget - total_section_allocations
```

Planned deficit is valid. Dabber represents it; it does not rewrite income, commitments, or the spending budget to remove it.

## Actual outflow

Posted transactions linked to flexible section snapshots are actual variable spending. They can exceed either an allocation or the spending budget:

```text
section_remaining = section_allocation - section_actual_spent
budget_remaining = spending_budget - actual_variable_spending_total
```

Both remaining values may be negative.

A paid `period_fixed_commitment` records exactly one fixed actual outflow on that snapshot. It does not create a variable transaction, so the same payment cannot be counted in both fixed and variable totals. Repeating the paid operation is idempotent.

## Recording a variable expense

`record_expense(p_period_section_budget_id, p_amount, p_occurred_at default null, p_description default null, p_transaction_id default null)` is the sole authoritative path for creating an ordinary (non-recurring-linked) transaction. There is no direct client `INSERT` grant on `transactions` for this purpose — the prior RLS policy that allowed one only checked `is_period_open_for_writes` (true for Draft *or* Open), which does not match the product rule that expense recording requires an **Open** period specifically, and nothing validated `occurred_at` against the period's date range or against the future. `record_expense(...)` enforces, in order:

1. The caller is authenticated (`created_by` is always `auth.uid()`; there is no way to attribute an expense to another user).
2. The caller is the Household owner, or `can_contribute_to_section(...)` grants them contribution on the section (a cross-Household section id, an `owner_only`/hidden section, or a `view`-only section for a Member all fail this check with the same `not_authorized` error).
3. The period's status is exactly `open` (`period_not_open` otherwise — Draft and Closed are both rejected).
4. `p_occurred_at` (defaulting to "today" in the Household's IANA timezone when omitted) falls within `[budget_periods.start_date, budget_periods.end_date]` and is not after "today" in that timezone (`expense_date_out_of_period` / `expense_date_in_future`).
5. `p_amount` is a positive value within the existing `numeric(14,2)` precision; the raw validated value is passed through to the RPC so Postgres, not JavaScript, is the arithmetic authority.

Idempotency mirrors the financial-setup creation operations (D-029): an optional caller-supplied `p_transaction_id` is inserted with `on conflict (id) do nothing`; a retry with the same id returns the existing row after confirming it belongs to the same period (a mismatch — reusing an id that belongs to another period/Household — raises `transaction_id_conflict`, `23505`). No new idempotency table was introduced.

Overspending a section allocation or the total spending budget is never blocked by `record_expense(...)`; `section_remaining` and `budget_remaining` are simply negative, matching the existing invariant above. Correcting a mistaken expense is void (`void_transaction(...)`) followed by a new `record_expense(...)` call — there is no transaction-editing or hard-delete path.

## Privacy and lifecycle

The Owner-only planning summary RPC returns income, fixed commitments, and derived plan totals only to an Owner. Members retain section-level visibility under the existing RLS model and cannot obtain hidden totals that could reveal private income or commitments.

The one exception is opt-in and narrow: when the Owner sets `households.share_total_income_with_members = true` (default `false`), a Member may call `get_member_visible_total_income(p_period_id)` to see the period's aggregate total planned income — never individual `income_sources`/`period_income_items` rows, which remain governed by their own unchanged `owner_only`-by-default RLS regardless of this toggle. A Member with sharing off, and any non-member, are never conflated: sharing-off returns SQL `NULL`; non-membership raises `not_authorized`. A shared-and-currently-zero period returns `0`, distinct from `NULL`. See `docs/DATABASE.md` §6.5 and `docs/PERMISSIONS.md` §3.1.

Planning mutations respect the existing Draft/Open/Closed lifecycle. Snapshot rows remain historical truth: changing reusable templates does not rewrite a created month.

## Domain operations

- `set_period_spending_budget(uuid, numeric)` atomically sets the Owner’s variable budget after validating existing allocations.
- `set_period_section_allocation(uuid, numeric)` atomically sets a flexible section allocation.
- `set_period_fixed_commitment_planned_amount(uuid, numeric)` updates an Owner’s current-period fixed plan.
- `set_period_fixed_commitment_skipped(uuid, boolean, text)` preserves monthly skipped semantics.
- `mark_period_fixed_commitment_paid(uuid, numeric)` records one fixed actual outflow.
- `get_owner_period_planning_summary(uuid)` supplies the canonical Owner-only calculation.
- `create_recurring_fixed_commitment(uuid, text, numeric, smallint, uuid)` atomically creates a reusable fixed-commitment template and its current-period snapshot; see `docs/DATABASE.md` §6.2.
- `create_one_time_fixed_commitment(uuid, text, numeric, date, uuid)` atomically creates a this-month-only fixed-commitment snapshot with no template; see `docs/DATABASE.md` §6.2.
- `create_flexible_budget_section(uuid, text, visibility_scope, section_member_access, uuid)` atomically creates a reusable flexible section and its current-period snapshot at a zero planned allocation; see `docs/DATABASE.md` §6.2.
- `set_budget_period_status(uuid, period_status, text)` performs the Draft → Open "ابدأ الشهر" (start month) transition; the Owner may keep editing the plan afterward while the period remains Open.
- `record_expense(uuid, numeric, date, text, uuid)` is the sole authoritative path for recording an ordinary variable expense; see "Recording a variable expense" below.
- `get_member_visible_total_income(uuid)` returns the summed `period_income_items.planned_amount` for a period: always to the Owner, and to a Member only when `households.share_total_income_with_members = true`; see "Privacy and lifecycle" below and `docs/DATABASE.md` §6.5.

## Financial setup product decisions (post-D-027)

- Financial setup ends with an explicit Owner action, "ابدأ الشهر", which transitions the period Draft → Open via `set_budget_period_status(...)`. Entering income, commitments, or section data never auto-opens a period.
- The Owner may continue editing the plan while a period is Open, subject to existing validation and audit rules. Closed remains protected; month-closing UX is not implemented yet.
- Income remains monthly/non-recurring only in MVP; there is no recurring-income system.
- A new fixed commitment added during setup defaults to `يتكرر شهريًا` (monthly recurring, via `create_recurring_fixed_commitment`). The Owner may instead choose `هذا الشهر فقط` (this month only, via `create_one_time_fixed_commitment`). No weekly/yearly/custom recurrence schedules exist in MVP.

## Quick Expense Entry Web implementation notes (`apps/web/src/app/app/expenses`)

- `apps/web/src/app/app/expenses/eligibility.ts` is the single authoritative place that resolves which flexible sections a user may record an expense into. Both `/app` (the landing CTA) and `/app/expenses/new` call this same function, so the security-sensitive filtering logic exists in exactly one place rather than being re-derived twice. It calls `ensure_budget_period(...)` (safe for both roles — it only requires active membership, never Owner) to resolve the current period without duplicating any period-boundary arithmetic in React, then branches on `budget_periods.status`.
- For an Owner, eligibility returns every flexible-kind `period_section_budgets` row for the period (RLS already grants full visibility via `is_household_owner(...)`). For a Member, it additionally filters to `budget_sections.visibility_scope = 'household' and member_access = 'contribute'` — the exact condition `can_contribute_to_section(...)` checks for the `household` scope. A hypothetical `custom`-scope grant (via `resource_permissions.can_edit`) is **not** evaluated by the selector: there is no UI anywhere yet for an Owner to create that grant, so a Member can never actually hold one today. This is a known, deliberate MVP scope limitation, not a privacy gap — `record_expense(...)` re-derives authorization itself regardless of what the selector shows, so a future custom-scoped Member would simply not see the section in the picker yet, never be incorrectly granted access to one they can't already use.
- `/app/expenses/new` requires `budget_periods.status = 'open'` to render the entry form; Draft and Closed both show a safe guidance state instead (Owner sees a path to `/app/plan`; a Member sees only generic copy, never why the Owner hasn't opened the month). The route never calls `get_owner_period_planning_summary(...)` — Owner-private planning data has no reason to exist on this surface at all.
- The entry form reuses `MoneyInput`, `Amount`, `Icon`, and `formatAmount`/`currencyLabel` from `apps/web/src/app/app/plan/` directly (via `@/app/app/plan/...` imports) rather than duplicating them, so the two surfaces share one visual/technical definition of "how an amount looks and behaves in Dabber." Page-level composition (not a bespoke larger input) is what gives the amount field its visual priority: it is the first field, autofocused, with generous surrounding space, while section/date/note are progressively quieter.
- The caller-supplied `p_transaction_id` for `record_expense(...)` is generated once per logical attempt (`crypto.randomUUID()` in the client) and reused across a failed-submission retry; a fresh id is only minted after a confirmed success or when the user explicitly starts a new expense ("إضافة مصروف آخر" / "تسجيل المصروف الصحيح" after a void).
- The overspend note after a successful save is computed from a fresh server-side refetch of the section's actual totals *after* the mutation (`apps/web/src/app/app/expenses/new/actions.ts`), never from client-side arithmetic on stale props — matching "server truth wins."
- **Known staging gap, not a silent one:** `apps/web/DESIGN.md` (APPROVED) documents "إضافة مصروف" as a fixed, persistent pill above mobile navigation / beside the header on desktop (`design-preview/page.module.css`'s `.expenseAction`/`.desktopAction`). This session wired the real action as a static link on the `/app` household-landing card instead, because no persistent app shell (bottom nav, fixed header) exists anywhere in the shipped app yet to anchor a floating action to — building one was out of this session's scope ("do not turn `/app` into a full dashboard"). This is a deliberate staging choice, expected to be revisited once a persistent `/app/*` shell exists, not an unnoticed divergence from the approved design system.

## Financial setup Web implementation notes (`apps/web/src/app/app/plan`)

- Income entry writes directly to `period_income_items` with `income_source_id = null` (the same nullable one-off shape `ensure_budget_period()` already supports), never to `income_sources`. Writing `income_sources` would make `ensure_budget_period()` regenerate that income item in every future period, which is recurring income and would contradict the "no recurring-income system in MVP" decision above. `one_off_visibility_scope` is left unset on insert so the column default (`owner_only`) applies; the UI does not offer a visibility choice.
- Income items support full CRUD (create/edit/delete) directly against `period_income_items` under its existing RLS grants (Owner + Draft/Open only), matching the simple-single-row-write guidance in `docs/ARCHITECTURE.md` §6.
- Fixed commitments and flexible sections have no delete operation at the database layer (`period_fixed_commitments`, `period_section_budgets`, and `budget_sections` grant no client `delete`). The setup UI does not offer deletion for these. For a recurring commitment the Owner no longer wants going forward, the UI offers "إيقاف التكرار" (stop recurring), which sets the persistent `fixed_commitment_templates.is_active = false` under its existing Owner `update` grant — the schema's own archive mechanism. This does not remove the current month's already-created snapshot (by design: snapshots are historical) and only prevents `ensure_budget_period()` from generating a snapshot from that template in future periods. For a commitment the Owner wants excluded from the current month's totals only, the existing "تخطي هذا الشهر" (skip) action is the correction path. There is no way to correct a commitment's name after creation in this milestone (no RPC updates `name_snapshot`); this is a known limitation, not a bug.
- `/app/plan` serves both the Draft setup wizard and the Open "edit the plan" surface — there is no separate month-landing route. The same five content steps (income, commitments, budget, sections, review) are freely navigable in both modes; only the review step's terminal action differs (`ابدأ الشهر` in Draft, an "الشهر مفتوح الآن" notice in Open).
