/**
 * Numeric primitives — IV-QUANT-FOUNDATION-01 (QUANT_CALCULATION_SPEC.md §1).
 *
 * COMPUTATION PRECISION: IEEE 754 binary64 (JS number) throughout, never
 * rounded inside the engine. Sums use Neumaier compensated summation so
 * long series do not accumulate O(n·ε) error. Rounding for humans happens
 * only in display.ts.
 */

/** Neumaier (improved Kahan–Babuška) compensated sum. */
export function fsum(values: readonly number[]): number {
  let sum = 0;
  let c = 0;
  for (const v of values) {
    const t = sum + v;
    if (Math.abs(sum) >= Math.abs(v)) c += (sum - t) + v;
    else c += (v - t) + sum;
    sum = t;
  }
  return sum + c;
}

export function mean(values: readonly number[]): number {
  return fsum(values) / values.length;
}

/** Two-pass variance (mean first, then compensated sum of squared
 * deviations) — numerically stable for constant/near-constant series,
 * unlike the one-pass E[x²]−E[x]² form. ddof=1 → sample, ddof=0 → population. */
export function variance(values: readonly number[], ddof: 0 | 1): number {
  const m = mean(values);
  return fsum(values.map((v) => (v - m) * (v - m))) / (values.length - ddof);
}

export function allFinite(values: readonly number[]): boolean {
  return values.every((v) => typeof v === 'number' && Number.isFinite(v));
}
