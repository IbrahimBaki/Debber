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
  currency_code varchar(3) not null default 'EGP'
    check (currency_code in ('EGP', 'SAR', 'USD', 'EUR')),
  timezone text not null default 'Africa/Cairo',
  period_start_day smallint not null default 1 check (period_start_day between 1 and 31),
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
