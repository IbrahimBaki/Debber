"use server";

import { redirect } from "next/navigation";

import { requireAdmin } from "@/lib/admin/require-admin";

export type CreateInvitationState = {
  error?: string;
};

function friendlyError(message: string | undefined): string {
  switch (message) {
    case "self_invite_not_allowed":
      return "لا يمكن دعوة البريد الإلكتروني الخاص بمالك البيت نفسه.";
    case "already_active_member":
      return "هذا البريد الإلكتروني ينتمي بالفعل لعضو نشط في هذا البيت.";
    case "household_not_found":
      return "لا يوجد بيت بهذا المعرّف.";
    case "invalid_email":
      return "البريد الإلكتروني غير صالح.";
    default:
      return "تعذر إنشاء الدعوة.";
  }
}

export async function createInvitationAction(
  _previousState: CreateInvitationState,
  formData: FormData,
): Promise<CreateInvitationState> {
  const { supabase } = await requireAdmin();
  const householdId = String(formData.get("householdId") ?? "").trim();
  const email = String(formData.get("email") ?? "").trim().toLowerCase();

  if (!householdId || !email) {
    return { error: "أدخل معرّف البيت والبريد الإلكتروني." };
  }

  const { error } = await supabase.rpc("admin_create_household_invitation", {
    p_household_id: householdId,
    p_email: email,
  });

  if (error) {
    return { error: friendlyError(error.message) };
  }

  redirect("/invitations");
}
