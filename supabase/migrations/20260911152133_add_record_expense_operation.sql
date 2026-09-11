-- Migration: 20260911152133_add_record_expense_operation
-- Purpose: Close two confirmed authoritative-enforcement gaps discovered while auditing the
-- transaction-creation path for Quick Expense Entry, per owner-approved decision:
--   1. The prior direct-insert RLS policy ("Contributors can create ordinary transactions")
--      used is_period_open_for_writes(period_id), which is true for Draft OR Open. Nothing
--      authoritative stopped a Draft-period expense insert via the browser-exposed
--      publishable key hitting the REST API directly.
--   2. No trigger/constraint anywhere validated that transactions.occurred_at falls within
--      its budget_periods start_date/end_date, or that it is not in the future.
-- Fix: remove the direct client INSERT path for ordinary transactions entirely and replace
-- it with record_expense(...), a narrow SECURITY DEFINER operation (matching the established
-- D-029 creation-RPC pattern) that authoritatively enforces Owner/Member contribution
-- authorization, Open-only period status, household-timezone date bounds, and idempotent
-- retry via an optional caller-supplied transaction id. mark_monthly_item_paid(...) (the
-- separate linked-recurring-payment path) is unaffected: it is already SECURITY DEFINER and
-- never used the removed policy.
-- Risk: Removes a previously-permissive INSERT policy/grant on public.transactions for
-- authenticated; a client that only ever went through record_expense(...) (or the browser
-- UI, once built) is unaffected. Any hypothetical direct-insert caller loses that path.
-- Data migration: None.
-- Rollback: Forward migration only. Do not delete migration history.

revoke insert (period_id, period_section_budget_id, amount, occurred_at, description, created_by)
  on public.transactions from authenticated;

drop policy "Contributors can create ordinary transactions" on public.transactions;

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
