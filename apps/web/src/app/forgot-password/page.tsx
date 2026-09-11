import Link from "next/link";

import { requestPasswordReset } from "@/app/auth/actions";
import { AuthForm } from "@/components/auth/auth-form";
import { AuthShell } from "@/components/auth/auth-shell";
import { EmailField } from "@/components/auth/email-field";
import { SubmitButton } from "@/components/auth/submit-button";
import styles from "@/components/auth/auth.module.css";

export default async function ForgotPasswordPage({
  searchParams,
}: {
  searchParams: Promise<{ sent?: string }>;
}) {
  const { sent } = await searchParams;

  return (
    <AuthShell title="استعادة كلمة المرور" description="أدخل بريدك الإلكتروني وسنرسل التعليمات إذا كان الحساب موجودًا.">
      {sent ? (
        <p className={styles.success} role="status">
          لو الحساب موجود، أرسلنا تعليمات استعادة كلمة المرور.
        </p>
      ) : (
        <AuthForm action={requestPasswordReset}>
          <EmailField />
          <SubmitButton>إرسال التعليمات</SubmitButton>
        </AuthForm>
      )}
      <p className={styles.footer}>
        <Link className={styles.backLink} href="/login">
          العودة إلى تسجيل الدخول
        </Link>
      </p>
    </AuthShell>
  );
}
