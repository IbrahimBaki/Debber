begin;

create extension if not exists pgtap with schema extensions;

select plan(52);

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('40000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'setup-owner@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('40000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'setup-member@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('40000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'setup-other-owner@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now());

insert into public.households (id, name, owner_user_id, currency_code, period_start_day)
values
  ('41000000-0000-0000-0000-000000000001', 'إعداد مالي', '40000000-0000-0000-0000-000000000001', 'EGP', 1),
  ('41000000-0000-0000-0000-000000000002', 'منزل آخر', '40000000-0000-0000-0000-000000000003', 'EGP', 1);
insert into public.household_members (household_id, user_id, role, status)
values ('41000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000002', 'member', 'active');

insert into public.budget_periods (id, household_id, period_key, start_date, end_date, status, created_by)
values
  ('42000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000001', date '2026-09-01', date '2026-09-01', date '2026-09-30', 'draft', '40000000-0000-0000-0000-000000000001'),
  ('42000000-0000-0000-0000-000000000002', '41000000-0000-0000-0000-000000000001', date '2026-10-01', date '2026-10-01', date '2026-10-31', 'open', '40000000-0000-0000-0000-000000000001'),
  ('42000000-0000-0000-0000-000000000003', '41000000-0000-0000-0000-000000000001', date '2026-11-01', date '2026-11-01', date '2026-11-30', 'closed', '40000000-0000-0000-0000-000000000001'),
  ('42000000-0000-0000-0000-000000000004', '41000000-0000-0000-0000-000000000002', date '2026-09-01', date '2026-09-01', date '2026-09-30', 'draft', '40000000-0000-0000-0000-000000000003');

-- Function execution grants: anon must never be able to call these.
select ok(not has_function_privilege('anon','public.create_recurring_fixed_commitment(uuid,text,numeric,smallint,uuid)','execute'), 'anon cannot execute create_recurring_fixed_commitment');
select ok(not has_function_privilege('anon','public.create_one_time_fixed_commitment(uuid,text,numeric,date,uuid)','execute'), 'anon cannot execute create_one_time_fixed_commitment');
select ok(not has_function_privilege('anon','public.create_flexible_budget_section(uuid,text,visibility_scope,section_member_access,uuid)','execute'), 'anon cannot execute create_flexible_budget_section');

-- Table-level write surface must remain closed; the RPC is the only write path.
select ok(not has_table_privilege('authenticated','public.period_fixed_commitments','insert'), 'authenticated clients cannot directly insert period fixed commitments');
select ok(not has_table_privilege('authenticated','public.period_section_budgets','insert'), 'authenticated clients cannot directly insert period section budget snapshots');

-- === Recurring fixed commitment ===

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000001', true);

select public.create_recurring_fixed_commitment(
  '42000000-0000-0000-0000-000000000001', 'إيجار', 12000, 5::smallint, '43000000-0000-0000-0000-000000000001'
) as recurring_commitment_id \gset

select is((select count(*)::integer from public.fixed_commitment_templates where id='43000000-0000-0000-0000-000000000001'), 1, 'recurring creation makes exactly one template');
select is((select count(*)::integer from public.period_fixed_commitments where fixed_commitment_template_id='43000000-0000-0000-0000-000000000001'), 1, 'recurring creation makes exactly one current-period snapshot');
select is((select planned_amount from public.period_fixed_commitments where id=:'recurring_commitment_id'), 12000::numeric, 'current snapshot has the correct planned amount');
select is((select fixed_commitment_template_id from public.period_fixed_commitments where id=:'recurring_commitment_id'), '43000000-0000-0000-0000-000000000001'::uuid, 'current snapshot links to the created template');
select is((select status from public.period_fixed_commitments where id=:'recurring_commitment_id'), 'pending'::public.monthly_item_status, 'current snapshot is not paid automatically');

-- Retry with the same caller-supplied template id must not duplicate template or snapshot.
select public.create_recurring_fixed_commitment(
  '42000000-0000-0000-0000-000000000001', 'إيجار', 12000, 5::smallint, '43000000-0000-0000-0000-000000000001'
) as recurring_retry_id \gset
select is(:'recurring_retry_id'::uuid, :'recurring_commitment_id'::uuid, 'retry of the same logical operation returns the same snapshot id');
select is((select count(*)::integer from public.fixed_commitment_templates where id='43000000-0000-0000-0000-000000000001'), 1, 'retry does not duplicate the template');
select is((select count(*)::integer from public.period_fixed_commitments where fixed_commitment_template_id='43000000-0000-0000-0000-000000000001'), 1, 'retry does not duplicate the current-period snapshot');
select is((select count(*)::integer from public.audit_events where entity_id=:'recurring_commitment_id' and event_type='fixed_commitment.created'), 1, 'retry does not duplicate the audit event');

-- ensure_budget_period() must not create a duplicate current snapshot after this operation.
-- Uses the real wall-clock current period (rather than the fixed test period ids) so this
-- assertion genuinely exercises the interaction instead of depending on "today" happening to
-- fall inside period 001's date range.
select public.ensure_budget_period('41000000-0000-0000-0000-000000000001') as live_period_id \gset
select public.create_recurring_fixed_commitment(:'live_period_id', 'اختبار الفترة الحية', 777, null, '43900000-0000-0000-0000-000000000001');
select public.ensure_budget_period('41000000-0000-0000-0000-000000000001');
select is((select count(*)::integer from public.period_fixed_commitments where period_id=:'live_period_id' and fixed_commitment_template_id='43900000-0000-0000-0000-000000000001'), 1, 'ensure_budget_period does not duplicate the current snapshot for an already-created template (live period)');

-- Future period generation continues to inherit the recurring template.
select public.ensure_budget_period('41000000-0000-0000-0000-000000000001');
reset role;
insert into public.budget_periods (id, household_id, period_key, start_date, end_date, status, created_by)
values ('42000000-0000-0000-0000-000000000005', '41000000-0000-0000-0000-000000000001', date '2026-12-01', date '2026-12-01', date '2026-12-31', 'draft', '40000000-0000-0000-0000-000000000001');
insert into public.period_fixed_commitments (period_id, fixed_commitment_template_id, name_snapshot, planned_amount, status, created_by)
select '42000000-0000-0000-0000-000000000005', fct.id, fct.name, fct.default_amount, 'pending', '40000000-0000-0000-0000-000000000001'
from public.fixed_commitment_templates fct
where fct.id = '43000000-0000-0000-0000-000000000001'
on conflict (period_id, fixed_commitment_template_id) where fixed_commitment_template_id is not null do nothing;
select is((select count(*)::integer from public.period_fixed_commitments where period_id='42000000-0000-0000-0000-000000000005' and fixed_commitment_template_id='43000000-0000-0000-0000-000000000001'), 1, 'future period generation continues to inherit the recurring template');

-- Historical current snapshot remains unchanged if the template changes later.
update public.fixed_commitment_templates set default_amount = 99999 where id = '43000000-0000-0000-0000-000000000001';
select is((select planned_amount from public.period_fixed_commitments where id=:'recurring_commitment_id'), 12000::numeric, 'changing the template later does not rewrite the historical current-month snapshot');

-- === One-time (this-month-only) fixed commitment ===

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000001', true);

select public.create_one_time_fixed_commitment(
  '42000000-0000-0000-0000-000000000001', 'صيانة السيارة', 3000, null, '44000000-0000-0000-0000-000000000001'
) as one_time_commitment_id \gset

select is((select count(*)::integer from public.period_fixed_commitments where id=:'one_time_commitment_id'), 1, 'one-time creation makes exactly one current-period snapshot');
select is((select fixed_commitment_template_id from public.period_fixed_commitments where id=:'one_time_commitment_id'), null, 'one-time creation creates zero recurring templates');
select is((select count(*)::integer from public.fixed_commitment_templates where name='صيانة السيارة'), 0, 'one-time creation never creates a fixed_commitment_templates row');

-- Retry with the same caller-supplied commitment id must not duplicate.
select public.create_one_time_fixed_commitment(
  '42000000-0000-0000-0000-000000000001', 'صيانة السيارة', 3000, null, '44000000-0000-0000-0000-000000000001'
) as one_time_retry_id \gset
select is(:'one_time_retry_id'::uuid, :'one_time_commitment_id'::uuid, 'retry of the one-time creation returns the same snapshot id');
select is((select count(*)::integer from public.period_fixed_commitments where id=:'one_time_commitment_id'), 1, 'retry does not duplicate the one-time snapshot');
select is((select count(*)::integer from public.audit_events where entity_id=:'one_time_commitment_id' and event_type='fixed_commitment.created'), 1, 'retry does not duplicate the one-time audit event');

-- Future period generation does not inherit a this-month-only commitment.
select public.ensure_budget_period('41000000-0000-0000-0000-000000000001');
reset role;
select is((select count(*)::integer from public.period_fixed_commitments where period_id='42000000-0000-0000-0000-000000000005' and name_snapshot='صيانة السيارة'), 0, 'future period generation does not inherit a this-month-only commitment');

-- Draft/Open/Closed lifecycle for one-time creation.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000001', true);
select lives_ok($$select public.create_one_time_fixed_commitment('42000000-0000-0000-0000-000000000001', 'اختبار مسودة', 100)$$, 'owner can create a one-time commitment in Draft');
select lives_ok($$select public.create_one_time_fixed_commitment('42000000-0000-0000-0000-000000000002', 'اختبار مفتوح', 100)$$, 'owner can create a one-time commitment in Open');
select throws_ok($$select public.create_one_time_fixed_commitment('42000000-0000-0000-0000-000000000003', 'اختبار مغلق', 100)$$, '42501', 'not_authorized', 'Closed period rejects one-time commitment creation');
reset role;

-- Draft/Open/Closed lifecycle for recurring creation.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000001', true);
select lives_ok($$select public.create_recurring_fixed_commitment('42000000-0000-0000-0000-000000000002', 'اشتراك', 200)$$, 'owner can create a recurring commitment in Open');
select throws_ok($$select public.create_recurring_fixed_commitment('42000000-0000-0000-0000-000000000003', 'اشتراك مغلق', 200)$$, '42501', 'not_authorized', 'Closed period rejects recurring commitment creation');
reset role;

-- Member and anon rejection.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000002', true);
select throws_ok($$select public.create_recurring_fixed_commitment('42000000-0000-0000-0000-000000000001', 'محاولة عضو', 100)$$, '42501', 'not_authorized', 'member cannot create a recurring commitment');
select throws_ok($$select public.create_one_time_fixed_commitment('42000000-0000-0000-0000-000000000001', 'محاولة عضو', 100)$$, '42501', 'not_authorized', 'member cannot create a one-time commitment');
reset role;

set local role anon;
select throws_ok($$select public.create_recurring_fixed_commitment('42000000-0000-0000-0000-000000000001', 'محاولة مجهول', 100)$$, '42501', null, 'anonymous callers cannot create a recurring commitment');
select throws_ok($$select public.create_one_time_fixed_commitment('42000000-0000-0000-0000-000000000001', 'محاولة مجهول', 100)$$, '42501', null, 'anonymous callers cannot create a one-time commitment');
reset role;

-- Cross-household identity attack: Owner A cannot mutate household B's period, and cannot
-- reuse a template/commitment id that already belongs to household B.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000003', true);
select public.create_recurring_fixed_commitment(
  '42000000-0000-0000-0000-000000000004', 'التزام آخر', 500, null, '45000000-0000-0000-0000-000000000001'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000001', true);
select throws_ok($$select public.create_recurring_fixed_commitment('42000000-0000-0000-0000-000000000001', 'اختطاف', 100, null, '45000000-0000-0000-0000-000000000001')$$, '23505', 'template_id_conflict', 'caller cannot attach a recurring commitment to a template id owned by another household');
select throws_ok($$select public.create_recurring_fixed_commitment('42000000-0000-0000-0000-000000000004', 'محاولة عبر الأسرة', 100)$$, '42501', 'not_authorized', 'caller cannot mutate another household''s period merely by supplying its id');
reset role;

-- === Flexible section ===

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000001', true);

select public.create_flexible_budget_section(
  '42000000-0000-0000-0000-000000000001', 'ترفيه', 'household', 'contribute', '46000000-0000-0000-0000-000000000001'
) as section_snapshot_id \gset

select is((select count(*)::integer from public.budget_sections where id='46000000-0000-0000-0000-000000000001'), 1, 'section creation makes exactly one reusable budget_sections record');
select is((select count(*)::integer from public.period_section_budgets where section_id='46000000-0000-0000-0000-000000000001' and period_id='42000000-0000-0000-0000-000000000001'), 1, 'section creation makes exactly one current-period snapshot');
select is((select planned_amount from public.period_section_budgets where id=:'section_snapshot_id'), 0::numeric, 'current period planned allocation starts at zero');
select is((select default_planned_amount from public.budget_sections where id='46000000-0000-0000-0000-000000000001'), 0::numeric, 'default_planned_amount is not silently populated by this operation');

-- Update the reusable section's default after creation; the current snapshot must not be rewritten.
update public.budget_sections set default_planned_amount = 9000 where id = '46000000-0000-0000-0000-000000000001';
select is((select planned_amount from public.period_section_budgets where id=:'section_snapshot_id'), 0::numeric, 'default_planned_amount is never automatically copied into the current monthly allocation');

-- Retry with the same caller-supplied section id must not duplicate.
select public.create_flexible_budget_section(
  '42000000-0000-0000-0000-000000000001', 'ترفيه', 'household', 'contribute', '46000000-0000-0000-0000-000000000001'
) as section_retry_id \gset
select is(:'section_retry_id'::uuid, :'section_snapshot_id'::uuid, 'retry of the section creation returns the same snapshot id');
select is((select count(*)::integer from public.budget_sections where id='46000000-0000-0000-0000-000000000001'), 1, 'retry does not duplicate the reusable section');
select is((select count(*)::integer from public.period_section_budgets where section_id='46000000-0000-0000-0000-000000000001'), 1, 'retry does not duplicate the current-period snapshot');
select is((select count(*)::integer from public.audit_events where entity_id='46000000-0000-0000-0000-000000000001' and event_type='budget_section.created'), 1, 'retry does not duplicate the section creation audit event');

-- Future period behavior: new periods still start section allocations at zero, mirroring the
-- exact zero-amount snapshot generation ensure_budget_period() performs for active sections
-- (deterministic manual insert here, since ensure_budget_period() targets the real wall-clock
-- current period rather than the fixed test period ids used in this file).
reset role;
insert into public.period_section_budgets (period_id, section_id, section_name_snapshot, section_kind_snapshot, planned_amount)
select '42000000-0000-0000-0000-000000000005', s.id, s.name, s.kind, 0
from public.budget_sections s
where s.id = '46000000-0000-0000-0000-000000000001' and s.is_active = true and s.archived_at is null
on conflict (period_id, section_id) do nothing;
select is((select planned_amount from public.period_section_budgets where section_id='46000000-0000-0000-0000-000000000001' and period_id='42000000-0000-0000-0000-000000000005'), 0::numeric, 'future period allocations for the new section still begin at zero, even though default_planned_amount was raised to 9000');

-- Draft/Open/Closed lifecycle for section creation.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000001', true);
select lives_ok($$select public.create_flexible_budget_section('42000000-0000-0000-0000-000000000001', 'قسم مسودة')$$, 'owner can create a section in Draft');
select lives_ok($$select public.create_flexible_budget_section('42000000-0000-0000-0000-000000000002', 'قسم مفتوح')$$, 'owner can create a section in Open');
select throws_ok($$select public.create_flexible_budget_section('42000000-0000-0000-0000-000000000003', 'قسم مغلق')$$, '42501', 'not_authorized', 'Closed period rejects section creation');
reset role;

-- Member and anon rejection for section creation.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000002', true);
select throws_ok($$select public.create_flexible_budget_section('42000000-0000-0000-0000-000000000001', 'محاولة عضو')$$, '42501', 'not_authorized', 'member cannot create a flexible section');
reset role;

set local role anon;
select throws_ok($$select public.create_flexible_budget_section('42000000-0000-0000-0000-000000000001', 'محاولة مجهول')$$, '42501', null, 'anonymous callers cannot create a flexible section');
reset role;

-- Cross-household id attack for sections.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000003', true);
select public.create_flexible_budget_section(
  '42000000-0000-0000-0000-000000000004', 'قسم أسرة أخرى', 'owner_only', 'view', '47000000-0000-0000-0000-000000000001'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000001', true);
select throws_ok($$select public.create_flexible_budget_section('42000000-0000-0000-0000-000000000001', 'اختطاف قسم', 'owner_only', 'view', '47000000-0000-0000-0000-000000000001')$$, '23505', 'section_id_conflict', 'caller cannot attach a section snapshot to a section id owned by another household');
reset role;

-- Prior financial-invariant behavior must still hold after this migration.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000001', true);
select is((select spending_budget from public.budget_periods where id='42000000-0000-0000-0000-000000000001'), 0::numeric, 'new periods still start with a zero owner-defined spending budget');
reset role;

select * from finish();
rollback;
