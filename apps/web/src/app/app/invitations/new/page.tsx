import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

import { AppShell, type AppNavContext } from "../../app-shell";
import { resolveExpenseEligibility } from "../../expenses/eligibility";
import { resolveCurrentPeriod } from "../../period-context";
import { InvitePartnerForm } from "./invite-partner-form";

export const metadata: Metadata = { title: "دعوة شريك" };

export default async function InviteMemberPage() {
  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();
  if (claimsError || !claims?.claims?.sub) redirect("/login?next=/app/invitations/new");

  // Role is checked before any Owner-only data is fetched: a Member navigating here directly
  // must never receive the invite form (or a rendered-then-hidden version of it).
  const { data: membership } = await supabase
    .from("household_members")
    .select("household_id, role")
    .eq("user_id", claims.claims.sub)
    .eq("status", "active")
    .order("joined_at", { ascending: true })
    .limit(1)
    .maybeSingle();

  if (!membership) redirect("/app");
  if (membership.role !== "owner") redirect("/app");

  const { data: household } = await supabase
    .from("households")
    .select("id, name, timezone")
    .eq("id", membership.household_id)
    .maybeSingle();
  if (!household) redirect("/app");

  const period = await resolveCurrentPeriod(supabase, household.id);
  const eligibility = await resolveExpenseEligibility(supabase, household, "owner", period);
  const nav: AppNavContext = {
    role: "owner",
    periodStatus: eligibility.status === "not_open" ? eligibility.periodStatus : eligibility.status === "open" ? "open" : "no_period",
    canRecordExpense: eligibility.status === "open" && eligibility.sections.length > 0,
  };

  return (
    <AppShell nav={nav} householdName={household.name}>
      <InvitePartnerForm householdId={household.id} householdName={household.name} />
    </AppShell>
  );
}
