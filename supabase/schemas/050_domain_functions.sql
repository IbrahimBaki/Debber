-- Dabber declarative schema: domain RPCs that require atomic multi-table writes.

create or replace function public.clamped_period_start_date(
  p_year integer,
  p_month integer,
  p_period_start_day integer
)
returns date
language sql
immutable
strict
set search_path = ''
as $$
  select pg_catalog.make_date(p_year, p_month, 1)
    + (
      least(
        p_period_start_day::integer,
        pg_catalog.date_part(
          'day',
          pg_catalog.date_trunc('month', pg_catalog.make_date(p_year, p_month, 1))
          + interval '1 month - 1 day'
        )::integer
      ) - 1
    );
$$;

revoke all on function public.clamped_period_start_date(integer, integer, integer) from public;
revoke all on function public.clamped_period_start_date(integer, integer, integer) from anon, authenticated, service_role;

create or replace function public.ensure_budget_period(p_household_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
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
  if v_uid is null or not public.is_household_member(p_household_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select h.timezone, h.period_start_day
  into v_timezone, v_start_day
  from public.households h
  where h.id = p_household_id and h.archived_at is null;

  if v_timezone is null then
    raise exception 'household_not_found' using errcode = 'P0002';
  end if;

  v_local_date := (now() at time zone v_timezone)::date;

  if v_local_date >= public.clamped_period_start_date(
    extract(year from v_local_date)::integer,
    extract(month from v_local_date)::integer,
    v_start_day
  ) then
    v_target_month := date_trunc('month', v_local_date)::date;
  else
    v_target_month := (date_trunc('month', v_local_date)::date - interval '1 month')::date;
  end if;

  v_next_target_month := (v_target_month + interval '1 month')::date;
  v_start_date := public.clamped_period_start_date(
    extract(year from v_target_month)::integer,
    extract(month from v_target_month)::integer,
    v_start_day
  );
  v_next_start_date := public.clamped_period_start_date(
    extract(year from v_next_target_month)::integer,
    extract(month from v_next_target_month)::integer,
    v_start_day
  );
  v_end_date := v_next_start_date - 1;

  insert into public.budget_periods (
    household_id, period_key, start_date, end_date, status, created_by
  )
  values (
    p_household_id, v_start_date, v_start_date, v_end_date, 'draft', v_uid
  )
  on conflict (household_id, period_key)
  do update set updated_at = public.budget_periods.updated_at
  returning id into v_period_id;

  insert into public.period_section_budgets (
    period_id, section_id, section_name_snapshot, section_kind_snapshot, planned_amount
  )
  select
    v_period_id, s.id, s.name, s.kind, 0
  from public.budget_sections s
  where s.household_id = p_household_id
    and s.is_active = true
    and s.archived_at is null
  on conflict (period_id, section_id) do nothing;

  insert into public.period_fixed_commitments (
    period_id, fixed_commitment_template_id, name_snapshot, planned_amount,
    due_date, status, created_by
  )
  select
    v_period_id, fct.id, fct.name, fct.default_amount,
    case
      when fct.due_day is null then null
      when fct.due_day >= v_start_day then
        make_date(extract(year from v_start_date)::integer, extract(month from v_start_date)::integer, fct.due_day)
      else
        make_date(extract(year from v_next_start_date)::integer, extract(month from v_next_start_date)::integer, fct.due_day)
    end,
    'pending', v_uid
  from public.fixed_commitment_templates fct
  where fct.household_id = p_household_id
    and fct.is_active = true
    and fct.archived_at is null
  on conflict (period_id, fixed_commitment_template_id) where fixed_commitment_template_id is not null do nothing;

  insert into public.period_income_items (
    period_id, income_source_id, name_snapshot, planned_amount,
    one_off_visibility_scope, created_by
  )
  select
    v_period_id, src.id, src.name, src.default_amount,
    src.visibility_scope, v_uid
  from public.income_sources src
  where src.household_id = p_household_id
    and src.is_active = true
    and src.archived_at is null
  on conflict (period_id, income_source_id) where income_source_id is not null do nothing;

  insert into public.monthly_items (
    period_id,
    period_section_budget_id,
    recurring_template_id,
    name_snapshot,
    planned_amount,
    due_date,
    status,
    created_by
  )
  select
    v_period_id,
    psb.id,
    rt.id,
    rt.name,
    rt.default_amount,
    case
      when rt.due_day is null then null
      when rt.due_day >= v_start_day then
        make_date(extract(year from v_start_date)::integer, extract(month from v_start_date)::integer, rt.due_day)
      else
        make_date(
          extract(year from v_next_start_date)::integer,
          extract(month from v_next_start_date)::integer,
          rt.due_day
        )
    end,
    'pending',
    v_uid
  from public.recurring_templates rt
  join public.period_section_budgets psb
    on psb.period_id = v_period_id
   and psb.section_id = rt.section_id
  where rt.household_id = p_household_id
    and rt.is_active = true
    and rt.archived_at is null
  on conflict (period_id, recurring_template_id) where recurring_template_id is not null do nothing;

  return v_period_id;
end;
$$;

revoke all on function public.ensure_budget_period(uuid) from public;
grant execute on function public.ensure_budget_period(uuid) to authenticated;

create or replace function public.set_period_spending_budget(p_period_id uuid, p_spending_budget numeric)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_household_id uuid;
  v_allocations numeric(14,2);
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  if p_spending_budget is null or p_spending_budget < 0 then raise exception 'invalid_amount' using errcode = '22003'; end if;
  select household_id into v_household_id from public.budget_periods where id = p_period_id for update;
  if v_household_id is null then raise exception 'period_not_found' using errcode = 'P0002'; end if;
  if not public.is_household_owner(v_household_id) or not public.is_period_open_for_writes(p_period_id) then raise exception 'not_authorized' using errcode = '42501'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_period_id::text, 0));
  perform 1
  from public.period_section_budgets
  where period_id = p_period_id and section_kind_snapshot = 'flexible'
  for update;
  select coalesce(sum(planned_amount), 0) into v_allocations
  from public.period_section_budgets
  where period_id = p_period_id and section_kind_snapshot = 'flexible';
  if v_allocations > p_spending_budget then raise exception 'section_allocations_exceed_spending_budget' using errcode = '23514'; end if;
  update public.budget_periods set spending_budget = p_spending_budget where id = p_period_id;
end; $$;
revoke all on function public.set_period_spending_budget(uuid, numeric) from public;
revoke all on function public.set_period_spending_budget(uuid, numeric) from anon, service_role;
grant execute on function public.set_period_spending_budget(uuid, numeric) to authenticated;

create or replace function public.set_period_section_allocation(p_period_section_budget_id uuid, p_planned_amount numeric)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_period_id uuid;
  v_household_id uuid;
  v_kind public.section_kind;
  v_budget numeric(14,2);
  v_other numeric(14,2);
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  if p_planned_amount is null or p_planned_amount < 0 then raise exception 'invalid_amount' using errcode = '22003'; end if;
  select psb.period_id, bp.household_id, psb.section_kind_snapshot, bp.spending_budget into v_period_id,v_household_id,v_kind,v_budget from public.period_section_budgets psb join public.budget_periods bp on bp.id=psb.period_id where psb.id=p_period_section_budget_id for update of psb, bp;
  if v_period_id is null then raise exception 'period_section_budget_not_found' using errcode='P0002'; end if;
  if v_kind <> 'flexible' then raise exception 'fixed_commitments_are_not_section_allocations' using errcode='23514'; end if;
  if not public.is_household_owner(v_household_id) or not public.is_period_open_for_writes(v_period_id) then raise exception 'not_authorized' using errcode='42501'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_period_id::text, 0));
  perform 1
  from public.period_section_budgets
  where period_id=v_period_id and section_kind_snapshot='flexible'
  for update;
  select coalesce(sum(planned_amount),0) into v_other
  from public.period_section_budgets
  where period_id=v_period_id and section_kind_snapshot='flexible' and id<>p_period_section_budget_id;
  if v_other + p_planned_amount > v_budget then raise exception 'section_allocations_exceed_spending_budget' using errcode='23514'; end if;
  update public.period_section_budgets set planned_amount=p_planned_amount where id=p_period_section_budget_id;
end; $$;
revoke all on function public.set_period_section_allocation(uuid, numeric) from public;
revoke all on function public.set_period_section_allocation(uuid, numeric) from anon, service_role;
grant execute on function public.set_period_section_allocation(uuid, numeric) to authenticated;

create or replace function public.get_owner_period_planning_summary(p_period_id uuid)
returns table(total_planned_income numeric, total_planned_commitments numeric, available_after_commitments numeric, spending_budget numeric, plan_balance numeric, unallocated_income numeric, planned_deficit numeric, total_section_allocations numeric, unallocated_spending_budget numeric, actual_variable_spending_total numeric, actual_fixed_commitment_outflow numeric, budget_remaining numeric)
language plpgsql stable security definer set search_path = '' as $$
declare v_household_id uuid;
begin
  select household_id into v_household_id from public.budget_periods where id=p_period_id;
  if (select auth.uid()) is null or not public.is_household_owner(v_household_id) then raise exception 'not_authorized' using errcode='42501'; end if;
  return query
  with income as (select coalesce(sum(planned_amount),0)::numeric v from public.period_income_items where period_id=p_period_id), commitments as (select coalesce(sum(planned_amount),0)::numeric v from public.period_fixed_commitments where period_id=p_period_id and status in ('pending','paid')), allocations as (select coalesce(sum(planned_amount),0)::numeric v from public.period_section_budgets where period_id=p_period_id and section_kind_snapshot='flexible'), variable_spend as (select coalesce(sum(t.amount),0)::numeric v from public.transactions t join public.period_section_budgets psb on psb.id=t.period_section_budget_id where t.period_id=p_period_id and t.state='posted' and psb.section_kind_snapshot='flexible'), fixed_actual as (select coalesce(sum(actual_amount),0)::numeric v from public.period_fixed_commitments where period_id=p_period_id and status='paid')
  select income.v, commitments.v, income.v-commitments.v, bp.spending_budget, income.v-commitments.v-bp.spending_budget, greatest(income.v-commitments.v-bp.spending_budget,0), greatest(-(income.v-commitments.v-bp.spending_budget),0), allocations.v, bp.spending_budget-allocations.v, variable_spend.v, fixed_actual.v, bp.spending_budget-variable_spend.v from public.budget_periods bp,income,commitments,allocations,variable_spend,fixed_actual where bp.id=p_period_id;
end; $$;
revoke all on function public.get_owner_period_planning_summary(uuid) from public;
revoke all on function public.get_owner_period_planning_summary(uuid) from anon, service_role;
grant execute on function public.get_owner_period_planning_summary(uuid) to authenticated;

create or replace function public.mark_period_fixed_commitment_paid(p_period_fixed_commitment_id uuid, p_actual_amount numeric default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_period_id uuid;
  v_household_id uuid;
  v_planned numeric;
  v_status public.monthly_item_status;
  v_amount numeric(14,2);
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode='42501'; end if;
  select pfc.period_id, bp.household_id, pfc.planned_amount, pfc.status
  into v_period_id, v_household_id, v_planned, v_status
  from public.period_fixed_commitments pfc
  join public.budget_periods bp on bp.id=pfc.period_id
  where pfc.id=p_period_fixed_commitment_id
  for update of pfc;
  if v_period_id is null then raise exception 'fixed_commitment_not_found' using errcode='P0002'; end if;
  if not public.is_household_owner(v_household_id) or not public.is_period_open_for_writes(v_period_id) then raise exception 'not_authorized' using errcode='42501'; end if;
  if v_status = 'paid' then return; end if;
  v_amount := coalesce(p_actual_amount, v_planned);
  if v_amount is null or v_amount <= 0 then raise exception 'invalid_amount' using errcode='22003'; end if;
  update public.period_fixed_commitments
  set status='paid', actual_amount=v_amount
  where id=p_period_fixed_commitment_id;
  insert into public.audit_events(household_id,actor_user_id,actor_type,event_type,entity_type,entity_id,after_data)
  values(v_household_id,v_uid,'user','fixed_commitment.paid','period_fixed_commitment',p_period_fixed_commitment_id,jsonb_build_object('actual_amount', v_amount));
end; $$;
revoke all on function public.mark_period_fixed_commitment_paid(uuid, numeric) from public;
revoke all on function public.mark_period_fixed_commitment_paid(uuid, numeric) from anon, service_role;
grant execute on function public.mark_period_fixed_commitment_paid(uuid, numeric) to authenticated;

create or replace function public.set_period_fixed_commitment_planned_amount(
  p_period_fixed_commitment_id uuid,
  p_planned_amount numeric
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_period_id uuid;
  v_household_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode='42501'; end if;
  if p_planned_amount is null or p_planned_amount < 0 then raise exception 'invalid_amount' using errcode='22003'; end if;
  select pfc.period_id, bp.household_id into v_period_id, v_household_id
  from public.period_fixed_commitments pfc
  join public.budget_periods bp on bp.id = pfc.period_id
  where pfc.id = p_period_fixed_commitment_id
  for update of pfc;
  if v_period_id is null then raise exception 'fixed_commitment_not_found' using errcode='P0002'; end if;
  if not public.is_household_owner(v_household_id) or not public.is_period_open_for_writes(v_period_id) then raise exception 'not_authorized' using errcode='42501'; end if;
  update public.period_fixed_commitments set planned_amount = p_planned_amount where id = p_period_fixed_commitment_id;
end; $$;
revoke all on function public.set_period_fixed_commitment_planned_amount(uuid, numeric) from public;
revoke all on function public.set_period_fixed_commitment_planned_amount(uuid, numeric) from anon, service_role;
grant execute on function public.set_period_fixed_commitment_planned_amount(uuid, numeric) to authenticated;

create or replace function public.set_period_fixed_commitment_skipped(
  p_period_fixed_commitment_id uuid,
  p_skip boolean,
  p_reason text default null
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_period_id uuid;
  v_household_id uuid;
  v_status public.monthly_item_status;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode='42501'; end if;
  select pfc.period_id, bp.household_id, pfc.status
  into v_period_id, v_household_id, v_status
  from public.period_fixed_commitments pfc
  join public.budget_periods bp on bp.id = pfc.period_id
  where pfc.id = p_period_fixed_commitment_id
  for update of pfc;
  if v_period_id is null then raise exception 'fixed_commitment_not_found' using errcode='P0002'; end if;
  if not public.is_household_owner(v_household_id) or not public.is_period_open_for_writes(v_period_id) then raise exception 'not_authorized' using errcode='42501'; end if;
  if p_skip and v_status = 'paid' then raise exception 'cannot_skip_paid_commitment' using errcode='23514'; end if;
  update public.period_fixed_commitments
  set status = case when p_skip then 'skipped'::public.monthly_item_status else 'pending'::public.monthly_item_status end,
      actual_amount = case when p_skip then null else actual_amount end
  where id = p_period_fixed_commitment_id;
  insert into public.audit_events(household_id,actor_user_id,actor_type,event_type,entity_type,entity_id,metadata)
  values(v_household_id,v_uid,'user',case when p_skip then 'fixed_commitment.skipped' else 'fixed_commitment.unskipped' end,'period_fixed_commitment',p_period_fixed_commitment_id,jsonb_build_object('reason', p_reason));
end; $$;
revoke all on function public.set_period_fixed_commitment_skipped(uuid, boolean, text) from public;
revoke all on function public.set_period_fixed_commitment_skipped(uuid, boolean, text) from anon, service_role;
grant execute on function public.set_period_fixed_commitment_skipped(uuid, boolean, text) to authenticated;

create or replace function public.list_my_pending_household_invitations()
returns table (
  invitation_id uuid,
  household_id uuid,
  household_name text,
  inviter_display_name text,
  created_at timestamptz,
  expires_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_user_email text;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select pg_catalog.lower(u.email) into v_user_email
  from auth.users u
  where u.id = v_uid;

  if v_user_email is null then
    raise exception 'authenticated_user_email_not_found' using errcode = 'P0002';
  end if;

  return query
  select hi.id, h.id, h.name, p.display_name, hi.created_at, hi.expires_at
  from public.household_invitations hi
  join public.households h on h.id = hi.household_id
  left join public.profiles p on p.id = hi.invited_by
  where pg_catalog.lower(hi.email) = v_user_email
    and hi.status = 'pending'
    and hi.expires_at > now()
    and h.archived_at is null
  order by hi.created_at asc, hi.id asc;
end;
$$;

revoke all on function public.list_my_pending_household_invitations() from public;
revoke all on function public.list_my_pending_household_invitations() from anon, service_role;
grant execute on function public.list_my_pending_household_invitations() to authenticated;

create or replace function public.create_initial_household(
  p_name text,
  p_currency_code varchar(3),
  p_period_start_day integer default 1,
  p_timezone text default 'Africa/Cairo'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_user_email text;
  v_existing_household_id uuid;
  v_household_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  if p_currency_code not in ('EGP', 'SAR', 'USD', 'EUR') then
    raise exception 'unsupported_currency_code' using errcode = '23514';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_uid::text, 0));

  select hm.household_id into v_existing_household_id
  from public.household_members hm
  where hm.user_id = v_uid
    and hm.status = 'active'
  order by hm.joined_at asc, hm.id asc
  limit 1;

  if v_existing_household_id is not null then
    return v_existing_household_id;
  end if;

  select pg_catalog.lower(u.email) into v_user_email
  from auth.users u
  where u.id = v_uid;

  if exists (
    select 1
    from public.household_invitations hi
    join public.households h on h.id = hi.household_id
    where pg_catalog.lower(hi.email) = v_user_email
      and hi.status = 'pending'
      and hi.expires_at > now()
      and h.archived_at is null
  ) then
    raise exception 'pending_invitation_requires_resolution' using errcode = 'P0001';
  end if;

  insert into public.households (
    name, owner_user_id, currency_code, period_start_day, timezone
  ) values (
    p_name, v_uid, p_currency_code, p_period_start_day, p_timezone
  )
  returning id into v_household_id;

  return v_household_id;
end;
$$;

revoke all on function public.create_initial_household(text, varchar, integer, text) from public;
revoke all on function public.create_initial_household(text, varchar, integer, text) from anon, service_role;
grant execute on function public.create_initial_household(text, varchar, integer, text) to authenticated;

create or replace function public.mark_monthly_item_paid(
  p_monthly_item_id uuid,
  p_actual_amount numeric default null,
  p_occurred_at timestamptz default now(),
  p_description text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_period_id uuid;
  v_psb_id uuid;
  v_section_id uuid;
  v_household_id uuid;
  v_planned numeric(14,2);
  v_amount numeric(14,2);
  v_existing_transaction_id uuid;
  v_transaction_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select mi.period_id, mi.period_section_budget_id, psb.section_id, bp.household_id, mi.planned_amount
  into v_period_id, v_psb_id, v_section_id, v_household_id, v_planned
  from public.monthly_items mi
  join public.period_section_budgets psb on psb.id = mi.period_section_budget_id
  join public.budget_periods bp on bp.id = mi.period_id
  where mi.id = p_monthly_item_id
  for update of mi;

  if v_period_id is null then
    raise exception 'monthly_item_not_found' using errcode = 'P0002';
  end if;

  if not public.is_period_open_for_writes(v_period_id) then
    raise exception 'period_closed' using errcode = 'P0001';
  end if;

  if not public.can_contribute_to_section(v_section_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select t.id into v_existing_transaction_id
  from public.transactions t
  where t.monthly_item_id = p_monthly_item_id
    and t.state = 'posted'
  limit 1;

  if v_existing_transaction_id is not null then
    return v_existing_transaction_id;
  end if;

  v_amount := coalesce(p_actual_amount, v_planned);
  if v_amount <= 0 then
    raise exception 'invalid_amount' using errcode = '22003';
  end if;

  insert into public.transactions (
    period_id,
    period_section_budget_id,
    monthly_item_id,
    amount,
    occurred_at,
    description,
    state,
    created_by
  )
  values (
    v_period_id,
    v_psb_id,
    p_monthly_item_id,
    v_amount,
    p_occurred_at,
    p_description,
    'posted',
    v_uid
  )
  returning id into v_transaction_id;

  update public.monthly_items
  set status = 'paid', actual_amount = v_amount, updated_at = now()
  where id = p_monthly_item_id;

  insert into public.audit_events (
    household_id, actor_user_id, actor_type, event_type, entity_type, entity_id, after_data
  )
  values (
    v_household_id,
    v_uid,
    'user',
    'monthly_item.paid',
    'monthly_item',
    p_monthly_item_id,
    jsonb_build_object('transaction_id', v_transaction_id, 'actual_amount', v_amount)
  );

  return v_transaction_id;
end;
$$;

revoke all on function public.mark_monthly_item_paid(uuid, numeric, timestamptz, text) from public;
grant execute on function public.mark_monthly_item_paid(uuid, numeric, timestamptz, text) to authenticated;

create or replace function public.void_transaction(
  p_transaction_id uuid,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_period_id uuid;
  v_created_by uuid;
  v_household_id uuid;
  v_monthly_item_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select t.period_id, t.created_by, bp.household_id, t.monthly_item_id
  into v_period_id, v_created_by, v_household_id, v_monthly_item_id
  from public.transactions t
  join public.budget_periods bp on bp.id = t.period_id
  where t.id = p_transaction_id and t.state = 'posted'
  for update of t;

  if v_period_id is null then
    raise exception 'transaction_not_found' using errcode = 'P0002';
  end if;

  if not public.is_period_open_for_writes(v_period_id) then
    raise exception 'period_closed' using errcode = 'P0001';
  end if;

  if not (public.is_household_owner(v_household_id) or v_created_by = v_uid) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  update public.transactions
  set state = 'voided', voided_by = v_uid, voided_at = now(), void_reason = p_reason, updated_at = now()
  where id = p_transaction_id;

  if v_monthly_item_id is not null then
    update public.monthly_items
    set status = 'pending', actual_amount = null, updated_at = now()
    where id = v_monthly_item_id;
  end if;

  insert into public.audit_events (
    household_id, actor_user_id, actor_type, event_type, entity_type, entity_id, metadata
  )
  values (
    v_household_id, v_uid, 'user', 'transaction.voided', 'transaction', p_transaction_id,
    jsonb_build_object('reason', p_reason)
  );
end;
$$;

revoke all on function public.void_transaction(uuid, text) from public;
grant execute on function public.void_transaction(uuid, text) to authenticated;


create or replace function public.accept_household_invitation_internal(p_invitation_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_user_email text;
  v_invitation public.household_invitations%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select pg_catalog.lower(u.email) into v_user_email
  from auth.users u where u.id = v_uid;

  select * into v_invitation
  from public.household_invitations hi
  where hi.id = p_invitation_id
  for update;

  if v_invitation.id is null then
    raise exception 'invitation_not_found' using errcode = 'P0002';
  end if;

  if pg_catalog.lower(v_invitation.email) is distinct from v_user_email then
    raise exception 'invitation_email_mismatch' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.households h
    where h.id = v_invitation.household_id
      and h.archived_at is null
  ) then
    raise exception 'household_not_found' using errcode = 'P0002';
  end if;

  if v_invitation.status = 'accepted' and v_invitation.accepted_by = v_uid then
    if exists (
      select 1
      from public.household_members hm
      where hm.household_id = v_invitation.household_id
        and hm.user_id = v_uid
        and hm.status = 'active'
    ) then
      return v_invitation.household_id;
    end if;
    raise exception 'invitation_acceptance_incomplete' using errcode = 'P0001';
  end if;

  if v_invitation.status <> 'pending' then
    raise exception 'invitation_not_pending' using errcode = 'P0001';
  end if;

  if v_invitation.expires_at <= now() then
    update public.household_invitations
    set status = 'expired', updated_at = now()
    where id = v_invitation.id;
    raise exception 'invitation_expired' using errcode = 'P0001';
  end if;

  insert into public.household_members (household_id, user_id, role, status)
  values (v_invitation.household_id, v_uid, 'member', 'active')
  on conflict (household_id, user_id)
  do update set status = 'active', removed_at = null, updated_at = now();

  update public.household_invitations
  set status = 'accepted', accepted_by = v_uid, accepted_at = now(), updated_at = now()
  where id = v_invitation.id;

  insert into public.audit_events (
    household_id, actor_user_id, actor_type, event_type, entity_type, entity_id
  ) values (
    v_invitation.household_id, v_uid, 'user', 'membership.invitation_accepted', 'household_member', v_uid
  );

  return v_invitation.household_id;
end;
$$;

revoke all on function public.accept_household_invitation_internal(uuid) from public;
revoke all on function public.accept_household_invitation_internal(uuid) from anon, authenticated, service_role;

create or replace function public.accept_household_invitation(p_token_hash text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invitation_id uuid;
begin
  select hi.id into v_invitation_id
  from public.household_invitations hi
  where hi.token_hash = p_token_hash;

  if v_invitation_id is null then
    raise exception 'invitation_not_found' using errcode = 'P0002';
  end if;

  return public.accept_household_invitation_internal(v_invitation_id);
end;
$$;

revoke all on function public.accept_household_invitation(text) from public;
revoke all on function public.accept_household_invitation(text) from anon, service_role;
grant execute on function public.accept_household_invitation(text) to authenticated;

create or replace function public.accept_household_invitation_by_id(p_invitation_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  return public.accept_household_invitation_internal(p_invitation_id);
end;
$$;

revoke all on function public.accept_household_invitation_by_id(uuid) from public;
revoke all on function public.accept_household_invitation_by_id(uuid) from anon, service_role;
grant execute on function public.accept_household_invitation_by_id(uuid) to authenticated;

create or replace function public.remove_household_member(p_household_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_owner_id uuid;
begin
  if v_uid is null or not public.is_household_owner(p_household_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select h.owner_user_id into v_owner_id
  from public.households h where h.id = p_household_id;

  if p_user_id = v_owner_id then
    raise exception 'cannot_remove_household_owner' using errcode = 'P0001';
  end if;

  update public.household_members
  set status = 'removed', removed_at = now(), updated_at = now()
  where household_id = p_household_id
    and user_id = p_user_id
    and status = 'active';

  insert into public.audit_events (
    household_id, actor_user_id, actor_type, event_type, entity_type, entity_id,
    metadata
  ) values (
    p_household_id, v_uid, 'user', 'membership.removed', 'household_member', p_user_id,
    jsonb_build_object('removed_user_id', p_user_id)
  );
end;
$$;

revoke all on function public.remove_household_member(uuid, uuid) from public;
grant execute on function public.remove_household_member(uuid, uuid) to authenticated;

create or replace function public.set_monthly_item_skipped(
  p_monthly_item_id uuid,
  p_skip boolean default true,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_period_id uuid;
  v_section_id uuid;
  v_household_id uuid;
  v_has_posted_transaction boolean;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select mi.period_id, psb.section_id, bp.household_id
  into v_period_id, v_section_id, v_household_id
  from public.monthly_items mi
  join public.period_section_budgets psb on psb.id = mi.period_section_budget_id
  join public.budget_periods bp on bp.id = mi.period_id
  where mi.id = p_monthly_item_id
  for update of mi;

  if v_period_id is null then
    raise exception 'monthly_item_not_found' using errcode = 'P0002';
  end if;

  if not public.is_period_open_for_writes(v_period_id) then
    raise exception 'period_closed' using errcode = 'P0001';
  end if;

  if not public.can_contribute_to_section(v_section_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select exists (
    select 1 from public.transactions t
    where t.monthly_item_id = p_monthly_item_id and t.state = 'posted'
  ) into v_has_posted_transaction;

  if p_skip and v_has_posted_transaction then
    raise exception 'cannot_skip_paid_item' using errcode = 'P0001';
  end if;

  update public.monthly_items
  set status = case when p_skip then 'skipped'::public.monthly_item_status else 'pending'::public.monthly_item_status end,
      actual_amount = case when p_skip then null else actual_amount end,
      updated_at = now()
  where id = p_monthly_item_id;

  insert into public.audit_events (
    household_id, actor_user_id, actor_type, event_type, entity_type, entity_id, metadata
  ) values (
    v_household_id,
    v_uid,
    'user',
    case when p_skip then 'monthly_item.skipped' else 'monthly_item.unskipped' end,
    'monthly_item',
    p_monthly_item_id,
    jsonb_build_object('reason', p_reason)
  );
end;
$$;

revoke all on function public.set_monthly_item_skipped(uuid, boolean, text) from public;
grant execute on function public.set_monthly_item_skipped(uuid, boolean, text) to authenticated;

create or replace function public.set_budget_period_status(
  p_period_id uuid,
  p_status public.period_status,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_household_id uuid;
  v_old_status public.period_status;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select bp.household_id, bp.status
  into v_household_id, v_old_status
  from public.budget_periods bp
  where bp.id = p_period_id
  for update of bp;

  if v_household_id is null then
    raise exception 'period_not_found' using errcode = 'P0002';
  end if;

  if not public.is_household_owner(v_household_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  if v_old_status = p_status then
    return;
  end if;

  if not (
    (v_old_status = 'draft' and p_status = 'open')
    or (v_old_status = 'open' and p_status = 'closed')
    or (v_old_status = 'closed' and p_status = 'open')
  ) then
    raise exception 'invalid_period_status_transition' using errcode = 'P0001';
  end if;

  update public.budget_periods
  set status = p_status,
      opened_at = case
        when p_status = 'open' and opened_at is null then now()
        else opened_at
      end,
      closed_at = case
        when p_status = 'closed' then now()
        when v_old_status = 'closed' and p_status = 'open' then null
        else closed_at
      end,
      updated_at = now()
  where id = p_period_id;

  insert into public.audit_events (
    household_id, actor_user_id, actor_type, event_type, entity_type, entity_id,
    before_data, after_data, metadata
  ) values (
    v_household_id,
    v_uid,
    'user',
    'budget_period.status_changed',
    'budget_period',
    p_period_id,
    jsonb_build_object('status', v_old_status),
    jsonb_build_object('status', p_status),
    jsonb_build_object('reason', p_reason)
  );
end;
$$;

revoke all on function public.set_budget_period_status(uuid, public.period_status, text) from public;
grant execute on function public.set_budget_period_status(uuid, public.period_status, text) to authenticated;

-- Financial setup creation operations.
-- These exist because the browser has no safe multi-step write path to create a recurring
-- fixed commitment (template + current snapshot), a this-month-only fixed commitment, or a
-- flexible section (section + current snapshot) atomically. Idempotency uses caller-supplied
-- entity UUIDs plus the existing natural unique keys already relied on by ensure_budget_period;
-- no new idempotency table or column is introduced.

create or replace function public.create_recurring_fixed_commitment(
  p_period_id uuid,
  p_name text,
  p_planned_amount numeric,
  p_due_day smallint default null,
  p_template_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_household_id uuid;
  v_start_date date;
  v_period_start_day integer;
  v_target_month date;
  v_next_target_month date;
  v_due_date date;
  v_template_id uuid;
  v_template_inserted_id uuid;
  v_template_created boolean := false;
  v_existing_template_household_id uuid;
  v_commitment_id uuid;
  v_commitment_inserted_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if p_name is null or char_length(p_name) not between 1 and 160 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if p_planned_amount is null or p_planned_amount < 0 then
    raise exception 'invalid_amount' using errcode = '22003';
  end if;
  if p_due_day is not null and p_due_day not between 1 and 28 then
    raise exception 'invalid_due_day' using errcode = '22003';
  end if;

  select bp.household_id, bp.start_date, h.period_start_day
  into v_household_id, v_start_date, v_period_start_day
  from public.budget_periods bp
  join public.households h on h.id = bp.household_id
  where bp.id = p_period_id
  for update of bp;

  if v_household_id is null then
    raise exception 'period_not_found' using errcode = 'P0002';
  end if;
  if not public.is_household_owner(v_household_id) or not public.is_period_open_for_writes(p_period_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  v_template_id := coalesce(p_template_id, pg_catalog.gen_random_uuid());

  insert into public.fixed_commitment_templates (
    id, household_id, name, default_amount, due_day, is_active, created_by
  )
  values (
    v_template_id, v_household_id, p_name, p_planned_amount, p_due_day, true, v_uid
  )
  on conflict (id) do nothing
  returning id into v_template_inserted_id;

  if v_template_inserted_id is not null then
    v_template_created := true;
  else
    select household_id into v_existing_template_household_id
    from public.fixed_commitment_templates
    where id = v_template_id;

    if v_existing_template_household_id is distinct from v_household_id then
      raise exception 'template_id_conflict' using errcode = '23505';
    end if;
  end if;

  if p_due_day is null then
    v_due_date := null;
  else
    v_target_month := pg_catalog.date_trunc('month', v_start_date)::date;
    v_next_target_month := (v_target_month + interval '1 month')::date;
    if p_due_day >= v_period_start_day then
      v_due_date := make_date(
        extract(year from v_target_month)::integer,
        extract(month from v_target_month)::integer,
        p_due_day
      );
    else
      v_due_date := make_date(
        extract(year from v_next_target_month)::integer,
        extract(month from v_next_target_month)::integer,
        p_due_day
      );
    end if;
  end if;

  insert into public.period_fixed_commitments (
    period_id, fixed_commitment_template_id, name_snapshot, planned_amount, due_date, status, created_by
  )
  values (
    p_period_id, v_template_id, p_name, p_planned_amount, v_due_date, 'pending', v_uid
  )
  on conflict (period_id, fixed_commitment_template_id) where fixed_commitment_template_id is not null do nothing
  returning id into v_commitment_inserted_id;

  if v_commitment_inserted_id is not null then
    v_commitment_id := v_commitment_inserted_id;
    insert into public.audit_events (
      household_id, actor_user_id, actor_type, event_type, entity_type, entity_id, after_data
    )
    values (
      v_household_id, v_uid, 'user', 'fixed_commitment.created', 'period_fixed_commitment', v_commitment_id,
      jsonb_build_object(
        'recurrence', 'recurring',
        'fixed_commitment_template_id', v_template_id,
        'template_created', v_template_created,
        'planned_amount', p_planned_amount,
        'name', p_name
      )
    );
  else
    select id into v_commitment_id
    from public.period_fixed_commitments
    where period_id = p_period_id and fixed_commitment_template_id = v_template_id;
  end if;

  return v_commitment_id;
end;
$$;

revoke all on function public.create_recurring_fixed_commitment(uuid, text, numeric, smallint, uuid) from public;
revoke all on function public.create_recurring_fixed_commitment(uuid, text, numeric, smallint, uuid) from anon, service_role;
grant execute on function public.create_recurring_fixed_commitment(uuid, text, numeric, smallint, uuid) to authenticated;

create or replace function public.create_one_time_fixed_commitment(
  p_period_id uuid,
  p_name text,
  p_planned_amount numeric,
  p_due_date date default null,
  p_commitment_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_household_id uuid;
  v_start_date date;
  v_end_date date;
  v_commitment_id uuid;
  v_inserted_id uuid;
  v_existing_period_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if p_name is null or char_length(p_name) not between 1 and 160 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if p_planned_amount is null or p_planned_amount < 0 then
    raise exception 'invalid_amount' using errcode = '22003';
  end if;

  select bp.household_id, bp.start_date, bp.end_date
  into v_household_id, v_start_date, v_end_date
  from public.budget_periods bp
  where bp.id = p_period_id
  for update of bp;

  if v_household_id is null then
    raise exception 'period_not_found' using errcode = 'P0002';
  end if;
  if not public.is_household_owner(v_household_id) or not public.is_period_open_for_writes(p_period_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  if p_due_date is not null and (p_due_date < v_start_date or p_due_date > v_end_date) then
    raise exception 'invalid_due_date' using errcode = '22003';
  end if;

  v_commitment_id := coalesce(p_commitment_id, pg_catalog.gen_random_uuid());

  insert into public.period_fixed_commitments (
    id, period_id, fixed_commitment_template_id, name_snapshot, planned_amount, due_date, status, created_by
  )
  values (
    v_commitment_id, p_period_id, null, p_name, p_planned_amount, p_due_date, 'pending', v_uid
  )
  on conflict (id) do nothing
  returning id into v_inserted_id;

  if v_inserted_id is not null then
    insert into public.audit_events (
      household_id, actor_user_id, actor_type, event_type, entity_type, entity_id, after_data
    )
    values (
      v_household_id, v_uid, 'user', 'fixed_commitment.created', 'period_fixed_commitment', v_commitment_id,
      jsonb_build_object('recurrence', 'one_time', 'planned_amount', p_planned_amount, 'name', p_name)
    );
  else
    select period_id into v_existing_period_id
    from public.period_fixed_commitments
    where id = v_commitment_id;

    if v_existing_period_id is distinct from p_period_id then
      raise exception 'commitment_id_conflict' using errcode = '23505';
    end if;
  end if;

  return v_commitment_id;
end;
$$;

revoke all on function public.create_one_time_fixed_commitment(uuid, text, numeric, date, uuid) from public;
revoke all on function public.create_one_time_fixed_commitment(uuid, text, numeric, date, uuid) from anon, service_role;
grant execute on function public.create_one_time_fixed_commitment(uuid, text, numeric, date, uuid) to authenticated;

create or replace function public.create_flexible_budget_section(
  p_period_id uuid,
  p_name text,
  p_visibility_scope public.visibility_scope default 'owner_only',
  p_member_access public.section_member_access default 'view',
  p_section_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_household_id uuid;
  v_section_id uuid;
  v_section_inserted_id uuid;
  v_section_created boolean := false;
  v_existing_section_household_id uuid;
  v_snapshot_id uuid;
  v_snapshot_inserted_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if p_name is null or char_length(p_name) not between 1 and 120 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;

  select bp.household_id into v_household_id
  from public.budget_periods bp
  where bp.id = p_period_id
  for update of bp;

  if v_household_id is null then
    raise exception 'period_not_found' using errcode = 'P0002';
  end if;
  if not public.is_household_owner(v_household_id) or not public.is_period_open_for_writes(p_period_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  v_section_id := coalesce(p_section_id, pg_catalog.gen_random_uuid());

  insert into public.budget_sections (
    id, household_id, name, kind, default_planned_amount, visibility_scope, member_access, is_active, created_by
  )
  values (
    v_section_id, v_household_id, p_name, 'flexible', 0, p_visibility_scope, p_member_access, true, v_uid
  )
  on conflict (id) do nothing
  returning id into v_section_inserted_id;

  if v_section_inserted_id is not null then
    v_section_created := true;
  else
    select household_id into v_existing_section_household_id
    from public.budget_sections
    where id = v_section_id;

    if v_existing_section_household_id is distinct from v_household_id then
      raise exception 'section_id_conflict' using errcode = '23505';
    end if;
  end if;

  insert into public.period_section_budgets (
    period_id, section_id, section_name_snapshot, section_kind_snapshot, planned_amount
  )
  values (
    p_period_id, v_section_id, p_name, 'flexible', 0
  )
  on conflict (period_id, section_id) do nothing
  returning id into v_snapshot_inserted_id;

  if v_snapshot_inserted_id is not null then
    v_snapshot_id := v_snapshot_inserted_id;
    insert into public.audit_events (
      household_id, actor_user_id, actor_type, event_type, entity_type, entity_id, after_data
    )
    values (
      v_household_id, v_uid, 'user', 'budget_section.created', 'budget_section', v_section_id,
      jsonb_build_object('period_id', p_period_id, 'section_created', v_section_created, 'name', p_name)
    );
  else
    select id into v_snapshot_id
    from public.period_section_budgets
    where period_id = p_period_id and section_id = v_section_id;
  end if;

  return v_snapshot_id;
end;
$$;

revoke all on function public.create_flexible_budget_section(uuid, text, public.visibility_scope, public.section_member_access, uuid) from public;
revoke all on function public.create_flexible_budget_section(uuid, text, public.visibility_scope, public.section_member_access, uuid) from anon, service_role;
grant execute on function public.create_flexible_budget_section(uuid, text, public.visibility_scope, public.section_member_access, uuid) to authenticated;

-- Ordinary (variable) expense creation. This is the sole authoritative path for recording a
-- transaction against a flexible section: the direct-insert RLS policy that used to exist for
-- this was removed because period-status-must-be-Open, expense-date-bounds, and idempotent
-- retry cannot be expressed safely as a plain with-check. Linked recurring-item payments keep
-- using mark_monthly_item_paid(...) and are unaffected.
create or replace function public.record_expense(
  p_period_section_budget_id uuid,
  p_amount numeric,
  p_occurred_at date default null,
  p_description text default null,
  p_transaction_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_period_id uuid;
  v_section_id uuid;
  v_household_id uuid;
  v_status public.period_status;
  v_start_date date;
  v_end_date date;
  v_timezone text;
  v_today date;
  v_occurred_at date;
  v_occurred_at_ts timestamptz;
  v_transaction_id uuid;
  v_inserted_id uuid;
  v_existing_period_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'invalid_amount' using errcode = '22003';
  end if;

  if p_description is not null and char_length(p_description) > 500 then
    raise exception 'invalid_description' using errcode = '22001';
  end if;

  select psb.period_id, psb.section_id, bp.household_id, bp.status, bp.start_date, bp.end_date, h.timezone
  into v_period_id, v_section_id, v_household_id, v_status, v_start_date, v_end_date, v_timezone
  from public.period_section_budgets psb
  join public.budget_periods bp on bp.id = psb.period_id
  join public.households h on h.id = bp.household_id
  where psb.id = p_period_section_budget_id;

  if v_period_id is null then
    raise exception 'section_budget_not_found' using errcode = 'P0002';
  end if;

  if not (public.is_household_owner(v_household_id) or public.can_contribute_to_section(v_section_id)) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  if v_status <> 'open' then
    raise exception 'period_not_open' using errcode = 'P0001';
  end if;

  v_today := (now() at time zone v_timezone)::date;
  v_occurred_at := coalesce(p_occurred_at, v_today);

  if v_occurred_at < v_start_date or v_occurred_at > v_end_date then
    raise exception 'expense_date_out_of_period' using errcode = '22003';
  end if;

  if v_occurred_at > v_today then
    raise exception 'expense_date_in_future' using errcode = '22003';
  end if;

  v_occurred_at_ts := case
    when v_occurred_at = v_today then now()
    else (v_occurred_at::timestamp + time '12:00') at time zone v_timezone
  end;

  v_transaction_id := coalesce(p_transaction_id, pg_catalog.gen_random_uuid());

  insert into public.transactions (
    id, period_id, period_section_budget_id, amount, occurred_at, description, state, created_by
  )
  values (
    v_transaction_id, v_period_id, p_period_section_budget_id, p_amount, v_occurred_at_ts, p_description, 'posted', v_uid
  )
  on conflict (id) do nothing
  returning id into v_inserted_id;

  if v_inserted_id is null then
    select period_id into v_existing_period_id
    from public.transactions
    where id = v_transaction_id;

    if v_existing_period_id is distinct from v_period_id then
      raise exception 'transaction_id_conflict' using errcode = '23505';
    end if;
  end if;

  return v_transaction_id;
end;
$$;

revoke all on function public.record_expense(uuid, numeric, date, text, uuid) from public;
revoke all on function public.record_expense(uuid, numeric, date, text, uuid) from anon, service_role;
grant execute on function public.record_expense(uuid, numeric, date, text, uuid) to authenticated;

-- MVP total-income sharing: a narrow, Member-safe aggregate. Individual period_income_items/
-- income_sources rows are never returned to a Member through this or any other path -- their
-- RLS policies (both owner_only-by-default in the current one-off Financial Setup pattern) are
-- untouched. NULL means "not shared with this caller"; 0 means "shared and currently zero" --
-- these are deliberately distinct return values, never conflated.
create or replace function public.get_member_visible_total_income(p_period_id uuid)
returns numeric
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_household_id uuid;
  v_shared boolean;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select household_id into v_household_id
  from public.budget_periods
  where id = p_period_id;

  if v_household_id is null then
    raise exception 'period_not_found' using errcode = 'P0002';
  end if;

  if not public.is_household_member(v_household_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  if not public.is_household_owner(v_household_id) then
    select share_total_income_with_members into v_shared
    from public.households
    where id = v_household_id;

    if not coalesce(v_shared, false) then
      return null;
    end if;
  end if;

  return coalesce(
    (select sum(planned_amount) from public.period_income_items where period_id = p_period_id),
    0
  );
end;
$$;

revoke all on function public.get_member_visible_total_income(uuid) from public;
revoke all on function public.get_member_visible_total_income(uuid) from anon, service_role;
grant execute on function public.get_member_visible_total_income(uuid) to authenticated;

-- Partner invitation creation: the sole authoritative path for an Owner to invite someone by
-- email. Invited role is always 'member' -- the table has no role column at all, so nothing
-- here could spoof one even if it tried. token_hash/expires_at/status/invited_by are always
-- server-computed, never accepted as input. Creating for the same Household + normalized
-- email while an unexpired 'pending' invitation already exists is idempotent: it returns the
-- existing invitation instead of creating a duplicate, and writes no additional audit event.
create or replace function public.create_household_invitation(
  p_household_id uuid,
  p_email text
)
returns table (
  invitation_id uuid,
  email text,
  expires_at timestamptz,
  created boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_caller_email text;
  v_email text;
  v_existing_id uuid;
  v_existing_expires_at timestamptz;
  v_new_id uuid;
  v_new_expires_at timestamptz;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  if not public.is_household_owner(p_household_id) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  v_email := pg_catalog.lower(pg_catalog.btrim(p_email));

  if v_email is null or v_email = '' or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'invalid_email' using errcode = '22023';
  end if;

  select pg_catalog.lower(u.email) into v_caller_email
  from auth.users u
  where u.id = v_uid;

  if v_caller_email is not null and v_caller_email = v_email then
    raise exception 'self_invite_not_allowed' using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.household_members hm
    join auth.users u on u.id = hm.user_id
    where hm.household_id = p_household_id
      and hm.status = 'active'
      and pg_catalog.lower(u.email) = v_email
  ) then
    raise exception 'already_active_member' using errcode = 'P0001';
  end if;

  -- Serialize concurrent/retried invitation-creation attempts for the same Household+email so
  -- a race can never leave two simultaneous pending rows for the same recipient. A different
  -- Household inviting the same email is a different lock key and proceeds independently.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_household_id::text || ':' || v_email, 0)
  );

  select hi.id, hi.expires_at into v_existing_id, v_existing_expires_at
  from public.household_invitations hi
  where hi.household_id = p_household_id
    and pg_catalog.lower(hi.email) = v_email
    and hi.status = 'pending'
  order by hi.created_at desc
  limit 1
  for update;

  if v_existing_id is not null then
    if v_existing_expires_at > now() then
      return query select v_existing_id, v_email, v_existing_expires_at, false;
      return;
    end if;

    -- A stale pending invitation never blocks a fresh one; lazily transition it first.
    update public.household_invitations
    set status = 'expired', updated_at = now()
    where id = v_existing_id;
  end if;

  v_new_expires_at := now() + interval '7 days';

  insert into public.household_invitations (
    household_id, email, token_hash, invited_by, expires_at
  ) values (
    p_household_id,
    v_email,
    encode(extensions.gen_random_bytes(32), 'hex'),
    v_uid,
    v_new_expires_at
  )
  returning id into v_new_id;

  insert into public.audit_events (
    household_id, actor_user_id, actor_type, event_type, entity_type, entity_id
  ) values (
    p_household_id, v_uid, 'user', 'household_invitation.created', 'household_invitation', v_new_id
  );

  return query select v_new_id, v_email, v_new_expires_at, true;
end;
$$;

revoke all on function public.create_household_invitation(uuid, text) from public;
revoke all on function public.create_household_invitation(uuid, text) from anon, service_role;
grant execute on function public.create_household_invitation(uuid, text) to authenticated;
