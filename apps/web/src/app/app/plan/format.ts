// Owner-approved display rule: Latin (0-9) digits always ("ar-EG" alone would render
// Arabic-Indic digits, ٠١٢٣...), and no fraction digits ever, even when the underlying
// numeric(14,2) value has real cents. This is presentation only -- it never touches stored
// precision, RPC signatures, or accepted transaction precision.
const numberFormatter = new Intl.NumberFormat("ar-EG", {
  numberingSystem: "latn",
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
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

/**
 * Formats a server-supplied numeric amount for display: Latin digits, thousands separators,
 * no fraction digits. Never used as a calculation input -- the underlying numeric(14,2) value
 * and every domain RPC keep full stored precision regardless of how this displays it.
 */
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
