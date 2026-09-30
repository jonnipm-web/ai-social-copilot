/**
 * Synthetic market-data vendor payloads — IV-QUANT-REAL-DATA-READINESS-03
 * (docs/quant/QUANT_REAL_DATA_READINESS.md §2).
 *
 * ORIGIN: 100 % generated here. No real vendor dataset, price or symbol
 * history is copied. Series are a deterministic log-normal random walk
 * seeded from the canonical instrument key (FNV-1a + mulberry32), placed on
 * the instrument's real exchange sessions (XNYS/XNAS/XLON calendars) so
 * freshness/calendar logic is exercised realistically. The JSON shape is a
 * generic "meta + values" envelope common to REST market-data APIs, not any
 * specific vendor's schema.
 *
 * Used by: provider-adapter contract tests (served through a fake fetch),
 * the in-process SYNTHETIC_PROVIDER data source of the Lab, and benchmarks.
 * Pure: the clock is injected; no network.
 */
import { addDays, calendarForMic, isTradingDay, marketClock } from './calendar.ts';
import type { AdjustmentPolicy, Frequency } from './provenance.ts';
import type { InstrumentIdentity } from './instrument.ts';
import { instrumentKey } from './instrument.ts';
import { fail, ok, type QuantResult } from './errors.ts';
import type { HistoricalBarsRequest, MarketDataProvider, ProviderCapability, ProviderResponse, RawQuote } from './provider.ts';
import type { RawBarInput } from './timeseries.ts';
import { syntheticVendorAdapter } from './provider_adapter.ts';

export interface SyntheticVendorBar {
  datetime: string;
  open: string;
  high: string;
  low: string;
  close: string;
  volume: string;
}

export interface SyntheticVendorPayload {
  meta: {
    symbol: string;
    exchange: string | null;
    currency: string;
    interval: '1day';
    adjustment: AdjustmentPolicy;
    as_of: string;
    generated_by: 'insightvalues-synthetic-v1';
  };
  values: SyntheticVendorBar[];
  status: 'ok';
}

function fnv1a(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

function mulberry32(seed: number): () => number {
  let a = seed;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Session dates (YYYY-MM-DD) ending at the last completed session at `nowMs`. */
export function syntheticSessions(instrument: InstrumentIdentity, nowMs: number, count: number): string[] {
  const cal = calendarForMic(instrument.exchangeMic);
  const clock = cal ? marketClock(cal, nowMs) : null;
  let d = clock?.lastCompletedSession ?? new Date(nowMs - 86_400_000).toISOString().slice(0, 10);
  const out: string[] = [];
  for (let guard = 0; out.length < count && guard < count * 3 + 30; guard++) {
    const trading = cal ? isTradingDay(cal, d) : null;
    const weekday = new Date(`${d}T00:00:00Z`).getUTCDay();
    if (trading === true || (trading === null && weekday !== 0 && weekday !== 6)) out.push(d);
    d = addDays(d, -1);
  }
  return out.reverse();
}

/**
 * Deterministic vendor-shaped payload for `instrument`: `sessions` daily bars
 * ending at the last completed session. `drift`/`vol` are per-session.
 */
export function syntheticVendorPayload(
  instrument: InstrumentIdentity,
  nowMs: number,
  opts: { sessions?: number; adjustment?: AdjustmentPolicy; drift?: number; vol?: number } = {},
): SyntheticVendorPayload {
  const sessions = syntheticSessions(instrument, nowMs, opts.sessions ?? 260);
  const rand = mulberry32(fnv1a(instrumentKey(instrument)));
  const drift = opts.drift ?? 0.0003;
  const vol = opts.vol ?? 0.015;
  let price = 20 + rand() * 180;
  const values: SyntheticVendorBar[] = [];
  for (const d of sessions) {
    // Box–Muller normal draw → log-normal step (always positive).
    const u = Math.max(rand(), 1e-12), v = rand();
    const z = Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
    const open = price;
    const close = price * Math.exp(drift + vol * z);
    const high = Math.max(open, close) * (1 + rand() * 0.006);
    const low = Math.min(open, close) * (1 - rand() * 0.006);
    values.push({
      datetime: d,
      open: open.toFixed(4),
      high: high.toFixed(4),
      low: low.toFixed(4),
      close: close.toFixed(4),
      volume: String(Math.round(1e5 + rand() * 9e5)),
    });
    price = close;
  }
  const last = values[values.length - 1]?.datetime ?? new Date(nowMs).toISOString().slice(0, 10);
  return {
    meta: {
      symbol: instrument.symbol,
      exchange: instrument.exchangeMic ?? null,
      currency: instrument.currency,
      interval: '1day',
      adjustment: opts.adjustment ?? 'SPLIT_AND_DIVIDEND_ADJUSTED',
      as_of: `${last}T00:00:00.000Z`,
      generated_by: 'insightvalues-synthetic-v1',
    },
    values: [...values].reverse(), // newest first, as many REST vendors return
    status: 'ok',
  };
}

export const SYNTHETIC_FREQUENCY: Frequency = 'DAILY';

// ---------------------------------------------------------------- in-process synthetic provider


/**
 * The Lab's SYNTHETIC_PROVIDER data source: builds the vendor-shaped payload
 * in process and parses it through the SAME adapter code a network provider
 * uses (no fetch). Provenance is FIXTURE / SYNTHETIC_FIXTURE → evidence WEAK.
 */
export class SyntheticInProcessProvider implements MarketDataProvider {
  readonly id = syntheticVendorAdapter.id;
  readonly capabilities: ReadonlySet<ProviderCapability> = new Set(['HISTORICAL_BARS']);
  constructor(private readonly clock: () => number) {}

  // deno-lint-ignore require-await
  async lookupInstrument(): Promise<QuantResult<InstrumentIdentity[]>> {
    return fail('PROVIDER_UNAVAILABLE', 'lookup not supported by the synthetic provider');
  }
  // deno-lint-ignore require-await
  async latestQuote(): Promise<QuantResult<ProviderResponse<RawQuote>>> {
    return fail('PROVIDER_UNAVAILABLE', 'quotes not supported by the synthetic provider');
  }
  // deno-lint-ignore require-await
  async historicalBars(req: HistoricalBarsRequest): Promise<QuantResult<ProviderResponse<RawBarInput[]>>> {
    const now = this.clock();
    const payload = syntheticVendorPayload(req.instrument, now, { adjustment: req.adjustment });
    payload.values = payload.values.filter((v) => {
      const t = Date.parse(`${v.datetime}T00:00:00Z`);
      return t >= req.fromT && t <= req.toT;
    });
    if (payload.values.length === 0) return fail('INSUFFICIENT_DATA', 'no synthetic bars in range');
    const res = syntheticVendorAdapter.parseResponse(req, 200, new Headers(), JSON.stringify(payload), now);
    return res.ok ? ok(res.value) : res;
  }
}
