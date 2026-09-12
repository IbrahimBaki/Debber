import type { createClient } from "@/lib/supabase/server";

export type SectionExpense = {
  id: string;
  amount: number;
  description: string | null;
  occurredAt: string;
};

export type SectionDetailView =
  | { status: "not_found" }
  | {
      status: "found";
      householdName: string;
      role: "owner" | "member";
      sectionName: string;
      currencyCode: string;
      periodStatus: "draft" | "open" | "closed";
      allocated: number;
      spent: number;
      remaining: number;
      overspent: boolean;
      expenses: SectionExpense[];
      canRecordExpense: boolean;
    };

/**
 * Loads one period-specific flexible section for its detail route
 * (/app/sections/[periodSectionBudgetId]). Authorization is entirely RLS-driven: the
 * period_section_budgets select policy is `using (can_view_section(section_id))`, which
 * already returns false (no row) for a cross-Household id, a hidden owner_only section for a
 * Member, and an anonymous/unauthenticated caller alike -- so a single `.maybeSingle()` miss
 * is the one safe "not found" outcome for every one of those cases, with no distinguishing
 * information leaked. No service-role client, no pre-fetch-then-filter.
 *
 * `uid` is required for the household_members lookup specifically: that table's RLS policy
 * (`is_household_member(household_id)`) grants a caller read access to every membership row in
 * their own Household, not just their own row, so the query must filter by `user_id` itself --
 * omitting it let `.maybeSingle()` see more than one row in any Household with more than one
 * active member (i.e. any Household with a Member at all) and silently resolve to `not_found`.
 */
export async function loadSectionDetail(
  supabase: Awaited<ReturnType<typeof createClient>>,
  periodSectionBudgetId: string,
  uid: string,
): Promise<SectionDetailView> {
  const { data: psb } = await supabase
    .from("period_section_budgets")
    .select("id, planned_amount, section_name_snapshot, section_kind_snapshot, section_id, period_id")
    .eq("id", periodSectionBudgetId)
    .maybeSingle();

  // Fixed-kind snapshots exist for every household section (ensure_budget_period creates one
  // regardless of kind) but are not a section detail surface -- fixed commitments have their
  // own owner-only execution surface and never produce transactions.
  if (!psb || psb.section_kind_snapshot !== "flexible") return { status: "not_found" };

  const { data: period } = await supabase
    .from("budget_periods")
    .select("id, status, household_id")
    .eq("id", psb.period_id)
    .maybeSingle();
  if (!period) return { status: "not_found" };

  const [{ data: household }, { data: sectionMeta }, { data: membership }, { data: txRows }] = await Promise.all([
    supabase.from("households").select("name, currency_code").eq("id", period.household_id).maybeSingle(),
    supabase.from("budget_sections").select("visibility_scope, member_access").eq("id", psb.section_id).maybeSingle(),
    supabase
      .from("household_members")
      .select("role")
      .eq("household_id", period.household_id)
      .eq("user_id", uid)
      .eq("status", "active")
      .maybeSingle(),
    supabase
      .from("transactions")
      .select("id, amount, description, occurred_at")
      .eq("period_section_budget_id", periodSectionBudgetId)
      .eq("state", "posted")
      .order("occurred_at", { ascending: false }),
  ]);

  if (!household || !sectionMeta || !membership) return { status: "not_found" };

  const spent = (txRows ?? []).reduce((sum, row) => sum + Number(row.amount), 0);
  const allocated = Number(psb.planned_amount);
  const remaining = allocated - spent;

  const isOwner = membership.role === "owner";
  const canContribute =
    isOwner || (sectionMeta.visibility_scope === "household" && sectionMeta.member_access === "contribute");

  return {
    status: "found",
    householdName: household.name,
    role: isOwner ? "owner" : "member",
    sectionName: psb.section_name_snapshot,
    currencyCode: household.currency_code,
    periodStatus: period.status,
    allocated,
    spent,
    remaining,
    overspent: remaining < 0,
    expenses: (txRows ?? []).map((row) => ({
      id: row.id,
      amount: Number(row.amount),
      description: row.description,
      occurredAt: row.occurred_at,
    })),
    canRecordExpense: period.status === "open" && canContribute,
  };
}
