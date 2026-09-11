"use client";

import { startMonth, type PlanActionState } from "./actions";
import { Amount } from "./amount";
import type { Commitment } from "./commitments-step";
import { formatDateRange } from "./format";
import { Icon } from "./icons";
import type { IncomeItem } from "./income-step";
import type { PlanningSummary } from "./budget-step";
import type { SectionAllocation } from "./sections-step";
import styles from "./plan.module.css";
import { useAddForm } from "./use-add-form";

const initialState: PlanActionState = {};

export function ReviewStep({
  mode,
  periodId,
  periodStart,
  periodEnd,
  currencyCode,
  summary,
  income,
  commitments,
  sections,
}: {
  mode: "draft" | "open";
  periodId: string;
  periodStart: string;
  periodEnd: string;
  currencyCode: string;
  summary: PlanningSummary;
  income: IncomeItem[];
  commitments: Commitment[];
  sections: SectionAllocation[];
}) {
  const [state, formAction, pending] = useAddForm(startMonth, initialState, () => {});
  const isDeficit = summary.plan_balance < 0;

  return (
    <section className={styles.stepSection} aria-labelledby="review-step-title">
      <div className={styles.stepIntro}>
        <p>الخطوة ٥</p>
        <h2 id="review-step-title">مراجعة الخطة</h2>
        <p className={styles.stepHint}>كل الأرقام هنا أرقام مخططة لهذا الشهر، وليست أرقام صرف فعلي.</p>
      </div>

      <div className={styles.reviewHeader}>
        <span>{formatDateRange(periodStart, periodEnd)}</span>
        <span dir="ltr">{currencyCode}</span>
      </div>

      <div className={styles.relationCard}>
        <div className={styles.relationRow}><span>إجمالي الدخل المخطط</span><Amount value={summary.total_planned_income} currencyCode={currencyCode} /></div>
        <div className={styles.relationRow}><span>الالتزامات الثابتة المخططة</span><Amount value={summary.total_planned_commitments} currencyCode={currencyCode} /></div>
        <div className={`${styles.relationRow} ${styles.relationResult}`}><span>المتاح بعد الالتزامات</span><Amount value={summary.available_after_commitments} currencyCode={currencyCode} /></div>
      </div>

      <div className={styles.relationCard}>
        <div className={styles.relationRow}><span>ميزانية المصروف المخططة</span><Amount value={summary.spending_budget} currencyCode={currencyCode} /></div>
        <div className={`${styles.relationRow} ${styles.relationResult}`}>
          <span>{isDeficit ? "العجز المخطط" : "غير مخصص من الدخل"}</span>
          <Amount value={Math.abs(summary.plan_balance)} currencyCode={currencyCode} tone={isDeficit ? "deficit" : "positive"} />
        </div>
      </div>

      <div className={styles.reviewLists}>
        <div>
          <h3>الدخل ({income.length})</h3>
          <ul className={styles.reviewList}>
            {income.map((item) => (
              <li key={item.id}><span>{item.name_snapshot}</span><Amount value={item.planned_amount} currencyCode={currencyCode} /></li>
            ))}
            {income.length === 0 ? <li className={styles.reviewEmpty}>لا يوجد دخل مضاف</li> : null}
          </ul>
        </div>
        <div>
          <h3>الالتزامات ({commitments.length})</h3>
          <ul className={styles.reviewList}>
            {commitments.map((item) => (
              <li key={item.id}>
                <span>{item.name_snapshot}{item.status === "skipped" ? " (تم تخطيه)" : ""}</span>
                <Amount value={item.planned_amount} currencyCode={currencyCode} />
              </li>
            ))}
            {commitments.length === 0 ? <li className={styles.reviewEmpty}>لا توجد التزامات مضافة</li> : null}
          </ul>
        </div>
        <div>
          <h3>الأقسام ({sections.length})</h3>
          <ul className={styles.reviewList}>
            {sections.map((item) => (
              <li key={item.id}><span>{item.section_name_snapshot}</span><Amount value={item.planned_amount} currencyCode={currencyCode} /></li>
            ))}
            {sections.length === 0 ? <li className={styles.reviewEmpty}>لا توجد أقسام مضافة</li> : null}
          </ul>
          <p className={styles.reviewFootnote}>
            غير موزع من ميزانية المصروف: <Amount value={summary.unallocated_spending_budget} currencyCode={currencyCode} />
          </p>
        </div>
      </div>

      {mode === "draft" ? (
        <form action={formAction} className={styles.startForm}>
          <input type="hidden" name="periodId" value={periodId} />
          {state.error ? <p className={styles.rowError} role="alert">{state.error}</p> : null}
          <button type="submit" className={styles.primaryButton} disabled={pending}>
            {pending ? "جارٍ بدء الشهر…" : "ابدأ الشهر"}
          </button>
          <p className={styles.fieldHint}>يمكنك تعديل الخطة بعد بدء الشهر أيضًا.</p>
        </form>
      ) : (
        <div className={styles.openNotice}>
          <Icon name="check" size={17} />
          <p>الشهر مفتوح الآن. أي تعديل هنا يُحفظ فورًا.</p>
        </div>
      )}
    </section>
  );
}
