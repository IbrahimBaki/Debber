"use client";

import Link from "next/link";
import { useActionState, useEffect, useRef, useState } from "react";

import { markCommitmentPaid, setCommitmentSkipped, type PlanActionState } from "./plan/actions";
import { Amount } from "./plan/amount";
import { formatAmount, formatDate } from "./plan/format";
import { Icon } from "./plan/icons";
import planStyles from "./plan/plan.module.css";
import type { OwnerCommitment, OwnerCommitmentsView } from "./owner-commitments-data";
import styles from "./owner-commitments.module.css";

const initialState: PlanActionState = {};

function StatusLabel({ status, overdue }: { status: OwnerCommitment["status"]; overdue: boolean }) {
  if (status === "paid") {
    return (
      <span className={styles.statusPaid}>
        <Icon name="check" size={14} /> مدفوع
      </span>
    );
  }
  if (status === "skipped") {
    return (
      <span className={styles.statusSkipped}>
        <Icon name="skip" size={14} /> تم تخطيه هذا الشهر
      </span>
    );
  }
  if (overdue) {
    return (
      <span className={styles.statusOverdue}>
        <Icon name="alert" size={14} /> فات موعده
      </span>
    );
  }
  return (
    <span className={styles.statusPending}>
      <Icon name="clock" size={14} /> منتظر
    </span>
  );
}

function CommitmentRow({
  item,
  currencyCode,
  canAct,
}: {
  item: OwnerCommitment;
  currencyCode: string;
  canAct: boolean;
}) {
  const [confirming, setConfirming] = useState<"paid" | "skip" | null>(null);
  const [paidState, paidAction, paidPending] = useActionState(markCommitmentPaid, initialState);
  const [skipState, skipAction, skipPending] = useActionState(setCommitmentSkipped, initialState);
  const confirmRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (confirming) confirmRef.current?.focus();
  }, [confirming]);

  const displayAmount = item.status === "paid" ? (item.actualAmount ?? item.plannedAmount) : item.plannedAmount;

  return (
    <div className={planStyles.itemRow}>
      <div className={planStyles.itemInfo}>
        <strong>{item.name}</strong>
        <span className={planStyles.itemMeta}>
          {item.dueDate ? <>موعد الاستحقاق: {formatDate(item.dueDate)} · </> : null}
          <StatusLabel status={item.status} overdue={item.overdue} />
        </span>
        <Amount value={displayAmount} currencyCode={currencyCode} />
      </div>

      {canAct && item.status === "pending" ? (
        confirming === "paid" ? (
          <div ref={confirmRef} tabIndex={-1} className={styles.confirmBlock}>
            <p>
              تأكيد دفع {item.name} بمبلغ {formatAmount(item.plannedAmount)}؟
            </p>
            <div className={planStyles.rowActions}>
              <form action={paidAction}>
                <input type="hidden" name="id" value={item.id} />
                <button type="submit" className={planStyles.saveButton} disabled={paidPending}>
                  {paidPending ? "جارٍ الحفظ…" : "تأكيد الدفع"}
                </button>
              </form>
              <button type="button" className={planStyles.cancelButton} onClick={() => setConfirming(null)} disabled={paidPending}>
                إلغاء
              </button>
            </div>
          </div>
        ) : confirming === "skip" ? (
          <div ref={confirmRef} tabIndex={-1} className={styles.confirmBlock}>
            <p>هيتجاهل الالتزام في حساب خطة الشهر ده.</p>
            <div className={planStyles.rowActions}>
              <form action={skipAction}>
                <input type="hidden" name="id" value={item.id} />
                <input type="hidden" name="skip" value="true" />
                <button type="submit" className={planStyles.saveButton} disabled={skipPending}>
                  {skipPending ? "جارٍ الحفظ…" : "تأكيد التخطي"}
                </button>
              </form>
              <button type="button" className={planStyles.cancelButton} onClick={() => setConfirming(null)} disabled={skipPending}>
                إلغاء
              </button>
            </div>
          </div>
        ) : (
          <div className={planStyles.rowActions}>
            <button type="button" className={planStyles.textAction} onClick={() => setConfirming("paid")}>
              تم الدفع
            </button>
            <button type="button" className={planStyles.textAction} onClick={() => setConfirming("skip")}>
              تخطي هذا الشهر
            </button>
          </div>
        )
      ) : null}

      {canAct && item.status === "skipped" ? (
        <form action={skipAction}>
          <input type="hidden" name="id" value={item.id} />
          <input type="hidden" name="skip" value="false" />
          <button type="submit" className={planStyles.textAction} disabled={skipPending}>
            {skipPending ? "جارٍ الحفظ…" : "إرجاع للمنتظر"}
          </button>
        </form>
      ) : null}

      {paidState.error ? (
        <p className={planStyles.rowError} role="alert">
          {paidState.error}
        </p>
      ) : null}
      {skipState.error ? (
        <p className={planStyles.rowError} role="alert">
          {skipState.error}
        </p>
      ) : null}
    </div>
  );
}

export function OwnerCommitmentsSection({
  view,
  currencyCode,
}: {
  view: OwnerCommitmentsView;
  currencyCode: string;
}) {
  if (view.status === "no_period") return null;

  const canAct = view.status === "open";

  return (
    <section className={styles.section} aria-labelledby="commitments-title">
      <div className={styles.header}>
        <h2 id="commitments-title">الالتزامات الثابتة</h2>
        <Link href="/app/plan" className={planStyles.textAction}>
          تعديل الخطة
        </Link>
      </div>

      {view.status === "draft" ? (
        <p className={styles.note}>لسه بتجهّز خطة الشهر. أكمل الإعداد من صفحة الخطة قبل ما تبدأ الشهر.</p>
      ) : null}
      {view.status === "closed" ? <p className={styles.note}>الشهر ده مقفول، والبيانات هنا للعرض فقط.</p> : null}

      {view.commitments.length === 0 ? (
        <div className={planStyles.emptyState}>
          <span>
            <Icon name="spark" size={20} />
          </span>
          <p>لا توجد التزامات ثابتة مضافة.</p>
        </div>
      ) : (
        <>
          <div className={planStyles.listSurface}>
            {view.commitments.map((item) => (
              <CommitmentRow key={item.id} item={item} currencyCode={currencyCode} canAct={canAct} />
            ))}
          </div>
          <dl className={styles.summary}>
            <div>
              <dt>المخطط</dt>
              <dd>
                <Amount value={view.plannedTotal} currencyCode={currencyCode} />
              </dd>
            </div>
            <div>
              <dt>مدفوع</dt>
              <dd>
                <Amount value={view.paidTotal} currencyCode={currencyCode} />
              </dd>
            </div>
            <div>
              <dt>منتظر</dt>
              <dd>
                <Amount value={view.pendingTotal} currencyCode={currencyCode} />
              </dd>
            </div>
            {view.skippedTotal > 0 ? (
              <div>
                <dt>متخطى</dt>
                <dd>
                  <Amount value={view.skippedTotal} currencyCode={currencyCode} />
                </dd>
              </div>
            ) : null}
          </dl>
        </>
      )}
    </section>
  );
}
