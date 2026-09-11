-- Migration: 20260911131032_harden_financial_planning_semantics
-- Purpose: Separate fixed commitments from variable section budgets and establish
-- owner-authorized, atomic monthly planning operations.
-- Data migration: Existing section/recurring data remains historical and intact.
-- New budget periods start with a zero spending budget and zero section allocations.
-- Rollback: Forward migration only. Do not delete migration history.

alter table public.budget_periods
  add column spending_budget numeric(14,2) not null default 0
    check (spending_budget >= 0);

create table public.fixed_commitment_templates (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 160),
  default_amount numeric(14,2) not null default 0 check (default_amount >= 0),
  due_day smallint check (due_day is null or due_day between 1 and 28),
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.period_fixed_commitments (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.budget_periods(id) on delete cascade,
  fixed_commitment_template_id uuid references public.fixed_commitment_templates(id) on delete set null,
  name_snapshot text not null check (char_length(name_snapshot) between 1 and 160),
  planned_amount numeric(14,2) not null default 0 check (planned_amount >= 0),
  actual_amount numeric(14,2) check (actual_amount is null or actual_amount >= 0),
  due_date date,
  status public.monthly_item_status not null default 'pending',
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index period_fixed_commitments_template_period_unique
on public.period_fixed_commitments (period_id, fixed_commitment_template_id)
where fixed_commitment_template_id is not null;

create trigger fixed_commitment_templates_set_updated_at before update on public.fixed_commitment_templates
for each row execute function public.set_updated_at();
create trigger period_fixed_commitments_set_updated_at before update on public.period_fixed_commitments
for each row execute function public.set_updated_at();

alter table public.fixed_commitment_templates enable row level security;
alter table public.period_fixed_commitments enable row level security;
revoke all on table public.fixed_commitment_templates from anon, authenticated;
revoke all on table public.period_fixed_commitments from anon, authenticated;

grant select, insert, update on table public.fixed_commitment_templates to authenticated;
create policy "Owners can read fixed commitment templates"
on public.fixed_commitment_templates for select to authenticated
using ((select public.is_household_owner(household_id)));
create policy "Owners can create fixed commitment templates"
on public.fixed_commitment_templates for insert to authenticated
with check ((select public.is_household_owner(household_id)) and created_by = (select auth.uid()));
create policy "Owners can update fixed commitment templates"
on public.fixed_commitment_templates for update to authenticated
using ((select public.is_household_owner(household_id)))
with check ((select public.is_household_owner(household_id)));

grant select on table public.period_fixed_commitments to authenticated;
create policy "Owners can read period fixed commitments"
on public.period_fixed_commitments for select to authenticated
using ((select public.is_household_owner(public.period_household_id(period_id))));

revoke insert, update on table public.period_section_budgets from authenticated;
drop policy if exists "Owners can create monthly section budgets" on public.period_section_budgets;
drop policy if exists "Owners can update monthly section budgets" on public.period_section_budgets;

create or replace function public.ensure_budget_period(p_household_id uuid)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_timezone text;
  v_start_day integer;
  v_local_date date;
  v_target_month date;
  v_next_target_month date;
  v_start_date date;
  v_next_start_date date;
  v_end_date date;
  v_period_id uuid;
begin
  if v_uid is null or not public.is_household_member(p_household_id) then raise exception 'not_authorized' using errcode = '42501'; end if;
  select h.timezone, h.period_start_day into v_timezone, v_start_day from public.households h where h.id = p_household_id and h.archived_at is null;
  if v_timezone is null then raise exception 'household_not_found' using errcode = 'P0002'; end if;
  v_local_date := (now() at time zone v_timezone)::date;
  if v_local_date >= public.clamped_period_start_date(extract(year from v_local_date)::integer, extract(month from v_local_date)::integer, v_start_day) then
    v_target_month := date_trunc('month', v_local_date)::date;
  else v_target_month := (date_trunc('month', v_local_date)::date - interval '1 month')::date; end if;
  v_next_target_month := (v_target_month + interval '1 month')::date;
  v_start_date := public.clamped_period_start_date(extract(year from v_target_month)::integer, extract(month from v_target_month)::integer, v_start_day);
  v_next_start_date := public.clamped_period_start_date(extract(year from v_next_target_month)::integer, extract(month from v_next_target_month)::integer, v_start_day);
  v_end_date := v_next_start_date - 1;
  insert into public.budget_periods (household_id, period_key, start_date, end_date, status, created_by)
  values (p_household_id, v_start_date, v_start_date, v_end_date, 'draft', v_uid)
  on conflict (household_id, period_key) do update set updated_at = public.budget_periods.updated_at
  returning id into v_period_id;
  insert into public.period_section_budgets (period_id, section_id, section_name_snapshot, section_kind_snapshot, planned_amount)
  select v_period_id, s.id, s.name, s.kind, 0 from public.budget_sections s
  where s.household_id = p_household_id and s.is_active and s.archived_at is null
  on conflict (period_id, section_id) do nothing;
  insert into public.period_fixed_commitments (period_id, fixed_commitment_template_id, name_snapshot, planned_amount, due_date, status, created_by)
  select v_period_id, fct.id, fct.name, fct.default_amount,
    case when fct.due_day is null then null when fct.due_day >= v_start_day then make_date(extract(year from v_start_date)::integer, extract(month from v_start_date)::integer, fct.due_day) else make_date(extract(year from v_next_start_date)::integer, extract(month from v_next_start_date)::integer, fct.due_day) end,
    'pending', v_uid
  from public.fixed_commitment_templates fct
  where fct.household_id = p_household_id and fct.is_active and fct.archived_at is null
  on conflict (period_id, fixed_commitment_template_id) where fixed_commitment_template_id is not null do nothing;
  insert into public.period_income_items (period_id, income_source_id, name_snapshot, planned_amount, one_off_visibility_scope, created_by)
  select v_period_id, src.id, src.name, src.default_amount, src.visibility_scope, v_uid from public.income_sources src
  where src.household_id = p_household_id and src.is_active and src.archived_at is null
  on conflict (period_id, income_source_id) where income_source_id is not null do nothing;
  insert into public.monthly_items (period_id, period_section_budget_id, recurring_template_id, name_snapshot, planned_amount, due_date, status, created_by)
  select v_period_id, psb.id, rt.id, rt.name, rt.default_amount,
    case when rt.due_day is null then null when rt.due_day >= v_start_day then make_date(extract(year from v_start_date)::integer, extract(month from v_start_date)::integer, rt.due_day) else make_date(extract(year from v_next_start_date)::integer, extract(month from v_next_start_date)::integer, rt.due_day) end,
    'pending', v_uid
  from public.recurring_templates rt join public.period_section_budgets psb on psb.period_id=v_period_id and psb.section_id=rt.section_id
  where rt.household_id=p_household_id and rt.is_active and rt.archived_at is null
  on conflict (period_id, recurring_template_id) where recurring_template_id is not null do nothing;
  return v_period_id;
end; $$;
revoke all on function public.ensure_budget_period(uuid) from public;
grant execute on function public.ensure_budget_period(uuid) to authenticated;

create or replace function public.set_period_spending_budget(p_period_id uuid, p_spending_budget numeric)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_household_id uuid; v_allocations numeric(14,2);
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode='42501'; end if;
  if p_spending_budget is null or p_spending_budget < 0 then raise exception 'invalid_amount' using errcode='22003'; end if;
  select household_id into v_household_id from public.budget_periods where id=p_period_id for update;
  if v_household_id is null then raise exception 'period_not_found' using errcode='P0002'; end if;
  if not public.is_household_owner(v_household_id) or not public.is_period_open_for_writes(p_period_id) then raise exception 'not_authorized' using errcode='42501'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_period_id::text,0));
  perform 1 from public.period_section_budgets where period_id=p_period_id and section_kind_snapshot='flexible' for update;
  select coalesce(sum(planned_amount),0) into v_allocations from public.period_section_budgets where period_id=p_period_id and section_kind_snapshot='flexible';
  if v_allocations > p_spending_budget then raise exception 'section_allocations_exceed_spending_budget' using errcode='23514'; end if;
  update public.budget_periods set spending_budget=p_spending_budget where id=p_period_id;
end; $$;
revoke all on function public.set_period_spending_budget(uuid,numeric) from public;
revoke all on function public.set_period_spending_budget(uuid,numeric) from anon,service_role;
grant execute on function public.set_period_spending_budget(uuid,numeric) to authenticated;

create or replace function public.set_period_section_allocation(p_period_section_budget_id uuid, p_planned_amount numeric)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_period_id uuid; v_household_id uuid; v_kind public.section_kind; v_budget numeric(14,2); v_other numeric(14,2);
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode='42501'; end if;
  if p_planned_amount is null or p_planned_amount < 0 then raise exception 'invalid_amount' using errcode='22003'; end if;
  select psb.period_id,bp.household_id,psb.section_kind_snapshot,bp.spending_budget into v_period_id,v_household_id,v_kind,v_budget from public.period_section_budgets psb join public.budget_periods bp on bp.id=psb.period_id where psb.id=p_period_section_budget_id for update of psb,bp;
  if v_period_id is null then raise exception 'period_section_budget_not_found' using errcode='P0002'; end if;
  if v_kind <> 'flexible' then raise exception 'fixed_commitments_are_not_section_allocations' using errcode='23514'; end if;
  if not public.is_household_owner(v_household_id) or not public.is_period_open_for_writes(v_period_id) then raise exception 'not_authorized' using errcode='42501'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_period_id::text,0));
  perform 1 from public.period_section_budgets where period_id=v_period_id and section_kind_snapshot='flexible' for update;
  select coalesce(sum(planned_amount),0) into v_other from public.period_section_budgets where period_id=v_period_id and section_kind_snapshot='flexible' and id<>p_period_section_budget_id;
  if v_other+p_planned_amount > v_budget then raise exception 'section_allocations_exceed_spending_budget' using errcode='23514'; end if;
  update public.period_section_budgets set planned_amount=p_planned_amount where id=p_period_section_budget_id;
end; $$;
revoke all on function public.set_period_section_allocation(uuid,numeric) from public;
revoke all on function public.set_period_section_allocation(uuid,numeric) from anon,service_role;
grant execute on function public.set_period_section_allocation(uuid,numeric) to authenticated;

create or replace function public.get_owner_period_planning_summary(p_period_id uuid)
returns table(total_planned_income numeric,total_planned_commitments numeric,available_after_commitments numeric,spending_budget numeric,plan_balance numeric,unallocated_income numeric,planned_deficit numeric,total_section_allocations numeric,unallocated_spending_budget numeric,actual_variable_spending_total numeric,actual_fixed_commitment_outflow numeric,budget_remaining numeric)
language plpgsql stable security definer set search_path='' as $$
declare v_household_id uuid;
begin
  select household_id into v_household_id from public.budget_periods where id=p_period_id;
  if (select auth.uid()) is null or not public.is_household_owner(v_household_id) then raise exception 'not_authorized' using errcode='42501'; end if;
  return query with income as (select coalesce(sum(planned_amount),0)::numeric v from public.period_income_items where period_id=p_period_id), commitments as (select coalesce(sum(planned_amount),0)::numeric v from public.period_fixed_commitments where period_id=p_period_id and status in ('pending','paid')), allocations as (select coalesce(sum(planned_amount),0)::numeric v from public.period_section_budgets where period_id=p_period_id and section_kind_snapshot='flexible'), variable_spend as (select coalesce(sum(t.amount),0)::numeric v from public.transactions t join public.period_section_budgets psb on psb.id=t.period_section_budget_id where t.period_id=p_period_id and t.state='posted' and psb.section_kind_snapshot='flexible'), fixed_actual as (select coalesce(sum(actual_amount),0)::numeric v from public.period_fixed_commitments where period_id=p_period_id and status='paid') select income.v,commitments.v,income.v-commitments.v,bp.spending_budget,income.v-commitments.v-bp.spending_budget,greatest(income.v-commitments.v-bp.spending_budget,0),greatest(-(income.v-commitments.v-bp.spending_budget),0),allocations.v,bp.spending_budget-allocations.v,variable_spend.v,fixed_actual.v,bp.spending_budget-variable_spend.v from public.budget_periods bp,income,commitments,allocations,variable_spend,fixed_actual where bp.id=p_period_id;
end; $$;
revoke all on function public.get_owner_period_planning_summary(uuid) from public;
revoke all on function public.get_owner_period_planning_summary(uuid) from anon,service_role;
grant execute on function public.get_owner_period_planning_summary(uuid) to authenticated;

create or replace function public.mark_period_fixed_commitment_paid(p_period_fixed_commitment_id uuid,p_actual_amount numeric default null)
returns void language plpgsql security definer set search_path='' as $$
declare v_uid uuid := (select auth.uid()); v_period_id uuid; v_household_id uuid; v_planned numeric; v_status public.monthly_item_status; v_amount numeric(14,2);
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode='42501'; end if;
  select pfc.period_id,bp.household_id,pfc.planned_amount,pfc.status into v_period_id,v_household_id,v_planned,v_status from public.period_fixed_commitments pfc join public.budget_periods bp on bp.id=pfc.period_id where pfc.id=p_period_fixed_commitment_id for update of pfc;
  if v_period_id is null then raise exception 'fixed_commitment_not_found' using errcode='P0002'; end if;
  if not public.is_household_owner(v_household_id) or not public.is_period_open_for_writes(v_period_id) then raise exception 'not_authorized' using errcode='42501'; end if;
  if v_status='paid' then return; end if;
  v_amount:=coalesce(p_actual_amount,v_planned);
  if v_amount is null or v_amount<=0 then raise exception 'invalid_amount' using errcode='22003'; end if;
  update public.period_fixed_commitments set status='paid',actual_amount=v_amount where id=p_period_fixed_commitment_id;
  insert into public.audit_events(household_id,actor_user_id,actor_type,event_type,entity_type,entity_id,after_data) values(v_household_id,v_uid,'user','fixed_commitment.paid','period_fixed_commitment',p_period_fixed_commitment_id,jsonb_build_object('actual_amount',v_amount));
end; $$;
revoke all on function public.mark_period_fixed_commitment_paid(uuid,numeric) from public;
revoke all on function public.mark_period_fixed_commitment_paid(uuid,numeric) from anon,service_role;
grant execute on function public.mark_period_fixed_commitment_paid(uuid,numeric) to authenticated;

create or replace function public.set_period_fixed_commitment_planned_amount(p_period_fixed_commitment_id uuid,p_planned_amount numeric)
returns void language plpgsql security definer set search_path='' as $$
declare v_uid uuid := (select auth.uid()); v_period_id uuid; v_household_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode='42501'; end if;
  if p_planned_amount is null or p_planned_amount<0 then raise exception 'invalid_amount' using errcode='22003'; end if;
  select pfc.period_id,bp.household_id into v_period_id,v_household_id from public.period_fixed_commitments pfc join public.budget_periods bp on bp.id=pfc.period_id where pfc.id=p_period_fixed_commitment_id for update of pfc;
  if v_period_id is null then raise exception 'fixed_commitment_not_found' using errcode='P0002'; end if;
  if not public.is_household_owner(v_household_id) or not public.is_period_open_for_writes(v_period_id) then raise exception 'not_authorized' using errcode='42501'; end if;
  update public.period_fixed_commitments set planned_amount=p_planned_amount where id=p_period_fixed_commitment_id;
end; $$;
revoke all on function public.set_period_fixed_commitment_planned_amount(uuid,numeric) from public;
revoke all on function public.set_period_fixed_commitment_planned_amount(uuid,numeric) from anon,service_role;
grant execute on function public.set_period_fixed_commitment_planned_amount(uuid,numeric) to authenticated;

create or replace function public.set_period_fixed_commitment_skipped(p_period_fixed_commitment_id uuid,p_skip boolean,p_reason text default null)
returns void language plpgsql security definer set search_path='' as $$
declare v_uid uuid := (select auth.uid()); v_period_id uuid; v_household_id uuid; v_status public.monthly_item_status;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode='42501'; end if;
  select pfc.period_id,bp.household_id,pfc.status into v_period_id,v_household_id,v_status from public.period_fixed_commitments pfc join public.budget_periods bp on bp.id=pfc.period_id where pfc.id=p_period_fixed_commitment_id for update of pfc;
  if v_period_id is null then raise exception 'fixed_commitment_not_found' using errcode='P0002'; end if;
  if not public.is_household_owner(v_household_id) or not public.is_period_open_for_writes(v_period_id) then raise exception 'not_authorized' using errcode='42501'; end if;
  if p_skip and v_status='paid' then raise exception 'cannot_skip_paid_commitment' using errcode='23514'; end if;
  update public.period_fixed_commitments set status=case when p_skip then 'skipped'::public.monthly_item_status else 'pending'::public.monthly_item_status end,actual_amount=case when p_skip then null else actual_amount end where id=p_period_fixed_commitment_id;
  insert into public.audit_events(household_id,actor_user_id,actor_type,event_type,entity_type,entity_id,metadata) values(v_household_id,v_uid,'user',case when p_skip then 'fixed_commitment.skipped' else 'fixed_commitment.unskipped' end,'period_fixed_commitment',p_period_fixed_commitment_id,jsonb_build_object('reason',p_reason));
end; $$;
revoke all on function public.set_period_fixed_commitment_skipped(uuid,boolean,text) from public;
revoke all on function public.set_period_fixed_commitment_skipped(uuid,boolean,text) from anon,service_role;
grant execute on function public.set_period_fixed_commitment_skipped(uuid,boolean,text) to authenticated;
