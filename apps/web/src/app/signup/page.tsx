import Link from "next/link";

import { signUp } from "@/app/auth/actions";
import { AuthForm } from "@/components/auth/auth-form";
import { AuthShell } from "@/components/auth/auth-shell";
import { EmailField } from "@/components/auth/email-field";
import { PasswordField } from "@/components/auth/password-field";
import { SubmitButton } from "@/components/auth/submit-button";
import styles from "@/components/auth/auth.module.css";

export default function SignupPage() {
  return (
    <AuthShell title="ابدأ بهدوء" description="أنشئ حسابك أولًا، ثم أكّد بريدك الإلكتروني.">
      <AuthForm action={signUp}>
        <EmailField />
        <PasswordField name="password" label="كلمة المرور" autoComplete="new-password" />
        <PasswordField
          name="passwordConfirmation"
          label="تأكيد كلمة المرور"
          autoComplete="new-password"
        />
        <SubmitButton>إنشاء الحساب</SubmitButton>
      </AuthForm>
      <p className={styles.footer}>
        لديك حساب بالفعل؟
        <Link className={styles.textLink} href="/login">
          تسجيل الدخول
        </Link>
      </p>
    </AuthShell>
  );
}
