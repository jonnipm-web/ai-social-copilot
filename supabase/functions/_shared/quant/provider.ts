/**
 * Market data provider abstraction — IV-QUANT-FOUNDATION-01
 * (QUANT_ARCHITECTURE.md §4).
 *
 * Vendor-neutral. A provider returns RAW payloads plus the provenance facts
 * only it knows (source time, retrieval time, adjustment, currency); the
 * canonical PriceSeries is built by timeseries.createPriceSeries(), never by
 * the provider. No concrete external vendor is wired in the Foundation (no
 * paid API, no key, no network) — only the deterministic FixtureProvider.
 *
 * Rules for any future external provider (enforced at review, documented in
 * QUANT_SECURITY_MODEL.md): fixed allowlisted host via _shared/safe_fetch.ts,
 * API key from server env only (never from the client, never logged),
 * response size cap, timeout, and provider errors mapped to
 * PROVIDER_UNAVAILABLE — never to an empty-but-successful series.
 */
import { fail, ok, type QuantResult } from './errors.ts';
import { type InstrumentIdentity, instrumentKey } from './instrument.ts';
import type { AdjustmentPolicy, DataProvenance, Frequency } from './provenance.ts';
import type { RawBarInput } from './timeseries.ts';

export type ProviderCapability = 'INSTRUMENT_LOOKUP' | 'LATEST_QUOTE' | 'HISTORICAL_BARS' | 'METADATA';
/** Declared for the roadmap; no provider implements them in the Foundation. */
export type FutureProviderCapability = 'FUNDAMENTALS' | 'ECONOMIC_DATA' | 'NEWS';

export interface RawQuote {
  readonly price: number;
  readonly currency: string;
  /** Market time the quote refers to (ISO 8601 UTC). */
  readonly marketTimestamp: string;
}

export interface ProviderResponse<T> {
  readonly data: T;
  readonly provenance: DataProvenance;
}

export interface HistoricalBarsRequest {
  readonly instrument: InstrumentIdentity;
  readonly frequency: Frequency;
  /** Inclusive range, epoch ms UTC. */
  readonly fromT: number;
  readonly toT: number;
  readonly adjustment: AdjustmentPolicy;
}

export interface MarketDataProvider {
  readonly id: string;
  readonly capabilities: ReadonlySet<ProviderCapability>;
  lookupInstrument(query: string): Promise<QuantResult<InstrumentIdentity[]>>;
  latestQuote(instrument: InstrumentIdentity): Promise<QuantResult<ProviderResponse<RawQuote>>>;
  historicalBars(req: HistoricalBarsRequest): Promise<QuantResult<ProviderResponse<RawBarInput[]>>>;
}

export interface FixtureDataset {
  readonly instrument: InstrumentIdentity;
  readonly frequency: Frequency;
  readonly adjustment: AdjustmentPolicy;
  readonly bars: readonly RawBarInput[];
}

/**
 * Deterministic in-memory provider over golden datasets. `retrievedAt` comes
 * from an injected clock so provenance and freshness are reproducible.
 * Latest quote = last bar close, stamped with that bar's time: a fixture
 * never pretends a historical close is a live price.
 */
export class FixtureProvider implements MarketDataProvider {
  readonly id = 'fixture-golden';
  readonly capabilities: ReadonlySet<ProviderCapability> = new Set(['INSTRUMENT_LOOKUP', 'LATEST_QUOTE', 'HISTORICAL_BARS']);
  private readonly byKey: Map<string, FixtureDataset>;

  constructor(datasets: readonly FixtureDataset[], private readonly clock: () => number) {
    this.byKey = new Map(datasets.map((d) => [instrumentKey(d.instrument), d]));
  }

  private provenance(d: FixtureDataset, sourceAsOfT: number | null): DataProvenance {
    return {
      providerId: this.id,
      providerKind: 'FIXTURE',
      ...(sourceAsOfT !== null ? { sourceAsOf: new Date(sourceAsOfT).toISOString() } : {}),
      retrievedAt: new Date(this.clock()).toISOString(),
      frequency: d.frequency,
      currency: d.instrument.currency,
      adjustment: d.adjustment,
      trust: 'SYNTHETIC_FIXTURE',
    };
  }

  // deno-lint-ignore require-await
  async lookupInstrument(query: string): Promise<QuantResult<InstrumentIdentity[]>> {
    const q = String(query ?? '').trim().toUpperCase();
    if (q.length === 0 || q.length > 32) return fail('INVALID_PARAMETER', 'query must be 1..32 characters');
    return ok([...this.byKey.values()].map((d) => d.instrument).filter((i) => i.symbol === q));
  }

  // deno-lint-ignore require-await
  async latestQuote(instrument: InstrumentIdentity): Promise<QuantResult<ProviderResponse<RawQuote>>> {
    const d = this.byKey.get(instrumentKey(instrument));
    if (!d || d.bars.length === 0) return fail('INVALID_INSTRUMENT', 'instrument not available from this provider');
    const last = d.bars.reduce((a, b) => ((b.t as number) > (a.t as number) ? b : a));
    const t = last.t as number;
    return ok({
      data: { price: last.close as number, currency: d.instrument.currency, marketTimestamp: new Date(t).toISOString() },
      provenance: this.provenance(d, t),
    });
  }

  // deno-lint-ignore require-await
  async historicalBars(req: HistoricalBarsRequest): Promise<QuantResult<ProviderResponse<RawBarInput[]>>> {
    const d = this.byKey.get(instrumentKey(req.instrument));
    if (!d) return fail('INVALID_INSTRUMENT', 'instrument not available from this provider');
    if (req.frequency !== d.frequency) return fail('INVALID_PARAMETER', 'frequency not available', { frequency: req.frequency });
    if (req.adjustment !== d.adjustment) return fail('INVALID_PARAMETER', 'adjustment policy not available', { adjustment: req.adjustment });
    if (!(Number.isSafeInteger(req.fromT) && Number.isSafeInteger(req.toT) && req.fromT <= req.toT)) {
      return fail('INVALID_PARAMETER', 'invalid time range');
    }
    const bars = d.bars.filter((b) => (b.t as number) >= req.fromT && (b.t as number) <= req.toT);
    const newest = bars.reduce<number | null>((m, b) => (m === null || (b.t as number) > m ? (b.t as number) : m), null);
    return ok({ data: [...bars], provenance: this.provenance(d, newest) });
  }
}
