"use client";

import { useActionState } from "react";

import { acceptInvitationAction, revokeInvitationAction, type InvitationRowState } from "./actions";

const initialState: InvitationRowState = {};

export function InvitationRowActions({ invitationId }: { invitationId: string }) {
  const [revokeState, revokeAction, revoking] = useActionState(revokeInvitationAction, initialState);
  const [acceptState, acceptAction, accepting] = useActionState(acceptInvitationAction, initialState);

  return (
    <div className="flex flex-col items-end gap-1">
      <div className="flex gap-2">
        <form action={acceptAction}>
          <input type="hidden" name="invitationId" value={invitationId} />
          <button
            type="submit"
            disabled={accepting}
            className="h-8 rounded-md border border-neutral-300 bg-white px-2 text-xs font-medium hover:bg-neutral-50 disabled:opacity-60"
          >
            {accepting ? "…" : "قبول نيابة عن المدعو"}
          </button>
        </form>
        <form action={revokeAction}>
          <input type="hidden" name="invitationId" value={invitationId} />
          <button
            type="submit"
            disabled={revoking}
            className="h-8 rounded-md border border-red-200 bg-white px-2 text-xs font-medium text-red-700 hover:bg-red-50 disabled:opacity-60"
          >
            {revoking ? "…" : "إلغاء"}
          </button>
        </form>
      </div>
      {revokeState.error ? <p className="text-xs text-red-700">{revokeState.error}</p> : null}
      {acceptState.error ? <p className="text-xs text-red-700">{acceptState.error}</p> : null}
    </div>
  );
}
