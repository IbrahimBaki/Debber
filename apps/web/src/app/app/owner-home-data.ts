import type { createClient } from "@/lib/supabase/server";

import type { ResolvedPeriod } from "./period-context";

export type OwnerSection = {
  id: string; // period_section_budget_id
  sectionId: string;
  name: string;
  allocated: number;
  spent: number;
  remaining: number;
  overspent: boolean;
};

export type OwnerHomeView =
  | { status: "no_period" }
  | { status: "draft"; periodStart: string; periodEnd: string }
  | {
      status: "open" | "closed";
      periodStart: string;
      periodEnd: string;
      spendingBudget: number;
      actualVariableSpending: number;
      budgetRemaining: number;
      sections: OwnerSection[];
    };

/**
 * Loads the Owner's daily-dashboard data for the current Budget Period. The hero figures
 * (spendingBudget/actualVariableSpending/budgetRemaining) come from
 * get_owner_period_planning_summary(...) -- the canonical whole-period variable-budget
 * formula -- never from summing section allocations, which may total less than the spending
 * budget (unallocated budget). Section cards are a separate, additional read of the exact
 * same flexible period_section_budgets/transactions rows the rest of the app already uses.
 *
 * `period` is resolved once per request by the caller (see ./period-context.ts); this function
 * no longer calls ensure_budget_period(...) itself.
 */
export async function loadOwnerHomeView(
  supabase: Awaited<ReturnType<typeof createClient>>,
  household: { id: string },
  period: ResolvedPeriod | null,
): Promise<OwnerHomeView> {
  if (!period) return { status: "no_period" };

  if (period.status === "draft") {
    return { status: "draft", periodStart: period.startDate, periodEnd: period.endDate };
  }

  const [{ data: summaryRows }, { data: sectionRows }] = await Promise.all([
    supabase.rpc("get_owner_period_planning_summary", { p_period_id: period.id }),
    supabase
      .from("period_section_budgets")
      .select("id, section_id, section_name_snapshot, planned_amount")
      .eq("period_id", period.id)
      .eq("section_kind_snapshot", "flexible")
      .order("created_at", { ascending: true }),
  ]);

  const summary = summaryRows?.[0] ?? null;
  const rows = sectionRows ?? [];
  const budgetIds = rows.map((row) => row.id);

  const spentByBudgetId = new Map<string, number>();
  if (budgetIds.length > 0) {
    const { data: txRows } = await supabase
      .from("transactions")
      .select("period_section_budget_id, amount")
      .eq("period_id", period.id)
      .eq("state", "posted")
      .in("period_section_budget_id", budgetIds);
    for (const row of txRows ?? []) {
      spentByBudgetId.set(
        row.period_section_budget_id,
        (spentByBudgetId.get(row.period_section_budget_id) ?? 0) + Number(row.amount),
      );
    }
  }

  const sections: OwnerSection[] = rows.map((row) => {
    const allocated = Number(row.planned_amount);
    const spent = spentByBudgetId.get(row.id) ?? 0;
    const remaining = allocated - spent;
    return {
      id: row.id,
      sectionId: row.section_id,
      name: row.section_name_snapshot,
      allocated,
      spent,
      remaining,
      overspent: remaining < 0,
    };
  });

  return {
    status: period.status === "closed" ? "closed" : "open",
    periodStart: period.startDate,
    periodEnd: period.endDate,
    spendingBudget: Number(summary?.spending_budget ?? 0),
    actualVariableSpending: Number(summary?.actual_variable_spending_total ?? 0),
    budgetRemaining: Number(summary?.budget_remaining ?? 0),
    sections,
  };
}
