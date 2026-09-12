"use server";

import { redirect } from "next/navigation";

import { requireAdmin } from "@/lib/admin/require-admin";
import { createAuthUser } from "@/lib/supabase/admin-auth";

export type CreateUserState = {
  error?: string;
};

export async function createUserAction(
  _previousState: CreateUserState,
  formData: FormData,
): Promise<CreateUserState> {
  const { supabase } = await requireAdmin();

  const email = String(formData.get("email") ?? "").trim().toLowerCase();
  const password = String(formData.get("password") ?? "");
  const activateImmediately = formData.get("activateImmediately") === "on";

  if (!email || !password) {
    return { error: "أدخل البريد الإلكتروني وكلمة المرور." };
  }

  if (password.length < 6) {
    return { error: "كلمة المرور يجب ألا تقل عن 6 أحرف." };
  }

  let createdUserId: string;
  try {
    const user = await createAuthUser({ email, password, activateImmediately });
    createdUserId = user.id;
  } catch {
    return { error: "تعذر إنشاء المستخدم. تأكد أن البريد الإلكتروني غير مستخدم من قبل." };
  }

  await supabase.rpc("admin_record_audit_event", {
    p_action: "user.created",
    p_target_type: "auth_user",
    p_target_id: createdUserId,
    p_target_user_id: createdUserId,
    p_household_id: undefined,
    p_invitation_id: undefined,
    p_reason: undefined,
  });

  redirect(`/users/${createdUserId}`);
}
