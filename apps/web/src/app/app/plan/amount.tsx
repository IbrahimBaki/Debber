import { currencyLabel, formatAmount } from "./format";
import styles from "./plan.module.css";

export function Amount({
  value,
  currencyCode,
  tone,
  className = "",
}: {
  value: number;
  currencyCode: string;
  // "deficit" is a planning-warning tone (amber), never the danger/error tone: a planned
  // deficit is a valid outcome, not a failure. "negative" is reserved for genuine errors.
  tone?: "negative" | "positive" | "deficit";
  className?: string;
}) {
  const toneClass =
    tone === "negative" ? styles.amountNegative : tone === "positive" ? styles.amountPositive : tone === "deficit" ? styles.amountDeficit : "";
  return (
    <span className={`${styles.amount} ${toneClass} ${className}`} dir="rtl">
      {formatAmount(value)}
      <small>{currencyLabel(currencyCode)}</small>
    </span>
  );
}
