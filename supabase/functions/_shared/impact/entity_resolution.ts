/**
 * Entity resolution — IV-IMPACT-FOUNDATION-01.
 *
 * "Is organization record A the same entity as candidate B?" A name is never
 * enough: two unrelated charities can share a name, and an impersonator will
 * copy one. Outcomes (IMPACT_DOMAIN_MODEL.md §3):
 *
 *   CONFIRMED_MATCH         same registration (scheme+value) in the same
 *                           jurisdiction, and nothing contradicts it
 *   PROBABLE_MATCH          strong-but-not-legal signals agree (domain + name
 *                           + country) — shown as probable, never merged
 *   ENTITY_MATCH_UNCERTAIN  only weak signals (name/alias similarity), or
 *                           signals disagree
 *   DISTINCT                same jurisdiction+scheme with DIFFERENT values,
 *                           or different countries with no shared identifier
 *   INSUFFICIENT_IDENTIFIERS nothing comparable
 *
 * Only CONFIRMED_MATCH may be merged (canAutoMerge). Everything else is shown
 * as candidates for a human, and the Verification Engine caps claim status
 * while the subject's identity is not CONFIRMED.
 */
import type { Jurisdiction, OrganizationIdentity } from './types.ts';

export type EntityMatchOutcome =
  | 'CONFIRMED_MATCH'
  | 'PROBABLE_MATCH'
  | 'ENTITY_MATCH_UNCERTAIN'
  | 'DISTINCT'
  | 'INSUFFICIENT_IDENTIFIERS';

export type MatchSignal =
  | 'REGISTRATION_EQUAL'
  | 'REGISTRATION_DIFFERENT'
  | 'DOMAIN_EQUAL'
  | 'DOMAIN_DIFFERENT'
  | 'NAME_EQUAL'
  | 'NAME_SIMILAR'
  | 'COUNTRY_EQUAL'
  | 'COUNTRY_DIFFERENT';

export interface EntityMatch {
  readonly outcome: EntityMatchOutcome;
  readonly signals: readonly MatchSignal[];
  readonly canAutoMerge: boolean;
}

const LEGAL_SUFFIXES = [
  'ltd', 'limited', 'inc', 'incorporated', 'llc', 'cic', 'cio', 'plc', 'ltda', 'sa', 'gmbh', 'ev', 'eireli', 'me',
];

export function normalizeName(name: string): string {
  const base = name.normalize('NFKD').replace(/[̀-ͯ]/g, '').toLowerCase()
    .replace(/&/g, ' and ').replace(/[^a-z0-9 ]+/g, ' ').replace(/\s+/g, ' ').trim();
  const words = base.split(' ').filter((w) => w && !LEGAL_SUFFIXES.includes(w) && w !== 'the');
  return words.join(' ');
}

/** Registration values compared without spaces/dashes/dots, uppercase. */
export function normalizeRegistration(value: string): string {
  return value.normalize('NFKC').toUpperCase().replace(/[\s\-./]/g, '');
}

/** Lowercase, no scheme, no "www.", no trailing dot/port/path. Returns null
 * for anything that is not a plain hostname (IP literals are not identity). */
export function normalizeDomain(raw: string): string | null {
  let d = raw.trim().toLowerCase();
  d = d.replace(/^[a-z]+:\/\//, '').split('/')[0].split('?')[0].split('#')[0];
  if (d.includes('@')) return null;
  d = d.replace(/:\d+$/, '').replace(/\.$/, '').replace(/^www\./, '');
  if (!/^[a-z0-9-]+(\.[a-z0-9-]+)+$/.test(d)) return null;
  if (/^[0-9.]+$/.test(d)) return null;
  return d;
}

function countryOf(j: Jurisdiction): string {
  return j.country.trim().toUpperCase();
}

function names(id: OrganizationIdentity): Set<string> {
  return new Set([id.legalName, id.publicName, ...(id.aliases ?? [])].filter((n): n is string => !!n).map(normalizeName).filter(Boolean));
}

/** Token-set Jaccard similarity — a hint only, never identity. */
function nameSimilarity(a: string, b: string): number {
  const ta = new Set(a.split(' '));
  const tb = new Set(b.split(' '));
  const inter = [...ta].filter((t) => tb.has(t)).length;
  return inter / (ta.size + tb.size - inter || 1);
}

export function resolveEntity(a: OrganizationIdentity, b: OrganizationIdentity): EntityMatch {
  const signals = new Set<MatchSignal>();

  // Registrations: compared only inside the same country + scheme.
  let regEqual = false;
  let regDifferent = false;
  for (const ra of a.registrations ?? []) {
    for (const rb of b.registrations ?? []) {
      if (countryOf(ra.jurisdiction) !== countryOf(rb.jurisdiction)) continue;
      if (ra.scheme.trim().toLowerCase() !== rb.scheme.trim().toLowerCase()) continue;
      if (normalizeRegistration(ra.value) === normalizeRegistration(rb.value)) regEqual = true;
      else regDifferent = true;
    }
  }
  if (regEqual) signals.add('REGISTRATION_EQUAL');
  if (regDifferent) signals.add('REGISTRATION_DIFFERENT');

  const da = new Set((a.domains ?? []).map(normalizeDomain).filter((d): d is string => !!d));
  const db = new Set((b.domains ?? []).map(normalizeDomain).filter((d): d is string => !!d));
  if (da.size && db.size) signals.add([...da].some((d) => db.has(d)) ? 'DOMAIN_EQUAL' : 'DOMAIN_DIFFERENT');

  const na = names(a);
  const nb = names(b);
  if ([...na].some((n) => nb.has(n))) signals.add('NAME_EQUAL');
  else if ([...na].some((x) => [...nb].some((y) => nameSimilarity(x, y) >= 0.5))) signals.add('NAME_SIMILAR');

  const ca = new Set((a.jurisdictions ?? []).concat((a.registrations ?? []).map((r) => r.jurisdiction)).map(countryOf));
  const cb = new Set((b.jurisdictions ?? []).concat((b.registrations ?? []).map((r) => r.jurisdiction)).map(countryOf));
  if (ca.size && cb.size) signals.add([...ca].some((c) => cb.has(c)) ? 'COUNTRY_EQUAL' : 'COUNTRY_DIFFERENT');

  const sig = [...signals].sort();
  const has = (s: MatchSignal) => signals.has(s);
  const out = (outcome: EntityMatchOutcome): EntityMatch =>
    Object.freeze({ outcome, signals: Object.freeze(sig), canAutoMerge: outcome === 'CONFIRMED_MATCH' });

  if (regEqual && regDifferent) return out('ENTITY_MATCH_UNCERTAIN'); // inconsistent records
  if (regEqual) return out(has('DOMAIN_DIFFERENT') ? 'ENTITY_MATCH_UNCERTAIN' : 'CONFIRMED_MATCH');
  if (regDifferent) return out('DISTINCT');
  if (has('DOMAIN_EQUAL') && (has('NAME_EQUAL') || has('NAME_SIMILAR')) && !has('COUNTRY_DIFFERENT')) {
    return out('PROBABLE_MATCH');
  }
  if (has('COUNTRY_DIFFERENT') && !has('DOMAIN_EQUAL')) {
    return out(has('NAME_EQUAL') || has('NAME_SIMILAR') ? 'ENTITY_MATCH_UNCERTAIN' : 'DISTINCT');
  }
  if (has('NAME_EQUAL') || has('NAME_SIMILAR') || has('DOMAIN_EQUAL')) return out('ENTITY_MATCH_UNCERTAIN');
  if (signals.size === 0) return out('INSUFFICIENT_IDENTIFIERS');
  return out('ENTITY_MATCH_UNCERTAIN');
}

/** Maps a match outcome to the identity status the Verification Engine uses. */
export function identityStatusFor(outcome: EntityMatchOutcome): 'CONFIRMED' | 'PROBABLE' | 'UNCERTAIN' | 'UNRESOLVED' {
  switch (outcome) {
    case 'CONFIRMED_MATCH':
      return 'CONFIRMED';
    case 'PROBABLE_MATCH':
      return 'PROBABLE';
    case 'ENTITY_MATCH_UNCERTAIN':
      return 'UNCERTAIN';
    default:
      return 'UNRESOLVED';
  }
}
