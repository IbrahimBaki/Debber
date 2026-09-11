import type { createClient } from "@/lib/supabase/server";

export type OwnerCommitment = {
  id: string;
  name: string;
  plannedAmount: number;
  actualAmount: number | null;
  status: "pending" | "paid" | "skipped";
  dueDate: string | null;
  overdue: boolean;
};

export type OwnerCommitmentsView =
  | { status: "no_period" }
  | {
      status: "draft" | "open" | "closed";
      commitments: OwnerCommitment[];
      plannedTotal: number;
      paidTotal: number;
      pendingTotal: number;
      skippedTotal: number;
    };

/**
 * Owner-only fixed-commitment execution data for the current Budget Period. Relies entirely
 * on the existing RLS grant on period_fixed_commitments (Owner-only select) -- a Member
 * calling this same code path receives zero rows, never an error that would reveal anything.
 * Every bucketed total below is a plain sum of the exact rows returned, never a re-derivation
 * of the deeper income/budget arithmetic that already has one canonical source
 * (get_owner_period_planning_summary), which this loader intentionally does not duplicate.
 */
export async function loadOwnerCommitments(
  supabase: Awaited<ReturnType<typeof createClient>>,
  household: { id: string; timezone: string },
): Promise<OwnerCommitmentsView> {
  const { data: periodId, error: periodError } = await supabase.rpc("ensure_budget_period", {
    p_household_id: household.id,
  });
  if (periodError || !periodId) return { status: "no_period" };

  const { data: period } = await supabase
    .from("budget_periods")
    .select("id, status")
    .eq("id", periodId)
    .maybeSingle();
  if (!period) return { status: "no_period" };

  const { data: rows } = await supabase
    .from("period_fixed_commitments")
    .select("id, name_snapshot, planned_amount, actual_amount, status, due_date")
    .eq("period_id", period.id)
    .order("created_at", { ascending: true });

  const today = new Intl.DateTimeFormat("en-CA", { timeZone: household.timezone }).format(new Date());

  const commitments: OwnerCommitment[] = (rows ?? []).map((row) => ({
    id: row.id,
    name: row.name_snapshot,
    plannedAmount: Number(row.planned_amount),
    actualAmount: row.actual_amount === null ? null : Number(row.actual_amount),
    status: row.status,
    dueDate: row.due_date,
    overdue: row.status === "pending" && row.due_date !== null && row.due_date < today,
  }));

  const plannedTotal = commitments.filter((c) => c.status !== "skipped").reduce((sum, c) => sum + c.plannedAmount, 0);
  const paidTotal = commitments.filter((c) => c.status === "paid").reduce((sum, c) => sum + (c.actualAmount ?? 0), 0);
  const pendingTotal = commitments.filter((c) => c.status === "pending").reduce((sum, c) => sum + c.plannedAmount, 0);
  const skippedTotal = commitments.filter((c) => c.status === "skipped").reduce((sum, c) => sum + c.plannedAmount, 0);

  return {
    status: period.status,
    commitments,
    plannedTotal,
    paidTotal,
    pendingTotal,
    skippedTotal,
  };
}
