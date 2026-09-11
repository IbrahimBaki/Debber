begin;

create extension if not exists pgtap with schema extensions;

select plan(38);

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('80000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'owner1@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('80000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'member1@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('80000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'owner2@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  -- This user's email intentionally matches the very first invitation created below, so the
  -- same invitation can be used for the end-of-file discovery/acceptance regression check.
  ('80000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'fresh1@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now());

insert into public.households (id, name, owner_user_id, currency_code)
values
  ('81000000-0000-0000-0000-000000000001', 'بيت الدعوات', '80000000-0000-0000-0000-000000000001', 'EGP'),
  ('81000000-0000-0000-0000-000000000002', 'بيت آخر', '80000000-0000-0000-0000-000000000003', 'EGP');

insert into public.household_members (household_id, user_id, role, status)
values ('81000000-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000002', 'member', 'active');

-- Fixture: a stale pending invitation and a revoked invitation, inserted directly (no client
-- path can do this once raw grants are removed; the fixture emulates prior/legacy state).
insert into public.household_invitations (id, household_id, email, token_hash, status, invited_by, expires_at)
values
  ('82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', 'stale@example.test', 'stale-token-fixture', 'pending', '80000000-0000-0000-0000-000000000001', now() - interval '1 hour'),
  ('82000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000001', 'revoked@example.test', 'revoked-token-fixture', 'revoked', '80000000-0000-0000-0000-000000000001', now() + interval '1 day');

-- === AUTHORIZATION ===
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000001', true);

select invitation_id, email, expires_at, created
from public.create_household_invitation('81000000-0000-0000-0000-000000000001', 'fresh1@example.test')
\gset owner_invite1_
select ok(:'owner_invite1_created'::boolean, 'owner can create an invitation for another email');
select ok(
  :'owner_invite1_expires_at'::timestamptz between now() + interval '6 days 23 hours' and now() + interval '7 days 1 minute',
  'server computes expires_at ~ 7 days from now, not client-supplied'
);

select set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000002', true);
select throws_ok(
  $$select * from public.create_household_invitation('81000000-0000-0000-0000-000000000001', 'someone@example.test')$$,
  '42501', null,
  'a non-owner active Member cannot create an invitation'
);

reset role;
set local role anon;
select throws_ok(
  $$select * from public.create_household_invitation('81000000-0000-0000-0000-000000000001', 'someone@example.test')$$,
  '42501', null,
  'anonymous callers cannot execute invitation creation'
);
select ok(
  not has_function_privilege('anon', 'public.create_household_invitation(uuid,text)', 'execute'),
  'anonymous role has no execute grant on invitation creation'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$select * from public.create_household_invitation('81000000-0000-0000-0000-000000000002', 'cross@example.test')$$,
  '42501', null,
  'owner cannot create an invitation for a household they do not own (guessed/known id)'
);

-- === EMAIL NORMALIZATION ===
reset role;
select is(
  (select email from public.household_invitations where id = :'owner_invite1_invitation_id'::uuid),
  'fresh1@example.test',
  'stored email is normalized (already-lowercase input stays as-is)'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$select * from public.create_household_invitation('81000000-0000-0000-0000-000000000001', '')$$,
  '22023', null,
  'an empty email is rejected'
);
select throws_ok(
  $$select * from public.create_household_invitation('81000000-0000-0000-0000-000000000001', 'not-an-email')$$,
  '22023', null,
  'a malformed email is rejected'
);

select invitation_id, created
from public.create_household_invitation('81000000-0000-0000-0000-000000000001', '  Fresh2@Example.TEST  ')
\gset fresh2_first_
select invitation_id, created
from public.create_household_invitation('81000000-0000-0000-0000-000000000001', 'fresh2@example.test')
\gset fresh2_second_
select is(
  :'fresh2_second_invitation_id'::uuid, :'fresh2_first_invitation_id'::uuid,
  'mixed case and surrounding whitespace resolve to the same invitation identity'
);
select ok(not :'fresh2_second_created'::boolean, 'the case/whitespace-variant call is idempotent (created=false)');
reset role;
select is(
  (select count(*)::integer from public.household_invitations where household_id = '81000000-0000-0000-0000-000000000001' and email = 'fresh2@example.test'),
  1,
  'exactly one row exists for the case/whitespace-varied email'
);

-- === SELF-INVITE ===
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$select * from public.create_household_invitation('81000000-0000-0000-0000-000000000001', 'owner1@example.test')$$,
  'P0001', 'self_invite_not_allowed',
  'owner cannot invite their own authoritative email'
);
select throws_ok(
  $$select * from public.create_household_invitation('81000000-0000-0000-0000-000000000001', '  Owner1@Example.Test  ')$$,
  'P0001', 'self_invite_not_allowed',
  'self-invite rejection also normalizes case/whitespace before comparing'
);

-- === EXISTING ACTIVE MEMBER ===
select throws_ok(
  $$select * from public.create_household_invitation('81000000-0000-0000-0000-000000000001', 'member1@example.test')$$,
  'P0001', 'already_active_member',
  'inviting an existing active Member of this household is rejected'
);
select lives_ok(
  $$select * from public.create_household_invitation('81000000-0000-0000-0000-000000000001', 'nobody@example.test')$$,
  'inviting an email with no Dabber account at all succeeds normally (no account-existence signal)'
);

-- === DUPLICATE ACTIVE PENDING (IDEMPOTENCY) ===
select invitation_id, created
from public.create_household_invitation('81000000-0000-0000-0000-000000000001', 'dup@example.test')
\gset dup_first_
select invitation_id, created
from public.create_household_invitation('81000000-0000-0000-0000-000000000001', 'dup@example.test')
\gset dup_second_
select is(:'dup_second_invitation_id'::uuid, :'dup_first_invitation_id'::uuid, 'a duplicate call while pending/unexpired reuses the same invitation');
select ok(not :'dup_second_created'::boolean, 'the duplicate call reports created=false');
reset role;
select is(
  (select count(*)::integer from public.household_invitations where household_id = '81000000-0000-0000-0000-000000000001' and email = 'dup@example.test' and status = 'pending'),
  1,
  'exactly one pending row exists after the duplicate call'
);
select is(
  (select count(*)::integer from public.audit_events where entity_type = 'household_invitation' and entity_id = :'dup_first_invitation_id'::uuid and event_type = 'household_invitation.created'),
  1,
  'exactly one creation audit event exists; the idempotent replay wrote no second event'
);

-- === STALE EXPIRED PENDING DOES NOT BLOCK A FRESH INVITE ===
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000001', true);
select invitation_id, expires_at, created
from public.create_household_invitation('81000000-0000-0000-0000-000000000001', 'stale@example.test')
\gset stale_retry_
select ok(:'stale_retry_created'::boolean, 'a stale expired-but-still-pending invitation does not block a fresh one');
select isnt(
  :'stale_retry_invitation_id'::uuid, '82000000-0000-0000-0000-000000000001'::uuid,
  'the fresh invitation has a new identity, distinct from the stale row'
);
reset role;
select is(
  (select status::text from public.household_invitations where id = '82000000-0000-0000-0000-000000000001'),
  'expired',
  'the stale pending row is lazily transitioned to expired'
);
select isnt(
  (select token_hash from public.household_invitations where id = :'stale_retry_invitation_id'::uuid),
  'stale-token-fixture',
  'the fresh invitation has a newly generated token, not reused from the stale row'
);

-- === REVOKED DOES NOT BLOCK A NEW INVITE ===
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select * from public.create_household_invitation('81000000-0000-0000-0000-000000000001', 'revoked@example.test')$$,
  'a revoked old invitation does not block a new invitation to the same email'
);

-- === SERVER AUTHORITY OVER STATUS/INVITED_BY/EXPIRY/TOKEN ===
reset role;
select is(
  (select status::text from public.household_invitations where id = :'owner_invite1_invitation_id'::uuid),
  'pending',
  'a freshly created invitation starts pending'
);
select is(
  (select invited_by from public.household_invitations where id = :'owner_invite1_invitation_id'::uuid),
  '80000000-0000-0000-0000-000000000001'::uuid,
  'invited_by is always the caller, never client-supplied'
);
select is(
  (select char_length(token_hash) from public.household_invitations where id = :'owner_invite1_invitation_id'::uuid),
  64,
  'token_hash is a server-generated 32-byte hex value (64 hex characters), not client input'
);
select throws_ok(
  $$select * from public.create_household_invitation('81000000-0000-0000-0000-000000000001', 'blocked@example.test', 'accepted')$$,
  '42883', null,
  'the function has no parameter for status/expiry/token -- a caller cannot supply one at all'
);

-- === RAW TABLE HARDENING ===
select ok(not has_table_privilege('authenticated', 'public.household_invitations', 'select'), 'authenticated clients cannot directly SELECT household_invitations (token_hash cannot leak this way)');
select ok(not has_table_privilege('authenticated', 'public.household_invitations', 'insert'), 'authenticated clients cannot directly INSERT household_invitations');
select ok(not has_table_privilege('authenticated', 'public.household_invitations', 'update'), 'authenticated clients cannot directly UPDATE household_invitations');
select ok(not has_table_privilege('authenticated', 'public.household_invitations', 'delete'), 'authenticated clients cannot directly DELETE household_invitations');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$select token_hash from public.household_invitations limit 1$$,
  '42501', null,
  'a direct client SELECT (including token_hash) is rejected outright'
);
reset role;

-- === EXISTING ONBOARDING FLOW REGRESSION: discovery + explicit acceptance still work ===
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000004', true);
select is(
  (select count(*)::integer from public.list_my_pending_household_invitations() where invitation_id = :'owner_invite1_invitation_id'::uuid),
  1,
  'the invitee discovers the invitation created via the new domain operation'
);
select is(
  public.accept_household_invitation_by_id(:'owner_invite1_invitation_id'::uuid),
  '81000000-0000-0000-0000-000000000001'::uuid,
  'the invitee can explicitly accept the invitation through the existing acceptance RPC'
);
reset role;
select is(
  (select role::text from public.household_members where household_id = '81000000-0000-0000-0000-000000000001' and user_id = '80000000-0000-0000-0000-000000000004'),
  'member',
  'acceptance still grants exactly the member role -- there is no invitation role to spoof'
);
select is(
  (select status::text from public.household_invitations where id = :'owner_invite1_invitation_id'::uuid),
  'accepted',
  'the accepted invitation transitions status as before'
);

select * from finish();
rollback;
