import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { redirect } from "next/navigation";

import { signOut } from "@/app/auth/actions";
import styles from "@/app/app/onboarding.module.css";
import { createClient } from "@/lib/supabase/server";

import { resolveExpenseEligibility } from "./expenses/eligibility";
import { loadMemberMonthlyView } from "./member-data";
import { MemberMonthlyViewPanel } from "./member-view";
import { loadOwnerCommitments } from "./owner-commitments-data";
import { OwnerCommitmentsSection } from "./owner-commitments";
import { loadOwnerHomeView } from "./owner-home-data";
import ownerHomeStyles from "./owner-home.module.css";
import { OwnerHero } from "./owner-hero";
import { formatDateRange } from "./plan/format";
import { Icon } from "./plan/icons";
import planStyles from "./plan/plan.module.css";
import { SectionCard } from "./section-card";
import sectionCardStyles from "./section-card.module.css";

export const metadata: Metadata = { title: "مساحتك المشتركة" };

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
          <div className={ownerHomeStyles.stack}>
            {passwordUpdated ? <p className={styles.success} role="status">تم تحديث كلمة المرور بنجاح.</p> : null}
            <MemberMonthlyViewPanel
              householdName={household.name}
              currencyCode={household.currency_code}
              view={view}
              canRecordExpense={canRecordExpense}
            />
            <form action={signOut}><button className={styles.quietButton}>تسجيل الخروج</button></form>
          </div>
        </div>
      </main>
    );
  }

  const commitmentsView = await loadOwnerCommitments(supabase, household);
  const ownerHome = await loadOwnerHomeView(supabase, household);

  // Draft (and the practically-unreachable no_period case) keep the existing setup-focused
  // "ready" composition: the Owner's job here is to finish and start the month, not read a
  // dashboard of numbers that don't represent an active month yet (§26).
  if (ownerHome.status === "no_period" || ownerHome.status === "draft") {
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
            <Link className={styles.primaryButton} href="/app/plan">خطة الشهر</Link>
            <Link className={styles.quietButton} href="/app/invitations/new">دعوة شريك</Link>
          </div>
          <OwnerCommitmentsSection view={commitmentsView} currencyCode={household.currency_code} />
          <form action={signOut}><button className={styles.quietButton}>تسجيل الخروج</button></form>
        </section>
      </main>
    );
  }

  return (
    <main className={planStyles.page} dir="rtl">
      <div className={planStyles.content}>
        <div className={ownerHomeStyles.stack}>
          {passwordUpdated ? <p className={styles.success} role="status">تم تحديث كلمة المرور بنجاح.</p> : null}

          <header className={ownerHomeStyles.header}>
            <div>
              <p className={ownerHomeStyles.eyebrow}>
                {household.name} · {formatDateRange(ownerHome.periodStart, ownerHome.periodEnd)} · <span dir="ltr">{household.currency_code}</span>
              </p>
              <h1>مصروف الشهر</h1>
            </div>
            {ownerHome.status === "closed" ? (
              <span className={ownerHomeStyles.statusBadge} data-status="closed">الشهر مغلق</span>
            ) : null}
          </header>

          <div className={ownerHomeStyles.heroGroup}>
            <OwnerHero
              spendingBudget={ownerHome.spendingBudget}
              actualVariableSpending={ownerHome.actualVariableSpending}
              budgetRemaining={ownerHome.budgetRemaining}
              currencyCode={household.currency_code}
            />
            {canRecordExpense ? (
              <Link className={ownerHomeStyles.heroCta} href="/app/expenses/new">إضافة مصروف</Link>
            ) : null}
          </div>

          <div className={ownerHomeStyles.columns}>
            <section aria-labelledby="owner-sections-title">
              <h2 id="owner-sections-title" className={ownerHomeStyles.sectionsHeading}>الأقسام</h2>
              {ownerHome.sections.length > 0 ? (
                <div className={sectionCardStyles.list}>
                  {ownerHome.sections.map((section) => (
                    <SectionCard key={section.id} section={section} currencyCode={household.currency_code} />
                  ))}
                </div>
              ) : (
                <div className={planStyles.emptyState}>
                  <span><Icon name="spark" size={20} /></span>
                  <p>مفيش أقسام مصروف بعد. أضف قسمًا من خطة الشهر.</p>
                </div>
              )}
            </section>

            <div className={ownerHomeStyles.commitmentsColumn}>
              <OwnerCommitmentsSection view={commitmentsView} currencyCode={household.currency_code} />
            </div>
          </div>

          <div className={ownerHomeStyles.managementLinks}>
            <Link className={ownerHomeStyles.managementLink} href="/app/plan">تعديل الخطة</Link>
            <Link className={ownerHomeStyles.managementLink} href="/app/invitations/new">دعوة شريك</Link>
          </div>

          <form action={signOut}><button className={styles.quietButton}>تسجيل الخروج</button></form>
        </div>
      </div>
    </main>
  );
}
