-- Migration: 20260911141635_reconcile_declarative_schema_drift
-- Purpose: Bring 11 pre-existing functions' stored definitions into byte-for-byte
-- agreement with supabase/schemas/*.sql, discovered while fixing the db-diff workflow
-- (see docs/MIGRATIONS.md). `npx supabase db schema declarative sync` compares the
-- migrations-derived database against the declarative schema files and flags any
-- function whose stored text differs at all from the schema file's text, including
-- pure whitespace. These 11 functions had been hand-authored into supabase/migrations/
-- with denser spacing (e.g. `errcode='42501'`, `x.is_active`) than the already-correct
-- text later written into supabase/schemas/ (e.g. `errcode = '42501'`, `x.is_active = true`).
-- Verified change-by-change: every diff across all 11 functions is either pure
-- whitespace/punctuation spacing, or `column = true` vs bare `column` on a boolean
-- column declared `not null default true` (is_active on budget_sections,
-- fixed_commitment_templates, income_sources, recurring_templates) — logically
-- identical in both forms since the column can never be null. No parameter, type,
-- default, security property, or control-flow logic changes.
-- Risk: None. CREATE OR REPLACE FUNCTION preserves existing grants when the
-- signature is unchanged; no signatures changed here.
-- Data migration: None.
-- Rollback: Forward migration only. Do not delete migration history.
-- Notes: Generated via `npx supabase db schema declarative sync --no-apply`, reviewed,
-- and re-headered to match this project's migration documentation convention.

SET local check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.accept_household_invitation (
  p_token_hash text
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.accept_household_invitation_internal (
  p_invitation_id uuid
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.create_initial_household (
  p_name             text,
  p_currency_code    character varying,
  p_period_start_day integer           DEFAULT 1,
  p_timezone         text              DEFAULT 'Africa/Cairo'::text
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.ensure_budget_period (
  p_household_id uuid
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.get_owner_period_planning_summary (
  p_period_id uuid
)
  RETURNS TABLE (
    total_planned_income            numeric,
    total_planned_commitments       numeric,
    available_after_commitments     numeric,
    spending_budget                 numeric,
    plan_balance                    numeric,
    unallocated_income              numeric,
    planned_deficit                 numeric,
    total_section_allocations       numeric,
    unallocated_spending_budget     numeric,
    actual_variable_spending_total  numeric,
    actual_fixed_commitment_outflow numeric,
    budget_remaining                numeric
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare v_household_id uuid;
begin
  select household_id into v_household_id from public.budget_periods where id=p_period_id;
  if (select auth.uid()) is null or not public.is_household_owner(v_household_id) then raise exception 'not_authorized' using errcode='42501'; end if;
  return query
  with income as (select coalesce(sum(planned_amount),0)::numeric v from public.period_income_items where period_id=p_period_id), commitments as (select coalesce(sum(planned_amount),0)::numeric v from public.period_fixed_commitments where period_id=p_period_id and status in ('pending','paid')), allocations as (select coalesce(sum(planned_amount),0)::numeric v from public.period_section_budgets where period_id=p_period_id and section_kind_snapshot='flexible'), variable_spend as (select coalesce(sum(t.amount),0)::numeric v from public.transactions t join public.period_section_budgets psb on psb.id=t.period_section_budget_id where t.period_id=p_period_id and t.state='posted' and psb.section_kind_snapshot='flexible'), fixed_actual as (select coalesce(sum(actual_amount),0)::numeric v from public.period_fixed_commitments where period_id=p_period_id and status='paid')
  select income.v, commitments.v, income.v-commitments.v, bp.spending_budget, income.v-commitments.v-bp.spending_budget, greatest(income.v-commitments.v-bp.spending_budget,0), greatest(-(income.v-commitments.v-bp.spending_budget),0), allocations.v, bp.spending_budget-allocations.v, variable_spend.v, fixed_actual.v, bp.spending_budget-variable_spend.v from public.budget_periods bp,income,commitments,allocations,variable_spend,fixed_actual where bp.id=p_period_id;
end; $function$;

CREATE OR REPLACE FUNCTION public.list_my_pending_household_invitations()
  RETURNS TABLE (
    invitation_id        uuid,
    household_id         uuid,
    household_name       text,
    inviter_display_name text,
    created_at           timestamp with time zone,
    expires_at           timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.mark_period_fixed_commitment_paid (
  p_period_fixed_commitment_id uuid,
  p_actual_amount              numeric DEFAULT NULL::numeric
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
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
end; $function$;

CREATE OR REPLACE FUNCTION public.set_period_fixed_commitment_planned_amount (
  p_period_fixed_commitment_id uuid,
  p_planned_amount             numeric
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
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
end; $function$;

CREATE OR REPLACE FUNCTION public.set_period_fixed_commitment_skipped (
  p_period_fixed_commitment_id uuid,
  p_skip                       boolean,
  p_reason                     text    DEFAULT NULL::text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
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
end; $function$;

CREATE OR REPLACE FUNCTION public.set_period_section_allocation (
  p_period_section_budget_id uuid,
  p_planned_amount           numeric
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
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
end; $function$;

CREATE OR REPLACE FUNCTION public.set_period_spending_budget (
  p_period_id       uuid,
  p_spending_budget numeric
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
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
end; $function$;
