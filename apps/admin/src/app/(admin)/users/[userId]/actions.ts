"use server";

import { redirect } from "next/navigation";

import { requireAdmin } from "@/lib/admin/require-admin";
import {
  activateAuthUser,
  disableAuthUser,
  enableAuthUser,
  setAuthUserPassword,
} from "@/lib/supabase/admin-auth";

export type UserActionState = {
  error?: string;
  success?: string;
};

async function recordAudit(
  supabase: Awaited<ReturnType<typeof requireAdmin>>["supabase"],
  action: string,
  userId: string,
) {
  await supabase.rpc("admin_record_audit_event", {
    p_action: action,
    p_target_type: "auth_user",
    p_target_id: userId,
    p_target_user_id: userId,
    p_household_id: undefined,
    p_invitation_id: undefined,
    p_reason: undefined,
  });
}

export async function activateUserAction(userId: string) {
  const { supabase } = await requireAdmin();
  await activateAuthUser(userId);
  await recordAudit(supabase, "user.activated", userId);
  redirect(`/users/${userId}`);
}

export async function disableUserAction(userId: string) {
  const { supabase } = await requireAdmin();
  await disableAuthUser(userId);
  await recordAudit(supabase, "user.disabled", userId);
  redirect(`/users/${userId}`);
}

export async function enableUserAction(userId: string) {
  const { supabase } = await requireAdmin();
  await enableAuthUser(userId);
  await recordAudit(supabase, "user.enabled", userId);
  redirect(`/users/${userId}`);
}

export async function changePasswordAction(
  _previousState: UserActionState,
  formData: FormData,
): Promise<UserActionState> {
  const { supabase } = await requireAdmin();
  const userId = String(formData.get("userId") ?? "");
  const newPassword = String(formData.get("newPassword") ?? "");

  if (!userId || !newPassword) {
    return { error: "بيانات غير مكتملة." };
  }

  if (newPassword.length < 6) {
    return { error: "كلمة المرور يجب ألا تقل عن 6 أحرف." };
  }

  try {
    await setAuthUserPassword(userId, newPassword);
  } catch {
    return { error: "تعذر تغيير كلمة المرور." };
  }

  await recordAudit(supabase, "user.password_changed", userId);

  return { success: "تم تغيير كلمة المرور. الجلسات السابقة لهذا المستخدم لم تعد صالحة." };
}
