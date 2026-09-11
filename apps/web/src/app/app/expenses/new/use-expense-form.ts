"use client";

import { useActionState, useEffect, useRef } from "react";

import type { ExpenseActionState } from "./actions";

/**
 * Wraps useActionState so the caller can react exactly once when a pending submission
 * resolves without an error. Mirrors apps/web/src/app/app/plan/use-add-form.ts (kept as a
 * separate small copy rather than a shared generic: the two folders' action-state shapes
 * differ and the previous generic attempt hit a useActionState overload-inference issue).
 */
export function useExpenseForm(
  action: (state: ExpenseActionState, formData: FormData) => Promise<ExpenseActionState>,
  initialState: ExpenseActionState,
  onSettled: (state: ExpenseActionState) => void,
) {
  const [state, formAction, pending] = useActionState(action, initialState);
  const wasPending = useRef(false);

  useEffect(() => {
    if (wasPending.current && !pending) onSettled(state);
    wasPending.current = pending;
  }, [pending, state, onSettled]);

  return [state, formAction, pending] as const;
}
