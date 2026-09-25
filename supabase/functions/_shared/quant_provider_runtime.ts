/**
 * Market-data provider RUNTIME — IV-QUANT-REAL-DATA-READINESS-03
 * (docs/quant/QUANT_REAL_DATA_READINESS.md §3–§4).
 *
 * The only place a Quant provider may perform network I/O:
 *  - outbound only through safeFetch (SSRF-validated, bounded size/time)
 *    with the adapter's exact host allowlist re-checked on every redirect,
 *    so a credential can never follow a redirect to another host;
 *  - the credential comes ONLY from a server secret (Deno.env, name declared
 *    by the adapter), attached as a header — never a URL parameter, never
 *    from Flutter/the client bundle/the repository/a client-readable row,
 *    never logged or returned;
 *  - every failure is normalized to a Quant error code (PROVIDER_TIMEOUT,
 *    PROVIDER_RATE_LIMITED, PROVIDER_UNAVAILABLE, PROVIDER_MALFORMED) —
 *    never an empty-but-successful series.
 * NO real vendor is configured in this repository: no base URL, no key.
 */
import { safeFetch, type SafeFetchOptions, UnsafeUrlError } from './safe_fetch.ts';
import { fail, type QuantResult } from './quant/errors.ts';
import type { InstrumentIdentity } from './quant/instrument.ts';
import type { AdapterSpec } from './quant/provider_adapter.ts';
import type {
  HistoricalBarsRequest,
  MarketDataProvider,
  ProviderCapability,
  ProviderResponse,
  RawQuote,
} from './quant/provider.ts';
import type { RawBarInput } from './quant/timeseries.ts';

export type OutboundFetch = (url: string, options: SafeFetchOptions) => Promise<Response>;

export interface ProviderRuntimeDeps {
  /** Defaults to safeFetch. Tests inject a fake with the same contract. */
  fetchImpl?: OutboundFetch;
  /** Defaults to Deno.env; returns null when unset. */
  readSecret?: (name: string) => string | null;
  clock?: () => number;
}

export class HttpAdapterProvider implements MarketDataProvider {
  readonly id: string;
  readonly capabilities: ReadonlySet<ProviderCapability> = new Set(['HISTORICAL_BARS']);

  constructor(private readonly spec: AdapterSpec, private readonly baseUrl: string, private readonly deps: ProviderRuntimeDeps = {}) {
    this.id = spec.id;
  }

  // deno-lint-ignore require-await
  async lookupInstrument(): Promise<QuantResult<InstrumentIdentity[]>> {
    return fail('PROVIDER_UNAVAILABLE', 'instrument lookup not implemented for this adapter');
  }

  // deno-lint-ignore require-await
  async latestQuote(): Promise<QuantResult<ProviderResponse<RawQuote>>> {
    return fail('PROVIDER_UNAVAILABLE', 'quotes not implemented for this adapter');
  }

  async historicalBars(req: HistoricalBarsRequest): Promise<QuantResult<ProviderResponse<RawBarInput[]>>> {
    const built = this.spec.buildRequest(req, this.baseUrl);
    if (!built.ok) return built;
    const url = new URL(built.value.url);
    const allowed = this.spec.allowedHosts.map((h) => h.toLowerCase());
    if (!allowed.includes(url.hostname.toLowerCase())) return fail('PROVIDER_UNAVAILABLE', 'provider host not allowlisted');
    if (url.search.toLowerCase().includes('key=') || url.search.toLowerCase().includes('token=')) {
      return fail('PROVIDER_UNAVAILABLE', 'credentials must never be sent in the URL');
    }

    const headers: Record<string, string> = { ...built.value.headers };
    if (this.spec.secretEnvName) {
      const secret = (this.deps.readSecret ?? ((n: string) => Deno.env.get(n) ?? null))(this.spec.secretEnvName);
      if (!secret || !this.spec.secretHeader) return fail('PROVIDER_UNAVAILABLE', 'provider credential not configured');
      headers[this.spec.secretHeader] = secret;
    }

    const fetchImpl = this.deps.fetchImpl ?? safeFetch;
    const clock = this.deps.clock ?? (() => Date.now());
    let res: Response;
    try {
      res = await fetchImpl(url.toString(), {
        headers,
        timeoutMs: this.spec.timeoutMs,
        maxResponseBytes: this.spec.maxResponseBytes,
        allowedHosts: allowed,
        // The provider credential never follows a redirect to another origin.
        ...(this.spec.secretHeader ? { credentialHeaders: [this.spec.secretHeader] } : {}),
      });
    } catch (e) {
      if (e instanceof DOMException && e.name === 'AbortError') return fail('PROVIDER_TIMEOUT', 'provider did not answer in time');
      if (e instanceof UnsafeUrlError) return fail('PROVIDER_UNAVAILABLE', 'provider URL refused by the outbound policy');
      return fail('PROVIDER_UNAVAILABLE', 'provider unreachable');
    }
    let body: string;
    try {
      body = await res.text();
    } catch {
      return fail('PROVIDER_MALFORMED', 'provider response unreadable or too large');
    }
    return this.spec.parseResponse(req, res.status, res.headers, body, clock());
  }
}
