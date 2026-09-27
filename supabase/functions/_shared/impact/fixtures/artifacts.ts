// IV-IMPACT-I3 — synthetic artifact builders for tests (no real documents are
// committed). Builds minimal but structurally valid ZIP/OOXML and PDF files.

const enc = new TextEncoder();

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
function crc32(b: Uint8Array): number {
  let c = 0xffffffff;
  for (const x of b) c = CRC_TABLE[(c ^ x) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

async function compress(data: Uint8Array, format: 'deflate-raw' | 'deflate'): Promise<Uint8Array> {
  const cs = new CompressionStream(format);
  const w = cs.writable.getWriter();
  w.write(data as Uint8Array<ArrayBuffer>);
  w.close();
  return new Uint8Array(await new Response(cs.readable).arrayBuffer());
}

export interface ZipInput {
  readonly name: string;
  readonly data: Uint8Array | string;
  /** Declared uncompressed size override (zip-bomb / lying header tests). */
  readonly declaredSize?: number;
  readonly flags?: number;
}

export async function makeZip(files: readonly ZipInput[], deflate = true): Promise<Uint8Array> {
  const locals: Uint8Array[] = [];
  const centrals: Uint8Array[] = [];
  let offset = 0;
  for (const f of files) {
    const raw = typeof f.data === 'string' ? enc.encode(f.data) : f.data;
    const body = deflate ? await compress(raw, 'deflate-raw') : raw;
    const name = enc.encode(f.name);
    const crc = crc32(raw);
    const size = f.declaredSize ?? raw.length;
    const lh = new DataView(new ArrayBuffer(30));
    lh.setUint32(0, 0x04034b50, true); lh.setUint16(4, 20, true); lh.setUint16(6, f.flags ?? 0, true);
    lh.setUint16(8, deflate ? 8 : 0, true); lh.setUint32(14, crc, true); lh.setUint32(18, body.length, true);
    lh.setUint32(22, size, true); lh.setUint16(26, name.length, true);
    locals.push(new Uint8Array(lh.buffer), name, body);
    const ch = new DataView(new ArrayBuffer(46));
    ch.setUint32(0, 0x02014b50, true); ch.setUint16(4, 20, true); ch.setUint16(6, 20, true); ch.setUint16(8, f.flags ?? 0, true);
    ch.setUint16(10, deflate ? 8 : 0, true); ch.setUint32(16, crc, true); ch.setUint32(20, body.length, true);
    ch.setUint32(24, size, true); ch.setUint16(28, name.length, true); ch.setUint32(42, offset, true);
    centrals.push(new Uint8Array(ch.buffer), name);
    offset += 30 + name.length + body.length;
  }
  const cd = concat(centrals);
  const eocd = new DataView(new ArrayBuffer(22));
  eocd.setUint32(0, 0x06054b50, true); eocd.setUint16(8, files.length, true); eocd.setUint16(10, files.length, true);
  eocd.setUint32(12, cd.length, true); eocd.setUint32(16, offset, true);
  return concat([...locals, cd, new Uint8Array(eocd.buffer)]);
}

export function concat(parts: readonly Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
}

const xmlEsc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

export const CT_DOCX = `<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>`;
export const CT_XLSX = `<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/></Types>`;

export async function makeDocx(opts: { paragraphs: readonly string[]; heading?: string; tables?: readonly (readonly (readonly string[])[])[]; extra?: readonly ZipInput[]; contentTypes?: string }): Promise<Uint8Array> {
  const p = (t: string, style?: string) => `<w:p>${style ? `<w:pPr><w:pStyle w:val="${style}"/></w:pPr>` : ''}<w:r><w:t xml:space="preserve">${xmlEsc(t)}</w:t></w:r></w:p>`;
  const tbl = (rows: readonly (readonly string[])[]) =>
    `<w:tbl>${rows.map((r) => `<w:tr>${r.map((c) => `<w:tc>${p(c)}</w:tc>`).join('')}</w:tr>`).join('')}</w:tbl>`;
  const body = `${opts.heading ? p(opts.heading, 'Heading1') : ''}${opts.paragraphs.map((t) => p(t)).join('')}${(opts.tables ?? []).map(tbl).join('')}`;
  const doc = `<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>${body}</w:body></w:document>`;
  return await makeZip([{ name: '[Content_Types].xml', data: opts.contentTypes ?? CT_DOCX }, { name: 'word/document.xml', data: doc }, ...(opts.extra ?? [])]);
}

export interface SheetInput {
  readonly name: string;
  /** cell ref → value, or { f: formula, v: cached } */
  readonly cells: Readonly<Record<string, string | number | { f: string; v?: string | number }>>;
}

export async function makeXlsx(sheets: readonly SheetInput[], extra: readonly ZipInput[] = []): Promise<Uint8Array> {
  const shared: string[] = [];
  const files: ZipInput[] = [{ name: '[Content_Types].xml', data: CT_XLSX }];
  const wbSheets = sheets.map((s, i) => `<sheet name="${xmlEsc(s.name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>`).join('');
  files.push({ name: 'xl/workbook.xml', data: `<?xml version="1.0"?><workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${wbSheets}</sheets></workbook>` });
  files.push({ name: 'xl/_rels/workbook.xml.rels', data: `<?xml version="1.0"?><Relationships>${sheets.map((_, i) => `<Relationship Id="rId${i + 1}" Target="worksheets/sheet${i + 1}.xml"/>`).join('')}</Relationships>` });
  sheets.forEach((s, i) => {
    const cells = Object.entries(s.cells).map(([ref, v]) => {
      if (typeof v === 'number') return `<c r="${ref}"><v>${v}</v></c>`;
      if (typeof v === 'string') { shared.push(v); return `<c r="${ref}" t="s"><v>${shared.length - 1}</v></c>`; }
      return `<c r="${ref}"><f>${xmlEsc(v.f)}</f>${v.v !== undefined ? `<v>${v.v}</v>` : ''}</c>`;
    }).join('');
    files.push({ name: `xl/worksheets/sheet${i + 1}.xml`, data: `<?xml version="1.0"?><worksheet><sheetData><row>${cells}</row></sheetData></worksheet>` });
  });
  files.push({ name: 'xl/sharedStrings.xml', data: `<?xml version="1.0"?><sst>${shared.map((t) => `<si><t>${xmlEsc(t)}</t></si>`).join('')}</sst>` });
  return await makeZip([...files, ...extra]);
}

const pdfEsc = (s: string) => s.replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)');

/** Minimal PDF: one text line per page (optionally FlateDecode-compressed, image-only or encrypted). */
export async function makePdf(pages: readonly string[], opts: { compress?: boolean; imageOnly?: boolean; encrypt?: boolean; objectStream?: boolean } = {}): Promise<Uint8Array> {
  const objs: (string | Uint8Array)[] = [];
  const pageRefs: number[] = [];
  const firstPage = 3;
  const add = (o: string | Uint8Array) => { objs.push(o); return objs.length; };
  add('<< /Type /Catalog /Pages 2 0 R >>');
  add(''); // pages placeholder (2)
  for (const text of pages) {
    const content = opts.imageOnly ? 'q 100 0 0 100 0 0 cm /Im1 Do Q' : `BT /F1 12 Tf 72 720 Td (${pdfEsc(text)}) Tj ET`;
    const raw = enc.encode(content);
    const body = opts.compress ? await compress(raw, 'deflate') : raw;
    const header = enc.encode(`<< /Length ${body.length}${opts.compress ? ' /Filter /FlateDecode' : ''} >>\nstream\n`);
    const streamObj = concat([header, body, enc.encode('\nendstream')]);
    const pageNum = objs.length + 1;
    pageRefs.push(pageNum);
    add(`<< /Type /Page /Parent 2 0 R /Contents ${pageNum + 1} 0 R /MediaBox [0 0 612 792] >>`);
    add(streamObj);
  }
  objs[1] = `<< /Type /Pages /Kids [${pageRefs.map((n) => `${n} 0 R`).join(' ')}] /Count ${pageRefs.length} >>`;
  void firstPage;
  const parts: Uint8Array[] = [enc.encode('%PDF-1.7\n%\xE2\xE3\xCF\xD3\n')];
  objs.forEach((o, i) => {
    parts.push(enc.encode(`${i + 1} 0 obj\n`));
    parts.push(typeof o === 'string' ? enc.encode(o) : o);
    parts.push(enc.encode('\nendobj\n'));
  });
  parts.push(enc.encode(`trailer\n<< /Root 1 0 R${opts.encrypt ? ' /Encrypt 99 0 R' : ''} >>\n%%EOF\n`));
  return concat(parts);
}

export const utf8 = (s: string) => enc.encode(s);
