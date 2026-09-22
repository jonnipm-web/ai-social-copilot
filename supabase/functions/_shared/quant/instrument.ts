/**
 * Instrument identity — IV-QUANT-FOUNDATION-01 (QUANT_DOMAIN_MODEL.md §2).
 *
 * A ticker alone is NOT an identity: "AAPL" on XNAS in USD and a same-named
 * symbol on another venue/currency are different instruments. The canonical
 * key is assetClass + venue (ISO 10383 MIC, or UNSPECIFIED) + symbol +
 * currency. ISIN/FIGI/provider ids are optional cross-references: validated
 * when present, never required, never used as the sole key (one ISIN maps
 * to many listings).
 *
 * Economic series (rates, inflation, GDP...) are NOT instruments — they are
 * not tradable and live in EconomicSeriesIdentity (domain_future.ts).
 */
import { fail, ok, type QuantResult } from './errors.ts';

export type AssetClass =
  | 'EQUITY'
  | 'ETF'
  | 'INDEX'
  | 'FX'
  | 'CRYPTO'
  | 'FIXED_INCOME'
  | 'COMMODITY'
  | 'FUND';

export const ALL_ASSET_CLASSES: readonly AssetClass[] = [
  'EQUITY', 'ETF', 'INDEX', 'FX', 'CRYPTO', 'FIXED_INCOME', 'COMMODITY', 'FUND',
];

/**
 * Asset classes whose price-series analytics are supported by the Foundation.
 * All three are exchange-session, positive-price series where the Foundation
 * calculations (returns on positive prices, calendar-naive daily bars) hold.
 * FX/CRYPTO (24/7 or 24/5 calendars, quote/base currency pairs), FIXED_INCOME
 * (yield/clean-dirty price), COMMODITY (futures rolls) and FUND (NAV
 * frequency) need class-specific rules and are rejected with
 * UNSUPPORTED_ASSET_CLASS until a gate adds them.
 */
export const FOUNDATION_SUPPORTED_ASSET_CLASSES: ReadonlySet<AssetClass> = new Set(['EQUITY', 'ETF', 'INDEX']);

export interface InstrumentIdentity {
  readonly assetClass: AssetClass;
  /** Venue symbol, as listed. Uppercase. */
  readonly symbol: string;
  /** ISO 10383 Market Identifier Code (e.g. XNAS, BVMF). Optional. */
  readonly exchangeMic?: string;
  /** ISO 4217 trading/quote currency. Required: prices are meaningless without it. */
  readonly currency: string;
  /** IANA timezone of the listing venue, when known (e.g. America/New_York). */
  readonly exchangeTimezone?: string;
  readonly isin?: string;
  readonly figi?: string;
  /** Provider-specific ids, keyed by provider id. Never used as the canonical key. */
  readonly providerIds?: Readonly<Record<string, string>>;
}

const SYMBOL_RE = /^[A-Z0-9][A-Z0-9.\-=/]{0,31}$/;
const MIC_RE = /^[A-Z0-9]{4}$/;
const CURRENCY_RE = /^[A-Z]{3}$/;
const ISIN_RE = /^[A-Z]{2}[A-Z0-9]{9}[0-9]$/;
const FIGI_RE = /^[B-DF-HJ-NP-TV-Z0-9]{2}G[B-DF-HJ-NP-TV-Z0-9]{8}[0-9]$/;
const PROVIDER_KEY_RE = /^[a-z0-9][a-z0-9_-]{0,63}$/;
const TZ_RE = /^[A-Za-z_]+(\/[A-Za-z0-9_+\-]+){0,2}$/;

function charValue(c: string): number {
  const code = c.charCodeAt(0);
  if (code >= 48 && code <= 57) return code - 48; // 0-9
  return code - 55; // A=10 ... Z=35
}

/** ISIN check digit (ISO 6166): letters expanded to two digits, Luhn over the result. */
export function isValidIsin(isin: string): boolean {
  if (!ISIN_RE.test(isin)) return false;
  const digits = isin.slice(0, 11).split('').map((c) => String(charValue(c))).join('');
  let sum = 0;
  let double = true; // rightmost digit of the payload is doubled (check digit sits to its right)
  for (let i = digits.length - 1; i >= 0; i--) {
    let d = digits.charCodeAt(i) - 48;
    if (double) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    double = !double;
  }
  return (10 - (sum % 10)) % 10 === Number(isin[11]);
}

/** FIGI check digit (OpenFIGI spec): char values, every 2nd char (1-based even
 * positions) doubled, digits of each product summed, mod-10 complement. */
export function isValidFigi(figi: string): boolean {
  if (!FIGI_RE.test(figi)) return false;
  let sum = 0;
  for (let i = 0; i < 11; i++) {
    let v = charValue(figi[i]);
    if (i % 2 === 1) v *= 2;
    sum += Math.floor(v / 10) + (v % 10);
  }
  return (10 - (sum % 10)) % 10 === Number(figi[11]);
}

/** Validates and canonicalizes (uppercases symbol/currency/MIC). */
export function createInstrument(input: InstrumentIdentity): QuantResult<InstrumentIdentity> {
  if (!input || typeof input !== 'object') return fail('INVALID_INSTRUMENT', 'instrument must be an object');
  if (!ALL_ASSET_CLASSES.includes(input.assetClass)) {
    return fail('INVALID_INSTRUMENT', 'unknown asset class', { field: 'assetClass' });
  }
  const symbol = typeof input.symbol === 'string' ? input.symbol.trim().toUpperCase() : '';
  if (!SYMBOL_RE.test(symbol)) return fail('INVALID_INSTRUMENT', 'invalid symbol', { field: 'symbol' });
  const currency = typeof input.currency === 'string' ? input.currency.trim().toUpperCase() : '';
  if (!CURRENCY_RE.test(currency)) return fail('INVALID_INSTRUMENT', 'currency must be ISO 4217', { field: 'currency' });
  let exchangeMic: string | undefined;
  if (input.exchangeMic !== undefined) {
    exchangeMic = String(input.exchangeMic).trim().toUpperCase();
    if (!MIC_RE.test(exchangeMic)) return fail('INVALID_INSTRUMENT', 'exchangeMic must be ISO 10383', { field: 'exchangeMic' });
  }
  if (input.exchangeTimezone !== undefined && !TZ_RE.test(input.exchangeTimezone)) {
    return fail('INVALID_INSTRUMENT', 'exchangeTimezone must be an IANA zone name', { field: 'exchangeTimezone' });
  }
  if (input.isin !== undefined && !isValidIsin(input.isin)) {
    return fail('INVALID_INSTRUMENT', 'ISIN format or check digit invalid', { field: 'isin' });
  }
  if (input.figi !== undefined && !isValidFigi(input.figi)) {
    return fail('INVALID_INSTRUMENT', 'FIGI format or check digit invalid', { field: 'figi' });
  }
  let providerIds: Record<string, string> | undefined;
  if (input.providerIds !== undefined) {
    providerIds = {};
    for (const [k, v] of Object.entries(input.providerIds)) {
      if (!PROVIDER_KEY_RE.test(k) || typeof v !== 'string' || v.length === 0 || v.length > 128) {
        return fail('INVALID_INSTRUMENT', 'invalid provider id entry', { field: 'providerIds' });
      }
      providerIds[k] = v;
    }
  }
  const out: InstrumentIdentity = {
    assetClass: input.assetClass,
    symbol,
    currency,
    ...(exchangeMic ? { exchangeMic } : {}),
    ...(input.exchangeTimezone ? { exchangeTimezone: input.exchangeTimezone } : {}),
    ...(input.isin ? { isin: input.isin } : {}),
    ...(input.figi ? { figi: input.figi } : {}),
    ...(providerIds ? { providerIds } : {}),
  };
  return ok(Object.freeze(out));
}

/** Canonical identity key. Two instruments are the same listing iff keys match. */
export function instrumentKey(i: InstrumentIdentity): string {
  return `${i.assetClass}:${i.exchangeMic ?? 'UNSPECIFIED'}:${i.symbol}:${i.currency}`;
}

export function requireFoundationSupported(i: InstrumentIdentity): QuantResult<InstrumentIdentity> {
  return FOUNDATION_SUPPORTED_ASSET_CLASSES.has(i.assetClass)
    ? ok(i)
    : fail('UNSUPPORTED_ASSET_CLASS', 'asset class not supported by the Quant Foundation', { assetClass: i.assetClass });
}
