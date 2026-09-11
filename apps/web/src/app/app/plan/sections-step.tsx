"use client";

import { useActionState, useEffect, useRef, useState } from "react";

import { addSection, updateSectionAllocation, updateSectionSharing, type PlanActionState } from "./actions";
import { Amount } from "./amount";
import { formatAmount } from "./format";
import { Icon } from "./icons";
import { MoneyInput } from "./money-input";
import styles from "./plan.module.css";
import { useAddForm } from "./use-add-form";

export type SectionAllocation = {
  id: string;
  section_id: string;
  section_name_snapshot: string;
  planned_amount: number;
  visibility_scope: "owner_only" | "household" | "custom";
  member_access: "view" | "contribute";
};

type SharingMode = "private" | "shared_view" | "shared_contribute";

function currentSharingMode(item: SectionAllocation): SharingMode | "custom" {
  if (item.visibility_scope === "household") return item.member_access === "contribute" ? "shared_contribute" : "shared_view";
  if (item.visibility_scope === "owner_only") return "private";
  return "custom";
}

const modeLabels: Record<SharingMode, string> = {
  private: "خاص بيا",
  shared_view: "مشترك — مشاهدة",
  shared_contribute: "مشترك — مساهمة",
};

const modeHints: Record<SharingMode, string> = {
  private: "خاص: القسم ده يظهر لك بس.",
  shared_view: "مشاهدة: يقدر يشوف المخصص والمصروف والمتبقي.",
  shared_contribute: "مساهمة: يقدر يشوف القسم ويسجل فيه مصروفات.",
};

function SectionSharingControl({ item }: { item: SectionAllocation }) {
  const current = currentSharingMode(item);
  const [confirmMode, setConfirmMode] = useState<SharingMode | null>(null);
  const [state, formAction, pending] = useActionState(updateSectionSharing, initialState);
  const formRef = useRef<HTMLFormElement>(null);
  const modeInputRef = useRef<HTMLInputElement>(null);
  const confirmRef = useRef<HTMLDivElement>(null);

  // A confirmed mode change revalidates the page and this component re-renders with a new
  // `current`; clear any pending confirmation for the resolved mode during render (the React-
  // recommended way to reset state on a prop change) rather than in an effect.
  const [confirmedFor, setConfirmedFor] = useState(current);
  if (current !== confirmedFor) {
    setConfirmedFor(current);
    setConfirmMode(null);
  }

  useEffect(() => {
    if (confirmMode) confirmRef.current?.focus();
  }, [confirmMode]);

  function submitMode(mode: SharingMode) {
    if (modeInputRef.current) modeInputRef.current.value = mode;
    formRef.current?.requestSubmit();
  }

  function handleChoose(mode: SharingMode) {
    if (mode === current) return;
    // Broadening from a scope a Member cannot currently see (private, or an unsupported
    // custom grant) into either shared mode can also expose that section's previously
    // recorded historical data under the MVP's live-authorization model -- see D-031.
    const broadening = item.visibility_scope !== "household" && mode !== "private";
    if (broadening) setConfirmMode(mode);
    else submitMode(mode);
  }

  return (
    <div className={styles.sectionSharing}>
      <form ref={formRef} action={formAction}>
        <input type="hidden" name="sectionId" value={item.section_id} />
        <input ref={modeInputRef} type="hidden" name="mode" defaultValue={current === "custom" ? "" : current} />
      </form>
      <fieldset className={styles.sharingGroup} disabled={pending}>
        <legend className={styles.sharingLegend}>مشاركة القسم</legend>
        {(Object.keys(modeLabels) as SharingMode[]).map((mode) => (
          <label key={mode} className={current === mode ? styles.sharingOptionSelected : styles.sharingOption}>
            <input
              type="radio"
              name={`sharing-${item.id}`}
              checked={current === mode}
              onChange={() => handleChoose(mode)}
              disabled={pending}
            />
            {modeLabels[mode]}
          </label>
        ))}
      </fieldset>
      {current === "custom" ? (
        <p className={styles.rowNote}>هذا القسم بإعداد مشاركة غير مدعوم في هذا العرض. اختر أحد الخيارات أعلاه لاستبداله.</p>
      ) : (
        <p className={styles.fieldHint}>{modeHints[current]}</p>
      )}
      {confirmMode ? (
        <div ref={confirmRef} tabIndex={-1} className={styles.sharingConfirm}>
          <p>مشاركة القسم هتخلي الشريك يقدر يشوف بيانات القسم السابقة كمان.</p>
          <div className={styles.sharingConfirmActions}>
            <button
              type="button"
              className={styles.confirmSharingButton}
              onClick={() => {
                submitMode(confirmMode);
                setConfirmMode(null);
              }}
              disabled={pending}
            >
              {pending ? "جارٍ الحفظ…" : "تأكيد المشاركة"}
            </button>
            <button type="button" className={styles.cancelButton} onClick={() => setConfirmMode(null)} disabled={pending}>
              إلغاء
            </button>
          </div>
        </div>
      ) : null}
      {state.error ? <p className={styles.rowError} role="alert">{state.error}</p> : null}
    </div>
  );
}

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
            <div key={item.id} className={styles.sectionEntry}>
              <SectionRow item={item} currencyCode={currencyCode} />
              <SectionSharingControl item={item} />
            </div>
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
