import type { Metadata } from "next";

import { LoginForm } from "./login-form";

export const metadata: Metadata = { title: "تسجيل الدخول" };

export default function LoginPage() {
  return (
    <main className="flex min-h-dvh items-center justify-center bg-neutral-50 px-4">
      <div className="w-full max-w-sm rounded-lg border border-neutral-200 bg-white p-6 shadow-sm">
        <h1 className="mb-1 text-lg font-bold text-neutral-900">لوحة إدارة دبّر</h1>
        <p className="mb-6 text-sm text-neutral-500">
          مخصصة لفريق التشغيل فقط. لا يوجد تسجيل عام.
        </p>
        <LoginForm />
      </div>
    </main>
  );
}
