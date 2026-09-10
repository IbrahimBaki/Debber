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
