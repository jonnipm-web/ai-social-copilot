/**
 * Evidence candidates — IV-IMPACT-I3-EVIDENCE-COLLECTION-01.
 *
 * Extraction produces EVIDENCE CANDIDATES — never evidence, never a fact,
 * never a finding. A candidate points at an artifact version (hash) and a
 * locator, carries a SERVER-extracted excerpt (a client can neither write the
 * excerpt nor forge its location), and waits for human review. Pure.
 *
 * Generation methods:
 *   ANALYST_LOCATOR   the analyst pointed at a locator (+ optional quote that
 *                     must occur there); relationship proposed, not decided
 *   AUTO_VALUE_MATCH  deterministic: a claim's quantity appears in a segment;
 *                     relationship left undecided for the reviewer
 * (LLM_SUGGESTED exists in the vocabulary for a future gate; nothing here
 * calls an LLM.)
 *
 * Privacy guards applied BEFORE anything is persisted:
 *   - e-mail addresses, phone numbers and long personal-id-like digit runs in
 *     an excerpt are redacted (PII_REDACTED);
 *   - an excerpt that looks like personal data about a MINOR (age / birth
 *     date next to a child term) is never persisted (MINOR_DATA_RISK);
 *   - document text is untrusted data: instruction-like content is flagged
 *     for review, never obeyed (safety.ts).
 */
import { ARTIFACT_LIMITS, type ArtifactLocator, type Extraction, type Segment } from './artifact_model.ts';
import { findSegment } from './artifact_extract.ts';
import { normalizeName, normalizeRegistration } from './entity_resolution.ts';
import { fail, ok, type ImpactResult } from './errors.ts';
import { scanUntrustedContent } from './safety.ts';
import type { Claim, OrganizationIdentity } from './types.ts';

export type CandidateMethod = 'ANALYST_LOCATOR' | 'AUTO_VALUE_MATCH' | 'LLM_SUGGESTED';
export type CandidateRelationship = 'SUPPORTS' | 'CONTRADICTS' | 'CONTEXTUALIZES';
export type CandidateReviewReason =
  | 'AUTOMATED_MATCH'
  | 'SUBJECT_NOT_MENTIONED'
  | 'UNTRUSTED_INSTRUCTIONS'
  | 'PII_REDACTED'
  | 'EXCERPT_TRUNCATED'
  | 'FORMULA_CELL'
  | 'EXTRACTION_PARTIAL';

export interface CandidateDraft {
  readonly locator: ArtifactLocator;
  readonly excerpt: string;
  readonly claimRef?: string;
  readonly proposedRelationship?: CandidateRelationship;
  readonly method: CandidateMethod;
  readonly reviewReasons: readonly CandidateReviewReason[];
}

const EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;
// 10+ digits with phone-like separators, optionally international.
const PHONE = /(?:\+\d{1,3}[\s.-]?)?(?:\(\d{1,4}\)[\s.-]?)?\d(?:[\s.-]?\d){9,14}\b/g;
// Long uninterrupted digit runs (national id / account-like), 11+ digits.
const LONG_ID = /\b\d{11,}\b/g;

export function redactPii(text: string): { text: string; redacted: boolean } {
  let redacted = false;
  const out = text.replace(EMAIL, () => { redacted = true; return '[redacted-email]'; })
    .replace(PHONE, (m) => (m.replace(/\D/g, '').length >= 10 ? ((redacted = true), '[redacted-number]') : m))
    .replace(LONG_ID, () => { redacted = true; return '[redacted-number]'; });
  return { text: out, redacted };
}

const MINOR_TERM = /\b(child|children|kid|minor|boy|girl|pupil|student|orphan|criança|crianças|menor|menino|menina|aluno|aluna|órfão|niño|niña)\b/iu;
const AGE_OR_BIRTH = /\b(aged?\s*\d{1,2}|\d{1,2}\s*(?:years?|yrs?)\s*old|\d{1,2}\s*anos(?:\s*de\s*idade)?|idade\s*:?\s*\d{1,2}|born\s+(?:on|in)\b|date of birth|d\.?o\.?b\.?|data de nascimento|nascid[oa]\s+em)\b/iu;

/** Personal data about a minor (not aggregate counts like "10,000 children"). */
export function minorDataRisk(text: string): boolean {
  return MINOR_TERM.test(text) && AGE_OR_BIRTH.test(text);
}

/** Does the excerpt mention the subject (legal / public / trading name, alias or registration)? */
export function subjectMentioned(excerpt: string, identity: OrganizationIdentity): boolean {
  const hay = normalizeName(excerpt);
  const names = [identity.legalName, identity.publicName, ...(identity.aliases ?? []), ...(identity.tradingNames ?? [])]
    .filter((n): n is string => !!n).map(normalizeName).filter((n) => n.length >= 3);
  if (names.some((n) => ` ${hay} `.includes(` ${n} `))) return true;
  const compact = normalizeRegistration(excerpt);
  return (identity.registrations ?? []).some((r) => normalizeRegistration(r.value).length >= 5 && compact.includes(normalizeRegistration(r.value)));
}

function finalize(
  segment: Segment,
  raw: string,
  base: Omit<CandidateDraft, 'excerpt' | 'reviewReasons' | 'locator'> & { reasons: CandidateReviewReason[] },
  identity: OrganizationIdentity,
  extraction: Extraction,
): CandidateDraft | 'MINOR_DATA_RISK' {
  if (minorDataRisk(raw)) return 'MINOR_DATA_RISK';
  const reasons = [...base.reasons];
  let text = raw.replace(/\s+/g, ' ').trim();
  if (text.length > ARTIFACT_LIMITS.maxExcerptChars) { text = text.slice(0, ARTIFACT_LIMITS.maxExcerptChars); reasons.push('EXCERPT_TRUNCATED'); }
  const pii = redactPii(text);
  if (pii.redacted) reasons.push('PII_REDACTED');
  if (scanUntrustedContent(pii.text).flagged) reasons.push('UNTRUSTED_INSTRUCTIONS');
  if (!subjectMentioned(pii.text, identity)) reasons.push('SUBJECT_NOT_MENTIONED');
  if (segment.formula !== undefined) reasons.push('FORMULA_CELL');
  if (extraction.summary.status !== 'SUCCESS') reasons.push('EXTRACTION_PARTIAL');
  const { reasons: _r, ...rest } = base;
  void _r;
  return Object.freeze({ ...rest, locator: segment.locator, excerpt: pii.text, reviewReasons: Object.freeze([...new Set(reasons)].sort()) });
}

/**
 * Analyst-requested candidate: the locator must exist in THIS extraction and
 * an optional quote must occur at that locator (else LOCATOR_INVALID).
 */
export function analystCandidate(
  extraction: Extraction,
  req: { readonly locator: ArtifactLocator; readonly quote?: string; readonly claimRef?: string; readonly proposedRelationship?: CandidateRelationship },
  identity: OrganizationIdentity,
): ImpactResult<CandidateDraft | 'MINOR_DATA_RISK'> {
  const seg = findSegment(extraction, req.locator);
  if (!seg) return fail('LOCATOR_INVALID', 'locator does not address extracted content of this artifact');
  let raw = seg.text;
  if (req.quote !== undefined) {
    const norm = (s: string) => s.replace(/\s+/g, ' ').trim();
    if (!norm(seg.text).includes(norm(req.quote)) || !norm(req.quote)) return fail('LOCATOR_INVALID', 'quote does not occur at the locator');
    raw = norm(req.quote);
  }
  return ok(finalize(seg, raw, {
    method: 'ANALYST_LOCATOR',
    ...(req.claimRef ? { claimRef: req.claimRef } : {}),
    ...(req.proposedRelationship ? { proposedRelationship: req.proposedRelationship } : {}),
    reasons: [],
  }, identity, extraction));
}

function numberForms(v: number): RegExp | null {
  if (!Number.isFinite(v) || v < 0 || v > 1e15) return null;
  const int = Number.isInteger(v);
  const digits = int ? String(v) : String(v).replace('.', '[.,]');
  if (!int) return new RegExp(`(?<![\\d.,])${digits}(?![\\d])`);
  // 20000 also as 20,000 / 20.000 / 20 000
  const grouped = String(v).replace(/\B(?=(\d{3})+(?!\d))/g, '[,.  ]?');
  return new RegExp(`(?<![\\d.,])${grouped}(?![\\d]|[.,]\\d)`);
}

/** Deterministic candidates: a claim's quantity value appears in a segment. */
export function autoCandidates(
  extraction: Extraction,
  claims: readonly Claim[],
  identity: OrganizationIdentity,
): { readonly drafts: readonly CandidateDraft[]; readonly skippedMinorRisk: number } {
  const drafts: CandidateDraft[] = [];
  let skipped = 0;
  const seen = new Set<string>();
  for (const c of claims) {
    if (!c.quantity) continue;
    const re = numberForms(c.quantity.value);
    if (!re) continue;
    for (const seg of extraction.segments) {
      if (drafts.length >= ARTIFACT_LIMITS.maxCandidatesPerArtifact) break;
      const m = re.exec(seg.text);
      if (!m) continue;
      const key = `${c.id}|${JSON.stringify(seg.locator)}`;
      if (seen.has(key)) continue;
      seen.add(key);
      const start = Math.max(0, m.index - 160);
      const window = seg.text.slice(start, m.index + m[0].length + 160);
      const d = finalize(seg, window, { method: 'AUTO_VALUE_MATCH', claimRef: c.id, reasons: ['AUTOMATED_MATCH'] }, identity, extraction);
      if (d === 'MINOR_DATA_RISK') skipped++;
      // The value must survive PII redaction: "20" inside a phone number is not a match.
      else if (re.test(d.excerpt)) drafts.push(d);
    }
  }
  return { drafts, skippedMinorRisk: skipped };
}
