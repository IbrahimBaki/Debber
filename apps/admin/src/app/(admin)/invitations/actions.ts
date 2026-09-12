"use server";

import { revalidatePath } from "next/cache";

import { requireAdmin } from "@/lib/admin/require-admin";

export type InvitationRowState = {
  error?: string;
};

function friendlyError(message: string | undefined): string {
  switch (message) {
    case "invitee_user_not_found":
      return "لا يوجد حساب دخول مسجّل بهذا البريد الإلكتروني بعد.";
    case "invitation_expired":
      return "انتهت صلاحية هذه الدعوة.";
    case "invitation_not_pending":
      return "هذه الدعوة لم تعد معلّقة.";
    default:
      return "تعذر تنفيذ العملية.";
  }
}

export async function revokeInvitationAction(
  _previousState: InvitationRowState,
  formData: FormData,
): Promise<InvitationRowState> {
  const { supabase } = await requireAdmin();
  const invitationId = String(formData.get("invitationId") ?? "");
  const { error } = await supabase.rpc("admin_revoke_household_invitation", {
    p_invitation_id: invitationId,
    p_reason: undefined,
  });

  if (error) return { error: friendlyError(error.message) };

  revalidatePath("/invitations");
  return {};
}

export async function acceptInvitationAction(
  _previousState: InvitationRowState,
  formData: FormData,
): Promise<InvitationRowState> {
  const { supabase } = await requireAdmin();
  const invitationId = String(formData.get("invitationId") ?? "");
  const { error } = await supabase.rpc("admin_accept_household_invitation", {
    p_invitation_id: invitationId,
  });

  if (error) return { error: friendlyError(error.message) };

  revalidatePath("/invitations");
  return {};
}
