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

## Privacy and lifecycle

The Owner-only planning summary RPC returns income, fixed commitments, and derived plan totals only to an Owner. Members retain section-level visibility under the existing RLS model and cannot obtain hidden totals that could reveal private income or commitments.

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

## Financial setup product decisions (post-D-027)

- Financial setup ends with an explicit Owner action, "ابدأ الشهر", which transitions the period Draft → Open via `set_budget_period_status(...)`. Entering income, commitments, or section data never auto-opens a period.
- The Owner may continue editing the plan while a period is Open, subject to existing validation and audit rules. Closed remains protected; month-closing UX is not implemented yet.
- Income remains monthly/non-recurring only in MVP; there is no recurring-income system.
- A new fixed commitment added during setup defaults to `يتكرر شهريًا` (monthly recurring, via `create_recurring_fixed_commitment`). The Owner may instead choose `هذا الشهر فقط` (this month only, via `create_one_time_fixed_commitment`). No weekly/yearly/custom recurrence schedules exist in MVP.
