/**
 * Data layer tests — instrument identity, provenance, freshness,
 * normalization, CSV schema validation. IV-QUANT-FOUNDATION-01.
 *
 * Execução:
 *   deno test --allow-read supabase/functions/_shared/quant/data_test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { createInstrument, instrumentKey, isValidFigi, isValidIsin, requireFoundationSupported } from './instrument.ts';
import { assessFreshness, DEFAULT_FRESHNESS_POLICIES, type DataProvenance, evidenceStrength, validateProvenance } from './provenance.ts';
import { alignOnTimestamps, createPriceSeries, MAX_BARS_PER_SERIES, normalizeBars, type RawBarInput } from './timeseries.ts';
import { MAX_CSV_BYTES, parseOhlcvCsv, parseStrictNumber, parseStrictTimestamp } from './csv.ts';
import { dailyBars, G1_CLOSES, G_START_T, INSTR_A, INSTR_BRL } from './fixtures/golden.ts';
import type { QuantResult } from './errors.ts';

function val<T>(r: QuantResult<T>): T {
  if (!r.ok) throw new Error(`expected ok, got ${r.error.code}: ${r.error.message}`);
  return r.value;
}
function code<T>(r: QuantResult<T>): string {
  assert(!r.ok, 'expected failure');
  return (r as { ok: false; error: { code: string } }).error.code;
}

const DAY = 86_400_000;
const PROV: DataProvenance = {
  providerId: 'user-csv',
  providerKind: 'USER_UPLOAD',
  retrievedAt: '2026-01-12T10:00:00.000Z',
  frequency: 'DAILY',
  currency: 'USD',
  adjustment: 'UNKNOWN',
  trust: 'USER_SUPPLIED',
};

// ------------------------------------------------------------ instrument identity

Deno.test('DT-01 identity is symbol+venue+class+currency, not ticker alone', () => {
  const a = val(createInstrument({ assetClass: 'EQUITY', symbol: 'aapl', exchangeMic: 'xnas', currency: 'usd' }));
  assertEquals([a.symbol, a.exchangeMic, a.currency], ['AAPL', 'XNAS', 'USD']);
  const sameTickerOtherVenue = val(createInstrument({ assetClass: 'EQUITY', symbol: 'AAPL', exchangeMic: 'BVMF', currency: 'BRL' }));
  const sameTickerOtherClass = val(createInstrument({ assetClass: 'ETF', symbol: 'AAPL', exchangeMic: 'XNAS', currency: 'USD' }));
  const keys = new Set([instrumentKey(a), instrumentKey(sameTickerOtherVenue), instrumentKey(sameTickerOtherClass)]);
  assertEquals(keys.size, 3);
  // Provider-specific symbols (e.g. a vendor's '^GSPC') are cross-references, not the canonical symbol.
  const idx = val(createInstrument({ assetClass: 'INDEX', symbol: 'SPX', currency: 'USD', providerIds: { 'vendor-x': '^GSPC' } }));
  assertEquals(instrumentKey(idx), 'INDEX:UNSPECIFIED:SPX:USD');
  assertEquals(code(createInstrument({ assetClass: 'INDEX', symbol: '^GSPC', currency: 'USD' })), 'INVALID_INSTRUMENT');
  assert(val(createInstrument({ assetClass: 'EQUITY', symbol: 'BRK.B', exchangeMic: 'XNYS', currency: 'USD' })));
});
Deno.test('DT-02 ISIN/FIGI optional, but validated with check digits when present', () => {
  assert(isValidIsin('US0378331005') && isValidIsin('BRPETRACNPR6'));
  assert(!isValidIsin('US0378331006') && !isValidIsin('US037833100'));
  assert(isValidFigi('BBG000B9XRY4') && isValidFigi('BBG000BLNNH6'));
  assert(!isValidFigi('BBG000B9XRY5') && !isValidFigi('BBG000B9XRYA'));
  assert(val(createInstrument({ assetClass: 'EQUITY', symbol: 'AAPL', currency: 'USD', isin: 'US0378331005', figi: 'BBG000B9XRY4' })));
  assertEquals(code(createInstrument({ assetClass: 'EQUITY', symbol: 'AAPL', currency: 'USD', isin: 'US0378331006' })), 'INVALID_INSTRUMENT');
  // No identifier beyond symbol/currency is required.
  assert(val(createInstrument({ assetClass: 'EQUITY', symbol: 'TSTA', currency: 'USD' })));
});
Deno.test('DT-03 forged/malformed instruments are rejected', () => {
  // deno-lint-ignore no-explicit-any
  const bad: any[] = [
    { assetClass: 'STOCK', symbol: 'A', currency: 'USD' },
    { assetClass: 'EQUITY', symbol: '', currency: 'USD' },
    { assetClass: 'EQUITY', symbol: 'A B', currency: 'USD' },
    { assetClass: 'EQUITY', symbol: 'A'.repeat(40), currency: 'USD' },
    { assetClass: 'EQUITY', symbol: '<script>', currency: 'USD' },
    { assetClass: 'EQUITY', symbol: 'A', currency: 'US' },
    { assetClass: 'EQUITY', symbol: 'A', currency: 'USD', exchangeMic: 'NASDAQ' },
    { assetClass: 'EQUITY', symbol: 'A', currency: 'USD', providerIds: { 'Bad Key': 'x' } },
    { assetClass: 'EQUITY', symbol: 'A', currency: 'USD', exchangeTimezone: '../etc/passwd' },
  ];
  for (const b of bad) assertEquals(code(createInstrument(b)), 'INVALID_INSTRUMENT', JSON.stringify(b));
});
Deno.test('DT-04 Foundation supports EQUITY/ETF/INDEX only; others → UNSUPPORTED_ASSET_CLASS', () => {
  for (const c of ['EQUITY', 'ETF', 'INDEX'] as const) assert(requireFoundationSupported({ ...INSTR_A, assetClass: c }).ok);
  for (const c of ['FX', 'CRYPTO', 'FIXED_INCOME', 'COMMODITY', 'FUND'] as const) {
    assertEquals(code(requireFoundationSupported({ ...INSTR_A, assetClass: c })), 'UNSUPPORTED_ASSET_CLASS');
  }
});

// ------------------------------------------------------------ provenance + freshness

Deno.test('DT-10 provenance validation: required fields, ISO UTC, trust must match providerKind', () => {
  assert(validateProvenance(PROV).ok);
  assertEquals(code(validateProvenance({ ...PROV, retrievedAt: '2026-01-12 10:00' })), 'INVALID_DATASET');
  assertEquals(code(validateProvenance({ ...PROV, currency: 'usd' })), 'INVALID_DATASET');
  // A user upload cannot claim to be provider-reported.
  assertEquals(code(validateProvenance({ ...PROV, trust: 'PROVIDER_REPORTED' })), 'INVALID_DATASET');
  assertEquals(code(validateProvenance({ ...PROV, providerId: 'Evil Provider' })), 'INVALID_DATASET');
});
Deno.test('DT-11 evidence strength: only fully-sourced provider data is STANDARD', () => {
  assertEquals(evidenceStrength(PROV), 'WEAK');
  const good: DataProvenance = { ...PROV, providerKind: 'EXTERNAL_PROVIDER', trust: 'PROVIDER_REPORTED', adjustment: 'SPLIT_ADJUSTED', sourceAsOf: '2026-01-09T21:00:00.000Z' };
  assertEquals(evidenceStrength(good), 'STANDARD');
  assertEquals(evidenceStrength({ ...good, adjustment: 'UNKNOWN' }), 'WEAK');
  const { sourceAsOf: _drop, ...noAsOf } = good;
  assertEquals(evidenceStrength(noAsOf), 'WEAK');
});
Deno.test('DT-12 freshness states for DAILY: FRESH / DELAYED / STALE / UNKNOWN', () => {
  const p = DEFAULT_FRESHNESS_POLICIES.DAILY;
  const now = Date.UTC(2026, 0, 12, 12);
  assertEquals(assessFreshness(now - 3 * DAY, now, p).state, 'FRESH'); // Friday bar read on Monday
  assertEquals(assessFreshness(now - 5 * DAY, now, p).state, 'DELAYED');
  assertEquals(assessFreshness(now - 30 * DAY, now, p).state, 'STALE');
  assertEquals(assessFreshness(null, now, p).state, 'UNKNOWN');
  // Data from the future (clock/provider error) is never FRESH.
  assertEquals(assessFreshness(now + 3 * DAY, now, p).state, 'UNKNOWN');
  const f = assessFreshness(now - 30 * DAY, now, p);
  assertEquals(f.ageMs, 30 * DAY);
  assertEquals(f.asOf, new Date(now - 30 * DAY).toISOString());
});
Deno.test('DT-13 freshness boundaries are inclusive and deterministic (injected clock)', () => {
  const p = DEFAULT_FRESHNESS_POLICIES.INTRADAY_1M;
  const now = 1_800_000_000_000;
  assertEquals(assessFreshness(now - p.freshMaxMs, now, p).state, 'FRESH');
  assertEquals(assessFreshness(now - p.freshMaxMs - 1, now, p).state, 'DELAYED');
  assertEquals(assessFreshness(now - p.delayedMaxMs, now, p).state, 'DELAYED');
  assertEquals(assessFreshness(now - p.delayedMaxMs - 1, now, p).state, 'STALE');
});

// ------------------------------------------------------------ normalization

Deno.test('DT-20 out-of-order rows are sorted (warning) — sorting does not change the canonical series', () => {
  const bars = dailyBars(G1_CLOSES);
  const shuffled = [bars[3], bars[0], bars[4], bars[2], bars[1]];
  const a = val(normalizeBars(bars, 'DAILY'));
  const b = val(normalizeBars(shuffled, 'DAILY'));
  assertEquals(a.bars, b.bars);
  assertEquals(a.warnings.map((w) => w.code), []);
  assertEquals(b.warnings.map((w) => w.code), ['ROWS_REORDERED']);
});
Deno.test('DT-21 exact duplicates collapse (warning); conflicting duplicates → DATA_QUALITY_ERROR', () => {
  const bars = dailyBars(G1_CLOSES);
  const dup = val(normalizeBars([...bars, bars[2]], 'DAILY'));
  assertEquals(dup.bars.length, 5);
  assert(dup.warnings.some((w) => w.code === 'EXACT_DUPLICATES_COLLAPSED'));
  const conflicting: RawBarInput = { ...bars[2], close: (bars[2].close as number) + 0.5, high: (bars[2].high as number) + 1 };
  assertEquals(code(normalizeBars([...bars, conflicting], 'DAILY')), 'DATA_QUALITY_ERROR');
});
Deno.test('DT-22 missing / invalid values are rejected, never filled', () => {
  const bars = dailyBars(G1_CLOSES);
  const missingClose = { ...bars[1], close: undefined };
  assertEquals(code(normalizeBars([bars[0], missingClose as unknown as RawBarInput], 'DAILY')), 'INVALID_DATASET');
  assertEquals(code(normalizeBars([{ ...bars[0], close: NaN }], 'DAILY')), 'INVALID_DATASET');
  assertEquals(code(normalizeBars([{ ...bars[0], close: 0, low: 0 }], 'DAILY')), 'INVALID_DATASET');
  assertEquals(code(normalizeBars([{ ...bars[0], open: -1 }], 'DAILY')), 'INVALID_DATASET');
  assertEquals(code(normalizeBars([{ ...bars[0], volume: -5 }], 'DAILY')), 'INVALID_DATASET');
  assertEquals(code(normalizeBars([{ ...bars[0], t: '2026-01-05' }], 'DAILY')), 'INVALID_DATASET');
  assertEquals(code(normalizeBars([{ ...bars[0], t: 1.5 }], 'DAILY')), 'INVALID_DATASET');
});
Deno.test('DT-23 OHLC consistency enforced', () => {
  const b = dailyBars([100])[0];
  assertEquals(code(normalizeBars([{ ...b, high: 99 }], 'DAILY')), 'DATA_QUALITY_ERROR');
  assertEquals(code(normalizeBars([{ ...b, low: 101 }], 'DAILY')), 'DATA_QUALITY_ERROR');
});
Deno.test('DT-24 missing dates are reported as gaps, not interpolated', () => {
  const bars = dailyBars(G1_CLOSES);
  const gapped = [bars[0], { ...bars[1], t: G_START_T + 20 * DAY }];
  const r = val(normalizeBars(gapped, 'DAILY'));
  assertEquals(r.bars.length, 2);
  assert(r.warnings.some((w) => w.code === 'TIME_GAPS_DETECTED'));
  // A normal weekend (Fri → Mon) is not a gap.
  assertEquals(val(normalizeBars(dailyBars([1, 2, 3, 4, 5, 6, 7]), 'DAILY')).warnings, []);
});
Deno.test('DT-25 adjustedClose must be on every bar or none', () => {
  const bars = dailyBars(G1_CLOSES);
  assertEquals(code(normalizeBars([{ ...bars[0], adjustedClose: 99 }, bars[1]], 'DAILY')), 'DATA_QUALITY_ERROR');
});
Deno.test('DT-26 oversized input boundary', () => {
  const bars = dailyBars([1, 2, 3]);
  assertEquals(code(normalizeBars(bars, 'DAILY', 2)), 'DATASET_TOO_LARGE');
  assertEquals(MAX_BARS_PER_SERIES, 50_000);
});
Deno.test('DT-27 series currency must match the instrument (no silent currency mix)', () => {
  assertEquals(code(createPriceSeries(INSTR_BRL, PROV, dailyBars(G1_CLOSES))), 'CURRENCY_MISMATCH');
  assertEquals(code(createPriceSeries({ ...INSTR_A, assetClass: 'CRYPTO' }, PROV, dailyBars(G1_CLOSES))), 'UNSUPPORTED_ASSET_CLASS');
  const s = val(createPriceSeries(INSTR_A, PROV, dailyBars(G1_CLOSES)));
  assert(Object.isFrozen(s) && Object.isFrozen(s.bars));
});
Deno.test('DT-28 alignment is an inner join — no forward fill', () => {
  const a = dailyBars([1, 2, 3, 4]);
  const b = [a[0], a[2], a[3]].map((x) => ({ ...x }));
  const pa = val(normalizeBars(a, 'DAILY')).bars, pb = val(normalizeBars(b, 'DAILY')).bars;
  const al = alignOnTimestamps(pa, pb);
  assertEquals(al.ai, [0, 2, 3]);
  assertEquals(al.bi, [0, 1, 2]);
});

// ------------------------------------------------------------ CSV

Deno.test('DT-30 golden CSV fixture parses into the G1 series', async () => {
  const text = await Deno.readTextFile(new URL('./fixtures/golden_g1_daily.csv', import.meta.url));
  const parsed = val(parseOhlcvCsv(text));
  assertEquals(parsed.rows.length, 5);
  assertEquals(parsed.warnings, []);
  const s = val(createPriceSeries(INSTR_A, PROV, parsed.rows));
  assertEquals(s.bars.map((b) => b.close), [...G1_CLOSES]);
  assertEquals(s.bars[0].t, G_START_T);
  assertEquals(s.bars.map((b) => b.adjustedClose), [...G1_CLOSES]);
});
Deno.test('DT-31 headers: case-insensitive, any order, unknown ignored with warning, duplicates rejected, required enforced', () => {
  const ok1 = val(parseOhlcvCsv('Close,LOW,High,Open,Date,notes\n10,9,11,10,2026-01-05,=HYPERLINK(x)\n'));
  assertEquals(ok1.rows[0], { t: G_START_T, open: 10, high: 11, low: 9, close: 10 });
  assertEquals(ok1.warnings.map((w) => w.code), ['UNKNOWN_COLUMNS_IGNORED']);
  assertEquals(code(parseOhlcvCsv('date,open,high,low,close,close\n2026-01-05,1,1,1,1,1\n')), 'INVALID_DATASET');
  assertEquals(code(parseOhlcvCsv('date,timestamp,open,high,low,close\n2026-01-05,2026-01-05,1,1,1,1\n')), 'INVALID_DATASET');
  assertEquals(code(parseOhlcvCsv('date,open,high,low\n2026-01-05,1,1,1\n')), 'INVALID_DATASET');
  assertEquals(code(parseOhlcvCsv('')), 'INVALID_DATASET');
});
Deno.test('DT-32 ambiguous timestamps are rejected, never guessed', () => {
  for (const t of ['01/02/2026', '2026-1-5', '2026-01-05T10:00:00', '1767571200000', '2026-02-30', '2026-13-01', 'yesterday', '2026-01-05T25:00:00Z']) {
    assertEquals(parseStrictTimestamp(t), null, t);
  }
  assertEquals(parseStrictTimestamp('2026-01-05'), G_START_T);
  assertEquals(parseStrictTimestamp('2026-01-05T14:30:00-03:00'), Date.UTC(2026, 0, 5, 17, 30));
  assertEquals(parseStrictTimestamp('2026-01-05T14:30:00Z'), Date.UTC(2026, 0, 5, 14, 30));
});
Deno.test('DT-33 numbers: plain decimals only', () => {
  for (const n of ['1,234.5', '12,5', '$10', 'NaN', 'Infinity', '', ' ', '0x10', '1e400', '--1']) assertEquals(parseStrictNumber(n), null, n);
  assertEquals(parseStrictNumber('108.9'), 108.9);
  assertEquals(parseStrictNumber(' 1e3 '), 1000);
  assertEquals(parseStrictNumber('.5'), 0.5);
});
Deno.test('DT-34 malformed CSV rows are rejected with location', () => {
  const r = parseOhlcvCsv('date,open,high,low,close\n2026-01-05,1,1,1,1\n2026-01-06,1,1,1\n');
  assertEquals(code(r), 'INVALID_DATASET');
  assert(!r.ok && r.error.details?.record === 3);
  assertEquals(code(parseOhlcvCsv('date,open,high,low,close\n2026-01-05,1,1,1,abc\n')), 'INVALID_DATASET');
  assertEquals(code(parseOhlcvCsv('date,open,high,low,close\n2026-01-05,1,1,1,\n')), 'INVALID_DATASET');
  assertEquals(code(parseOhlcvCsv('date,open,high,low,close\n2026-01-05,"1,1,1,1\n')), 'INVALID_DATASET');
  assertEquals(code(parseOhlcvCsv('date,open,high,low,close\n2026-01-05,1"x",1,1,1\n')), 'INVALID_DATASET');
});
Deno.test('DT-35 RFC 4180 quoting, CRLF, BOM and blank lines handled', () => {
  const r = val(parseOhlcvCsv('﻿date,open,high,low,close,label\r\n"2026-01-05","10","11","9","10","a ""quoted"", label"\r\n\r\n'));
  assertEquals(r.rows.length, 1);
  assertEquals(r.rows[0].close, 10);
});
Deno.test('DT-36 CSV size limits (bytes and rows) are enforced before parsing scales', () => {
  assertEquals(code(parseOhlcvCsv('x'.repeat(100), { maxBytes: 50 })), 'DATASET_TOO_LARGE');
  // Multi-byte characters: 30 × "é" = 60 UTF-8 bytes but 30 UTF-16 units.
  assertEquals(code(parseOhlcvCsv('é'.repeat(30), { maxBytes: 50 })), 'DATASET_TOO_LARGE');
  const rows = ['date,open,high,low,close', ...[5, 6, 7].map((d) => `2026-01-0${d},1,1,1,1`)].join('\n');
  assertEquals(code(parseOhlcvCsv(rows, { maxRows: 2 })), 'DATASET_TOO_LARGE');
  assertEquals(MAX_CSV_BYTES, 5 * 1024 * 1024);
});
Deno.test('DT-37 arbitrary non-OHLCV CSV is never accepted as a price series', () => {
  assertEquals(code(parseOhlcvCsv('name,email\nana,a@x.com\n')), 'INVALID_DATASET');
  // Valid shape but inconsistent OHLC is caught by normalization.
  const parsed = val(parseOhlcvCsv('date,open,high,low,close\n2026-01-05,10,9,8,10\n'));
  assertEquals(code(createPriceSeries(INSTR_A, PROV, parsed.rows)), 'DATA_QUALITY_ERROR');
});
