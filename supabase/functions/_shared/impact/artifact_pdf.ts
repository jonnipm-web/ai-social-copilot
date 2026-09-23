/**
 * PDF text-layer extraction with page mapping — IV-IMPACT-I3.
 *
 * A deliberately small, bounded reader (no dependency, nothing executed —
 * no JavaScript, no forms, no embedded files, no external references):
 *   objects (incl. object streams) → catalog → page tree (bounded, cycle-safe)
 *   → each page's content streams (FlateDecode only) → text operators
 *   (Tj, TJ, ', ") with literal / hex strings.
 * Limits: pages, objects, and a shared inflate budget. Known limitation
 * (documented): fonts with custom / CID encodings yield no reliable text →
 * such pages are reported as OCR_REQUIRED, never guessed; encrypted PDFs are
 * FAILED/ENCRYPTED. PDF metadata is never trusted as a fact.
 */
import { ARTIFACT_LIMITS, type Extraction, type Segment } from './artifact_model.ts';
import { finish } from './artifact_extract.ts';
import { InflateBudget, inflateBounded } from './artifact_zip.ts';

const MAX_PAGE_TEXT = 200_000;
const MAX_STREAM = 16 * 1024 * 1024;

interface PdfObject { dict: string; stream?: Uint8Array }

const latin = (b: Uint8Array) => new TextDecoder('latin1').decode(b);

function parseObjects(bytes: Uint8Array, s: string, objs: Map<number, PdfObject>) {
  const re = /(\d{1,7})\s+(\d{1,5})\s+obj\b/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(s)) !== null) {
    if (objs.size >= ARTIFACT_LIMITS.maxPdfObjects) break;
    const num = Number(m[1]);
    const start = m.index + m[0].length;
    const end = s.indexOf('endobj', start);
    if (end < 0) break;
    const body = s.slice(start, end);
    const si = body.search(/\bstream\r?\n/);
    if (si >= 0) {
      const dict = body.slice(0, si);
      const dataStart = start + si + (body[si + 6] === '\r' ? 8 : 7);
      const len = /\/Length\s+(\d+)(?!\s+\d+\s+R)/.exec(dict)?.[1];
      let dataEnd = len ? dataStart + Number(len) : -1;
      if (dataEnd < 0 || dataEnd > end + start || s.slice(dataEnd, dataEnd + 20).search(/endstream/) < 0) {
        dataEnd = s.indexOf('endstream', dataStart);
        if (dataEnd < 0) dataEnd = end;
        while (dataEnd > dataStart && (s[dataEnd - 1] === '\n' || s[dataEnd - 1] === '\r')) dataEnd--;
      }
      objs.set(num, { dict, stream: bytes.subarray(dataStart, Math.max(dataStart, dataEnd)) });
    } else {
      objs.set(num, { dict: body });
    }
    re.lastIndex = end + 6;
  }
}

async function streamData(o: PdfObject, budget: InflateBudget): Promise<Uint8Array | null> {
  if (!o.stream) return null;
  const filter = /\/Filter\s*(\[[^\]]*\]|\/\w+)/.exec(o.dict)?.[1] ?? '';
  const filters = filter.match(/\/\w+/g) ?? [];
  if (filters.length === 0) { budget.take(o.stream.length); return o.stream; }
  if (filters.length === 1 && filters[0] === '/FlateDecode') return await inflateBounded(o.stream, 'deflate', MAX_STREAM, budget);
  return null; // other filters (LZW, DCT, …): not text we can read
}

async function expandObjectStreams(objs: Map<number, PdfObject>, budget: InflateBudget) {
  for (const [, o] of [...objs]) {
    if (!/\/Type\s*\/ObjStm/.test(o.dict)) continue;
    const data = await streamData(o, budget);
    if (!data) continue;
    const n = Number(/\/N\s+(\d+)/.exec(o.dict)?.[1] ?? 0);
    const first = Number(/\/First\s+(\d+)/.exec(o.dict)?.[1] ?? 0);
    const text = latin(data);
    const header = text.slice(0, first).trim().split(/\s+/).map(Number);
    for (let i = 0; i < Math.min(n, header.length / 2) && objs.size < ARTIFACT_LIMITS.maxPdfObjects; i++) {
      const num = header[2 * i];
      const off = first + header[2 * i + 1];
      const next = i + 1 < n ? first + header[2 * i + 3] : text.length;
      if (!objs.has(num) && Number.isFinite(off)) objs.set(num, { dict: text.slice(off, next) });
    }
  }
}

const refs = (s: string) => [...s.matchAll(/(\d{1,7})\s+\d{1,5}\s+R/g)].map((m) => Number(m[1]));

function pageTree(objs: Map<number, PdfObject>): number[] {
  const catalog = [...objs.values()].find((o) => /\/Type\s*\/Catalog\b/.test(o.dict));
  const root = catalog ? /\/Pages\s+(\d+)\s+\d+\s+R/.exec(catalog.dict)?.[1] : undefined;
  const pages: number[] = [];
  const seen = new Set<number>();
  const stack: { n: number; d: number }[] = root ? [{ n: Number(root), d: 0 }] : [];
  while (stack.length) {
    const { n, d } = stack.pop()!;
    if (seen.has(n) || d > 64 || pages.length >= ARTIFACT_LIMITS.maxPdfPages) continue;
    seen.add(n);
    const o = objs.get(n);
    if (!o) continue;
    if (/\/Type\s*\/Pages\b/.test(o.dict)) {
      const kids = /\/Kids\s*\[([^\]]*)\]/.exec(o.dict)?.[1] ?? '';
      const r = refs(kids);
      for (let i = r.length - 1; i >= 0; i--) stack.push({ n: r[i], d: d + 1 });
    } else if (/\/Type\s*\/Page\b/.test(o.dict)) {
      pages.push(n);
    }
  }
  return pages;
}

function decodeLiteral(s: string): string {
  return s.replace(/\\([nrtbf()\\]|[0-7]{1,3}|\r?\n)/g, (_, e: string) => {
    if (e === 'n') return '\n';
    if (e === 'r') return '\r';
    if (e === 't') return '\t';
    if (e === 'b' || e === 'f') return '';
    if (e === '(' || e === ')' || e === '\\') return e;
    if (/^[0-7]+$/.test(e)) return String.fromCharCode(parseInt(e, 8) & 0xff);
    return '';
  });
}

/** Content-stream tokenizer: collects text shown by Tj / TJ / ' / ". */
export function contentText(c: string): string {
  let out = '';
  let i = 0;
  const operands: string[] = [];
  let array: string[] | null = null;
  while (i < c.length && out.length < MAX_PAGE_TEXT) {
    const ch = c[i];
    if (ch === '(') {
      let depth = 1;
      let j = i + 1;
      let buf = '';
      while (j < c.length && depth > 0) {
        const x = c[j];
        if (x === '\\') { buf += x + (c[j + 1] ?? ''); j += 2; continue; }
        if (x === '(') depth++;
        if (x === ')') { depth--; if (depth === 0) break; }
        buf += x;
        j++;
      }
      const str = decodeLiteral(buf);
      (array ?? operands).push(str);
      i = j + 1;
      continue;
    }
    if (ch === '<' && c[i + 1] !== '<') {
      const j = c.indexOf('>', i);
      if (j < 0) break;
      const hex = c.slice(i + 1, j).replace(/\s+/g, '');
      let str = '';
      for (let k = 0; k + 1 < hex.length || k < hex.length; k += 2) str += String.fromCharCode(parseInt((hex.slice(k, k + 2) + '0').slice(0, 2), 16));
      (array ?? operands).push(str);
      i = j + 1;
      continue;
    }
    if (ch === '[') { array = []; i++; continue; }
    if (ch === ']') { if (array) operands.push(array.join('')); array = null; i++; continue; }
    if (ch === '-' && array) {
      // A large negative kerning inside TJ is a word gap.
      const m = /^-(\d{3,})/.exec(c.slice(i, i + 12));
      if (m && Number(m[1]) >= 200) array.push(' ');
      i++;
      continue;
    }
    if (/[A-Za-z'"*]/.test(ch)) {
      const m = /^[A-Za-z'"*]+/.exec(c.slice(i, i + 4))!;
      const op = m[0];
      if (op === 'Tj' || op === 'TJ' || op === "'" || op === '"') {
        if (op === "'" || op === '"') out += '\n';
        out += operands.pop() ?? '';
      } else if (op === 'Td' || op === 'TD' || op === 'T*' || op === 'ET') {
        if (!out.endsWith('\n')) out += '\n';
      }
      operands.length = 0;
      i += op.length;
      continue;
    }
    i++;
  }
  return out.replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').trim();
}

/** Share of plausible text characters (a custom / CID encoding yields garbage). */
function readable(t: string): boolean {
  if (!t) return false;
  const ok = [...t].filter((c) => /[\p{L}\p{N}\p{P}\p{Zs}\n]/u.test(c) && c.charCodeAt(0) >= 0x20 || c === '\n').length;
  return ok / t.length >= 0.85;
}

export async function extractPdf(bytes: Uint8Array): Promise<Extraction> {
  const s = latin(bytes);
  if (/\/Encrypt\s+\d+\s+\d+\s+R|\/Encrypt\s*<</.test(s)) return finish('PDF', 'FAILED', [], ['ENCRYPTED'], { pages: 0 });
  const budget = new InflateBudget();
  const objs = new Map<number, PdfObject>();
  parseObjects(bytes, s, objs);
  await expandObjectStreams(objs, budget);
  const pages = pageTree(objs);
  if (pages.length === 0) return finish('PDF', 'FAILED', [], ['PAGE_TREE_NOT_FOUND'], { pages: 0 });
  const notes: string[] = [];
  if (pages.length >= ARTIFACT_LIMITS.maxPdfPages) notes.push('TRUNCATED_PAGES');
  const segments: Segment[] = [];
  let unreadable = 0;
  for (let p = 0; p < pages.length; p++) {
    const page = objs.get(pages[p])!;
    const contents = /\/Contents\s*(\[[^\]]*\]|\d+\s+\d+\s+R)/.exec(page.dict)?.[1] ?? '';
    let text = '';
    for (const r of refs(contents)) {
      const o = objs.get(r);
      if (!o) continue;
      const data = await streamData(o, budget);
      if (!data) { notes.push('UNSUPPORTED_STREAM_FILTER'); continue; }
      text += `${contentText(latin(data))}\n`;
      if (text.length > MAX_PAGE_TEXT) break;
    }
    text = text.trim();
    if (text && readable(text)) segments.push({ locator: { kind: 'PDF_PAGE', page: p + 1 }, text });
    else unreadable++;
  }
  if (segments.length === 0) return finish('PDF', 'OCR_REQUIRED', [], [...notes, 'TEXT_LAYER_MISSING'], { pages: pages.length });
  if (unreadable > 0) notes.push('PAGES_WITHOUT_TEXT_LAYER');
  return finish('PDF', unreadable > 0 ? 'PARTIAL' : 'SUCCESS', segments, notes, { pages: pages.length });
}
