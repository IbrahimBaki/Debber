import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { requireAdmin } from "@/lib/admin/require-admin";
import { userStatusLabel } from "@/lib/admin/status-labels";
import { ConfirmFormButton } from "@/components/confirm-form-button";

import { activateUserAction, disableUserAction, enableUserAction } from "./actions";
import { ChangePasswordForm } from "./change-password-form";

export const metadata: Metadata = { title: "تفاصيل المستخدم" };

export default async function UserDetailPage({
  params,
}: {
  params: Promise<{ userId: string }>;
}) {
  const { userId } = await params;
  const { supabase } = await requireAdmin();

  const [{ data: user, error: userError }, { data: memberships, error: membershipsError }] =
    await Promise.all([
      supabase.rpc("admin_get_user", { p_user_id: userId }).single(),
      supabase.rpc("admin_list_user_memberships", { p_user_id: userId }),
    ]);

  if (userError || !user) notFound();

  const activateWithId = activateUserAction.bind(null, userId);
  const disableWithId = disableUserAction.bind(null, userId);
  const enableWithId = enableUserAction.bind(null, userId);

  return (
    <div className="max-w-2xl">
      <h1 className="mb-1 text-xl font-bold text-neutral-900">{user.email}</h1>
      <p className="mb-6 text-sm text-neutral-500">
        الحالة: {userStatusLabel(user.status)} · أُنشئ في {new Date(user.created_at).toLocaleDateString("ar-EG")}
      </p>

      <section className="mb-8 rounded-lg border border-neutral-200 bg-white p-4">
        <h2 className="mb-3 text-sm font-bold text-neutral-900">إجراءات الحساب</h2>
        <div className="flex flex-wrap gap-3">
          {user.status === "needs_activation" ? (
            <form action={activateWithId}>
              <ConfirmFormButton confirmLabel="تفعيل الحساب؟">تفعيل الحساب</ConfirmFormButton>
            </form>
          ) : null}
          {user.status !== "disabled" ? (
            <form action={disableWithId}>
              <ConfirmFormButton confirmLabel="إيقاف الحساب؟" tone="danger">إيقاف الحساب</ConfirmFormButton>
            </form>
          ) : (
            <form action={enableWithId}>
              <ConfirmFormButton confirmLabel="إعادة تفعيل الحساب؟">إعادة تفعيل</ConfirmFormButton>
            </form>
          )}
        </div>
      </section>

      <section className="mb-8 rounded-lg border border-neutral-200 bg-white p-4">
        <h2 className="mb-3 text-sm font-bold text-neutral-900">تغيير كلمة المرور</h2>
        <ChangePasswordForm userId={userId} />
      </section>

      <section className="rounded-lg border border-neutral-200 bg-white p-4">
        <h2 className="mb-3 text-sm font-bold text-neutral-900">العضويات</h2>
        {membershipsError || !memberships || memberships.length === 0 ? (
          <p className="text-sm text-neutral-500">لا توجد عضويات في أي بيت.</p>
        ) : (
          <ul className="grid gap-2">
            {memberships.map((m) => (
              <li key={m.household_id} className="flex items-center justify-between rounded-md border border-neutral-100 px-3 py-2 text-sm">
                <span className="font-medium text-neutral-900">{m.household_name}</span>
                <span className="flex items-center gap-3 text-neutral-500">
                  <span>{m.role === "owner" ? "مالك" : "عضو"} · {m.status === "active" ? "نشط" : "غير نشط"}</span>
                  {m.role === "owner" ? (
                    <Link
                      href={`/invitations/new?householdId=${m.household_id}&householdName=${encodeURIComponent(m.household_name)}`}
                      className="font-medium text-neutral-900 hover:underline"
                    >
                      دعوة لهذا البيت
                    </Link>
                  ) : null}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
