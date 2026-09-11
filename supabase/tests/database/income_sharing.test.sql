begin;

create extension if not exists pgtap with schema extensions;

select plan(20);

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('70000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'income-owner@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('70000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'income-member@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('70000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'income-other-owner@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now());

insert into public.households (id, name, owner_user_id, currency_code, timezone)
values
  ('71000000-0000-0000-0000-000000000001', 'أسرة الدخل', '70000000-0000-0000-0000-000000000001', 'EGP', 'UTC'),
  ('71000000-0000-0000-0000-000000000002', 'أسرة أخرى للدخل', '70000000-0000-0000-0000-000000000003', 'EGP', 'UTC');

insert into public.household_members (household_id, user_id, role, status)
values ('71000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000002', 'member', 'active');

-- DEFAULT: a newly created household defaults sharing to off.
select is((select share_total_income_with_members from public.households where id = '71000000-0000-0000-0000-000000000001'), false, 'new household defaults share_total_income_with_members to false');

insert into public.budget_periods (id, household_id, period_key, start_date, end_date, status, created_by)
values
  ('72000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001', date '2020-01-01', date '2020-01-01', date '2020-01-31', 'open', '70000000-0000-0000-0000-000000000001'),
  ('72000000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000001', date '2020-02-01', date '2020-02-01', date '2020-02-29', 'open', '70000000-0000-0000-0000-000000000001'),
  ('72000000-0000-0000-0000-000000000003', '71000000-0000-0000-0000-000000000002', date '2020-01-01', date '2020-01-01', date '2020-01-31', 'open', '70000000-0000-0000-0000-000000000003');

insert into public.period_income_items (id, period_id, name_snapshot, planned_amount, created_by)
values
  ('73000000-0000-0000-0000-000000000001', '72000000-0000-0000-0000-000000000001', 'راتب', 10000, '70000000-0000-0000-0000-000000000001'),
  ('73000000-0000-0000-0000-000000000002', '72000000-0000-0000-0000-000000000001', 'عمل إضافي', 2500, '70000000-0000-0000-0000-000000000001');
-- period ...002 (household 1) intentionally has zero income items.

-- === OWNER SETTING: owner can toggle both directions; member cannot; anon cannot. ===
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000001', true);

update public.households set share_total_income_with_members = true where id = '71000000-0000-0000-0000-000000000001';
select is((select share_total_income_with_members from public.households where id = '71000000-0000-0000-0000-000000000001'), true, 'owner can turn sharing on via the existing household UPDATE policy');

update public.households set share_total_income_with_members = false where id = '71000000-0000-0000-0000-000000000001';
select is((select share_total_income_with_members from public.households where id = '71000000-0000-0000-0000-000000000001'), false, 'owner can turn sharing back off');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000002', true);
update public.households set share_total_income_with_members = true where id = '71000000-0000-0000-0000-000000000001';
select is((select share_total_income_with_members from public.households where id = '71000000-0000-0000-0000-000000000001'), false, 'a member cannot toggle the sharing flag (RLS silently affects zero rows)');
reset role;

set local role anon;
select throws_ok($$update public.households set share_total_income_with_members = true where id = '71000000-0000-0000-0000-000000000001'$$, '42501', null, 'anon cannot update households at all');
reset role;

-- Grants: anon must never execute the RPC.
select ok(not has_function_privilege('anon','public.get_member_visible_total_income(uuid)','execute'), 'anon cannot execute get_member_visible_total_income');

set local role anon;
select throws_ok($$select public.get_member_visible_total_income('72000000-0000-0000-0000-000000000001')$$, '42501', null, 'anonymous callers cannot call get_member_visible_total_income');
reset role;

-- === RPC SHARING OFF (household 1's flag is currently false) ===
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000001', true);
select is(public.get_member_visible_total_income('72000000-0000-0000-0000-000000000001'), 12500::numeric, 'owner always gets the real total, sharing off');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000002', true);
select is(public.get_member_visible_total_income('72000000-0000-0000-0000-000000000001'), null, 'member gets NULL when sharing is off, not zero');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000003', true);
select throws_ok($$select public.get_member_visible_total_income('72000000-0000-0000-0000-000000000001')$$, '42501', null, 'a non-member is rejected with not_authorized, not NULL');
reset role;

-- === ROW PRIVACY: even with sharing about to be turned on, direct row access stays zero for a member. ===
-- Turn sharing on for household 1 first (as owner) so the following checks are meaningful.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000001', true);
update public.households set share_total_income_with_members = true where id = '71000000-0000-0000-0000-000000000001';
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000002', true);
select is((select count(*)::integer from public.period_income_items where period_id = '72000000-0000-0000-0000-000000000001'), 0, 'member direct SELECT on period_income_items returns zero rows even with sharing ON');
select is((select count(*)::integer from public.income_sources where household_id = '71000000-0000-0000-0000-000000000001'), 0, 'member direct SELECT on income_sources returns zero rows even with sharing ON');
reset role;

-- === RPC SHARING ON ===
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000002', true);
select is(public.get_member_visible_total_income('72000000-0000-0000-0000-000000000001'), 12500::numeric, 'member gets the correct aggregate SUM once sharing is on');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000001', true);
select is(public.get_member_visible_total_income('72000000-0000-0000-0000-000000000001'), 12500::numeric, 'owner sees the same total as the member for the same period');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000002', true);
select is(public.get_member_visible_total_income('72000000-0000-0000-0000-000000000002'), 0::numeric, 'a zero-income period returns 0 (shared and currently zero), not NULL, for an authorized member');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000001', true);
select is(public.get_member_visible_total_income('72000000-0000-0000-0000-000000000002'), 0::numeric, 'owner also gets 0 (not NULL) for the zero-income period');
reset role;

-- === CROSS-HOUSEHOLD: a member of household 1 querying household 2's period must get not_authorized, never NULL. ===
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000002', true);
select throws_ok($$select public.get_member_visible_total_income('72000000-0000-0000-0000-000000000003')$$, '42501', null, 'a member of another household gets not_authorized for a foreign period, never NULL');
reset role;

-- Unknown/bogus period id.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000001', true);
select throws_ok($$select public.get_member_visible_total_income('00000000-0000-0000-0000-000000000000')$$, 'P0002', null, 'a nonexistent period id is rejected as period_not_found');
reset role;

-- === FIXED COMMITMENT REGRESSION: fixed commitments remain Owner-only, unaffected by income sharing. ===
insert into public.fixed_commitment_templates (id, household_id, name, default_amount, created_by)
values ('74000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001', 'إيجار', 1000, '70000000-0000-0000-0000-000000000001');
insert into public.period_fixed_commitments (id, period_id, fixed_commitment_template_id, name_snapshot, planned_amount, status, created_by)
values ('75000000-0000-0000-0000-000000000001', '72000000-0000-0000-0000-000000000001', '74000000-0000-0000-0000-000000000001', 'إيجار', 1000, 'pending', '70000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000002', true);
select is((select count(*)::integer from public.period_fixed_commitments where period_id = '72000000-0000-0000-0000-000000000001'), 0, 'a member still cannot see fixed commitments, sharing ON has no effect on that boundary');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000001', true);
select is((select count(*)::integer from public.period_fixed_commitments where period_id = '72000000-0000-0000-0000-000000000001'), 1, 'the owner still sees the fixed commitment unchanged');
reset role;

select * from finish();
rollback;
