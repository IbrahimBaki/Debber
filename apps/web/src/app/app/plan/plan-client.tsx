"use client";

import { useState } from "react";
import Image from "next/image";

import { Amount } from "./amount";
import type { PlanningSummary } from "./budget-step";
import { BudgetStep } from "./budget-step";
import type { Commitment } from "./commitments-step";
import { CommitmentsStep } from "./commitments-step";
import { formatDateRange } from "./format";
import { Icon } from "./icons";
import type { IncomeItem } from "./income-step";
import { IncomeStep } from "./income-step";
import { ReviewStep } from "./review-step";
import type { SectionAllocation } from "./sections-step";
import { SectionsStep } from "./sections-step";
import styles from "./plan.module.css";

const STEPS = [
  { key: "income", label: "الدخل" },
  { key: "commitments", label: "الالتزامات" },
  { key: "budget", label: "الميزانية" },
  { key: "sections", label: "الأقسام" },
  { key: "review", label: "المراجعة" },
] as const;

type StepKey = (typeof STEPS)[number]["key"];

export function PlanClient({
  mode,
  household,
  period,
  summary,
  income,
  commitments,
  sections,
}: {
  mode: "draft" | "open";
  household: {
    id: string;
    name: string;
    currency_code: string;
    period_start_day: number;
    timezone: string;
    share_total_income_with_members: boolean;
  };
  period: { id: string; periodKey: string; startDate: string; endDate: string };
  summary: PlanningSummary | null;
  income: IncomeItem[];
  commitments: Commitment[];
  sections: SectionAllocation[];
}) {
  const [step, setStep] = useState<StepKey>("income");
  const currencyCode = household.currency_code;
  const safeSummary: PlanningSummary = summary ?? {
    total_planned_income: 0,
    total_planned_commitments: 0,
    available_after_commitments: 0,
    spending_budget: 0,
    plan_balance: 0,
    unallocated_income: 0,
    planned_deficit: 0,
    total_section_allocations: 0,
    unallocated_spending_budget: 0,
  };
  const isDeficit = safeSummary.plan_balance < 0;
  const stepComplete: Record<StepKey, boolean> = {
    income: income.length > 0,
    commitments: commitments.length > 0,
    budget: safeSummary.spending_budget > 0,
    sections: sections.length > 0,
    review: mode === "open",
  };

  return (
    <main className={styles.page} dir="rtl">
      <div className={styles.content}>
        <header className={styles.header}>
          <Image src="/brand/mark.svg" alt="" width={34} height={34} />
          <div>
            <p className={styles.headerEyebrow}>{household.name} · {formatDateRange(period.startDate, period.endDate)}</p>
            <h1>{mode === "draft" ? "جهّز خطة الشهر" : "تعديل الخطة"}</h1>
          </div>
        </header>

        <div className={styles.planGrid}>
          <div className={styles.planMain}>
            <nav className={styles.stepNav} aria-label="خطوات إعداد الخطة">
              {STEPS.map((item, index) => (
                <button
                  key={item.key}
                  type="button"
                  className={step === item.key ? styles.stepPillActive : styles.stepPill}
                  onClick={() => setStep(item.key)}
                  aria-current={step === item.key ? "step" : undefined}
                >
                  <span className={styles.stepNumber}>
                    {stepComplete[item.key] ? <Icon name="check" size={12} /> : index + 1}
                  </span>
                  {item.label}
                </button>
              ))}
            </nav>

            {step === "income" ? (
              <IncomeStep
                periodId={period.id}
                currencyCode={currencyCode}
                income={income}
                householdId={household.id}
                shareTotalIncomeWithMembers={household.share_total_income_with_members}
              />
            ) : null}
            {step === "commitments" ? (
              <CommitmentsStep periodId={period.id} currencyCode={currencyCode} commitments={commitments} canOperate={mode === "open"} />
            ) : null}
            {step === "budget" ? <BudgetStep periodId={period.id} currencyCode={currencyCode} summary={safeSummary} /> : null}
            {step === "sections" ? (
              <SectionsStep periodId={period.id} currencyCode={currencyCode} sections={sections} spendingBudget={safeSummary.spending_budget} />
            ) : null}
            {step === "review" ? (
              <ReviewStep
                mode={mode}
                periodId={period.id}
                periodStart={period.startDate}
                periodEnd={period.endDate}
                currencyCode={currencyCode}
                summary={safeSummary}
                income={income}
                commitments={commitments}
                sections={sections}
              />
            ) : null}
          </div>

          <aside className={styles.summaryDock} aria-labelledby="summary-dock-title">
            <p id="summary-dock-title" className={styles.summaryLabel}>{isDeficit ? "العجز المخطط" : "غير مخصص"}</p>
            <Amount value={Math.abs(safeSummary.plan_balance)} currencyCode={currencyCode} tone={isDeficit ? "deficit" : "positive"} className={styles.summaryHeadline} />
            <dl className={styles.summaryStats}>
              <div><dt>الدخل</dt><dd><Amount value={safeSummary.total_planned_income} currencyCode={currencyCode} /></dd></div>
              <div><dt>الالتزامات</dt><dd><Amount value={safeSummary.total_planned_commitments} currencyCode={currencyCode} /></dd></div>
              <div><dt>ميزانية المصروف</dt><dd><Amount value={safeSummary.spending_budget} currencyCode={currencyCode} /></dd></div>
              <div><dt>غير موزع من الميزانية</dt><dd><Amount value={safeSummary.unallocated_spending_budget} currencyCode={currencyCode} /></dd></div>
            </dl>
          </aside>
        </div>
      </div>
    </main>
  );
}
