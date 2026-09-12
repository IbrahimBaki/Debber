import type { Metadata } from "next";

import { requireAdmin } from "@/lib/admin/require-admin";

export const metadata: Metadata = { title: "الرئيسية" };

export default async function DashboardPage() {
  const { supabase } = await requireAdmin();
  const { data, error } = await supabase.rpc("admin_dashboard_counts").single();

  const cards = error || !data
    ? []
    : [
        { label: "إجمالي المستخدمين", value: data.users_total },
        { label: "بيوت نشطة", value: data.households_active },
        { label: "بيوت مؤرشفة", value: data.households_archived },
        { label: "دعوات معلّقة", value: data.invitations_pending },
        { label: "عضويات نشطة", value: data.memberships_active },
      ];

  return (
    <div>
      <h1 className="mb-1 text-xl font-bold text-neutral-900">نظرة عامة</h1>
      <p className="mb-6 text-sm text-neutral-500">
        أرقام تشغيلية غير مالية فقط. لا تعرض هذه اللوحة أي بيانات دخل أو مصروفات أو ميزانيات.
      </p>
      {error ? (
        <p role="alert" className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-800">
          تعذر تحميل الأرقام الآن.
        </p>
      ) : (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5">
          {cards.map((card) => (
            <div key={card.label} className="rounded-lg border border-neutral-200 bg-white p-4">
              <p className="text-2xl font-bold text-neutral-900">{card.value}</p>
              <p className="mt-1 text-xs text-neutral-500">{card.label}</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
