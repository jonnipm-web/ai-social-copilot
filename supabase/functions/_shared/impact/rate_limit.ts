/**
 * Dossier rate limiting — IV-IMPACT-I5-PRODUCT-UX-01 (closes Codex I4G3-04).
 *
 * Threat model: dossier generation abuse (every get_dossier rebuilds and
 * hashes the full projection), repeated export (register + audit growth),
 * verification spam, resource exhaustion, enumeration.
 *
 * Design (server-authoritative, reusing the ai_quota pattern):
 *   - identity = the authenticated caller (never a client field);
 *   - fixed window per (caller, bucket), counted by ONE atomic statement in
 *     the database (impact_rate_limit_hit, SECURITY DEFINER, auth.uid());
 *   - applied in the Edge Function BEFORE the investigation ownership check,
 *     so a foreign or missing investigation costs the caller exactly the same
 *     and reveals nothing (no oracle); counters are per caller, never per
 *     investigation owner;
 *   - blocked ⇒ 429 RATE_LIMITED + Retry-After; limiter failure ⇒ fail CLOSED;
 *   - limits are provisional Lab values, configurable server-side, NOT a
 *     commercial contract; any future tier may change QUANTITY only — the
 *     same engine and the same epistemic quality for everyone.
 */
import { fail, ok, type ImpactResult } from './errors.ts';

export type RateBucket = 'dossier_build' | 'dossier_export' | 'dossier_verify';

export interface RateRule {
  readonly limit: number;
  readonly windowSeconds: number;
}

/** Fixed in the database function (Codex I5G2-01) — not configurable, never a caller argument. */
export const RATE_WINDOW_SECONDS = 60;

export const DEFAULT_RATE_LIMITS: Readonly<Record<RateBucket, RateRule>> = Object.freeze({
  dossier_build: { limit: 30, windowSeconds: RATE_WINDOW_SECONDS },
  dossier_export: { limit: 10, windowSeconds: RATE_WINDOW_SECONDS },
  dossier_verify: { limit: 30, windowSeconds: RATE_WINDOW_SECONDS },
});

const ENV_KEY: Readonly<Record<RateBucket, string>> = {
  dossier_build: 'IMPACT_RL_DOSSIER_BUILD_PER_MIN',
  dossier_export: 'IMPACT_RL_DOSSIER_EXPORT_PER_MIN',
  dossier_verify: 'IMPACT_RL_DOSSIER_VERIFY_PER_MIN',
};

/** Server-side configuration (env), bounded; anything invalid keeps the default. */
export function rateLimitsFrom(get: (key: string) => string | undefined): Readonly<Record<RateBucket, RateRule>> {
  const out = { ...DEFAULT_RATE_LIMITS } as Record<RateBucket, RateRule>;
  for (const b of Object.keys(ENV_KEY) as RateBucket[]) {
    const n = Number(get(ENV_KEY[b]));
    if (Number.isInteger(n) && n >= 1 && n <= 1000) out[b] = { limit: n, windowSeconds: RATE_WINDOW_SECONDS };
  }
  return Object.freeze(out);
}

export function bucketFor(action: string): RateBucket | null {
  switch (action) {
    case 'get_dossier':
      return 'dossier_build';
    case 'export_dossier':
      return 'dossier_export';
    case 'verify_dossier':
      return 'dossier_verify';
    default:
      return null;
  }
}

export interface RateHit {
  /** Requests counted in the current window, INCLUDING this one. */
  readonly count: number;
  /** Start of the current window (ms since epoch). */
  readonly windowStartMs: number;
}

export interface ImpactRateLimiter {
  hit(userId: string, bucket: RateBucket, windowSeconds: number, nowMs: number): Promise<ImpactResult<RateHit>>;
}

export interface RateDecision {
  readonly allowed: boolean;
  readonly retryAfterSeconds: number;
}

export function decideRate(hit: RateHit, rule: RateRule, nowMs: number): RateDecision {
  const end = hit.windowStartMs + rule.windowSeconds * 1000;
  return { allowed: hit.count <= rule.limit, retryAfterSeconds: Math.max(1, Math.ceil((end - nowMs) / 1000)) };
}

export function windowStartOf(nowMs: number, windowSeconds: number): number {
  const w = windowSeconds * 1000;
  return Math.floor(nowMs / w) * w;
}

/** In-memory twin of impact_rate_limit_hit (tests / Lab without a database). */
export class InMemoryRateLimiter implements ImpactRateLimiter {
  readonly counts = new Map<string, number>();
  failNext = false;
  hit(userId: string, bucket: RateBucket, windowSeconds: number, nowMs: number): Promise<ImpactResult<RateHit>> {
    if (this.failNext) {
      this.failNext = false;
      return Promise.resolve(fail('INTERNAL_ERROR', 'rate limiter unavailable'));
    }
    const start = windowStartOf(nowMs, windowSeconds);
    const key = `${userId}|${bucket}|${start}`;
    const count = (this.counts.get(key) ?? 0) + 1; // single-threaded: atomic
    this.counts.set(key, count);
    return Promise.resolve(ok({ count, windowStartMs: start }));
  }
}
