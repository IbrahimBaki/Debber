# Dabber ERD

```mermaid
erDiagram
  AUTH_USERS ||--|| PROFILES : has
  AUTH_USERS ||--o{ HOUSEHOLDS : owns
  AUTH_USERS ||--o{ HOUSEHOLD_MEMBERS : joins
  HOUSEHOLDS ||--o{ HOUSEHOLD_MEMBERS : contains
  HOUSEHOLDS ||--o{ HOUSEHOLD_INVITATIONS : invites
  AUTH_USERS ||--o| PLATFORM_ADMINS : may_be

  HOUSEHOLDS ||--o{ BUDGET_PERIODS : has
  HOUSEHOLDS ||--o{ INCOME_SOURCES : configures
  BUDGET_PERIODS ||--o{ PERIOD_INCOME_ITEMS : snapshots
  INCOME_SOURCES ||--o{ PERIOD_INCOME_ITEMS : creates

  HOUSEHOLDS ||--o{ BUDGET_SECTIONS : configures
  BUDGET_PERIODS ||--o{ PERIOD_SECTION_BUDGETS : snapshots
  BUDGET_SECTIONS ||--o{ PERIOD_SECTION_BUDGETS : creates

  BUDGET_SECTIONS ||--o{ RECURRING_TEMPLATES : contains
  PERIOD_SECTION_BUDGETS ||--o{ MONTHLY_ITEMS : contains
  RECURRING_TEMPLATES ||--o{ MONTHLY_ITEMS : snapshots

  BUDGET_PERIODS ||--o{ TRANSACTIONS : contains
  PERIOD_SECTION_BUDGETS ||--o{ TRANSACTIONS : categorizes
  MONTHLY_ITEMS ||--o| TRANSACTIONS : paid_by

  HOUSEHOLDS ||--o{ RESOURCE_PERMISSIONS : grants
  HOUSEHOLDS ||--o{ AUDIT_EVENTS : records
  AUTH_USERS ||--o{ ADMIN_AUDIT_LOGS : acts
```

## Notes

- `auth.users` is owned by Supabase Auth and is not recreated in the public schema.
- `resource_permissions` uses a polymorphic `resource_type/resource_id` pair for custom grants; domain code validates the target resource.
- Recurring item privacy inherits its section in MVP to prevent aggregate inference problems.
- Savings/goals are intentionally not in the initial schema and will be introduced by later migrations when the feature starts.
