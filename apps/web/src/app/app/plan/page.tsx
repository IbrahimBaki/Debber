import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

import { ClosedPanel } from "./closed-panel";
import { PlanClient } from "./plan-client";

export default async function PlanPage() {
  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();
  if (claimsError || !claims?.claims?.sub) redirect("/login?next=/app/plan");
  const uid = claims.claims.sub;

  // Role is checked before any Owner-only data is ever requested: a Member must never
  // reach ensure_budget_period()/get_owner_period_planning_summary() to be rejected there.
  const { data: membership } = await supabase
    .from("household_members")
    .select("household_id, role")
    .eq("user_id", uid)
    .eq("status", "active")
    .order("joined_at", { ascending: true })
    .limit(1)
    .maybeSingle();

  if (!membership) redirect("/app");
  if (membership.role !== "owner") redirect("/app");

  const { data: household } = await supabase
    .from("households")
    .select("id, name, currency_code, period_start_day, timezone")
    .eq("id", membership.household_id)
    .maybeSingle();
  if (!household) redirect("/app");

  const { data: periodId, error: periodError } = await supabase.rpc("ensure_budget_period", {
    p_household_id: household.id,
  });
  if (periodError || !periodId) redirect("/app");

  const { data: period } = await supabase
    .from("budget_periods")
    .select("id, period_key, start_date, end_date, status, spending_budget")
    .eq("id", periodId)
    .maybeSingle();
  if (!period) redirect("/app");

  if (period.status === "closed") {
    return <ClosedPanel householdName={household.name} periodStart={period.start_date} periodEnd={period.end_date} />;
  }

  const [{ data: summaryRows }, { data: income }, { data: commitments }, { data: sections }, { data: templates }] =
    await Promise.all([
      supabase.rpc("get_owner_period_planning_summary", { p_period_id: period.id }),
      supabase
        .from("period_income_items")
        .select("id, name_snapshot, planned_amount")
        .eq("period_id", period.id)
        .order("created_at", { ascending: true }),
      supabase
        .from("period_fixed_commitments")
        .select("id, name_snapshot, planned_amount, status, fixed_commitment_template_id, created_at")
        .eq("period_id", period.id)
        .order("created_at", { ascending: true }),
      supabase
        .from("period_section_budgets")
        .select("id, section_id, section_name_snapshot, planned_amount")
        .eq("period_id", period.id)
        .order("created_at", { ascending: true }),
      supabase
        .from("fixed_commitment_templates")
        .select("id, is_active")
        .eq("household_id", household.id),
    ]);

  const summary = summaryRows?.[0] ?? null;
  const activeTemplateIds = new Set((templates ?? []).filter((template) => template.is_active).map((template) => template.id));

  return (
    <PlanClient
      mode={period.status === "open" ? "open" : "draft"}
      household={household}
      period={{ id: period.id, periodKey: period.period_key, startDate: period.start_date, endDate: period.end_date }}
      summary={summary}
      income={income ?? []}
      commitments={(commitments ?? []).map((commitment) => ({
        ...commitment,
        isRecurringActive: commitment.fixed_commitment_template_id
          ? activeTemplateIds.has(commitment.fixed_commitment_template_id)
          : false,
      }))}
      sections={sections ?? []}
    />
  );
}
