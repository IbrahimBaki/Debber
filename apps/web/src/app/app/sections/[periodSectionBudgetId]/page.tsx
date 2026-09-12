import type { Metadata } from "next";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";

import { Amount } from "@/app/app/plan/amount";
import { formatDate } from "@/app/app/plan/format";
import { Icon } from "@/app/app/plan/icons";
import planStyles from "@/app/app/plan/plan.module.css";
import { createClient } from "@/lib/supabase/server";

import { AppShell, type AppNavContext } from "../../app-shell";
import { loadSectionDetail } from "./data";
import styles from "./section-detail.module.css";

// Static metadata keeps this dynamic route server-safe: a generateMetadata here would mean a
// second authorized data read just to name the tab, and would have to duplicate the not-found
// handling below.
export const metadata: Metadata = { title: "تفاصيل القسم" };

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export default async function SectionDetailPage({
  params,
}: {
  params: Promise<{ periodSectionBudgetId: string }>;
}) {
  const { periodSectionBudgetId } = await params;
  if (!uuidPattern.test(periodSectionBudgetId)) notFound();

  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();
  if (claimsError || !claims?.claims?.sub) redirect(`/login?next=/app/sections/${periodSectionBudgetId}`);

  // A single RLS-scoped lookup: not_found covers a nonexistent id, a fixed-kind id, a hidden
  // owner_only section, and a section belonging to another Household identically -- no
  // distinguishing information is ever leaked back through this route (see ./data.ts).
  const view = await loadSectionDetail(supabase, periodSectionBudgetId, claims.claims.sub);
  if (view.status === "not_found") notFound();

  const addExpenseHref = `/app/expenses/new?section=${periodSectionBudgetId}`;
  const nav: AppNavContext = {
    role: view.role,
    periodStatus: view.periodStatus,
    canRecordExpense: view.canRecordExpense,
  };

  return (
    <AppShell nav={nav} active="sections" householdName={view.householdName}>
      <main className={styles.page} dir="rtl">
      <div className={styles.content}>
        <header className={styles.header}>
          <Link href="/app#app-sections" className={styles.backLink} aria-label="رجوع للأقسام">
            <Icon name="arrow" size={20} />
          </Link>
          <h1>{view.sectionName}</h1>
          <span style={{ width: "2.5rem" }} aria-hidden="true" />
        </header>

        <div className={styles.summary}>
          <p className={styles.summaryLabel}>{view.overspent ? "متجاوز بـ" : "المتبقي"}</p>
          <Amount
            value={Math.abs(view.remaining)}
            currencyCode={view.currencyCode}
            tone={view.overspent ? "deficit" : undefined}
            className={styles.summaryAmount}
          />
          <div className={styles.summarySupport}>
            <span>المصروف <Amount value={view.spent} currencyCode={view.currencyCode} /></span>
            <span>المخصص <Amount value={view.allocated} currencyCode={view.currencyCode} /></span>
          </div>
        </div>

        {view.canRecordExpense ? (
          <Link className={styles.addButton} href={addExpenseHref}>
            <Icon name="plus" size={18} /> إضافة مصروف
          </Link>
        ) : null}

        <section aria-labelledby="expenses-title">
          <h2 id="expenses-title" className={styles.expensesHeading}>المصروفات</h2>
          {view.expenses.length > 0 ? (
            <ul className={styles.expenseList}>
              {view.expenses.map((expense) => (
                <li key={expense.id} className={styles.expenseRow}>
                  <Amount value={expense.amount} currencyCode={view.currencyCode} className={styles.expenseAmount} />
                  <div className={styles.expenseDetails}>
                    {expense.description ? <p className={styles.expenseDescription}>{expense.description}</p> : null}
                    <p className={styles.expenseDate}>{formatDate(expense.occurredAt)}</p>
                  </div>
                </li>
              ))}
            </ul>
          ) : (
            <div className={planStyles.emptyState}>
              <span><Icon name="spark" size={20} /></span>
              <p>لسه مفيش مصروفات في القسم ده.</p>
              {view.canRecordExpense ? (
                <Link className={styles.emptyStateAction} href={addExpenseHref}>إضافة مصروف</Link>
              ) : null}
            </div>
          )}
        </section>
      </div>
      </main>
    </AppShell>
  );
}
