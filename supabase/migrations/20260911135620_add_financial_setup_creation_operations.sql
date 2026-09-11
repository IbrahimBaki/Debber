-- Migration: 20260911135620_add_financial_setup_creation_operations
-- Purpose: Add atomic, owner-authorized creation operations for a recurring fixed
-- commitment (template + current snapshot), a this-month-only fixed commitment, and a
-- flexible section (section + current snapshot). The browser previously had no safe
-- multi-step write path for these; period_fixed_commitments and period_section_budgets
-- have no client insert grant and creation must be atomic.
-- Risk: New functions only; no table/column changes; no existing rows affected.
-- Data migration: None.
-- Rollback: Forward migration only. Do not delete migration history.
-- Notes: Idempotency uses caller-supplied entity UUIDs plus the existing natural unique
-- keys already relied on by ensure_budget_period() (period_id, fixed_commitment_template_id)
-- and (period_id, section_id). No new idempotency table or column is introduced.

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
