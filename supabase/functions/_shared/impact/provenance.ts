/**
 * Provenance, retention and input validation — IV-IMPACT-FOUNDATION-01.
 *
 * Every evidence item must be traceable to a Source (who published it, when
 * it was published and retrieved, a content fingerprint when content was
 * retained, where in the source it sits). The engine never relies on an AI
 * summary: `excerpt` is optional, and when present it must match its hash.
 *
 * URIs are REFERENCES. Nothing in the Impact core fetches anything; a future
 * ingestion path must go through _shared/safe_fetch.ts (SSRF guard). The
 * reference check below still rejects obviously unsafe references (non-http
 * schemes, credentials, loopback/private/metadata literals) so they can never
 * be stored and later handed to a fetcher.
 */
import { assertUrlShapeIsSafe, isBlockedIp, ipv4ToInt } from '../safe_fetch.ts';
import { fail, ok, type ImpactResult } from './errors.ts';
import type { Claim, EvidenceItem, PersonalDataClass, RetentionMode, Source, SourceType } from './types.ts';

export const LIMITS = Object.freeze({
  maxIdLength: 128,
  maxTextLength: 4_000, //     claim text
  maxExcerptLength: 2_000, //  an excerpt is an extract, never a copied page
  maxPublisherLength: 300,
  maxUriLength: 2_048,
  maxEvidencePerClaim: 200,
});

const ID_RE = /^[A-Za-z0-9][A-Za-z0-9_.:-]*$/;
const HASH_RE = /^[0-9a-f]{64}$/;
const ISO_RE = /^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2}(\.\d{1,9})?)?(Z|[+-]\d{2}:\d{2}))?$/;

export async function sha256Hex(s: string): Promise<string> {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

export function isValidId(id: unknown): id is string {
  return typeof id === 'string' && id.length > 0 && id.length <= LIMITS.maxIdLength && ID_RE.test(id);
}

export function parseIsoMs(s: unknown): number | null {
  if (typeof s !== 'string' || !ISO_RE.test(s)) return null;
  const ms = Date.parse(s);
  return Number.isFinite(ms) ? ms : null;
}

// ── Reference safety (SSRF pre-guard) ───────────────────────────────────────

const BLOCKED_HOST_SUFFIXES = ['.localhost', '.local', '.internal', '.lan', '.home.arpa'];
const BLOCKED_HOSTS = new Set(['localhost', 'metadata', 'metadata.google.internal', 'instance-data']);

export function checkReferenceUri(uri: string): ImpactResult<URL> {
  if (uri.length > LIMITS.maxUriLength) return fail('UNSAFE_REFERENCE', 'reference too long');
  let url: URL;
  try {
    url = new URL(uri);
  } catch {
    return fail('UNSAFE_REFERENCE', 'reference is not a URL');
  }
  try {
    assertUrlShapeIsSafe(url);
  } catch {
    return fail('UNSAFE_REFERENCE', 'unsupported scheme or credentials in reference');
  }
  const host = url.hostname.toLowerCase().replace(/^\[|\]$/g, '').replace(/\.$/, '');
  if (BLOCKED_HOSTS.has(host) || BLOCKED_HOST_SUFFIXES.some((s) => host.endsWith(s))) {
    return fail('UNSAFE_REFERENCE', 'internal host in reference');
  }
  // Numeric shorthands (http://2130706433/, http://0x7f.1/) are rejected
  // outright: WHATWG URL normalizes most of them to dotted IPv4, and any
  // host that is an IP literal is checked against the blocked ranges.
  if (/^[0-9.]+$/.test(host) || /^0x/i.test(host) || host.includes(':')) {
    if (host.includes(':') ? isBlockedIp(host) : (ipv4ToInt(host) === null || isBlockedIp(host))) {
      return fail('UNSAFE_REFERENCE', 'private, loopback, link-local or malformed IP literal');
    }
  }
  return ok(url);
}

// ── Retention / snapshot policy ─────────────────────────────────────────────

/**
 * What may be kept from a source (IMPACT_SOURCE_MODEL.md §4). Default is to
 * keep as little as possible:
 *  - official / regulator / court / government records are public records
 *    whose later change matters → SNAPSHOT allowed (hash mandatory);
 *  - news, academic, third-party sites are copyrighted → EXCERPT_AND_HASH
 *    (short extract + fingerprint of the full retrieved content);
 *  - social media and anything that may carry personal data → HASH_ONLY;
 *  - user documents → HASH_ONLY in the Foundation (storage belongs to the
 *    Knowledge Vault, which already has ownership/RLS).
 * A caller may always choose something MORE restrictive, never less.
 */
const MAX_RETENTION: Readonly<Record<SourceType, RetentionMode>> = {
  OFFICIAL_REGISTRY: 'SNAPSHOT',
  GOVERNMENT_RECORD: 'SNAPSHOT',
  REGULATOR: 'SNAPSHOT',
  COURT_RECORD: 'EXCERPT_AND_HASH', // may name private individuals
  AUDITED_REPORT: 'EXCERPT_AND_HASH',
  FINANCIAL_REPORT: 'EXCERPT_AND_HASH',
  ORGANIZATION_WEBSITE: 'EXCERPT_AND_HASH',
  NEWS: 'EXCERPT_AND_HASH',
  ACADEMIC: 'EXCERPT_AND_HASH',
  NGO_DATABASE: 'EXCERPT_AND_HASH',
  SOCIAL_MEDIA: 'HASH_ONLY',
  USER_DOCUMENT: 'HASH_ONLY',
  OTHER: 'REFERENCE_ONLY',
};

const RETENTION_RANK: Readonly<Record<RetentionMode, number>> = {
  REFERENCE_ONLY: 0,
  HASH_ONLY: 1,
  EXCERPT_AND_HASH: 2,
  SNAPSHOT: 3,
};

export function maxRetentionFor(type: SourceType): RetentionMode {
  return MAX_RETENTION[type];
}

/** Conceptual retention periods (days); enforcement arrives with
 * persistence (IMPACT_SECURITY_MODEL.md §8). null = kept while the
 * investigation exists. */
export const RETENTION_POLICY = Object.freeze({
  sourceMetadataDays: null,
  snapshotDays: 730,
  userEvidenceDays: 365,
  verificationResultsDays: null, // history is the audit trail of conclusions
  auditTrailDays: 2_555,
});

// ── Validation ──────────────────────────────────────────────────────────────

/** Personal-data classes the Foundation refuses to hold at all. */
const REJECTED_PERSONAL_DATA: ReadonlySet<PersonalDataClass> = new Set(['PERSONAL', 'SENSITIVE', 'MINOR']);

export function validateSource(s: Source, evaluatedAtMs: number): ImpactResult<Source> {
  if (!isValidId(s.id)) return fail('INVALID_SOURCE', 'invalid source id');
  if (typeof s.publisher !== 'string' || !s.publisher.trim() || s.publisher.length > LIMITS.maxPublisherLength) {
    return fail('INVALID_SOURCE', 'publisher required', { sourceId: s.id });
  }
  if (!(s.type in MAX_RETENTION)) return fail('INVALID_SOURCE', 'unknown source type', { sourceId: s.id });
  const retrieved = parseIsoMs(s.retrievedAt);
  if (retrieved === null) return fail('INVALID_SOURCE', 'retrievedAt required', { sourceId: s.id });
  if (retrieved > evaluatedAtMs) return fail('INVALID_SOURCE', 'retrievedAt is in the future', { sourceId: s.id });
  if (s.publishedAt !== undefined) {
    const pub = parseIsoMs(s.publishedAt);
    if (pub === null || pub > retrieved) return fail('INVALID_SOURCE', 'publishedAt invalid or after retrieval', { sourceId: s.id });
  }
  if (RETENTION_RANK[s.retention] === undefined) return fail('INVALID_SOURCE', 'unknown retention', { sourceId: s.id });
  if (RETENTION_RANK[s.retention] > RETENTION_RANK[MAX_RETENTION[s.type]]) {
    return fail('INVALID_SOURCE', 'retention exceeds policy for this source type', { sourceId: s.id, type: s.type });
  }
  if (s.retention !== 'REFERENCE_ONLY' && !(typeof s.contentHash === 'string' && HASH_RE.test(s.contentHash))) {
    return fail('INVALID_SOURCE', 'contentHash (sha-256 hex) required when content is retained', { sourceId: s.id });
  }
  if (s.retention === 'REFERENCE_ONLY' && !s.uri) {
    return fail('INVALID_SOURCE', 'a reference-only source needs a uri', { sourceId: s.id });
  }
  if (s.uri !== undefined) {
    const r = checkReferenceUri(s.uri);
    if (!r.ok) return fail(r.error.code, r.error.message, { sourceId: s.id });
  }
  if (s.newsGenre !== undefined && s.type !== 'NEWS') return fail('INVALID_SOURCE', 'newsGenre only for NEWS', { sourceId: s.id });
  return ok(s);
}

export function validateClaim(c: Claim, investigationId: string): ImpactResult<Claim> {
  if (!isValidId(c.id)) return fail('INVALID_CLAIM', 'invalid claim id');
  if (c.investigationId !== investigationId) {
    return fail('CROSS_INVESTIGATION_DENIED', 'claim belongs to another investigation', { claimId: c.id });
  }
  if (!isValidId(c.subjectOrganizationId)) return fail('INVALID_CLAIM', 'subject required', { claimId: c.id });
  if (typeof c.text !== 'string' || !c.text.trim() || c.text.length > LIMITS.maxTextLength) {
    return fail('INVALID_CLAIM', 'claim text required and bounded', { claimId: c.id });
  }
  if (!isValidId(c.sourceId)) return fail('INVALID_CLAIM', 'claim must cite the source where it was made', { claimId: c.id });
  if (parseIsoMs(c.extractedAt) === null) return fail('INVALID_CLAIM', 'extractedAt required', { claimId: c.id });
  if (c.quantity && !(Number.isFinite(c.quantity.value) && c.quantity.value >= 0)) {
    return fail('INVALID_CLAIM', 'quantity must be a finite non-negative number', { claimId: c.id });
  }
  return ok(c);
}

export async function validateEvidence(
  e: EvidenceItem,
  claim: Claim,
  sources: ReadonlyMap<string, Source>,
): Promise<ImpactResult<EvidenceItem>> {
  if (!isValidId(e.id)) return fail('INVALID_EVIDENCE', 'invalid evidence id');
  if (e.investigationId !== claim.investigationId) {
    return fail('CROSS_INVESTIGATION_DENIED', 'evidence belongs to another investigation', { evidenceId: e.id });
  }
  if (e.claimId !== claim.id) return fail('INVALID_EVIDENCE', 'evidence is linked to another claim', { evidenceId: e.id });
  if (!sources.has(e.sourceId)) return fail('INVALID_EVIDENCE', 'evidence without a known source (no provenance)', { evidenceId: e.id });
  if (!isValidId(e.aboutOrganizationId)) return fail('INVALID_EVIDENCE', 'aboutOrganizationId required', { evidenceId: e.id });
  if (REJECTED_PERSONAL_DATA.has(e.personalData)) {
    return fail('SENSITIVE_DATA_REJECTED', 'personal/sensitive/minor data is not accepted by the Foundation', { evidenceId: e.id });
  }
  if (!['NONE', 'AGGREGATED', 'PUBLIC_OFFICIAL_ROLE'].includes(e.personalData)) {
    return fail('INVALID_EVIDENCE', 'personalData classification required', { evidenceId: e.id });
  }
  if (!['SUPPORTS', 'CONTRADICTS', 'CONTEXTUALIZES'].includes(e.relationship)) {
    return fail('INVALID_EVIDENCE', 'unknown relationship', { evidenceId: e.id });
  }
  if (!['STRUCTURED_MATCH', 'HUMAN_ASSESSED', 'LLM_SUGGESTED'].includes(e.relationshipBasis)) {
    return fail('INVALID_EVIDENCE', 'relationshipBasis required', { evidenceId: e.id });
  }
  if (e.relationshipBasis === 'STRUCTURED_MATCH' && !(claim.quantity && e.reportedQuantity)) {
    return fail('INVALID_EVIDENCE', 'STRUCTURED_MATCH requires structured quantities on claim and evidence', { evidenceId: e.id });
  }
  if (e.reportedQuantity && !(Number.isFinite(e.reportedQuantity.value) && e.reportedQuantity.value >= 0)) {
    return fail('INVALID_EVIDENCE', 'reportedQuantity must be finite and non-negative', { evidenceId: e.id });
  }
  if (parseIsoMs(e.addedAt) === null) return fail('INVALID_EVIDENCE', 'addedAt required', { evidenceId: e.id });
  if (e.excerpt !== undefined) {
    if (e.excerpt.length > LIMITS.maxExcerptLength) return fail('INVALID_EVIDENCE', 'excerpt too long', { evidenceId: e.id });
    const src = sources.get(e.sourceId)!;
    if (src.retention !== 'EXCERPT_AND_HASH' && src.retention !== 'SNAPSHOT') {
      return fail('INVALID_EVIDENCE', 'source retention does not allow storing an excerpt', { evidenceId: e.id });
    }
    if (!e.excerptHash || e.excerptHash !== (await sha256Hex(e.excerpt))) {
      return fail('INVALID_EVIDENCE', 'excerpt does not match its hash (tampered or unhashed)', { evidenceId: e.id });
    }
  }
  for (const p of [e.observedPeriod?.from, e.observedPeriod?.to]) {
    if (p !== undefined && parseIsoMs(p) === null) return fail('INVALID_EVIDENCE', 'invalid observedPeriod', { evidenceId: e.id });
  }
  return ok(e);
}
