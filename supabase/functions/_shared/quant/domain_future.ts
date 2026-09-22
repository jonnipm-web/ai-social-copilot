/**
 * Contracts prepared for later Quant gates — IV-QUANT-FOUNDATION-01
 * (QUANT_DOMAIN_MODEL.md §9–§12). Types + minimal validation only: no
 * provider, no persistence, no UI.
 */
import { fail, ok, type QuantResult } from './errors.ts';
import { type InstrumentIdentity, instrumentKey } from './instrument.ts';

// --- Watchlist ---------------------------------------------------------------

export const MAX_WATCHLIST_ITEMS = 200;

export interface Watchlist {
  readonly name: string;
  /** Optional project scope. Ownership is enforced server-side (RLS), never by this type. */
  readonly projectId?: string;
  readonly instruments: readonly InstrumentIdentity[];
}

/** Dedupes by canonical instrument key (keeps first) and bounds size. */
export function normalizeWatchlist(w: Watchlist): QuantResult<Watchlist> {
  const name = typeof w?.name === 'string' ? w.name.trim() : '';
  if (name.length === 0 || name.length > 80) return fail('INVALID_PARAMETER', 'watchlist name must be 1..80 characters');
  if (!Array.isArray(w.instruments)) return fail('INVALID_PARAMETER', 'instruments must be an array');
  const seen = new Set<string>();
  const instruments: InstrumentIdentity[] = [];
  for (const i of w.instruments) {
    const k = instrumentKey(i);
    if (seen.has(k)) continue;
    seen.add(k);
    instruments.push(i);
  }
  if (instruments.length > MAX_WATCHLIST_ITEMS) return fail('DATASET_TOO_LARGE', 'too many watchlist items', { max: MAX_WATCHLIST_ITEMS });
  return ok({ name, ...(w.projectId ? { projectId: w.projectId } : {}), instruments });
}

// --- Fundamentals (future Q5) ---------------------------------------------------

export interface FundamentalMetric {
  readonly instrumentKey: string;
  /** e.g. 'REVENUE', 'NET_INCOME', 'EPS_DILUTED' — taxonomy decided in Q5. */
  readonly metric: string;
  readonly reportedValue: number;
  readonly currency: string;
  readonly periodStart: string;
  readonly periodEnd: string;
  readonly fiscalPeriod: string;
  /** When the figure became public — the only safe point-in-time key for backtests. */
  readonly filingDate: string;
  readonly isRestated: boolean;
  readonly providerId: string;
}

// --- Economic series (future) ---------------------------------------------------

/** NOT an instrument: not tradable, no price, no position may reference it. */
export interface EconomicSeriesIdentity {
  readonly kind: 'ECONOMIC_SERIES';
  /** e.g. 'CPI', 'POLICY_RATE', 'UNEMPLOYMENT', 'GDP'. */
  readonly concept: string;
  /** ISO 3166-1 alpha-2 or a region code. */
  readonly region: string;
  readonly unit: string;
  readonly seasonallyAdjusted: boolean;
  readonly providerSeriesId?: string;
}

// --- Research / documents (Knowledge boundary) ---------------------------------

/**
 * A figure extracted from a user document (PDF/CSV/report) through Knowledge.
 * Always UNTRUSTED: it can support a narrative, never overwrite or stand in
 * for market data, and never enter the calculation engine without passing
 * through the same schema validation as any other dataset.
 */
export interface UntrustedDocumentEvidence {
  readonly trust: 'UNTRUSTED_CONTENT';
  readonly knowledgeItemId: string;
  readonly excerpt: string;
  readonly claimedValue?: number;
}
