"use client";

import { useId, useState } from "react";

import { useAuthErrorDescription } from "./auth-form";
import styles from "./auth.module.css";

export function PasswordField({
  name,
  label,
  autoComplete,
}: {
  name: string;
  label: string;
  autoComplete: "current-password" | "new-password";
}) {
  const [visible, setVisible] = useState(false);
  const id = useId();
  const errorDescription = useAuthErrorDescription();

  return (
    <div className={styles.field}>
      <label htmlFor={id}>{label}</label>
      <div className={styles.passwordControl}>
        <input
          id={id}
          name={name}
          type={visible ? "text" : "password"}
          autoComplete={autoComplete}
          aria-describedby={errorDescription}
          required
          minLength={6}
        />
        <button
          type="button"
          className={styles.visibilityButton}
          aria-pressed={visible}
          aria-label={visible ? "إخفاء كلمة المرور" : "إظهار كلمة المرور"}
          onClick={() => setVisible((current) => !current)}
        >
          {visible ? "إخفاء" : "إظهار"}
        </button>
      </div>
    </div>
  );
}
