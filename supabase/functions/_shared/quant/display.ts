/**
 * DISPLAY precision — IV-QUANT-FOUNDATION-01 (QUANT_CALCULATION_SPEC.md §1).
 *
 * The only place Quant numbers are rounded, and only into strings for
 * humans/LLM prompts. Never feed a display string back into a calculation.
 * Locale-neutral ('.' decimal separator); UI localization happens in the
 * client from the raw value.
 */

/** 0.1234 → "12.34%" */
export function formatRatioAsPercent(ratio: number, digits = 2): string {
  if (!Number.isFinite(ratio)) return 'n/a';
  return `${formatNumber(ratio * 100, digits)}%`;
}

/** 104.456 → "104.46 USD" */
export function formatPrice(value: number, currency: string, digits = 2): string {
  if (!Number.isFinite(value)) return 'n/a';
  return `${value.toFixed(digits)} ${currency}`;
}

export function formatNumber(value: number, digits = 4): string {
  if (!Number.isFinite(value)) return 'n/a';
  const s = value.toFixed(digits);
  // Avoid "-0.00" for tiny negatives that round to zero.
  return /^-0(\.0+)?$/.test(s) ? s.slice(1) : s;
}
