import Link from "next/link";

import { Amount } from "./plan/amount";
import { formatDateRange } from "./plan/format";
import { Icon } from "./plan/icons";
import planStyles from "./plan/plan.module.css";
import type { MemberMonthlyView } from "./member-data";
import styles from "./member-view.module.css";

function StatusBadge({ status }: { status: "draft" | "open" | "closed" }) {
  const label = status === "open" ? "الشهر مفتوح" : status === "closed" ? "الشهر مغلق" : "لسه ما بدأش";
  return (
    <span className={styles.statusBadge} data-status={status}>
      {label}
    </span>
  );
}

function Header({
  householdName,
  currencyCode,
  periodStart,
  periodEnd,
  status,
}: {
  householdName: string;
  currencyCode: string;
  periodStart: string;
  periodEnd: string;
  status: "draft" | "open" | "closed";
}) {
  return (
    <header className={planStyles.header}>
      <div>
        <p className={planStyles.headerEyebrow}>
          {householdName} · {formatDateRange(periodStart, periodEnd)} · <span dir="ltr">{currencyCode}</span>
        </p>
        <h1>مصروف الشهر</h1>
      </div>
      <StatusBadge status={status} />
    </header>
  );
}

/**
 * Renders only what a Member is authorized to see for the current/last-relevant Budget
 * Period: spending budget, an optional aggregate income total, and the sections currently
 * shared with them. Fixed commitments, the Owner planning summary, and individual income
 * rows never appear here -- they were never fetched (see ./member-data.ts).
 */
export function MemberMonthlyViewPanel({
  householdName,
  currencyCode,
  view,
}: {
  householdName: string;
  currencyCode: string;
  view: MemberMonthlyView;
}) {
  if (view.status === "no_period") {
    return (
      <div className={planStyles.emptyState}>
        <span>
          <Icon name="clock" size={20} />
        </span>
        <p>لسه مفيش شهر متاح دلوقتي.</p>
      </div>
    );
  }

  if (view.status === "draft") {
    return (
      <>
        <Header householdName={householdName} currencyCode={currencyCode} periodStart={view.periodStart} periodEnd={view.periodEnd} status="draft" />
        <div className={planStyles.emptyState}>
          <span>
            <Icon name="clock" size={20} />
          </span>
          <p>الشهر لسه ما بدأش.</p>
        </div>
      </>
    );
  }

  const { spendingBudget, totalIncome, sections, sharedSummary } = view;

  return (
    <>
      <Header householdName={householdName} currencyCode={currencyCode} periodStart={view.periodStart} periodEnd={view.periodEnd} status={view.status} />

      <div className={planStyles.summaryDock}>
        <p className={planStyles.summaryLabel}>ميزانية المصروف</p>
        <Amount value={spendingBudget} currencyCode={currencyCode} className={planStyles.summaryHeadline} />
        {totalIncome !== null ? (
          <div className={styles.incomeLine}>
            <span>إجمالي الدخل</span>
            <Amount value={totalIncome} currencyCode={currencyCode} />
          </div>
        ) : (
          <p className={styles.incomeLine}>
            <span>الدخل غير مشارك</span>
          </p>
        )}
      </div>

      {sections.length > 0 ? (
        <>
          <section className={planStyles.relationCard} aria-labelledby="shared-summary-title">
            <h2 id="shared-summary-title" className={styles.sectionsHeading}>
              الأقسام المشتركة
            </h2>
            <div className={planStyles.relationRow}>
              <span>إجمالي المخصص</span>
              <Amount value={sharedSummary.allocated} currencyCode={currencyCode} />
            </div>
            <div className={planStyles.relationRow}>
              <span>المصروف</span>
              <Amount value={sharedSummary.spent} currencyCode={currencyCode} />
            </div>
            <div className={`${planStyles.relationRow} ${planStyles.relationResult}`}>
              <span>المتبقي</span>
              <Amount
                value={sharedSummary.remaining}
                currencyCode={currencyCode}
                tone={sharedSummary.remaining < 0 ? "deficit" : undefined}
              />
            </div>
          </section>

          <section aria-labelledby="sections-title">
            <h2 id="sections-title" className={styles.sectionsHeading}>
              الأقسام
            </h2>
            <div className={planStyles.listSurface}>
              {sections.map((section) => (
                <div key={section.id} className={planStyles.itemRow}>
                  <div className={planStyles.itemInfo}>
                    <strong>{section.name}</strong>
                    <span className={planStyles.itemMeta}>
                      المخصص <Amount value={section.allocated} currencyCode={currencyCode} /> · المصروف{" "}
                      <Amount value={section.spent} currencyCode={currencyCode} /> · المتبقي{" "}
                      <Amount value={section.remaining} currencyCode={currencyCode} tone={section.remaining < 0 ? "deficit" : undefined} />
                    </span>
                    {section.overspent ? (
                      <p className={planStyles.warningNote}>
                        <Icon name="alert" size={14} />
                        تجاوز المخصص بـ <Amount value={Math.abs(section.remaining)} currencyCode={currencyCode} />
                      </p>
                    ) : null}
                  </div>
                  {view.status === "open" && section.canContribute ? (
                    <Link href="/app/expenses/new" className={planStyles.textAction}>
                      إضافة مصروف
                    </Link>
                  ) : null}
                </div>
              ))}
            </div>
          </section>
        </>
      ) : (
        <div className={planStyles.emptyState}>
          <span>
            <Icon name="spark" size={20} />
          </span>
          <p>مفيش أقسام مشتركة معاك دلوقتي.</p>
        </div>
      )}
    </>
  );
}
