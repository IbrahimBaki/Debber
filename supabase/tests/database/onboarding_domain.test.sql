begin;

create extension if not exists pgtap with schema extensions;

select plan(43);

-- Test identities are inserted as the database owner. The product profile trigger creates profiles.
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'inviter@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'invitee@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'other@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'owner@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'sar@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000006', 'authenticated', 'authenticated', 'usd@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000007', 'authenticated', 'authenticated', 'eur@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000008', 'authenticated', 'authenticated', 'invalid@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000009', 'authenticated', 'authenticated', 'period@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000010', 'authenticated', 'authenticated', 'must-resolve@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now());

insert into public.households (id, name, owner_user_id, currency_code)
values
  ('10000000-0000-0000-0000-000000000001', 'دعوة أولى', '00000000-0000-0000-0000-000000000001', 'EGP'),
  ('10000000-0000-0000-0000-000000000002', 'دعوة ثانية', '00000000-0000-0000-0000-000000000001', 'EGP'),
  ('10000000-0000-0000-0000-000000000003', 'فترة', '00000000-0000-0000-0000-000000000009', 'EGP');

insert into public.household_invitations (id, household_id, email, token_hash, status, invited_by, expires_at, created_at)
values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'invitee@example.test', 'token-valid-one', 'pending', '00000000-0000-0000-0000-000000000001', now() + interval '1 day', now() - interval '2 hours'),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'invitee@example.test', 'token-valid-two', 'pending', '00000000-0000-0000-0000-000000000001', now() + interval '2 days', now() - interval '1 hour'),
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'invitee@example.test', 'token-expired', 'pending', '00000000-0000-0000-0000-000000000001', now() - interval '1 day', now()),
  ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', 'invitee@example.test', 'token-revoked', 'revoked', '00000000-0000-0000-0000-000000000001', now() + interval '1 day', now()),
  ('20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000001', 'invitee@example.test', 'token-accepted', 'accepted', '00000000-0000-0000-0000-000000000001', now() + interval '1 day', now()),
  ('20000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000002', 'must-resolve@example.test', 'token-must-resolve', 'pending', '00000000-0000-0000-0000-000000000001', now() + interval '1 day', now());

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);

select is(
  (select count(*)::integer from public.list_my_pending_household_invitations()),
  2,
  'invitee sees each valid pending invitation addressed to their authoritative email'
);
select is(
  (select household_name from public.list_my_pending_household_invitations() order by created_at limit 1),
  'دعوة أولى',
  'invitation discovery returns safe household display context'
);
select ok(
  not (select to_jsonb(i) ? 'token_hash' from public.list_my_pending_household_invitations() i limit 1),
  'invitation discovery never exposes token_hash'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select is(
  (select count(*)::integer from public.list_my_pending_household_invitations()),
  0,
  'unrelated user cannot discover another users invitations'
);
select throws_ok(
  $$select public.accept_household_invitation_by_id('20000000-0000-0000-0000-000000000001')$$,
  '42501',
  'invitation_email_mismatch',
  'unrelated user cannot accept an invitation by guessing its UUID'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select is(
  public.accept_household_invitation_by_id('20000000-0000-0000-0000-000000000001'),
  '10000000-0000-0000-0000-000000000001'::uuid,
  'correct invitee can atomically accept by invitation ID'
);

reset role;
select is(
  (select role::text from public.household_members where household_id = '10000000-0000-0000-0000-000000000001' and user_id = '00000000-0000-0000-0000-000000000002'),
  'member',
  'in-app invitation acceptance forces the MVP member role'
);
select is(
  (select status::text from public.household_invitations where id = '20000000-0000-0000-0000-000000000001'),
  'accepted',
  'accepted invitation is transitioned atomically'
);
select ok(
  exists (
    select 1 from public.audit_events
    where household_id = '10000000-0000-0000-0000-000000000001'
      and actor_user_id = '00000000-0000-0000-0000-000000000002'
      and event_type = 'membership.invitation_accepted'
  ),
  'invitation acceptance preserves the household audit event'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select is(
  public.accept_household_invitation_by_id('20000000-0000-0000-0000-000000000001'),
  '10000000-0000-0000-0000-000000000001'::uuid,
  'same-user acceptance retry is deterministic and safe'
);

select throws_ok(
  $$select public.accept_household_invitation_by_id('20000000-0000-0000-0000-000000000003')$$,
  'P0001',
  'invitation_expired',
  'expired invitation cannot be accepted'
);
select throws_ok(
  $$select public.accept_household_invitation_by_id('20000000-0000-0000-0000-000000000004')$$,
  'P0001',
  'invitation_not_pending',
  'revoked invitation cannot be accepted'
);
reset role;
select is(
  (select count(*)::integer from public.household_members where household_id = '10000000-0000-0000-0000-000000000001' and user_id = '00000000-0000-0000-0000-000000000002'),
  1,
  'acceptance retries cannot create duplicate memberships'
);
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$select * from public.list_my_pending_household_invitations()$$,
  '42501',
  'permission denied for function list_my_pending_household_invitations',
  'anonymous callers cannot execute invitation discovery'
);
reset role;
select ok(
  not has_function_privilege('anon', 'public.list_my_pending_household_invitations()', 'execute'),
  'anonymous role has no execute grant on invitation discovery'
);
select ok(
  not has_table_privilege('authenticated', 'public.households', 'insert'),
  'authenticated clients cannot bypass initial Household creation with direct table inserts'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000010', true);
select throws_ok(
  $$select public.create_initial_household('لا تتجاوز الدعوة', 'EGP')$$,
  'P0001',
  'pending_invitation_requires_resolution',
  'initial Household creation cannot bypass a valid pending invitation'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000004', true);
select lives_ok(
  $$select public.create_initial_household('أسرة المالك', 'EGP', 31, 'Africa/Cairo')$$,
  'authenticated user can create an initial Household'
);
select is(
  public.create_initial_household('تكرار لا ينشئ أسرة', 'EGP', 1, 'Africa/Cairo'),
  (select household_id from public.household_members where user_id = '00000000-0000-0000-0000-000000000004' and status = 'active'),
  'initial Household creation retry returns the existing active Household'
);
reset role;
select is(
  (select role::text from public.household_members where user_id = '00000000-0000-0000-0000-000000000004' and status = 'active'),
  'owner',
  'initial Household creator becomes Household Owner'
);
select is(
  (select count(*)::integer from public.household_members where user_id = '00000000-0000-0000-0000-000000000004' and status = 'active'),
  1,
  'initial creation creates exactly one active membership'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000005', true);
select lives_ok($$select public.create_initial_household('SAR', 'SAR')$$, 'SAR is accepted');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000006', true);
select lives_ok($$select public.create_initial_household('USD', 'USD')$$, 'USD is accepted');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000007', true);
select lives_ok($$select public.create_initial_household('EUR', 'EUR')$$, 'EUR is accepted');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000008', true);
select throws_ok(
  $$select public.create_initial_household('GBP', 'GBP')$$,
  '23514',
  'unsupported_currency_code',
  'unsupported currency is rejected by the domain operation'
);
select throws_ok(
  $$select public.create_initial_household('lowercase', 'egp')$$,
  '23514',
  'unsupported_currency_code',
  'lowercase currency is rejected rather than silently normalized'
);
reset role;

select throws_ok(
  $$insert into public.households (name, owner_user_id, currency_code) values ('bad currency', '00000000-0000-0000-0000-000000000008', 'GBP')$$,
  '23514',
  'new row for relation "households" violates check constraint "households_currency_code_check"',
  'unsupported currency is rejected by the table constraint'
);
select throws_ok(
  $$insert into public.households (name, owner_user_id, period_start_day) values ('day zero', '00000000-0000-0000-0000-000000000008', 0)$$,
  '23514',
  'new row for relation "households" violates check constraint "households_period_start_day_check"',
  'period start day zero is rejected'
);
select throws_ok(
  $$insert into public.households (name, owner_user_id, period_start_day) values ('day 32', '00000000-0000-0000-0000-000000000008', 32)$$,
  '23514',
  'new row for relation "households" violates check constraint "households_period_start_day_check"',
  'period start day 32 is rejected'
);
select lives_ok(
  $$insert into public.households (name, owner_user_id, period_start_day) values ('day 28', '00000000-0000-0000-0000-000000000008', 28)$$,
  'period start day 28 is accepted'
);
select lives_ok(
  $$insert into public.households (name, owner_user_id, period_start_day) values ('day 29', '00000000-0000-0000-0000-000000000008', 29)$$,
  'period start day 29 is accepted'
);
select lives_ok(
  $$insert into public.households (name, owner_user_id, period_start_day) values ('day 30', '00000000-0000-0000-0000-000000000008', 30)$$,
  'period start day 30 is accepted'
);
select lives_ok(
  $$insert into public.households (name, owner_user_id, period_start_day) values ('day 31', '00000000-0000-0000-0000-000000000008', 31)$$,
  'period start day 31 is accepted'
);

select is(public.clamped_period_start_date(2027, 2, 31), date '2027-02-28', 'non-leap February clamps day 31 to February 28');
select is(public.clamped_period_start_date(2028, 2, 31), date '2028-02-29', 'leap February clamps day 31 to February 29');
select is(public.clamped_period_start_date(2027, 4, 31), date '2027-04-30', 'April clamps day 31 to April 30');
select is(public.clamped_period_start_date(2027, 5, 31), date '2027-05-31', '31-day months retain day 31');
select is(
  public.clamped_period_start_date(2027, 1, 31),
  date '2027-01-31',
  'January day 31 start is exact'
);
select is(
  public.clamped_period_start_date(2027, 2, 31) - 1,
  date '2027-02-27',
  'period end is one day before the next clamped start'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000009', true);
update public.households set period_start_day = 31 where id = '10000000-0000-0000-0000-000000000003';
select public.ensure_budget_period('10000000-0000-0000-0000-000000000003') as period_id \gset
reset role;
create temporary table period_history as
select start_date, end_date from public.budget_periods where id = :'period_id';
update public.households set period_start_day = 1 where id = '10000000-0000-0000-0000-000000000003';
select is(
  (select row(start_date, end_date)::text from public.budget_periods where id = :'period_id'),
  (select row(start_date, end_date)::text from period_history),
  'changing period_start_day does not rewrite historical budget-period boundaries'
);
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000009', true);
select public.ensure_budget_period('10000000-0000-0000-0000-000000000003') as new_period_id \gset
reset role;
select isnt(
  :'new_period_id'::uuid,
  :'period_id'::uuid,
  'a future period is created from the updated period_start_day setting'
);
select is(
  (select start_date from public.budget_periods where id = :'new_period_id'),
  date_trunc('month', (now() at time zone 'Africa/Cairo')::date)::date,
  'the future period uses the updated first-day setting'
);
select is(
  public.clamped_period_start_date(2027, 2, 31), date '2027-02-28',
  'future period calculations retain the configured clamped-day rule'
);

select * from finish();
rollback;
