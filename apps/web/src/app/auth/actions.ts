"use server";

import { headers } from "next/headers";
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

function safeNext(value: FormDataEntryValue | null, fallback = "/app") {
  if (typeof value !== "string") return fallback;

  return value.startsWith("/") && !value.startsWith("//") && !value.includes("\\")
    ? value
    : fallback;
}

// NEXT_PUBLIC_SITE_URL is an optional override; when unset (as in production today) the origin
// is derived from the incoming request's own Host header, which Vercel always sets correctly.
// Previously this threw synchronously whenever the env var was absent -- caught by the outer
// try/catch below and surfaced as the generic fallback error with auth.signUp() never reached
// (confirmed via temporary stage logging: production never got past this line).
async function appUrl(path: string) {
  const configured = process.env.NEXT_PUBLIC_SITE_URL;
  const origin = configured || (await requestOrigin());

  if (!origin) {
    throw new Error("Unable to determine site origin for redirect URL.");
  }

  return new URL(path, origin).toString();
}

async function requestOrigin(): Promise<string | null> {
  const headersList = await headers();
  const host = headersList.get("x-forwarded-host") ?? headersList.get("host");

  if (!host) return null;

  const proto = headersList.get("x-forwarded-proto") ?? "http";
  return `${proto}://${host}`;
}

// Minimal, safe server-side log for an unexpected signup/auth-action failure -- no password,
// confirmation, Supabase key, token, cookie, or email value, ever.
function logUnexpectedAuthError(stage: string, error: unknown) {
  const err = error as { name?: string; code?: string; status?: number; message?: string };
  console.error(
    JSON.stringify({
      tag: "auth-action-error",
      stage,
      name: err?.name,
      code: err?.code,
      status: err?.status,
      message: err?.message,
    }),
  );
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
    const emailRedirectTo = await appUrl("/auth/confirm");
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: { emailRedirectTo },
    });

    if (error) {
      logUnexpectedAuthError("signup", error);
      return { error: "تعذر إنشاء الحساب الآن. حاول مرة أخرى لاحقًا." };
    }
  } catch (err) {
    logUnexpectedAuthError("signup", err);
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
    const redirectTo = await appUrl("/auth/confirm");
    await supabase.auth.resetPasswordForEmail(email, { redirectTo });
  } catch (err) {
    // Keep this response non-enumerating and do not disclose provider details to the caller,
    // but still record the unexpected failure server-side.
    logUnexpectedAuthError("password-reset-request", err);
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

  redirect("/app?passwordUpdated=1");
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
