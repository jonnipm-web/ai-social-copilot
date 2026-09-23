// IV-IMPACT-I3-EVIDENCE-COLLECTION-01 — file-type matrix (§91–§97):
// detection (signature / MIME / extension), bounded extraction, locators,
// fail-safe refusal of unsupported, disguised, archive and macro content.
// Every fixture is SYNTHETIC, built in memory (fixtures/artifacts.ts).
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { detectArtifact, sanitizeFilename } from './artifact_detect.ts';
import { extractArtifact, findSegment } from './artifact_extract.ts';
import { ARTIFACT_LIMITS, type ArtifactLocator, locatorFitsSummary, parseLocator } from './artifact_model.ts';
import { InflateBudget, inflateBounded, readZipIndex, ZipError } from './artifact_zip.ts';
import { concat, CT_DOCX, CT_XLSX, makeDocx, makePdf, makeXlsx, makeZip, utf8 } from './fixtures/artifacts.ts';

async function run(bytes: Uint8Array, filename: string, mime?: string) {
  const d = await detectArtifact(bytes, filename, mime);
  if (!d.ok) return { code: d.error.code } as const;
  const x = await extractArtifact(d.value.type, bytes, d.value.text);
  return { code: 'OK', type: d.value.type, mediaType: d.value.mediaType, x } as const;
}
const seg = (x: Awaited<ReturnType<typeof extractArtifact>>, l: ArtifactLocator) => findSegment(x, l)?.text;

// ── §91 PDF ────────────────────────────────────────────────────────────────

Deno.test('F-PDF-01 text PDF (compressed + plain): pages, page locators, SUCCESS', async () => {
  for (const compress of [true, false]) {
    const r = await run(await makePdf(['Wellspring built 20 wells.', 'Page two text.'], { compress }), 'report.pdf', 'application/pdf');
    assert(r.code === 'OK');
    assertEquals([r.type, r.mediaType, r.x.summary.status, r.x.summary.pages], ['PDF', 'application/pdf', 'SUCCESS', 2]);
    assertEquals(seg(r.x, { kind: 'PDF_PAGE', page: 1 }), 'Wellspring built 20 wells.');
    assertEquals(seg(r.x, { kind: 'PDF_PAGE', page: 2 }), 'Page two text.');
    assertEquals(seg(r.x, { kind: 'PDF_PAGE', page: 3 }), undefined);
  }
});

Deno.test('F-PDF-02 object-stream PDF is read (ObjStm expansion)', async () => {
  const r = await run(await makePdf(['Inside an object stream.'], { compress: true, objectStream: true }), 'o.pdf');
  assert(r.code === 'OK');
  assertEquals([r.x.summary.status, seg(r.x, { kind: 'PDF_PAGE', page: 1 })], ['SUCCESS', 'Inside an object stream.']);
});

Deno.test('F-PDF-03 image-only PDF → OCR_REQUIRED (boundary only; nothing OCRed, no candidates possible)', async () => {
  const r = await run(await makePdf(['x'], { imageOnly: true }), 'scan.pdf');
  assert(r.code === 'OK');
  assertEquals(r.x.summary.status, 'OCR_REQUIRED');
  assert(r.x.summary.notes.includes('TEXT_LAYER_MISSING'));
  assertEquals(r.x.segments.length, 0);
});

Deno.test('F-PDF-04 encrypted PDF → FAILED ENCRYPTED (never decrypted)', async () => {
  const r = await run(await makePdf(['secret'], { encrypt: true }), 'enc.pdf');
  assert(r.code === 'OK');
  assertEquals(r.x.summary.status, 'FAILED');
  assert(r.x.summary.notes.includes('ENCRYPTED'));
});

Deno.test('F-PDF-05 a .pdf that is not a PDF, and a PDF behind a lying MIME, are refused', async () => {
  assertEquals((await run(utf8('hello'), 'fake.pdf')).code, 'FILE_SIGNATURE_INVALID');
  assertEquals((await run(await makePdf(['a']), 'r.pdf', 'text/html')).code, 'FILE_SIGNATURE_INVALID');
  // an executable renamed to .pdf
  assertEquals((await run(concat([utf8('MZ'), new Uint8Array(64)]), 'invoice.pdf')).code, 'FILE_SIGNATURE_INVALID');
});

Deno.test('F-PDF-06 garbage after the header never throws: FAILED / bounded', async () => {
  const r = await run(utf8('%PDF-1.7\n' + '1 0 obj << /Type /Catalog /Pages 9 0 R >> endobj\n'.repeat(50) + '%%EOF'), 'broken.pdf');
  assert(r.code === 'OK');
  assert(['FAILED', 'OCR_REQUIRED'].includes(r.x.summary.status));
});

// ── §92 DOCX ───────────────────────────────────────────────────────────────

Deno.test('F-DOCX-01 paragraphs, headings and table cells get their own locators', async () => {
  const r = await run(await makeDocx({ heading: 'Annual report', paragraphs: ['We built 20 wells.', 'Second paragraph.'], tables: [[['Metric', 'Value'], ['Wells', '20']]] }), 'r.docx');
  assert(r.code === 'OK');
  assertEquals([r.type, r.x.summary.status], ['DOCX', 'SUCCESS']);
  assert(r.x.summary.notes.includes('HEADINGS_PRESENT'));
  assertEquals(seg(r.x, { kind: 'DOCX_TABLE_CELL', table: 1, row: 2, cell: 2 }), '20');
  assert(r.x.segments.some((s) => s.locator.kind === 'DOCX_PARAGRAPH' && s.text === 'We built 20 wells.'));
  assertEquals(r.x.summary.tables, [[2, 2]]);
});

Deno.test('F-DOCX-02 macro-enabled / vbaProject documents are refused, never parsed', async () => {
  const withVba = await makeDocx({ paragraphs: ['x'], extra: [{ name: 'word/vbaProject.bin', data: new Uint8Array([1, 2, 3]) }] });
  assertEquals((await run(withVba, 'm.docx')).code, 'UNSUPPORTED_FILE_TYPE');
  const macroCt = await makeDocx({ paragraphs: ['x'], contentTypes: CT_DOCX.replace('document.main+xml', 'document.macroEnabled.main+xml') });
  assertEquals((await run(macroCt, 'm.docx')).code, 'UNSUPPORTED_FILE_TYPE');
  assertEquals((await run(utf8('anything'), 'm.docm')).code, 'UNSUPPORTED_FILE_TYPE');
});

Deno.test('F-DOCX-03 a zip without the Word main part, or a legacy .doc (OLE2), is refused', async () => {
  assertEquals((await run(await makeZip([{ name: '[Content_Types].xml', data: CT_DOCX }]), 'x.docx')).code, 'FILE_SIGNATURE_INVALID');
  assertEquals((await run(concat([new Uint8Array([0xd0, 0xcf, 0x11, 0xe0]), new Uint8Array(100)]), 'x.docx')).code, 'FILE_SIGNATURE_INVALID');
  assertEquals((await run(utf8('x'), 'x.doc')).code, 'UNSUPPORTED_FILE_TYPE');
});

Deno.test('F-DOCX-04 zip bomb: a part inflating past its limit fails bounded (no memory blow-up)', async () => {
  const bomb = 'A'.repeat(40 * 1024 * 1024); // 40 MB of one letter deflates to a few KB
  const docx = await makeZip([{ name: '[Content_Types].xml', data: CT_DOCX }, { name: 'word/document.xml', data: bomb, declaredSize: 100 }]);
  assert(docx.length < ARTIFACT_LIMITS.maxBytes);
  const r = await run(docx, 'bomb.docx');
  assert(r.code === 'OK' || r.code === 'FILE_SIGNATURE_INVALID');
  if (r.code === 'OK') assertEquals(r.x.summary.status, 'FAILED');
});

// ── §93 XLSX ───────────────────────────────────────────────────────────────

Deno.test('F-XLSX-01 cells by sheet + A1 ref; formulas are text (cached value), never evaluated', async () => {
  const r = await run(await makeXlsx([{ name: 'Data', cells: { A1: 'Wells', B1: 20, B2: { f: 'SUM(B1:B1)', v: 20 }, A3: '=HYPERLINK("http://evil.example","x")' } }]), 'w.xlsx');
  assert(r.code === 'OK');
  assertEquals([r.type, r.x.summary.status], ['XLSX', 'SUCCESS']);
  assertEquals(seg(r.x, { kind: 'SHEET_CELL', sheet: 'Data', cell: 'B1' }), '20');
  const f = findSegment(r.x, { kind: 'SHEET_CELL', sheet: 'Data', cell: 'B2' });
  assertEquals([f?.text, f?.formula], ['20', 'SUM(B1:B1)']);
  assert(r.x.summary.notes.includes('FORMULAS_PRESENT'));
  assertEquals(r.x.summary.sheets?.[0].name, 'Data');
});

Deno.test('F-XLSX-02 macro workbooks and external links are refused', async () => {
  assertEquals((await run(await makeXlsx([{ name: 'S', cells: { A1: 1 } }], [{ name: 'xl/vbaProject.bin', data: new Uint8Array([9]) }]), 'm.xlsx')).code, 'UNSUPPORTED_FILE_TYPE');
  assertEquals((await run(utf8('x'), 'm.xlsm')).code, 'UNSUPPORTED_FILE_TYPE');
  assertEquals((await run(await makeZip([{ name: '[Content_Types].xml', data: CT_XLSX }]), 'x.xlsx')).code, 'FILE_SIGNATURE_INVALID');
});

// ── §94 CSV ────────────────────────────────────────────────────────────────

Deno.test('F-CSV-01 RFC 4180 quoting, delimiter detection, row/column locators', async () => {
  const r = await run(utf8('name;wells\r\n"Wellspring; Water";20\r\n"quoted ""x""";7\r\n'), 'w.csv', 'text/csv');
  assert(r.code === 'OK');
  assertEquals([r.type, r.x.summary.status, r.x.summary.rows, r.x.summary.columns], ['CSV', 'SUCCESS', 3, 2]);
  assertEquals(seg(r.x, { kind: 'CSV_CELL', row: 2, column: 1 }), 'Wellspring; Water');
  assertEquals(seg(r.x, { kind: 'CSV_CELL', row: 3, column: 1 }), 'quoted "x"');
});

Deno.test('F-CSV-02 formula-like cells (CSV injection) are flagged, stored as inert text', async () => {
  const r = await run(utf8('a,b\n=cmd|calc!A1,@SUM(1)\n'), 'i.csv');
  assert(r.code === 'OK');
  assert(r.x.summary.notes.includes('FORMULA_LIKE_CELLS'));
  assertEquals(seg(r.x, { kind: 'CSV_CELL', row: 2, column: 1 }), '=cmd|calc!A1');
});

Deno.test('F-CSV-03 unterminated quote → FAILED MALFORMED_CSV (never a silent partial read)', async () => {
  const r = await run(utf8('a,b\n"open,1\n'), 'bad.csv');
  assert(r.code === 'OK');
  assertEquals(r.x.summary.status, 'FAILED');
  assert(r.x.summary.notes.includes('MALFORMED_CSV'));
});

Deno.test('F-CSV-04 row limit: beyond maxCsvRows the extraction is PARTIAL and says so', async () => {
  const r = await run(utf8('v\n' + '1\n'.repeat(ARTIFACT_LIMITS.maxCsvRows + 5)), 'big.csv');
  assert(r.code === 'OK');
  assertEquals(r.x.summary.status, 'PARTIAL');
  assert(r.x.summary.notes.includes('TRUNCATED_ROWS'));
});

// ── §95 JSON ───────────────────────────────────────────────────────────────

Deno.test('F-JSON-01 JSON Pointer locators with ~0/~1 escaping', async () => {
  const r = await run(utf8('{"report":{"wells":20,"a/b":"slash","t~x":"tilde","list":["x","y"]}}'), 'r.json', 'application/json');
  assert(r.code === 'OK');
  assertEquals(seg(r.x, { kind: 'JSON_POINTER', pointer: '/report/wells' }), '20');
  assertEquals(seg(r.x, { kind: 'JSON_POINTER', pointer: '/report/a~1b' }), 'slash');
  assertEquals(seg(r.x, { kind: 'JSON_POINTER', pointer: '/report/t~0x' }), 'tilde');
  assertEquals(seg(r.x, { kind: 'JSON_POINTER', pointer: '/report/list/1' }), 'y');
});

Deno.test('F-JSON-02 hostile nesting and malformed JSON fail bounded', async () => {
  const deep = await run(utf8('['.repeat(5000) + ']'.repeat(5000)), 'deep.json');
  assert(deep.code === 'OK');
  assertEquals(deep.x.summary.status, 'FAILED');
  assert(deep.x.summary.notes.includes('JSON_TOO_DEEP'));
  const bad = await run(utf8('{"a":'), 'bad.json');
  assert(bad.code === 'OK' && bad.x.summary.status === 'FAILED' && bad.x.summary.notes.includes('MALFORMED_JSON'));
  assertEquals((await run(utf8('hello'), 'x.json')).code, 'FILE_SIGNATURE_INVALID');
});

// ── §96 TXT / MD ───────────────────────────────────────────────────────────

Deno.test('F-TXT-01 line locators (1-based, ranges joined); BOM stripped; Markdown kept as text', async () => {
  const r = await run(concat([new Uint8Array([0xef, 0xbb, 0xbf]), utf8('one\ntwo\r\nthree')]), 'n.txt');
  assert(r.code === 'OK');
  assertEquals([r.x.summary.status, r.x.summary.lines], ['SUCCESS', 3]);
  assertEquals(seg(r.x, { kind: 'TEXT_LINES', lineStart: 1, lineEnd: 1 }), 'one');
  assertEquals(seg(r.x, { kind: 'TEXT_LINES', lineStart: 2, lineEnd: 3 }), 'two\nthree');
  const md = await run(utf8('# Title\n\n<script>alert(1)</script>\n'), 'n.md');
  assert(md.code === 'OK' && md.type === 'MARKDOWN');
  assertEquals(seg(md.x, { kind: 'TEXT_LINES', lineStart: 3, lineEnd: 3 }), '<script>alert(1)</script>'); // inert text, never rendered
});

Deno.test('F-TXT-02 NUL bytes / invalid UTF-8 / binary disguised as text are refused', async () => {
  assertEquals((await run(new Uint8Array([0x61, 0x00, 0x62]), 'x.txt')).code, 'FILE_SIGNATURE_INVALID');
  assertEquals((await run(new Uint8Array([0x61, 0xff, 0xfe, 0x62]), 'x.txt')).code, 'FILE_SIGNATURE_INVALID');
  assertEquals((await run(utf8('#!/bin/sh\nrm -rf /'), 'x.txt')).code, 'FILE_SIGNATURE_INVALID');
  assertEquals((await run(new Uint8Array([0x7f, 0x45, 0x4c, 0x46, 1, 1]), 'x.md')).code, 'FILE_SIGNATURE_INVALID');
});

// ── §97 unsupported / archives / names ─────────────────────────────────────

Deno.test('F-UNS-01 unsupported types and archives are refused (UNSUPPORTED_FILE_TYPE), nothing extracted', async () => {
  for (const name of ['a.exe', 'a.zip', 'a.png', 'a.html', 'a.svg', 'a.js', 'a.rtf', 'a', 'a.docx.exe']) {
    assertEquals((await run(utf8('x'), name)).code, 'UNSUPPORTED_FILE_TYPE', name);
  }
  // a gzip / 7z / rar payload under a text extension is an archive, refused
  assertEquals((await run(new Uint8Array([0x1f, 0x8b, 8, 0]), 'a.csv')).code, 'UNSUPPORTED_FILE_TYPE');
  assertEquals((await run(new Uint8Array([0x37, 0x7a, 0xbc, 0xaf, 0x27, 0x1c]), 'a.txt')).code, 'UNSUPPORTED_FILE_TYPE');
});

Deno.test('F-UNS-02 empty / oversized files', async () => {
  assertEquals((await run(new Uint8Array(0), 'a.txt')).code, 'FILE_SIGNATURE_INVALID');
  assertEquals((await run(new Uint8Array(ARTIFACT_LIMITS.maxBytes + 1).fill(0x61), 'a.txt')).code, 'FILE_TOO_LARGE');
});

Deno.test('F-UNS-03 filenames: paths, control characters, traversal and empty names are sanitized or refused', () => {
  assertEquals(sanitizeFilename('C:\\Users\\victim\\report.pdf'), 'report.pdf');
  assertEquals(sanitizeFilename('../../etc/passwd.txt'), 'passwd.txt');
  assertEquals(sanitizeFilename('..'), null);
  assertEquals(sanitizeFilename(''), null);
  const s = sanitizeFilename('a\u0000b\u202Etxt.exe.pdf');
  // deno-lint-ignore no-control-regex -- asserting control characters are gone
  assert(s === null || !/[\u0000-\u001f\u202e]/.test(s));
});

Deno.test('F-ZIP-01 hostile containers: duplicate names, ZIP64 markers, encrypted parts, inflate budget', async () => {
  const dup = await makeZip([{ name: '[Content_Types].xml', data: CT_DOCX }, { name: 'word/document.xml', data: '<w/>' }, { name: 'word/document.xml', data: '<w/>' }]);
  assertEquals((await run(dup, 'd.docx')).code, 'FILE_SIGNATURE_INVALID');
  let threw = '';
  try {
    readZipIndex(utf8('PK not really a zip'));
  } catch (e) {
    threw = e instanceof ZipError ? e.message : 'other';
  }
  assertEquals(threw, 'ZIP_EOCD_MISSING');
  const enc = await makeZip([{ name: '[Content_Types].xml', data: CT_DOCX }, { name: 'word/document.xml', data: '<w:document/>', flags: 1 }]);
  const r = await run(enc, 'e.docx');
  assert(r.code !== 'OK' || r.x.summary.status === 'FAILED');
  // the shared inflate budget caps the total across parts
  const budget = new InflateBudget(1024);
  const raw = new Uint8Array(await new Response(new Blob([new Uint8Array(4096)]).stream().pipeThrough(new CompressionStream('deflate-raw'))).arrayBuffer());
  let over = '';
  try {
    await inflateBounded(raw, 'deflate-raw', 10_000, budget);
  } catch (e) {
    over = e instanceof ZipError ? e.message : 'other';
  }
  assert(['ZIP_INFLATE_BUDGET_EXCEEDED', 'INFLATE_LIMIT_EXCEEDED'].includes(over));
});

// ── locators ───────────────────────────────────────────────────────────────

Deno.test('F-LOC-01 parseLocator is strict (unknown kinds / extra keys / bad ranges refused)', () => {
  assertEquals(parseLocator({ kind: 'PDF_PAGE', page: 1 }), { kind: 'PDF_PAGE', page: 1 });
  for (const bad of [
    { kind: 'PDF_PAGE', page: 0 }, { kind: 'PDF_PAGE', page: 1, x: 1 }, { kind: 'URL', href: 'http://x' },
    { kind: 'TEXT_LINES', lineStart: 5, lineEnd: 4 }, { kind: 'TEXT_LINES', lineStart: 1, lineEnd: 500 },
    { kind: 'SHEET_CELL', sheet: 'S', cell: 'A0' }, { kind: 'JSON_POINTER', pointer: 'no-slash' }, null, 'PDF_PAGE',
  ]) assertEquals(parseLocator(bad), null, JSON.stringify(bad));
});

Deno.test('F-LOC-02 locatorFitsSummary mirrors the SQL impact_locator_fits vector (E3-18)', () => {
  const txt = { type: 'TEXT', status: 'SUCCESS', extractorVersion: 'impact-extractor/1', lines: 3, segments: 3, notes: [] } as const;
  const xl = { type: 'XLSX', status: 'SUCCESS', extractorVersion: 'impact-extractor/1', sheets: [{ name: 'Data', rows: 10, columns: 2 }], segments: 1, notes: [] } as const;
  const got = [
    locatorFitsSummary({ kind: 'TEXT_LINES', lineStart: 1, lineEnd: 3 }, txt),
    locatorFitsSummary({ kind: 'TEXT_LINES', lineStart: 2, lineEnd: 4 }, txt),
    locatorFitsSummary({ kind: 'PDF_PAGE', page: 1 }, txt),
    locatorFitsSummary({ kind: 'SHEET_CELL', sheet: 'Data', cell: 'B7' }, xl),
    locatorFitsSummary({ kind: 'SHEET_CELL', sheet: 'Data', cell: 'C7' }, xl),
    locatorFitsSummary({ kind: 'SHEET_CELL', sheet: 'Other', cell: 'A1' }, xl),
  ];
  assertEquals(got, [true, false, false, true, false, false]);
});

// ── Codex Gate 1 regressions (I3G1-01..05) ─────────────────────────────────

const ms = async (f: () => Promise<unknown>) => { const t = performance.now(); await f(); return performance.now() - t; };

Deno.test('G1-01 hostile XML is scanned in linear time (unterminated <si>, <c>, < floods)', async () => {
  const n = 1_000_000;
  const docx = await makeZip([{ name: '[Content_Types].xml', data: CT_DOCX }, { name: 'word/document.xml', data: '<'.repeat(n) }]);
  const xlsx = await makeZip([
    { name: '[Content_Types].xml', data: CT_XLSX },
    { name: 'xl/workbook.xml', data: '<workbook><sheets><sheet name="S" r:id="rId1"/></sheets></workbook>' },
    { name: 'xl/_rels/workbook.xml.rels', data: '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>' },
    { name: 'xl/sharedStrings.xml', data: '<sst>' + '<si>'.repeat(n / 4) },
    { name: 'xl/worksheets/sheet1.xml', data: '<worksheet><sheetData>' + '<c r="A1">'.repeat(n / 10) },
  ]);
  for (const [bytes, name] of [[docx, 'flood.docx'], [xlsx, 'flood.xlsx']] as const) {
    let r: Awaited<ReturnType<typeof run>> | undefined;
    const t = await ms(async () => { r = await run(bytes, name); });
    assert(t < 5_000, `${name} took ${t.toFixed(0)} ms`);
    assert(r!.code !== 'OK' || r!.x.summary.status !== 'SUCCESS', `${name} must not claim SUCCESS`);
  }
});

Deno.test('G1-02 anything not read in full is PARTIAL, never SUCCESS', async () => {
  const long = await run(await makePdf(['word '.repeat(50_000)]), 'long.pdf');
  assert(long.code === 'OK');
  assertEquals(long.x.summary.status, 'PARTIAL');
  assert(long.x.summary.notes.includes('TRUNCATED_PAGE_TEXT'));
  const docx = await makeZip([{ name: '[Content_Types].xml', data: CT_DOCX }, { name: 'word/document.xml', data: '<w:document><w:body><w:p><w:r><w:t>Readable text.</w:t></w:r></w:p><w:p unterminated' }]);
  const r = await run(docx, 'cut.docx');
  assert(r.code === 'OK');
  assertEquals(r.x.summary.status, 'PARTIAL');
  assert(r.x.summary.notes.includes('MALFORMED_XML'));
  const many = await makeXlsx([{ name: 'S', cells: { A1: 1 } }], []);
  const sst = await makeZip([
    { name: '[Content_Types].xml', data: CT_XLSX },
    { name: 'xl/workbook.xml', data: '<workbook><sheets><sheet name="S" r:id="rId1"/></sheets></workbook>' },
    { name: 'xl/_rels/workbook.xml.rels', data: '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>' },
    { name: 'xl/sharedStrings.xml', data: '<sst>' + '<si><t>x</t></si>'.repeat(ARTIFACT_LIMITS.maxXlsxCells + 5) + '</sst>' },
    { name: 'xl/worksheets/sheet1.xml', data: '<worksheet><sheetData><row><c r="A1" t="s"><v>0</v></c></row></sheetData></worksheet>' },
  ]);
  void many;
  const x = await run(sst, 'sst.xlsx');
  assert(x.code === 'OK');
  assertEquals(x.x.summary.status, 'PARTIAL');
  assert(x.x.summary.notes.includes('TRUNCATED_SHARED_STRINGS'));
});

Deno.test('G1-03 PDF/ZIP polyglots and OOXML with embedded OLE / ActiveX are refused; printer settings are fine', async () => {
  const pdf = await makePdf(['Visible text.']);
  const zip = await makeZip([{ name: 'payload.txt', data: 'hidden' }]);
  assertEquals((await run(concat([pdf, zip]), 'poly.pdf')).code, 'FILE_SIGNATURE_INVALID');
  const ole = await makeDocx({ paragraphs: ['x'], extra: [{ name: 'word/embeddings/oleObject1.bin', data: new Uint8Array([0xd0, 0xcf, 0x11, 0xe0]) }] });
  assertEquals((await run(ole, 'ole.docx')).code, 'UNSUPPORTED_FILE_TYPE');
  const ax = await makeXlsx([{ name: 'S', cells: { A1: 1 } }], [{ name: 'xl/activeX/activeX1.xml', data: '<ax/>' }]);
  assertEquals((await run(ax, 'ax.xlsx')).code, 'UNSUPPORTED_FILE_TYPE');
  const printer = await makeXlsx([{ name: 'S', cells: { A1: 1 } }], [{ name: 'xl/printerSettings/printerSettings1.bin', data: new Uint8Array([1, 2]) }]);
  assertEquals((await run(printer, 'p.xlsx')).code, 'OK');
});

Deno.test('G1-04 sheet names in the structure index are bounded labels without control / bidi characters', async () => {
  const r = await run(await makeXlsx([{ name: 'Data\u202Egnp.exe' + 'x'.repeat(300), cells: { A1: 1 } }]), 'n.xlsx');
  assert(r.code === 'OK');
  const name = r.x.summary.sheets![0].name;
  assert(name.length <= 100 && !name.includes('\u202E'));
  assertEquals(findSegment(r.x, { kind: 'SHEET_CELL', sheet: name, cell: 'A1' })?.text, '1');
});

Deno.test('F3-01 (Codex I3F-02) quote-aware XML: ">" inside attribute values and single-quoted attributes', async () => {
  const xlsx = await makeZip([
    { name: '[Content_Types].xml', data: CT_XLSX },
    { name: 'xl/workbook.xml', data: `<workbook><sheets><sheet name="A>B" r:id='rId1'/></sheets></workbook>` },
    { name: 'xl/_rels/workbook.xml.rels', data: `<Relationships><Relationship Id='rId1' Target="worksheets/sheet1.xml"/></Relationships>` },
    { name: 'xl/worksheets/sheet1.xml', data: `<worksheet><sheetData><row><c r='B2' t="inlineStr"><is><t>Wells: 20</t></is></c></row></sheetData></worksheet>` },
  ]);
  const r = await run(xlsx, 'q.xlsx');
  assert(r.code === 'OK');
  assertEquals([r.x.summary.status, r.x.summary.sheets?.[0].name], ['SUCCESS', 'A>B']);
  assertEquals(findSegment(r.x, { kind: 'SHEET_CELL', sheet: 'A>B', cell: 'B2' })?.text, 'Wells: 20');
  const unclosed = await makeZip([{ name: '[Content_Types].xml', data: CT_DOCX }, { name: 'word/document.xml', data: '<w:p><w:r><w:t>ok</w:t></w:r></w:p><w:p a="' + 'x'.repeat(500_000) }]);
  const u = await run(unclosed, 'u.docx');
  assert(u.code === 'OK' && u.x.summary.status === 'PARTIAL' && u.x.summary.notes.includes('MALFORMED_XML'));
});
