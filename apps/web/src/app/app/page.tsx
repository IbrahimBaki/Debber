import Image from "next/image";
import Link from "next/link";
import { redirect } from "next/navigation";

import { signOut } from "@/app/auth/actions";
import styles from "@/app/app/onboarding.module.css";
import { createClient } from "@/lib/supabase/server";

import { resolveExpenseEligibility } from "./expenses/eligibility";
import { loadMemberMonthlyView } from "./member-data";
import { MemberMonthlyViewPanel } from "./member-view";
import planStyles from "./plan/plan.module.css";

export default async function AppPage({ searchParams }: { searchParams: Promise<{ passwordUpdated?: string }> }) {
  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();
  if (claimsError || !claims?.claims?.sub) redirect("/login?next=/app");

  const { data: membership } = await supabase
    .from("household_members")
    .select("household_id, role")
    .eq("user_id", claims.claims.sub)
    .eq("status", "active")
    .order("joined_at", { ascending: true })
    .limit(1)
    .maybeSingle();

  if (!membership) {
    const { data: invitations, error } = await supabase.rpc("list_my_pending_household_invitations");
    if (error) redirect("/app/new-household?state=retry");
    if ((invitations?.length ?? 0) > 0) redirect("/app/invitations");
    redirect("/app/new-household");
  }

  const { data: household } = await supabase
    .from("households")
    .select("id, name, currency_code, period_start_day, timezone")
    .eq("id", membership.household_id)
    .maybeSingle();
  if (!household) redirect("/app");

  const { passwordUpdated } = await searchParams;

  const eligibility = await resolveExpenseEligibility(supabase, household, membership.role === "owner" ? "owner" : "member");
  const canRecordExpense = eligibility.status === "open" && eligibility.sections.length > 0;

  if (membership.role !== "owner") {
    const view = await loadMemberMonthlyView(supabase, household);
    return (
      <main className={planStyles.page} dir="rtl">
        <div className={planStyles.content}>
          {passwordUpdated ? <p className={styles.success} role="status">تم تحديث كلمة المرور بنجاح.</p> : null}
          <MemberMonthlyViewPanel householdName={household.name} currencyCode={household.currency_code} view={view} />
          {canRecordExpense ? (
            <Link className={planStyles.primaryButton} href="/app/expenses/new">إضافة مصروف</Link>
          ) : null}
          <form action={signOut}><button className={styles.quietButton}>تسجيل الخروج</button></form>
        </div>
      </main>
    );
  }

  return (
    <main className={styles.page}>
      <section className={styles.ready} aria-labelledby="ready-title">
        <Image src="/brand/mark.svg" alt="" width={42} height={42} priority />
        {passwordUpdated ? <p className={styles.success} role="status">تم تحديث كلمة المرور بنجاح.</p> : null}
        <p className={styles.readyLead}>مساحتك المشتركة</p>
        <h1 id="ready-title">{household.name}</h1>
        <p className={styles.readyRole}>مالك البيت</p>
        <dl className={styles.details}>
          <div><dt>العملة</dt><dd dir="ltr">{household.currency_code}</dd></div>
          <div><dt>بداية الشهر المالي</dt><dd>{household.period_start_day}</dd></div>
        </dl>
        <div className={styles.actions}>
          {canRecordExpense ? (
            <Link className={styles.primaryButton} href="/app/expenses/new">إضافة مصروف</Link>
          ) : null}
          <Link className={canRecordExpense ? styles.quietButton : styles.primaryButton} href="/app/plan">خطة الشهر</Link>
          <Link className={styles.quietButton} href="/app/invitations/new">دعوة شريك</Link>
        </div>
        <form action={signOut}><button className={styles.quietButton}>تسجيل الخروج</button></form>
      </section>
    </main>
  );
}
