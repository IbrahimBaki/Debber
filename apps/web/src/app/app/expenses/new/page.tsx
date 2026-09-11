import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import type { ReactNode } from "react";

import { Icon, type IconName } from "@/app/app/plan/icons";
import { createClient } from "@/lib/supabase/server";

import { resolveExpenseEligibility } from "../eligibility";
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

export default async function NewExpensePage() {
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
  const eligibility = await resolveExpenseEligibility(supabase, household, role);

  const header = (
    <header className={styles.header}>
      <Link href="/app" className={styles.backLink} aria-label="رجوع"><Icon name="arrow" size={20} /></Link>
      <h1>إضافة مصروف</h1>
      <span style={{ width: "2.5rem" }} aria-hidden="true" />
    </header>
  );

  if (eligibility.status === "no_period") redirect("/app");

  if (eligibility.status === "not_open") {
    if (role === "owner") {
      return (
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
      );
    }
    return (
      <main className={styles.page} dir="rtl">
        <div className={styles.content}>
          {header}
          <StateCard title="الشهر لسه ما بدأش" body="لسه مفيش شهر مفتوح لتسجيل المصروفات." />
        </div>
      </main>
    );
  }

  if (eligibility.sections.length === 0) {
    if (role === "owner") {
      return (
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
      );
    }
    return (
      <main className={styles.page} dir="rtl">
        <div className={styles.content}>
          {header}
          <StateCard icon="spark" title="مفيش أقسام متاحة" body="مفيش أقسام متاحة ليك لتسجيل مصروف دلوقتي." />
        </div>
      </main>
    );
  }

  return (
    <main className={styles.page} dir="rtl">
      <div className={styles.content}>
        {header}
        <ExpenseFormClient
          currencyCode={household.currency_code}
          periodStart={eligibility.periodStart}
          today={eligibility.today}
          sections={eligibility.sections}
        />
      </div>
    </main>
  );
}
