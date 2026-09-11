begin;

create extension if not exists pgtap with schema extensions;

select plan(27);

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('90000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'fcl-owner@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('90000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'fcl-member@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now());

insert into public.households (id, name, owner_user_id, currency_code)
values ('91000000-0000-0000-0000-000000000001', 'التزامات دورة الفترة', '90000000-0000-0000-0000-000000000001', 'EGP');

insert into public.household_members (household_id, user_id, role, status)
values ('91000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000002', 'member', 'active');

insert into public.budget_periods (id, household_id, period_key, start_date, end_date, status, spending_budget, created_by)
values
  ('92000000-0000-0000-0000-000000000001', '91000000-0000-0000-0000-000000000001', date '2026-01-01', date '2026-01-01', date '2026-01-31', 'draft', 0, '90000000-0000-0000-0000-000000000001'),
  ('92000000-0000-0000-0000-000000000002', '91000000-0000-0000-0000-000000000001', date '2026-02-01', date '2026-02-01', date '2026-02-28', 'open', 5000, '90000000-0000-0000-0000-000000000001'),
  ('92000000-0000-0000-0000-000000000003', '91000000-0000-0000-0000-000000000001', date '2026-03-01', date '2026-03-01', date '2026-03-31', 'closed', 0, '90000000-0000-0000-0000-000000000001');

insert into public.fixed_commitment_templates (id, household_id, name, default_amount, created_by)
values
  ('93000000-0000-0000-0000-000000000001', '91000000-0000-0000-0000-000000000001', 'إيجار', 6000, '90000000-0000-0000-0000-000000000001'),
  ('93000000-0000-0000-0000-000000000002', '91000000-0000-0000-0000-000000000001', 'جمعية', 2000, '90000000-0000-0000-0000-000000000001');

insert into public.period_fixed_commitments (id, period_id, fixed_commitment_template_id, name_snapshot, planned_amount, status, created_by)
values
  ('94000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000001', null, 'التزام في مسودة', 1000, 'pending', '90000000-0000-0000-0000-000000000001'),
  ('94000000-0000-0000-0000-000000000002', '92000000-0000-0000-0000-000000000002', '93000000-0000-0000-0000-000000000001', 'إيجار', 6000, 'pending', '90000000-0000-0000-0000-000000000001'),
  ('94000000-0000-0000-0000-000000000003', '92000000-0000-0000-0000-000000000002', '93000000-0000-0000-0000-000000000002', 'جمعية', 2000, 'pending', '90000000-0000-0000-0000-000000000001'),
  ('94000000-0000-0000-0000-000000000004', '92000000-0000-0000-0000-000000000003', null, 'التزام في شهر مقفول', 500, 'pending', '90000000-0000-0000-0000-000000000001');

-- A flexible section + an existing posted expense in the Open period, for the fixed/variable
-- separation regression below.
insert into public.budget_sections (id, household_id, name, kind, visibility_scope, member_access, created_by)
values ('95000000-0000-0000-0000-000000000001', '91000000-0000-0000-0000-000000000001', 'مصروف يومي', 'flexible', 'owner_only', 'view', '90000000-0000-0000-0000-000000000001');
insert into public.period_section_budgets (id, period_id, section_id, section_name_snapshot, section_kind_snapshot, planned_amount)
values ('96000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000002', '95000000-0000-0000-0000-000000000001', 'مصروف يومي', 'flexible', 1000);
insert into public.transactions (period_id, period_section_budget_id, amount, created_by)
values ('92000000-0000-0000-0000-000000000002', '96000000-0000-0000-0000-000000000001', 300, '90000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', true);

-- === PAID ===
select throws_ok(
  $$select public.mark_period_fixed_commitment_paid('94000000-0000-0000-0000-000000000001')$$,
  'P0001', 'period_not_open', 'Paid is rejected on a Draft period'
);
select lives_ok(
  $$select public.mark_period_fixed_commitment_paid('94000000-0000-0000-0000-000000000002')$$,
  'Paid succeeds on an Open period'
);
select throws_ok(
  $$select public.mark_period_fixed_commitment_paid('94000000-0000-0000-0000-000000000004')$$,
  'P0001', 'period_not_open', 'Paid is rejected on a Closed period'
);

reset role;
select is(
  (select status::text from public.period_fixed_commitments where id = '94000000-0000-0000-0000-000000000002'),
  'paid', 'status becomes paid'
);
select is(
  (select actual_amount from public.period_fixed_commitments where id = '94000000-0000-0000-0000-000000000002'),
  6000::numeric, 'actual_amount defaults to planned_amount'
);
select is(
  (select count(*)::integer from public.audit_events where entity_id = '94000000-0000-0000-0000-000000000002' and event_type = 'fixed_commitment.paid'),
  1, 'exactly one paid audit event'
);

-- Repeated Paid in Open: still idempotent, no double count, no duplicate audit event.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.mark_period_fixed_commitment_paid('94000000-0000-0000-0000-000000000002')$$,
  'repeated Paid call in Open does not error'
);
reset role;
select is(
  (select actual_amount from public.period_fixed_commitments where id = '94000000-0000-0000-0000-000000000002'),
  6000::numeric, 'repeated Paid does not change the recorded actual amount'
);
select is(
  (select count(*)::integer from public.audit_events where entity_id = '94000000-0000-0000-0000-000000000002' and event_type = 'fixed_commitment.paid'),
  1, 'repeated Paid writes no second audit event'
);

-- === SKIP ===
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$select public.set_period_fixed_commitment_skipped('94000000-0000-0000-0000-000000000001', true)$$,
  'P0001', 'period_not_open', 'Skip is rejected on a Draft period'
);
select lives_ok(
  $$select public.set_period_fixed_commitment_skipped('94000000-0000-0000-0000-000000000003', true)$$,
  'Skip succeeds on an Open period'
);
select throws_ok(
  $$select public.set_period_fixed_commitment_skipped('94000000-0000-0000-0000-000000000004', true)$$,
  'P0001', 'period_not_open', 'Skip is rejected on a Closed period'
);

reset role;
select is(
  (select status::text from public.period_fixed_commitments where id = '94000000-0000-0000-0000-000000000003'),
  'skipped', 'status becomes skipped'
);
select is(
  (select total_planned_commitments from public.get_owner_period_planning_summary('92000000-0000-0000-0000-000000000002')),
  6000::numeric, 'skipped commitment is excluded from the planned commitment total'
);
select is(
  (select is_active from public.fixed_commitment_templates where id = '93000000-0000-0000-0000-000000000002'),
  true, 'the recurring template remains active after skipping one month'
);

-- === UNSKIP ===
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$select public.set_period_fixed_commitment_skipped('94000000-0000-0000-0000-000000000001', false)$$,
  'P0001', 'period_not_open', 'Unskip is rejected on a Draft period'
);
select lives_ok(
  $$select public.set_period_fixed_commitment_skipped('94000000-0000-0000-0000-000000000003', false)$$,
  'Unskip succeeds on an Open period'
);
select throws_ok(
  $$select public.set_period_fixed_commitment_skipped('94000000-0000-0000-0000-000000000004', false)$$,
  'P0001', 'period_not_open', 'Unskip is rejected on a Closed period'
);

reset role;
select is(
  (select status::text from public.period_fixed_commitments where id = '94000000-0000-0000-0000-000000000003'),
  'pending', 'status is restored to pending'
);
select is(
  (select total_planned_commitments from public.get_owner_period_planning_summary('92000000-0000-0000-0000-000000000002')),
  8000::numeric, 'the planned commitment total is restored once unskipped'
);

-- === PRIVACY: Member denied both RPCs regardless of period status ===
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000002', true);
select throws_ok(
  $$select public.mark_period_fixed_commitment_paid('94000000-0000-0000-0000-000000000003')$$,
  '42501', null, 'a Member cannot invoke Paid'
);
select throws_ok(
  $$select public.set_period_fixed_commitment_skipped('94000000-0000-0000-0000-000000000003', true)$$,
  '42501', null, 'a Member cannot invoke Skip'
);
reset role;

-- === FINANCIAL REGRESSION: fixed/variable separation ===
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', true);
select is(
  (select actual_fixed_commitment_outflow from public.get_owner_period_planning_summary('92000000-0000-0000-0000-000000000002')),
  6000::numeric, 'Paid fixed commitment is counted exactly once in the fixed actual outflow'
);
select is(
  (select actual_variable_spending_total from public.get_owner_period_planning_summary('92000000-0000-0000-0000-000000000002')),
  300::numeric, 'variable spending total is unaffected by the Paid fixed commitment'
);
select is(
  (select budget_remaining from public.get_owner_period_planning_summary('92000000-0000-0000-0000-000000000002')),
  5000 - 300::numeric, 'variable budget remaining is unaffected by the Paid fixed commitment'
);
select is(
  (select count(*)::integer from public.transactions where period_id = '92000000-0000-0000-0000-000000000002'),
  1, 'no variable transaction was created by any fixed-commitment mutation'
);
select is(
  (select planned_amount from public.period_section_budgets where id = '96000000-0000-0000-0000-000000000001'),
  1000::numeric, 'section allocation is unaffected by fixed-commitment mutations'
);
reset role;

select * from finish();
rollback;
