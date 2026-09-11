"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";

import { Amount } from "@/app/app/plan/amount";
import { formatAmount } from "@/app/app/plan/format";
import { Icon } from "@/app/app/plan/icons";
import { currencyLabel, MoneyInput } from "@/app/app/plan/money-input";

import { recordExpenseAction, voidExpenseAction, type ExpenseActionState } from "./actions";
import type { EligibleSection } from "../eligibility";
import styles from "./expenses.module.css";
import { useExpenseForm } from "./use-expense-form";

const initialState: ExpenseActionState = {};

function newTransactionId() {
  return crypto.randomUUID();
}

export function ExpenseFormClient({
  currencyCode,
  periodStart,
  today,
  sections,
}: {
  currencyCode: string;
  periodStart: string;
  today: string;
  sections: EligibleSection[];
}) {
  const router = useRouter();
  const [phase, setPhase] = useState<"form" | "success" | "voided">("form");
  const [transactionId, setTransactionId] = useState(newTransactionId);
  const [sectionId, setSectionId] = useState(sections[0]?.id ?? "");
  const [amountResetKey, setAmountResetKey] = useState(0);
  const [lastResult, setLastResult] = useState<ExpenseActionState["success"] | null>(null);
  const [confirmingVoid, setConfirmingVoid] = useState(false);

  const [createState, createAction, creating] = useExpenseForm(recordExpenseAction, initialState, (state) => {
    if (state.success) {
      setLastResult(state.success);
      setPhase("success");
    }
  });

  const [voidState, voidAction, voiding] = useExpenseForm(voidExpenseAction, initialState, (state) => {
    if (!state.error) setPhase("voided");
  });

  const selectedSection = useMemo(() => sections.find((section) => section.id === sectionId), [sections, sectionId]);

  function startNewExpense(preferredSectionId?: string) {
    setTransactionId(newTransactionId());
    setAmountResetKey((key) => key + 1);
    if (preferredSectionId) setSectionId(preferredSectionId);
    setLastResult(null);
    setConfirmingVoid(false);
    setPhase("form");
    // The section list's displayed allocated/spent figures are informational (not the
    // authorization check, which record_expense always re-derives) but should not visibly go
    // stale across several expenses added in a row without leaving the page.
    router.refresh();
  }

  if (phase === "success" && lastResult) {
    return (
      <div className={styles.successCard} role="status">
        <span><Icon name="check" size={22} /></span>
        <h1>تم تسجيل المصروف</h1>
        <Amount value={lastResult.amount} currencyCode={lastResult.currencyCode} className={styles.successAmount} />
        <p className={styles.successSection}>{lastResult.sectionName}</p>
        {lastResult.overspent ? (
          <p className={styles.overspendNote}>
            <Icon name="alert" size={16} />
            {lastResult.sectionName} تجاوز المخصص بـ {formatAmount(lastResult.overspentBy)} {currencyLabel(lastResult.currencyCode)}
          </p>
        ) : null}
        <div className={styles.successActions}>
          <button type="button" className={styles.primaryButton} onClick={() => startNewExpense()}>
            إضافة مصروف آخر
          </button>
          {confirmingVoid ? (
            <div className={styles.voidConfirm}>
              <span>إلغاء هذا المصروف؟</span>
              <div className={styles.voidConfirmActions}>
                <form action={voidAction}>
                  <input type="hidden" name="transactionId" value={lastResult.transactionId} />
                  <button type="submit" className={styles.confirmVoidButton} disabled={voiding}>
                    {voiding ? "جارٍ الإلغاء…" : "تأكيد الإلغاء"}
                  </button>
                </form>
                <button type="button" className={styles.cancelVoidButton} onClick={() => setConfirmingVoid(false)} disabled={voiding}>
                  تراجع
                </button>
              </div>
            </div>
          ) : (
            <button type="button" className={styles.voidButton} onClick={() => setConfirmingVoid(true)}>
              إلغاء المصروف
            </button>
          )}
          {voidState.error ? <p className={styles.rowError} role="alert">{voidState.error}</p> : null}
          <Link href="/app" className={styles.quietLink}>رجوع</Link>
        </div>
      </div>
    );
  }

  if (phase === "voided" && lastResult) {
    return (
      <div className={styles.voidedCard} role="status">
        <span><Icon name="skip" size={20} /></span>
        <h1>تم إلغاء المصروف</h1>
        <p className={styles.successSection}>ملغي — {lastResult.sectionName}</p>
        <div className={styles.successActions}>
          <button type="button" className={styles.primaryButton} onClick={() => startNewExpense(sectionId)}>
            تسجيل المصروف الصحيح
          </button>
          <Link href="/app" className={styles.quietLink}>رجوع</Link>
        </div>
      </div>
    );
  }

  return (
    <form action={createAction} className={styles.form}>
      <input type="hidden" name="periodSectionBudgetId" value={sectionId} />
      <input type="hidden" name="transactionId" value={transactionId} />
      <input type="hidden" name="sectionName" value={selectedSection?.name ?? ""} />
      <input type="hidden" name="currencyCode" value={currencyCode} />

      <MoneyInput key={amountResetKey} name="amount" label="المبلغ" currencyCode={currencyCode} disabled={creating} autoFocus size="hero" />

      <div className={styles.field}>
        <label htmlFor="expense-section">القسم</label>
        {sections.length > 1 ? (
          <select id="expense-section" value={sectionId} onChange={(event) => setSectionId(event.target.value)} disabled={creating} required>
            {sections.map((section) => (
              <option key={section.id} value={section.id}>{section.name}</option>
            ))}
          </select>
        ) : (
          <select id="expense-section" value={sectionId} disabled>
            <option value={sectionId}>{selectedSection?.name}</option>
          </select>
        )}
        {selectedSection ? (
          <div className={styles.sectionMeta}>
            <span>المخصص <Amount value={selectedSection.allocated} currencyCode={currencyCode} /></span>
            <span>المصروف <Amount value={selectedSection.spent} currencyCode={currencyCode} /></span>
            <span>المتبقي <Amount value={selectedSection.allocated - selectedSection.spent} currencyCode={currencyCode} tone={selectedSection.allocated - selectedSection.spent < 0 ? "deficit" : undefined} /></span>
          </div>
        ) : null}
      </div>

      <div className={`${styles.field} ${styles.fieldSecondary}`}>
        <label htmlFor="expense-date">التاريخ</label>
        <input id="expense-date" type="date" name="occurredAt" defaultValue={today} min={periodStart} max={today} disabled={creating} required />
      </div>

      <div className={`${styles.field} ${styles.fieldSecondary}`}>
        <label htmlFor="expense-note">ملاحظة (اختياري)</label>
        <textarea id="expense-note" name="description" maxLength={500} disabled={creating} />
      </div>

      {createState.error ? <p className={styles.rowError} role="alert">{createState.error}</p> : null}

      <div className={styles.spacer} />
      <button type="submit" className={styles.submitButton} disabled={creating || !sectionId}>
        {creating ? "جارٍ التسجيل…" : "تسجيل المصروف"}
      </button>
    </form>
  );
}
