-- Migration: 20260911102006_harden_household_onboarding
-- Purpose: Harden household onboarding domain operations, supported currencies, and clamped period boundaries.
-- Risk: Existing Household currency values must already be in the approved MVP catalogue.
-- Data migration: No row rewriting; existing budget periods remain immutable.
-- Rollback: Forward migration only. Do not delete migration history.

alter table public.households
  drop constraint if exists households_currency_code_check,
  add constraint households_currency_code_check
    check (currency_code in ('EGP', 'SAR', 'USD', 'EUR')),
  drop constraint if exists households_period_start_day_check,
  add constraint households_period_start_day_check
    check (period_start_day between 1 and 31);

revoke insert on table public.households from authenticated;
drop policy if exists "Users can create a household owned by themselves" on public.households;

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

  select h.timezone, h.period_start_day into v_timezone, v_start_day
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
  ) values (
    p_household_id, v_start_date, v_start_date, v_end_date, 'draft', v_uid
  )
  on conflict (household_id, period_key)
  do update set updated_at = public.budget_periods.updated_at
  returning id into v_period_id;

  insert into public.period_section_budgets (
    period_id, section_id, section_name_snapshot, section_kind_snapshot, planned_amount
  )
  select v_period_id, s.id, s.name, s.kind, s.default_planned_amount
  from public.budget_sections s
  where s.household_id = p_household_id and s.is_active = true and s.archived_at is null
  on conflict (period_id, section_id) do nothing;

  insert into public.period_income_items (
    period_id, income_source_id, name_snapshot, planned_amount,
    one_off_visibility_scope, created_by
  )
  select v_period_id, src.id, src.name, src.default_amount, src.visibility_scope, v_uid
  from public.income_sources src
  where src.household_id = p_household_id and src.is_active = true and src.archived_at is null
  on conflict (period_id, income_source_id) where income_source_id is not null do nothing;

  insert into public.monthly_items (
    period_id, period_section_budget_id, recurring_template_id, name_snapshot,
    planned_amount, due_date, status, created_by
  )
  select
    v_period_id, psb.id, rt.id, rt.name, rt.default_amount,
    case
      when rt.due_day is null then null
      when rt.due_day >= v_start_day then
        make_date(extract(year from v_start_date)::integer, extract(month from v_start_date)::integer, rt.due_day)
      else
        make_date(extract(year from v_next_start_date)::integer, extract(month from v_next_start_date)::integer, rt.due_day)
    end,
    'pending', v_uid
  from public.recurring_templates rt
  join public.period_section_budgets psb on psb.period_id = v_period_id and psb.section_id = rt.section_id
  where rt.household_id = p_household_id and rt.is_active = true and rt.archived_at is null
  on conflict (period_id, recurring_template_id) where recurring_template_id is not null do nothing;

  return v_period_id;
end;
$$;

revoke all on function public.ensure_budget_period(uuid) from public;
grant execute on function public.ensure_budget_period(uuid) to authenticated;

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

  select pg_catalog.lower(u.email) into v_user_email from auth.users u where u.id = v_uid;
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
  where hm.user_id = v_uid and hm.status = 'active'
  order by hm.joined_at asc, hm.id asc
  limit 1;
  if v_existing_household_id is not null then
    return v_existing_household_id;
  end if;

  select pg_catalog.lower(u.email) into v_user_email from auth.users u where u.id = v_uid;
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

  insert into public.households (name, owner_user_id, currency_code, period_start_day, timezone)
  values (p_name, v_uid, p_currency_code, p_period_start_day, p_timezone)
  returning id into v_household_id;
  return v_household_id;
end;
$$;

revoke all on function public.create_initial_household(text, varchar, integer, text) from public;
revoke all on function public.create_initial_household(text, varchar, integer, text) from anon, service_role;
grant execute on function public.create_initial_household(text, varchar, integer, text) to authenticated;

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
  select pg_catalog.lower(u.email) into v_user_email from auth.users u where u.id = v_uid;
  select * into v_invitation from public.household_invitations hi where hi.id = p_invitation_id for update;
  if v_invitation.id is null then
    raise exception 'invitation_not_found' using errcode = 'P0002';
  end if;
  if pg_catalog.lower(v_invitation.email) is distinct from v_user_email then
    raise exception 'invitation_email_mismatch' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.households h
    where h.id = v_invitation.household_id and h.archived_at is null
  ) then
    raise exception 'household_not_found' using errcode = 'P0002';
  end if;
  if v_invitation.status = 'accepted' and v_invitation.accepted_by = v_uid then
    if exists (
      select 1 from public.household_members hm
      where hm.household_id = v_invitation.household_id and hm.user_id = v_uid and hm.status = 'active'
    ) then
      return v_invitation.household_id;
    end if;
    raise exception 'invitation_acceptance_incomplete' using errcode = 'P0001';
  end if;
  if v_invitation.status <> 'pending' then
    raise exception 'invitation_not_pending' using errcode = 'P0001';
  end if;
  if v_invitation.expires_at <= now() then
    update public.household_invitations set status = 'expired', updated_at = now() where id = v_invitation.id;
    raise exception 'invitation_expired' using errcode = 'P0001';
  end if;

  insert into public.household_members (household_id, user_id, role, status)
  values (v_invitation.household_id, v_uid, 'member', 'active')
  on conflict (household_id, user_id)
  do update set status = 'active', removed_at = null, updated_at = now();
  update public.household_invitations
  set status = 'accepted', accepted_by = v_uid, accepted_at = now(), updated_at = now()
  where id = v_invitation.id;
  insert into public.audit_events (household_id, actor_user_id, actor_type, event_type, entity_type, entity_id)
  values (v_invitation.household_id, v_uid, 'user', 'membership.invitation_accepted', 'household_member', v_uid);
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
  select hi.id into v_invitation_id from public.household_invitations hi where hi.token_hash = p_token_hash;
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
