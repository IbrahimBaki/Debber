begin;

create extension if not exists pgtap with schema extensions;

select plan(30);

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('30000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'financial-owner@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('30000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'financial-member@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now());

insert into public.households (id, name, owner_user_id, currency_code)
values ('31000000-0000-0000-0000-000000000001', 'خطة مالية', '30000000-0000-0000-0000-000000000001', 'EGP');
insert into public.household_members (household_id, user_id, role, status)
values ('31000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000002', 'member', 'active');
insert into public.budget_periods (id, household_id, period_key, start_date, end_date, status, created_by)
values ('32000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', date '2026-09-01', date '2026-09-01', date '2026-09-30', 'draft', '30000000-0000-0000-0000-000000000001');
insert into public.budget_sections (id, household_id, name, kind, default_planned_amount, visibility_scope, member_access, created_by)
values
  ('33000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', 'البيت', 'flexible', 9000, 'household', 'contribute', '30000000-0000-0000-0000-000000000001'),
  ('33000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000001', 'تنقل', 'flexible', 2000, 'household', 'contribute', '30000000-0000-0000-0000-000000000001');
insert into public.period_section_budgets (id, period_id, section_id, section_name_snapshot, section_kind_snapshot, planned_amount)
values
  ('34000000-0000-0000-0000-000000000001', '32000000-0000-0000-0000-000000000001', '33000000-0000-0000-0000-000000000001', 'البيت', 'flexible', 0),
  ('34000000-0000-0000-0000-000000000002', '32000000-0000-0000-0000-000000000001', '33000000-0000-0000-0000-000000000002', 'تنقل', 'flexible', 0);
insert into public.period_income_items (period_id, name_snapshot, planned_amount, created_by)
values
  ('32000000-0000-0000-0000-000000000001', 'راتب', 20000, '30000000-0000-0000-0000-000000000001'),
  ('32000000-0000-0000-0000-000000000001', 'دخل إضافي', 5000, '30000000-0000-0000-0000-000000000001');
insert into public.period_fixed_commitments (id, period_id, name_snapshot, planned_amount, created_by)
values ('35000000-0000-0000-0000-000000000001', '32000000-0000-0000-0000-000000000001', 'إيجار', 10000, '30000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-000000000001', true);
reset role;
insert into public.households (id, name, owner_user_id, currency_code)
values ('31100000-0000-0000-0000-000000000001', 'صفر البداية', '30000000-0000-0000-0000-000000000001', 'EGP');
insert into public.budget_sections (id, household_id, name, kind, default_planned_amount, created_by)
values ('33100000-0000-0000-0000-000000000001', '31100000-0000-0000-0000-000000000001', 'اقتراح فقط', 'flexible', 1234, '30000000-0000-0000-0000-000000000001');
insert into public.fixed_commitment_templates (id, household_id, name, default_amount, created_by)
values ('35100000-0000-0000-0000-000000000001', '31100000-0000-0000-0000-000000000001', 'التزام مستقل', 500, '30000000-0000-0000-0000-000000000001');
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-000000000001', true);
select public.ensure_budget_period('31100000-0000-0000-0000-000000000001') as zero_start_period_id \gset
select is((select spending_budget from public.budget_periods where id=:'zero_start_period_id'), 0::numeric, 'ensure_budget_period starts spending budget at zero');
select is((select planned_amount from public.period_section_budgets where period_id=:'zero_start_period_id' and section_id='33100000-0000-0000-0000-000000000001'), 0::numeric, 'section defaults are not automatically applied to monthly allocations');
select is((select planned_amount from public.period_fixed_commitments where period_id=:'zero_start_period_id' and fixed_commitment_template_id='35100000-0000-0000-0000-000000000001'), 500::numeric, 'fixed commitment templates independently generate monthly commitment snapshots');
update public.fixed_commitment_templates set default_amount=999 where id='35100000-0000-0000-0000-000000000001';
update public.budget_sections set default_planned_amount=9999 where id='33100000-0000-0000-0000-000000000001';
select is((select planned_amount from public.period_fixed_commitments where period_id=:'zero_start_period_id' and fixed_commitment_template_id='35100000-0000-0000-0000-000000000001'), 500::numeric, 'changing a fixed template never rewrites an existing monthly snapshot');
select is((select planned_amount from public.period_section_budgets where period_id=:'zero_start_period_id' and section_id='33100000-0000-0000-0000-000000000001'), 0::numeric, 'changing a section default never rewrites an existing monthly allocation snapshot');
select is((select spending_budget from public.budget_periods where id='32000000-0000-0000-0000-000000000001'), 0::numeric, 'a new period starts with zero owner-defined spending budget');
select public.set_period_spending_budget('32000000-0000-0000-0000-000000000001', 12000);
select public.set_period_section_allocation('34000000-0000-0000-0000-000000000001', 6000);
select public.set_period_section_allocation('34000000-0000-0000-0000-000000000002', 2000);

select is((select total_planned_income from public.get_owner_period_planning_summary('32000000-0000-0000-0000-000000000001')), 25000::numeric, 'multiple planned income sources are summed');
select is((select total_planned_commitments from public.get_owner_period_planning_summary('32000000-0000-0000-0000-000000000001')), 10000::numeric, 'planned fixed commitments are separate and summed');
select is((select available_after_commitments from public.get_owner_period_planning_summary('32000000-0000-0000-0000-000000000001')), 15000::numeric, 'available after commitments is derived canonically');
select is((select unallocated_income from public.get_owner_period_planning_summary('32000000-0000-0000-0000-000000000001')), 3000::numeric, 'owner-defined budget can leave unallocated income');
select is((select total_section_allocations from public.get_owner_period_planning_summary('32000000-0000-0000-0000-000000000001')), 8000::numeric, 'partial flexible allocation is valid');
select is((select unallocated_spending_budget from public.get_owner_period_planning_summary('32000000-0000-0000-0000-000000000001')), 4000::numeric, 'unallocated spending budget is derived');
select throws_ok($$select public.set_period_section_allocation('34000000-0000-0000-0000-000000000002', 7000)$$, '23514', 'section_allocations_exceed_spending_budget', 'section allocations cannot exceed spending budget');
select throws_ok($$select public.set_period_spending_budget('32000000-0000-0000-0000-000000000001', 7000)$$, '23514', 'section_allocations_exceed_spending_budget', 'reducing budget below existing allocations is rejected atomically');
select lives_ok($$select public.set_period_spending_budget('32000000-0000-0000-0000-000000000001', 14000)$$, 'a planned deficit remains valid');
select is((select planned_deficit from public.get_owner_period_planning_summary('32000000-0000-0000-0000-000000000001')), 0::numeric, 'larger budget removes prior positive plan balance');
update public.period_income_items set planned_amount = 0 where period_id='32000000-0000-0000-0000-000000000001';
update public.period_income_items set planned_amount = 20000 where name_snapshot='راتب';
select public.set_period_fixed_commitment_planned_amount('35000000-0000-0000-0000-000000000001', 8000);
select is((select planned_deficit from public.get_owner_period_planning_summary('32000000-0000-0000-0000-000000000001')), 2000::numeric, 'planned deficit is represented and not rejected');
select public.set_period_fixed_commitment_skipped('35000000-0000-0000-0000-000000000001', true, 'اختبار');
select is((select total_planned_commitments from public.get_owner_period_planning_summary('32000000-0000-0000-0000-000000000001')), 0::numeric, 'skipped fixed commitment is excluded from this month planning total');
select public.set_period_fixed_commitment_skipped('35000000-0000-0000-0000-000000000001', false, null);
select public.set_period_spending_budget('32000000-0000-0000-0000-000000000001', 10000);

insert into public.transactions (period_id, period_section_budget_id, amount, created_by)
values
 ('32000000-0000-0000-0000-000000000001','34000000-0000-0000-0000-000000000001',3500,'30000000-0000-0000-0000-000000000001'),
 ('32000000-0000-0000-0000-000000000001','34000000-0000-0000-0000-000000000002',7700,'30000000-0000-0000-0000-000000000001');
select is((select actual_variable_spending_total from public.get_owner_period_planning_summary('32000000-0000-0000-0000-000000000001')), 11200::numeric, 'actual variable spending may exceed the budget');
select is((select budget_remaining from public.get_owner_period_planning_summary('32000000-0000-0000-0000-000000000001')), -1200::numeric, 'negative budget remaining is meaningful');
select is((select planned_amount - coalesce((select sum(t.amount) from public.transactions t where t.period_section_budget_id='34000000-0000-0000-0000-000000000001' and t.state='posted'),0) from public.period_section_budgets where id='34000000-0000-0000-0000-000000000001'), 2500::numeric, 'section remaining is derived without a spending cap');

select public.mark_period_fixed_commitment_paid('35000000-0000-0000-0000-000000000001', 5000);
select is((select actual_fixed_commitment_outflow from public.get_owner_period_planning_summary('32000000-0000-0000-0000-000000000001')), 5000::numeric, 'paid fixed commitment contributes one fixed actual outflow');
select is((select actual_variable_spending_total from public.get_owner_period_planning_summary('32000000-0000-0000-0000-000000000001')), 11200::numeric, 'paid fixed commitment does not increase variable spending');
select public.mark_period_fixed_commitment_paid('35000000-0000-0000-0000-000000000001', 5000);
select is((select count(*)::integer from public.audit_events where entity_id='35000000-0000-0000-0000-000000000001' and event_type='fixed_commitment.paid'), 1, 'repeating paid transition does not double count or duplicate audit');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-000000000002', true);
select throws_ok($$select * from public.get_owner_period_planning_summary('32000000-0000-0000-0000-000000000001')$$, '42501', 'not_authorized', 'member cannot obtain private derived planning totals');
select is((select count(*)::integer from public.period_fixed_commitments), 0, 'member cannot read private fixed commitment snapshots');
select throws_ok($$select public.set_period_spending_budget('32000000-0000-0000-0000-000000000001', 1)$$, '42501', 'not_authorized', 'member cannot modify owner planning');
reset role;

select is((select spending_budget from public.budget_periods where id='32000000-0000-0000-0000-000000000001'), 10000::numeric, 'authorized later budget change remains the only persisted change');
select ok(not has_table_privilege('authenticated','public.period_section_budgets','update'), 'direct section allocation updates are not granted to browser clients');
select ok(not has_function_privilege('anon','public.get_owner_period_planning_summary(uuid)','execute'), 'anonymous callers cannot execute owner planning summary');

select * from finish();
rollback;
