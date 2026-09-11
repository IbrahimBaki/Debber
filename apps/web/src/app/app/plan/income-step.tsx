"use client";

import { useActionState, useId, useRef, useState } from "react";

import {
  addIncomeItem,
  deleteIncomeItem,
  setTotalIncomeSharing,
  updateIncomeItem,
  type PlanActionState,
} from "./actions";
import { Amount } from "./amount";
import { formatAmount } from "./format";
import { Icon } from "./icons";
import { MoneyInput } from "./money-input";
import styles from "./plan.module.css";
import { useAddForm } from "./use-add-form";

export type IncomeItem = { id: string; name_snapshot: string; planned_amount: number };

const initialState: PlanActionState = {};

function IncomeRow({ item, currencyCode }: { item: IncomeItem; currencyCode: string }) {
  const [editing, setEditing] = useState(false);
  const [confirmingDelete, setConfirmingDelete] = useState(false);
  const [updateState, updateAction, updatePending] = useActionState(updateIncomeItem, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteIncomeItem, initialState);

  if (editing) {
    return (
      <form action={updateAction} className={styles.rowEditForm}>
        <input type="hidden" name="id" value={item.id} />
        <div className={styles.field}>
          <label htmlFor={`income-name-${item.id}`}>اسم الدخل</label>
          <input id={`income-name-${item.id}`} name="name" defaultValue={item.name_snapshot} maxLength={120} required disabled={updatePending} />
        </div>
        <MoneyInput name="amount" label="المبلغ" defaultValue={String(item.planned_amount)} currencyCode={currencyCode} disabled={updatePending} autoFocus />
        {updateState.error ? <p className={styles.rowError} role="alert">{updateState.error}</p> : null}
        <div className={styles.rowActions}>
          <button type="submit" className={styles.saveButton} disabled={updatePending}>{updatePending ? "جارٍ الحفظ…" : "حفظ"}</button>
          <button type="button" className={styles.cancelButton} onClick={() => setEditing(false)} disabled={updatePending}>إلغاء</button>
        </div>
      </form>
    );
  }

  if (confirmingDelete) {
    return (
      <div className={`${styles.itemRow} ${styles.itemRowConfirm}`}>
        <div className={styles.itemInfo}>
          <strong>حذف {item.name_snapshot}؟</strong>
          <span className={styles.itemMeta}>هذا الإجراء لا يمكن التراجع عنه.</span>
        </div>
        <div className={styles.rowActions}>
          <form action={deleteAction}>
            <input type="hidden" name="id" value={item.id} />
            <button type="submit" className={styles.confirmDeleteButton} disabled={deletePending}>
              {deletePending ? "جارٍ الحذف…" : "تأكيد الحذف"}
            </button>
          </form>
          <button type="button" className={styles.cancelButton} onClick={() => setConfirmingDelete(false)} disabled={deletePending}>إلغاء</button>
        </div>
        {deleteState.error ? <p className={styles.rowError} role="alert">{deleteState.error}</p> : null}
      </div>
    );
  }

  return (
    <div className={styles.itemRow}>
      <div className={styles.itemInfo}>
        <strong>{item.name_snapshot}</strong>
        <Amount value={item.planned_amount} currencyCode={currencyCode} />
      </div>
      <div className={styles.rowActions}>
        <button type="button" className={styles.textAction} onClick={() => setEditing(true)}>تعديل</button>
        <button type="button" className={styles.textActionDanger} onClick={() => setConfirmingDelete(true)} aria-label={`حذف ${item.name_snapshot}`}>
          <Icon name="trash" size={17} />
        </button>
      </div>
    </div>
  );
}

function AddIncomeForm({ periodId, currencyCode }: { periodId: string; currencyCode: string }) {
  const [nameValue, setNameValue] = useState("");
  const [amountResetKey, setAmountResetKey] = useState(0);
  const [state, formAction, pending] = useAddForm(addIncomeItem, initialState, () => {
    setNameValue("");
    setAmountResetKey((key) => key + 1);
  });

  return (
    <form action={formAction} className={styles.addForm}>
      <input type="hidden" name="periodId" value={periodId} />
      <div className={styles.field}>
        <label htmlFor="new-income-name">اسم الدخل</label>
        <input
          id="new-income-name"
          name="name"
          placeholder="مثال: مرتب"
          maxLength={120}
          value={nameValue}
          onChange={(event) => setNameValue(event.target.value)}
          disabled={pending}
          required
        />
      </div>
      <MoneyInput key={amountResetKey} name="amount" label="المبلغ" currencyCode={currencyCode} disabled={pending} />
      {state.error ? <p className={styles.rowError} role="alert">{state.error}</p> : null}
      <button type="submit" className={styles.addButton} disabled={pending}>
        <Icon name="plus" size={18} />
        {pending ? "جارٍ الإضافة…" : "إضافة دخل"}
      </button>
    </form>
  );
}

function TotalIncomeSharingControl({ householdId, enabled }: { householdId: string; enabled: boolean }) {
  const [state, formAction, pending] = useActionState(setTotalIncomeSharing, initialState);
  const formRef = useRef<HTMLFormElement>(null);
  const switchId = useId();
  const hintId = `${switchId}-hint`;

  return (
    <section className={styles.sharingPanel} aria-labelledby={`${switchId}-title`}>
      <h3 id={`${switchId}-title`} className={styles.sharingPanelTitle}>المشاركة</h3>
      <form ref={formRef} action={formAction}>
        <input type="hidden" name="householdId" value={householdId} />
        <label className={styles.switchRow}>
          <span className={styles.switchLabelText}>
            <strong>مشاركة إجمالي الدخل</strong>
            <span className={styles.switchDescription}>
              {enabled ? "الأعضاء يقدروا يشوفوا إجمالي الدخل فقط." : "إجمالي الدخل مش ظاهر للأعضاء."}
            </span>
          </span>
          <span className={styles.switchControl}>
            <input
              type="checkbox"
              name="enabled"
              value="true"
              defaultChecked={enabled}
              disabled={pending}
              aria-describedby={hintId}
              onChange={() => formRef.current?.requestSubmit()}
            />
            <span className={styles.switchTrack} aria-hidden="true">
              <span className={styles.switchThumb} />
            </span>
          </span>
        </label>
        <p id={hintId} className={styles.fieldHint}>تفاصيل مصادر الدخل بتفضل خاصة دايمًا، حتى مع تفعيل المشاركة.</p>
        {pending ? <p role="status" className={styles.fieldHint}>جارٍ الحفظ…</p> : null}
        {state.error ? <p className={styles.rowError} role="alert">{state.error}</p> : null}
      </form>
    </section>
  );
}

export function IncomeStep({
  periodId,
  currencyCode,
  income,
  householdId,
  shareTotalIncomeWithMembers,
}: {
  periodId: string;
  currencyCode: string;
  income: IncomeItem[];
  householdId: string;
  shareTotalIncomeWithMembers: boolean;
}) {
  const total = income.reduce((sum, item) => sum + item.planned_amount, 0);

  return (
    <section className={styles.stepSection} aria-labelledby="income-step-title">
      <div className={styles.stepIntro}>
        <p>الخطوة ١</p>
        <h2 id="income-step-title">دخل الشهر</h2>
        <p className={styles.stepHint}>أضف كل مصدر دخل متوقع لهذا الشهر. مرتب، دخل إضافي، أو أي مبلغ تعرف قيمته مقدمًا.</p>
      </div>

      {income.length ? (
        <div className={styles.listSurface}>
          {income.map((item) => (
            <IncomeRow key={item.id} item={item} currencyCode={currencyCode} />
          ))}
        </div>
      ) : (
        <div className={styles.emptyState}>
          <span><Icon name="spark" size={20} /></span>
          <p>لم تُضف أي مصادر دخل بعد.</p>
        </div>
      )}

      <div className={styles.totalLine}>
        <span>إجمالي الدخل</span>
        <strong dir="rtl">{formatAmount(total)}</strong>
      </div>

      <AddIncomeForm periodId={periodId} currencyCode={currencyCode} />

      <TotalIncomeSharingControl householdId={householdId} enabled={shareTotalIncomeWithMembers} />
    </section>
  );
}
