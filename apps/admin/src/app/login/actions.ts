"use server";

import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export type AuthActionState = {
  error?: string;
};

const genericSignInError = "تعذر تسجيل الدخول. تأكد من البريد الإلكتروني وكلمة المرور.";
const notAdminError = "هذا الحساب غير مصرّح له بالدخول إلى لوحة الإدارة.";

export async function signIn(
  _previousState: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  const email = String(formData.get("email") ?? "").trim().toLowerCase();
  const password = String(formData.get("password") ?? "");

  if (!email || !password) {
    return { error: "أدخل البريد الإلكتروني وكلمة المرور." };
  }

  const supabase = await createClient();
  const { error: signInError } = await supabase.auth.signInWithPassword({ email, password });

  if (signInError) {
    return { error: genericSignInError };
  }

  // The signed-in identity may belong to a perfectly valid Dabber account that simply is not an
  // admin. Reject and drop the session immediately rather than leaving a non-admin session
  // sitting inside the admin app.
  const { data: isAdmin, error: adminError } = await supabase.rpc("is_platform_admin");

  if (adminError || !isAdmin) {
    await supabase.auth.signOut();
    return { error: notAdminError };
  }

  redirect("/");
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
