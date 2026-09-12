import Link from "next/link";

import { signOut } from "@/app/auth/actions";

import { NavMoreSheet } from "./nav-more-sheet";
import { Icon, type IconName } from "./plan/icons";
import styles from "./app-shell.module.css";

export type AppNavKey = "home" | "sections" | "add" | "plan";

export type AppNavContext = {
  role: "owner" | "member";
  periodStatus: "no_period" | "draft" | "open" | "closed";
  canRecordExpense: boolean;
};

type NavItem = { key: AppNavKey; href: string; label: string; icon: IconName };

/**
 * One shared nav-item list drives both the mobile bottom bar and the desktop navbar, so the two
 * surfaces can never drift apart. Eligibility comes entirely from props the caller already
 * resolved for its own page body (role/period status/canRecordExpense) -- this never issues a
 * query of its own. Draft intentionally omits "الأقسام" too (see AGENTS §23): there is no
 * section-execution surface to scroll to yet before the month is started.
 */
function buildNavItems(nav: AppNavContext): NavItem[] {
  const items: NavItem[] = [{ key: "home", href: "/app", label: "الرئيسية", icon: "home" }];

  if (nav.role === "owner" && nav.periodStatus === "draft") {
    items.push({ key: "plan", href: "/app/plan", label: "الخطة", icon: "list" });
    return items;
  }

  items.push({ key: "sections", href: "/app#app-sections", label: "الأقسام", icon: "grid" });

  if (nav.canRecordExpense) {
    items.push({ key: "add", href: "/app/expenses/new", label: "إضافة مصروف", icon: "plus" });
  }

  if (nav.role === "owner") {
    items.push({ key: "plan", href: "/app/plan", label: "الخطة", icon: "list" });
  }

  return items;
}

function NavLink({ item, active }: { item: NavItem; active: AppNavKey | undefined }) {
  const isActive = item.key === active;
  const isAdd = item.key === "add";
  return (
    <Link
      href={item.href}
      className={isAdd ? styles.navItemPrimary : styles.navItem}
      aria-current={isActive ? "page" : undefined}
      data-active={isActive ? "true" : undefined}
    >
      <span className={isAdd ? styles.navIconPrimary : styles.navIcon}>
        <Icon name={item.icon} size={isAdd ? 22 : 20} />
      </span>
      <span className={styles.navLabel}>{item.label}</span>
    </Link>
  );
}

function SecondaryLinks({ role }: { role: "owner" | "member" }) {
  return (
    <>
      {role === "owner" ? (
        <Link href="/app/invitations/new" className={styles.secondaryLink}>
          <Icon name="spark" size={18} />
          <span>دعوة شريك</span>
        </Link>
      ) : null}
      <form action={signOut}>
        <button type="submit" className={styles.secondaryLink}>
          <Icon name="logout" size={18} />
          <span>تسجيل الخروج</span>
        </button>
      </form>
    </>
  );
}

export function AppShell({
  nav,
  active,
  householdName,
  children,
}: {
  nav: AppNavContext;
  active?: AppNavKey;
  householdName: string;
  children: React.ReactNode;
}) {
  const items = buildNavItems(nav);

  return (
    <div className={styles.shell}>
      <header className={styles.desktopBar}>
        <div className={styles.desktopBarInner}>
          <Link href="/app" className={styles.brand} aria-label="دبّر — الرئيسية">
            <span className={styles.brandMark} aria-hidden="true" />
            <span className={styles.brandHouseholdName}>{householdName}</span>
          </Link>
          <nav className={styles.desktopNav} aria-label="التنقل الرئيسي">
            {items.map((item) => (
              <NavLink key={item.key} item={item} active={active} />
            ))}
          </nav>
          <div className={styles.desktopSecondary}>
            <SecondaryLinks role={nav.role} />
          </div>
        </div>
      </header>

      <div className={styles.body}>{children}</div>

      <nav className={styles.mobileBar} aria-label="التنقل الرئيسي">
        {items.map((item) => (
          <NavLink key={item.key} item={item} active={active} />
        ))}
        {nav.role === "owner" ? <NavMoreSheet active={false} /> : null}
      </nav>
    </div>
  );
}
