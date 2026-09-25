/**
 * Presentation privacy — IV-IMPACT-I6-PRIVACY-PHYSICAL-VALIDATION-01
 * (closes Codex I5F-03).
 *
 * Impact is ORGANIZATION intelligence, never people intelligence. Every
 * free-text value leaving the server in a dossier (live view, export,
 * snapshot, human-readable text) passes through `present()` with the
 * SEMANTICS of its field. Stored evidence is never modified: this is a
 * presentation boundary only (stored evidence ≠ safe presentation).
 *
 * Policy (fail-closed):
 *  - minor-data risk ⇒ WITHHELD (MINOR_DATA_RISK), in every field;
 *  - structured personal identifiers (e-mail, phone, IBAN / bank account,
 *    payment card, formatted national / tax ids, long digit runs) ⇒ REDACTED
 *    in every field;
 *  - free text that may be ABOUT people (claim text, evidence excerpts):
 *    any private-name or private-address signal ⇒ the whole text is
 *    WITHHELD (PERSONAL_DATA_RISK). Only names from TRUSTED origins (the
 *    subject's declared identity, official registry snapshots) are exempt —
 *    never client-entered publisher names;
 *  - organization identity (declared identity, official registry name):
 *    organizational information, structured redaction only;
 *  - publisher names of sources that may be a private person
 *    (SOCIAL_MEDIA, OTHER) ⇒ WITHHELD unless the name is an organization
 *    on record;
 *  - URLs ⇒ origin only (scheme + host); paths and queries can carry
 *    personal handles, names or tokens and are never presented.
 *
 * HONEST LIMIT: private names and addresses cannot be detected universally
 * by any deterministic rule. The detectors below are deliberately
 * HIGH-RECALL SIGNALS, not a promise: when in doubt they withhold (and a
 * limitation says so). A name written in a way no signal matches (e.g. a
 * single lower-case word) can still pass; that residual is documented in
 * IMPACT_PRIVACY_MODEL.md and is bounded by the evidence reviewer's
 * mandatory personal-data classification (PERSONAL / SENSITIVE / MINOR are
 * not even representable in the Lab contract).
 */
import { minorDataRisk, redactPii } from './evidence_candidates.ts';

export const PRIVACY_POLICY_VERSION = 'impact-privacy/1';

export type WithheldReason = 'MINOR_DATA_RISK' | 'PERSONAL_DATA_RISK';

export interface Presented {
  readonly text: string | null;
  readonly withheld: WithheldReason | null;
  readonly redacted: boolean;
}

/** What a field IS decides how it may be presented. */
export type FieldKind =
  | 'FREE_TEXT' //          claim text, evidence excerpt: may be about people
  | 'ORGANIZATION_NAME' //  declared identity, official registry name
  | 'PUBLISHER'; //         source publisher / lineage names

/** Source types whose publisher may be a private individual. */
const PERSONAL_PUBLISHER_TYPES = new Set(['SOCIAL_MEDIA', 'OTHER']);

// ── structured identifiers not covered by redactPii ─────────────────────────
// Payment cards: 13–19 digits in groups, validated by Luhn.
const CARD = /(?<!\d)\d(?:[ -]?\d){12,18}(?!\d)/g;
// UK sort code + account, "12-34-56 12345678".
const SORT_CODE_ACCOUNT = /(?<!\d)\d{2}-\d{2}-\d{2}\s+\d{6,8}(?!\d)/g;
// UK National Insurance number.
const NINO = /(?<![A-Za-z0-9])[A-CEGHJ-PR-TW-Z]{2}\s?\d{2}\s?\d{2}\s?\d{2}\s?[A-D](?![A-Za-z0-9])/g;
// "account / acct / conta / cuenta / agência (no|nº|#)? <6+ digits>".
const LABELLED_ACCOUNT = /(?<![\p{L}])(?:account|acct|a\/c|conta|cuenta|ag[eê]ncia|agencia)\s*(?:no\.?|n[º°o]\.?|number|número|numero|#|:)?\s*[\d][\d .\-/]{5,}\d/giu;

function luhn(digits: string): boolean {
  let sum = 0;
  let alt = false;
  for (let i = digits.length - 1; i >= 0; i--) {
    let n = digits.charCodeAt(i) - 48;
    if (alt) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alt = !alt;
  }
  return sum % 10 === 0;
}

/** redactPii + the identifiers above. */
export function redactStructured(text: string): { text: string; redacted: boolean } {
  let redacted = false;
  let out = text.replace(CARD, (m) => {
    const d = m.replace(/\D/g, '');
    if (d.length >= 13 && d.length <= 19 && luhn(d)) {
      redacted = true;
      return '[redacted-card]';
    }
    return m;
  });
  out = out.replace(SORT_CODE_ACCOUNT, () => ((redacted = true), '[redacted-account]'))
    .replace(LABELLED_ACCOUNT, () => ((redacted = true), '[redacted-account]'))
    .replace(NINO, () => ((redacted = true), '[redacted-id]'));
  const base = redactPii(out);
  return { text: base.text, redacted: redacted || base.redacted };
}

// ── private-address signals ────────────────────────────────────────────────
const STREET_EN = /(?<![\p{L}\p{N}])\d{1,5}[A-Za-z]?,?\s+(?:[\p{L}'’.-]+\s+){0,4}(?:street|st|road|rd|avenue|ave|lane|ln|drive|dr|close|court|ct|way|place|pl|terrace|crescent|boulevard|blvd|highway|hwy|square|sq)\.?(?![\p{L}])/iu;
const STREET_LATIN = /(?<![\p{L}])(?:rua|r\.|avenida|av\.|travessa|tv\.|alameda|estrada|rodovia|praça|largo|calle|c\/|carrera|avda\.?|paseo|plaza|camino)\s+[\p{L}0-9][^\n]{0,60}?(?:,|nº|n\.º|no\.?|número|numero|#)?\s*\d{1,5}(?![\d])/iu;
const UNIT = /(?<![\p{L}])(?:apt|apartment|flat|suite|unit|apto|apartamento|bloco|casa|piso|puerta|depto|departamento)\.?\s*(?:no\.?|n[º°]\.?|#)?\s*\d/iu;
const POSTCODE = /(?<![A-Za-z0-9])(?:[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2}|\d{5}-\d{3}|\d{5}-\d{4})(?![A-Za-z0-9])/u;
const PO_BOX = /(?<![\p{L}])(?:p\.?\s?o\.?\s?box|caixa postal|apartado(?: de correos)?)\s*\d/iu;

export function privateAddressSignal(text: string): boolean {
  return STREET_EN.test(text) || STREET_LATIN.test(text) || UNIT.test(text) || POSTCODE.test(text) || PO_BOX.test(text);
}

// ── private-name signals ───────────────────────────────────────────────────
// Case-insensitive on the FIRST letter only: the word after it must really
// start with an upper-case letter (an `i` flag would let \p{Lu} match
// lower case and turn "donor list" into a name signal).
const ci = (w: string) => `[${w[0].toUpperCase()}${w[0]}]${w.slice(1)}`;
const HONORIFICS = ['mr', 'mrs', 'ms', 'miss', 'mx', 'dr', 'prof', 'sr', 'sra', 'srta', 'dona', 'don', 'doña', 'sir', 'dame', 'rev', 'fr', 'madame', 'mme', 'monsieur'];
const HONORIFIC = new RegExp(`(?<![\\p{L}])(?:${HONORIFICS.map(ci).join('|')})\\.?\\s+\\p{Lu}`, 'u');
const ROLES = [
  'trustee', 'director', 'volunteer', 'donor', 'beneficiary', 'resident', 'patient', 'member', 'employee', 'staff', 'founder', 'ceo', 'cfo',
  'chair', 'chairman', 'chairwoman', 'treasurer', 'secretary', 'manager', 'teacher', 'nurse', 'doctor', 'pastor', 'priest', 'mother',
  'father', 'son', 'daughter', 'wife', 'husband', 'widow', 'widower', 'brother', 'sister', 'family', 'neighbour', 'neighbor', 'citizen',
  'worker', 'farmer', 'villager',
  'voluntário', 'voluntária', 'doador', 'doadora', 'beneficiário', 'beneficiária', 'morador', 'moradora', 'paciente', 'diretor', 'diretora',
  'fundador', 'fundadora', 'presidente', 'funcionário', 'funcionária', 'professor', 'professora', 'enfermeiro', 'enfermeira', 'mãe', 'pai',
  'filho', 'filha', 'esposa', 'marido', 'viúvo', 'viúva', 'irmão', 'irmã', 'família', 'vizinho', 'vizinha', 'agricultor', 'agricultora',
  'voluntario', 'voluntaria', 'donante', 'residente', 'directora', 'madre', 'padre', 'hijo', 'hija', 'esposo', 'hermano', 'hermana',
  'vecino', 'vecina',
];
const PERSON_ROLE = new RegExp(`(?<![\\p{L}])(?:${ROLES.map(ci).join('|')})\\s+\\p{Lu}\\p{Ll}`, 'u');

// Capitalized words that make a capitalized run ORGANIZATIONAL or otherwise
// not a personal name (organization forms, media, places, calendar, function words).
const NOT_A_NAME = new Set([
  // organization forms / sectors
  'foundation', 'fund', 'trust', 'charity', 'association', 'institute', 'institution', 'society', 'council', 'committee', 'board',
  'ministry', 'department', 'agency', 'authority', 'commission', 'office', 'registry', 'register', 'company', 'companies', 'corporation',
  'group', 'holdings', 'holding', 'ltd', 'limited', 'inc', 'llc', 'plc', 'cic', 'cio', 'gmbh', 'sa', 'ltda', 'eireli', 'me', 'ong', 'oscip',
  'bank', 'university', 'college', 'school', 'academy', 'hospital', 'clinic', 'church', 'mission', 'project', 'programme', 'program',
  'network', 'alliance', 'federation', 'union', 'coalition', 'centre', 'center', 'international', 'global', 'national', 'regional',
  'news', 'daily', 'times', 'post', 'journal', 'gazette', 'herald', 'tribune', 'press', 'media', 'radio', 'tv', 'television', 'magazine',
  'report', 'review', 'annual', 'audit', 'accounts', 'statement', 'financial', 'fixture', 'registry',
  'fundação', 'fundacao', 'instituto', 'associação', 'associacao', 'conselho', 'ministério', 'ministerio', 'secretaria', 'empresa',
  'banco', 'universidade', 'escola', 'igreja', 'projeto', 'rede', 'federação', 'jornal', 'revista', 'relatório', 'relatorio',
  'fundación', 'fundacion', 'asociación', 'asociacion', 'empresa', 'universidad', 'escuela', 'iglesia', 'proyecto', 'periódico', 'informe',
  // places / geography
  'kingdom', 'united', 'states', 'state', 'republic', 'nations', 'county', 'district', 'city', 'province', 'region', 'valley', 'river',
  'north', 'south', 'east', 'west', 'northern', 'southern', 'eastern', 'western', 'central', 'europe', 'africa', 'america', 'asia',
  'brasil', 'brazil', 'england', 'scotland', 'wales', 'ireland', 'london', 'exampleland',
  // calendar
  'january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december',
  'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  'enero', 'febrero', 'marzo', 'mayo', 'junio', 'julio', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  // function words that start sentences
  'the', 'a', 'an', 'this', 'that', 'these', 'those', 'our', 'we', 'it', 'its', 'in', 'on', 'at', 'by', 'for', 'from', 'of', 'to', 'and',
  'o', 'os', 'as', 'um', 'uma', 'no', 'na', 'em', 'de', 'do', 'da', 'dos', 'das', 'e', 'nosso', 'nossa', 'el', 'la', 'los', 'las', 'en', 'y',
]);
const NAME_PARTICLE = new Set(['da', 'de', 'do', 'dos', 'das', 'del', 'van', 'von', 'der', 'di', 'du', 'le', 'la', 'bin', 'ibn', 'al', 'e', 'y']);
const CAP_WORD = /^\p{Lu}[\p{Ll}\p{M}'’-]+$/u;

const norm = (s: string) => s.normalize('NFKC').toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();

/** Remove every occurrence of a known ORGANIZATION name (case-insensitive, token-bounded). */
function stripKnownOrganizations(text: string, orgNames: readonly string[]): string {
  let out = ` ${text.normalize('NFKC')} `;
  const names = [...new Set(orgNames.map((n) => n.normalize('NFKC').trim()).filter((n) => norm(n).length >= 3))].sort((a, b) => b.length - a.length);
  for (const n of names) {
    const tokens = n.split(/[^\p{L}\p{N}]+/u).filter(Boolean).map((t) => t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
    if (!tokens.length) continue;
    out = out.replace(new RegExp(`(?<![\\p{L}\\p{N}])${tokens.join('[^\\p{L}\\p{N}]+')}(?![\\p{L}\\p{N}])`, 'giu'), ' ORGREF ');
  }
  return out;
}

/**
 * Two or more consecutive Capitalized words (name particles allowed inside)
 * form a possible personal name. Organizational / place / calendar /
 * function words BREAK a run (they never excuse the words around them), so
 * "In January Maria Silva" still signals. High recall by design: an
 * organization name that is not on record can be withheld too.
 */
function capitalizedNameRun(text: string): boolean {
  let run = 0;
  let pendingParticles = 0;
  for (const raw of text.split(/[\s,;:()"“”«»!?/]+/u)) {
    const w = raw.replace(/[.]+$/u, '');
    const lower = w.toLowerCase().replace(/['’]s$/u, '');
    const isName = CAP_WORD.test(w) && !NOT_A_NAME.has(lower);
    if (isName) {
      run += 1;
      pendingParticles = 0;
      if (run >= 2) return true;
    } else if (run > 0 && NAME_PARTICLE.has(lower) && pendingParticles < 2) {
      pendingParticles += 1;
    } else {
      run = 0;
      pendingParticles = 0;
    }
    if (raw.endsWith('.')) {
      run = 0; // a sentence end closes the run
      pendingParticles = 0;
    }
  }
  return false;
}

export function privateNameSignal(text: string, orgNames: readonly string[]): boolean {
  const t = stripKnownOrganizations(text, orgNames);
  return HONORIFIC.test(t) || PERSON_ROLE.test(t) || capitalizedNameRun(t);
}

export interface PresentationContext {
  /**
   * Organization names on record from TRUSTED origins only: the subject's
   * declared identity and official registry snapshots. Client-entered
   * publisher names are never added (they could whitelist a person's name).
   */
  readonly orgNames: readonly string[];
}

// Invisible / bidi / format characters carry no meaning in quoted data and can
// split a name or address so that no signal matches (found by PV-09): they
// are removed BEFORE detection and from the presented text; no-break spaces
// become plain spaces.
const INVISIBLE_FORMAT = new RegExp(`[${[0x00ad, 0x061c, 0x180e, 0x200b, 0x200c, 0x200d, 0x200e, 0x200f, 0x202a, 0x202b, 0x202c, 0x202d, 0x202e,
  0x2060, 0x2061, 0x2062, 0x2063, 0x2064, 0x2066, 0x2067, 0x2068, 0x2069, 0xfeff].map((c) => String.fromCharCode(c)).join('')}]`, 'g');
const NBSP = new RegExp(`[${[0x00a0, 0x2007, 0x202f].map((c) => String.fromCharCode(c)).join('')}]`, 'g');
export const normalizeForPresentation = (s: string) => s.replace(INVISIBLE_FORMAT, '').replace(NBSP, ' ');

/** Present one value according to what its field IS. */
export function present(
  kind: FieldKind,
  value: string | null | undefined,
  ctx: PresentationContext,
  sourceType?: string,
): Presented {
  if (value === null || value === undefined) return { text: null, withheld: null, redacted: false };
  const clean = normalizeForPresentation(value);
  if (minorDataRisk(clean)) return { text: null, withheld: 'MINOR_DATA_RISK', redacted: false };
  const r = redactStructured(clean);
  if (kind === 'FREE_TEXT' && (privateAddressSignal(r.text) || privateNameSignal(r.text, ctx.orgNames))) {
    return { text: null, withheld: 'PERSONAL_DATA_RISK', redacted: false };
  }
  // A social-media / "other" publisher may be a private person: it is shown
  // only when it IS an organization already on record (fail-closed).
  if (kind === 'PUBLISHER' && sourceType !== undefined && PERSONAL_PUBLISHER_TYPES.has(sourceType) &&
    !ctx.orgNames.some((n) => norm(n) === norm(r.text))) {
    return { text: null, withheld: 'PERSONAL_DATA_RISK', redacted: false };
  }
  return { text: r.text, withheld: null, redacted: r.redacted };
}

/** URLs are presented as their origin only; anything unparsable is withheld. */
export function presentUri(uri: string | null | undefined): { text: string | null; reduced: boolean } {
  if (!uri) return { text: null, reduced: false };
  try {
    const u = new URL(uri);
    if (u.protocol !== 'https:' && u.protocol !== 'http:') return { text: null, reduced: true };
    const origin = `${u.protocol}//${u.hostname}`;
    return { text: origin, reduced: origin !== uri.replace(/\/$/, '') };
  } catch {
    return { text: null, reduced: true };
  }
}
