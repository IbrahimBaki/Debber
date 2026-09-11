const numberFormatter = new Intl.NumberFormat("ar-EG", {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const CURRENCY_LABELS: Record<string, string> = {
  EGP: "ج.م",
  SAR: "ر.س",
  USD: "$",
  EUR: "€",
};

/**
 * Pure formatter with no browser-only dependency, so both Server and Client Components can
 * call it directly. Do not move this into a "use client" module (e.g. money-input.tsx) --
 * React Server Components cannot invoke a plain function exported from a client module.
 */
export function currencyLabel(currencyCode: string): string {
  return CURRENCY_LABELS[currencyCode] ?? currencyCode;
}

/** Formats a server-supplied numeric amount for display. Never used as a calculation input. */
export function formatAmount(value: number): string {
  return numberFormatter.format(value);
}

export function formatDateRange(start: string, end: string): string {
  const formatter = new Intl.DateTimeFormat("ar-EG", { day: "numeric", month: "long", year: "numeric" });
  return `${formatter.format(new Date(start))} – ${formatter.format(new Date(end))}`;
}

export function formatDate(value: string): string {
  return new Intl.DateTimeFormat("ar-EG", { day: "numeric", month: "long" }).format(new Date(value));
}
