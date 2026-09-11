-- Migration: 20260911141955_extend_fixed_commitment_immutability
-- Purpose: Close a pre-existing gap where enforce_immutable_scope_fields() protected
-- every sibling persistent/monthly-snapshot table pair (income_sources/period_income_items,
-- budget_sections/period_section_budgets, recurring_templates/monthly_items) except
-- fixed_commitment_templates and period_fixed_commitments, which were left unprotected
-- against legitimate users moving a historical or scoped row across a security boundary
-- via UPDATE.
-- Risk: New trigger coverage only. Columns frozen are chosen by direct analogy to
-- sibling tables and cannot be reached by any approved RPC's UPDATE statement today:
--   fixed_commitment_templates: household_id, created_by (same set as recurring_templates,
--     income_sources, budget_sections).
--   period_fixed_commitments: period_id, fixed_commitment_template_id, created_by (same
--     shape as period_income_items' period_id/income_source_id/created_by).
-- planned_amount, actual_amount, status, name_snapshot and due_date remain mutable,
-- matching monthly_items' and period_income_items' choice not to freeze their equivalent
-- fields. mark_period_fixed_commitment_paid, set_period_fixed_commitment_planned_amount,
-- and set_period_fixed_commitment_skipped only ever update those columns, never the
-- newly-frozen ones, so no approved operation is affected.
-- Data migration: None.
-- Rollback: Forward migration only. Do not delete migration history.

CREATE OR REPLACE FUNCTION public.enforce_immutable_scope_fields()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
begin
  if tg_table_name = 'budget_periods' then
    if new.household_id is distinct from old.household_id
       or new.period_key is distinct from old.period_key
       or new.start_date is distinct from old.start_date
       or new.end_date is distinct from old.end_date
       or new.created_by is distinct from old.created_by then
      raise exception 'immutable_budget_period_scope' using errcode = '23514';
    end if;
  elsif tg_table_name = 'income_sources' then
    if new.household_id is distinct from old.household_id
       or new.created_by is distinct from old.created_by then
      raise exception 'immutable_income_source_scope' using errcode = '23514';
    end if;
  elsif tg_table_name = 'period_income_items' then
    if new.period_id is distinct from old.period_id
       or new.income_source_id is distinct from old.income_source_id
       or new.created_by is distinct from old.created_by then
      raise exception 'immutable_period_income_scope' using errcode = '23514';
    end if;
  elsif tg_table_name = 'budget_sections' then
    if new.household_id is distinct from old.household_id
       or new.created_by is distinct from old.created_by then
      raise exception 'immutable_budget_section_scope' using errcode = '23514';
    end if;
  elsif tg_table_name = 'period_section_budgets' then
    if new.period_id is distinct from old.period_id
       or new.section_id is distinct from old.section_id then
      raise exception 'immutable_period_section_scope' using errcode = '23514';
    end if;
  elsif tg_table_name = 'recurring_templates' then
    if new.household_id is distinct from old.household_id
       or new.created_by is distinct from old.created_by then
      raise exception 'immutable_recurring_template_scope' using errcode = '23514';
    end if;
  elsif tg_table_name = 'fixed_commitment_templates' then
    if new.household_id is distinct from old.household_id
       or new.created_by is distinct from old.created_by then
      raise exception 'immutable_fixed_commitment_template_scope' using errcode = '23514';
    end if;
  elsif tg_table_name = 'period_fixed_commitments' then
    if new.period_id is distinct from old.period_id
       or new.fixed_commitment_template_id is distinct from old.fixed_commitment_template_id
       or new.created_by is distinct from old.created_by then
      raise exception 'immutable_period_fixed_commitment_scope' using errcode = '23514';
    end if;
  elsif tg_table_name = 'monthly_items' then
    if new.period_id is distinct from old.period_id
       or new.period_section_budget_id is distinct from old.period_section_budget_id
       or new.recurring_template_id is distinct from old.recurring_template_id
       or new.created_by is distinct from old.created_by then
      raise exception 'immutable_monthly_item_scope' using errcode = '23514';
    end if;
  elsif tg_table_name = 'transactions' then
    if new.period_id is distinct from old.period_id
       or new.monthly_item_id is distinct from old.monthly_item_id
       or new.created_by is distinct from old.created_by then
      raise exception 'immutable_transaction_scope' using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

CREATE TRIGGER fixed_commitment_templates_immutable_scope BEFORE UPDATE ON public.fixed_commitment_templates
FOR EACH ROW EXECUTE FUNCTION public.enforce_immutable_scope_fields();

CREATE TRIGGER period_fixed_commitments_immutable_scope BEFORE UPDATE ON public.period_fixed_commitments
FOR EACH ROW EXECUTE FUNCTION public.enforce_immutable_scope_fields();
