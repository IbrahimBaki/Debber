-- Dabber declarative schema: indexes supporting foreign keys, dashboards, RLS and common filters.

create index household_members_user_active_idx
  on public.household_members (user_id, household_id)
  where status = 'active';
create index household_members_household_active_idx
  on public.household_members (household_id, user_id)
  where status = 'active';
create index resource_permissions_lookup_idx
  on public.resource_permissions (household_id, resource_type, resource_id, user_id);
create index budget_periods_household_dates_idx
  on public.budget_periods (household_id, start_date desc);
create index income_sources_household_active_idx
  on public.income_sources (household_id, sort_order)
  where is_active = true and archived_at is null;
create index period_income_items_period_idx
  on public.period_income_items (period_id);
create index budget_sections_household_active_idx
  on public.budget_sections (household_id, sort_order)
  where is_active = true and archived_at is null;
create index period_section_budgets_period_idx
  on public.period_section_budgets (period_id, section_id);
create index recurring_templates_household_active_idx
  on public.recurring_templates (household_id, section_id)
  where is_active = true and archived_at is null;
create index monthly_items_period_status_idx
  on public.monthly_items (period_id, status, due_date);
create index transactions_period_section_idx
  on public.transactions (period_id, period_section_budget_id, occurred_at desc)
  where state = 'posted';
create index transactions_created_by_idx
  on public.transactions (created_by, occurred_at desc);
create index audit_events_household_created_idx
  on public.audit_events (household_id, created_at desc);
create index admin_audit_logs_admin_created_idx
  on public.admin_audit_logs (admin_user_id, created_at desc);
