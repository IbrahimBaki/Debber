"use client";

import { useActionState } from "react";

import { createInvitationAction, type CreateInvitationState } from "./actions";

const initialState: CreateInvitationState = {};

export function CreateInvitationForm({
  defaultHouseholdId,
  defaultHouseholdName,
}: {
  defaultHouseholdId?: string;
  defaultHouseholdName?: string;
}) {
  const [state, formAction, pending] = useActionState(createInvitationAction, initialState);

  return (
    <form action={formAction} className="grid max-w-md gap-4">
      <div className="grid gap-1.5">
        <label htmlFor="householdId" className="text-sm font-medium text-neutral-700">
          معرّف البيت (Household ID)
        </label>
        <input
          id="householdId"
          name="householdId"
          type="text"
          required
          defaultValue={defaultHouseholdId}
          disabled={pending}
          className="h-11 rounded-md border border-neutral-300 px-3 font-mono text-sm"
        />
        {defaultHouseholdName ? (
          <p className="text-xs text-neutral-500">البيت: {defaultHouseholdName}</p>
        ) : (
          <p className="text-xs text-neutral-500">
            ابحث عن مالك البيت في المستخدمون ثم اضغط &quot;دعوة لهذا البيت&quot; في صفحته.
          </p>
        )}
      </div>
      <div className="grid gap-1.5">
        <label htmlFor="email" className="text-sm font-medium text-neutral-700">
          البريد الإلكتروني المدعو
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
      {state.error ? (
        <p role="alert" className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-800">
          {state.error}
        </p>
      ) : null}
      <button
        type="submit"
        disabled={pending}
        className="h-11 w-fit rounded-md bg-neutral-900 px-4 text-sm font-semibold text-white disabled:opacity-60"
      >
        {pending ? "جارٍ الإنشاء…" : "إنشاء الدعوة"}
      </button>
    </form>
  );
}
