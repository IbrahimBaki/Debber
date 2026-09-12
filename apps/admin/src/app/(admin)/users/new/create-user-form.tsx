"use client";

import { useActionState } from "react";

import { createUserAction, type CreateUserState } from "./actions";

const initialState: CreateUserState = {};

export function CreateUserForm() {
  const [state, formAction, pending] = useActionState(createUserAction, initialState);

  return (
    <form action={formAction} className="grid max-w-md gap-4">
      <div className="grid gap-1.5">
        <label htmlFor="email" className="text-sm font-medium text-neutral-700">
          البريد الإلكتروني
        </label>
        <input
          id="email"
          name="email"
          type="email"
          required
          disabled={pending}
          className="h-11 rounded-md border border-neutral-300 px-3 text-sm"
        />
      </div>
      <div className="grid gap-1.5">
        <label htmlFor="password" className="text-sm font-medium text-neutral-700">
          كلمة المرور
        </label>
        <input
          id="password"
          name="password"
          type="password"
          required
          minLength={6}
          disabled={pending}
          className="h-11 rounded-md border border-neutral-300 px-3 text-sm"
        />
        <p className="text-xs text-neutral-500">لن تُعرض كلمة المرور أو تُسجَّل في أي مكان بعد هذه الخطوة.</p>
      </div>
      <label className="flex items-center gap-2 text-sm text-neutral-700">
        <input name="activateImmediately" type="checkbox" defaultChecked className="h-4 w-4" />
        تفعيل الحساب فورًا (بدون تأكيد بريد إلكتروني منفصل)
      </label>
      {state.error ? (
        <p role="alert" className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-800">
          {state.error}
        </p>
      ) : null}
      <button
        type="submit"
        disabled={pending}
        className="h-11 rounded-md bg-neutral-900 text-sm font-semibold text-white disabled:opacity-60"
      >
        {pending ? "جارٍ الإنشاء…" : "إنشاء المستخدم"}
      </button>
    </form>
  );
}
