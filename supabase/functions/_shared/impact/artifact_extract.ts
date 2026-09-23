/**
 * Bounded extraction — IV-IMPACT-I3. The extracted representation is kept
 * SEPARATE from the original (which is only hashed) and is addressable by
 * locators. Extraction can fail without invalidating the artifact; a failure
 * is never a signal about an organization. Nothing is executed or evaluated
 * (spreadsheet formulas are recorded, not computed).
 */
import {
  ARTIFACT_LIMITS,
  type ArtifactType,
  type Extraction,
  type ExtractionStatus,
  EXTRACTOR_VERSION,
  locatorKey,
  type Segment,
} from './artifact_model.ts';
import { extractPdf } from './artifact_pdf.ts';
import { extractDocx, extractXlsx } from './artifact_ooxml.ts';

export function finish(type: ArtifactType, status: ExtractionStatus, segments: Segment[], notes: string[], extra: Record<string, unknown> = {}): Extraction {
  const bounded = segments.slice(0, ARTIFACT_LIMITS.maxSegments);
  if (segments.length > bounded.length) notes.push('TRUNCATED_SEGMENTS');
  return Object.freeze({
    summary: Object.freeze({
      type, status: status === 'SUCCESS' && notes.some((n) => n.startsWith('TRUNCATED')) ? 'PARTIAL' : status,
      extractorVersion: EXTRACTOR_VERSION, segments: bounded.length, notes: Object.freeze([...new Set(notes)].sort()), ...extra,
    }),
    segments: Object.freeze(bounded),
  }) as Extraction;
}

function extractText(type: 'TEXT' | 'MARKDOWN', text: string): Extraction {
  const all = text.split(/\r\n|\r|\n/);
  const notes: string[] = [];
  const lines = all.slice(0, ARTIFACT_LIMITS.maxTextLines);
  if (all.length > lines.length) notes.push('TRUNCATED_LINES');
  const segments: Segment[] = lines.map((t, i) => ({ locator: { kind: 'TEXT_LINES', lineStart: i + 1, lineEnd: i + 1 }, text: t }));
  return finish(type, lines.some((l) => l.trim()) ? 'SUCCESS' : 'FAILED', segments, lines.some((l) => l.trim()) ? notes : [...notes, 'EMPTY_TEXT'], { lines: lines.length });
}

/** RFC 4180 state machine with delimiter detection (',' ';' '\t'). */
function extractCsv(text: string): Extraction {
  const first = text.slice(0, 4096).split(/\r?\n/)[0] ?? '';
  const count = (d: string) => first.split(d).length;
  const delim = [',', ';', '\t'].reduce((a, b) => (count(b) > count(a) ? b : a), ',');
  const rows: string[][] = [];
  const notes: string[] = [];
  let row: string[] = [];
  let cur = '';
  let quoted = false;
  let i = 0;
  let malformed = false;
  const push = () => { row.push(cur); cur = ''; };
  while (i < text.length) {
    const c = text[i];
    if (quoted) {
      if (c === '"') {
        if (text[i + 1] === '"') { cur += '"'; i += 2; continue; }
        quoted = false; i++; continue;
      }
      cur += c; i++; continue;
    }
    if (c === '"' && cur === '') { quoted = true; i++; continue; }
    if (c === delim) { push(); i++; continue; }
    if (c === '\r' || c === '\n') {
      push();
      rows.push(row);
      row = [];
      if (rows.length >= ARTIFACT_LIMITS.maxCsvRows) { notes.push('TRUNCATED_ROWS'); break; }
      i += c === '\r' && text[i + 1] === '\n' ? 2 : 1;
      continue;
    }
    cur += c; i++;
  }
  if (quoted) malformed = true;
  if (!notes.includes('TRUNCATED_ROWS') && (cur !== '' || row.length)) { push(); rows.push(row); }
  if (malformed) return finish('CSV', 'FAILED', [], ['MALFORMED_CSV'], { rows: 0, columns: 0 });
  const segments: Segment[] = [];
  let columns = 0;
  rows.forEach((r, ri) => {
    if (r.length > ARTIFACT_LIMITS.maxCsvColumns) notes.push('TRUNCATED_COLUMNS');
    const cells = r.slice(0, ARTIFACT_LIMITS.maxCsvColumns);
    columns = Math.max(columns, cells.length);
    cells.forEach((v, ci) => {
      if (v.trim() === '') return;
      // Formula-like cells are data here; flagged so no future export re-enables them.
      if (/^[=+\-@]/.test(v) && !/^[+-]?\d/.test(v)) notes.push('FORMULA_LIKE_CELLS');
      segments.push({ locator: { kind: 'CSV_CELL', row: ri + 1, column: ci + 1 }, text: v });
    });
  });
  return finish('CSV', segments.length ? 'SUCCESS' : 'FAILED', segments, segments.length ? notes : [...notes, 'EMPTY_TEXT'], { rows: rows.length, columns });
}

const escapePointer = (k: string) => k.replace(/~/g, '~0').replace(/\//g, '~1');

function extractJson(text: string): Extraction {
  let root: unknown;
  try {
    root = JSON.parse(text);
  } catch {
    return finish('JSON', 'FAILED', [], ['MALFORMED_JSON'], { jsonNodes: 0 });
  }
  const segments: Segment[] = [];
  const notes: string[] = [];
  let nodes = 0;
  // Iterative walk (no recursion): depth and node count bounded.
  const stack: { v: unknown; p: string; d: number }[] = [{ v: root, p: '', d: 0 }];
  while (stack.length) {
    const { v, p, d } = stack.pop()!;
    if (++nodes > ARTIFACT_LIMITS.maxJsonNodes) { notes.push('TRUNCATED_NODES'); break; }
    if (d > ARTIFACT_LIMITS.maxJsonDepth) return finish('JSON', 'FAILED', [], ['JSON_TOO_DEEP'], { jsonNodes: 0 });
    if (v !== null && typeof v === 'object') {
      const entries = Array.isArray(v) ? v.map((x, i) => [String(i), x] as const) : Object.entries(v as Record<string, unknown>);
      for (let i = entries.length - 1; i >= 0; i--) stack.push({ v: entries[i][1], p: `${p}/${escapePointer(entries[i][0])}`, d: d + 1 });
    } else {
      segments.push({ locator: { kind: 'JSON_POINTER', pointer: p }, text: v === null ? 'null' : String(v) });
    }
  }
  return finish('JSON', segments.length ? 'SUCCESS' : 'FAILED', segments, segments.length ? notes : [...notes, 'EMPTY_TEXT'], { jsonNodes: Math.min(nodes, ARTIFACT_LIMITS.maxJsonNodes) });
}

/** Dispatcher. `text` is the decoded text for text-based types (artifact_detect.ts). */
export async function extractArtifact(type: ArtifactType, bytes: Uint8Array, text?: string): Promise<Extraction> {
  try {
    switch (type) {
      case 'TEXT':
      case 'MARKDOWN': return extractText(type, text ?? '');
      case 'CSV': return extractCsv(text ?? '');
      case 'JSON': return extractJson(text ?? '');
      case 'PDF': return await extractPdf(bytes);
      case 'DOCX': return await extractDocx(bytes);
      case 'XLSX': return await extractXlsx(bytes);
    }
  } catch {
    // Parser failure is an operational state of this artifact, nothing more.
    return finish(type, 'FAILED', [], ['EXTRACTOR_ERROR']);
  }
}

/** Finds the segment a locator addresses (TEXT_LINES ranges are joined). */
export function findSegment(x: Extraction, l: import('./artifact_model.ts').ArtifactLocator): Segment | null {
  if (l.kind === 'TEXT_LINES') {
    if (l.lineEnd > (x.summary.lines ?? 0)) return null;
    const parts = x.segments.slice(l.lineStart - 1, l.lineEnd);
    const text = parts.map((s) => s.text).join('\n');
    return text.trim() ? { locator: l, text } : null;
  }
  const key = locatorKey(l);
  return x.segments.find((s) => locatorKey(s.locator) === key) ?? null;
}
