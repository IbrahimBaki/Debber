import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import type { ReactNode } from "react";

import { Icon, type IconName } from "@/app/app/plan/icons";
import { createClient } from "@/lib/supabase/server";

import { AppShell, type AppNavContext } from "../../app-shell";
import { resolveExpenseEligibility } from "../eligibility";
import { resolveCurrentPeriod } from "../../period-context";
import { ExpenseFormClient } from "./expense-form-client";
import styles from "./expenses.module.css";

export const metadata: Metadata = { title: "إضافة مصروف" };

function StateCard({ icon = "clock", title, body, action }: { icon?: IconName; title: string; body: string; action?: ReactNode }) {
  return (
    <div className={styles.stateCard}>
      <span><Icon name={icon} size={22} /></span>
      <h1>{title}</h1>
      <p>{body}</p>
      {action}
    </div>
  );
}

export default async function NewExpensePage({
  searchParams,
}: {
  searchParams: Promise<{ section?: string }>;
}) {
  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();
  if (claimsError || !claims?.claims?.sub) redirect("/login?next=/app/expenses/new");
  const uid = claims.claims.sub;

  const { data: membership } = await supabase
    .from("household_members")
    .select("household_id, role")
    .eq("user_id", uid)
    .eq("status", "active")
    .order("joined_at", { ascending: true })
    .limit(1)
    .maybeSingle();

  if (!membership) redirect("/app");

  const { data: household } = await supabase
    .from("households")
    .select("id, name, currency_code, timezone")
    .eq("id", membership.household_id)
    .maybeSingle();
  if (!household) redirect("/app");

  const role = membership.role === "owner" ? "owner" : "member";
  const period = await resolveCurrentPeriod(supabase, household.id);
  const eligibility = await resolveExpenseEligibility(supabase, household, role, period);

  // A query-param preselection is only a UX hint: it must match a section the caller's own
  // eligibility already returned, or it is silently ignored (§10). The same validated,
  // same-origin section id also decides the safe "back" destination -- never an arbitrary
  // caller-supplied URL, just a fixed /app/sections/<validated-uuid> path -- so opening the
  // form from a section detail page returns there instead of always landing on /app.
  const { section: requestedSection } = await searchParams;
  const eligibleSections = eligibility.status === "open" ? eligibility.sections : [];
  const initialSectionId = eligibleSections.some((section) => section.id === requestedSection)
    ? requestedSection
    : undefined;
  const returnHref = initialSectionId ? `/app/sections/${initialSectionId}` : "/app";
  const returnLabel = initialSectionId ? "رجوع للقسم" : "رجوع للرئيسية";

  const header = (
    <header className={styles.header}>
      <Link href={returnHref} className={styles.backLink} aria-label={returnLabel}><Icon name="arrow" size={20} /></Link>
      <h1>إضافة مصروف</h1>
      <span style={{ width: "2.5rem" }} aria-hidden="true" />
    </header>
  );

  if (eligibility.status === "no_period") redirect("/app");

  const nav: AppNavContext = {
    role,
    periodStatus: eligibility.status === "not_open" ? eligibility.periodStatus : "open",
    canRecordExpense: eligibility.status === "open" && eligibility.sections.length > 0,
  };

  if (eligibility.status === "not_open") {
    if (role === "owner") {
      return (
        <AppShell nav={nav} active="add" householdName={household.name}>
          <main className={styles.page} dir="rtl">
            <div className={styles.content}>
              {header}
              <StateCard
                title={eligibility.periodStatus === "draft" ? "الشهر لسه ما بدأش" : "الشهر ده مقفول"}
                body={
                  eligibility.periodStatus === "draft"
                    ? "جهّز خطة الشهر وابدأه عشان تقدر تسجل مصروفات."
                    : "الشهر ده مقفول ومش متاح لتسجيل مصروفات جديدة."
                }
                action={eligibility.periodStatus === "draft" ? <Link className={styles.primaryButton} href="/app/plan">خطة الشهر</Link> : null}
              />
            </div>
          </main>
        </AppShell>
      );
    }
    return (
      <AppShell nav={nav} active="add" householdName={household.name}>
        <main className={styles.page} dir="rtl">
          <div className={styles.content}>
            {header}
            <StateCard title="الشهر لسه ما بدأش" body="لسه مفيش شهر مفتوح لتسجيل المصروفات." />
          </div>
        </main>
      </AppShell>
    );
  }

  if (eligibility.sections.length === 0) {
    if (role === "owner") {
      return (
        <AppShell nav={nav} active="add" householdName={household.name}>
          <main className={styles.page} dir="rtl">
            <div className={styles.content}>
              {header}
              <StateCard
                icon="spark"
                title="مفيش أقسام بعد"
                body="أضف قسم مصروف في خطة الشهر عشان تقدر تسجل مصروفات."
                action={<Link className={styles.primaryButton} href="/app/plan">خطة الشهر</Link>}
              />
            </div>
          </main>
        </AppShell>
      );
    }
    return (
      <AppShell nav={nav} active="add" householdName={household.name}>
        <main className={styles.page} dir="rtl">
          <div className={styles.content}>
            {header}
            <StateCard icon="spark" title="مفيش أقسام متاحة" body="مفيش أقسام متاحة ليك لتسجيل مصروف دلوقتي." />
          </div>
        </main>
      </AppShell>
    );
  }

  return (
    <AppShell nav={nav} active="add" householdName={household.name}>
      <main className={styles.page} dir="rtl">
        <div className={styles.content}>
          {header}
          <ExpenseFormClient
            currencyCode={household.currency_code}
            periodStart={eligibility.periodStart}
            today={eligibility.today}
            sections={eligibility.sections}
            initialSectionId={initialSectionId}
            returnHref={returnHref}
          />
        </div>
      </main>
    </AppShell>
  );
}
