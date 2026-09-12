import type { Metadata } from "next";

import { requireAdmin } from "@/lib/admin/require-admin";

import { CreateUserForm } from "./create-user-form";

export const metadata: Metadata = { title: "مستخدم جديد" };

export default async function NewUserPage() {
  await requireAdmin();

  return (
    <div>
      <h1 className="mb-1 text-xl font-bold text-neutral-900">مستخدم جديد</h1>
      <p className="mb-6 text-sm text-neutral-500">
        هذا ينشئ حساب دخول (Auth) فقط -- لا ينشئ بيتًا أو عضوية. العضوية تتم لاحقًا عبر دعوة.
      </p>
      <CreateUserForm />
    </div>
  );
}
