/**
 * Quant API rate-limit policy — IV-QUANT-REAL-DATA-READINESS-03
 * (docs/quant/QUANT_RATE_LIMIT_POLICY.md).
 *
 * Pure data + a deterministic fixed-window counter used by tests and the
 * local Lab dev server. The production authority is the SQL function
 * public.quant_rate_limit_hit (migration 20260924000100), whose per-bucket
 * limits must equal RATE_LIMITS below (test QB-17 compares them).
 *
 * These are TECHNICAL protection limits per authenticated user, not
 * commercial quotas.
 */

export type RateLimitBucket = 'quant-analyze' | 'quant-watchlists-read' | 'quant-watchlists-write';

export const RATE_LIMIT_WINDOW_SECONDS = 60;

export const RATE_LIMITS: Readonly<Record<RateLimitBucket, number>> = {
  'quant-analyze': 30,
  'quant-watchlists-read': 120,
  'quant-watchlists-write': 60,
};

export interface RateLimitDecision {
  readonly allowed: boolean;
  readonly limit: number;
  readonly remaining: number;
  /** Seconds until the current window resets (≥ 1). */
  readonly retryAfterSeconds: number;
}

/**
 * Deterministic in-memory fixed-window limiter (tests / local dev server
 * only — not shared across Edge isolates, so never the production authority).
 * Keyed by the SERVER-derived user id; the clock is injected.
 */
export class FixedWindowCounter {
  private readonly windows = new Map<string, { windowStart: number; hits: number }>();

  constructor(private readonly clock: () => number, private readonly maxKeys = 10_000) {}

  hit(userId: string, bucket: RateLimitBucket): RateLimitDecision {
    const limit = RATE_LIMITS[bucket];
    const now = this.clock();
    const windowMs = RATE_LIMIT_WINDOW_SECONDS * 1000;
    const windowStart = Math.floor(now / windowMs) * windowMs;
    // JSON tuple key: no separator-injection collisions between user ids and buckets.
    const key = JSON.stringify([userId, bucket]);
    const cur = this.windows.get(key);
    const hits = cur && cur.windowStart === windowStart ? cur.hits + 1 : 1;
    if (!cur && this.windows.size >= this.maxKeys) this.windows.clear(); // bounded memory
    this.windows.set(key, { windowStart, hits });
    return {
      allowed: hits <= limit,
      limit,
      remaining: Math.max(limit - hits, 0),
      retryAfterSeconds: Math.max(1, Math.ceil((windowStart + windowMs - now) / 1000)),
    };
  }
}
