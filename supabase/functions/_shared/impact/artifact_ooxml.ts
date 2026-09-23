/**
 * DOCX / XLSX extraction — IV-IMPACT-I3. Read-only XML scanning of the
 * needed parts only (bounded ZIP reader). Nothing is executed: no macros,
 * no external links, no formula evaluation (the formula EXPRESSION is kept
 * apart from the cached VALUE the file carries).
 */
import { ARTIFACT_LIMITS, columnIndex, type Extraction, type Segment } from './artifact_model.ts';
import { finish } from './artifact_extract.ts';
import { InflateBudget, readZipEntry, readZipIndex } from './artifact_zip.ts';

const MAX_PART = 16 * 1024 * 1024;

export function decodeXmlEntities(s: string): string {
  return s.replace(/&(#x[0-9a-fA-F]{1,6}|#[0-9]{1,7}|amp|lt|gt|quot|apos);/g, (_, e: string) => {
    if (e === 'amp') return '&';
    if (e === 'lt') return '<';
    if (e === 'gt') return '>';
    if (e === 'quot') return '"';
    if (e === 'apos') return "'";
    const cp = e.startsWith('#x') ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
    return cp > 0 && cp <= 0x10ffff && !(cp >= 0xd800 && cp <= 0xdfff) ? String.fromCodePoint(cp) : '';
  });
}

const dec = new TextDecoder('utf-8');

export async function extractDocx(bytes: Uint8Array): Promise<Extraction> {
  const idx = readZipIndex(bytes);
  const budget = new InflateBudget();
  const raw = await readZipEntry(bytes, idx, 'word/document.xml', budget, MAX_PART);
  if (!raw) return finish('DOCX', 'FAILED', [], ['MAIN_PART_MISSING'], { paragraphs: 0, tables: [] });
  const xml = dec.decode(raw);
  const segments: Segment[] = [];
  const tables: number[][] = [];
  const notes: string[] = [];
  let paragraph = 0;
  let tblDepth = 0;
  let table = 0;
  let row = 0;
  let cell = 0;
  let text = '';
  let inText = false;
  // Tag-level scan over the document body (linear, no recursion).
  const re = /<(\/?)w:(p|tbl|tr|tc|t|tab|br|cr)\b[^>]*?(\/?)>|([^<]+)|<[^>]*>/g;
  let m: RegExpExecArray | null;
  const flushParagraph = () => {
    if (tblDepth === 0) {
      paragraph++;
      if (text.trim()) segments.push({ locator: { kind: 'DOCX_PARAGRAPH', paragraph }, text: text.trim() });
      text = '';
    } else {
      text += '\n';
    }
  };
  while ((m = re.exec(xml)) !== null) {
    const [, close, tag, selfClose, chars] = m;
    if (chars !== undefined) { if (inText) text += decodeXmlEntities(chars); continue; }
    if (!tag) continue;
    if (tag === 't') { inText = !close && !selfClose; continue; }
    if (tag === 'tab' && !close) { text += '\t'; continue; }
    if ((tag === 'br' || tag === 'cr') && !close) { text += '\n'; continue; }
    if (tag === 'p' && (close || selfClose)) { flushParagraph(); continue; }
    if (tag === 'tbl') {
      if (!close) {
        tblDepth++;
        if (tblDepth === 1) { table++; tables.push([]); row = 0; }
      } else {
        tblDepth = Math.max(0, tblDepth - 1);
      }
      continue;
    }
    if (tblDepth === 1 && tag === 'tr' && !close) { row++; cell = 0; tables[table - 1].push(0); continue; }
    if (tblDepth === 1 && tag === 'tc') {
      if (!close) { cell++; tables[table - 1][row - 1] = cell; text = ''; } else {
        if (text.trim()) segments.push({ locator: { kind: 'DOCX_TABLE_CELL', table, row, cell }, text: text.trim() });
        text = '';
      }
      continue;
    }
    if (segments.length > ARTIFACT_LIMITS.maxSegments) { notes.push('TRUNCATED_SEGMENTS'); break; }
  }
  if (/<w:pStyle\s+w:val="Heading/i.test(xml)) notes.push('HEADINGS_PRESENT');
  return finish('DOCX', segments.length ? 'SUCCESS' : 'FAILED', segments, segments.length ? notes : [...notes, 'EMPTY_TEXT'], { paragraphs: paragraph, tables });
}

function resolveTarget(target: string): string | null {
  const t = target.startsWith('/') ? target.slice(1) : `xl/${target}`;
  return t.split('/').some((x) => x === '..' || x === '') ? null : t;
}

export async function extractXlsx(bytes: Uint8Array): Promise<Extraction> {
  const idx = readZipIndex(bytes);
  const budget = new InflateBudget();
  const wb = await readZipEntry(bytes, idx, 'xl/workbook.xml', budget, MAX_PART);
  const rels = await readZipEntry(bytes, idx, 'xl/_rels/workbook.xml.rels', budget, MAX_PART);
  if (!wb || !rels) return finish('XLSX', 'FAILED', [], ['MAIN_PART_MISSING'], { sheets: [] });
  const relMap = new Map<string, string>();
  for (const r of dec.decode(rels).matchAll(/<Relationship\b[^>]*>/g)) {
    const id = /\bId="([^"]+)"/.exec(r[0])?.[1];
    const target = /\bTarget="([^"]+)"/.exec(r[0])?.[1];
    if (id && target && !/TargetMode="External"/.test(r[0])) {
      const t = resolveTarget(decodeXmlEntities(target));
      if (t) relMap.set(id, t);
    }
  }
  const shared: string[] = [];
  const sst = await readZipEntry(bytes, idx, 'xl/sharedStrings.xml', budget, MAX_PART);
  if (sst) {
    for (const si of dec.decode(sst).matchAll(/<si\b[^>]*>([\s\S]*?)<\/si>/g)) {
      shared.push([...si[1].matchAll(/<t\b[^>]*>([\s\S]*?)<\/t>/g)].map((t) => decodeXmlEntities(t[1])).join(''));
      if (shared.length > ARTIFACT_LIMITS.maxXlsxCells) break;
    }
  }
  const segments: Segment[] = [];
  const notes: string[] = [];
  const sheets: { name: string; rows: number; columns: number }[] = [];
  let cells = 0;
  const declared = [...dec.decode(wb).matchAll(/<sheet\b[^>]*\/?>/g)];
  if (declared.length > ARTIFACT_LIMITS.maxXlsxSheets) notes.push('TRUNCATED_SHEETS');
  for (const s of declared.slice(0, ARTIFACT_LIMITS.maxXlsxSheets)) {
    const name = decodeXmlEntities(/\bname="([^"]*)"/.exec(s[0])?.[1] ?? '').slice(0, 100);
    const rid = /\br:id="([^"]+)"/.exec(s[0])?.[1];
    const path = rid ? relMap.get(rid) : undefined;
    if (!name || !path) continue;
    const data = await readZipEntry(bytes, idx, path, budget, MAX_PART);
    if (!data) continue;
    let maxRow = 0;
    let maxCol = 0;
    for (const c of dec.decode(data).matchAll(/<c\b([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g)) {
      if (++cells > ARTIFACT_LIMITS.maxXlsxCells) { notes.push('TRUNCATED_CELLS'); break; }
      const ref = /\br="([A-Z]{1,3})([0-9]{1,7})"/.exec(c[1]);
      if (!ref) continue;
      const t = /\bt="([a-zA-Z]+)"/.exec(c[1])?.[1] ?? 'n';
      const body = c[2] ?? '';
      const f = /<f\b[^>]*>([\s\S]*?)<\/f>/.exec(body)?.[1];
      const v = /<v\b[^>]*>([\s\S]*?)<\/v>/.exec(body)?.[1];
      let value: string | undefined;
      if (t === 's' && v !== undefined) value = shared[Number(v)];
      else if (t === 'inlineStr') value = [...body.matchAll(/<t\b[^>]*>([\s\S]*?)<\/t>/g)].map((x) => decodeXmlEntities(x[1])).join('');
      else if (t === 'b' && v !== undefined) value = v === '1' ? 'TRUE' : 'FALSE';
      else if (v !== undefined) value = decodeXmlEntities(v);
      const formula = f !== undefined ? decodeXmlEntities(f) : undefined;
      if (formula !== undefined) notes.push('FORMULAS_PRESENT');
      if ((value === undefined || value === '') && formula === undefined) continue;
      maxRow = Math.max(maxRow, Number(ref[2]));
      maxCol = Math.max(maxCol, columnIndex(ref[1]));
      // `text` is the CACHED value the file declares (never computed here).
      segments.push({ locator: { kind: 'SHEET_CELL', sheet: name, cell: `${ref[1]}${ref[2]}` }, text: value ?? '', ...(formula !== undefined ? { formula } : {}) });
    }
    sheets.push({ name, rows: maxRow, columns: maxCol });
    if (notes.includes('TRUNCATED_CELLS')) break;
  }
  return finish('XLSX', segments.length ? 'SUCCESS' : 'FAILED', segments, segments.length ? notes : [...notes, 'EMPTY_TEXT'], { sheets });
}
