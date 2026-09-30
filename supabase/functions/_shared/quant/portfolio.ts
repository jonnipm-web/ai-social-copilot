/**
 * Portfolio foundation — IV-QUANT-FOUNDATION-01 (QUANT_DOMAIN_MODEL.md §6).
 *
 * MANUAL / DEMO positions only. There is no broker connection, no account
 * import, no order, no rebalance execution — the portfolio is an analysis
 * input the user typed (or a fixture), nothing more.
 *
 * Currency rule: amounts in different currencies are NEVER summed. Without
 * an explicit FX conversion (future: FX source + rate + timestamp) a
 * multi-currency portfolio returns CURRENCY_MISMATCH as a stated limitation.
 */
import { fail, ok, type QuantResult, type QuantWarning } from './errors.ts';
import { fsum } from './numeric.ts';
import { createInstrument, type InstrumentIdentity, instrumentKey, requireFoundationSupported } from './instrument.ts';
import { ALL_FREQUENCIES, assessFreshness, DEFAULT_FRESHNESS_POLICIES, type FreshnessAssessment, type Frequency, parseIsoUtc } from './provenance.ts';
import { concentration, type Concentration, validateWeights, type WeightEntry } from './risk.ts';
import { type PriceBasis, type PriceSeries, pricesOf } from './timeseries.ts';

export const MAX_PORTFOLIO_POSITIONS = 500;


export interface PortfolioPosition {
  readonly instrument: InstrumentIdentity;
  /** Units held. Must be > 0 (short positions are out of Foundation scope). */
  readonly quantity: number;
  /** Optional, per unit, in the instrument currency. Informational only. */
  readonly costBasisPerUnit?: number;
}

export interface ManualPortfolio {
  readonly source: 'MANUAL' | 'DEMO';
  readonly baseCurrency: string;
  readonly positions: readonly PortfolioPosition[];
}

export interface PricePoint {
  readonly price: number;
  readonly currency: string;
  /** Market as-of time of this price (ISO 8601 UTC). */
  readonly asOf: string;
  readonly frequency: Frequency;
}

export interface Holding {
  readonly key: string;
  readonly quantity: number;
  readonly price: number;
  readonly marketValue: number;
  readonly weight: number;
  readonly unrealizedReturn: number | null;
  readonly priceFreshness: FreshnessAssessment;
}

export interface PortfolioValuation {
  readonly currency: string;
  readonly totalMarketValue: number;
  readonly holdings: readonly Holding[];
  readonly concentration: Concentration;
  readonly warnings: readonly QuantWarning[];
}

export function validatePortfolio(p: ManualPortfolio): QuantResult<ManualPortfolio> {
  if (!p || (p.source !== 'MANUAL' && p.source !== 'DEMO')) return fail('INVALID_PORTFOLIO', 'portfolio source must be MANUAL or DEMO');
  if (!/^[A-Z]{3}$/.test(p.baseCurrency ?? '')) return fail('INVALID_PORTFOLIO', 'baseCurrency must be ISO 4217');
  if (!Array.isArray(p.positions) || p.positions.length === 0) return fail('INVALID_PORTFOLIO', 'portfolio has no positions');
  if (p.positions.length > MAX_PORTFOLIO_POSITIONS) {
    return fail('DATASET_TOO_LARGE', 'too many positions', { max: MAX_PORTFOLIO_POSITIONS });
  }
  const seen = new Set<string>();
  const positions: PortfolioPosition[] = [];
  for (const pos of p.positions) {
    // Codex Gate 1 CX1-05: the same identity + asset-class boundary as createPriceSeries.
    const inst = createInstrument(pos?.instrument);
    if (!inst.ok) return inst;
    const supported = requireFoundationSupported(inst.value);
    if (!supported.ok) return supported;
    const key = instrumentKey(inst.value);
    if (seen.has(key)) return fail('INVALID_PORTFOLIO', 'duplicate position for the same instrument', { key });
    seen.add(key);
    if (!Number.isFinite(pos.quantity) || pos.quantity <= 0) {
      return fail('INVALID_PORTFOLIO', 'quantity must be finite and > 0', { key });
    }
    if (pos.costBasisPerUnit !== undefined && (!Number.isFinite(pos.costBasisPerUnit) || pos.costBasisPerUnit <= 0)) {
      return fail('INVALID_PORTFOLIO', 'costBasisPerUnit must be finite and > 0', { key });
    }
    if (inst.value.currency !== p.baseCurrency) {
      return fail('CURRENCY_MISMATCH', 'position currency differs from portfolio base currency and no FX conversion is available', {
        key,
        positionCurrency: inst.value.currency,
        baseCurrency: p.baseCurrency,
      });
    }
    positions.push({ ...pos, instrument: inst.value });
  }
  return ok({ source: p.source, baseCurrency: p.baseCurrency, positions });
}

/** Market value = quantity × price (float64, unrounded). weight_i = MV_i / Σ MV. */
export function valuePortfolio(
  p: ManualPortfolio,
  prices: ReadonlyMap<string, PricePoint>,
  nowMs: number,
): QuantResult<PortfolioValuation> {
  const v = validatePortfolio(p);
  if (!v.ok) return v;
  const rows: { key: string; pos: PortfolioPosition; px: PricePoint; mv: number; fresh: FreshnessAssessment }[] = [];
  const warnings: QuantWarning[] = [];
  for (const pos of v.value.positions) {
    const key = instrumentKey(pos.instrument);
    const px = prices.get(key);
    if (!px) return fail('INSUFFICIENT_DATA', 'no price for position', { key });
    if (!Number.isFinite(px.price) || px.price <= 0) return fail('INVALID_DATASET', 'price must be finite and > 0', { key });
    if (px.currency !== p.baseCurrency) {
      return fail('CURRENCY_MISMATCH', 'price currency differs from portfolio base currency', { key, priceCurrency: px.currency });
    }
    // Claude finding CL-04: never index the policy table with an unvalidated key.
    if (!ALL_FREQUENCIES.includes(px.frequency)) return fail('INVALID_DATASET', 'unknown price frequency', { key });
    const policy = DEFAULT_FRESHNESS_POLICIES[px.frequency];
    const fresh = assessFreshness(parseIsoUtc(px.asOf), nowMs, policy);
    if (fresh.state === 'STALE') warnings.push({ code: 'DATA_STALE', message: 'a position is valued with a stale price', details: { key } });
    if (fresh.state === 'DELAYED') warnings.push({ code: 'DATA_DELAYED', message: 'a position is valued with a delayed price', details: { key } });
    if (fresh.state === 'UNKNOWN') warnings.push({ code: 'FRESHNESS_UNKNOWN', message: 'price age unknown', details: { key } });
    const mv = pos.quantity * px.price;
    if (!Number.isFinite(mv)) return fail('CALCULATION_ERROR', 'market value overflow', { key, reason: 'NON_FINITE_RESULT' });
    if (pos.costBasisPerUnit !== undefined && !Number.isFinite(px.price / pos.costBasisPerUnit - 1)) {
      return fail('CALCULATION_ERROR', 'unrealized return overflow', { key, reason: 'NON_FINITE_RESULT' });
    }
    rows.push({ key, pos, px, mv, fresh });
  }
  const total = fsum(rows.map((r) => r.mv));
  if (!(total > 0) || !Number.isFinite(total)) return fail('CALCULATION_ERROR', 'total market value must be finite and > 0');
  const holdings: Holding[] = rows.map((r) => ({
    key: r.key,
    quantity: r.pos.quantity,
    price: r.px.price,
    marketValue: r.mv,
    weight: r.mv / total,
    unrealizedReturn: r.pos.costBasisPerUnit === undefined ? null : r.px.price / r.pos.costBasisPerUnit - 1,
    priceFreshness: r.fresh,
  }));
  const conc = concentration(holdings.map((h) => ({ key: h.key, weight: h.weight })));
  if (!conc.ok) return conc;
  return ok({ currency: p.baseCurrency, totalMarketValue: total, holdings, concentration: conc.value, warnings });
}

/**
 * Buy-and-hold return with initial weights over the common period:
 *   R = Σ w_i · (P_i(t_end) / P_i(t_start) − 1)
 * where [t_start, t_end] are the first and last timestamps present in EVERY
 * series (no fill). Exact for a buy-and-hold portfolio with no cash flows,
 * dividends reinvested only if the chosen price basis already adjusts.
 */
export function buyAndHoldReturn(
  weights: readonly WeightEntry[],
  series: readonly PriceSeries[],
  basis: PriceBasis,
  baseCurrency: string,
): QuantResult<{ value: number; startT: number; endT: number }> {
  const w = validateWeights(weights);
  if (!w.ok) return w;
  const byKey = new Map(series.map((s) => [instrumentKey(s.instrument), s]));
  if (byKey.size !== series.length) return fail('INVALID_PORTFOLIO', 'duplicate series for the same instrument');
  // Timestamps present in every weighted series (counted, then filtered).
  const seenIn = new Map<number, number>();
  for (const entry of weights) {
    const s = byKey.get(entry.key);
    if (!s) return fail('INSUFFICIENT_DATA', 'no series for weighted instrument', { key: entry.key });
    if (s.instrument.currency !== baseCurrency) {
      return fail('CURRENCY_MISMATCH', 'series currency differs from base currency', { key: entry.key });
    }
    for (const b of s.bars) seenIn.set(b.t, (seenIn.get(b.t) ?? 0) + 1);
  }
  const sorted = [...seenIn].filter(([, n]) => n === weights.length).map(([t]) => t).sort((a, b) => a - b);
  if (sorted.length < 2) return fail('INSUFFICIENT_DATA', 'series share fewer than two timestamps');
  const startT = sorted[0], endT = sorted[sorted.length - 1];
  const parts: number[] = [];
  for (const entry of weights) {
    const s = byKey.get(entry.key)!;
    const px = pricesOf(s, basis);
    if (!px.ok) return px;
    const i0 = s.bars.findIndex((b) => b.t === startT);
    const i1 = s.bars.findIndex((b) => b.t === endT);
    parts.push(entry.weight * (px.value[i1] / px.value[i0] - 1));
  }
  const value = fsum(parts);
  if (!Number.isFinite(value)) return fail('CALCULATION_ERROR', 'buy-and-hold return is not finite', { reason: 'NON_FINITE_RESULT' });
  return ok({ value, startT, endT });
}
