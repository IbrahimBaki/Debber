import { redirect } from "next/navigation";

import { signOut } from "@/app/auth/actions";
import { AuthShell } from "@/components/auth/auth-shell";
import { SubmitButton } from "@/components/auth/submit-button";
import styles from "@/components/auth/auth.module.css";
import { createClient } from "@/lib/supabase/server";

export default async function AuthSessionPage({
  searchParams,
}: {
  searchParams: Promise<{ passwordUpdated?: string }>;
}) {
  const supabase = await createClient();
  const { data, error } = await supabase.auth.getClaims();

  if (error || !data?.claims) {
    redirect("/login?next=/auth/session");
  }

  const { passwordUpdated } = await searchParams;
  const email = typeof data?.claims?.email === "string" ? data.claims.email : "";

  return (
    <AuthShell title="تم تسجيل الدخول" description="هذه صفحة تقنية مؤقتة إلى أن يتم اعتماد توجيه الإعداد الأولي.">
      {passwordUpdated ? (
        <p className={styles.success} role="status">
          تم تحديث كلمة المرور بنجاح.
        </p>
      ) : null}
      <p className={styles.notice}>
        الحساب الحالي: <span className={styles.sessionEmail}>{email}</span>
      </p>
      <form className={styles.form} action={signOut}>
        <SubmitButton>تسجيل الخروج</SubmitButton>
      </form>
    </AuthShell>
  );
}
