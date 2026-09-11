import type { Metadata } from "next";
import Link from "next/link";

import { signIn } from "@/app/auth/actions";
import { AuthForm } from "@/components/auth/auth-form";
import { AuthShell } from "@/components/auth/auth-shell";
import { EmailField } from "@/components/auth/email-field";
import { PasswordField } from "@/components/auth/password-field";
import { SubmitButton } from "@/components/auth/submit-button";
import styles from "@/components/auth/auth.module.css";

export const metadata: Metadata = { title: "تسجيل الدخول" };

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string; auth_error?: string }>;
}) {
  const { next, auth_error: authError } = await searchParams;
  const safeNext = next?.startsWith("/") && !next.startsWith("//") ? next : undefined;

  // A confirmation link and a recovery link fail for different reasons and imply different
  // next actions -- a used/expired confirmation link often means the account is already
  // confirmed (so logging in is the useful next step), while a used/expired recovery link
  // implies nothing about whether the password was actually changed, so the safe next step is
  // simply to request a new one. Neither message claims a specific account state as fact.
  const errorMessage =
    authError === "confirmation"
      ? "الرابط ده اتستخدم قبل كده أو انتهت صلاحيته. لو كنت فعّلت الحساب بالفعل، جرّب تسجيل الدخول بنفس البريد وكلمة السر اللي اخترتهم وقت التسجيل."
      : authError === "recovery"
        ? "رابط استعادة كلمة المرور ده اتستخدم قبل كده أو انتهت صلاحيته. اطلب رابطًا جديدًا وحاول تاني."
        : authError
          ? "تعذر إتمام الرابط. اطلب رابطًا جديدًا وحاول مرة أخرى."
          : null;

  return (
    <AuthShell title="أهلًا بعودتك" description="سجّل دخولك للمتابعة إلى دبّر.">
      {errorMessage ? (
        <p className={styles.error} role="alert">
          {errorMessage}
        </p>
      ) : null}
      <AuthForm action={signIn}>
        <input type="hidden" name="next" value={safeNext} />
        <EmailField />
        <PasswordField name="password" label="كلمة المرور" autoComplete="current-password" />
        <SubmitButton>تسجيل الدخول</SubmitButton>
      </AuthForm>
      <p className={styles.footer}>
        <Link className={styles.textLink} href="/forgot-password">
          نسيت كلمة المرور؟
        </Link>
      </p>
      <p className={styles.footer}>
        ليس لديك حساب؟
        <Link className={styles.textLink} href="/signup">
          أنشئ حسابًا
        </Link>
      </p>
    </AuthShell>
  );
}
