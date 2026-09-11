"use client";

import { useId, useState } from "react";

import { currencyLabel } from "./format";
import styles from "./plan.module.css";

const draftPattern = /^\d*\.?\d{0,2}$/;

/**
 * Controlled text input for money amounts. Uses inputMode="decimal" for the mobile numeric
 * keyboard, never type="number" (which allows scientific notation and has poor RTL/mobile
 * behavior). The raw string is what gets submitted; parsing/validation happens server-side
 * so the browser never stands in as the financial authority.
 */
export function MoneyInput({
  name,
  label,
  defaultValue = "",
  currencyCode,
  disabled,
  autoFocus,
  required = true,
  size = "default",
}: {
  name: string;
  label: string;
  defaultValue?: string;
  currencyCode: string;
  disabled?: boolean;
  autoFocus?: boolean;
  required?: boolean;
  /** "hero" is for a surface where the amount IS the screen (e.g. Quick Expense Entry). */
  size?: "default" | "hero";
}) {
  const [value, setValue] = useState(defaultValue);
  const id = useId();

  return (
    <div className={size === "hero" ? `${styles.moneyField} ${styles.moneyFieldHero}` : styles.moneyField}>
      <label htmlFor={id}>{label}</label>
      <div className={styles.moneyControl}>
        <input
          id={id}
          name={name}
          inputMode="decimal"
          autoComplete="off"
          dir="ltr"
          className={styles.moneyInput}
          value={value}
          placeholder="0"
          disabled={disabled}
          autoFocus={autoFocus}
          required={required}
          onChange={(event) => {
            const next = event.target.value.replace(/[^\d.]/g, "");
            if (draftPattern.test(next)) setValue(next);
          }}
        />
        <span className={styles.moneySuffix}>{currencyLabel(currencyCode)}</span>
      </div>
    </div>
  );
}
