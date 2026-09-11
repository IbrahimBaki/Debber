"use client";

import { useActionState, useState } from "react";

import {
  addOneTimeCommitment,
  addRecurringCommitment,
  setCommitmentSkipped,
  stopRecurringCommitment,
  updateCommitmentAmount,
  type PlanActionState,
} from "./actions";
import { Amount } from "./amount";
import { formatAmount } from "./format";
import { Icon } from "./icons";
import { MoneyInput } from "./money-input";
import styles from "./plan.module.css";
import { useAddForm } from "./use-add-form";

export type Commitment = {
  id: string;
  name_snapshot: string;
  planned_amount: number;
  status: "pending" | "paid" | "skipped";
  fixed_commitment_template_id: string | null;
  isRecurringActive: boolean;
};

const initialState: PlanActionState = {};

function CommitmentRow({
  item,
  currencyCode,
  canOperate,
}: {
  item: Commitment;
  currencyCode: string;
  canOperate: boolean;
}) {
  const [editing, setEditing] = useState(false);
  const [amountState, amountAction, amountPending] = useActionState(updateCommitmentAmount, initialState);
  const [skipState, skipAction, skipPending] = useActionState(setCommitmentSkipped, initialState);
  const [stopState, stopAction, stopPending] = useActionState(stopRecurringCommitment, initialState);
  const isRecurring = Boolean(item.fixed_commitment_template_id);
  const skipped = item.status === "skipped";

  if (editing) {
    return (
      <form action={amountAction} className={styles.rowEditForm}>
        <input type="hidden" name="id" value={item.id} />
        <p className={styles.rowEditLabel}>{item.name_snapshot}</p>
        <MoneyInput name="amount" label="المبلغ المخطط" defaultValue={String(item.planned_amount)} currencyCode={currencyCode} disabled={amountPending} autoFocus />
        {amountState.error ? <p className={styles.rowError} role="alert">{amountState.error}</p> : null}
        <div className={styles.rowActions}>
          <button type="submit" className={styles.saveButton} disabled={amountPending}>{amountPending ? "جارٍ الحفظ…" : "حفظ"}</button>
          <button type="button" className={styles.cancelButton} onClick={() => setEditing(false)} disabled={amountPending}>إلغاء</button>
        </div>
      </form>
    );
  }

  return (
    <div className={`${styles.itemRow} ${skipped ? styles.itemRowMuted : ""}`}>
      <div className={styles.itemInfo}>
        <strong>{item.name_snapshot}</strong>
        <span className={styles.itemMeta}>
          {isRecurring ? "يتكرر شهريًا" : "هذا الشهر فقط"}
          {skipped ? " · تم تخطيه هذا الشهر" : ""}
        </span>
        <Amount value={item.planned_amount} currencyCode={currencyCode} />
      </div>
      <div className={styles.rowActions}>
        <button type="button" className={styles.textAction} onClick={() => setEditing(true)}>تعديل</button>
        {canOperate ? (
          <form action={skipAction}>
            <input type="hidden" name="id" value={item.id} />
            <input type="hidden" name="skip" value={skipped ? "false" : "true"} />
            <button type="submit" className={styles.textAction} disabled={skipPending}>
              {skipped ? "إلغاء التخطي" : "تخطي هذا الشهر"}
            </button>
          </form>
        ) : null}
        {isRecurring && item.isRecurringActive ? (
          <form action={stopAction}>
            <input type="hidden" name="templateId" value={item.fixed_commitment_template_id ?? ""} />
            <button type="submit" className={styles.textAction} disabled={stopPending} title="لن يتكرر هذا الالتزام في الشهور القادمة">
              <Icon name="pause" size={16} />
              إيقاف التكرار
            </button>
          </form>
        ) : null}
      </div>
      {skipState.error ? <p className={styles.rowError} role="alert">{skipState.error}</p> : null}
      {stopState.error ? <p className={styles.rowError} role="alert">{stopState.error}</p> : null}
      {isRecurring && !item.isRecurringActive ? <p className={styles.rowNote}>لن يتكرر هذا الالتزام بدءًا من الشهر القادم.</p> : null}
    </div>
  );
}

function AddCommitmentForm({ periodId, currencyCode }: { periodId: string; currencyCode: string }) {
  const [recurrence, setRecurrence] = useState<"recurring" | "one_time">("recurring");
  const [nameValue, setNameValue] = useState("");
  const [amountResetKey, setAmountResetKey] = useState(0);
  const [operationId, setOperationId] = useState(() => crypto.randomUUID());
  const action = recurrence === "recurring" ? addRecurringCommitment : addOneTimeCommitment;

  const [state, formAction, pending] = useAddForm(action, initialState, () => {
    setNameValue("");
    setAmountResetKey((key) => key + 1);
    setOperationId(crypto.randomUUID());
  });

  return (
    <form action={formAction} className={styles.addForm}>
      <input type="hidden" name="periodId" value={periodId} />
      <input type="hidden" name="operationId" value={operationId} />
      <div className={styles.field}>
        <label htmlFor="new-commitment-name">اسم الالتزام</label>
        <input
          id="new-commitment-name"
          name="name"
          placeholder="مثال: الإيجار"
          maxLength={160}
          value={nameValue}
          onChange={(event) => setNameValue(event.target.value)}
          disabled={pending}
          required
        />
      </div>
      <MoneyInput key={amountResetKey} name="amount" label="المبلغ المخطط" currencyCode={currencyCode} disabled={pending} />
      <fieldset className={styles.recurrenceGroup} disabled={pending}>
        <legend>التكرار</legend>
        <label className={recurrence === "recurring" ? styles.recurrenceOptionSelected : styles.recurrenceOption}>
          <input type="radio" name="recurrence" checked={recurrence === "recurring"} onChange={() => setRecurrence("recurring")} />
          يتكرر شهريًا
        </label>
        <label className={recurrence === "one_time" ? styles.recurrenceOptionSelected : styles.recurrenceOption}>
          <input type="radio" name="recurrence" checked={recurrence === "one_time"} onChange={() => setRecurrence("one_time")} />
          هذا الشهر فقط
        </label>
      </fieldset>
      {state.error ? <p className={styles.rowError} role="alert">{state.error}</p> : null}
      <button type="submit" className={styles.addButton} disabled={pending}>
        <Icon name="plus" size={18} />
        {pending ? "جارٍ الإضافة…" : "إضافة التزام"}
      </button>
    </form>
  );
}

export function CommitmentsStep({
  periodId,
  currencyCode,
  commitments,
  canOperate,
}: {
  periodId: string;
  currencyCode: string;
  commitments: Commitment[];
  canOperate: boolean;
}) {
  const total = commitments.filter((item) => item.status !== "skipped").reduce((sum, item) => sum + item.planned_amount, 0);

  return (
    <section className={styles.stepSection} aria-labelledby="commitments-step-title">
      <div className={styles.stepIntro}>
        <p>الخطوة ٢</p>
        <h2 id="commitments-step-title">الالتزامات الثابتة</h2>
        <p className={styles.stepHint}>الإيجار، القسط، الجمعية… مبالغ ثابتة منفصلة عن مصروف الأقسام اليومي.</p>
      </div>

      {commitments.length ? (
        <div className={styles.listSurface}>
          {commitments.map((item) => (
            <CommitmentRow key={item.id} item={item} currencyCode={currencyCode} canOperate={canOperate} />
          ))}
        </div>
      ) : (
        <div className={styles.emptyState}>
          <span><Icon name="spark" size={20} /></span>
          <p>لا توجد التزامات ثابتة مضافة بعد.</p>
        </div>
      )}

      <div className={styles.totalLine}>
        <span>إجمالي الالتزامات المخطّطة</span>
        <strong dir="rtl">{formatAmount(total)}</strong>
      </div>

      <AddCommitmentForm periodId={periodId} currencyCode={currencyCode} />
    </section>
  );
}
