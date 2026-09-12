import Link from "next/link";

import { Amount } from "./plan/amount";
import { Icon } from "./plan/icons";
import styles from "./section-card.module.css";

export type SectionCardData = {
  id: string; // period_section_budget_id
  name: string;
  allocated: number;
  spent: number;
  remaining: number;
  overspent: boolean;
};

/**
 * A contiguous, clickable list row -- not a floating card -- matching apps/web/DESIGN.md's
 * "Section and list surfaces" rule (warm white bordered surfaces with contiguous rows; "avoids
 * a deck of identical cards" is an explicit Don't). Render one or more inside a
 * `styles.list` wrapper. The whole row links to /app/sections/[periodSectionBudgetId] (§15 of
 * the home redesign) and the chevron is the row's only navigation affordance -- no decorative
 * circular icon: a previous sparkle/warning icon read as a second, false clickable control in
 * a real browser and has been removed. "Add Expense" is never duplicated in this row either --
 * it belongs on the section detail page this links to.
 */
export function SectionCard({ section, currencyCode }: { section: SectionCardData; currencyCode: string }) {
  const percentSpent = section.allocated > 0 ? Math.min(100, Math.round((section.spent / section.allocated) * 100)) : 0;

  return (
    <Link href={`/app/sections/${section.id}`} className={styles.row}>
      <div className={styles.info}>
        <strong className={styles.name}>{section.name}</strong>

        <p className={styles.remainingLine}>
          <span className={styles.remainingLabel}>{section.overspent ? "متجاوز بـ" : "باقي"}</span>
          <Amount
            value={Math.abs(section.remaining)}
            currencyCode={currencyCode}
            tone={section.overspent ? "deficit" : undefined}
            className={styles.remainingAmount}
          />
        </p>

        <div className={styles.stats}>
          <span className={styles.stat}>
            <span className={styles.statLabel}>المصروف</span>
            <Amount value={section.spent} currencyCode={currencyCode} className={styles.statAmount} />
          </span>
          <span className={styles.stat}>
            <span className={styles.statLabel}>المخصص</span>
            <Amount value={section.allocated} currencyCode={currencyCode} className={styles.statAmount} />
          </span>
        </div>

        {section.allocated > 0 ? (
          <span className={styles.track} role="img" aria-label={`تم صرف ${percentSpent}٪ من القسم`}>
            <span className={styles.trackFill} data-overspent={section.overspent ? "true" : undefined} style={{ width: `${percentSpent}%` }} />
          </span>
        ) : null}
      </div>

      <span className={styles.chevron} aria-hidden="true">
        <Icon name="chevron" size={18} />
      </span>
    </Link>
  );
}
