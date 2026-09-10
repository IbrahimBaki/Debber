-- Migration: 20260910190000_initial_dabber_schema
-- Purpose: Initial Dabber household budgeting schema, RLS, integrity checks, and core transactional RPCs.
-- Risk: New-schema baseline; no existing production rows are assumed.
-- Data migration: None.
-- Rollback: Recreate a fresh non-production environment from the previous migration chain; production changes are forward-fixed.
-- Notes: Generated from the committed declarative files under supabase/schemas and reviewed as the v2.0 baseline.

-- Dabber declarative schema: shared types and helper functions.

create extension if not exists pgcrypto with schema extensions;

create type public.household_role as enum ('owner', 'member');
create type public.member_status as enum ('active', 'removed');
create type public.invitation_status as enum ('pending', 'accepted', 'revoked', 'expired');
create type public.period_status as enum ('draft', 'open', 'closed');
create type public.section_kind as enum ('fixed', 'flexible');
create type public.visibility_scope as enum ('owner_only', 'household', 'custom');
create type public.section_member_access as enum ('view', 'contribute');
create type public.monthly_item_status as enum ('pending', 'paid', 'skipped');
create type public.transaction_state as enum ('posted', 'voided');
create type public.platform_admin_role as enum ('super_admin', 'support', 'read_only');
create type public.audit_actor_type as enum ('user', 'platform_admin', 'system');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
-- Dabber declarative schema: identity, households, membership, invitations and platform admins.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  locale text not null default 'ar-EG',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  owner_user_id uuid not null references auth.users(id),
  currency_code varchar(3) not null default 'EGP' check (currency_code ~ '^[A-Z]{3}$'),
  timezone text not null default 'Africa/Cairo',
  period_start_day smallint not null default 1 check (period_start_day between 1 and 28),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.household_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.household_role not null default 'member',
  status public.member_status not null default 'active',
  joined_at timestamptz not null default now(),
  removed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, user_id)
);

create table public.household_invitations (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  email text not null,
  token_hash text not null unique,
  status public.invitation_status not null default 'pending',
  invited_by uuid not null references auth.users(id),
  expires_at timestamptz not null,
  accepted_by uuid references auth.users(id),
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role public.platform_admin_role not null default 'super_admin',
  is_active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Generic per-member grants are used only when a resource is set to visibility_scope = 'custom'.
-- resource_id is intentionally polymorphic; application/domain code must validate the referenced resource.
create table public.resource_permissions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  resource_type text not null check (resource_type in ('budget_section', 'income_source', 'income_item', 'goal')),
  resource_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  can_view boolean not null default true,
  can_edit boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (resource_type, resource_id, user_id)
);

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', new.raw_user_meta_data ->> 'name'))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

create or replace function public.handle_new_household_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.household_members (household_id, user_id, role, status)
  values (new.id, new.owner_user_id, 'owner', 'active')
  on conflict (household_id, user_id)
  do update set role = 'owner', status = 'active', removed_at = null, updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_household_created on public.households;
create trigger on_household_created
after insert on public.households
for each row execute function public.handle_new_household_owner();

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger households_set_updated_at before update on public.households
for each row execute function public.set_updated_at();
create trigger household_members_set_updated_at before update on public.household_members
for each row execute function public.set_updated_at();
create trigger household_invitations_set_updated_at before update on public.household_invitations
for each row execute function public.set_updated_at();
create trigger platform_admins_set_updated_at before update on public.platform_admins
for each row execute function public.set_updated_at();
create trigger resource_permissions_set_updated_at before update on public.resource_permissions
for each row execute function public.set_updated_at();
-- Dabber declarative schema: monthly finance domain.

create table public.budget_periods (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  period_key date not null,
  start_date date not null,
  end_date date not null,
  status public.period_status not null default 'draft',
  opened_at timestamptz,
  closed_at timestamptz,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, period_key),
  check (end_date >= start_date)
);

create table public.income_sources (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  default_amount numeric(14,2) not null default 0 check (default_amount >= 0),
  visibility_scope public.visibility_scope not null default 'owner_only',
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_by uuid not null references auth.users(id),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.period_income_items (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.budget_periods(id) on delete cascade,
  income_source_id uuid references public.income_sources(id) on delete set null,
  name_snapshot text not null check (char_length(name_snapshot) between 1 and 120),
  planned_amount numeric(14,2) not null default 0 check (planned_amount >= 0),
  actual_amount numeric(14,2) check (actual_amount is null or actual_amount >= 0),
  one_off_visibility_scope public.visibility_scope not null default 'owner_only',
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index period_income_items_source_unique
on public.period_income_items (period_id, income_source_id)
where income_source_id is not null;

create table public.budget_sections (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  kind public.section_kind not null,
  default_planned_amount numeric(14,2) not null default 0 check (default_planned_amount >= 0),
  visibility_scope public.visibility_scope not null default 'owner_only',
  member_access public.section_member_access not null default 'view',
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_by uuid not null references auth.users(id),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.period_section_budgets (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.budget_periods(id) on delete cascade,
  section_id uuid not null references public.budget_sections(id),
  section_name_snapshot text not null,
  section_kind_snapshot public.section_kind not null,
  planned_amount numeric(14,2) not null default 0 check (planned_amount >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (period_id, section_id)
);

create table public.recurring_templates (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  section_id uuid not null references public.budget_sections(id),
  name text not null check (char_length(name) between 1 and 160),
  default_amount numeric(14,2) not null default 0 check (default_amount >= 0),
  due_day smallint check (due_day is null or due_day between 1 and 28),
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.monthly_items (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.budget_periods(id) on delete cascade,
  period_section_budget_id uuid not null references public.period_section_budgets(id) on delete cascade,
  recurring_template_id uuid references public.recurring_templates(id) on delete set null,
  name_snapshot text not null check (char_length(name_snapshot) between 1 and 160),
  planned_amount numeric(14,2) not null default 0 check (planned_amount >= 0),
  actual_amount numeric(14,2) check (actual_amount is null or actual_amount >= 0),
  due_date date,
  status public.monthly_item_status not null default 'pending',
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index monthly_items_template_period_unique
on public.monthly_items (period_id, recurring_template_id)
where recurring_template_id is not null;

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.budget_periods(id) on delete cascade,
  period_section_budget_id uuid not null references public.period_section_budgets(id),
  monthly_item_id uuid references public.monthly_items(id) on delete set null,
  amount numeric(14,2) not null check (amount > 0),
  occurred_at timestamptz not null default now(),
  description text check (description is null or char_length(description) <= 500),
  state public.transaction_state not null default 'posted',
  created_by uuid not null references auth.users(id),
  updated_by uuid references auth.users(id),
  voided_by uuid references auth.users(id),
  voided_at timestamptz,
  void_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((state = 'posted' and voided_at is null) or state = 'voided')
);

-- MVP: a recurring monthly item maps to at most one posted transaction.
-- Partial payments can later replace this with a payment-allocation table.
create unique index transactions_monthly_item_unique
on public.transactions (monthly_item_id)
where monthly_item_id is not null and state = 'posted';

create table public.audit_events (
  id bigint generated always as identity primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  actor_user_id uuid references auth.users(id),
  actor_type public.audit_actor_type not null default 'user',
  event_type text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.admin_audit_logs (
  id bigint generated always as identity primary key,
  admin_user_id uuid not null references auth.users(id),
  action text not null,
  target_type text not null,
  target_id text,
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create trigger budget_periods_set_updated_at before update on public.budget_periods
for each row execute function public.set_updated_at();
create trigger income_sources_set_updated_at before update on public.income_sources
for each row execute function public.set_updated_at();
create trigger period_income_items_set_updated_at before update on public.period_income_items
for each row execute function public.set_updated_at();
create trigger budget_sections_set_updated_at before update on public.budget_sections
for each row execute function public.set_updated_at();
create trigger period_section_budgets_set_updated_at before update on public.period_section_budgets
for each row execute function public.set_updated_at();
create trigger recurring_templates_set_updated_at before update on public.recurring_templates
for each row execute function public.set_updated_at();
create trigger monthly_items_set_updated_at before update on public.monthly_items
for each row execute function public.set_updated_at();
create trigger transactions_set_updated_at before update on public.transactions
for each row execute function public.set_updated_at();
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
-- Dabber declarative schema: reusable authorization helpers.
-- All security-definer functions use an empty search_path and fully-qualified names.

create or replace function public.is_household_member(p_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members hm
    where hm.household_id = p_household_id
      and hm.user_id = (select auth.uid())
      and hm.status = 'active'
  );
$$;

create or replace function public.is_household_owner(p_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.households h
    where h.id = p_household_id
      and h.owner_user_id = (select auth.uid())
      and h.archived_at is null
  );
$$;

create or replace function public.shares_household_with(p_other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members mine
    join public.household_members theirs
      on theirs.household_id = mine.household_id
    where mine.user_id = (select auth.uid())
      and mine.status = 'active'
      and theirs.user_id = p_other_user_id
      and theirs.status = 'active'
  );
$$;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.platform_admins pa
    where pa.user_id = (select auth.uid())
      and pa.is_active = true
      and pa.role = 'super_admin'
  );
$$;

create or replace function public.can_view_resource(
  p_household_id uuid,
  p_scope public.visibility_scope,
  p_resource_type text,
  p_resource_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    return false;
  end if;

  if public.is_household_owner(p_household_id) then
    return true;
  end if;

  if not public.is_household_member(p_household_id) then
    return false;
  end if;

  if p_scope = 'household' then
    return true;
  elsif p_scope = 'owner_only' then
    return false;
  end if;

  return exists (
    select 1
    from public.resource_permissions rp
    where rp.household_id = p_household_id
      and rp.resource_type = p_resource_type
      and rp.resource_id = p_resource_id
      and rp.user_id = (select auth.uid())
      and rp.can_view = true
  );
end;
$$;

create or replace function public.can_edit_custom_resource(
  p_household_id uuid,
  p_resource_type text,
  p_resource_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_household_owner(p_household_id)
      or exists (
        select 1
        from public.resource_permissions rp
        where rp.household_id = p_household_id
          and rp.resource_type = p_resource_type
          and rp.resource_id = p_resource_id
          and rp.user_id = (select auth.uid())
          and rp.can_view = true
          and rp.can_edit = true
      );
$$;

create or replace function public.can_view_section(p_section_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select public.can_view_resource(
        s.household_id,
        s.visibility_scope,
        'budget_section',
        s.id
      )
      from public.budget_sections s
      where s.id = p_section_id
    ),
    false
  );
$$;

create or replace function public.can_contribute_to_section(p_section_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_household_id uuid;
  v_scope public.visibility_scope;
  v_access public.section_member_access;
begin
  select s.household_id, s.visibility_scope, s.member_access
  into v_household_id, v_scope, v_access
  from public.budget_sections s
  where s.id = p_section_id;

  if v_household_id is null then
    return false;
  end if;

  if public.is_household_owner(v_household_id) then
    return true;
  end if;

  if not public.can_view_resource(v_household_id, v_scope, 'budget_section', p_section_id) then
    return false;
  end if;

  if v_scope = 'custom' then
    return public.can_edit_custom_resource(v_household_id, 'budget_section', p_section_id);
  end if;

  return v_access = 'contribute';
end;
$$;

create or replace function public.period_household_id(p_period_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select bp.household_id from public.budget_periods bp where bp.id = p_period_id;
$$;

create or replace function public.is_period_open_for_writes(p_period_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select bp.status in ('draft', 'open') from public.budget_periods bp where bp.id = p_period_id), false);
$$;

create or replace function public.can_view_income_item(p_income_item_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select public.can_view_resource(
        bp.household_id,
        case
          when pii.income_source_id is null then pii.one_off_visibility_scope
          else src.visibility_scope
        end,
        case when pii.income_source_id is null then 'income_item' else 'income_source' end,
        coalesce(pii.income_source_id, pii.id)
      )
      from public.period_income_items pii
      join public.budget_periods bp on bp.id = pii.period_id
      left join public.income_sources src on src.id = pii.income_source_id
      where pii.id = p_income_item_id
    ),
    false
  );
$$;
-- Dabber declarative schema: grants and Row Level Security.
-- Public/anon access is denied by default. Authenticated access is explicitly granted then constrained by RLS.

alter table public.profiles enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.household_invitations enable row level security;
alter table public.platform_admins enable row level security;
alter table public.resource_permissions enable row level security;
alter table public.budget_periods enable row level security;
alter table public.income_sources enable row level security;
alter table public.period_income_items enable row level security;
alter table public.budget_sections enable row level security;
alter table public.period_section_budgets enable row level security;
alter table public.recurring_templates enable row level security;
alter table public.monthly_items enable row level security;
alter table public.transactions enable row level security;
alter table public.audit_events enable row level security;
alter table public.admin_audit_logs enable row level security;

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.households from anon, authenticated;
revoke all on table public.household_members from anon, authenticated;
revoke all on table public.household_invitations from anon, authenticated;
revoke all on table public.platform_admins from anon, authenticated;
revoke all on table public.resource_permissions from anon, authenticated;
revoke all on table public.budget_periods from anon, authenticated;
revoke all on table public.income_sources from anon, authenticated;
revoke all on table public.period_income_items from anon, authenticated;
revoke all on table public.budget_sections from anon, authenticated;
revoke all on table public.period_section_budgets from anon, authenticated;
revoke all on table public.recurring_templates from anon, authenticated;
revoke all on table public.monthly_items from anon, authenticated;
revoke all on table public.transactions from anon, authenticated;
revoke all on table public.audit_events from anon, authenticated;
revoke all on table public.admin_audit_logs from anon, authenticated;

-- Profiles
grant select, update on table public.profiles to authenticated;
create policy "Users can read their profile or profiles in a shared household"
on public.profiles for select to authenticated
using (
  id = (select auth.uid())
  or (select public.shares_household_with(id))
);
create policy "Users can update only their own profile"
on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- Households
grant select, insert, update on table public.households to authenticated;
create policy "Active household members can read the household"
on public.households for select to authenticated
using ((select public.is_household_member(id)));
create policy "Users can create a household owned by themselves"
on public.households for insert to authenticated
with check (owner_user_id = (select auth.uid()));
create policy "Only the household owner can update the household"
on public.households for update to authenticated
using ((select public.is_household_owner(id)))
with check (owner_user_id = (select auth.uid()));

-- Household members
grant select on table public.household_members to authenticated;
create policy "Members can read membership rows in their household"
on public.household_members for select to authenticated
using ((select public.is_household_member(household_id)));

-- Invitations
grant select, insert, update, delete on table public.household_invitations to authenticated;
create policy "Owners can read invitations for their household"
on public.household_invitations for select to authenticated
using ((select public.is_household_owner(household_id)));
create policy "Owners can create invitations for their household"
on public.household_invitations for insert to authenticated
with check (
  (select public.is_household_owner(household_id))
  and invited_by = (select auth.uid())
);
create policy "Owners can update invitations for their household"
on public.household_invitations for update to authenticated
using ((select public.is_household_owner(household_id)))
with check ((select public.is_household_owner(household_id)));
create policy "Owners can delete invitations for their household"
on public.household_invitations for delete to authenticated
using ((select public.is_household_owner(household_id)));

-- Platform admin marker: clients may only read their own marker. All privileged data access still happens server-side.
grant select on table public.platform_admins to authenticated;
create policy "Users can read only their own platform admin marker"
on public.platform_admins for select to authenticated
using (user_id = (select auth.uid()));

-- Custom resource permissions
grant select, insert, update, delete on table public.resource_permissions to authenticated;
create policy "Owners and granted members can read resource permissions"
on public.resource_permissions for select to authenticated
using (
  (select public.is_household_owner(household_id))
  or user_id = (select auth.uid())
);
create policy "Only owners can create resource permissions"
on public.resource_permissions for insert to authenticated
with check ((select public.is_household_owner(household_id)));
create policy "Only owners can update resource permissions"
on public.resource_permissions for update to authenticated
using ((select public.is_household_owner(household_id)))
with check ((select public.is_household_owner(household_id)));
create policy "Only owners can delete resource permissions"
on public.resource_permissions for delete to authenticated
using ((select public.is_household_owner(household_id)));

-- Budget periods
grant select, insert on table public.budget_periods to authenticated;
create policy "Members can read budget periods"
on public.budget_periods for select to authenticated
using ((select public.is_household_member(household_id)));
create policy "Owners can create budget periods"
on public.budget_periods for insert to authenticated
with check (
  (select public.is_household_owner(household_id))
  and created_by = (select auth.uid())
);
-- Income sources
grant select, insert, update on table public.income_sources to authenticated;
create policy "Users can read visible income sources"
on public.income_sources for select to authenticated
using ((select public.can_view_resource(household_id, visibility_scope, 'income_source', id)));
create policy "Owners can create income sources"
on public.income_sources for insert to authenticated
with check ((select public.is_household_owner(household_id)) and created_by = (select auth.uid()));
create policy "Owners can update income sources"
on public.income_sources for update to authenticated
using ((select public.is_household_owner(household_id)))
with check ((select public.is_household_owner(household_id)));

-- Period income items
grant select, insert, update, delete on table public.period_income_items to authenticated;
create policy "Users can read visible period income items"
on public.period_income_items for select to authenticated
using ((select public.can_view_income_item(id)));
create policy "Owners can create period income items"
on public.period_income_items for insert to authenticated
with check (
  (select public.is_household_owner(public.period_household_id(period_id)))
  and created_by = (select auth.uid())
  and (select public.is_period_open_for_writes(period_id))
);
create policy "Owners can update period income items"
on public.period_income_items for update to authenticated
using (
  (select public.is_household_owner(public.period_household_id(period_id)))
  and (select public.is_period_open_for_writes(period_id))
)
with check (
  (select public.is_household_owner(public.period_household_id(period_id)))
  and (select public.is_period_open_for_writes(period_id))
);
create policy "Owners can delete period income items before close"
on public.period_income_items for delete to authenticated
using (
  (select public.is_household_owner(public.period_household_id(period_id)))
  and (select public.is_period_open_for_writes(period_id))
);

-- Budget sections
grant select, insert, update on table public.budget_sections to authenticated;
create policy "Users can read visible budget sections"
on public.budget_sections for select to authenticated
using ((select public.can_view_section(id)));
create policy "Owners can create budget sections"
on public.budget_sections for insert to authenticated
with check ((select public.is_household_owner(household_id)) and created_by = (select auth.uid()));
create policy "Owners can update budget sections"
on public.budget_sections for update to authenticated
using ((select public.is_household_owner(household_id)))
with check ((select public.is_household_owner(household_id)));

-- Monthly section snapshots
grant select, insert, update on table public.period_section_budgets to authenticated;
create policy "Users can read visible monthly section budgets"
on public.period_section_budgets for select to authenticated
using ((select public.can_view_section(section_id)));
create policy "Owners can create monthly section budgets"
on public.period_section_budgets for insert to authenticated
with check (
  (select public.is_household_owner(public.period_household_id(period_id)))
  and (select public.is_period_open_for_writes(period_id))
);
create policy "Owners can update monthly section budgets"
on public.period_section_budgets for update to authenticated
using (
  (select public.is_household_owner(public.period_household_id(period_id)))
  and (select public.is_period_open_for_writes(period_id))
)
with check (
  (select public.is_household_owner(public.period_household_id(period_id)))
  and (select public.is_period_open_for_writes(period_id))
);

-- Recurring templates inherit the containing section privacy boundary.
grant select, insert, update on table public.recurring_templates to authenticated;
create policy "Users can read recurring templates in visible sections"
on public.recurring_templates for select to authenticated
using ((select public.can_view_section(section_id)));
create policy "Owners can create recurring templates"
on public.recurring_templates for insert to authenticated
with check ((select public.is_household_owner(household_id)) and created_by = (select auth.uid()));
create policy "Owners can update recurring templates"
on public.recurring_templates for update to authenticated
using ((select public.is_household_owner(household_id)))
with check ((select public.is_household_owner(household_id)));

-- Monthly items: members read visible sections; direct mutation is owner-only.
-- Partner payment/checklist actions use a checked RPC so status + transaction stay atomic.
grant select, insert on table public.monthly_items to authenticated;
grant update (name_snapshot, planned_amount, due_date) on table public.monthly_items to authenticated;
create policy "Users can read monthly items in visible sections"
on public.monthly_items for select to authenticated
using (
  exists (
    select 1
    from public.period_section_budgets psb
    where psb.id = monthly_items.period_section_budget_id
      and (select public.can_view_section(psb.section_id))
  )
);
create policy "Owners can create monthly items"
on public.monthly_items for insert to authenticated
with check (
  (select public.is_household_owner(public.period_household_id(period_id)))
  and created_by = (select auth.uid())
  and (select public.is_period_open_for_writes(period_id))
);
create policy "Owners can update monthly items"
on public.monthly_items for update to authenticated
using (
  (select public.is_household_owner(public.period_household_id(period_id)))
  and (select public.is_period_open_for_writes(period_id))
)
with check (
  (select public.is_household_owner(public.period_household_id(period_id)))
  and (select public.is_period_open_for_writes(period_id))
);

-- Transactions: direct inserts are for ordinary expenses only. Linked recurring payments use RPC.
grant select on table public.transactions to authenticated;
grant insert (period_id, period_section_budget_id, amount, occurred_at, description, created_by) on table public.transactions to authenticated;
grant update (period_section_budget_id, amount, occurred_at, description, updated_by) on table public.transactions to authenticated;
create policy "Users can read transactions in visible sections"
on public.transactions for select to authenticated
using (
  exists (
    select 1
    from public.period_section_budgets psb
    where psb.id = transactions.period_section_budget_id
      and (select public.can_view_section(psb.section_id))
  )
);
create policy "Contributors can create ordinary transactions"
on public.transactions for insert to authenticated
with check (
  monthly_item_id is null
  and state = 'posted'
  and voided_at is null
  and voided_by is null
  and created_by = (select auth.uid())
  and (select public.is_period_open_for_writes(period_id))
  and exists (
    select 1
    from public.period_section_budgets psb
    where psb.id = transactions.period_section_budget_id
      and psb.period_id = transactions.period_id
      and (select public.can_contribute_to_section(psb.section_id))
  )
);
create policy "Owners or creators can update posted transactions before close"
on public.transactions for update to authenticated
using (
  state = 'posted'
  and (select public.is_period_open_for_writes(period_id))
  and (
    (select public.is_household_owner(public.period_household_id(period_id)))
    or created_by = (select auth.uid())
  )
)
with check (
  (select public.is_period_open_for_writes(period_id))
  and (updated_by is null or updated_by = (select auth.uid()))
  and exists (
    select 1
    from public.period_section_budgets psb
    where psb.id = transactions.period_section_budget_id
      and psb.period_id = transactions.period_id
      and (select public.can_contribute_to_section(psb.section_id))
  )
);

-- Household audit events are owner-visible. Writes are reserved for checked RPCs/triggers/server workflows.
grant select on table public.audit_events to authenticated;
create policy "Only household owners can read household audit events"
on public.audit_events for select to authenticated
using ((select public.is_household_owner(household_id)));

-- admin_audit_logs intentionally has no anon/authenticated grants or policies.
-- It is accessed only by the server-side Supabase secret-key client after platform-admin verification.
-- Dabber declarative schema: domain RPCs that require atomic multi-table writes.

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
  v_start_date date;
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

  if extract(day from v_local_date)::integer >= v_start_day then
    v_start_date := make_date(
      extract(year from v_local_date)::integer,
      extract(month from v_local_date)::integer,
      v_start_day
    );
  else
    v_start_date := (date_trunc('month', v_local_date)::date - interval '1 month')::date
                    + (v_start_day - 1);
  end if;

  v_end_date := (v_start_date + interval '1 month' - interval '1 day')::date;

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
    v_period_id, s.id, s.name, s.kind, s.default_planned_amount
  from public.budget_sections s
  where s.household_id = p_household_id
    and s.is_active = true
    and s.archived_at is null
  on conflict (period_id, section_id) do nothing;

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
          extract(year from (v_start_date + interval '1 month'))::integer,
          extract(month from (v_start_date + interval '1 month'))::integer,
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


create or replace function public.accept_household_invitation(p_token_hash text)
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

  select lower(u.email) into v_user_email
  from auth.users u where u.id = v_uid;

  select * into v_invitation
  from public.household_invitations hi
  where hi.token_hash = p_token_hash
    and hi.status = 'pending'
  for update;

  if v_invitation.id is null then
    raise exception 'invitation_not_found' using errcode = 'P0002';
  end if;

  if v_invitation.expires_at <= now() then
    update public.household_invitations
    set status = 'expired', updated_at = now()
    where id = v_invitation.id;
    raise exception 'invitation_expired' using errcode = 'P0001';
  end if;

  if lower(v_invitation.email) is distinct from v_user_email then
    raise exception 'invitation_email_mismatch' using errcode = '42501';
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

revoke all on function public.accept_household_invitation(text) from public;
grant execute on function public.accept_household_invitation(text) to authenticated;

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
