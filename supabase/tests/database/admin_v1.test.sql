begin;

create extension if not exists pgtap with schema extensions;

select plan(72);

-- === FIXTURES ===

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('90000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'admin-owner@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('90000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'admin-member@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('90000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'admin-sa@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('90000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'admin-plainuser@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('90000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'admin-invitee-exists@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('90000000-0000-0000-0000-000000000006', 'authenticated', 'authenticated', 'admin-inactive-admin@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now());

insert into public.households (id, name, owner_user_id, currency_code, timezone)
values ('91000000-0000-0000-0000-000000000001', 'بيت الخصوصية', '90000000-0000-0000-0000-000000000001', 'EGP', 'UTC');

-- The household's owner_user_id row is inserted automatically by on_household_created; only the
-- Member needs an explicit row here.
insert into public.household_members (household_id, user_id, role, status)
values ('91000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000002', 'member', 'active');

insert into public.budget_periods (id, household_id, period_key, start_date, end_date, status, spending_budget, created_by)
values ('92000000-0000-0000-0000-000000000001', '91000000-0000-0000-0000-000000000001', date '2020-01-01', date '2020-01-01', date '2020-01-31', 'open', 5000, '90000000-0000-0000-0000-000000000001');

insert into public.budget_sections (id, household_id, name, kind, default_planned_amount, visibility_scope, member_access, created_by)
values ('93000000-0000-0000-0000-000000000001', '91000000-0000-0000-0000-000000000001', 'البيت', 'flexible', 5000, 'household', 'contribute', '90000000-0000-0000-0000-000000000001');

insert into public.period_section_budgets (id, period_id, section_id, section_name_snapshot, section_kind_snapshot, planned_amount)
values ('94000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000001', '93000000-0000-0000-0000-000000000001', 'البيت', 'flexible', 5000);

insert into public.period_income_items (id, period_id, name_snapshot, planned_amount, created_by)
values ('95000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000001', 'راتب', 20000, '90000000-0000-0000-0000-000000000001');

insert into public.period_fixed_commitments (id, period_id, name_snapshot, planned_amount, created_by)
values ('96000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000001', 'إيجار', 8000, '90000000-0000-0000-0000-000000000001');

insert into public.transactions (id, period_id, period_section_budget_id, amount, created_by)
values ('97000000-0000-0000-0000-000000000001', '92000000-0000-0000-0000-000000000001', '94000000-0000-0000-0000-000000000001', 3500, '90000000-0000-0000-0000-000000000001');

-- One already-active, already-allowlisted-elsewhere admin used purely to prove the allowlist logic (inactive/wrong-role cases).
insert into public.platform_admins (user_id, role, is_active)
values ('90000000-0000-0000-0000-000000000006', 'super_admin', false);

-- === 1. SUPER ADMIN ALLOWLIST ===

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000006', true);
select is(public.is_platform_admin(), false, 'an inactive platform_admins row does not grant admin status');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000004', true);
select is(public.is_platform_admin(), false, 'a plain authenticated user with no platform_admins row is not an admin');
reset role;

set local role anon;
select is(public.is_platform_admin(), false, 'an anonymous caller is never an admin');
reset role;

-- Promote the SA fixture user to an active super_admin for the remainder of the suite.
insert into public.platform_admins (user_id, role, is_active, created_by)
values ('90000000-0000-0000-0000-000000000003', 'super_admin', true, '90000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000003', true);
select is(public.is_platform_admin(), true, 'an active, listed super_admin row grants admin status');
reset role;

-- === 2. FINANCIAL PRIVACY WALL (asserted BEFORE and AFTER the caller is an admin) ===

-- helper macro pattern: run as the SA user while SA is NOT YET in platform_admins would require
-- removing/re-adding the row; instead we assert the zero-row/not_authorized behavior for a
-- different never-admin household outsider (plain user) first, then re-assert identically for
-- the SA user once they ARE an active admin -- proving admin status changes nothing.

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000004', true);
select is((select count(*)::int from public.period_income_items where period_id = '92000000-0000-0000-0000-000000000001'), 0, 'a non-member, non-admin sees zero period_income_items rows');
select is((select count(*)::int from public.transactions where period_id = '92000000-0000-0000-0000-000000000001'), 0, 'a non-member, non-admin sees zero transactions rows');
select is((select count(*)::int from public.period_fixed_commitments where period_id = '92000000-0000-0000-0000-000000000001'), 0, 'a non-member, non-admin sees zero period_fixed_commitments rows');
select is((select count(*)::int from public.period_section_budgets where period_id = '92000000-0000-0000-0000-000000000001'), 0, 'a non-member, non-admin sees zero period_section_budgets rows');
select throws_ok($$select * from public.get_owner_period_planning_summary('92000000-0000-0000-0000-000000000001')$$, '42501', null, 'a non-member, non-admin cannot call get_owner_period_planning_summary');
select throws_ok($$select public.get_member_visible_total_income('92000000-0000-0000-0000-000000000001')$$, '42501', null, 'a non-member, non-admin cannot call get_member_visible_total_income');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000003', true);
select is(public.is_platform_admin(), true, 'sanity: the SA fixture user is an active admin for the checks below');
select is((select count(*)::int from public.period_income_items where period_id = '92000000-0000-0000-0000-000000000001'), 0, 'an active super_admin who is NOT a household member still sees zero period_income_items rows');
select is((select count(*)::int from public.transactions where period_id = '92000000-0000-0000-0000-000000000001'), 0, 'an active super_admin who is NOT a household member still sees zero transactions rows');
select is((select count(*)::int from public.period_fixed_commitments where period_id = '92000000-0000-0000-0000-000000000001'), 0, 'an active super_admin who is NOT a household member still sees zero period_fixed_commitments rows');
select is((select count(*)::int from public.period_section_budgets where period_id = '92000000-0000-0000-0000-000000000001'), 0, 'an active super_admin who is NOT a household member still sees zero period_section_budgets rows');
select throws_ok($$select * from public.get_owner_period_planning_summary('92000000-0000-0000-0000-000000000001')$$, '42501', null, 'an active super_admin cannot call get_owner_period_planning_summary for a household they do not own');
select throws_ok($$select public.get_member_visible_total_income('92000000-0000-0000-0000-000000000001')$$, '42501', null, 'an active super_admin cannot call get_member_visible_total_income for a household they are not a member of');
reset role;

-- === 3. ADMIN RPC AUTH: super_admin succeeds / non-admin rejected / anon rejected (per RPC) ===

-- admin_list_users
set local role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000003', true);
select lives_ok($$select * from public.admin_list_users(null, 10, 0)$$, 'super_admin can call admin_list_users');
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000004', true);
select throws_ok($$select * from public.admin_list_users(null, 10, 0)$$, '42501', null, 'non-admin cannot call admin_list_users');
reset role;
set local role anon;
select throws_ok($$select * from public.admin_list_users(null, 10, 0)$$, '42501', null, 'anon cannot call admin_list_users');
select ok(not has_function_privilege('anon', 'public.admin_list_users(text,integer,integer)', 'execute'), 'anon has no execute grant on admin_list_users');
reset role;

-- admin_get_user
set local role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000003', true);
select lives_ok($$select * from public.admin_get_user('90000000-0000-0000-0000-000000000001')$$, 'super_admin can call admin_get_user');
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000004', true);
select throws_ok($$select * from public.admin_get_user('90000000-0000-0000-0000-000000000001')$$, '42501', null, 'non-admin cannot call admin_get_user');
reset role;
set local role anon;
select throws_ok($$select * from public.admin_get_user('90000000-0000-0000-0000-000000000001')$$, '42501', null, 'anon cannot call admin_get_user');
select ok(not has_function_privilege('anon', 'public.admin_get_user(uuid)', 'execute'), 'anon has no execute grant on admin_get_user');
reset role;

-- admin_list_user_memberships
set local role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000003', true);
select lives_ok($$select * from public.admin_list_user_memberships('90000000-0000-0000-0000-000000000001')$$, 'super_admin can call admin_list_user_memberships');
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000004', true);
select throws_ok($$select * from public.admin_list_user_memberships('90000000-0000-0000-0000-000000000001')$$, '42501', null, 'non-admin cannot call admin_list_user_memberships');
reset role;
set local role anon;
select throws_ok($$select * from public.admin_list_user_memberships('90000000-0000-0000-0000-000000000001')$$, '42501', null, 'anon cannot call admin_list_user_memberships');
select ok(not has_function_privilege('anon', 'public.admin_list_user_memberships(uuid)', 'execute'), 'anon has no execute grant on admin_list_user_memberships');
reset role;

-- admin_list_invitations
set local role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000003', true);
select lives_ok($$select * from public.admin_list_invitations(null, null, 10, 0)$$, 'super_admin can call admin_list_invitations');
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000004', true);
select throws_ok($$select * from public.admin_list_invitations(null, null, 10, 0)$$, '42501', null, 'non-admin cannot call admin_list_invitations');
reset role;
set local role anon;
select throws_ok($$select * from public.admin_list_invitations(null, null, 10, 0)$$, '42501', null, 'anon cannot call admin_list_invitations');
select ok(not has_function_privilege('anon', 'public.admin_list_invitations(text,public.invitation_status,integer,integer)', 'execute'), 'anon has no execute grant on admin_list_invitations');
reset role;

-- admin_dashboard_counts
set local role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000003', true);
select lives_ok($$select * from public.admin_dashboard_counts()$$, 'super_admin can call admin_dashboard_counts');
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000004', true);
select throws_ok($$select * from public.admin_dashboard_counts()$$, '42501', null, 'non-admin cannot call admin_dashboard_counts');
reset role;
set local role anon;
select throws_ok($$select * from public.admin_dashboard_counts()$$, '42501', null, 'anon cannot call admin_dashboard_counts');
select ok(not has_function_privilege('anon', 'public.admin_dashboard_counts()', 'execute'), 'anon has no execute grant on admin_dashboard_counts');
reset role;

-- admin_list_audit_logs
set local role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000003', true);
select lives_ok($$select * from public.admin_list_audit_logs(10, 0)$$, 'super_admin can call admin_list_audit_logs');
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000004', true);
select throws_ok($$select * from public.admin_list_audit_logs(10, 0)$$, '42501', null, 'non-admin cannot call admin_list_audit_logs');
reset role;
set local role anon;
select throws_ok($$select * from public.admin_list_audit_logs(10, 0)$$, '42501', null, 'anon cannot call admin_list_audit_logs');
select ok(not has_function_privilege('anon', 'public.admin_list_audit_logs(integer,integer)', 'execute'), 'anon has no execute grant on admin_list_audit_logs');
reset role;

-- admin_record_audit_event
set local role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000004', true);
select throws_ok($$select public.admin_record_audit_event('probe.event', 'test', null, null, null, null, null)$$, '42501', null, 'non-admin cannot call admin_record_audit_event');
reset role;
set local role anon;
select throws_ok($$select public.admin_record_audit_event('probe.event', 'test', null, null, null, null, null)$$, '42501', null, 'anon cannot call admin_record_audit_event');
select ok(not has_function_privilege('anon', 'public.admin_record_audit_event(text,text,text,uuid,uuid,uuid,text)', 'execute'), 'anon has no execute grant on admin_record_audit_event');
reset role;

-- === 4. SAFE FIELDS: no password/token/financial columns can leak from admin RPC return shapes ===

select ok(
  not (
    (select proargnames from pg_proc where proname = 'admin_list_users' and pronamespace = 'public'::regnamespace)
    && array['encrypted_password','password','raw_user_meta_data','raw_app_meta_data','confirmation_token','recovery_token','email_change_token_current']
  ),
  'admin_list_users return shape has no password/token/raw-metadata columns'
);
select ok(
  not (
    (select proargnames from pg_proc where proname = 'admin_get_user' and pronamespace = 'public'::regnamespace)
    && array['encrypted_password','password','raw_user_meta_data','raw_app_meta_data','confirmation_token','recovery_token']
  ),
  'admin_get_user return shape has no password/token/raw-metadata columns'
);
select ok(
  not (
    (select proargnames from pg_proc where proname = 'admin_list_invitations' and pronamespace = 'public'::regnamespace)
    && array['token_hash']
  ),
  'admin_list_invitations return shape never includes token_hash'
);
select ok(
  (select pronargs from pg_proc where proname = 'admin_accept_household_invitation' and pronamespace = 'public'::regnamespace) = 1,
  'admin_accept_household_invitation takes only an invitation id -- no caller-suppliable target user id exists at all'
);

-- === 5. INVITATION ADMIN FLOWS ===

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000003', true);

-- self-invite (against the OWNER's email, not the admin's)
select throws_ok(
  $$select * from public.admin_create_household_invitation('91000000-0000-0000-0000-000000000001', 'admin-owner@example.test')$$,
  'P0001', 'self_invite_not_allowed',
  'admin-on-behalf creation rejects the household owner''s own email'
);

-- already-active-member rejection
select throws_ok(
  $$select * from public.admin_create_household_invitation('91000000-0000-0000-0000-000000000001', 'admin-member@example.test')$$,
  'P0001', 'already_active_member',
  'admin-on-behalf creation rejects an existing active member''s email'
);

-- create on behalf: happy path
select invitation_id, email, created
from public.admin_create_household_invitation('91000000-0000-0000-0000-000000000001', 'admin-invitee-exists@example.test')
\gset onbehalf_
select ok(:'onbehalf_created'::boolean, 'admin can create an invitation on behalf of the household owner');
reset role;
select is(
  (select invited_by from public.household_invitations where id = :'onbehalf_invitation_id'::uuid),
  '90000000-0000-0000-0000-000000000001'::uuid,
  'invited_by is preserved as the household owner, not the admin actor'
);
select is(
  (select count(*)::int from public.admin_audit_logs where action = 'invitation.created_on_behalf' and invitation_id = :'onbehalf_invitation_id'::uuid),
  1,
  'exactly one admin_audit_logs row records the on-behalf creation'
);
select is(
  (select admin_user_id from public.admin_audit_logs where action = 'invitation.created_on_behalf' and invitation_id = :'onbehalf_invitation_id'::uuid),
  '90000000-0000-0000-0000-000000000003'::uuid,
  'the audit row records the real admin actor, separately from invited_by'
);
select is(
  (select count(*)::int from public.audit_events where entity_type = 'household_invitation' and entity_id = :'onbehalf_invitation_id'::uuid and actor_type = 'platform_admin'),
  1,
  'the household-visible audit_events row records actor_type = platform_admin'
);

-- idempotent reuse: no misleading duplicate audit row
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000003', true);
select invitation_id, created
from public.admin_create_household_invitation('91000000-0000-0000-0000-000000000001', 'admin-invitee-exists@example.test')
\gset onbehalf_dup_
select ok(not :'onbehalf_dup_created'::boolean, 'a duplicate on-behalf creation call is idempotent (created=false)');
select is(:'onbehalf_dup_invitation_id'::uuid, :'onbehalf_invitation_id'::uuid, 'the duplicate call reuses the same invitation');
reset role;
select is(
  (select count(*)::int from public.admin_audit_logs where action = 'invitation.created_on_behalf' and invitation_id = :'onbehalf_invitation_id'::uuid),
  1,
  'the idempotent replay wrote no second audit_logs row'
);

-- accept on behalf: matching Auth user exists
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000003', true);
select is(
  public.admin_accept_household_invitation(:'onbehalf_invitation_id'::uuid),
  '91000000-0000-0000-0000-000000000001'::uuid,
  'admin can accept an existing invitation on behalf of its invitee'
);
reset role;
select is(
  (select role::text from public.household_members where household_id = '91000000-0000-0000-0000-000000000001' and user_id = '90000000-0000-0000-0000-000000000005'),
  'member',
  'acceptance grants exactly the member role'
);
select is(
  (select status::text from public.household_invitations where id = :'onbehalf_invitation_id'::uuid),
  'accepted',
  'the invitation transitions to accepted'
);
select is(
  (select accepted_by from public.household_invitations where id = :'onbehalf_invitation_id'::uuid),
  '90000000-0000-0000-0000-000000000005'::uuid,
  'accepted_by is the invitee resolved from the invitation email, not the admin'
);
select is(
  (select count(*)::int from public.admin_audit_logs where action = 'invitation.accepted_on_behalf' and invitation_id = :'onbehalf_invitation_id'::uuid),
  1,
  'exactly one admin_audit_logs row records the on-behalf acceptance'
);

-- accept on behalf: NO matching Auth user (cannot be forced to an unrelated/guessed user id)
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', true);
select invitation_id
from public.create_household_invitation('91000000-0000-0000-0000-000000000001', 'nobody-registered@example.test')
\gset orphan_
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000003', true);
select throws_ok(
  format($$select public.admin_accept_household_invitation(%L::uuid)$$, :'orphan_invitation_id'),
  'P0002', 'invitee_user_not_found',
  'admin cannot accept an invitation whose email has no matching Auth user'
);
reset role;

-- revoke: pending -> revoked, and cannot revoke twice or revoke an accepted invitation
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000003', true);
select lives_ok(
  format($$select public.admin_revoke_household_invitation(%L::uuid, 'no longer needed')$$, :'orphan_invitation_id'),
  'admin can revoke a pending invitation'
);
reset role;
select is(
  (select status::text from public.household_invitations where id = :'orphan_invitation_id'::uuid),
  'revoked',
  'the invitation transitions to revoked'
);
select is(
  (select count(*)::int from public.admin_audit_logs where action = 'invitation.revoked' and invitation_id = :'orphan_invitation_id'::uuid),
  1,
  'exactly one admin_audit_logs row records the revoke'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000003', true);
select throws_ok(
  format($$select public.admin_revoke_household_invitation(%L::uuid, null)$$, :'orphan_invitation_id'),
  'P0001', 'invitation_not_pending',
  'an already-revoked invitation cannot be revoked again'
);
select throws_ok(
  format($$select public.admin_revoke_household_invitation(%L::uuid, null)$$, :'onbehalf_invitation_id'),
  'P0001', 'invitation_not_pending',
  'an already-accepted invitation can never be revoked (no un-accepting a real membership)'
);
reset role;

-- no direct membership-creation path exists anywhere in the admin surface
select ok(
  not exists (
    select 1 from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname like 'admin%'
      and (proname ilike '%add_member%' or proname ilike '%create_member%')
  ),
  'no admin RPC creates a household membership directly (only via invitation accept)'
);

-- === 6. AUDIT LOG never stores sensitive values ===

select is(
  (select metadata from public.admin_audit_logs where action = 'invitation.created_on_behalf' and invitation_id = :'onbehalf_invitation_id'::uuid),
  '{}'::jsonb,
  'the on-behalf creation audit row stores empty metadata (no email/token captured there)'
);
select ok(
  not exists (
    select 1 from public.admin_audit_logs
    where reason ilike '%password%' or reason ilike '%token%' or action ilike '%password%'
  ),
  'no admin_audit_logs row generated in this suite mentions a password or token'
);

select * from finish();
rollback;
