import { Amount } from "./plan/amount";
import planStyles from "./plan/plan.module.css";

/**
 * The Owner's daily "how much is left" hero. Values come straight from
 * get_owner_period_planning_summary(...) (see ./owner-home-data.ts) -- the whole-period
 * variable-budget formula, never a sum of section remainders, so unallocated spending budget
 * is correctly reflected here. A negative budgetRemaining is a valid, calm warning state
 * ("متجاوز بـ ..."), never clamped to zero and never an error state.
 */
export function OwnerHero({
  spendingBudget,
  actualVariableSpending,
  budgetRemaining,
  currencyCode,
}: {
  spendingBudget: number;
  actualVariableSpending: number;
  budgetRemaining: number;
  currencyCode: string;
}) {
  const overspent = budgetRemaining < 0;

  return (
    <div className={planStyles.summaryDock}>
      <p className={planStyles.summaryLabel}>{overspent ? "متجاوز ميزانية المصروف بـ" : "باقي من ميزانية المصروف"}</p>
      <Amount
        value={Math.abs(budgetRemaining)}
        currencyCode={currencyCode}
        tone={overspent ? "deficit" : undefined}
        className={planStyles.summaryHeadline}
      />
      <dl className={planStyles.summaryStats}>
        <div>
          <dt>ميزانية المصروف</dt>
          <dd><Amount value={spendingBudget} currencyCode={currencyCode} /></dd>
        </div>
        <div>
          <dt>المصروف</dt>
          <dd><Amount value={actualVariableSpending} currencyCode={currencyCode} /></dd>
        </div>
      </dl>
    </div>
  );
}
