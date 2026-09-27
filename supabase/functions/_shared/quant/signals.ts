/**
 * Indicators and signals — IV-QUANT-FOUNDATION-01 (QUANT_DOMAIN_MODEL.md §8).
 *
 *   INDICATOR       a number derived from data (e.g. SMA_20 = 104.3)
 *   SIGNAL          a factual, descriptive observation about indicators
 *                   ("close crossed above SMA_20 on 2026-03-04")
 *   RECOMMENDATION  an opinion about what someone should do — NOT MODELED
 *   ORDER           an instruction to a broker — NOT MODELED, no path exists
 *
 * A Signal's `nature` is the literal type 'DESCRIPTIVE' and its
 * `isRecommendation` is the literal type `false`: the type system itself
 * refuses a Signal that claims to be advice. There are deliberately no
 * Recommendation / Order / TradeIntent types in the Quant Foundation.
 */
import { fail, ok, type QuantResult } from './errors.ts';
import { simpleMovingAverage } from './metrics.ts';

export type SignalType = 'MA_CROSSOVER';
export type CrossDirection = 'CROSSED_ABOVE' | 'CROSSED_BELOW';

export interface Signal {
  readonly type: SignalType;
  readonly nature: 'DESCRIPTIVE';
  readonly isRecommendation: false;
  readonly direction: CrossDirection;
  /** Bar index at which the cross is observed (fast/slow both defined at index−1 and index). */
  readonly index: number;
  readonly t: number;
  readonly description: string;
  readonly parameters: Readonly<Record<string, number>>;
}

/**
 * Moving-average crossover observations. Let s_t = sign(fast_t − slow_t)
 * and p = the last NON-ZERO sign before t. A cross is reported at t when
 * p ≠ 0, s_t ≠ 0 and s_t ≠ p. Consequences (pinned by tests, Codex Gate 1 CX1-08):
 *   above → equal → above   no cross (a touch)
 *   above → equal → below   CROSSED_BELOW, reported at the first bar strictly below
 *   below → equal → above   CROSSED_ABOVE, reported at the first bar strictly above
 * No trading rule is implied.
 */
export function movingAverageCrossovers(
  prices: readonly number[],
  timestamps: readonly number[],
  fastWindow: number,
  slowWindow: number,
): QuantResult<Signal[]> {
  if (prices.length !== timestamps.length) return fail('INVALID_PARAMETER', 'prices and timestamps differ in length');
  if (!(fastWindow < slowWindow)) return fail('INVALID_PARAMETER', 'fastWindow must be < slowWindow');
  const fast = simpleMovingAverage(prices, fastWindow);
  if (!fast.ok) return fast;
  const slow = simpleMovingAverage(prices, slowWindow);
  if (!slow.ok) return slow;
  const out: Signal[] = [];
  let prevSign = 0;
  for (let t = 0; t < prices.length; t++) {
    const f = fast.value[t], s = slow.value[t];
    if (f === null || s === null) continue;
    const sign = Math.sign(f - s);
    if (sign !== 0 && prevSign !== 0 && sign !== prevSign) {
      const direction: CrossDirection = sign > 0 ? 'CROSSED_ABOVE' : 'CROSSED_BELOW';
      out.push({
        type: 'MA_CROSSOVER',
        nature: 'DESCRIPTIVE',
        isRecommendation: false,
        direction,
        index: t,
        t: timestamps[t],
        description: `SMA(${fastWindow}) ${direction === 'CROSSED_ABOVE' ? 'crossed above' : 'crossed below'} SMA(${slowWindow}). Descriptive observation only; not a recommendation.`,
        parameters: { fastWindow, slowWindow },
      });
    }
    if (sign !== 0) prevSign = sign;
  }
  return ok(out);
}
