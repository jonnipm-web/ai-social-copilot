/**
 * Safe observability — IV-QUANT-FOUNDATION-01 (QUANT_SECURITY_MODEL.md §6).
 *
 * The ONLY shape a Quant log line may take. It carries operational facts
 * (id, provider, sizes, period, calculation types, freshness, latency,
 * error code) and nothing that identifies holdings: no symbols, no
 * quantities, no prices, no portfolio composition, no document text, no
 * keys. Built from an allowlist, so adding a field to a result can never
 * leak it into logs.
 */
import type { QuantErrorCode } from './errors.ts';
import type { FreshnessState } from './provenance.ts';

export interface QuantLogEvent {
  readonly event: 'quant_analysis';
  readonly analysis_id: string | null;
  readonly provider_id: string | null;
  readonly instrument_count: number;
  readonly dataset_size: number;
  readonly period_start: string | null;
  readonly period_end: string | null;
  readonly calculations: readonly string[];
  readonly freshness: FreshnessState | null;
  readonly latency_ms: number;
  readonly error_code: QuantErrorCode | null;
}

export interface QuantLogInput {
  analysisId?: string | null;
  providerId?: string | null;
  instrumentCount: number;
  datasetSize: number;
  periodStart?: string | null;
  periodEnd?: string | null;
  calculations?: readonly string[];
  freshness?: FreshnessState | null;
  latencyMs: number;
  errorCode?: QuantErrorCode | null;
}

const SAFE_TOKEN_RE = /^[A-Za-z0-9_:.\-]{1,64}$/;

function safe(v: string | null | undefined): string | null {
  return typeof v === 'string' && SAFE_TOKEN_RE.test(v) ? v : null;
}

export function quantLogEvent(i: QuantLogInput): QuantLogEvent {
  return {
    event: 'quant_analysis',
    analysis_id: safe(i.analysisId),
    provider_id: safe(i.providerId),
    instrument_count: Number.isSafeInteger(i.instrumentCount) ? i.instrumentCount : 0,
    dataset_size: Number.isSafeInteger(i.datasetSize) ? i.datasetSize : 0,
    period_start: safe(i.periodStart),
    period_end: safe(i.periodEnd),
    calculations: (i.calculations ?? []).map((c) => safe(c)).filter((c): c is string => c !== null).slice(0, 32),
    freshness: i.freshness ?? null,
    latency_ms: Number.isFinite(i.latencyMs) ? Math.max(0, Math.round(i.latencyMs)) : 0,
    error_code: i.errorCode ?? null,
  };
}
