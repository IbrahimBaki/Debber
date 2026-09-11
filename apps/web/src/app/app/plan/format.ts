const numberFormatter = new Intl.NumberFormat("ar-EG", {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

/** Formats a server-supplied numeric amount for display. Never used as a calculation input. */
export function formatAmount(value: number): string {
  return numberFormatter.format(value);
}

export function formatDateRange(start: string, end: string): string {
  const formatter = new Intl.DateTimeFormat("ar-EG", { day: "numeric", month: "long", year: "numeric" });
  return `${formatter.format(new Date(start))} – ${formatter.format(new Date(end))}`;
}
