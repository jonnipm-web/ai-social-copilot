/**
 * Investigation workspace — IV-IMPACT-FOUNDATION-01.
 *
 * An Investigation is the isolation unit: one owner (opaque subject ref),
 * optionally bound to one Project, holding claims, sources, evidence,
 * versioned verification results, disputes and an append-only,
 * hash-chained audit trail.
 *
 * Isolation here is a DOMAIN guard (every mutation checks the actor, every
 * claim/evidence checks its investigationId). It is not a substitute for
 * server-side RLS: persistence is out of scope for the Foundation and must
 * arrive with owner/project RLS (IMPACT_SECURITY_MODEL.md §3).
 *
 * Versioning: verification results are appended, never overwritten. A new
 * result supersedes the previous one for that claim; the history stays.
 * Disputes (organization response, correction request, retraction, source
 * update) never delete a record: they add events, can mark sources
 * RETRACTED/UPDATED, and force re-verification. No negative record is
 * immutable-and-final.
 */
import { fail, ok, type ImpactResult } from './errors.ts';
import { isOneOf, isValidId, parseIsoMs, sha256Hex, SOURCE_STATUSES, validateSource } from './provenance.ts';
import type { Claim, EvidenceItem, Source, SourceStatus } from './types.ts';
import { verifyClaim, type VerificationContext, type VerificationResult } from './verification.ts';

export interface Actor {
  /** Opaque subject reference (e.g. hashed user id) — never an e-mail. */
  readonly subjectRef: string;
  /** Projects the actor owns (server-resolved, never client-asserted). */
  readonly projectIds: readonly string[];
}

export type AuditEventType =
  | 'INVESTIGATION_CREATED'
  | 'SOURCE_ADDED'
  | 'CLAIM_CREATED'
  | 'EVIDENCE_ADDED'
  | 'VERIFICATION_RUN'
  | 'STATUS_CHANGED'
  | 'CONFLICT_DETECTED'
  | 'MANUAL_REVIEW'
  | 'DISPUTE_OPENED'
  | 'DISPUTE_RESOLVED'
  | 'SOURCE_STATUS_CHANGED'
  | 'CORRECTION';

export interface AuditEvent {
  readonly seq: number;
  readonly at: string;
  readonly type: AuditEventType;
  readonly actorRef: string;
  readonly investigationId: string;
  /** Ids and codes only — no text, no personal data. */
  readonly refs: readonly string[];
  readonly codes: readonly string[];
  readonly prevHash: string;
  readonly hash: string;
}

export type DisputeKind = 'ORGANIZATION_RESPONSE' | 'CORRECTION_REQUEST' | 'RETRACTION_REQUEST' | 'SOURCE_UPDATE';
export type DisputeResolution = 'CORRECTED' | 'UPHELD' | 'WITHDRAWN' | 'SOURCE_RETRACTED';

export interface Dispute {
  readonly id: string;
  readonly claimId: string;
  readonly kind: DisputeKind;
  readonly openedAt: string;
  readonly submittedEvidenceIds: readonly string[];
  readonly resolution?: DisputeResolution;
  readonly resolvedAt?: string;
}

export interface InvestigationInit {
  readonly id: string;
  readonly subjectOrganizationId: string;
  readonly projectId?: string;
  readonly createdAt: string;
}

const GENESIS = '0'.repeat(64);

export class Investigation {
  readonly id: string;
  readonly ownerRef: string;
  readonly projectId?: string;
  readonly subjectOrganizationId: string;
  readonly #sources = new Map<string, Source>();
  readonly #claims = new Map<string, Claim>();
  readonly #evidence = new Map<string, EvidenceItem>();
  readonly #history = new Map<string, VerificationResult[]>();
  readonly #disputes = new Map<string, Dispute>();
  readonly #audit: AuditEvent[] = [];

  private constructor(init: InvestigationInit, ownerRef: string) {
    this.id = init.id;
    this.ownerRef = ownerRef;
    this.subjectOrganizationId = init.subjectOrganizationId;
    if (init.projectId) this.projectId = init.projectId;
  }

  static async create(actor: Actor, init: InvestigationInit): Promise<ImpactResult<Investigation>> {
    if (!isValidId(init.id) || !isValidId(init.subjectOrganizationId) || !isValidId(actor.subjectRef)) {
      return fail('INVALID_CLAIM', 'invalid investigation init');
    }
    if (parseIsoMs(init.createdAt) === null) return fail('INVALID_CLAIM', 'createdAt required');
    if (init.projectId !== undefined && !actor.projectIds.includes(init.projectId)) {
      return fail('CROSS_INVESTIGATION_DENIED', 'actor does not own the project');
    }
    const inv = new Investigation(init, actor.subjectRef);
    await inv.#log(init.createdAt, 'INVESTIGATION_CREATED', actor, [init.id, init.subjectOrganizationId], []);
    return ok(inv);
  }

  /** Owner-only; if bound to a project, the actor must still own it. */
  authorize(actor: Actor): ImpactResult<true> {
    if (actor.subjectRef !== this.ownerRef) {
      return fail('CROSS_INVESTIGATION_DENIED', 'not the investigation owner', { investigationId: this.id });
    }
    if (this.projectId !== undefined && !actor.projectIds.includes(this.projectId)) {
      return fail('CROSS_INVESTIGATION_DENIED', 'project access revoked', { investigationId: this.id });
    }
    return ok(true);
  }

  async #log(at: string, type: AuditEventType, actor: Actor, refs: string[], codes: string[]): Promise<void> {
    const prevHash = this.#audit.length ? this.#audit[this.#audit.length - 1].hash : GENESIS;
    const seq = this.#audit.length + 1;
    const body = JSON.stringify([seq, at, type, actor.subjectRef, this.id, refs, codes, prevHash]);
    this.#audit.push(Object.freeze({
      seq, at, type, actorRef: actor.subjectRef, investigationId: this.id,
      refs: Object.freeze([...refs]), codes: Object.freeze([...codes]), prevHash, hash: await sha256Hex(body),
    }));
  }

  async addSource(actor: Actor, source: Source, at: string): Promise<ImpactResult<true>> {
    const a = this.authorize(actor);
    if (!a.ok) return a;
    const atMs = parseIsoMs(at);
    if (atMs === null) return fail('INVALID_SOURCE', 'timestamp required');
    if (this.#sources.has(source.id)) return fail('INVALID_SOURCE', 'source already exists (use updateSourceStatus)');
    const v = validateSource(source, atMs);
    if (!v.ok) return v;
    this.#sources.set(source.id, Object.freeze({ ...source }));
    await this.#log(at, 'SOURCE_ADDED', actor, [source.id], [source.type]);
    return ok(true);
  }

  async addClaim(actor: Actor, claim: Claim, at: string): Promise<ImpactResult<true>> {
    const a = this.authorize(actor);
    if (!a.ok) return a;
    if (claim.investigationId !== this.id) return fail('CROSS_INVESTIGATION_DENIED', 'claim belongs to another investigation');
    if (this.#claims.has(claim.id)) return fail('INVALID_CLAIM', 'claim already exists');
    if (!this.#sources.has(claim.sourceId)) return fail('INVALID_CLAIM', 'claim source not in this investigation');
    this.#claims.set(claim.id, Object.freeze({ ...claim }));
    await this.#log(at, 'CLAIM_CREATED', actor, [claim.id, claim.sourceId], [claim.kind, claim.origin]);
    return ok(true);
  }

  async addEvidence(actor: Actor, e: EvidenceItem, at: string): Promise<ImpactResult<true>> {
    const a = this.authorize(actor);
    if (!a.ok) return a;
    if (e.investigationId !== this.id) return fail('CROSS_INVESTIGATION_DENIED', 'evidence belongs to another investigation');
    if (!this.#claims.has(e.claimId)) return fail('INVALID_EVIDENCE', 'unknown claim in this investigation');
    if (!this.#sources.has(e.sourceId)) return fail('INVALID_EVIDENCE', 'unknown source in this investigation');
    if (this.#evidence.has(e.id)) return fail('INVALID_EVIDENCE', 'evidence already exists');
    this.#evidence.set(e.id, Object.freeze({ ...e }));
    await this.#log(at, 'EVIDENCE_ADDED', actor, [e.id, e.claimId, e.sourceId], [e.relationship, e.relationshipBasis]);
    return ok(true);
  }

  async updateSourceStatus(actor: Actor, sourceId: string, status: SourceStatus, at: string): Promise<ImpactResult<string[]>> {
    const a = this.authorize(actor);
    if (!a.ok) return a;
    const s = this.#sources.get(sourceId);
    if (!s) return fail('INVALID_SOURCE', 'unknown source');
    if (!isOneOf(status, SOURCE_STATUSES)) return fail('INVALID_SOURCE', 'unknown source status');
    if (parseIsoMs(at) === null) return fail('INVALID_SOURCE', 'timestamp required');
    this.#sources.set(sourceId, Object.freeze({ ...s, status }));
    const affected = [...this.#evidence.values()].filter((e) => e.sourceId === sourceId).map((e) => e.claimId);
    const claims = [...new Set(affected)].sort();
    await this.#log(at, 'SOURCE_STATUS_CHANGED', actor, [sourceId, ...claims], [status, 'REVERIFICATION_REQUIRED']);
    return ok(claims);
  }

  async verify(actor: Actor, claimId: string, ctx: VerificationContext): Promise<ImpactResult<VerificationResult>> {
    const a = this.authorize(actor);
    if (!a.ok) return a;
    const claim = this.#claims.get(claimId);
    if (!claim) return fail('INVALID_CLAIM', 'unknown claim');
    const evidence = [...this.#evidence.values()].filter((e) => e.claimId === claimId);
    const ids = new Set([claim.sourceId, ...evidence.map((e) => e.sourceId)]);
    const sources = [...ids].map((id) => this.#sources.get(id)!);
    const openDispute = [...this.#disputes.values()].some((d) => d.claimId === claimId && !d.resolution);
    const r = await verifyClaim({ claim, evidence, sources }, { ...ctx, openDispute: ctx.openDispute || openDispute });
    if (!r.ok) return r;
    const hist = this.#history.get(claimId) ?? [];
    const prev = hist[hist.length - 1];
    hist.push(r.value);
    this.#history.set(claimId, hist);
    await this.#log(ctx.evaluatedAt, 'VERIFICATION_RUN', actor, [claimId, r.value.resultId], [r.value.status, r.value.policyVersion]);
    if (prev && prev.status !== r.value.status) {
      await this.#log(ctx.evaluatedAt, 'STATUS_CHANGED', actor, [claimId, prev.resultId, r.value.resultId], [prev.status, r.value.status]);
    }
    if (r.value.conflicts.length > 0) {
      await this.#log(ctx.evaluatedAt, 'CONFLICT_DETECTED', actor, [claimId], r.value.conflicts.map((c) => c.kind));
    }
    if (ctx.humanReview && r.value.reviewState === 'HUMAN_REVIEWED') {
      await this.#log(ctx.evaluatedAt, 'MANUAL_REVIEW', actor, [claimId, ctx.humanReview.reviewerRef], ['HUMAN_REVIEWED']);
    }
    return r;
  }

  async openDispute(actor: Actor, d: Omit<Dispute, 'resolution' | 'resolvedAt'>): Promise<ImpactResult<true>> {
    const a = this.authorize(actor);
    if (!a.ok) return a;
    if (!this.#claims.has(d.claimId)) return fail('INVALID_CLAIM', 'unknown claim');
    if (!isValidId(d.id) || this.#disputes.has(d.id)) return fail('INVALID_CLAIM', 'invalid or duplicate dispute id');
    for (const id of d.submittedEvidenceIds) if (!this.#evidence.has(id)) return fail('INVALID_EVIDENCE', 'unknown evidence');
    this.#disputes.set(d.id, Object.freeze({ ...d, submittedEvidenceIds: Object.freeze([...d.submittedEvidenceIds]) }));
    await this.#log(d.openedAt, 'DISPUTE_OPENED', actor, [d.id, d.claimId, ...d.submittedEvidenceIds], [d.kind]);
    return ok(true);
  }

  async resolveDispute(actor: Actor, id: string, resolution: DisputeResolution, at: string): Promise<ImpactResult<true>> {
    const a = this.authorize(actor);
    if (!a.ok) return a;
    const d = this.#disputes.get(id);
    if (!d || d.resolution) return fail('INVALID_CLAIM', 'unknown or already resolved dispute');
    this.#disputes.set(id, Object.freeze({ ...d, resolution, resolvedAt: at }));
    await this.#log(at, 'DISPUTE_RESOLVED', actor, [id, d.claimId], [resolution, 'REVERIFICATION_REQUIRED']);
    if (resolution === 'CORRECTED') await this.#log(at, 'CORRECTION', actor, [d.claimId], ['CORRECTED']);
    return ok(true);
  }

  // ── Read models (frozen copies) ──────────────────────────────────────────
  history(claimId: string): readonly VerificationResult[] {
    return Object.freeze([...(this.#history.get(claimId) ?? [])]);
  }
  latest(claimId: string): VerificationResult | undefined {
    const h = this.#history.get(claimId);
    return h?.[h.length - 1];
  }
  claims(): readonly Claim[] {
    return Object.freeze([...this.#claims.values()]);
  }
  sources(): readonly Source[] {
    return Object.freeze([...this.#sources.values()]);
  }
  evidence(): readonly EvidenceItem[] {
    return Object.freeze([...this.#evidence.values()]);
  }
  disputes(): readonly Dispute[] {
    return Object.freeze([...this.#disputes.values()]);
  }
  auditTrail(): readonly AuditEvent[] {
    return Object.freeze([...this.#audit]);
  }
}

/** Recomputes the hash chain; any edited, dropped or reordered event fails. */
export async function verifyAuditChain(events: readonly AuditEvent[]): Promise<boolean> {
  let prev = GENESIS;
  for (let i = 0; i < events.length; i++) {
    const e = events[i];
    if (e.seq !== i + 1 || e.prevHash !== prev) return false;
    const body = JSON.stringify([e.seq, e.at, e.type, e.actorRef, e.investigationId, e.refs, e.codes, e.prevHash]);
    if ((await sha256Hex(body)) !== e.hash) return false;
    prev = e.hash;
  }
  return true;
}
