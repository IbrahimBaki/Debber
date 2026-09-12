import type { createClient } from "@/lib/supabase/server";

export type ResolvedPeriod = {
  id: string;
  startDate: string;
  endDate: string;
  status: "draft" | "open" | "closed";
  spendingBudget: number;
};

/**
 * Resolves the Household's current Budget Period exactly once per request. Previously,
 * resolveExpenseEligibility, loadOwnerCommitments, and loadOwnerHomeView (loadMemberMonthlyView
 * for a Member) each independently called ensure_budget_period(...) and re-fetched the same
 * budget_periods row -- three round trips to the same RPC plus three identical selects on a
 * single /app render for an Owner (two for a Member). ensure_budget_period(...) is idempotent
 * and side-effect-free on repeat calls within the same period, so calling it three times never
 * produced different data, only three extra sequential network round trips. Resolving it once
 * here and passing the result into each loader is a pure application-layer consolidation: every
 * loader's own status-branching logic (draft/open/closed/no_period) is unchanged, and
 * ensure_budget_period's own semantics are untouched.
 */
export async function resolveCurrentPeriod(
  supabase: Awaited<ReturnType<typeof createClient>>,
  householdId: string,
): Promise<ResolvedPeriod | null> {
  const { data: periodId, error: periodError } = await supabase.rpc("ensure_budget_period", {
    p_household_id: householdId,
  });
  if (periodError || !periodId) return null;

  const { data: period } = await supabase
    .from("budget_periods")
    .select("id, start_date, end_date, status, spending_budget")
    .eq("id", periodId)
    .maybeSingle();
  if (!period) return null;

  return {
    id: period.id,
    startDate: period.start_date,
    endDate: period.end_date,
    status: period.status,
    spendingBudget: Number(period.spending_budget),
  };
}
