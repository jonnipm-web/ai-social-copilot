/**
 * Artifact type detection — IV-IMPACT-I3. Extension, declared MIME and the
 * BYTES must agree; the bytes win. Unsupported, executable, archive and
 * macro-bearing content is refused before any parsing (nothing is executed,
 * nothing is reinterpreted as text).
 */
import { ARTIFACT_LIMITS, type ArtifactType } from './artifact_model.ts';
import { InflateBudget, isZip, readZipEntry, readZipIndex, ZipError } from './artifact_zip.ts';
import { fail, ok, type ImpactResult } from './errors.ts';

export const CANONICAL_MEDIA_TYPE: Readonly<Record<ArtifactType, string>> = {
  PDF: 'application/pdf',
  DOCX: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  XLSX: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  CSV: 'text/csv',
  JSON: 'application/json',
  TEXT: 'text/plain',
  MARKDOWN: 'text/markdown',
};

const EXTENSIONS: Readonly<Record<string, ArtifactType>> = {
  pdf: 'PDF', docx: 'DOCX', xlsx: 'XLSX', csv: 'CSV', json: 'JSON', txt: 'TEXT', md: 'MARKDOWN', markdown: 'MARKDOWN',
};

/** MIME types a client may declare for each type ('application/octet-stream' = unknown, allowed). */
const ACCEPTED_MIME: Readonly<Record<ArtifactType, readonly string[]>> = {
  PDF: ['application/pdf'],
  DOCX: [CANONICAL_MEDIA_TYPE.DOCX],
  XLSX: [CANONICAL_MEDIA_TYPE.XLSX],
  CSV: ['text/csv', 'text/plain', 'application/csv', 'application/vnd.ms-excel'],
  JSON: ['application/json', 'text/json', 'text/plain'],
  TEXT: ['text/plain'],
  MARKDOWN: ['text/markdown', 'text/x-markdown', 'text/plain'],
};

export interface DetectedArtifact {
  readonly type: ArtifactType;
  readonly mediaType: string;
  readonly filename: string;
  /** Decoded text for text-based types (UTF-8, BOM removed). */
  readonly text?: string;
}

/** Display name only: basename, no control / path / bidi-override / zero-width
 * characters (no right-to-left-override display spoofing), bounded. */
export function sanitizeFilename(name: string): string | null {
  const base = name.replace(/\\/g, '/').split('/').pop() ?? '';
  // deno-lint-ignore no-control-regex -- stripping control characters is the point
  const clean = base.normalize('NFKC').replace(/[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u202a-\u202e\u2066-\u2069\ufeff]/g, '').trim();
  if (!clean || clean.length > 200 || clean === '.' || clean === '..') return null;
  return clean;
}

function startsWith(b: Uint8Array, sig: number[], at = 0): boolean {
  return sig.every((x, i) => b[at + i] === x);
}

/** Known executable / archive / binary signatures (refused unconditionally). */
function binaryKind(b: Uint8Array): string | null {
  if (startsWith(b, [0x4d, 0x5a])) return 'EXECUTABLE'; //              MZ (PE)
  if (startsWith(b, [0x7f, 0x45, 0x4c, 0x46])) return 'EXECUTABLE'; //  ELF
  if (startsWith(b, [0xcf, 0xfa, 0xed, 0xfe]) || startsWith(b, [0xfe, 0xed, 0xfa, 0xce]) || startsWith(b, [0xca, 0xfe, 0xba, 0xbe])) return 'EXECUTABLE';
  if (startsWith(b, [0x23, 0x21])) return 'SCRIPT'; //                   #!
  if (startsWith(b, [0x52, 0x61, 0x72, 0x21])) return 'ARCHIVE'; //      Rar!
  if (startsWith(b, [0x37, 0x7a, 0xbc, 0xaf])) return 'ARCHIVE'; //      7z
  if (startsWith(b, [0x1f, 0x8b])) return 'ARCHIVE'; //                  gzip
  if (startsWith(b, [0xd0, 0xcf, 0x11, 0xe0])) return 'LEGACY_OFFICE'; // OLE2 (doc/xls, macro-capable)
  return null;
}

export async function detectArtifact(bytes: Uint8Array, filename: string, declaredMime?: string): Promise<ImpactResult<DetectedArtifact>> {
  const name = sanitizeFilename(filename);
  if (!name) return fail('INVALID_REQUEST', 'invalid filename');
  if (bytes.length === 0) return fail('FILE_SIGNATURE_INVALID', 'empty file');
  if (bytes.length > ARTIFACT_LIMITS.maxBytes) return fail('FILE_TOO_LARGE', 'file exceeds the artifact size limit');
  const ext = /\.([A-Za-z0-9]{1,10})$/.exec(name)?.[1]?.toLowerCase() ?? '';
  const type = Object.prototype.hasOwnProperty.call(EXTENSIONS, ext) ? EXTENSIONS[ext] : undefined;
  if (!type) return fail('UNSUPPORTED_FILE_TYPE', 'file type not supported for evidence', { extension: ext.slice(0, 10) });
  const mime = declaredMime?.trim().toLowerCase().split(';')[0];
  if (mime && mime !== 'application/octet-stream' && !ACCEPTED_MIME[type].includes(mime)) {
    return fail('FILE_SIGNATURE_INVALID', 'declared media type does not match the file type');
  }
  const bin = binaryKind(bytes);
  if (bin) return fail(bin === 'ARCHIVE' ? 'UNSUPPORTED_FILE_TYPE' : 'FILE_SIGNATURE_INVALID', 'binary content does not match the file type', { detected: bin });

  const out = (text?: string) => ok<DetectedArtifact>(Object.freeze({ type, mediaType: CANONICAL_MEDIA_TYPE[type], filename: name, ...(text !== undefined ? { text } : {}) }));

  if (type === 'PDF') {
    // The header may follow a little junk; nothing else counts as a PDF.
    const head = new TextDecoder('latin1').decode(bytes.subarray(0, 1024));
    return head.includes('%PDF-') ? out() : fail('FILE_SIGNATURE_INVALID', 'not a PDF');
  }
  if (type === 'DOCX' || type === 'XLSX') {
    if (!isZip(bytes)) return fail('FILE_SIGNATURE_INVALID', `not an OOXML ${type} container`);
    try {
      const idx = readZipIndex(bytes);
      const main = type === 'DOCX' ? 'word/document.xml' : 'xl/workbook.xml';
      if (!idx.entries.has('[Content_Types].xml') || !idx.entries.has(main)) return fail('FILE_SIGNATURE_INVALID', `not an OOXML ${type} document`);
      // Macro-bearing workbooks/documents are refused (never executed, never parsed).
      if (idx.names.some((n) => /vbaProject\.bin$/i.test(n) || /\.(bin|exe|dll|js|vbs|ps1)$/i.test(n) && /(^|\/)activeX|vba/i.test(n))) {
        return fail('UNSUPPORTED_FILE_TYPE', 'macro-enabled documents are not accepted');
      }
      const ct = await readZipEntry(bytes, idx, '[Content_Types].xml', new InflateBudget(1024 * 1024), 512 * 1024);
      if (ct && /macroEnabled/i.test(new TextDecoder().decode(ct))) return fail('UNSUPPORTED_FILE_TYPE', 'macro-enabled documents are not accepted');
      return out();
    } catch (e) {
      return fail('FILE_SIGNATURE_INVALID', e instanceof ZipError ? `malformed ${type}: ${e.message}` : `malformed ${type}`);
    }
  }
  // Text-based types: strict UTF-8, no NUL bytes.
  if (bytes.includes(0)) return fail('FILE_SIGNATURE_INVALID', 'binary content in a text file');
  let text: string;
  try {
    text = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  } catch {
    return fail('FILE_SIGNATURE_INVALID', 'text file is not valid UTF-8');
  }
  if (text.charCodeAt(0) === 0xfeff) text = text.slice(1);
  if (type === 'JSON' && !/^\s*[[{]/.test(text)) return fail('FILE_SIGNATURE_INVALID', 'not a JSON document');
  return out(text);
}
