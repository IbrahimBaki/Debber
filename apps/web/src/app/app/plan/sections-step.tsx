"use client";

import { useActionState, useState } from "react";

import { addSection, updateSectionAllocation, type PlanActionState } from "./actions";
import { Amount } from "./amount";
import { formatAmount } from "./format";
import { Icon } from "./icons";
import { MoneyInput } from "./money-input";
import styles from "./plan.module.css";
import { useAddForm } from "./use-add-form";

export type SectionAllocation = { id: string; section_id: string; section_name_snapshot: string; planned_amount: number };

const initialState: PlanActionState = {};

function SectionRow({ item, currencyCode }: { item: SectionAllocation; currencyCode: string }) {
  const [editing, setEditing] = useState(false);
  const [state, formAction, pending] = useActionState(updateSectionAllocation, initialState);

  if (editing) {
    return (
      <form action={formAction} className={styles.rowEditForm}>
        <input type="hidden" name="id" value={item.id} />
        <p className={styles.rowEditLabel}>{item.section_name_snapshot}</p>
        <MoneyInput name="amount" label="المخصص الشهري" defaultValue={String(item.planned_amount)} currencyCode={currencyCode} disabled={pending} autoFocus />
        {state.error ? <p className={styles.rowError} role="alert">{state.error}</p> : null}
        <div className={styles.rowActions}>
          <button type="submit" className={styles.saveButton} disabled={pending}>{pending ? "جارٍ الحفظ…" : "حفظ"}</button>
          <button type="button" className={styles.cancelButton} onClick={() => setEditing(false)} disabled={pending}>إلغاء</button>
        </div>
      </form>
    );
  }

  return (
    <div className={styles.itemRow}>
      <div className={styles.itemInfo}>
        <strong>{item.section_name_snapshot}</strong>
        <Amount value={item.planned_amount} currencyCode={currencyCode} />
      </div>
      <button type="button" className={styles.textAction} onClick={() => setEditing(true)}>تعديل المخصص</button>
    </div>
  );
}

function AddSectionForm({ periodId }: { periodId: string }) {
  const [nameValue, setNameValue] = useState("");
  const [operationId, setOperationId] = useState(() => crypto.randomUUID());
  const [state, formAction, pending] = useAddForm(addSection, initialState, () => {
    setNameValue("");
    setOperationId(crypto.randomUUID());
  });

  return (
    <form action={formAction} className={styles.addForm}>
      <input type="hidden" name="periodId" value={periodId} />
      <input type="hidden" name="operationId" value={operationId} />
      <div className={styles.field}>
        <label htmlFor="new-section-name">اسم القسم</label>
        <input
          id="new-section-name"
          name="name"
          placeholder="مثال: مصروف البيت"
          maxLength={120}
          value={nameValue}
          onChange={(event) => setNameValue(event.target.value)}
          disabled={pending}
          required
        />
      </div>
      <p className={styles.fieldHint}>المخصص الشهري يبدأ من صفر؛ اضبطه بعد الإضافة مباشرة.</p>
      {state.error ? <p className={styles.rowError} role="alert">{state.error}</p> : null}
      <button type="submit" className={styles.addButton} disabled={pending}>
        <Icon name="plus" size={18} />
        {pending ? "جارٍ الإضافة…" : "إضافة قسم"}
      </button>
    </form>
  );
}

export function SectionsStep({
  periodId,
  currencyCode,
  sections,
  spendingBudget,
}: {
  periodId: string;
  currencyCode: string;
  sections: SectionAllocation[];
  spendingBudget: number;
}) {
  const allocated = sections.reduce((sum, item) => sum + item.planned_amount, 0);
  const unallocated = spendingBudget - allocated;
  const allocatedPercent = spendingBudget > 0 ? Math.min(100, Math.max(0, (allocated / spendingBudget) * 100)) : 0;

  return (
    <section className={styles.stepSection} aria-labelledby="sections-step-title">
      <div className={styles.stepIntro}>
        <p>الخطوة ٤</p>
        <h2 id="sections-step-title">الأقسام والمخصصات</h2>
        <p className={styles.stepHint}>وزّع ميزانية المصروف على أقسام الحياة اليومية. التوزيع الجزئي مقبول تمامًا.</p>
      </div>

      <div className={styles.relationCard}>
        <div className={styles.relationRow}><span>ميزانية المصروف</span><strong dir="rtl">{formatAmount(spendingBudget)}</strong></div>
        <div className={styles.relationRow}><span>تم توزيعه</span><strong dir="rtl">{formatAmount(allocated)}</strong></div>
        <div className={`${styles.relationRow} ${styles.relationResult}`}><span>غير موزع</span><strong dir="rtl">{formatAmount(unallocated)}</strong></div>
        {spendingBudget > 0 ? (
          <>
            <div
              className={styles.sectionsTrack}
              role="progressbar"
              aria-label="نسبة توزيع ميزانية المصروف على الأقسام"
              aria-valuemin={0}
              aria-valuemax={spendingBudget}
              aria-valuenow={allocated}
              aria-valuetext={`تم توزيع ${formatAmount(allocated)} من ميزانية مصروف قدرها ${formatAmount(spendingBudget)}`}
            >
              <span className={styles.sectionsTrackAllocated} style={{ width: `${allocatedPercent}%` }} />
              <span className={styles.sectionsTrackRemaining} />
            </div>
            <div className={styles.sectionsTrackLabels}>
              <span><i className={styles.sectionsDotAllocated} />موزّع {Math.round(allocatedPercent)}٪</span>
              <span><i className={styles.sectionsDotRemaining} />غير موزّع {Math.round(100 - allocatedPercent)}٪</span>
            </div>
          </>
        ) : null}
      </div>

      {sections.length ? (
        <div className={styles.listSurface}>
          {sections.map((item) => (
            <SectionRow key={item.id} item={item} currencyCode={currencyCode} />
          ))}
        </div>
      ) : (
        <div className={styles.emptyState}>
          <span><Icon name="spark" size={20} /></span>
          <p>لا توجد أقسام بعد.</p>
        </div>
      )}

      <AddSectionForm periodId={periodId} />
    </section>
  );
}
