import type { createClient } from "@/lib/supabase/server";

import type { ResolvedPeriod } from "./period-context";

export type MemberSection = {
  id: string; // period_section_budget_id -- what record_expense expects
  sectionId: string;
  name: string;
  allocated: number;
  spent: number;
  remaining: number;
  overspent: boolean;
  canContribute: boolean;
};

export type MemberMonthlyView =
  | { status: "no_period" }
  | { status: "draft"; periodStart: string; periodEnd: string }
  | {
      status: "open" | "closed";
      periodStart: string;
      periodEnd: string;
      spendingBudget: number;
      totalIncome: number | null;
      sections: MemberSection[];
      sharedSummary: { allocated: number; spent: number; remaining: number };
      canRecordExpense: boolean;
    };

/**
 * Loads everything the Member Monthly View needs, entirely through the caller's own
 * RLS-scoped session -- never a service-role bypass. Fixed commitments, the Owner planning
 * summary, and individual income rows are never queried here: they simply do not exist on
 * this surface. `period_section_budgets`/`budget_sections`/`transactions` RLS
 * (can_view_section(...)) already returns only what this specific Member is authorized to
 * see, so this function does not re-derive visibility -- it only shapes and sums what RLS
 * already handed back.
 *
 * `period` is resolved once per request by the caller (see ./period-context.ts); this function
 * no longer calls ensure_budget_period(...) itself.
 */
export async function loadMemberMonthlyView(
  supabase: Awaited<ReturnType<typeof createClient>>,
  household: { id: string },
  period: ResolvedPeriod | null,
): Promise<MemberMonthlyView> {
  if (!period) return { status: "no_period" };

  if (period.status === "draft") {
    return { status: "draft", periodStart: period.startDate, periodEnd: period.endDate };
  }

  const [{ data: sectionRows }, totalIncomeResult] = await Promise.all([
    supabase
      .from("period_section_budgets")
      .select("id, section_id, section_name_snapshot, planned_amount, budget_sections(visibility_scope, member_access)")
      .eq("period_id", period.id)
      .eq("section_kind_snapshot", "flexible")
      .order("created_at", { ascending: true }),
    supabase.rpc("get_member_visible_total_income", { p_period_id: period.id }),
  ]);

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

  const sections: MemberSection[] = rows.map((row) => {
    const meta = Array.isArray(row.budget_sections) ? row.budget_sections[0] : row.budget_sections;
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
      canContribute: meta?.visibility_scope === "household" && meta?.member_access === "contribute",
    };
  });

  const sharedAllocated = sections.reduce((sum, s) => sum + s.allocated, 0);
  const sharedSpent = sections.reduce((sum, s) => sum + s.spent, 0);

  // Any error (including a rejected/expired session mid-request) is treated identically to
  // "not shared": this RPC's only two safe outcomes for a Member are a real number or an
  // absence, and an absence must never look like a distinct error state (see docs/PERMISSIONS.md).
  const totalIncome =
    totalIncomeResult.error || totalIncomeResult.data === null || totalIncomeResult.data === undefined
      ? null
      : Number(totalIncomeResult.data);

  return {
    status: period.status === "closed" ? "closed" : "open",
    periodStart: period.startDate,
    periodEnd: period.endDate,
    spendingBudget: period.spendingBudget,
    totalIncome,
    sections,
    sharedSummary: { allocated: sharedAllocated, spent: sharedSpent, remaining: sharedAllocated - sharedSpent },
    canRecordExpense: period.status === "open" && sections.some((s) => s.canContribute),
  };
}
