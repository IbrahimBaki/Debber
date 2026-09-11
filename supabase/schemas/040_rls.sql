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
alter table public.fixed_commitment_templates enable row level security;
alter table public.period_fixed_commitments enable row level security;
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
revoke all on table public.fixed_commitment_templates from anon, authenticated;
revoke all on table public.period_fixed_commitments from anon, authenticated;
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
grant select, update on table public.households to authenticated;
create policy "Active household members can read the household"
on public.households for select to authenticated
using ((select public.is_household_member(id)));
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

-- Fixed commitments are Owner-only in MVP; no summary RPC exposes them to members.
grant select, insert, update on table public.fixed_commitment_templates to authenticated;
create policy "Owners can read fixed commitment templates"
on public.fixed_commitment_templates for select to authenticated
using ((select public.is_household_owner(household_id)));
create policy "Owners can create fixed commitment templates"
on public.fixed_commitment_templates for insert to authenticated
with check ((select public.is_household_owner(household_id)) and created_by = (select auth.uid()));
create policy "Owners can update fixed commitment templates"
on public.fixed_commitment_templates for update to authenticated
using ((select public.is_household_owner(household_id)))
with check ((select public.is_household_owner(household_id)));

grant select on table public.period_fixed_commitments to authenticated;
create policy "Owners can read period fixed commitments"
on public.period_fixed_commitments for select to authenticated
using ((select public.is_household_owner(public.period_household_id(period_id))));

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
grant select on table public.period_section_budgets to authenticated;
create policy "Users can read visible monthly section budgets"
on public.period_section_budgets for select to authenticated
using ((select public.can_view_section(section_id)));

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
