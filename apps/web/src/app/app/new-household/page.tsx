import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { CreateHouseholdForm } from "@/app/app/new-household/create-household-form";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = { title: "إنشاء بيت جديد" };

export default async function NewHouseholdPage() {
  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();
  if (claimsError || !claims?.claims?.sub) redirect("/login?next=/app");

  const { data: membership } = await supabase
    .from("household_members")
    .select("household_id")
    .eq("user_id", claims.claims.sub)
    .eq("status", "active")
    .limit(1)
    .maybeSingle();
  if (membership) redirect("/app");

  const { data: invitations } = await supabase.rpc("list_my_pending_household_invitations");
  if (invitations?.length) redirect("/app/invitations");

  return <CreateHouseholdForm />;
}
