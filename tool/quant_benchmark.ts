/**
 * Quant performance / memory benchmark — IV-QUANT-REAL-DATA-READINESS-03
 * (docs/quant/QUANT_RESOURCE_BUDGET.md). Local Deno only: this is NOT the
 * Supabase Edge runtime (PLATFORM_RUNTIME_NOT_MEASURED — measuring the real
 * platform requires a deploy, which is out of scope).
 *
 *   deno run --v8-flags=--expose-gc --allow-env tool/quant_benchmark.ts
 *
 * Scenarios at the documented bounds:
 *   A  quant.analyze.v1        — 1 series × 50 000 rows (MAX_BARS_PER_SERIES)
 *   B  quant.analyze.multi.v1  — 10 series × 10k / 5k / 3k rows (bound chosen: MAX_TOTAL_ROWS = 50 000)
 *   C  quant.analyze.watchlist.v1 — 10 instruments × 1 100 days, synthetic provider, cold then warm cache
 * All data is generated here (deterministic); nothing is fetched.
 */
import { parseAnalyzeRequest, runAnalyze } from '../supabase/functions/_shared/quant/api_contract.ts';
import { parseMultiRequest, parseWatchlistAnalysisRequest, runMulti, runWatchlistAnalysis } from '../supabase/functions/_shared/quant/multi_contract.ts';
import { CachingProvider, InMemoryMarketCache } from '../supabase/functions/_shared/quant/market_cache.ts';
import { SyntheticInProcessProvider } from '../supabase/functions/_shared/quant/synthetic_market.ts';
import type { InstrumentIdentity } from '../supabase/functions/_shared/quant/instrument.ts';

const NOW = Date.UTC(2026, 8, 23, 22);
const gc = (globalThis as { gc?: () => void }).gc ?? (() => {});
const mb = (n: number) => Math.round((n / 1048576) * 10) / 10;

function csv(rows: number, seed: number, startYear: number): string {
  let s = seed >>> 0;
  const rand = () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
  const out = ['date,open,high,low,close,volume'];
  let t = Date.UTC(startYear, 0, 1);
  let p = 100;
  while (out.length <= rows) {
    const wd = new Date(t).getUTCDay();
    if (wd !== 0 && wd !== 6) {
      const o = p;
      p = Math.max(0.01, p * Math.exp(0.0002 + 0.012 * (rand() - 0.5) * 3.4));
      out.push(`${new Date(t).toISOString().slice(0, 10)},${o.toFixed(4)},${(Math.max(o, p) * 1.002).toFixed(4)},${(Math.min(o, p) * 0.998).toFixed(4)},${p.toFixed(4)},${1000 + Math.floor(rand() * 9000)}`);
    }
    t += 86_400_000;
  }
  return out.join('\n') + '\n';
}

async function measure(label: string, runs: number, fn: () => Promise<unknown>): Promise<Record<string, unknown>> {
  gc();
  const heap0 = Deno.memoryUsage().heapUsed;
  let peak = heap0;
  const times: number[] = [];
  for (let i = 0; i < runs; i++) {
    const t0 = performance.now();
    const r = await fn();
    times.push(performance.now() - t0);
    peak = Math.max(peak, Deno.memoryUsage().heapUsed);
    if (r && typeof r === 'object' && 'ok' in r && !(r as { ok: boolean }).ok) throw new Error(`${label}: ${JSON.stringify((r as unknown as { error: unknown }).error)}`);
  }
  times.sort((a, b) => a - b);
  gc();
  return {
    scenario: label,
    runs,
    median_ms: Math.round(times[Math.floor(times.length / 2)]),
    max_ms: Math.round(times[times.length - 1]),
    heap_before_mb: mb(heap0),
    heap_peak_mb: mb(peak),
    heap_after_gc_mb: mb(Deno.memoryUsage().heapUsed),
    rss_mb: mb(Deno.memoryUsage().rss),
  };
}

const results: Record<string, unknown>[] = [];

// A — single series at the row bound.
const csvA = csv(50_000, 1, 1830);
const bodyA = { contract_version: 'quant.analyze.v1', instrument: { asset_class: 'EQUITY', symbol: 'BENCHA', exchange_mic: 'XNYS', currency: 'USD' }, dataset: { format: 'csv', frequency: 'DAILY', adjustment: 'SPLIT_AND_DIVIDEND_ADJUSTED', csv: csvA }, options: { periods_per_year: 252, sma_windows: [2, 5, 10, 20, 50, 100, 200, 50_000] } };
const bytesA = new TextEncoder().encode(JSON.stringify(bodyA)).length;
results.push({ ...(await measure('A v1 1×50k rows', 5, () => runAnalyze((parseAnalyzeRequest(JSON.parse(JSON.stringify(bodyA))) as unknown as { value: never }).value, NOW))), body_mb: mb(bytesA) });

// B — multi-series: 10 series at several per-series sizes (total = 10 × size).
for (const perSeries of [10_000, 5_000, 3_000]) {
  const series = Array.from({ length: 10 }, (_, i) => ({
    instrument: { asset_class: 'EQUITY', symbol: `BENCH${i}`, exchange_mic: i % 2 ? 'XNYS' : 'XNAS', currency: 'USD' },
    dataset: { format: 'csv', frequency: 'DAILY', adjustment: 'SPLIT_AND_DIVIDEND_ADJUSTED', csv: csv(perSeries, 100 + i, 2026 - Math.ceil(perSeries / 250) - 1) },
  }));
  const b = { contract_version: 'quant.analyze.multi.v1', series, options: { periods_per_year: 252, weights: series.map((_, i) => ({ index: i, weight: 0.1 })) } };
  const bytes = new TextEncoder().encode(JSON.stringify(b)).length;
  results.push({ ...(await measure(`B multi 10×${perSeries} rows (+portfolio)`, 3, () => runMulti((parseMultiRequest(JSON.parse(JSON.stringify(b))) as unknown as { value: never }).value, NOW))), body_mb: mb(bytes) });
}

// C — watchlist bulk through the cache: cold (every run a fresh cache) then warm.
const instruments: InstrumentIdentity[] = Array.from({ length: 10 }, (_, i) => ({ assetClass: 'EQUITY', symbol: `SYN${i}`, exchangeMic: ['XNYS', 'XNAS', 'XLON'][i % 3], currency: i % 3 === 2 ? 'GBP' : 'USD' }));
const reqC = (parseWatchlistAnalysisRequest({ contract_version: 'quant.analyze.watchlist.v1', watchlist_id: '11111111-1111-4111-8111-111111111111', data_source: 'SYNTHETIC_PROVIDER', lookback_days: 1100, options: { periods_per_year: 252 } }) as unknown as { value: never }).value;
results.push(await measure('C watchlist 10×1100d cold cache', 3, () => runWatchlistAnalysis(instruments, reqC, new CachingProvider(new SyntheticInProcessProvider(() => NOW), new InMemoryMarketCache(64), () => NOW), NOW)));
const warm = new CachingProvider(new SyntheticInProcessProvider(() => NOW), new InMemoryMarketCache(64), () => NOW);
await runWatchlistAnalysis(instruments, reqC, warm, NOW);
results.push(await measure('C watchlist 10×1100d warm cache', 3, () => runWatchlistAnalysis(instruments, reqC, warm, NOW)));

console.log(JSON.stringify({ deno: Deno.version.deno, v8: Deno.version.v8, runtime: 'LOCAL_DENO (PLATFORM_RUNTIME_NOT_MEASURED)', results }, null, 2));
