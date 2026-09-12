import { Amount } from "./plan/amount";
import planStyles from "./plan/plan.module.css";

/**
 * The Member's daily "how much is left" hero -- deliberately NOT the Owner's whole-household
 * budget_remaining. Values are the sum of only the sections currently visible to this Member
 * (household/view + household/contribute; owner_only and hidden sections are never queried at
 * all -- see ./member-data.ts, unchanged by this component). A negative sharedRemaining is a
 * valid, calm warning state ("متجاوز في الأقسام المشتركة بـ ..."), never clamped to zero. The
 * label always keeps the "في الأقسام المشتركة" qualifier, in both the normal and overspent
 * cases, so this can never be mistaken for the Household's total spending-budget remaining
 * (that number belongs only to the Owner's hero).
 */
export function MemberHero({
  sharedAllocated,
  sharedSpent,
  sharedRemaining,
  currencyCode,
}: {
  sharedAllocated: number;
  sharedSpent: number;
  sharedRemaining: number;
  currencyCode: string;
}) {
  const overspent = sharedRemaining < 0;

  return (
    <div className={planStyles.summaryDock}>
      <p className={planStyles.summaryLabel}>{overspent ? "متجاوز في الأقسام المشتركة بـ" : "المتبقي في الأقسام المشتركة"}</p>
      <Amount
        value={Math.abs(sharedRemaining)}
        currencyCode={currencyCode}
        tone={overspent ? "deficit" : undefined}
        className={planStyles.summaryHeadline}
      />
      <dl className={planStyles.summaryStats}>
        <div>
          <dt>المصروف</dt>
          <dd><Amount value={sharedSpent} currencyCode={currencyCode} /></dd>
        </div>
        <div>
          <dt>المخصص</dt>
          <dd><Amount value={sharedAllocated} currencyCode={currencyCode} /></dd>
        </div>
      </dl>
    </div>
  );
}
