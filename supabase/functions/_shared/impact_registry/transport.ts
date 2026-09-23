/**
 * Registry transport — IV-IMPACT-I2-REGISTRY-INTELLIGENCE-01.
 *
 * The ONLY network path of Registry Intelligence. It sits OUTSIDE the pure
 * Impact core (_shared/impact/ has no network) and every request goes
 * through _shared/safe_fetch.ts with:
 *   - an exact, server-owned HOST ALLOWLIST checked at every hop (redirects
 *     included) — a caller never supplies a URL or a host;
 *   - https only, no userinfo, no explicit port;
 *   - SSRF guard (private / loopback / link-local / metadata / IPv6-mapped,
 *     DNS-resolved) from safe_fetch.ts;
 *   - timeout, response-size cap, redirect cap, expected content type;
 *   - a per-provider minimum interval (polite rate limit) and NO automatic
 *     retry (a 429 is reported as REGISTRY_RATE_LIMITED, never hammered).
 *
 * Every failure is an OPERATIONAL state (REGISTRY_UNAVAILABLE,
 * REGISTRY_RATE_LIMITED, REGISTRY_RESPONSE_INVALID, ORGANIZATION_NOT_FOUND):
 * an unreachable registry never means "not registered" and is never a signal
 * about an organization.
 */
import { fail, ok, type ImpactResult } from '../impact/errors.ts';
import { safeFetch, UnsafeUrlError } from '../safe_fetch.ts';

export const TRANSPORT_LIMITS = Object.freeze({
  timeoutMs: 10_000,
  maxJsonBytes: 1_000_000,
  maxCsvBytes: 8_000_000,
});

export type Fetcher = (url: string, init: {
  headers?: Record<string, string>;
  timeoutMs: number;
  maxResponseBytes: number;
  allowedHosts: ReadonlySet<string>;
}) => Promise<Response>;

export interface TransportConfig {
  readonly providerId: string;
  /** Exact hostnames (lowercase). */
  readonly hosts: readonly string[];
  /** Accepted content types (prefix match, lowercase). */
  readonly contentTypes: readonly string[];
  readonly maxBytes: number;
  /** Minimum milliseconds between two requests to this provider. */
  readonly minIntervalMs: number;
  readonly headers?: Readonly<Record<string, string>>;
}

export interface TransportDeps {
  readonly fetcher?: Fetcher;
  /** Injected clock (ms); the transport never reads a clock in tests. */
  readonly nowMs?: () => number;
}

export interface FetchedBody {
  readonly body: string;
  readonly retrievedAt: string;
  readonly contentType: string;
}

const defaultFetcher: Fetcher = (url, init) =>
  safeFetch(url, { headers: init.headers, timeoutMs: init.timeoutMs, maxResponseBytes: init.maxResponseBytes, allowedHosts: init.allowedHosts });

export class RegistryTransport {
  private lastRequestMs = -Infinity;
  private readonly hosts: ReadonlySet<string>;
  constructor(private readonly cfg: TransportConfig, private readonly deps: TransportDeps = {}) {
    this.hosts = new Set(cfg.hosts.map((h) => h.toLowerCase()));
  }

  /** GET a server-built URL. `url` must be https on an allowlisted host. */
  async get(url: string): Promise<ImpactResult<FetchedBody>> {
    let u: URL;
    try {
      u = new URL(url);
    } catch {
      return fail('UNSAFE_REFERENCE', 'malformed registry URL');
    }
    if (u.protocol !== 'https:' || u.username || u.password || u.port || !this.hosts.has(u.hostname.toLowerCase())) {
      return fail('UNSAFE_REFERENCE', 'registry URL outside the provider allowlist', { providerId: this.cfg.providerId });
    }
    const now = this.deps.nowMs ?? (() => Date.now());
    const t = now();
    if (t - this.lastRequestMs < this.cfg.minIntervalMs) {
      return fail('REGISTRY_RATE_LIMITED', 'local rate limit for this registry', { providerId: this.cfg.providerId });
    }
    this.lastRequestMs = t;

    let res: Response;
    try {
      res = await (this.deps.fetcher ?? defaultFetcher)(u.toString(), {
        headers: { ...(this.cfg.headers ?? {}), 'Accept': this.cfg.contentTypes.join(', ') },
        timeoutMs: TRANSPORT_LIMITS.timeoutMs,
        maxResponseBytes: this.cfg.maxBytes,
        allowedHosts: this.hosts,
      });
    } catch (e) {
      if (e instanceof UnsafeUrlError) return fail('UNSAFE_REFERENCE', 'registry request blocked by the SSRF guard', { providerId: this.cfg.providerId });
      return fail('REGISTRY_UNAVAILABLE', 'registry unreachable', { providerId: this.cfg.providerId });
    }
    if (res.status === 404) return fail('ORGANIZATION_NOT_FOUND', 'record not found in this registry', { providerId: this.cfg.providerId });
    if (res.status === 429) return fail('REGISTRY_RATE_LIMITED', 'registry rate limit', { providerId: this.cfg.providerId });
    if (res.status === 401 || res.status === 403 || res.status >= 500) {
      return fail('REGISTRY_UNAVAILABLE', 'registry unavailable', { providerId: this.cfg.providerId, status: res.status });
    }
    if (res.status !== 200) return fail('REGISTRY_RESPONSE_INVALID', 'unexpected registry response', { providerId: this.cfg.providerId, status: res.status });
    const ct = (res.headers.get('content-type') ?? '').toLowerCase();
    if (!this.cfg.contentTypes.some((c) => ct.startsWith(c))) {
      await res.body?.cancel();
      return fail('REGISTRY_RESPONSE_INVALID', 'unexpected content type', { providerId: this.cfg.providerId });
    }
    let body: string;
    try {
      body = await res.text();
    } catch {
      // includes the size cap (safe_fetch aborts the stream past maxResponseBytes)
      return fail('REGISTRY_RESPONSE_INVALID', 'registry response too large or truncated', { providerId: this.cfg.providerId });
    }
    if (body.length > this.cfg.maxBytes) return fail('REGISTRY_RESPONSE_INVALID', 'registry response too large', { providerId: this.cfg.providerId });
    return ok({ body, retrievedAt: new Date(t).toISOString(), contentType: ct });
  }

  async getJson(url: string): Promise<ImpactResult<{ readonly json: unknown; readonly retrievedAt: string }>> {
    const r = await this.get(url);
    if (!r.ok) return r;
    try {
      return ok({ json: JSON.parse(r.value.body), retrievedAt: r.value.retrievedAt });
    } catch {
      return fail('REGISTRY_RESPONSE_INVALID', 'malformed JSON', { providerId: this.cfg.providerId });
    }
  }
}
