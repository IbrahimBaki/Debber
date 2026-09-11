"use server";

import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export type InviteActionState = {
  error?: string;
  success?: { email: string; expiresAt: string };
};

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function friendlyError(message: string): string {
  if (message.includes("invalid_email")) return "اكتب بريد إلكتروني صحيح.";
  if (message.includes("self_invite_not_allowed")) return "مش محتاج تدعو بريدك أنت.";
  if (message.includes("already_active_member")) return "الشخص ده عضو في البيت بالفعل.";
  if (message.includes("not_authorized") || message.includes("not_authenticated")) {
    return "لا يمكن إنشاء دعوة الآن. حدّث الصفحة وتحقق من صلاحياتك.";
  }
  return "تعذر إنشاء الدعوة الآن. حاول مرة أخرى.";
}

/**
 * Creates a partner invitation via the sole authoritative RPC, create_household_invitation(...).
 * There is no outbound invitation email in MVP -- this only ever reports that a pending
 * invitation record now exists (created or reused), never that anything was sent.
 */
export async function inviteMember(_previousState: InviteActionState, formData: FormData): Promise<InviteActionState> {
  const householdId = String(formData.get("householdId") ?? "");
  const email = String(formData.get("email") ?? "").trim();

  if (!uuidPattern.test(householdId)) return { error: "تعذر التعرف على البيت. حدّث الصفحة." };
  if (!email) return { error: "اكتب بريد إلكتروني صحيح." };

  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();
  if (claimsError || !claims?.claims?.sub) redirect("/login?next=/app/invitations/new");

  const { data, error } = await supabase.rpc("create_household_invitation", {
    p_household_id: householdId,
    p_email: email,
  });
  if (error) return { error: friendlyError(error.message ?? "") };

  const row = data?.[0];
  if (!row) return { error: "تعذر إنشاء الدعوة الآن. حاول مرة أخرى." };

  return { success: { email: row.email, expiresAt: row.expires_at } };
}
