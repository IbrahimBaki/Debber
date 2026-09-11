"use client";

import { useActionState, useEffect, useRef } from "react";

import type { PlanActionState } from "./actions";

/**
 * Wraps useActionState for "add a new item" forms. Calls onSuccess exactly once when a
 * pending submission resolves without an error, so callers can clear the form and mint a
 * fresh operation id for the *next* logical entry. On failure the caller's existing form
 * state (including the operation id passed as a hidden field) is left untouched, so a retry
 * of the same submission reuses the same id instead of creating a duplicate.
 */
export function useAddForm(
  action: (state: PlanActionState, formData: FormData) => Promise<PlanActionState>,
  initialState: PlanActionState,
  onSuccess: () => void,
) {
  const [state, formAction, pending] = useActionState(action, initialState);
  const wasPending = useRef(false);

  useEffect(() => {
    if (wasPending.current && !pending && !state.error) onSuccess();
    wasPending.current = pending;
  }, [pending, state, onSuccess]);

  return [state, formAction, pending] as const;
}
