/**
 * Impact domain model — IV-IMPACT-FOUNDATION-01.
 *
 * Pure types. No network, no env, no clock, no LLM. Every timestamp is an
 * ISO-8601 string supplied by the caller; the engine never reads the wall
 * clock (reproducibility).
 *
 * The central separation (docs/impact/IMPACT_DOMAIN_MODEL.md):
 *   FACT · CLAIM · EVIDENCE · INFERENCE · ALLEGATION · CONFLICT · UNKNOWN ·
 *   ABSENCE_OF_EVIDENCE
 * An organization's self-declaration is a CLAIM, a news allegation is an
 * ALLEGATION, and missing evidence is ABSENCE_OF_EVIDENCE — none of them is
 * a FACT, and none of them is ever rendered as a verdict.
 */

// ── Epistemic classes ───────────────────────────────────────────────────────

export type EpistemicClass =
  | 'FACT' //               established by an authoritative source within its scope
  | 'CLAIM' //              an assertion made by someone (claimant recorded)
  | 'EVIDENCE' //           material that relates to a claim
  | 'INFERENCE' //          derived by the system; always labelled as such
  | 'ALLEGATION' //         an accusation not established by an authority
  | 'CONFLICT' //           sources disagree; no side is chosen
  | 'UNKNOWN' //            not determined
  | 'ABSENCE_OF_EVIDENCE'; // nothing found — NOT evidence of wrongdoing

// ── Jurisdiction ────────────────────────────────────────────────────────────

/** Never hardcoded to one country. `country` is ISO 3166-1 alpha-2;
 * `subdivision` optional (e.g. ISO 3166-2). A registry lookup in one
 * jurisdiction says nothing about legality in another. */
export interface Jurisdiction {
  readonly country: string;
  readonly subdivision?: string;
  readonly registry?: string; //                e.g. "fixture-charity-registry"
  readonly legalFrameworkRef?: string; //       free reference when known
}

// ── Organization ────────────────────────────────────────────────────────────

export type OrganizationType =
  | 'CHARITY'
  | 'NGO'
  | 'NONPROFIT'
  | 'FOUNDATION'
  | 'SOCIAL_ENTERPRISE'
  | 'RELIGIOUS_ORGANIZATION'
  | 'COMMUNITY_PROJECT'
  | 'CROWDFUNDING_CAMPAIGN'
  | 'INFORMAL_INITIATIVE'
  | 'OTHER';

export interface RegistrationIdentifier {
  readonly jurisdiction: Jurisdiction;
  /** Kind of identifier inside that jurisdiction (charity number, company
   * number, tax id…). Free text: the model does not assume one legislation. */
  readonly scheme: string;
  readonly value: string;
}

/** A name the organization legally held for a period (I2). Knowing a former
 * name never merges two entities by itself: identity is the registration. */
export interface FormerName {
  readonly name: string;
  readonly from?: string; // ISO date, inclusive
  readonly to?: string; //   ISO date, exclusive (the day the new name took effect)
}

/** A textual name is never identity. Identity is the set of identifiers;
 * every field is optional because informal initiatives may have none. */
export interface OrganizationIdentity {
  readonly legalName?: string;
  readonly publicName?: string;
  readonly aliases?: readonly string[];
  /** Registry-declared former legal names with their validity periods (I2). */
  readonly formerNames?: readonly FormerName[];
  /** Registry-declared trading / working names (I2). */
  readonly tradingNames?: readonly string[];
  readonly registrations?: readonly RegistrationIdentifier[];
  readonly domains?: readonly string[];
  readonly jurisdictions?: readonly Jurisdiction[];
}

export interface Organization {
  readonly id: string;
  readonly type: OrganizationType;
  readonly identity: OrganizationIdentity;
  readonly mission?: string;
}

// ── Project / Campaign ──────────────────────────────────────────────────────

export interface Period {
  readonly from?: string; // ISO date
  readonly to?: string; //   ISO date
}

export interface Location {
  /** Deliberately coarse: country/region only. Precise locations of
   * beneficiaries (especially minors) are out of scope by design. */
  readonly country: string;
  readonly region?: string;
}

export interface ImpactProject {
  readonly id: string;
  readonly organizationId: string;
  readonly name: string;
  readonly location?: Location;
  readonly period?: Period;
  readonly objectives?: readonly string[];
}

/** Affiliation is never inferred from a logo or a similar name. */
export type Affiliation = 'VERIFIED_AFFILIATION' | 'CLAIMED_AFFILIATION' | 'UNKNOWN_AFFILIATION';

export type CampaignOperator = 'OFFICIAL' | 'THIRD_PARTY' | 'UNKNOWN';

export interface Campaign {
  readonly id: string;
  readonly name: string;
  readonly claimedOrganizationId?: string;
  readonly projectId?: string;
  readonly operator: CampaignOperator;
  readonly affiliation: Affiliation;
  /** Evidence ids that justify VERIFIED_AFFILIATION (required for it). */
  readonly affiliationEvidenceIds?: readonly string[];
  readonly domains?: readonly string[];
}

// ── Sources ─────────────────────────────────────────────────────────────────

export type SourceType =
  | 'OFFICIAL_REGISTRY'
  | 'ORGANIZATION_WEBSITE'
  | 'GOVERNMENT_RECORD'
  | 'FINANCIAL_REPORT'
  | 'AUDITED_REPORT'
  | 'COURT_RECORD'
  | 'REGULATOR'
  | 'NEWS'
  | 'ACADEMIC'
  | 'NGO_DATABASE'
  | 'SOCIAL_MEDIA'
  | 'USER_DOCUMENT'
  | 'OTHER';

/** For NEWS: reporting ≠ opinion ≠ allegation ≠ correction. */
export type NewsGenre = 'REPORTING' | 'OPINION' | 'ALLEGATION' | 'CORRECTION';

export type SourceStatus = 'ACTIVE' | 'UPDATED' | 'RETRACTED' | 'UNAVAILABLE';

/** How much of the source the platform keeps (IMPACT_SOURCE_MODEL.md §4). */
export type RetentionMode = 'REFERENCE_ONLY' | 'HASH_ONLY' | 'EXCERPT_AND_HASH' | 'SNAPSHOT';

/**
 * How the platform obtained the source. Only material fetched by a TRUSTED
 * provider declared for that source type (and jurisdiction) can be
 * independent/authoritative: a source's `type` and `publisher` are otherwise
 * just labels someone typed, and a self-published report relabelled as an
 * "audit" must not become independent evidence (Codex G1-01).
 */
export type Acquisition =
  | { readonly method: 'PROVIDER'; readonly providerId: string }
  | { readonly method: 'USER_UPLOAD' }
  | { readonly method: 'ANALYST_ENTRY' };

/** A provider the server trusts for one source type (from provider.ts
 * descriptors; never from the client). */
export interface TrustedProviderRef {
  readonly id: string;
  readonly sourceType: SourceType;
  /** ISO 3166-1 alpha-2 codes the provider covers. */
  readonly jurisdictions: readonly string[];
  /** The provider publishes its OWN primary records (a statutory register,
   * a court's own docket): material it serves is ORIGINAL by provenance —
   * the only way independence is ever established positively (I2, CF-04). */
  readonly primaryPublisher: boolean;
  /** Upstream origin (I2G2-06): two providers serving the same upstream records
   * (e.g. an API and a bulk dump of one register) share an originId and count
   * as ONE voice. Defaults to the provider id. */
  readonly originId?: string;
}

export interface Source {
  readonly id: string;
  readonly type: SourceType;
  readonly publisher: string;
  /** Organization id when the publisher IS an organization under
   * investigation — makes its material self-reported for that organization. */
  readonly publisherOrganizationId?: string;
  /** Reference only. The Foundation never fetches it; see provenance.ts. */
  readonly uri?: string;
  readonly retrievedAt: string;
  readonly publishedAt?: string;
  readonly jurisdiction?: Jurisdiction;
  readonly newsGenre?: NewsGenre;
  readonly status: SourceStatus;
  readonly retention: RetentionMode;
  /** SHA-256 hex of the retrieved content when retention ≠ REFERENCE_ONLY. */
  readonly contentHash?: string;
  readonly acquisition: Acquisition;
  /** Original publisher when this is a syndicated/wire copy (set by the
   * provider). Affects COUNTING only: a republished story is never a second
   * independent voice. It never removes evidence (Codex CF-04, FV2-02). */
  readonly syndicatedFrom?: string;
  /** Uploaded by a user — never a verified fact by itself. */
  readonly userSubmitted?: boolean;
  // ── Lineage (IV-IMPACT-I2, source_lineage.ts). All SERVER-derived from the
  // submitted content; a client can never set them directly. They can only
  // MERGE voices (lower corroboration), never create independence.
  /** Other source/publisher this material is based on (cites / summarizes). */
  readonly derivedFrom?: string;
  /** sha-256 of the deterministically normalized content text. */
  readonly contentFingerprint?: string;
  /** Near-duplicate sketch (MinHash, 32 × uint32 hex) of the content text. */
  readonly similaritySketch?: string;
  /** Explicit syndication signals found in the content (wire credit, "via"…). */
  readonly syndicationMarkers?: readonly SyndicationMarker[];
}

/** Explicit syndication signals (source_lineage.ts). A marker is a SIGNAL,
 * never proof: it produces POSSIBLE lineage (merge-only), not a finding. */
export type SyndicationMarker =
  | 'WIRE_REUTERS'
  | 'WIRE_AP'
  | 'WIRE_AFP'
  | 'VIA_CREDIT'
  | 'ORIGINALLY_PUBLISHED'
  | 'REPUBLISHED_FROM';

// ── Claims ──────────────────────────────────────────────────────────────────

export type ClaimKind =
  | 'LEGAL_REGISTRATION'
  | 'OPERATING_HISTORY' //      "active since 2010"
  | 'FINANCIAL' //              revenue, spending, "90% reaches beneficiaries"
  | 'IMPACT_OUTPUT' //          "20 wells built"
  | 'IMPACT_OUTCOME' //         "child malnutrition fell 30%"
  | 'BENEFICIARY_COUNT' //      "we serve 10,000 children" (aggregate only)
  | 'AFFILIATION' //            "this campaign belongs to X"
  | 'GOVERNANCE'
  | 'REGULATORY_STATUS'
  | 'OTHER';

/** Impact chain (IMPACT_DOMAIN_MODEL.md §9): outputs are not impact. */
export type ImpactLevel = 'INPUT' | 'ACTIVITY' | 'OUTPUT' | 'OUTCOME' | 'IMPACT';

export interface Quantity {
  readonly metric: string; // normalized key, e.g. "wells_built"
  readonly value: number;
  readonly unit: string; //  e.g. "count", "GBP"
}

export type ClaimOrigin = 'MANUAL' | 'STRUCTURED_IMPORT' | 'LLM_EXTRACTED' | 'REGISTRY_IMPORT';
// REGISTRY_IMPORT (I2, Codex I2F2-01): SERVER-ONLY — a registry statement
// generated by import_registry_claim. Not representable in the client contract.

export interface Claim {
  readonly id: string;
  readonly investigationId: string;
  readonly kind: ClaimKind;
  /** Original text, never overwritten by a translation. */
  readonly text: string;
  readonly textLanguage?: string;
  readonly quantity?: Quantity;
  readonly level?: ImpactLevel;
  /** Who asserted it (organization id or free publisher label). */
  readonly claimantOrganizationId?: string;
  readonly claimantLabel?: string;
  /** What it is about. */
  readonly subjectOrganizationId: string;
  readonly subjectProjectId?: string;
  readonly subjectCampaignId?: string;
  readonly period?: Period;
  readonly sourceId: string; // where the claim was made
  readonly extractedAt: string;
  readonly origin: ClaimOrigin;
}

// ── Evidence ────────────────────────────────────────────────────────────────

export type EvidenceRelationship = 'SUPPORTS' | 'CONTRADICTS' | 'CONTEXTUALIZES';

/** Who decided the relationship. An LLM suggestion is never counted as
 * support or contradiction until confirmed (IMPACT_EVIDENCE_MODEL.md §3). */
export type RelationshipBasis = 'STRUCTURED_MATCH' | 'HUMAN_ASSESSED' | 'LLM_SUGGESTED' | 'REGISTRY_RECORD';
// REGISTRY_RECORD (I2): evidence generated by the SERVER from a trusted
// provider's registry snapshot for a registry-statement claim
// (registry_claims.ts). Never accepted from a client.

/** Personal-data classification is mandatory on every evidence item. */
export type PersonalDataClass =
  | 'NONE'
  | 'AGGREGATED'
  | 'PUBLIC_OFFICIAL_ROLE' // named trustee/director in an official register
  | 'PERSONAL' //            identifiable private individual
  | 'SENSITIVE' //           health, religion, etc.
  | 'MINOR'; //              anything identifying a child

/** Exact procedural stage — never collapsed into guilt. */
export type LegalStage =
  | 'INVESTIGATION_OPENED'
  | 'CHARGED'
  | 'CONVICTED'
  | 'ACQUITTED'
  | 'DISMISSED'
  | 'SANCTIONED'
  | 'SETTLED'
  | 'UNDER_APPEAL'
  | 'OVERTURNED'
  | 'CLOSED_NO_ACTION';

export interface EvidenceLocator {
  readonly page?: number;
  readonly section?: string;
  readonly charStart?: number;
  readonly charEnd?: number;
}

export interface EvidenceItem {
  readonly id: string;
  readonly investigationId: string;
  readonly claimId: string;
  readonly sourceId: string;
  /** Entity this evidence is actually about (after entity resolution). */
  readonly aboutOrganizationId: string;
  readonly relationship: EvidenceRelationship;
  readonly relationshipBasis: RelationshipBasis;
  /** Structured value reported by the source, for deterministic comparison. */
  readonly reportedQuantity?: Quantity;
  readonly level?: ImpactLevel;
  /** When the state described by the evidence held (not when retrieved). */
  readonly observedPeriod?: Period;
  readonly excerpt?: string;
  readonly excerptHash?: string;
  readonly locator?: EvidenceLocator;
  readonly personalData: PersonalDataClass;
  readonly legalStage?: LegalStage;
  readonly addedAt: string;
}

// ── Verification ────────────────────────────────────────────────────────────

export type ClaimStatus =
  | 'UNVERIFIED'
  | 'SUPPORTED'
  | 'PARTIALLY_SUPPORTED'
  | 'CONTRADICTED'
  | 'INCONCLUSIVE'
  | 'OUTDATED'
  | 'DISPUTED';

export type EvidenceSufficiency =
  | 'NO_EVIDENCE'
  | 'SELF_REPORTED'
  | 'SINGLE_SOURCE'
  | 'INDEPENDENT_SUPPORT'
  | 'MULTI_SOURCE_SUPPORT'
  | 'CONFLICTING_EVIDENCE';

export type ReviewState = 'AUTOMATED' | 'REVIEW_REQUIRED' | 'HUMAN_REVIEWED';

export type GapCode =
  | 'NO_EVIDENCE'
  | 'NO_INDEPENDENT_SOURCE'
  | 'ONLY_SELF_REPORTED'
  | 'EVIDENCE_OUTDATED'
  | 'PERIOD_NOT_COVERED'
  | 'IDENTITY_UNCONFIRMED'
  | 'OUT_OF_AUTHORITY_SCOPE'
  | 'UNCONFIRMED_LLM_LINKS'
  | 'LEVEL_MISMATCH'
  | 'UNITS_NOT_COMPARABLE'
  | 'SOURCE_RETRACTED'
  | 'SOURCE_CHANGED'
  | 'SOURCE_UNAVAILABLE'
  | 'ALLEGATION_UNRESOLVED'
  | 'UNTRUSTED_INSTRUCTIONS_DETECTED'
  // I2 — lineage / independence (source_lineage.ts)
  | 'INDEPENDENCE_NOT_ESTABLISHED' // counted sources exist but none is a positively established original
  | 'POSSIBLE_LINEAGE'; //           a similarity/marker signal links counted sources (merged, review)

export type ExclusionReason =
  | 'OUT_OF_AUTHORITY_SCOPE'
  | 'ENTITY_MISMATCH'
  | 'STALE'
  | 'PERIOD_MISMATCH'
  | 'LEVEL_MISMATCH'
  | 'UNITS_NOT_COMPARABLE'
  | 'UNCONFIRMED_LLM_LINK'
  | 'SOURCE_RETRACTED'
  | 'SOURCE_CHANGED'
  | 'SOURCE_UNAVAILABLE'
  | 'DUPLICATE_CONTENT';

export interface ConflictRecord {
  readonly claimId: string;
  readonly kind: 'QUANTITY_DISAGREEMENT' | 'SUPPORT_VS_CONTRADICTION';
  /** INDEPENDENT_SOURCES: independent sources disagree (CONCERN-worthy).
   * SELF_REPORTED_ONLY: the organization's own materials disagree with its
   * claim — often a correction; shown as an information gap, never a concern.
   * SAME_PUBLISHER: the disagreeing positions come from ONE publisher
   * identity (e.g. a report and its later correction, or a wire copy) —
   * inconclusive + review, information gap, never a concern (Codex FV-01). */
  readonly basis: 'INDEPENDENT_SOURCES' | 'SAME_PUBLISHER' | 'SELF_REPORTED_ONLY';
  /** Every position, side by side, with its source — no winner chosen. */
  readonly positions: readonly {
    readonly evidenceId: string;
    readonly sourceId: string;
    readonly publisher: string;
    readonly relationship: EvidenceRelationship;
    readonly reportedValue?: number;
  }[];
  readonly resolution: 'UNRESOLVED';
}
