"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";

import { signOut } from "@/app/auth/actions";

import { Icon } from "./plan/icons";
import styles from "./app-shell.module.css";

/**
 * Mobile-only "المزيد" -- Owner only. Contains exactly the secondary actions that already exist
 * elsewhere in the app (دعوة شريك, تسجيل الخروج); nothing invented to fill space (see AGENTS
 * §16). A Member has no secondary destinations at all in this nav, so this component is never
 * rendered for one.
 */
export function NavMoreSheet({ active }: { active: boolean }) {
  const [open, setOpen] = useState(false);
  const sheetRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") setOpen(false);
    }
    document.addEventListener("keydown", onKeyDown);
    sheetRef.current?.focus();
    return () => document.removeEventListener("keydown", onKeyDown);
  }, [open]);

  return (
    <>
      <button
        type="button"
        className={styles.navItem}
        aria-current={active ? "page" : undefined}
        data-active={active ? "true" : undefined}
        aria-expanded={open}
        aria-haspopup="dialog"
        onClick={() => setOpen(true)}
      >
        <span className={styles.navIcon}>
          <Icon name="more" size={20} />
        </span>
        <span className={styles.navLabel}>المزيد</span>
      </button>

      {open ? (
        <div className={styles.sheetOverlay} onClick={() => setOpen(false)}>
          <div
            ref={sheetRef}
            role="dialog"
            aria-modal="true"
            aria-label="قائمة المزيد"
            tabIndex={-1}
            className={styles.sheet}
            onClick={(event) => event.stopPropagation()}
          >
            <div className={styles.sheetHandle} aria-hidden="true" />
            <Link href="/app/invitations/new" className={styles.sheetLink} onClick={() => setOpen(false)}>
              <Icon name="spark" size={18} />
              <span>دعوة شريك</span>
            </Link>
            <form action={signOut}>
              <button type="submit" className={styles.sheetLink}>
                <Icon name="logout" size={18} />
                <span>تسجيل الخروج</span>
              </button>
            </form>
            <button type="button" className={styles.sheetClose} onClick={() => setOpen(false)}>
              إغلاق
            </button>
          </div>
        </div>
      ) : null}
    </>
  );
}
