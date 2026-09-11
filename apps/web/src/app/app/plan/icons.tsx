import type { ReactNode } from "react";

import styles from "./plan.module.css";

export type IconName = "plus" | "check" | "clock" | "skip" | "alert" | "arrow" | "chevron" | "spark" | "trash" | "pause";

const paths: Record<IconName, ReactNode> = {
  plus: <path d="M12 5v14M5 12h14" />,
  check: <path d="m5 12 4.1 4L19 6.8" />,
  clock: (
    <>
      <circle cx="12" cy="12" r="8.5" />
      <path d="M12 7v5l3.5 2" />
    </>
  ),
  skip: (
    <>
      <path d="M6 6v12M9.5 8.5 15 12l-5.5 3.5" />
      <path d="M18 6v12" />
    </>
  ),
  alert: (
    <>
      <path d="M12 3 21 20H3L12 3Z" />
      <path d="M12 9v4.5M12 17h.01" />
    </>
  ),
  arrow: (
    <>
      <path d="M5 12h14" />
      <path d="m13 6 6 6-6 6" />
    </>
  ),
  chevron: <path d="m9 18 6-6-6-6" />,
  spark: <path d="m12 3 1.65 5.35L19 10l-5.35 1.65L12 17l-1.65-5.35L5 10l5.35-1.65L12 3Z" />,
  trash: (
    <>
      <path d="M5 7h14M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2m3 0-1 13a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1L6 7h12Z" />
    </>
  ),
  pause: (
    <>
      <path d="M9 6v12M15 6v12" />
    </>
  ),
};

export function Icon({ name, size = 20 }: { name: IconName; size?: number }) {
  return (
    <svg
      aria-hidden="true"
      className={styles.icon}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {paths[name]}
    </svg>
  );
}
