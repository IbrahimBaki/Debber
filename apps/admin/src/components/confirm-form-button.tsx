"use client";

import { useState } from "react";

/**
 * A form-bound button requiring one extra click before it submits, for sensitive admin actions
 * (activate/disable/enable/revoke). Mirrors apps/web's void-transaction confirm pattern.
 */
export function ConfirmFormButton({
  confirmLabel,
  children,
  tone = "default",
}: {
  confirmLabel: string;
  children: React.ReactNode;
  tone?: "default" | "danger";
}) {
  const [confirming, setConfirming] = useState(false);

  const toneClass =
    tone === "danger"
      ? "bg-red-600 text-white hover:bg-red-700"
      : "bg-neutral-900 text-white hover:bg-neutral-800";

  if (confirming) {
    return (
      <div className="flex items-center gap-2">
        <span className="text-sm text-neutral-600">{confirmLabel}</span>
        <button
          type="submit"
          className={`h-9 rounded-md px-3 text-sm font-semibold ${toneClass}`}
        >
          تأكيد
        </button>
        <button
          type="button"
          onClick={() => setConfirming(false)}
          className="h-9 rounded-md border border-neutral-300 px-3 text-sm font-medium text-neutral-700"
        >
          تراجع
        </button>
      </div>
    );
  }

  return (
    <button
      type="button"
      onClick={() => setConfirming(true)}
      className="h-9 rounded-md border border-neutral-300 bg-white px-3 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
    >
      {children}
    </button>
  );
}
