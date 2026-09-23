/**
 * Impact Lab request contract — IV-IMPACT-I1-PERSISTENCE-RLS-01.
 *
 * Strict, explicit schemas for every Lab action. Unknown actions, unknown
 * fields, unknown enum values, malformed ids/dates/URIs and oversized text are
 * rejected with INVALID_REQUEST before any database access.
 *
 * Fields a client must NEVER control do not exist in any schema, so sending
 * them fails as an unknown field: owner_id / user_id / role / plan,
 * investigation subject on a claim, source acquisition / provider id /
 * "trusted" / authority, excerpt hash, claim or verification status,
 * evaluatedAt, version, audit fields. The server derives all of them.
 *
 * I2: lineage and registry authority are server-derived too — there is no
 * field for "independent", "original", lineage state, content fingerprint,
 * similarity sketch, syndication markers, provider authority/official flag,
 * canonical organization id, or "this record belongs to this organization".
 * A client may submit content TEXT (the server fingerprints it and keeps only
 * the hashes) and a merge-only `derivedFrom` label.
 *
 * I3: artifact bytes arrive as base64 and are hashed by the SERVER; there is
 * no field for a file hash, an excerpt, a reviewer, "reviewed", "verified",
 * "official", "authoritative", "independent" or "fact". Locators are parsed
 * strictly and re-validated against the server's own extraction.
 */
import { type ArtifactLocator, CLOUD_PROVIDERS, type CloudProvider, parseLocator } from './artifact_model.ts';
import { fail, ok, type ImpactResult } from './errors.ts';
import { CLAIM_KINDS, IMPACT_LEVELS, isOneOf, isValidId, LEGAL_STAGES, NEWS_GENRES, parseIsoMs, SOURCE_TYPES } from './provenance.ts';
import type { ClaimKind, ImpactLevel, LegalStage, NewsGenre, OrganizationType, SourceStatus, SourceType } from './types.ts';

export const LAB_LIMITS = Object.freeze({
  maxBodyBytes: 64 * 1024,
  maxText: 4_000,
  maxExcerpt: 2_000,
  maxShort: 300,
  maxList: 20,
  maxSourcesPerInvestigation: 200,
  maxClaimsPerInvestigation: 200,
  maxEvidencePerInvestigation: 1_000,
  maxDisputesPerInvestigation: 100,
  maxInvestigationsPerOwner: 100,
  /** I2: content text a client may submit for lineage fingerprinting (never stored). */
  maxContentText: 20_000,
  maxQueryField: 200,
  /** I3: body limit for ingest_artifact only (6 MB file ≈ 8 MB base64). Every other action keeps maxBodyBytes. */
  maxArtifactBodyBytes: 9 * 1024 * 1024,
  maxArtifactBase64: 8_400_000,
});

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const HASH_RE = /^[0-9a-f]{64}$/;

export const ORG_TYPES = [
  'CHARITY', 'NGO', 'NONPROFIT', 'FOUNDATION', 'SOCIAL_ENTERPRISE', 'RELIGIOUS_ORGANIZATION',
  'COMMUNITY_PROJECT', 'CROWDFUNDING_CAMPAIGN', 'INFORMAL_INITIATIVE', 'OTHER',
] as const;
const CLIENT_SOURCE_TYPES = SOURCE_TYPES; // any type may be *labelled*; authority still needs provider provenance
const CLIENT_RETENTION = ['REFERENCE_ONLY', 'HASH_ONLY', 'EXCERPT_AND_HASH'] as const; // SNAPSHOT only via provider ingestion
const CLIENT_ORIGINS = ['MANUAL', 'STRUCTURED_IMPORT'] as const; // no LLM in the Lab
const RELATIONSHIPS = ['SUPPORTS', 'CONTRADICTS', 'CONTEXTUALIZES'] as const;
const BASES = ['STRUCTURED_MATCH', 'HUMAN_ASSESSED', 'LLM_SUGGESTED'] as const;
const PERSONAL = ['NONE', 'AGGREGATED', 'PUBLIC_OFFICIAL_ROLE'] as const;
const SOURCE_STATUS_CHANGES = ['UPDATED', 'RETRACTED', 'UNAVAILABLE'] as const;
const DISPUTE_KINDS = ['ORGANIZATION_RESPONSE', 'CORRECTION_REQUEST', 'RETRACTION_REQUEST', 'SOURCE_UPDATE'] as const;
const DISPUTE_RESOLUTIONS = ['CORRECTED', 'UPHELD', 'WITHDRAWN', 'SOURCE_RETRACTED'] as const;
const LANGS = ['pt', 'en'] as const;

export interface SubjectInput {
  readonly ref: string;
  readonly type: OrganizationType;
  readonly identity: {
    readonly legalName?: string;
    readonly publicName?: string;
    readonly aliases?: readonly string[];
    readonly registrations?: readonly { readonly country: string; readonly scheme: string; readonly value: string }[];
    readonly domains?: readonly string[];
  };
}

export interface SourceInput {
  readonly ref: string;
  readonly type: SourceType;
  readonly publisher: string;
  readonly publisherOrgRef?: string;
  readonly uri?: string;
  readonly retrievedAt: string;
  readonly publishedAt?: string;
  readonly jurisdictionCountry?: string;
  readonly newsGenre?: NewsGenre;
  readonly retention: typeof CLIENT_RETENTION[number];
  readonly contentHash?: string;
  readonly syndicatedFrom?: string;
  readonly userUpload?: boolean;
  /** I2: merge-only lineage hint (this material cites / summarizes that publisher). */
  readonly derivedFrom?: string;
  /** I2: content text for server-side fingerprinting; only hashes are persisted. */
  readonly contentText?: string;
}

export interface CandidateRequestInput {
  readonly ref: string;
  readonly locator: ArtifactLocator;
  readonly quote?: string;
  readonly claimRef?: string;
  readonly proposedRelationship?: typeof RELATIONSHIPS[number];
}

export interface ArtifactInput {
  readonly ref: string;
  readonly filename: string;
  readonly mediaType?: string;
  readonly contentBase64: string;
  readonly origin: 'USER_UPLOAD' | 'CLOUD_IMPORT';
  readonly cloud?: { readonly provider: CloudProvider; readonly fileRef: string; readonly modifiedAt?: string };
  readonly supersedesRef?: string;
  readonly candidates: readonly CandidateRequestInput[];
}

export interface CandidateReviewInput {
  readonly candidateRef: string;
  readonly decision: 'ACCEPTED' | 'REJECTED' | 'NEEDS_CONTEXT';
  readonly relationship?: typeof RELATIONSHIPS[number];
  readonly claimRef?: string;
  readonly aboutOrgRef?: string;
  readonly personalData?: typeof PERSONAL[number];
  readonly observedPeriod?: { readonly from?: string; readonly to?: string };
  /** Required to attribute a SUBJECT_NOT_MENTIONED candidate to the investigation subject. */
  readonly subjectConfirmed?: boolean;
}

export interface RegistryQueryInput {
  readonly name?: string;
  readonly registration?: string;
  readonly scheme?: string;
  readonly domain?: string;
  readonly country?: string;
}

export interface ClaimInput {
  readonly ref: string;
  readonly kind: ClaimKind;
  readonly text: string;
  readonly textLanguage?: string;
  readonly quantity?: { readonly metric: string; readonly value: number; readonly unit: string };
  readonly level?: ImpactLevel;
  readonly claimantOrgRef?: string;
  readonly claimantLabel?: string;
  readonly subjectProjectRef?: string;
  readonly subjectCampaignRef?: string;
  readonly period?: { readonly from?: string; readonly to?: string };
  readonly sourceRef: string;
  readonly origin: typeof CLIENT_ORIGINS[number];
}

export interface EvidenceInput {
  readonly ref: string;
  readonly claimRef: string;
  readonly sourceRef: string;
  readonly aboutOrgRef: string;
  readonly relationship: typeof RELATIONSHIPS[number];
  readonly basis: typeof BASES[number];
  readonly reportedQuantity?: { readonly metric: string; readonly value: number; readonly unit: string };
  readonly level?: ImpactLevel;
  readonly observedPeriod?: { readonly from?: string; readonly to?: string };
  readonly excerpt?: string;
  readonly locator?: { readonly page?: number; readonly section?: string; readonly charStart?: number; readonly charEnd?: number };
  readonly personalData: typeof PERSONAL[number];
  readonly legalStage?: LegalStage;
}

export type LabRequest =
  | { readonly action: 'create_investigation'; readonly subject: SubjectInput; readonly projectId?: string }
  | { readonly action: 'list_investigations' }
  | { readonly action: 'get_investigation'; readonly investigationId: string; readonly lang: 'pt' | 'en' }
  | { readonly action: 'archive_investigation'; readonly investigationId: string }
  | { readonly action: 'add_source'; readonly investigationId: string; readonly source: SourceInput }
  | { readonly action: 'ingest_provider_record'; readonly investigationId: string; readonly providerId: string; readonly recordId: string; readonly ref: string }
  | { readonly action: 'update_source_status'; readonly investigationId: string; readonly sourceRef: string; readonly status: Exclude<SourceStatus, 'ACTIVE'> }
  | { readonly action: 'add_claim'; readonly investigationId: string; readonly claim: ClaimInput }
  | { readonly action: 'add_evidence'; readonly investigationId: string; readonly evidence: EvidenceInput }
  | { readonly action: 'run_verification'; readonly investigationId: string; readonly claimRef: string; readonly idempotencyKey?: string; readonly humanReviewBindingHash?: string }
  | { readonly action: 'open_dispute'; readonly investigationId: string; readonly ref: string; readonly claimRef: string; readonly kind: typeof DISPUTE_KINDS[number]; readonly submittedEvidenceRefs: readonly string[] }
  | { readonly action: 'resolve_dispute'; readonly investigationId: string; readonly disputeRef: string; readonly resolution: typeof DISPUTE_RESOLUTIONS[number] }
  | { readonly action: 'request_external_action'; readonly kind: string }
  // I2 Registry Intelligence
  | { readonly action: 'search_registry'; readonly investigationId: string; readonly providerId: string; readonly query: RegistryQueryInput }
  | { readonly action: 'import_registry_claim'; readonly investigationId: string; readonly sourceRef: string; readonly ref: string }
  // I3 Evidence Collection
  | { readonly action: 'ingest_artifact'; readonly investigationId: string; readonly artifact: ArtifactInput }
  | { readonly action: 'review_candidate'; readonly investigationId: string; readonly review: CandidateReviewInput };

export type LabAction = LabRequest['action'];

// ── tiny strict-schema toolkit ─────────────────────────────────────────────

class Bad extends Error {}

type Obj = Record<string, unknown>;
function obj(v: unknown, where: string, allowed: readonly string[]): Obj {
  if (typeof v !== 'object' || v === null || Array.isArray(v) || Object.getPrototypeOf(v) !== Object.prototype) {
    throw new Bad(`${where} must be an object`);
  }
  for (const k of Object.keys(v)) if (!allowed.includes(k)) throw new Bad(`${where}: unknown field "${k}"`);
  return v as Obj;
}
function str(o: Obj, k: string, max: number, required = true): string | undefined {
  const v = o[k];
  if (v === undefined && !required) return undefined;
  if (typeof v !== 'string' || !v.trim() || v.length > max) throw new Bad(`${k} must be a non-empty string ≤ ${max}`);
  return v;
}
function id(o: Obj, k: string, required = true): string | undefined {
  const v = o[k];
  if (v === undefined && !required) return undefined;
  if (!isValidId(v)) throw new Bad(`${k} must be a ref [A-Za-z0-9_.:-]`);
  return v as string;
}
function uuid(o: Obj, k: string, required = true): string | undefined {
  const v = o[k];
  if (v === undefined && !required) return undefined;
  if (typeof v !== 'string' || !UUID_RE.test(v)) throw new Bad(`${k} must be a UUID`);
  return v;
}
function en<T extends string>(o: Obj, k: string, allowed: readonly T[], required = true): T | undefined {
  const v = o[k];
  if (v === undefined && !required) return undefined;
  if (!isOneOf(v, allowed)) throw new Bad(`${k}: unknown value`);
  return v;
}
function iso(o: Obj, k: string, required = true): string | undefined {
  const v = o[k];
  if (v === undefined && !required) return undefined;
  if (parseIsoMs(v) === null) throw new Bad(`${k} must be an ISO-8601 date`);
  return v as string;
}
function period(v: unknown, where: string): { from?: string; to?: string } | undefined {
  if (v === undefined) return undefined;
  const o = obj(v, where, ['from', 'to']);
  const p = { from: iso(o, 'from', false), to: iso(o, 'to', false) };
  if (p.from && p.to && (parseIsoMs(p.from) as number) > (parseIsoMs(p.to) as number)) throw new Bad(`${where} is reversed`);
  return p;
}
function quantity(v: unknown, where: string) {
  if (v === undefined) return undefined;
  const o = obj(v, where, ['metric', 'value', 'unit']);
  const value = o.value;
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 || value > 1e15) throw new Bad(`${where}.value invalid`);
  return { metric: str(o, 'metric', 100)!, value, unit: str(o, 'unit', 50)! };
}
function strList(v: unknown, where: string, max: number, itemMax: number): string[] | undefined {
  if (v === undefined) return undefined;
  if (!Array.isArray(v) || v.length > max) throw new Bad(`${where} must be a list ≤ ${max}`);
  return v.map((x) => {
    if (typeof x !== 'string' || !x.trim() || x.length > itemMax) throw new Bad(`${where} item invalid`);
    return x;
  });
}

// ── action schemas ─────────────────────────────────────────────────────────

function subject(v: unknown): SubjectInput {
  const o = obj(v, 'subject', ['ref', 'type', 'identity']);
  const i = obj(o.identity ?? {}, 'subject.identity', ['legalName', 'publicName', 'aliases', 'registrations', 'domains']);
  const regs = i.registrations === undefined ? undefined : (() => {
    if (!Array.isArray(i.registrations) || i.registrations.length > 10) throw new Bad('registrations must be a list ≤ 10');
    return i.registrations.map((r, n) => {
      const ro = obj(r, `registrations[${n}]`, ['country', 'scheme', 'value']);
      const country = str(ro, 'country', 2)!;
      if (!/^[A-Z]{2}$/.test(country)) throw new Bad('registration country must be ISO 3166-1 alpha-2');
      return { country, scheme: str(ro, 'scheme', 60)!, value: str(ro, 'value', 60)! };
    });
  })();
  return {
    ref: id(o, 'ref')!,
    type: en(o, 'type', ORG_TYPES)!,
    identity: {
      legalName: str(i, 'legalName', LAB_LIMITS.maxShort, false),
      publicName: str(i, 'publicName', LAB_LIMITS.maxShort, false),
      aliases: strList(i.aliases, 'aliases', LAB_LIMITS.maxList, LAB_LIMITS.maxShort),
      registrations: regs,
      domains: strList(i.domains, 'domains', 10, 253),
    },
  };
}

function source(v: unknown): SourceInput {
  const o = obj(v, 'source', ['ref', 'type', 'publisher', 'publisherOrgRef', 'uri', 'retrievedAt', 'publishedAt',
    'jurisdictionCountry', 'newsGenre', 'retention', 'contentHash', 'syndicatedFrom', 'userUpload', 'derivedFrom', 'contentText']);
  const contentHash = o.contentHash;
  if (contentHash !== undefined && (typeof contentHash !== 'string' || !HASH_RE.test(contentHash))) throw new Bad('contentHash must be sha-256 hex');
  const jc = o.jurisdictionCountry;
  if (jc !== undefined && (typeof jc !== 'string' || !/^[A-Z]{2}$/.test(jc))) throw new Bad('jurisdictionCountry must be ISO alpha-2');
  if (o.userUpload !== undefined && typeof o.userUpload !== 'boolean') throw new Bad('userUpload must be boolean');
  return {
    ref: id(o, 'ref')!,
    type: en(o, 'type', CLIENT_SOURCE_TYPES)!,
    publisher: str(o, 'publisher', LAB_LIMITS.maxShort)!,
    publisherOrgRef: id(o, 'publisherOrgRef', false),
    uri: str(o, 'uri', 2048, false),
    retrievedAt: iso(o, 'retrievedAt')!,
    publishedAt: iso(o, 'publishedAt', false),
    jurisdictionCountry: jc as string | undefined,
    newsGenre: en(o, 'newsGenre', NEWS_GENRES, false),
    retention: en(o, 'retention', CLIENT_RETENTION)!,
    contentHash: contentHash as string | undefined,
    syndicatedFrom: str(o, 'syndicatedFrom', LAB_LIMITS.maxShort, false),
    userUpload: o.userUpload as boolean | undefined,
    derivedFrom: str(o, 'derivedFrom', LAB_LIMITS.maxShort, false),
    contentText: str(o, 'contentText', LAB_LIMITS.maxContentText, false),
  };
}

const B64_RE = /^[A-Za-z0-9+/]*={0,2}$/;

function artifactInput(v: unknown): ArtifactInput {
  const o = obj(v, 'artifact', ['ref', 'filename', 'mediaType', 'contentBase64', 'origin', 'cloud', 'supersedesRef', 'candidates']);
  const b64 = o.contentBase64;
  if (typeof b64 !== 'string' || !b64 || b64.length > LAB_LIMITS.maxArtifactBase64 || b64.length % 4 !== 0 || !B64_RE.test(b64)) {
    throw new Bad('contentBase64 must be canonical base64 within the size limit');
  }
  const origin = en(o, 'origin', ['USER_UPLOAD', 'CLOUD_IMPORT'] as const, false) ?? 'USER_UPLOAD';
  let cloud: ArtifactInput['cloud'];
  if (o.cloud !== undefined) {
    const c = obj(o.cloud, 'artifact.cloud', ['provider', 'fileRef', 'modifiedAt']);
    cloud = { provider: en(c, 'provider', CLOUD_PROVIDERS)!, fileRef: id(c, 'fileRef')!, ...(c.modifiedAt !== undefined ? { modifiedAt: iso(c, 'modifiedAt')! } : {}) };
  }
  if ((origin === 'CLOUD_IMPORT') !== (cloud !== undefined)) throw new Bad('cloud metadata is required for, and only for, CLOUD_IMPORT');
  const reqs = o.candidates === undefined ? [] : (() => {
    if (!Array.isArray(o.candidates) || o.candidates.length > 20) throw new Bad('candidates must be a list ≤ 20');
    return o.candidates.map((x, n) => {
      const c = obj(x, `candidates[${n}]`, ['ref', 'locator', 'quote', 'claimRef', 'proposedRelationship']);
      const locator = parseLocator(c.locator);
      if (!locator) throw new Bad(`candidates[${n}].locator invalid`);
      return {
        ref: id(c, 'ref')!, locator, quote: str(c, 'quote', 1_000, false), claimRef: id(c, 'claimRef', false),
        proposedRelationship: en(c, 'proposedRelationship', RELATIONSHIPS, false),
      };
    });
  })();
  return {
    ref: id(o, 'ref')!, filename: str(o, 'filename', 200)!, mediaType: str(o, 'mediaType', 100, false), contentBase64: b64, origin, cloud,
    supersedesRef: id(o, 'supersedesRef', false), candidates: reqs,
  };
}

function candidateReview(top: Obj): CandidateReviewInput {
  return {
    candidateRef: id(top, 'candidate_ref')!,
    decision: en(top, 'decision', ['ACCEPTED', 'REJECTED', 'NEEDS_CONTEXT'] as const)!,
    relationship: en(top, 'relationship', RELATIONSHIPS, false),
    claimRef: id(top, 'claim_ref', false),
    aboutOrgRef: id(top, 'about_org_ref', false),
    personalData: en(top, 'personal_data', PERSONAL, false),
    observedPeriod: period(top.observed_period, 'observed_period'),
    ...(top.subject_confirmed !== undefined ? { subjectConfirmed: (() => { if (typeof top.subject_confirmed !== 'boolean') throw new Bad('subject_confirmed must be boolean'); return top.subject_confirmed; })() } : {}),
  };
}

function registryQuery(v: unknown): RegistryQueryInput {
  const o = obj(v, 'query', ['name', 'registration', 'scheme', 'domain', 'country']);
  const country = o.country;
  if (country !== undefined && (typeof country !== 'string' || !/^[A-Z]{2}$/.test(country))) throw new Bad('query.country must be ISO alpha-2');
  const q: RegistryQueryInput = {
    name: str(o, 'name', LAB_LIMITS.maxQueryField, false),
    registration: str(o, 'registration', 60, false),
    scheme: str(o, 'scheme', 60, false),
    domain: str(o, 'domain', 253, false),
    country: country as string | undefined,
  };
  if (!q.name && !q.registration && !q.domain) throw new Bad('query needs a name, registration or domain');
  return q;
}

function claim(v: unknown): ClaimInput {
  const o = obj(v, 'claim', ['ref', 'kind', 'text', 'textLanguage', 'quantity', 'level', 'claimantOrgRef', 'claimantLabel',
    'subjectProjectRef', 'subjectCampaignRef', 'period', 'sourceRef', 'origin']);
  const lang = o.textLanguage;
  if (lang !== undefined && (typeof lang !== 'string' || !/^[a-z]{2}(-[A-Z]{2})?$/.test(lang))) throw new Bad('textLanguage invalid');
  return {
    ref: id(o, 'ref')!,
    kind: en(o, 'kind', CLAIM_KINDS)!,
    text: str(o, 'text', LAB_LIMITS.maxText)!,
    textLanguage: lang as string | undefined,
    quantity: quantity(o.quantity, 'claim.quantity'),
    level: en(o, 'level', IMPACT_LEVELS, false),
    claimantOrgRef: id(o, 'claimantOrgRef', false),
    claimantLabel: str(o, 'claimantLabel', LAB_LIMITS.maxShort, false),
    subjectProjectRef: id(o, 'subjectProjectRef', false),
    subjectCampaignRef: id(o, 'subjectCampaignRef', false),
    period: period(o.period, 'claim.period'),
    sourceRef: id(o, 'sourceRef')!,
    origin: en(o, 'origin', CLIENT_ORIGINS)!,
  };
}

function evidence(v: unknown): EvidenceInput {
  const o = obj(v, 'evidence', ['ref', 'claimRef', 'sourceRef', 'aboutOrgRef', 'relationship', 'basis', 'reportedQuantity',
    'level', 'observedPeriod', 'excerpt', 'locator', 'personalData', 'legalStage']);
  let locator: EvidenceInput['locator'];
  if (o.locator !== undefined) {
    const l = obj(o.locator, 'locator', ['page', 'section', 'charStart', 'charEnd']);
    for (const k of ['page', 'charStart', 'charEnd']) {
      if (l[k] !== undefined && !(Number.isInteger(l[k]) && (l[k] as number) >= 0 && (l[k] as number) < 1e9)) throw new Bad(`locator.${k} invalid`);
    }
    locator = { page: l.page as number | undefined, section: str(l, 'section', 200, false), charStart: l.charStart as number | undefined, charEnd: l.charEnd as number | undefined };
  }
  return {
    ref: id(o, 'ref')!,
    claimRef: id(o, 'claimRef')!,
    sourceRef: id(o, 'sourceRef')!,
    aboutOrgRef: id(o, 'aboutOrgRef')!,
    relationship: en(o, 'relationship', RELATIONSHIPS)!,
    basis: en(o, 'basis', BASES)!,
    reportedQuantity: quantity(o.reportedQuantity, 'evidence.reportedQuantity'),
    level: en(o, 'level', IMPACT_LEVELS, false),
    observedPeriod: period(o.observedPeriod, 'evidence.observedPeriod'),
    excerpt: str(o, 'excerpt', LAB_LIMITS.maxExcerpt, false),
    locator,
    // PERSONAL / SENSITIVE / MINOR are not even representable in the Lab contract.
    personalData: en(o, 'personalData', PERSONAL)!,
    legalStage: en(o, 'legalStage', LEGAL_STAGES, false),
  };
}

export function parseLabRequest(body: unknown): ImpactResult<LabRequest> {
  try {
    const top = obj(body, 'request', ['action', 'investigation_id', 'subject', 'project_id', 'lang', 'source', 'provider_id',
      'record_id', 'ref', 'source_ref', 'status', 'claim', 'evidence', 'claim_ref', 'idempotency_key',
      'human_review_binding_hash', 'kind', 'submitted_evidence_refs', 'dispute_ref', 'resolution', 'query', 'artifact',
      'candidate_ref', 'decision', 'relationship', 'about_org_ref', 'personal_data', 'observed_period', 'subject_confirmed']);
    const action = top.action;
    const allowOnly = (keys: string[]) => {
      for (const k of Object.keys(top)) if (k !== 'action' && !keys.includes(k)) throw new Bad(`field "${k}" not allowed for ${String(action)}`);
    };
    const inv = () => uuid(top, 'investigation_id')!;
    switch (action) {
      case 'create_investigation':
        allowOnly(['subject', 'project_id']);
        return ok({ action, subject: subject(top.subject), projectId: uuid(top, 'project_id', false) });
      case 'list_investigations':
        allowOnly([]);
        return ok({ action });
      case 'get_investigation':
        allowOnly(['investigation_id', 'lang']);
        return ok({ action, investigationId: inv(), lang: en(top, 'lang', LANGS, false) ?? 'pt' });
      case 'archive_investigation':
        allowOnly(['investigation_id']);
        return ok({ action, investigationId: inv() });
      case 'add_source':
        allowOnly(['investigation_id', 'source']);
        return ok({ action, investigationId: inv(), source: source(top.source) });
      case 'ingest_provider_record':
        allowOnly(['investigation_id', 'provider_id', 'record_id', 'ref']);
        return ok({ action, investigationId: inv(), providerId: id(top, 'provider_id')!, recordId: id(top, 'record_id')!, ref: id(top, 'ref')! });
      case 'update_source_status':
        allowOnly(['investigation_id', 'source_ref', 'status']);
        return ok({ action, investigationId: inv(), sourceRef: id(top, 'source_ref')!, status: en(top, 'status', SOURCE_STATUS_CHANGES)! });
      case 'add_claim':
        allowOnly(['investigation_id', 'claim']);
        return ok({ action, investigationId: inv(), claim: claim(top.claim) });
      case 'add_evidence':
        allowOnly(['investigation_id', 'evidence']);
        return ok({ action, investigationId: inv(), evidence: evidence(top.evidence) });
      case 'run_verification': {
        allowOnly(['investigation_id', 'claim_ref', 'idempotency_key', 'human_review_binding_hash']);
        const h = top.human_review_binding_hash;
        if (h !== undefined && (typeof h !== 'string' || !HASH_RE.test(h))) throw new Bad('human_review_binding_hash must be sha-256 hex');
        return ok({ action, investigationId: inv(), claimRef: id(top, 'claim_ref')!, idempotencyKey: uuid(top, 'idempotency_key', false), humanReviewBindingHash: h as string | undefined });
      }
      case 'open_dispute':
        allowOnly(['investigation_id', 'ref', 'claim_ref', 'kind', 'submitted_evidence_refs']);
        return ok({
          action, investigationId: inv(), ref: id(top, 'ref')!, claimRef: id(top, 'claim_ref')!, kind: en(top, 'kind', DISPUTE_KINDS)!,
          submittedEvidenceRefs: (strList(top.submitted_evidence_refs, 'submitted_evidence_refs', 50, 128) ?? []).map((r) => {
            if (!isValidId(r)) throw new Bad('submitted_evidence_refs item invalid');
            return r;
          }),
        });
      case 'resolve_dispute':
        allowOnly(['investigation_id', 'dispute_ref', 'resolution']);
        return ok({ action, investigationId: inv(), disputeRef: id(top, 'dispute_ref')!, resolution: en(top, 'resolution', DISPUTE_RESOLUTIONS)! });
      case 'search_registry':
        allowOnly(['investigation_id', 'provider_id', 'query']);
        return ok({ action, investigationId: inv(), providerId: id(top, 'provider_id')!, query: registryQuery(top.query) });
      case 'ingest_artifact':
        allowOnly(['investigation_id', 'artifact']);
        return ok({ action, investigationId: inv(), artifact: artifactInput(top.artifact) });
      case 'review_candidate':
        allowOnly(['investigation_id', 'candidate_ref', 'decision', 'relationship', 'claim_ref', 'about_org_ref', 'personal_data', 'observed_period', 'subject_confirmed']);
        return ok({ action, investigationId: inv(), review: candidateReview(top) });
      case 'import_registry_claim':
        allowOnly(['investigation_id', 'source_ref', 'ref']);
        return ok({ action, investigationId: inv(), sourceRef: id(top, 'source_ref')!, ref: id(top, 'ref')! });
      case 'request_external_action':
        allowOnly(['kind']);
        if (typeof top.kind !== 'string' || top.kind.length > 64) throw new Bad('kind must be a string');
        return ok({ action, kind: top.kind });
      default:
        throw new Bad('unknown action');
    }
  } catch (e) {
    if (e instanceof Bad) return fail('INVALID_REQUEST', e.message);
    return fail('INTERNAL_ERROR', 'request parsing failed');
  }
}
