"use client";

import { useActionState } from "react";

import { changePasswordAction, type UserActionState } from "./actions";

const initialState: UserActionState = {};

export function ChangePasswordForm({ userId }: { userId: string }) {
  const [state, formAction, pending] = useActionState(changePasswordAction, initialState);

  return (
    <form action={formAction} className="grid max-w-sm gap-3">
      <input type="hidden" name="userId" value={userId} />
      <div className="grid gap-1.5">
        <label htmlFor="newPassword" className="text-sm font-medium text-neutral-700">
          كلمة مرور جديدة
        </label>
        <input
          id="newPassword"
          name="newPassword"
          type="password"
          minLength={6}
          required
          disabled={pending}
          className="h-10 rounded-md border border-neutral-300 px-3 text-sm"
        />
      </div>
      {state.error ? (
        <p role="alert" className="rounded-md bg-red-50 px-3 py-2 text-xs text-red-800">
          {state.error}
        </p>
      ) : null}
      {state.success ? (
        <p role="status" className="rounded-md bg-green-50 px-3 py-2 text-xs text-green-800">
          {state.success}
        </p>
      ) : null}
      <button
        type="submit"
        disabled={pending}
        className="h-10 w-fit rounded-md border border-neutral-300 bg-white px-4 text-sm font-medium hover:bg-neutral-50 disabled:opacity-60"
      >
        {pending ? "جارٍ التغيير…" : "تغيير كلمة المرور"}
      </button>
    </form>
  );
}
