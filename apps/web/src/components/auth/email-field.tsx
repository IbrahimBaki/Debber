"use client";

import { useId } from "react";

import { useAuthErrorDescription } from "./auth-form";
import styles from "./auth.module.css";

export function EmailField() {
  const id = useId();
  const errorDescription = useAuthErrorDescription();

  return (
    <div className={styles.field}>
      <label htmlFor={id}>البريد الإلكتروني</label>
      <input
        className={styles.emailInput}
        id={id}
        name="email"
        type="email"
        dir="ltr"
        autoComplete="email"
        aria-describedby={errorDescription}
        required
      />
    </div>
  );
}
