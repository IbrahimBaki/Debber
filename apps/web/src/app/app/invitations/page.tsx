import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { InvitationFlow } from "@/app/app/invitations/invitation-flow";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = { title: "دعوة انضمام" };

export default async function InvitationsPage() {
  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();
  if (claimsError || !claims?.claims) redirect("/login?next=/app");

  const { data: membership } = await supabase
    .from("household_members")
    .select("household_id")
    .eq("user_id", claims.claims.sub)
    .eq("status", "active")
    .limit(1)
    .maybeSingle();
  if (membership) redirect("/app");

  const { data: invitations, error } = await supabase.rpc("list_my_pending_household_invitations");
  if (error || !invitations?.length) redirect("/app");

  return <InvitationFlow invitations={invitations} />;
}
