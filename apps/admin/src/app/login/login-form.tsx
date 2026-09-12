"use client";

import { useActionState } from "react";

import { signIn, type AuthActionState } from "./actions";

const initialState: AuthActionState = {};

export function LoginForm() {
  const [state, formAction, pending] = useActionState(signIn, initialState);

  return (
    <form action={formAction} className="grid gap-4">
      <div className="grid gap-1.5">
        <label htmlFor="email" className="text-sm font-medium text-neutral-700">
          البريد الإلكتروني
        </label>
        <input
          id="email"
          name="email"
          type="email"
          required
          autoComplete="username"
          disabled={pending}
          className="h-11 rounded-md border border-neutral-300 px-3 text-sm focus:outline focus:outline-2 focus:outline-neutral-900"
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
          autoComplete="current-password"
          disabled={pending}
          className="h-11 rounded-md border border-neutral-300 px-3 text-sm focus:outline focus:outline-2 focus:outline-neutral-900"
        />
      </div>
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
        {pending ? "جارٍ الدخول…" : "تسجيل الدخول"}
      </button>
    </form>
  );
}
