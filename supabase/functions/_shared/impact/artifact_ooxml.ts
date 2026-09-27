/**
 * DOCX / XLSX extraction — IV-IMPACT-I3. Read-only XML scanning of the
 * needed parts only (bounded ZIP reader, linear tokenizer — Codex I3G1-01).
 * Nothing is executed: no macros, no external links, no formula evaluation
 * (the formula EXPRESSION is kept apart from the cached VALUE the file
 * carries). Any truncation or malformed part is reported (PARTIAL), never
 * hidden (Codex I3G1-02).
 */
import { ARTIFACT_LIMITS, columnIndex, type Extraction, type Segment } from './artifact_model.ts';
import { finish } from './artifact_extract.ts';
import { scanXml, xmlAttr } from './artifact_xml.ts';
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
  const scan = scanXml(dec.decode(raw));
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
  let headings = false;
  const flushParagraph = () => {
    if (tblDepth === 0) {
      paragraph++;
      if (text.trim()) segments.push({ locator: { kind: 'DOCX_PARAGRAPH', paragraph }, text: text.trim() });
      text = '';
    } else {
      text += '\n';
    }
  };
  for (const tok of scan.tokens) {
    if (segments.length > ARTIFACT_LIMITS.maxSegments) { notes.push('TRUNCATED_SEGMENTS'); break; }
    if (tok.kind === 'text') { if (inText) text += decodeXmlEntities(tok.text); continue; }
    const { kind, name } = tok;
    if (name === 'w:t') { inText = kind === 'open'; continue; }
    if (kind === 'close' && name !== 'w:p' && name !== 'w:tbl' && name !== 'w:tc') continue;
    switch (name) {
      case 'w:pStyle':
        if (/^Heading/i.test(xmlAttr(tok.attrs, 'w:val') ?? '')) headings = true;
        break;
      case 'w:tab': text += '\t'; break;
      case 'w:br': case 'w:cr': text += '\n'; break;
      case 'w:p': if (kind !== 'open') flushParagraph(); break;
      case 'w:tbl':
        if (kind === 'open') {
          tblDepth++;
          if (tblDepth === 1) { table++; tables.push([]); row = 0; }
        } else if (kind === 'close') {
          tblDepth = Math.max(0, tblDepth - 1);
        }
        break;
      case 'w:tr':
        if (tblDepth === 1 && kind === 'open') { row++; cell = 0; tables[table - 1].push(0); }
        break;
      case 'w:tc':
        if (tblDepth !== 1 || row === 0) break;
        if (kind === 'open') { cell++; tables[table - 1][row - 1] = cell; text = ''; } else if (kind === 'close') {
          if (text.trim()) segments.push({ locator: { kind: 'DOCX_TABLE_CELL', table, row, cell }, text: text.trim() });
          text = '';
        }
        break;
    }
  }
  if (scan.malformed()) notes.push('MALFORMED_XML');
  if (headings) notes.push('HEADINGS_PRESENT');
  return finish('DOCX', segments.length ? 'SUCCESS' : 'FAILED', segments, segments.length ? notes : [...notes, 'EMPTY_TEXT'], { paragraphs: paragraph, tables });
}

function resolveTarget(target: string): string | null {
  const t = target.startsWith('/') ? target.slice(1) : `xl/${target}`;
  return t.split('/').some((x) => x === '..' || x === '') ? null : t;
}

/** Sheet names are structural labels needed by SHEET_CELL locators: bounded, no control/bidi characters. */
function sheetLabel(raw: string): string {
  // deno-lint-ignore no-control-regex -- stripping control characters is the point
  return decodeXmlEntities(raw).replace(/[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u202a-\u202e\u2066-\u2069\ufeff]/g, '').trim().slice(0, 100);
}

export async function extractXlsx(bytes: Uint8Array): Promise<Extraction> {
  const idx = readZipIndex(bytes);
  const budget = new InflateBudget();
  const wb = await readZipEntry(bytes, idx, 'xl/workbook.xml', budget, MAX_PART);
  const rels = await readZipEntry(bytes, idx, 'xl/_rels/workbook.xml.rels', budget, MAX_PART);
  if (!wb || !rels) return finish('XLSX', 'FAILED', [], ['MAIN_PART_MISSING'], { sheets: [] });
  const notes: string[] = [];
  const relMap = new Map<string, string>();
  const relScan = scanXml(dec.decode(rels));
  for (const t of relScan.tokens) {
    if (t.kind === 'text' || t.kind === 'close' || t.name !== 'Relationship') continue;
    const id = xmlAttr(t.attrs, 'Id');
    const target = xmlAttr(t.attrs, 'Target');
    if (id && target && xmlAttr(t.attrs, 'TargetMode') !== 'External') {
      const r = resolveTarget(decodeXmlEntities(target));
      if (r) relMap.set(id, r);
    }
  }
  if (relScan.malformed()) notes.push('MALFORMED_XML');

  const shared: string[] = [];
  const sst = await readZipEntry(bytes, idx, 'xl/sharedStrings.xml', budget, MAX_PART);
  if (sst) {
    const scan = scanXml(dec.decode(sst));
    let cur: string | null = null;
    let inT = false;
    let phonetic = 0;
    for (const t of scan.tokens) {
      if (t.kind === 'text') { if (cur !== null && inT && phonetic === 0) cur += decodeXmlEntities(t.text); continue; }
      if (t.name === 'si') {
        if (t.kind === 'open') cur = '';
        else if (t.kind === 'self') shared.push('');
        else if (cur !== null) { shared.push(cur); cur = null; }
        if (shared.length > ARTIFACT_LIMITS.maxXlsxCells) { notes.push('TRUNCATED_SHARED_STRINGS'); break; }
      } else if (t.name === 't') inT = t.kind === 'open';
      else if (t.name === 'rPh') phonetic += t.kind === 'open' ? 1 : t.kind === 'close' ? -1 : 0;
    }
    if (scan.malformed()) notes.push('MALFORMED_XML');
  }

  const segments: Segment[] = [];
  const sheets: { name: string; rows: number; columns: number }[] = [];
  const declared: { name: string; rid?: string }[] = [];
  const wbScan = scanXml(dec.decode(wb));
  for (const t of wbScan.tokens) {
    if (t.kind === 'text' || t.kind === 'close' || t.name !== 'sheet') continue;
    declared.push({ name: sheetLabel(xmlAttr(t.attrs, 'name') ?? ''), rid: xmlAttr(t.attrs, 'r:id') });
  }
  if (wbScan.malformed()) notes.push('MALFORMED_XML');
  if (declared.length > ARTIFACT_LIMITS.maxXlsxSheets) notes.push('TRUNCATED_SHEETS');
  let cells = 0;
  for (const s of declared.slice(0, ARTIFACT_LIMITS.maxXlsxSheets)) {
    const path = s.rid ? relMap.get(s.rid) : undefined;
    if (!s.name || !path || sheets.some((x) => x.name === s.name)) continue;
    const data = await readZipEntry(bytes, idx, path, budget, MAX_PART);
    if (!data) continue;
    let maxRow = 0;
    let maxCol = 0;
    let c: { attrs: string; f?: string; v?: string; is?: string } | null = null;
    let field: 'f' | 'v' | 'is' | null = null;
    const scan = scanXml(dec.decode(data));
    for (const t of scan.tokens) {
      if (t.kind === 'text') {
        if (c && field) c[field] = (c[field] ?? '') + t.text;
        continue;
      }
      if (t.name === 'c') {
        if (t.kind === 'open') { c = { attrs: t.attrs }; field = null; continue; }
        if (t.kind === 'self' || !c) { c = null; continue; }
        // close: one finished cell
        if (++cells > ARTIFACT_LIMITS.maxXlsxCells) { notes.push('TRUNCATED_CELLS'); break; }
        const ref = /^([A-Z]{1,3})([0-9]{1,7})$/.exec(xmlAttr(c.attrs, 'r') ?? '');
        const type = xmlAttr(c.attrs, 't') ?? 'n';
        const cur = c;
        c = null;
        if (!ref) continue;
        let value: string | undefined;
        if (type === 's' && cur.v !== undefined) value = shared[Number(cur.v.trim())];
        else if (type === 'inlineStr') value = cur.is !== undefined ? decodeXmlEntities(cur.is) : undefined;
        else if (type === 'b' && cur.v !== undefined) value = cur.v.trim() === '1' ? 'TRUE' : 'FALSE';
        else if (cur.v !== undefined) value = decodeXmlEntities(cur.v);
        const formula = cur.f !== undefined ? decodeXmlEntities(cur.f) : undefined;
        if (formula !== undefined) notes.push('FORMULAS_PRESENT');
        if ((value === undefined || value === '') && formula === undefined) continue;
        maxRow = Math.max(maxRow, Number(ref[2]));
        maxCol = Math.max(maxCol, columnIndex(ref[1]));
        // `text` is the CACHED value the file declares (never computed here).
        segments.push({ locator: { kind: 'SHEET_CELL', sheet: s.name, cell: `${ref[1]}${ref[2]}` }, text: value ?? '', ...(formula !== undefined ? { formula } : {}) });
        continue;
      }
      if (!c) continue;
      if (t.name === 'f' || t.name === 'v') {
        if (t.kind === 'open') { field = t.name; c[t.name] = c[t.name] ?? ''; } else { if (t.kind === 'self') c[t.name] = c[t.name] ?? ''; field = null; }
      } else if (t.name === 't') {
        if (t.kind === 'open') { field = 'is'; c.is = c.is ?? ''; } else field = null;
      }
    }
    if (scan.malformed()) notes.push('MALFORMED_XML');
    sheets.push({ name: s.name, rows: maxRow, columns: maxCol });
    if (notes.includes('TRUNCATED_CELLS')) break;
  }
  return finish('XLSX', segments.length ? 'SUCCESS' : 'FAILED', segments, segments.length ? notes : [...notes, 'EMPTY_TEXT'], { sheets });
}
