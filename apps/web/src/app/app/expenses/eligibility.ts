import type { createClient } from "@/lib/supabase/server";

import type { ResolvedPeriod } from "../period-context";

export type EligibleSection = {
  id: string; // period_section_budget_id -- the id record_expense expects
  sectionId: string;
  name: string;
  allocated: number;
  spent: number;
};

export type ExpenseEligibility =
  | { status: "no_period" }
  | { status: "not_open"; periodStatus: "draft" | "closed" }
  | {
      status: "open";
      periodId: string;
      periodStart: string;
      periodEnd: string;
      today: string;
      sections: EligibleSection[];
    };

/**
 * The single authoritative place that decides which flexible sections a user may record an
 * expense into, for a given Household. Both the /app landing CTA and /app/expenses/new call
 * this so the security-sensitive filtering logic exists in exactly one place.
 *
 * Owner: every flexible section snapshot in the current period (RLS already grants full
 * visibility via is_household_owner()).
 *
 * Member: only sections where visibility_scope = 'household' and member_access = 'contribute'
 * -- the exact condition can_contribute_to_section() checks for the 'household' scope. Both
 * queries below run under the caller's own RLS-scoped session, so a Member never receives a
 * row for an owner_only/hidden section at all (can_view_section already blocks it before this
 * function's own filtering ever runs). 'custom' visibility_scope sections are not evaluated
 * here: there is no UI anywhere yet for an Owner to grant a resource_permissions custom edit
 * grant, so a Member can never actually hold one today. If that changes, this is the one place
 * to extend. Excluding a hypothetical custom-granted section is a UX gap (they wouldn't see it
 * in the selector), never a privacy or authorization gap: record_expense() re-derives
 * authorization itself regardless of what this selector shows.
 *
 * `period` is resolved once per request by the caller (see ../period-context.ts); this function
 * no longer calls ensure_budget_period(...) itself.
 */
export async function resolveExpenseEligibility(
  supabase: Awaited<ReturnType<typeof createClient>>,
  household: { id: string; timezone: string },
  role: "owner" | "member",
  period: ResolvedPeriod | null,
): Promise<ExpenseEligibility> {
  if (!period) return { status: "no_period" };

  if (period.status !== "open") {
    return { status: "not_open", periodStatus: period.status === "closed" ? "closed" : "draft" };
  }

  const { data: sectionRows } = await supabase
    .from("period_section_budgets")
    .select("id, section_id, section_name_snapshot, planned_amount")
    .eq("period_id", period.id)
    .eq("section_kind_snapshot", "flexible");

  let eligibleRows = sectionRows ?? [];

  if (role === "member") {
    const sectionIds = eligibleRows.map((row) => row.section_id);
    const metaById = new Map<string, { visibility_scope: string; member_access: string }>();
    if (sectionIds.length > 0) {
      const { data: sectionMeta } = await supabase
        .from("budget_sections")
        .select("id, visibility_scope, member_access")
        .in("id", sectionIds);
      for (const section of sectionMeta ?? []) {
        metaById.set(section.id, { visibility_scope: section.visibility_scope, member_access: section.member_access });
      }
    }
    eligibleRows = eligibleRows.filter((row) => {
      const meta = metaById.get(row.section_id);
      return meta?.visibility_scope === "household" && meta?.member_access === "contribute";
    });
  }

  const spentByBudgetId = new Map<string, number>();
  const eligibleIds = eligibleRows.map((row) => row.id);
  if (eligibleIds.length > 0) {
    const { data: txRows } = await supabase
      .from("transactions")
      .select("period_section_budget_id, amount")
      .eq("period_id", period.id)
      .eq("state", "posted")
      .in("period_section_budget_id", eligibleIds);
    for (const row of txRows ?? []) {
      spentByBudgetId.set(row.period_section_budget_id, (spentByBudgetId.get(row.period_section_budget_id) ?? 0) + Number(row.amount));
    }
  }

  const today = new Intl.DateTimeFormat("en-CA", { timeZone: household.timezone }).format(new Date());

  return {
    status: "open",
    periodId: period.id,
    periodStart: period.startDate,
    periodEnd: period.endDate,
    today,
    sections: eligibleRows.map((row) => ({
      id: row.id,
      sectionId: row.section_id,
      name: row.section_name_snapshot,
      allocated: Number(row.planned_amount),
      spent: spentByBudgetId.get(row.id) ?? 0,
    })),
  };
}
