"use client";

import { useFormStatus } from "react-dom";

import styles from "./auth.module.css";

export function SubmitButton({ children }: { children: string }) {
  const { pending } = useFormStatus();

  return (
    <button className={styles.submit} type="submit" disabled={pending}>
      {pending ? "جارٍ الإرسال…" : children}
    </button>
  );
}
