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
