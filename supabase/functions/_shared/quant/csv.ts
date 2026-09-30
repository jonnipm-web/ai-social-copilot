/**
 * OHLCV CSV schema validation — IV-QUANT-FOUNDATION-01 (QUANT_DATA_MODEL.md §7).
 *
 * A CSV is UNTRUSTED input. It becomes a PriceSeries only through this
 * parser + normalizeBars(); an arbitrary CSV is never "assumed OHLCV".
 *
 * Accepted schema (header row required, case-insensitive, any order):
 *   required: date|timestamp, open, high, low, close
 *   optional: volume, adj_close|adjusted_close
 * Unknown columns are ignored (UNKNOWN_COLUMNS_IGNORED warning); duplicate
 * or ambiguous columns are rejected.
 *
 * Timestamps: `YYYY-MM-DD` (session date label → 00:00Z) or full ISO 8601
 * with an explicit `Z`/`±HH:MM` offset. Anything ambiguous — `01/02/2024`,
 * a datetime without zone, epoch numbers — is rejected, never guessed.
 * Numbers: plain decimal (optional exponent). Thousands separators, decimal
 * commas, currency symbols, `NaN`, `Infinity` and empty fields are rejected.
 *
 * Limits: MAX_CSV_BYTES (UTF-8 bytes) and MAX_BARS_PER_SERIES data rows,
 * checked BEFORE parsing work scales with input.
 */
import { fail, ok, type QuantResult, type QuantWarning } from './errors.ts';
import type { RawBarInput } from './timeseries.ts';
import { MAX_BARS_PER_SERIES } from './timeseries.ts';

export const MAX_CSV_BYTES = 5 * 1024 * 1024;

const NUMBER_RE = /^[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?$/;
const DATE_ONLY_RE = /^(\d{4})-(\d{2})-(\d{2})$/;
const ISO_WITH_ZONE_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,9})?)?(Z|[+-]\d{2}:\d{2})$/;

type Column = 't' | 'open' | 'high' | 'low' | 'close' | 'volume' | 'adjustedClose';
const HEADER_ALIASES: Record<string, Column> = {
  date: 't',
  timestamp: 't',
  open: 'open',
  high: 'high',
  low: 'low',
  close: 'close',
  volume: 'volume',
  adj_close: 'adjustedClose',
  adjusted_close: 'adjustedClose',
};
const REQUIRED: readonly Column[] = ['t', 'open', 'high', 'low', 'close'];

/** RFC 4180 record splitter (quoted fields, escaped quotes, CRLF/LF). */
function parseRecords(text: string): QuantResult<string[][]> {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let quoted = false;
  let i = 0;
  while (i < text.length) {
    const c = text[i];
    if (quoted) {
      if (c === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i += 2;
          continue;
        }
        quoted = false;
        i++;
        continue;
      }
      field += c;
      i++;
      continue;
    }
    if (c === '"') {
      if (field.length > 0) return fail('INVALID_DATASET', 'quote inside an unquoted field', { record: rows.length + 1 });
      quoted = true;
      i++;
    } else if (c === ',') {
      row.push(field);
      field = '';
      i++;
    } else if (c === '\r' || c === '\n') {
      row.push(field);
      rows.push(row);
      row = [];
      field = '';
      i += c === '\r' && text[i + 1] === '\n' ? 2 : 1;
    } else {
      field += c;
      i++;
    }
  }
  if (quoted) return fail('INVALID_DATASET', 'unterminated quoted field');
  if (field.length > 0 || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  // Blank lines (a single empty field) carry no data.
  return ok(rows.filter((r) => !(r.length === 1 && r[0].trim() === '')));
}

export function parseStrictNumber(s: string): number | null {
  const v = s.trim();
  if (!NUMBER_RE.test(v)) return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

export function parseStrictTimestamp(s: string): number | null {
  const v = s.trim();
  const d = DATE_ONLY_RE.exec(v);
  if (d) {
    const [y, m, day] = [Number(d[1]), Number(d[2]), Number(d[3])];
    const t = Date.UTC(y, m - 1, day);
    const back = new Date(t);
    // Reject impossible dates that Date.UTC would silently roll over (2024-02-30).
    if (back.getUTCFullYear() !== y || back.getUTCMonth() !== m - 1 || back.getUTCDate() !== day) return null;
    return t;
  }
  if (!ISO_WITH_ZONE_RE.test(v)) return null;
  // Same rollover guard for the calendar date part of a full timestamp.
  if (parseStrictTimestamp(v.slice(0, 10)) === null) return null;
  const t = Date.parse(v);
  return Number.isFinite(t) ? t : null;
}

export function parseOhlcvCsv(
  text: string,
  limits: { maxBytes?: number; maxRows?: number } = {},
): QuantResult<{ rows: RawBarInput[]; warnings: QuantWarning[] }> {
  if (typeof text !== 'string') return fail('INVALID_DATASET', 'CSV must be text');
  const maxBytes = limits.maxBytes ?? MAX_CSV_BYTES;
  const maxRows = limits.maxRows ?? MAX_BARS_PER_SERIES;
  // UTF-8 byte length is always >= UTF-16 code-unit length, so this cheap
  // check can only reject inputs that the exact check would also reject.
  if (text.length > maxBytes) return fail('DATASET_TOO_LARGE', 'CSV exceeds byte limit', { maxBytes });
  const bytes = new TextEncoder().encode(text).length;
  if (bytes > maxBytes) return fail('DATASET_TOO_LARGE', 'CSV exceeds byte limit', { bytes, maxBytes });

  const body = text.charCodeAt(0) === 0xfeff ? text.slice(1) : text;
  const parsed = parseRecords(body);
  if (!parsed.ok) return parsed;
  const records = parsed.value;
  if (records.length === 0) return fail('INVALID_DATASET', 'CSV is empty');
  if (records.length - 1 > maxRows) {
    return fail('DATASET_TOO_LARGE', 'CSV has too many data rows', { rows: records.length - 1, maxRows });
  }

  const header = records[0].map((h) => h.trim().toLowerCase());
  const colIndex = new Map<Column, number>();
  const unknown: string[] = [];
  for (let i = 0; i < header.length; i++) {
    const col = HEADER_ALIASES[header[i]];
    if (!col) {
      unknown.push(header[i]);
      continue;
    }
    if (colIndex.has(col)) return fail('INVALID_DATASET', 'duplicate or ambiguous column', { column: header[i] });
    colIndex.set(col, i);
  }
  for (const req of REQUIRED) {
    if (!colIndex.has(req)) return fail('INVALID_DATASET', 'missing required column', { column: req === 't' ? 'date' : req });
  }
  const warnings: QuantWarning[] = [];
  if (unknown.length > 0) {
    warnings.push({ code: 'UNKNOWN_COLUMNS_IGNORED', message: 'columns outside the OHLCV schema were ignored', details: { count: unknown.length } });
  }

  const rows: RawBarInput[] = [];
  for (let r = 1; r < records.length; r++) {
    const rec = records[r];
    // 1-based record number (header = 1); blank lines are not counted.
    const record = r + 1;
    if (rec.length !== header.length) {
      return fail('INVALID_DATASET', 'row has a different number of fields than the header', { record });
    }
    const t = parseStrictTimestamp(rec[colIndex.get('t')!]);
    if (t === null) return fail('INVALID_DATASET', 'invalid or ambiguous timestamp', { record, column: 'date' });
    const num = (col: Column): number | null | undefined => {
      const idx = colIndex.get(col);
      if (idx === undefined) return undefined;
      return parseStrictNumber(rec[idx]);
    };
    const out: Record<string, number> = { t };
    for (const col of ['open', 'high', 'low', 'close', 'volume', 'adjustedClose'] as const) {
      const v = num(col);
      if (v === undefined) continue;
      if (v === null) return fail('INVALID_DATASET', 'invalid or missing number', { record, column: col });
      out[col] = v;
    }
    rows.push(out as unknown as RawBarInput);
  }
  return ok({ rows, warnings });
}
