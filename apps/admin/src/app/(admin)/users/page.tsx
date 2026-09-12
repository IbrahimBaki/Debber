import type { Metadata } from "next";
import Link from "next/link";

import { requireAdmin } from "@/lib/admin/require-admin";
import { userStatusLabel } from "@/lib/admin/status-labels";

export const metadata: Metadata = { title: "المستخدمون" };

const PAGE_SIZE = 25;

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; offset?: string }>;
}) {
  const { supabase } = await requireAdmin();
  const { q, offset: offsetParam } = await searchParams;
  const offset = Math.max(0, Number(offsetParam) || 0);

  const { data: users, error } = await supabase.rpc("admin_list_users", {
    p_search: q || undefined,
    p_limit: PAGE_SIZE,
    p_offset: offset,
  });

  return (
    <div>
      <h1 className="mb-1 text-xl font-bold text-neutral-900">المستخدمون</h1>
      <p className="mb-4 text-sm text-neutral-500">
        بيانات الدخول والحالة فقط. لا يوجد إنشاء عضوية مباشر من هنا -- العضوية تتم فقط عبر قبول دعوة.
      </p>
      <div className="mb-4 flex items-center justify-between gap-4">
        <form method="get" className="flex gap-2">
          <input
            type="search"
            name="q"
            defaultValue={q}
            placeholder="ابحث بالبريد الإلكتروني"
            className="h-10 w-64 rounded-md border border-neutral-300 px-3 text-sm"
          />
          <button
            type="submit"
            className="h-10 rounded-md border border-neutral-300 bg-white px-4 text-sm font-medium hover:bg-neutral-50"
          >
            بحث
          </button>
        </form>
        <Link
          href="/users/new"
          className="h-10 rounded-md bg-neutral-900 px-4 text-sm font-semibold text-white leading-10"
        >
          مستخدم جديد
        </Link>
      </div>

      {error ? (
        <p role="alert" className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-800">
          تعذر تحميل المستخدمين الآن.
        </p>
      ) : !users || users.length === 0 ? (
        <p className="rounded-md border border-dashed border-neutral-300 p-6 text-center text-sm text-neutral-500">
          لا يوجد مستخدمون مطابقون.
        </p>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-neutral-200 bg-white">
          <table className="w-full text-start text-sm">
            <thead className="border-b border-neutral-200 bg-neutral-50 text-neutral-500">
              <tr>
                <th className="px-4 py-2 text-start font-medium">البريد الإلكتروني</th>
                <th className="px-4 py-2 text-start font-medium">الحالة</th>
                <th className="px-4 py-2 text-start font-medium">آخر دخول</th>
                <th className="px-4 py-2 text-start font-medium">تاريخ الإنشاء</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => (
                <tr key={user.user_id} className="border-b border-neutral-100 last:border-0">
                  <td className="px-4 py-2">
                    <Link href={`/users/${user.user_id}`} className="font-medium text-neutral-900 hover:underline">
                      {user.email}
                    </Link>
                  </td>
                  <td className="px-4 py-2 text-neutral-600">{userStatusLabel(user.status)}</td>
                  <td className="px-4 py-2 text-neutral-500">
                    {user.last_sign_in_at ? new Date(user.last_sign_in_at).toLocaleString("ar-EG") : "—"}
                  </td>
                  <td className="px-4 py-2 text-neutral-500">
                    {new Date(user.created_at).toLocaleDateString("ar-EG")}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div className="mt-4 flex justify-between">
        {offset > 0 ? (
          <Link
            href={`/users?${new URLSearchParams({ q: q ?? "", offset: String(Math.max(0, offset - PAGE_SIZE)) })}`}
            className="text-sm font-medium text-neutral-600 hover:underline"
          >
            السابق
          </Link>
        ) : (
          <span />
        )}
        {users && users.length === PAGE_SIZE ? (
          <Link
            href={`/users?${new URLSearchParams({ q: q ?? "", offset: String(offset + PAGE_SIZE) })}`}
            className="text-sm font-medium text-neutral-600 hover:underline"
          >
            التالي
          </Link>
        ) : null}
      </div>
    </div>
  );
}
