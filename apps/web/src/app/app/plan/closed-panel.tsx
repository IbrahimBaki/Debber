import Link from "next/link";

import styles from "@/app/app/onboarding.module.css";

function formatRange(start: string, end: string) {
  const formatter = new Intl.DateTimeFormat("ar-EG", { day: "numeric", month: "long" });
  return `${formatter.format(new Date(start))} – ${formatter.format(new Date(end))}`;
}

export function ClosedPanel({
  householdName,
  periodStart,
  periodEnd,
}: {
  householdName: string;
  periodStart: string;
  periodEnd: string;
}) {
  return (
    <main className={styles.page}>
      <section className={styles.ready} aria-labelledby="closed-title">
        <p className={styles.readyLead}>{householdName}</p>
        <h1 id="closed-title">هذا الشهر مغلق</h1>
        <p className={styles.future}>
          الفترة من {formatRange(periodStart, periodEnd)} مغلقة الآن، لذلك خطتها للعرض فقط ولا يمكن تعديلها من هنا.
        </p>
        <Link className={styles.quietButton} href="/app">
          العودة إلى الرئيسية
        </Link>
      </section>
    </main>
  );
}
