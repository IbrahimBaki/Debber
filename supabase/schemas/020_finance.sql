-- Dabber declarative schema: monthly finance domain.

create table public.budget_periods (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  period_key date not null,
  start_date date not null,
  end_date date not null,
  status public.period_status not null default 'draft',
  spending_budget numeric(14,2) not null default 0 check (spending_budget >= 0),
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

-- Fixed commitments are deliberately separate from variable spending sections.
create table public.fixed_commitment_templates (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 160),
  default_amount numeric(14,2) not null default 0 check (default_amount >= 0),
  due_day smallint check (due_day is null or due_day between 1 and 28),
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.period_fixed_commitments (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.budget_periods(id) on delete cascade,
  fixed_commitment_template_id uuid references public.fixed_commitment_templates(id) on delete set null,
  name_snapshot text not null check (char_length(name_snapshot) between 1 and 160),
  planned_amount numeric(14,2) not null default 0 check (planned_amount >= 0),
  actual_amount numeric(14,2) check (actual_amount is null or actual_amount >= 0),
  due_date date,
  status public.monthly_item_status not null default 'pending',
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index period_fixed_commitments_template_period_unique
on public.period_fixed_commitments (period_id, fixed_commitment_template_id)
where fixed_commitment_template_id is not null;

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
  -- Structured, nullable references alongside the generic target_type/target_id pair: an admin
  -- mutation typically concerns a specific Auth user and/or a specific Household/invitation, and
  -- typed columns let the Admin audit UI and pgTAP assertions join/filter without parsing text.
  -- Never populated with financial values -- see docs/DECISIONS.md D-034.
  target_user_id uuid references auth.users(id),
  household_id uuid references public.households(id),
  invitation_id uuid references public.household_invitations(id),
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
create trigger fixed_commitment_templates_set_updated_at before update on public.fixed_commitment_templates
for each row execute function public.set_updated_at();
create trigger period_fixed_commitments_set_updated_at before update on public.period_fixed_commitments
for each row execute function public.set_updated_at();
create trigger monthly_items_set_updated_at before update on public.monthly_items
for each row execute function public.set_updated_at();
create trigger transactions_set_updated_at before update on public.transactions
for each row execute function public.set_updated_at();
