SET local check_function_bodies = off;

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
  v_period_status public.period_status;
  v_planned numeric;
  v_status public.monthly_item_status;
  v_amount numeric(14,2);
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode='42501'; end if;
  select pfc.period_id, bp.household_id, bp.status, pfc.planned_amount, pfc.status
  into v_period_id, v_household_id, v_period_status, v_planned, v_status
  from public.period_fixed_commitments pfc
  join public.budget_periods bp on bp.id=pfc.period_id
  where pfc.id=p_period_fixed_commitment_id
  for update of pfc;
  if v_period_id is null then raise exception 'fixed_commitment_not_found' using errcode='P0002'; end if;
  if not public.is_household_owner(v_household_id) then raise exception 'not_authorized' using errcode='42501'; end if;
  -- Operational settlement is Open-only (unlike the planning RPCs below, which remain
  -- Draft/Open via is_period_open_for_writes(...)): you cannot have actually paid a bill for
  -- a month that has not started yet or has already closed.
  if v_period_status <> 'open' then raise exception 'period_not_open' using errcode='P0001'; end if;
  if v_status = 'paid' then return; end if;
  v_amount := coalesce(p_actual_amount, v_planned);
  if v_amount is null or v_amount <= 0 then raise exception 'invalid_amount' using errcode='22003'; end if;
  update public.period_fixed_commitments
  set status='paid', actual_amount=v_amount
  where id=p_period_fixed_commitment_id;
  insert into public.audit_events(household_id,actor_user_id,actor_type,event_type,entity_type,entity_id,after_data)
  values(v_household_id,v_uid,'user','fixed_commitment.paid','period_fixed_commitment',p_period_fixed_commitment_id,jsonb_build_object('actual_amount', v_amount));
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
  v_period_status public.period_status;
  v_status public.monthly_item_status;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode='42501'; end if;
  select pfc.period_id, bp.household_id, bp.status, pfc.status
  into v_period_id, v_household_id, v_period_status, v_status
  from public.period_fixed_commitments pfc
  join public.budget_periods bp on bp.id = pfc.period_id
  where pfc.id = p_period_fixed_commitment_id
  for update of pfc;
  if v_period_id is null then raise exception 'fixed_commitment_not_found' using errcode='P0002'; end if;
  if not public.is_household_owner(v_household_id) then raise exception 'not_authorized' using errcode='42501'; end if;
  -- Both Pending->Skipped and Skipped->Pending are Open-only operational mutations; unlike
  -- set_period_fixed_commitment_planned_amount above, this is not a planning edit.
  if v_period_status <> 'open' then raise exception 'period_not_open' using errcode='P0001'; end if;
  if p_skip and v_status = 'paid' then raise exception 'cannot_skip_paid_commitment' using errcode='23514'; end if;
  update public.period_fixed_commitments
  set status = case when p_skip then 'skipped'::public.monthly_item_status else 'pending'::public.monthly_item_status end,
      actual_amount = case when p_skip then null else actual_amount end
  where id = p_period_fixed_commitment_id;
  insert into public.audit_events(household_id,actor_user_id,actor_type,event_type,entity_type,entity_id,metadata)
  values(v_household_id,v_uid,'user',case when p_skip then 'fixed_commitment.skipped' else 'fixed_commitment.unskipped' end,'period_fixed_commitment',p_period_fixed_commitment_id,jsonb_build_object('reason', p_reason));
end; $function$;
