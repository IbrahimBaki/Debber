begin;

create extension if not exists pgtap with schema extensions;

select plan(30);

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('60000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'expense-owner@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('60000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'expense-member@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('60000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'expense-other-owner@example.test', 'x', now(), '{}'::jsonb, '{}'::jsonb, now(), now());

-- Household timezone is pinned to UTC so "today" in the test matches
-- (now() at time zone 'UTC')::date deterministically, regardless of server session timezone.
insert into public.households (id, name, owner_user_id, currency_code, timezone)
values
  ('61000000-0000-0000-0000-000000000001', 'مصروف يومي', '60000000-0000-0000-0000-000000000001', 'EGP', 'UTC'),
  ('61000000-0000-0000-0000-000000000002', 'أسرة أخرى', '60000000-0000-0000-0000-000000000003', 'EGP', 'UTC');

insert into public.household_members (household_id, user_id, role, status)
values ('61000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', 'member', 'active');

-- Budget periods: draft/closed use arbitrary historical ranges; the open period always spans
-- "today" (UTC) so date-bounds assertions never depend on when the suite happens to run.
insert into public.budget_periods (id, household_id, period_key, start_date, end_date, status, created_by)
values
  ('62000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000001', date '2020-01-01', date '2020-01-01', date '2020-01-31', 'draft', '60000000-0000-0000-0000-000000000001'),
  ('62000000-0000-0000-0000-000000000002', '61000000-0000-0000-0000-000000000001', date '2020-02-01', date '2020-02-01', date '2020-02-29', 'closed', '60000000-0000-0000-0000-000000000001'),
  ('62000000-0000-0000-0000-000000000003', '61000000-0000-0000-0000-000000000001', (now() at time zone 'UTC')::date, ((now() at time zone 'UTC')::date - 10), ((now() at time zone 'UTC')::date + 10), 'open', '60000000-0000-0000-0000-000000000001'),
  ('62000000-0000-0000-0000-000000000004', '61000000-0000-0000-0000-000000000002', (now() at time zone 'UTC')::date, ((now() at time zone 'UTC')::date - 10), ((now() at time zone 'UTC')::date + 10), 'open', '60000000-0000-0000-0000-000000000003');

insert into public.budget_sections (id, household_id, name, kind, visibility_scope, member_access, created_by)
values
  ('63000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000001', 'مصروف البيت', 'flexible', 'household', 'contribute', '60000000-0000-0000-0000-000000000001'),
  ('63000000-0000-0000-0000-000000000002', '61000000-0000-0000-0000-000000000001', 'قسم للعرض فقط', 'flexible', 'household', 'view', '60000000-0000-0000-0000-000000000001'),
  ('63000000-0000-0000-0000-000000000003', '61000000-0000-0000-0000-000000000001', 'قسم خاص', 'flexible', 'owner_only', 'view', '60000000-0000-0000-0000-000000000001'),
  ('63000000-0000-0000-0000-000000000004', '61000000-0000-0000-0000-000000000002', 'قسم أسرة أخرى', 'flexible', 'household', 'contribute', '60000000-0000-0000-0000-000000000003');

insert into public.period_section_budgets (id, period_id, section_id, section_name_snapshot, section_kind_snapshot, planned_amount)
values
  ('64000000-0000-0000-0000-000000000001', '62000000-0000-0000-0000-000000000001', '63000000-0000-0000-0000-000000000001', 'مصروف البيت', 'flexible', 3000),
  ('64000000-0000-0000-0000-000000000002', '62000000-0000-0000-0000-000000000002', '63000000-0000-0000-0000-000000000001', 'مصروف البيت', 'flexible', 3000),
  ('64000000-0000-0000-0000-000000000003', '62000000-0000-0000-0000-000000000003', '63000000-0000-0000-0000-000000000001', 'مصروف البيت', 'flexible', 3000),
  ('64000000-0000-0000-0000-000000000004', '62000000-0000-0000-0000-000000000003', '63000000-0000-0000-0000-000000000002', 'قسم للعرض فقط', 'flexible', 1000),
  ('64000000-0000-0000-0000-000000000005', '62000000-0000-0000-0000-000000000003', '63000000-0000-0000-0000-000000000003', 'قسم خاص', 'flexible', 1000),
  ('64000000-0000-0000-0000-000000000006', '62000000-0000-0000-0000-000000000004', '63000000-0000-0000-0000-000000000004', 'قسم أسرة أخرى', 'flexible', 1000);

update public.budget_periods set spending_budget = 3000 where id = '62000000-0000-0000-0000-000000000003';

-- Existing spend fixture for the overspend scenarios (fixture-only direct insert, outside the
-- authenticated role, exactly like financial_planning.test.sql's own overspend fixtures).
insert into public.transactions (period_id, period_section_budget_id, amount, occurred_at, state, created_by)
values ('62000000-0000-0000-0000-000000000003', '64000000-0000-0000-0000-000000000003', 2900, now(), 'posted', '60000000-0000-0000-0000-000000000001');

-- Grants: anon must never execute record_expense; authenticated must never directly INSERT.
select ok(not has_function_privilege('anon','public.record_expense(uuid,numeric,date,text,uuid)','execute'), 'anon cannot execute record_expense');
select ok(not has_table_privilege('authenticated','public.transactions','insert'), 'authenticated clients cannot directly insert transactions');

set local role anon;
select throws_ok($$select public.record_expense('64000000-0000-0000-0000-000000000003', 100)$$, '42501', null, 'anonymous callers cannot record an expense');
reset role;

-- === Owner: normal expense on the Open period ===
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '60000000-0000-0000-0000-000000000001', true);

select public.record_expense('64000000-0000-0000-0000-000000000003', 500) as owner_txn_id \gset
select is((select amount from public.transactions where id=:'owner_txn_id'), 500::numeric, 'owner expense recorded with correct amount');
select is((select created_by from public.transactions where id=:'owner_txn_id'), '60000000-0000-0000-0000-000000000001'::uuid, 'created_by cannot be spoofed: it is always the caller');
select is((select period_section_budget_id from public.transactions where id=:'owner_txn_id'), '64000000-0000-0000-0000-000000000003'::uuid, 'expense linked to the requested section snapshot');

-- Section overspend: allocation 3000, existing spend 2900, +500 -> 3400 spent, -400 remaining. Must succeed.
select is((select coalesce(sum(amount),0) from public.transactions where period_section_budget_id='64000000-0000-0000-0000-000000000003' and state='posted'), 3400::numeric, 'section overspend accepted: spent = 3400');
select is((select planned_amount - coalesce(sum(t.amount),0) from public.period_section_budgets psb left join public.transactions t on t.period_section_budget_id=psb.id and t.state='posted' where psb.id='64000000-0000-0000-0000-000000000003' group by psb.planned_amount), -400::numeric, 'section remaining is negative and meaningful, not blocked');

-- Total budget overspend: spending_budget=3000, actual variable spend already 3400 -> negative budget_remaining.
select is((select budget_remaining from public.get_owner_period_planning_summary('62000000-0000-0000-0000-000000000003')), -400::numeric, 'total budget overspend accepted: budget_remaining negative');

-- Date bounds: default (today) accepted.
select lives_ok($$select public.record_expense('64000000-0000-0000-0000-000000000003', 10)$$, 'default date (today) is accepted');
-- An earlier valid date still inside the open period.
select lives_ok($$select public.record_expense('64000000-0000-0000-0000-000000000003', 10, ((now() at time zone 'UTC')::date - 5))$$, 'an earlier valid date within the open period is accepted');
-- Before period start.
select throws_ok($$select public.record_expense('64000000-0000-0000-0000-000000000003', 10, ((now() at time zone 'UTC')::date - 11))$$, '22003', 'expense_date_out_of_period', 'a date before the period start is rejected');
-- After period end.
select throws_ok($$select public.record_expense('64000000-0000-0000-0000-000000000003', 10, ((now() at time zone 'UTC')::date + 11))$$, '22003', 'expense_date_out_of_period', 'a date after the period end is rejected');
-- Future date that is still within the period's end boundary (isolates the future-date check).
select throws_ok($$select public.record_expense('64000000-0000-0000-0000-000000000003', 10, ((now() at time zone 'UTC')::date + 1))$$, '22003', 'expense_date_in_future', 'a future date is rejected even though still inside the period range');

-- Invalid amounts.
select throws_ok($$select public.record_expense('64000000-0000-0000-0000-000000000003', 0)$$, '22003', 'invalid_amount', 'a zero amount is rejected');
select throws_ok($$select public.record_expense('64000000-0000-0000-0000-000000000003', -50)$$, '22003', 'invalid_amount', 'a negative amount is rejected');
select throws_ok($$select public.record_expense('64000000-0000-0000-0000-000000000003', 10, null, repeat('x', 501))$$, '22001', 'invalid_description', 'an overlong description is rejected');

-- Lifecycle: Draft and Closed periods reject expense creation; Open accepts (already proven above).
select throws_ok($$select public.record_expense('64000000-0000-0000-0000-000000000001', 10)$$, 'P0001', 'period_not_open', 'Draft period rejects expense creation');
select throws_ok($$select public.record_expense('64000000-0000-0000-0000-000000000002', 10)$$, 'P0001', 'period_not_open', 'Closed period rejects expense creation');

-- Unknown/bogus section snapshot id.
select throws_ok($$select public.record_expense('00000000-0000-0000-0000-000000000000', 10)$$, 'P0002', 'section_budget_not_found', 'a nonexistent section snapshot id is rejected');

-- Idempotent retry: same caller-supplied transaction id must not duplicate.
select public.record_expense('64000000-0000-0000-0000-000000000003', 77, null, null, '65000000-0000-0000-0000-000000000001') as retry_txn_id_1 \gset
select public.record_expense('64000000-0000-0000-0000-000000000003', 77, null, null, '65000000-0000-0000-0000-000000000001') as retry_txn_id_2 \gset
select is(:'retry_txn_id_2'::uuid, :'retry_txn_id_1'::uuid, 'retrying with the same transaction id returns the same row');
select is((select count(*)::integer from public.transactions where id='65000000-0000-0000-0000-000000000001'), 1, 'retry does not duplicate the expense row');

-- A different caller-supplied id creates a genuinely distinct expense.
select public.record_expense('64000000-0000-0000-0000-000000000003', 88, null, null, '65000000-0000-0000-0000-000000000002') as distinct_txn_id \gset
select isnt(:'distinct_txn_id'::uuid, '65000000-0000-0000-0000-000000000001'::uuid, 'a different transaction id creates a distinct expense');

reset role;

-- Cross-household id-reuse: owner1 cannot attach a new expense to a transaction id that
-- already belongs to household 2.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '60000000-0000-0000-0000-000000000003', true);
select public.record_expense('64000000-0000-0000-0000-000000000006', 20, null, null, '65000000-0000-0000-0000-000000000003');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '60000000-0000-0000-0000-000000000001', true);
select throws_ok($$select public.record_expense('64000000-0000-0000-0000-000000000003', 20, null, null, '65000000-0000-0000-0000-000000000003')$$, '23505', 'transaction_id_conflict', 'reusing a transaction id from another household is rejected');
reset role;

-- === Member ===
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '60000000-0000-0000-0000-000000000002', true);

select public.record_expense('64000000-0000-0000-0000-000000000003', 250) as member_txn_id \gset
select is((select created_by from public.transactions where id=:'member_txn_id'), '60000000-0000-0000-0000-000000000002'::uuid, 'authorized member expense is attributed to the member, not the owner');

select throws_ok($$select public.record_expense('64000000-0000-0000-0000-000000000004', 10)$$, '42501', 'not_authorized', 'a member cannot record an expense in a view-only section');
select throws_ok($$select public.record_expense('64000000-0000-0000-0000-000000000005', 10)$$, '42501', 'not_authorized', 'a member cannot record an expense in a hidden (owner_only) section');
select throws_ok($$select public.record_expense('64000000-0000-0000-0000-000000000006', 10)$$, '42501', 'not_authorized', 'a member cannot record an expense in another household''s section');
reset role;

-- === Fixed-commitment double-count regression (unchanged by record_expense) ===
insert into public.fixed_commitment_templates (id, household_id, name, default_amount, created_by)
values ('66000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000001', 'إيجار', 1000, '60000000-0000-0000-0000-000000000001');
insert into public.period_fixed_commitments (id, period_id, fixed_commitment_template_id, name_snapshot, planned_amount, status, created_by)
values ('67000000-0000-0000-0000-000000000001', '62000000-0000-0000-0000-000000000003', '66000000-0000-0000-0000-000000000001', 'إيجار', 1000, 'pending', '60000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '60000000-0000-0000-0000-000000000001', true);
select public.mark_period_fixed_commitment_paid('67000000-0000-0000-0000-000000000001', 1000);
select is((select actual_fixed_commitment_outflow from public.get_owner_period_planning_summary('62000000-0000-0000-0000-000000000003')), 1000::numeric, 'paid fixed commitment contributes exactly its own fixed actual outflow');
-- Running total for section 64...003 by this point: 2900 (fixture) + 500 + 10 + 10 + 77 + 88
-- (owner) + 250 (member) = 3835. No other section in this period received any transaction.
select is((select actual_variable_spending_total from public.get_owner_period_planning_summary('62000000-0000-0000-0000-000000000003')), 3835::numeric, 'record_expense variable spending is unaffected by the fixed commitment payment');
reset role;

select * from finish();
rollback;
