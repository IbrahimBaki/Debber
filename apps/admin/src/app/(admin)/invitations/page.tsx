import type { Metadata } from "next";
import Link from "next/link";

import { requireAdmin } from "@/lib/admin/require-admin";
import { invitationStatusLabel } from "@/lib/admin/status-labels";

import { InvitationRowActions } from "./invitation-row-actions";

export const metadata: Metadata = { title: "الدعوات" };

const PAGE_SIZE = 25;

export default async function InvitationsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; offset?: string }>;
}) {
  const { supabase } = await requireAdmin();
  const { q, offset: offsetParam } = await searchParams;
  const offset = Math.max(0, Number(offsetParam) || 0);

  const { data: invitations, error } = await supabase.rpc("admin_list_invitations", {
    p_search_email: q || undefined,
    p_status: undefined,
    p_limit: PAGE_SIZE,
    p_offset: offset,
  });

  return (
    <div>
      <h1 className="mb-1 text-xl font-bold text-neutral-900">الدعوات</h1>
      <p className="mb-4 text-sm text-neutral-500">
        لا يظهر رمز الدعوة (token) هنا أبدًا. لا يوجد إضافة عضو مباشرة -- كل عضوية تمر عبر دعوة.
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
          <button type="submit" className="h-10 rounded-md border border-neutral-300 bg-white px-4 text-sm font-medium hover:bg-neutral-50">
            بحث
          </button>
        </form>
        <Link href="/invitations/new" className="h-10 rounded-md bg-neutral-900 px-4 text-sm font-semibold text-white leading-10">
          دعوة جديدة
        </Link>
      </div>

      {error ? (
        <p role="alert" className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-800">
          تعذر تحميل الدعوات الآن.
        </p>
      ) : !invitations || invitations.length === 0 ? (
        <p className="rounded-md border border-dashed border-neutral-300 p-6 text-center text-sm text-neutral-500">
          لا توجد دعوات مطابقة.
        </p>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-neutral-200 bg-white">
          <table className="w-full text-start text-sm">
            <thead className="border-b border-neutral-200 bg-neutral-50 text-neutral-500">
              <tr>
                <th className="px-4 py-2 text-start font-medium">البيت</th>
                <th className="px-4 py-2 text-start font-medium">البريد المدعو</th>
                <th className="px-4 py-2 text-start font-medium">الحالة</th>
                <th className="px-4 py-2 text-start font-medium">من</th>
                <th className="px-4 py-2 text-start font-medium">تنتهي في</th>
                <th className="px-4 py-2" />
              </tr>
            </thead>
            <tbody>
              {invitations.map((inv) => (
                <tr key={inv.invitation_id} className="border-b border-neutral-100 last:border-0 align-top">
                  <td className="px-4 py-2 font-medium text-neutral-900">{inv.household_name}</td>
                  <td className="px-4 py-2 text-neutral-700">{inv.email}</td>
                  <td className="px-4 py-2 text-neutral-600">{invitationStatusLabel(inv.status)}</td>
                  <td className="px-4 py-2 text-neutral-500">{inv.invited_by_display_name ?? "—"}</td>
                  <td className="px-4 py-2 text-neutral-500">{new Date(inv.expires_at).toLocaleDateString("ar-EG")}</td>
                  <td className="px-4 py-2">
                    {inv.status === "pending" ? <InvitationRowActions invitationId={inv.invitation_id} /> : null}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
