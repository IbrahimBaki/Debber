"use server";

import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export type AuthActionState = {
  error?: string;
};

const genericSignInError =
  "تعذر تسجيل الدخول. تأكد من البريد الإلكتروني وكلمة المرور ثم حاول مرة أخرى.";

function readEmail(formData: FormData) {
  return String(formData.get("email") ?? "").trim().toLowerCase();
}

function readPassword(formData: FormData, name = "password") {
  return String(formData.get(name) ?? "");
}

function safeNext(value: FormDataEntryValue | null, fallback = "/auth/session") {
  if (typeof value !== "string") return fallback;

  return value.startsWith("/") && !value.startsWith("//") && !value.includes("\\")
    ? value
    : fallback;
}

function appUrl(path: string) {
  const origin = process.env.NEXT_PUBLIC_SITE_URL;

  if (!origin) {
    throw new Error("Site URL is not configured.");
  }

  return new URL(path, origin).toString();
}

export async function signUp(
  _previousState: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  const email = readEmail(formData);
  const password = readPassword(formData);
  const passwordConfirmation = readPassword(formData, "passwordConfirmation");

  if (!email || !password || !passwordConfirmation) {
    return { error: "أدخل البريد الإلكتروني وكلمة المرور وتأكيدها." };
  }

  if (password !== passwordConfirmation) {
    return { error: "كلمتا المرور غير متطابقتين." };
  }

  try {
    const supabase = await createClient();
    const emailRedirectTo = appUrl("/auth/confirm");
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: { emailRedirectTo },
    });

    if (error) {
      return { error: "تعذر إنشاء الحساب الآن. حاول مرة أخرى لاحقًا." };
    }
  } catch {
    return { error: "تعذر إنشاء الحساب الآن. حاول مرة أخرى لاحقًا." };
  }

  redirect(`/check-email?email=${encodeURIComponent(email)}`);
}

export async function signIn(
  _previousState: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  const email = readEmail(formData);
  const password = readPassword(formData);

  if (!email || !password) {
    return { error: "أدخل البريد الإلكتروني وكلمة المرور." };
  }

  try {
    const supabase = await createClient();
    const { error } = await supabase.auth.signInWithPassword({ email, password });

    if (error) {
      return { error: genericSignInError };
    }
  } catch {
    return { error: genericSignInError };
  }

  redirect(safeNext(formData.get("next")));
}

export async function requestPasswordReset(
  _previousState: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  const email = readEmail(formData);

  if (!email) {
    return { error: "أدخل بريدك الإلكتروني." };
  }

  try {
    const supabase = await createClient();
    const redirectTo = appUrl("/auth/confirm");
    await supabase.auth.resetPasswordForEmail(email, { redirectTo });
  } catch {
    // Keep this response non-enumerating and do not disclose provider details.
  }

  redirect("/forgot-password?sent=1");
}

export async function updatePassword(
  _previousState: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  const password = readPassword(formData);
  const passwordConfirmation = readPassword(formData, "passwordConfirmation");

  if (!password || !passwordConfirmation) {
    return { error: "أدخل كلمة المرور الجديدة وتأكيدها." };
  }

  if (password !== passwordConfirmation) {
    return { error: "كلمتا المرور غير متطابقتين." };
  }

  try {
    const supabase = await createClient();
    const { data: claims, error: claimsError } = await supabase.auth.getClaims();

    if (claimsError || !claims?.claims) {
      return { error: "انتهت صلاحية رابط الاستعادة. اطلب رابطًا جديدًا." };
    }

    const { error } = await supabase.auth.updateUser({ password });

    if (error) {
      return { error: "تعذر تحديث كلمة المرور. تحقق من متطلبات كلمة المرور وحاول مرة أخرى." };
    }
  } catch {
    return { error: "تعذر تحديث كلمة المرور. حاول مرة أخرى." };
  }

  redirect("/auth/session?passwordUpdated=1");
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
