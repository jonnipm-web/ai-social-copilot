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
 *     for review, never obeyed (safety.ts); invisible / bidi characters are
 *     dropped and homoglyphs folded before the scan;
 *   - quoted accusations / endorsements are flagged (VERDICT_LANGUAGE) and
 *     always returned as attributed quotes, never as platform statements;
 *   - IBANs, obfuscated e-mails and formatted national ids are redacted;
 *     names and street addresses cannot be detected deterministically — the
 *     reviewer must classify personal data before any promotion.
 */
import { ARTIFACT_LIMITS, type ArtifactLocator, type Extraction, type Segment } from './artifact_model.ts';
import { findSegment } from './artifact_extract.ts';
import { normalizeName, normalizeRegistration } from './entity_resolution.ts';
import { fail, ok, type ImpactResult } from './errors.ts';
import { findVerdictLanguage, scanUntrustedContent } from './safety.ts';
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
  | 'EXTRACTION_PARTIAL'
  | 'VERDICT_LANGUAGE';

export interface CandidateDraft {
  readonly locator: ArtifactLocator;
  readonly excerpt: string;
  readonly claimRef?: string;
  readonly proposedRelationship?: CandidateRelationship;
  readonly method: CandidateMethod;
  readonly reviewReasons: readonly CandidateReviewReason[];
}

const EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;
// "john [at] example [dot] com", "john (at) example dot org"
const EMAIL_OBFUSCATED = /[A-Za-z0-9._%+-]+\s*[[(]?\s*(?:at|arroba)\s*[\])]?\s*[A-Za-z0-9-]+(?:\s*[[(]?\s*(?:dot|ponto)\s*[\])]?\s*[A-Za-z]{2,})+/gi;
// IBAN: 2 letters, 2 check digits, 11–30 alphanumerics in optional groups of 4.
const IBAN = /(?<![A-Za-z0-9])[A-Z]{2}\d{2}(?:[ -]?[A-Z0-9]{4}){2,7}(?:[ -]?[A-Z0-9]{1,4})?(?![A-Za-z0-9])/g;
// Formatted national ids: CPF 000.000.000-00, CNPJ 00.000.000/0000-00, SSN 000-00-0000.
const FORMATTED_ID = /(?<!\d)(?:\d{3}\.\d{3}\.\d{3}-\d{2}|\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2}|\d{3}-\d{2}-\d{4})(?!\d)/g;
// 10+ digits with phone-like separators, optionally international.
const PHONE = /(?:\+\d{1,3}[\s.-]?)?(?:\(\d{1,4}\)[\s.-]?)?\d(?:[\s.-]?\d){9,14}(?!\d)/g;
// Long uninterrupted digit runs (national id / account-like), 11+ digits.
const LONG_ID = /(?<!\d)\d{11,}(?!\d)/g;

export function redactPii(text: string): { text: string; redacted: boolean } {
  let redacted = false;
  const hit = (tag: string) => () => { redacted = true; return tag; };
  // I6 (Codex I6G1R-03): the e-mail patterns backtrack quadratically on long
  // runs with no '@' / no "at": run them only when they can match.
  let out = text;
  if (text.includes('@')) out = out.replace(EMAIL, hit('[redacted-email]'));
  if (/(?:at|arroba)[\s\])]*[A-Za-z0-9-]+[\s[(]*(?:dot|ponto)/i.test(out)) out = out.replace(EMAIL_OBFUSCATED, hit('[redacted-email]'));
  out = out
    .replace(IBAN, hit('[redacted-account]'))
    .replace(FORMATTED_ID, hit('[redacted-id]'))
    .replace(PHONE, (m) => (m.replace(/\D/g, '').length >= 10 ? ((redacted = true), '[redacted-number]') : m))
    .replace(LONG_ID, hit('[redacted-number]'));
  return { text: out, redacted };
}

const W = '(?<![\\p{L}\\p{N}])';
const E = '(?![\\p{L}\\p{N}])';
const MINOR_TERM = new RegExp(`${W}(child|children|kid|kids|minor|boy|girl|pupil|student|orphan|teenager|toddler|infant|baby|criança|crianças|menor|menino|menina|aluno|aluna|órfão|órfã|bebê|adolescente|niño|niña|niños|niñas|menor de edad|huérfano|huérfana|alumno|alumna)${E}`, 'iu');
// Ages written as words (1–17) in EN / PT / ES.
const AGE_WORDS = 'one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen'
  + '|um|uma|dois|duas|três|tres|quatro|cinco|seis|sete|oito|nove|dez|onze|doze|treze|catorze|quatorze|quinze|dezesseis|dezessete'
  + '|uno|dos|cuatro|siete|ocho|nueve|diez|doce|trece|dieciséis|dieciseis|diecisiete';
const AGE = `(?:\\d{1,2}|${AGE_WORDS})`;
const AGE_OR_BIRTH = new RegExp(`${W}(aged?\\s*${AGE}${E}|${AGE}\\s*(?:-\\s*)?(?:years?|yrs?)(?:\\s*-\\s*|\\s+)old|${AGE}\\s*anos(?:\\s*de\\s*idade)?${E}|${AGE}\\s*años(?:\\s*de\\s*edad)?${E}|tem\\s+${AGE}\\s*anos|idade\\s*:?\\s*${AGE}${E}|edad\\s*:?\\s*${AGE}${E}|born\\s+(?:on|in)${E}|date of birth|d\\.?o\\.?b\\.?|data de nascimento|fecha de nacimiento|nacid[oa]\\s+el|nascid[oa]\\s+em|nasceu\\s+em|naci[oó]\\s+(?:el|en))`, 'iu');

/** Personal data about a minor (not aggregate counts like "10,000 children"). */
export function minorDataRisk(text: string): boolean {
  return MINOR_TERM.test(text) && AGE_OR_BIRTH.test(text);
}

const escapeRe = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/**
 * Does the excerpt mention the subject (legal / public / trading name, alias
 * or registration)? Conservative (Codex I3G3-03): a name occurrence glued to
 * another capitalized word ("HopeBridge Foundation International",
 * "Global HopeBridge") may be ANOTHER organization and does not count.
 */
export function subjectMentioned(excerpt: string, identity: OrganizationIdentity): boolean {
  const names = [identity.legalName, identity.publicName, ...(identity.aliases ?? []), ...(identity.tradingNames ?? [])]
    .filter((n): n is string => !!n && normalizeName(n).length >= 3);
  const flat = excerpt.normalize('NFKC');
  for (const n of names) {
    const tokens = n.normalize('NFKC').split(/[^\p{L}\p{N}]+/u).filter(Boolean).map(escapeRe);
    if (!tokens.length) continue;
    const re = new RegExp(`${W}${tokens.join('[^\\p{L}\\p{N}]+')}${E}`, 'giu');
    for (const m of flat.matchAll(re)) {
      const before = flat.slice(Math.max(0, m.index! - 40), m.index!);
      const after = flat.slice(m.index! + m[0].length, m.index! + m[0].length + 40);
      const gluedAfter = /^[ \t]+\p{Lu}/u.test(after) || /^['’]?s?[ \t]+(?:International|Global|Group|Trust|Holdings?|Inc|Ltd|LLC|Foundation|Fund|UK|USA|Brasil|Brazil)(?![\p{L}])/u.test(after);
      const gluedBefore = /\p{Lu}[\p{L}\p{N}]*[ \t]+$/u.test(before) && !/[.!?:;][ \t]+\p{Lu}[\p{L}\p{N}]*[ \t]+$/u.test(before) && !/^\s*\p{Lu}[\p{L}\p{N}]*[ \t]+$/u.test(before);
      if (!gluedAfter && !gluedBefore) return true;
    }
  }
  const compact = normalizeRegistration(excerpt);
  return (identity.registrations ?? []).some((r) => normalizeRegistration(r.value).length >= 5 && compact.includes(normalizeRegistration(r.value)));
}

// Invisible / bidi characters are dropped from stored excerpts and from the
// injection scan; common Cyrillic/Greek confusables are folded to Latin for
// the scan only (Codex I3G3-04).
const INVISIBLE = new RegExp(`[${[0x200b, 0x200c, 0x200d, 0x200e, 0x200f, 0x202a, 0x202b, 0x202c, 0x202d, 0x202e, 0x2060, 0x2066, 0x2067, 0x2068, 0x2069, 0xfeff, 0x00ad]
  .map((c) => String.fromCharCode(c)).join('')}]`, 'g');
const CONFUSABLES: ReadonlyMap<string, string> = new Map(Object.entries({
  'а': 'a', 'е': 'e', 'о': 'o', 'р': 'p', 'с': 'c', 'у': 'y', 'х': 'x', 'і': 'i', 'ј': 'j', 'ѕ': 's', 'к': 'k', 'м': 'm', 'т': 't', 'в': 'b', 'н': 'h',
  'А': 'A', 'Е': 'E', 'О': 'O', 'Р': 'P', 'С': 'C', 'Т': 'T', 'Х': 'X', 'К': 'K', 'М': 'M', 'В': 'B', 'Н': 'H', 'І': 'I',
  'α': 'a', 'ε': 'e', 'ο': 'o', 'ρ': 'p', 'ι': 'i', 'κ': 'k', 'ν': 'v', 'τ': 't', 'υ': 'u', 'χ': 'x', 'Ο': 'O', 'Α': 'A', 'Ε': 'E',
}));
const MIXED_SCRIPT_WORD = /(?=[\p{L}]*\p{Script=Latin})(?=[\p{L}]*[\p{Script=Cyrillic}\p{Script=Greek}])[\p{L}]{2,}/u;

function scanText(text: string): { flagged: boolean } {
  const folded = [...text.normalize('NFKC')].map((c) => CONFUSABLES.get(c) ?? c).join('').normalize('NFKD').replace(/\p{M}+/gu, '');
  return { flagged: MIXED_SCRIPT_WORD.test(text) || scanUntrustedContent(folded).flagged };
}

function finalize(
  segment: Segment,
  raw: string,
  base: Omit<CandidateDraft, 'excerpt' | 'reviewReasons' | 'locator'> & { reasons: CandidateReviewReason[] },
  identity: OrganizationIdentity,
  extraction: Extraction,
): CandidateDraft | 'MINOR_DATA_RISK' {
  const visible = raw.replace(INVISIBLE, '');
  if (minorDataRisk(visible)) return 'MINOR_DATA_RISK';
  const reasons = [...base.reasons];
  let text = visible.replace(/\s+/g, ' ').trim();
  if (text.length > ARTIFACT_LIMITS.maxExcerptChars) { text = text.slice(0, ARTIFACT_LIMITS.maxExcerptChars); reasons.push('EXCERPT_TRUNCATED'); }
  const pii = redactPii(text);
  if (pii.redacted) reasons.push('PII_REDACTED');
  if (scanText(pii.text).flagged) reasons.push('UNTRUSTED_INSTRUCTIONS');
  // Quoted source text may accuse or praise: flagged, never repeated as a platform statement (Codex I3G3-05).
  if (findVerdictLanguage(pii.text).length > 0) reasons.push('VERDICT_LANGUAGE');
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
  // Not part of a date, time, range, id, phone, percentage or signed value
  // (Codex I3G3-01): "20/05/2025", "10:20", "2019-20", "#20", "+20", "20%".
  const notBefore = '(?<![\\d.,#+])(?<!\\d[/:-])';
  const notAfter = '(?![\\d]|[.,]\\d|[/:-]\\d|\\s?%)';
  if (!int) return new RegExp(`${notBefore}${digits}${notAfter}`);
  // 20000 also as 20,000 / 20.000 / 20 000
  const grouped = String(v).replace(/\B(?=(\d{3})+(?!\d))/g, '[,.  ]?');
  return new RegExp(`${notBefore}${grouped}${notAfter}`);
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
