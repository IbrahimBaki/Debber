import Link from "next/link";

import { signOut } from "@/app/login/actions";
import { requireAdmin } from "@/lib/admin/require-admin";

const navItems = [
  { href: "/", label: "الرئيسية" },
  { href: "/users", label: "المستخدمون" },
  { href: "/invitations", label: "الدعوات" },
  { href: "/audit", label: "سجل الإدارة" },
];

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  await requireAdmin();

  return (
    <div className="flex min-h-dvh">
      <aside className="flex w-56 shrink-0 flex-col border-s border-neutral-200 bg-white">
        <div className="border-b border-neutral-200 px-4 py-4">
          <p className="text-sm font-bold text-neutral-900">لوحة إدارة دبّر</p>
        </div>
        <nav className="flex flex-1 flex-col gap-1 p-2">
          {navItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="rounded-md px-3 py-2 text-sm font-medium text-neutral-700 hover:bg-neutral-100"
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <form action={signOut} className="border-t border-neutral-200 p-2">
          <button
            type="submit"
            className="w-full rounded-md px-3 py-2 text-start text-sm font-medium text-neutral-500 hover:bg-neutral-100"
          >
            تسجيل الخروج
          </button>
        </form>
      </aside>
      <main className="min-w-0 flex-1 p-6">{children}</main>
    </div>
  );
}
