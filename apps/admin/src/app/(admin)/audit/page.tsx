import type { Metadata } from "next";

import { requireAdmin } from "@/lib/admin/require-admin";

export const metadata: Metadata = { title: "سجل الإدارة" };

const PAGE_SIZE = 50;

export default async function AuditPage({
  searchParams,
}: {
  searchParams: Promise<{ offset?: string }>;
}) {
  const { supabase } = await requireAdmin();
  const { offset: offsetParam } = await searchParams;
  const offset = Math.max(0, Number(offsetParam) || 0);

  const { data: events, error } = await supabase.rpc("admin_list_audit_logs", {
    p_limit: PAGE_SIZE,
    p_offset: offset,
  });

  return (
    <div>
      <h1 className="mb-1 text-xl font-bold text-neutral-900">سجل الإدارة</h1>
      <p className="mb-6 text-sm text-neutral-500">
        سجل للقراءة فقط لكل عملية إدارية حساسة. لا تظهر هنا أي كلمات مرور أو رموز أو بيانات مالية.
      </p>

      {error ? (
        <p role="alert" className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-800">
          تعذر تحميل السجل الآن.
        </p>
      ) : !events || events.length === 0 ? (
        <p className="rounded-md border border-dashed border-neutral-300 p-6 text-center text-sm text-neutral-500">
          لا توجد أحداث بعد.
        </p>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-neutral-200 bg-white">
          <table className="w-full text-start text-sm">
            <thead className="border-b border-neutral-200 bg-neutral-50 text-neutral-500">
              <tr>
                <th className="px-4 py-2 text-start font-medium">الوقت</th>
                <th className="px-4 py-2 text-start font-medium">المسؤول</th>
                <th className="px-4 py-2 text-start font-medium">الإجراء</th>
                <th className="px-4 py-2 text-start font-medium">الهدف</th>
              </tr>
            </thead>
            <tbody>
              {events.map((event) => (
                <tr key={event.id} className="border-b border-neutral-100 last:border-0">
                  <td className="whitespace-nowrap px-4 py-2 text-neutral-500">
                    {new Date(event.created_at).toLocaleString("ar-EG")}
                  </td>
                  <td className="px-4 py-2 text-neutral-700">{event.admin_email ?? "—"}</td>
                  <td className="px-4 py-2 font-medium text-neutral-900">{event.action}</td>
                  <td className="px-4 py-2 text-neutral-500">
                    {event.target_type}
                    {event.target_id ? ` · ${event.target_id}` : ""}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {events && events.length === PAGE_SIZE ? (
        <div className="mt-4">
          <a
            href={`/audit?offset=${offset + PAGE_SIZE}`}
            className="text-sm font-medium text-neutral-600 hover:underline"
          >
            التالي
          </a>
        </div>
      ) : null}
    </div>
  );
}
