-- Dabber declarative schema: immutable ownership/scope fields.
-- These prevent legitimate users from moving historical or scoped rows across security boundaries via UPDATE.

create or replace function public.enforce_immutable_scope_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_table_name = 'budget_periods' then
    if new.household_id is distinct from old.household_id
       or new.period_key is distinct from old.period_key
       or new.start_date is distinct from old.start_date
       or new.end_date is distinct from old.end_date
       or new.created_by is distinct from old.created_by then
      raise exception 'immutable_budget_period_scope' using errcode = '23514';
    end if;
  elsif tg_table_name = 'income_sources' then
    if new.household_id is distinct from old.household_id
       or new.created_by is distinct from old.created_by then
      raise exception 'immutable_income_source_scope' using errcode = '23514';
    end if;
  elsif tg_table_name = 'period_income_items' then
    if new.period_id is distinct from old.period_id
       or new.income_source_id is distinct from old.income_source_id
       or new.created_by is distinct from old.created_by then
      raise exception 'immutable_period_income_scope' using errcode = '23514';
    end if;
  elsif tg_table_name = 'budget_sections' then
    if new.household_id is distinct from old.household_id
       or new.created_by is distinct from old.created_by then
      raise exception 'immutable_budget_section_scope' using errcode = '23514';
    end if;
  elsif tg_table_name = 'period_section_budgets' then
    if new.period_id is distinct from old.period_id
       or new.section_id is distinct from old.section_id then
      raise exception 'immutable_period_section_scope' using errcode = '23514';
    end if;
  elsif tg_table_name = 'recurring_templates' then
    if new.household_id is distinct from old.household_id
       or new.created_by is distinct from old.created_by then
      raise exception 'immutable_recurring_template_scope' using errcode = '23514';
    end if;
  elsif tg_table_name = 'monthly_items' then
    if new.period_id is distinct from old.period_id
       or new.period_section_budget_id is distinct from old.period_section_budget_id
       or new.recurring_template_id is distinct from old.recurring_template_id
       or new.created_by is distinct from old.created_by then
      raise exception 'immutable_monthly_item_scope' using errcode = '23514';
    end if;
  elsif tg_table_name = 'transactions' then
    if new.period_id is distinct from old.period_id
       or new.monthly_item_id is distinct from old.monthly_item_id
       or new.created_by is distinct from old.created_by then
      raise exception 'immutable_transaction_scope' using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

create trigger budget_periods_immutable_scope before update on public.budget_periods
for each row execute function public.enforce_immutable_scope_fields();
create trigger income_sources_immutable_scope before update on public.income_sources
for each row execute function public.enforce_immutable_scope_fields();
create trigger period_income_items_immutable_scope before update on public.period_income_items
for each row execute function public.enforce_immutable_scope_fields();
create trigger budget_sections_immutable_scope before update on public.budget_sections
for each row execute function public.enforce_immutable_scope_fields();
create trigger period_section_budgets_immutable_scope before update on public.period_section_budgets
for each row execute function public.enforce_immutable_scope_fields();
create trigger recurring_templates_immutable_scope before update on public.recurring_templates
for each row execute function public.enforce_immutable_scope_fields();
create trigger monthly_items_immutable_scope before update on public.monthly_items
for each row execute function public.enforce_immutable_scope_fields();
create trigger transactions_immutable_scope before update on public.transactions
for each row execute function public.enforce_immutable_scope_fields();
