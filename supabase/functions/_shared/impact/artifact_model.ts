/**
 * Evidence artifact model — IV-IMPACT-I3-EVIDENCE-COLLECTION-01.
 *
 * An ARTIFACT is the original material an analyst attaches to an
 * investigation (a PDF, a spreadsheet, …). Pure: no network, no clock, no
 * LLM. Principles (docs/impact/IMPACT_ARTIFACT_MODEL.md):
 *  - a file is not evidence because it was uploaded; an extracted sentence is
 *    not a fact; a hash proves integrity, not truth; a locator proves WHERE,
 *    not that it is true;
 *  - the SERVER computes the file hash from the bytes it received; a client
 *    hash is never trusted;
 *  - the original bytes are NOT retained (minimization): the artifact keeps
 *    its hash, a content-free structure index (pages, sheets, rows…) and the
 *    excerpts of its evidence candidates only. More candidates later require
 *    re-attaching the same file, verified by hash;
 *  - every locator is bound to the artifact hash it was taken from.
 */

export const ARTIFACT_POLICY_VERSION = 'impact-artifact/1';
export const EXTRACTOR_VERSION = 'impact-extractor/1';

export type ArtifactType = 'PDF' | 'DOCX' | 'XLSX' | 'CSV' | 'JSON' | 'TEXT' | 'MARKDOWN';
export const ARTIFACT_TYPES: readonly ArtifactType[] = ['PDF', 'DOCX', 'XLSX', 'CSV', 'JSON', 'TEXT', 'MARKDOWN'];

/** How the bytes reached the Lab. Never an authority by itself. */
export type ArtifactOrigin = 'USER_UPLOAD' | 'CLOUD_IMPORT';
/** Cloud storage the client downloaded from (declared, not verified): the host
 * is never the source of the information. */
export type CloudProvider = 'GOOGLE_DRIVE' | 'DROPBOX' | 'ONEDRIVE' | 'BOX' | 'SHAREPOINT';
export const CLOUD_PROVIDERS: readonly CloudProvider[] = ['GOOGLE_DRIVE', 'DROPBOX', 'ONEDRIVE', 'BOX', 'SHAREPOINT'];

export type ExtractionStatus = 'SUCCESS' | 'PARTIAL' | 'FAILED' | 'UNSUPPORTED' | 'OCR_REQUIRED';

/**
 * Limits (rationale in IMPACT_FILE_SECURITY.md): 6 MB matches the existing
 * process-file ceiling (8 MB base64) — mobile uploads, Edge Function memory;
 * every parser is bounded by pages/rows/cells/depth and by a TOTAL inflated
 * byte budget so compressed containers cannot expand without limit.
 */
export const ARTIFACT_LIMITS = Object.freeze({
  maxBytes: 6 * 1024 * 1024,
  maxInflatedBytes: 32 * 1024 * 1024, //   total decompressed per artifact
  maxZipEntries: 2_000,
  maxPdfPages: 500,
  maxPdfObjects: 50_000,
  maxCsvRows: 50_000,
  maxCsvColumns: 200,
  maxXlsxSheets: 20,
  maxXlsxCells: 200_000,
  maxJsonDepth: 64,
  maxJsonNodes: 100_000,
  maxTextLines: 200_000,
  maxSegments: 250_000,
  maxExcerptChars: 1_000,
  maxQuoteChars: 1_000,
  maxCandidatesPerArtifact: 50,
  maxCandidatesPerRequest: 20,
  maxArtifactsPerInvestigation: 100,
  maxCandidatesPerInvestigation: 2_000,
});

export type ArtifactLocator =
  | { readonly kind: 'PDF_PAGE'; readonly page: number }
  | { readonly kind: 'DOCX_PARAGRAPH'; readonly paragraph: number }
  | { readonly kind: 'DOCX_TABLE_CELL'; readonly table: number; readonly row: number; readonly cell: number }
  | { readonly kind: 'SHEET_CELL'; readonly sheet: string; readonly cell: string }
  | { readonly kind: 'CSV_CELL'; readonly row: number; readonly column: number }
  | { readonly kind: 'JSON_POINTER'; readonly pointer: string }
  | { readonly kind: 'TEXT_LINES'; readonly lineStart: number; readonly lineEnd: number };

export type LocatorKind = ArtifactLocator['kind'];

/** One addressable unit of extracted content (never persisted as a whole). */
export interface Segment {
  readonly locator: ArtifactLocator;
  readonly text: string;
  /** Spreadsheet formula EXPRESSION, never evaluated (text holds the cached value). */
  readonly formula?: string;
}

/** Content-free structure index, persisted to validate locators later. */
export interface ExtractionSummary {
  readonly type: ArtifactType;
  readonly status: ExtractionStatus;
  readonly extractorVersion: string;
  readonly pages?: number;
  readonly paragraphs?: number;
  readonly tables?: readonly (readonly number[])[]; // per table: cells per row
  readonly sheets?: readonly { readonly name: string; readonly rows: number; readonly columns: number }[];
  readonly rows?: number;
  readonly columns?: number;
  readonly lines?: number;
  readonly jsonNodes?: number;
  readonly segments: number;
  /** Codes only (e.g. ENCRYPTED, TEXT_LAYER_MISSING, FORMULAS_PRESENT, TRUNCATED_ROWS). */
  readonly notes: readonly string[];
}

export interface Extraction {
  readonly summary: ExtractionSummary;
  readonly segments: readonly Segment[];
}

export function locatorKey(l: ArtifactLocator): string {
  switch (l.kind) {
    case 'PDF_PAGE': return `pdf:p${l.page}`;
    case 'DOCX_PARAGRAPH': return `docx:p${l.paragraph}`;
    case 'DOCX_TABLE_CELL': return `docx:t${l.table}r${l.row}c${l.cell}`;
    case 'SHEET_CELL': return `xlsx:${l.sheet}!${l.cell}`;
    case 'CSV_CELL': return `csv:r${l.row}c${l.column}`;
    case 'JSON_POINTER': return `json:${l.pointer}`;
    case 'TEXT_LINES': return `text:l${l.lineStart}-${l.lineEnd}`;
  }
}

const CELL_RE = /^[A-Z]{1,3}[1-9][0-9]{0,6}$/;
const POS_INT = (n: unknown, max: number) => Number.isInteger(n) && (n as number) >= 1 && (n as number) <= max;

/** Parses a locator from untrusted input (strict, unknown fields rejected). */
export function parseLocator(v: unknown): ArtifactLocator | null {
  if (typeof v !== 'object' || v === null || Array.isArray(v)) return null;
  const o = v as Record<string, unknown>;
  const keys = Object.keys(o);
  const only = (...k: string[]) => keys.every((x) => x === 'kind' || k.includes(x)) && k.every((x) => x in o);
  switch (o.kind) {
    case 'PDF_PAGE': return only('page') && POS_INT(o.page, 100_000) ? { kind: 'PDF_PAGE', page: o.page as number } : null;
    case 'DOCX_PARAGRAPH': return only('paragraph') && POS_INT(o.paragraph, 10_000_000) ? { kind: 'DOCX_PARAGRAPH', paragraph: o.paragraph as number } : null;
    case 'DOCX_TABLE_CELL':
      return only('table', 'row', 'cell') && POS_INT(o.table, 100_000) && POS_INT(o.row, 10_000_000) && POS_INT(o.cell, 100_000)
        ? { kind: 'DOCX_TABLE_CELL', table: o.table as number, row: o.row as number, cell: o.cell as number } : null;
    case 'SHEET_CELL':
      return only('sheet', 'cell') && typeof o.sheet === 'string' && o.sheet.length >= 1 && o.sheet.length <= 100 && typeof o.cell === 'string' && CELL_RE.test(o.cell)
        ? { kind: 'SHEET_CELL', sheet: o.sheet, cell: o.cell } : null;
    case 'CSV_CELL':
      return only('row', 'column') && POS_INT(o.row, 10_000_000) && POS_INT(o.column, 100_000) ? { kind: 'CSV_CELL', row: o.row as number, column: o.column as number } : null;
    case 'JSON_POINTER':
      return only('pointer') && typeof o.pointer === 'string' && o.pointer.length <= 500 && (o.pointer === '' || o.pointer.startsWith('/'))
        ? { kind: 'JSON_POINTER', pointer: o.pointer } : null;
    case 'TEXT_LINES':
      return only('lineStart', 'lineEnd') && POS_INT(o.lineStart, 10_000_000) && POS_INT(o.lineEnd, 10_000_000) && (o.lineEnd as number) >= (o.lineStart as number)
        && (o.lineEnd as number) - (o.lineStart as number) < 200
        ? { kind: 'TEXT_LINES', lineStart: o.lineStart as number, lineEnd: o.lineEnd as number } : null;
    default:
      return null;
  }
}

/** Column letters → 1-based index (A=1). */
export function columnIndex(letters: string): number {
  let n = 0;
  for (const ch of letters) n = n * 26 + (ch.charCodeAt(0) - 64);
  return n;
}

/**
 * Structural validity of a locator against the persisted summary (the same
 * check the database repeats). Content validity is checked at ingestion,
 * against the actual extraction.
 */
export function locatorFitsSummary(l: ArtifactLocator, s: ExtractionSummary): boolean {
  switch (l.kind) {
    case 'PDF_PAGE': return s.type === 'PDF' && l.page <= (s.pages ?? 0);
    case 'DOCX_PARAGRAPH': return s.type === 'DOCX' && l.paragraph <= (s.paragraphs ?? 0);
    case 'DOCX_TABLE_CELL': {
      const t = s.tables?.[l.table - 1];
      return s.type === 'DOCX' && !!t && l.row <= t.length && l.cell <= t[l.row - 1];
    }
    case 'SHEET_CELL': {
      const sh = s.sheets?.find((x) => x.name === l.sheet);
      const m = /^([A-Z]+)(\d+)$/.exec(l.cell)!;
      return s.type === 'XLSX' && !!sh && Number(m[2]) <= sh.rows && columnIndex(m[1]) <= sh.columns;
    }
    case 'CSV_CELL': return s.type === 'CSV' && l.row <= (s.rows ?? 0) && l.column <= (s.columns ?? 0);
    case 'JSON_POINTER': return s.type === 'JSON';
    case 'TEXT_LINES': return (s.type === 'TEXT' || s.type === 'MARKDOWN') && l.lineEnd <= (s.lines ?? 0);
  }
}
