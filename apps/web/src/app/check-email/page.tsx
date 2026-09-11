import type { Metadata } from "next";
import Link from "next/link";

import { AuthShell } from "@/components/auth/auth-shell";
import styles from "@/components/auth/auth.module.css";

export const metadata: Metadata = { title: "راجع بريدك الإلكتروني" };

export default async function CheckEmailPage({
  searchParams,
}: {
  searchParams: Promise<{ email?: string }>;
}) {
  const { email } = await searchParams;

  return (
    <AuthShell title="راجع بريدك الإلكتروني" description="أرسلنا رابط تأكيد لتفعيل حسابك.">
      {email ? (
        <p className={styles.notice}>
          أُرسل الرابط إلى <span className={styles.sessionEmail}>{email}</span>.
        </p>
      ) : null}
      {process.env.NODE_ENV === "development" ? (
        <p className={styles.notice}>
          للتطوير المحلي: راجع Mailpit على {" "}
          <a className={styles.textLink} href="http://127.0.0.1:54324">
            http://127.0.0.1:54324
          </a>
          .
        </p>
      ) : null}
      <p className={styles.footer}>
        <Link className={styles.backLink} href="/login">
          العودة إلى تسجيل الدخول
        </Link>
      </p>
    </AuthShell>
  );
}
