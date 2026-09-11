import Link from "next/link";
import { redirect } from "next/navigation";

import { updatePassword } from "@/app/auth/actions";
import { AuthForm } from "@/components/auth/auth-form";
import { AuthShell } from "@/components/auth/auth-shell";
import { PasswordField } from "@/components/auth/password-field";
import { SubmitButton } from "@/components/auth/submit-button";
import styles from "@/components/auth/auth.module.css";
import { createClient } from "@/lib/supabase/server";

export default async function ResetPasswordPage() {
  const supabase = await createClient();
  const { data, error } = await supabase.auth.getClaims();

  if (error || !data?.claims) {
    redirect("/login?auth_error=recovery");
  }

  return (
    <AuthShell title="كلمة مرور جديدة" description="اختر كلمة مرور جديدة لحسابك.">
      <AuthForm action={updatePassword}>
        <PasswordField name="password" label="كلمة المرور الجديدة" autoComplete="new-password" />
        <PasswordField
          name="passwordConfirmation"
          label="تأكيد كلمة المرور الجديدة"
          autoComplete="new-password"
        />
        <SubmitButton>حفظ كلمة المرور</SubmitButton>
      </AuthForm>
      <p className={styles.footer}>
        <Link className={styles.backLink} href="/login">
          العودة إلى تسجيل الدخول
        </Link>
      </p>
    </AuthShell>
  );
}
