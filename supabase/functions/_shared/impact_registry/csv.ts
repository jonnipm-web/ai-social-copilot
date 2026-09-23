/**
 * Minimal RFC 4180 single-line CSV parser (IV-IMPACT-I2). Linear time, no
 * regex backtracking; a quote error rejects the line instead of guessing.
 */
import { fail, ok, type ImpactResult } from '../impact/errors.ts';

export const CSV_MAX_LINE = 10_000;

export function parseCsvLine(line: string): ImpactResult<string[]> {
  if (line.length > CSV_MAX_LINE) return fail('REGISTRY_RESPONSE_INVALID', 'CSV line too long');
  const out: string[] = [];
  let cur = '';
  let quoted = false;
  let i = 0;
  let fieldStart = true;
  while (i < line.length) {
    const c = line[i];
    if (quoted) {
      if (c === '"') {
        if (line[i + 1] === '"') { cur += '"'; i += 2; continue; }
        quoted = false;
        i++;
        if (i < line.length && line[i] !== ',') return fail('REGISTRY_RESPONSE_INVALID', 'malformed CSV quote');
        continue;
      }
      cur += c;
      i++;
      continue;
    }
    if (c === '"' && fieldStart) { quoted = true; fieldStart = false; i++; continue; }
    if (c === '"') return fail('REGISTRY_RESPONSE_INVALID', 'stray CSV quote');
    if (c === ',') { out.push(cur); cur = ''; fieldStart = true; i++; continue; }
    cur += c;
    fieldStart = false;
    i++;
  }
  if (quoted) return fail('REGISTRY_RESPONSE_INVALID', 'unterminated CSV quote');
  out.push(cur);
  return ok(out);
}
