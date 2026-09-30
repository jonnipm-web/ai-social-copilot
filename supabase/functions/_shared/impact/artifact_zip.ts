/**
 * Minimal, bounded ZIP reader for OOXML (DOCX/XLSX) — IV-IMPACT-I3.
 *
 * No dependency, no filesystem, no execution. Reads the central directory,
 * refuses encrypted / non-deflate / oversized / too-many entries, and
 * inflates ONLY the named parts the caller asks for, each at most once,
 * against a TOTAL inflated-byte budget shared by the whole artifact (zip-bomb
 * guard). Entry names are only compared, never used as paths.
 */
import { ARTIFACT_LIMITS } from './artifact_model.ts';

export class ZipError extends Error {}

export interface ZipEntry {
  readonly name: string;
  readonly method: number;
  readonly flags: number;
  readonly compressedSize: number;
  readonly uncompressedSize: number;
  readonly localOffset: number;
}

export interface ZipIndex {
  readonly entries: ReadonlyMap<string, ZipEntry>;
  readonly names: readonly string[];
}

const u16 = (b: Uint8Array, o: number) => b[o] | (b[o + 1] << 8);
const u32 = (b: Uint8Array, o: number) => (b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)) >>> 0;

export function isZip(b: Uint8Array): boolean {
  return b.length >= 4 && b[0] === 0x50 && b[1] === 0x4b && b[2] === 0x03 && b[3] === 0x04;
}

export function readZipIndex(b: Uint8Array): ZipIndex {
  // End of central directory: last 22..(22+65535) bytes.
  let eocd = -1;
  for (let i = b.length - 22; i >= Math.max(0, b.length - 22 - 65_535); i--) {
    if (u32(b, i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) throw new ZipError('ZIP_EOCD_MISSING');
  const count = u16(b, eocd + 10);
  const cdSize = u32(b, eocd + 12);
  const cdOffset = u32(b, eocd + 16);
  if (count === 0xffff || cdOffset === 0xffffffff) throw new ZipError('ZIP64_NOT_SUPPORTED');
  if (count > ARTIFACT_LIMITS.maxZipEntries) throw new ZipError('ZIP_TOO_MANY_ENTRIES');
  if (cdOffset + cdSize > b.length) throw new ZipError('ZIP_CD_OUT_OF_RANGE');
  const entries = new Map<string, ZipEntry>();
  const names: string[] = [];
  let p = cdOffset;
  const dec = new TextDecoder('utf-8', { fatal: false });
  for (let i = 0; i < count; i++) {
    if (p + 46 > b.length || u32(b, p) !== 0x02014b50) throw new ZipError('ZIP_CD_CORRUPT');
    const flags = u16(b, p + 8);
    const method = u16(b, p + 10);
    const compressedSize = u32(b, p + 20);
    const uncompressedSize = u32(b, p + 24);
    const nameLen = u16(b, p + 28);
    const extraLen = u16(b, p + 30);
    const commentLen = u16(b, p + 32);
    const localOffset = u32(b, p + 42);
    const name = dec.decode(b.subarray(p + 46, p + 46 + nameLen));
    // Duplicate names are a crafted archive: refuse (never "pick one").
    if (entries.has(name)) throw new ZipError('ZIP_DUPLICATE_ENTRY');
    entries.set(name, { name, method, flags, compressedSize, uncompressedSize, localOffset });
    names.push(name);
    p += 46 + nameLen + extraLen + commentLen;
  }
  return { entries, names };
}

/** Shared inflation budget for one artifact. */
export class InflateBudget {
  private used = 0;
  constructor(private readonly max = ARTIFACT_LIMITS.maxInflatedBytes) {}
  take(n: number) {
    this.used += n;
    if (this.used > this.max) throw new ZipError('ZIP_INFLATE_BUDGET_EXCEEDED');
  }
}

/** Inflates one named entry (stored or deflate), bounded by its declared size and the budget. */
export async function readZipEntry(b: Uint8Array, idx: ZipIndex, name: string, budget: InflateBudget, maxPart: number): Promise<Uint8Array | null> {
  const e = idx.entries.get(name);
  if (!e) return null;
  if (e.flags & 0x1) throw new ZipError('ZIP_ENCRYPTED');
  if (e.uncompressedSize > maxPart) throw new ZipError('ZIP_PART_TOO_LARGE');
  if (e.localOffset + 30 > b.length || u32(b, e.localOffset) !== 0x04034b50) throw new ZipError('ZIP_LOCAL_HEADER_CORRUPT');
  const start = e.localOffset + 30 + u16(b, e.localOffset + 26) + u16(b, e.localOffset + 28);
  const end = start + e.compressedSize;
  if (end > b.length) throw new ZipError('ZIP_ENTRY_OUT_OF_RANGE');
  const data = b.subarray(start, end);
  if (e.method === 0) {
    budget.take(data.length);
    return data.slice();
  }
  if (e.method !== 8) throw new ZipError('ZIP_METHOD_NOT_SUPPORTED');
  // The declared size is untrusted: the stream is cut at the declared size AND the budget.
  const out = await inflateBounded(data, 'deflate-raw', Math.min(maxPart, e.uncompressedSize), budget);
  return out;
}

/** Streams a DecompressionStream, aborting as soon as `limit` bytes are exceeded. */
export async function inflateBounded(data: Uint8Array, format: 'deflate-raw' | 'deflate', limit: number, budget: InflateBudget): Promise<Uint8Array> {
  const ds = new DecompressionStream(format);
  const writer = ds.writable.getWriter();
  writer.write(data.slice() as Uint8Array<ArrayBuffer>).catch(() => {});
  writer.close().catch(() => {});
  const reader = ds.readable.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > limit) throw new ZipError('INFLATE_LIMIT_EXCEEDED');
      budget.take(value.byteLength);
      chunks.push(value);
    }
  } catch (e) {
    await reader.cancel().catch(() => {});
    if (e instanceof ZipError) throw e;
    throw new ZipError('INFLATE_CORRUPT');
  }
  const out = new Uint8Array(total);
  let o = 0;
  for (const c of chunks) { out.set(c, o); o += c.byteLength; }
  return out;
}
