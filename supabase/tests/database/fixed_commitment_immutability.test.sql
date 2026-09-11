begin;

create extension if not exists pgtap with schema extensions;

select plan(20);

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('50000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'immutable-owner@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('50000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'immutable-other-owner@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now());

insert into public.households (id, name, owner_user_id, currency_code)
values
  ('51000000-0000-0000-0000-000000000001', 'ثبات النطاق', '50000000-0000-0000-0000-000000000001', 'EGP'),
  ('51000000-0000-0000-0000-000000000002', 'أسرة أخرى', '50000000-0000-0000-0000-000000000002', 'EGP');

insert into public.budget_periods (id, household_id, period_key, start_date, end_date, status, created_by)
values
  ('52000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', date '2026-09-01', date '2026-09-01', date '2026-09-30', 'draft', '50000000-0000-0000-0000-000000000001'),
  ('52000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000002', date '2026-09-01', date '2026-09-01', date '2026-09-30', 'draft', '50000000-0000-0000-0000-000000000002');

insert into public.fixed_commitment_templates (id, household_id, name, default_amount, created_by)
values
  ('53000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', 'إيجار', 10000, '50000000-0000-0000-0000-000000000001'),
  ('53000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000001', 'قسط', 3000, '50000000-0000-0000-0000-000000000001');

insert into public.period_fixed_commitments (id, period_id, fixed_commitment_template_id, name_snapshot, planned_amount, status, created_by)
values ('54000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000001', '53000000-0000-0000-0000-000000000001', 'إيجار', 10000, 'pending', '50000000-0000-0000-0000-000000000001');

-- period_fixed_commitments has no client UPDATE grant at all (its only approved write paths
-- are SECURITY DEFINER RPCs, which run with elevated table privileges and so are not blocked
-- by the missing grant). Exercising its trigger therefore requires bypassing the grant layer
-- the same way those RPCs do, rather than going through the authenticated role, which would
-- be rejected by "permission denied" before the trigger ever runs.
select throws_ok(
  $$update public.period_fixed_commitments set period_id = '52000000-0000-0000-0000-000000000002' where id = '54000000-0000-0000-0000-000000000001'$$,
  '23514', 'immutable_period_fixed_commitment_scope', 'a period fixed commitment snapshot cannot be moved to another period'
);
select throws_ok(
  $$update public.period_fixed_commitments set fixed_commitment_template_id = '53000000-0000-0000-0000-000000000002' where id = '54000000-0000-0000-0000-000000000001'$$,
  '23514', 'immutable_period_fixed_commitment_scope', 'a period fixed commitment snapshot cannot be relinked to a different template'
);
select throws_ok(
  $$update public.period_fixed_commitments set created_by = '50000000-0000-0000-0000-000000000002' where id = '54000000-0000-0000-0000-000000000001'$$,
  '23514', 'immutable_period_fixed_commitment_scope', 'a period fixed commitment snapshot''s created_by cannot be reassigned'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '50000000-0000-0000-0000-000000000001', true);

-- Scope columns are frozen, mirroring the sibling persistent/monthly-snapshot table pairs.
select throws_ok(
  $$update public.fixed_commitment_templates set household_id = '51000000-0000-0000-0000-000000000002' where id = '53000000-0000-0000-0000-000000000001'$$,
  '23514', 'immutable_fixed_commitment_template_scope', 'a fixed commitment template cannot be moved to another household'
);
select throws_ok(
  $$update public.fixed_commitment_templates set created_by = '50000000-0000-0000-0000-000000000002' where id = '53000000-0000-0000-0000-000000000001'$$,
  '23514', 'immutable_fixed_commitment_template_scope', 'a fixed commitment template''s created_by cannot be reassigned'
);

-- Setting a frozen column to its own current value is not a change and must not be blocked.
select lives_ok(
  $$update public.fixed_commitment_templates set household_id = household_id where id = '53000000-0000-0000-0000-000000000001'$$,
  'writing the same household_id value back is not a scope change'
);

-- Legitimate, already-approved mutations on fixed_commitment_templates remain unaffected.
select lives_ok(
  $$update public.fixed_commitment_templates set default_amount = 12500, name = 'إيجار جديد', due_day = 5, is_active = true where id = '53000000-0000-0000-0000-000000000001'$$,
  'owner can still update mutable template fields directly'
);
select is((select default_amount from public.fixed_commitment_templates where id = '53000000-0000-0000-0000-000000000001'), 12500::numeric, 'default_amount mutation took effect');
select is((select name from public.fixed_commitment_templates where id = '53000000-0000-0000-0000-000000000001'), 'إيجار جديد', 'name mutation took effect');

-- Legitimate, already-approved planning RPCs on period_fixed_commitments remain unaffected.
select lives_ok(
  $$select public.set_period_fixed_commitment_planned_amount('54000000-0000-0000-0000-000000000001', 11000)$$,
  'set_period_fixed_commitment_planned_amount still works after adding immutability coverage'
);
select is((select planned_amount from public.period_fixed_commitments where id = '54000000-0000-0000-0000-000000000001'), 11000::numeric, 'planned_amount mutation took effect');

-- Fixed-commitment operational mutations (Paid/Skip/Unskip) are Open-only as of this session's
-- hardening; the planning RPC above deliberately still ran while Draft. Open the period before
-- exercising the operational RPCs below so this file keeps testing immutability, not lifecycle.
select public.set_budget_period_status('52000000-0000-0000-0000-000000000001', 'open');

select lives_ok(
  $$select public.set_period_fixed_commitment_skipped('54000000-0000-0000-0000-000000000001', true, 'اختبار')$$,
  'set_period_fixed_commitment_skipped(true) still works after adding immutability coverage'
);
select is((select status from public.period_fixed_commitments where id = '54000000-0000-0000-0000-000000000001'), 'skipped'::public.monthly_item_status, 'skipped transition took effect');

select lives_ok(
  $$select public.set_period_fixed_commitment_skipped('54000000-0000-0000-0000-000000000001', false, null)$$,
  'set_period_fixed_commitment_skipped(false) still works after adding immutability coverage'
);
select is((select status from public.period_fixed_commitments where id = '54000000-0000-0000-0000-000000000001'), 'pending'::public.monthly_item_status, 'unskipped transition took effect');

select lives_ok(
  $$select public.mark_period_fixed_commitment_paid('54000000-0000-0000-0000-000000000001', 11000)$$,
  'mark_period_fixed_commitment_paid still works after adding immutability coverage'
);
select is((select status from public.period_fixed_commitments where id = '54000000-0000-0000-0000-000000000001'), 'paid'::public.monthly_item_status, 'paid transition took effect');
select is((select actual_amount from public.period_fixed_commitments where id = '54000000-0000-0000-0000-000000000001'), 11000::numeric, 'paid actual_amount took effect');

-- The atomic creation RPCs (which only INSERT, never UPDATE these tables) remain unaffected.
select lives_ok(
  $$select public.create_recurring_fixed_commitment('52000000-0000-0000-0000-000000000001', 'اشتراك جديد', 400)$$,
  'create_recurring_fixed_commitment still works after adding immutability coverage'
);
select lives_ok(
  $$select public.create_one_time_fixed_commitment('52000000-0000-0000-0000-000000000001', 'مرة واحدة', 250)$$,
  'create_one_time_fixed_commitment still works after adding immutability coverage'
);

reset role;

select * from finish();
rollback;
