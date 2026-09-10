-- Dabber declarative schema: cross-table integrity checks that ordinary foreign keys cannot express cleanly.

create or replace function public.validate_recurring_template_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_section_household_id uuid;
begin
  select s.household_id into v_section_household_id
  from public.budget_sections s
  where s.id = new.section_id;

  if v_section_household_id is distinct from new.household_id then
    raise exception 'recurring_template_section_household_mismatch' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger recurring_templates_validate_scope
before insert or update on public.recurring_templates
for each row execute function public.validate_recurring_template_scope();

create or replace function public.validate_period_section_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_period_household_id uuid;
  v_section_household_id uuid;
begin
  select bp.household_id into v_period_household_id
  from public.budget_periods bp where bp.id = new.period_id;
  select s.household_id into v_section_household_id
  from public.budget_sections s where s.id = new.section_id;

  if v_period_household_id is distinct from v_section_household_id then
    raise exception 'period_section_household_mismatch' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger period_section_budgets_validate_scope
before insert or update on public.period_section_budgets
for each row execute function public.validate_period_section_scope();

create or replace function public.validate_monthly_item_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_psb_period_id uuid;
  v_psb_section_id uuid;
  v_template_section_id uuid;
begin
  select psb.period_id, psb.section_id
  into v_psb_period_id, v_psb_section_id
  from public.period_section_budgets psb
  where psb.id = new.period_section_budget_id;

  if v_psb_period_id is distinct from new.period_id then
    raise exception 'monthly_item_period_mismatch' using errcode = '23514';
  end if;

  if new.recurring_template_id is not null then
    select rt.section_id into v_template_section_id
    from public.recurring_templates rt
    where rt.id = new.recurring_template_id;

    if v_template_section_id is distinct from v_psb_section_id then
      raise exception 'monthly_item_template_section_mismatch' using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

create trigger monthly_items_validate_scope
before insert or update on public.monthly_items
for each row execute function public.validate_monthly_item_scope();

create or replace function public.validate_transaction_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_psb_period_id uuid;
  v_item_period_id uuid;
  v_item_psb_id uuid;
begin
  select psb.period_id into v_psb_period_id
  from public.period_section_budgets psb
  where psb.id = new.period_section_budget_id;

  if v_psb_period_id is distinct from new.period_id then
    raise exception 'transaction_period_section_mismatch' using errcode = '23514';
  end if;

  if new.monthly_item_id is not null then
    select mi.period_id, mi.period_section_budget_id
    into v_item_period_id, v_item_psb_id
    from public.monthly_items mi
    where mi.id = new.monthly_item_id;

    if v_item_period_id is distinct from new.period_id
       or v_item_psb_id is distinct from new.period_section_budget_id then
      raise exception 'transaction_monthly_item_mismatch' using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

create trigger transactions_validate_scope
before insert or update on public.transactions
for each row execute function public.validate_transaction_scope();
