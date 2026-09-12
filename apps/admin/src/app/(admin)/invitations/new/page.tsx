import type { Metadata } from "next";

import { requireAdmin } from "@/lib/admin/require-admin";

import { CreateInvitationForm } from "./create-invitation-form";

export const metadata: Metadata = { title: "دعوة جديدة" };

export default async function NewInvitationPage({
  searchParams,
}: {
  searchParams: Promise<{ householdId?: string; householdName?: string }>;
}) {
  await requireAdmin();
  const { householdId, householdName } = await searchParams;

  return (
    <div>
      <h1 className="mb-1 text-xl font-bold text-neutral-900">دعوة جديدة</h1>
      <p className="mb-6 text-sm text-neutral-500">
        تُنشأ هذه الدعوة نيابة عن مالك البيت -- تظهر له كأنه هو من أرسلها، وتُسجَّل هويتك الحقيقية في سجل الإدارة.
      </p>
      <CreateInvitationForm defaultHouseholdId={householdId} defaultHouseholdName={householdName} />
    </div>
  );
}
