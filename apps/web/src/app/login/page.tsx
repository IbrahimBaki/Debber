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

  return (
    <AuthShell title="أهلًا بعودتك" description="سجّل دخولك للمتابعة إلى دبّر.">
      {authError ? (
        <p className={styles.error} role="alert">
          تعذر إتمام الرابط. اطلب رابطًا جديدًا وحاول مرة أخرى.
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
