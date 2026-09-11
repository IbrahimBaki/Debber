"use client";

import { useMemo, useState } from "react";

import { setSpendingBudget, type PlanActionState } from "./actions";
import { formatAmount } from "./format";
import { Icon } from "./icons";
import { MoneyInput } from "./money-input";
import styles from "./plan.module.css";
import { useAddForm } from "./use-add-form";

export type PlanningSummary = {
  total_planned_income: number;
  total_planned_commitments: number;
  available_after_commitments: number;
  spending_budget: number;
  plan_balance: number;
  unallocated_income: number;
  planned_deficit: number;
  total_section_allocations: number;
  unallocated_spending_budget: number;
};

const initialState: PlanActionState = {};

export function BudgetStep({
  periodId,
  currencyCode,
  summary,
}: {
  periodId: string;
  currencyCode: string;
  summary: PlanningSummary;
}) {
  const [draftAmount, setDraftAmount] = useState(String(summary.spending_budget));
  const [state, formAction, pending] = useAddForm(setSpendingBudget, initialState, () => {});

  const previewBalance = useMemo(() => {
    const parsed = Number(draftAmount);
    if (!Number.isFinite(parsed)) return summary.plan_balance;
    return summary.available_after_commitments - parsed;
  }, [draftAmount, summary.available_after_commitments, summary.plan_balance]);

  const previewDeficit = previewBalance < 0;

  return (
    <section className={styles.stepSection} aria-labelledby="budget-step-title">
      <div className={styles.stepIntro}>
        <p>الخطوة ٣</p>
        <h2 id="budget-step-title">ميزانية المصروف</h2>
        <p className={styles.stepHint}>حدّد المبلغ الذي تخطط لصرفه على الأقسام هذا الشهر. القيمة الافتراضية صفر حتى تختارها بنفسك.</p>
      </div>

      <div className={styles.relationCard}>
        <div className={styles.relationRow}>
          <span>إجمالي الدخل</span>
          <strong dir="rtl">{formatAmount(summary.total_planned_income)}</strong>
        </div>
        <div className={styles.relationRow}>
          <span>− الالتزامات الثابتة</span>
          <strong dir="rtl">{formatAmount(summary.total_planned_commitments)}</strong>
        </div>
        <div className={`${styles.relationRow} ${styles.relationResult}`}>
          <span>= المتاح بعد الالتزامات</span>
          <strong dir="rtl">{formatAmount(summary.available_after_commitments)}</strong>
        </div>
      </div>

      <form
        action={formAction}
        className={styles.addForm}
        onChange={(event) => {
          const target = event.target;
          if (target instanceof HTMLInputElement && target.name === "amount") setDraftAmount(target.value);
        }}
      >
        <input type="hidden" name="periodId" value={periodId} />
        <MoneyInput name="amount" label="ميزانية المصروف" defaultValue={String(summary.spending_budget)} currencyCode={currencyCode} disabled={pending} />
        {state.error ? <p className={styles.rowError} role="alert">{state.error}</p> : null}
        <button type="submit" className={styles.addButton} disabled={pending}>
          {pending ? "جارٍ الحفظ…" : "حفظ ميزانية المصروف"}
        </button>
      </form>

      <div className={`${styles.relationCard} ${previewDeficit ? styles.relationCardWarning : styles.relationCardCalm}`}>
        <div className={styles.relationRow}>
          <span>المتاح بعد الالتزامات</span>
          <strong dir="rtl">{formatAmount(summary.available_after_commitments)}</strong>
        </div>
        <div className={styles.relationRow}>
          <span>− ميزانية المصروف</span>
          <strong dir="rtl">{draftAmount ? formatAmount(Number(draftAmount) || 0) : "٠٫٠٠"}</strong>
        </div>
        <div className={`${styles.relationRow} ${styles.relationResult}`}>
          <span>{previewDeficit ? "العجز المخطط" : "غير مخصص"}</span>
          <strong dir="rtl">{formatAmount(Math.abs(previewBalance))}</strong>
        </div>
        {previewDeficit ? (
          <p className={styles.warningNote}>
            <Icon name="alert" size={16} />
            الخطة محتاجة {formatAmount(Math.abs(previewBalance))} أكثر من الدخل المتاح بعد الالتزامات. هذا لا يمنع حفظ الخطة، لكنه يستحق انتباهك.
          </p>
        ) : (
          <p className={styles.calmNote}>
            <Icon name="check" size={16} />
            هذا المبلغ غير مخصص لأي قسم بعد. يمكنك توزيعه في الخطوة التالية أو تركه احتياطيًا.
          </p>
        )}
      </div>
    </section>
  );
}
