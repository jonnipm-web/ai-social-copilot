/**
 * Source lineage and independence — IV-IMPACT-I2-REGISTRY-INTELLIGENCE-01 (CF-04).
 *
 * Question answered: "is this source ORIGINAL, or is it reproducing another?"
 * — and, for counting corroboration: "how many INDEPENDENT voices support
 * this claim?". Pure: no network, no clock, no LLM.
 *
 * Principles (docs/impact/IMPACT_SOURCE_LINEAGE.md):
 *  - AUTHORITY ≠ INDEPENDENCE. Authority (source_authority.ts) says what a
 *    source may speak to; lineage says whether it is a separate voice.
 *  - Independence needs POSITIVE evidence. The only positive evidence today
 *    is provenance: a source obtained through a trusted provider that
 *    publishes its OWN primary records (`primaryPublisher`). Different URL,
 *    domain, headline or publisher name is never independence.
 *  - UNKNOWN lineage is not independent: any number of sources whose
 *    independence is not established count, together, as at most ONE voice.
 *  - Lineage signals only MERGE voices (lower corroboration). They never
 *    remove evidence, never create SUPPORTED/CONTRADICTED and never decide a
 *    conflict. A false-positive similarity can only understate corroboration
 *    (and asks for review) — it cannot hide or create a finding.
 *  - Similarity ≠ proof: near-duplicates and explicit markers are POSSIBLE
 *    lineage (merge + review), never an editorial or legal fact.
 *  - Every lineage input is SERVER-derived (fingerprint, sketch, markers are
 *    computed from submitted text; provider flags come from the server
 *    registry). A client cannot send "independent", "original" or a
 *    fingerprint — see lab_contract.ts.
 *  - VOICES are counted on a graph of TRUSTED-provenance sources only (Codex
 *    I2G2-01): a client-declared label (syndicatedFrom / derivedFrom on an
 *    analyst or user source) describes that source's lineage but can never
 *    bridge two established originals and lower their corroboration.
 *    Trusted sources of the same upstream ORIGIN (provider originId) are one
 *    voice even under different provider ids (I2G2-06).
 */
import { sha256Hex } from './provenance.ts';
import { hasTrustedProvenance } from './source_authority.ts';
import type { Source, SyndicationMarker, TrustedProviderRef } from './types.ts';

export const LINEAGE_POLICY_VERSION = 'impact-lineage/2';

export const LINEAGE_LIMITS = Object.freeze({
  /** Content text accepted for fingerprinting (characters). */
  maxContentChars: 20_000,
  /** Sources compared pairwise for near-duplicates (bounded O(n²)). */
  maxSourcesCompared: 200,
  sketchSlots: 32,
  shingleWords: 5,
  /** Fraction of equal MinHash slots from which two texts are POSSIBLE copies.
   * Beyond maxSourcesCompared the comparison is NOT silently truncated: the
   * result is flagged `comparisonTruncated` and requires review (I2G2-05). */
  nearDuplicateThreshold: 0.8,
  /** Links reported per result (the analysis itself is never truncated). */
  maxReportedLinks: 50,
});

export type LineageState = 'ORIGINAL' | 'SYNDICATED' | 'DERIVED' | 'POSSIBLE_LINEAGE' | 'UNKNOWN';

export type LineageLinkKind =
  | 'DECLARED_SYNDICATION' // syndicatedFrom
  | 'DECLARED_DERIVATION' //  derivedFrom (cites / summarizes)
  | 'IDENTICAL_CONTENT' //    same normalized-content fingerprint
  | 'NEAR_DUPLICATE' //       MinHash similarity ≥ threshold
  | 'WIRE_CREDIT'; //         explicit wire-agency marker / wire publisher

export interface LineageLink {
  readonly from: string; // source id
  readonly to: string; //   source id or "publisher:<key>" / "wire:<agency>"
  readonly kind: LineageLinkKind;
  readonly certainty: 'DECLARED' | 'POSSIBLE';
}

export interface SourceLineage {
  readonly sourceId: string;
  readonly state: LineageState;
  /** Independence positively established (trusted primary-publisher provenance). */
  readonly established: boolean;
}

export interface IndependenceAnalysis {
  readonly policyVersion: string;
  /** Independent voices among COUNTED items (drives sufficiency). */
  readonly voices: number;
  /** Voices whose independence is positively established. */
  readonly establishedVoices: number;
  /** Lineage of every source the claim's evidence uses. */
  readonly sources: readonly SourceLineage[];
  readonly links: readonly LineageLink[];
  /** Counted items from different raw publishers were merged by a link. */
  readonly mergedByLineage: boolean;
  /** A POSSIBLE link (similarity / marker) touches counted items. */
  readonly possibleLineage: boolean;
  /** More sketched sources than can be compared pairwise — review required. */
  readonly comparisonTruncated: boolean;
}

// ── content normalization, fingerprint, sketch, markers ────────────────────

/**
 * Deterministic normalization for fingerprinting. Removes what does not make
 * content different (case, accents, punctuation, whitespace, clock times of a
 * page UI, "x hours ago", URL query/fragment tracking) and KEEPS what does
 * (words, numbers, dates): "20 wells" and "200 wells" stay different.
 */
export function normalizeContent(text: string): string {
  return text.normalize('NFKC').toLowerCase()
    .replace(/(https?:\/\/[^\s?#]+)[?#]\S*/g, '$1') //             tracking params / fragments
    .replace(/\b\d{1,2}:\d{2}(?::\d{2})?\s*(?:am|pm)?(?:\s*(?:gmt|utc|bst|cet|cest|et|edt|est|pt|pdt|pst))?\b/g, ' ') // UI clock times
    .replace(/\b(?:updated|published|posted)?\s*\d+\s+(?:seconds?|minutes?|mins?|hours?|hrs?|days?)\s+ago\b/g, ' ')
    .normalize('NFKD').replace(/\p{M}+/gu, '')
    // Letters and digits of EVERY script are content (Codex I2G2-07).
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export async function contentFingerprint(text: string): Promise<string> {
  return await sha256Hex(`impact-content/1|${normalizeContent(text)}`);
}

function fnv1a(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

/** murmur3 finalizer — spreads (hash ⊕ seed) into an independent slot hash. */
function mix32(x: number): number {
  x ^= x >>> 16;
  x = Math.imul(x, 0x85ebca6b) >>> 0;
  x ^= x >>> 13;
  x = Math.imul(x, 0xc2b2ae35) >>> 0;
  x ^= x >>> 16;
  return x >>> 0;
}

const SLOT_SEEDS: readonly number[] = Object.freeze(
  Array.from({ length: LINEAGE_LIMITS.sketchSlots }, (_, i) => mix32(0x9e3779b9 ^ Math.imul(i + 1, 0x632be5ab))),
);

/** MinHash sketch over word 5-shingles: 32 slots × 8 hex = 256 hex chars. */
export function similaritySketch(text: string): string {
  const words = normalizeContent(text).split(' ').filter(Boolean);
  const n = LINEAGE_LIMITS.shingleWords;
  const shingles = words.length <= n ? [words.join(' ')] : Array.from({ length: words.length - n + 1 }, (_, i) => words.slice(i, i + n).join(' '));
  const mins = SLOT_SEEDS.map(() => 0xffffffff);
  for (const sh of shingles) {
    const base = fnv1a(sh);
    for (let i = 0; i < SLOT_SEEDS.length; i++) {
      const v = mix32(base ^ SLOT_SEEDS[i]);
      if (v < mins[i]) mins[i] = v;
    }
  }
  return mins.map((m) => m.toString(16).padStart(8, '0')).join('');
}

const SKETCH_RE = /^[0-9a-f]{256}$/;

export function isSketch(v: unknown): v is string {
  return typeof v === 'string' && SKETCH_RE.test(v);
}

/** Estimated Jaccard similarity: fraction of equal MinHash slots. */
export function sketchSimilarity(a: string, b: string): number {
  if (!isSketch(a) || !isSketch(b)) return 0;
  let eq = 0;
  for (let i = 0; i < 256; i += 8) if (a.slice(i, i + 8) === b.slice(i, i + 8)) eq++;
  return eq / LINEAGE_LIMITS.sketchSlots;
}

const MARKERS: readonly [SyndicationMarker, RegExp][] = [
  ['WIRE_REUTERS', /\breuters\b/i],
  ['WIRE_AP', /\bassociated press\b|\(ap\)/i],
  ['WIRE_AFP', /\bagence france[- ]presse\b|\(afp\)|\bafp\b/i],
  ['ORIGINALLY_PUBLISHED', /\boriginally (?:published|appeared)\b|\bpublicado originalmente\b/i],
  ['REPUBLISHED_FROM', /\brepublished (?:from|with permission|under)\b|\breproduzido de\b/i],
  // "via X" only as a credit line, not the ordinary word "via" in a sentence.
  // Linear-time pattern (no adjacent ambiguous whitespace runs — ReDoS-safe).
  ['VIA_CREDIT', /^[ \t]*(?:(?:[Ss]ource|[Cc]redit|[Ff]onte)[ \t]*:[ \t]*)?[Vv]ia[ \t]+[A-Z]/m],
];

/** Explicit syndication signals in the content (bounded input, linear regexes). */
export function detectSyndicationMarkers(text: string): SyndicationMarker[] {
  const t = text.slice(0, LINEAGE_LIMITS.maxContentChars);
  return MARKERS.filter(([, re]) => re.test(t)).map(([m]) => m).sort();
}

export const SYNDICATION_MARKERS: readonly SyndicationMarker[] = Object.freeze(MARKERS.map(([m]) => m).sort());

const WIRE_OF_MARKER: Readonly<Partial<Record<SyndicationMarker, string>>> = {
  WIRE_REUTERS: 'reuters', WIRE_AP: 'ap', WIRE_AFP: 'afp',
};

/** Normalized publisher key (same as verification.ts publisherKey). */
export function normalizedPublisherKey(p: string): string {
  return p.normalize('NFKC').trim().toLowerCase().replace(/\s+/g, ' ');
}

const WIRE_PUBLISHERS: ReadonlyMap<string, string> = new Map([
  ['reuters', 'reuters'], ['thomson reuters', 'reuters'], ['reuters news agency', 'reuters'],
  ['associated press', 'ap'], ['the associated press', 'ap'], ['ap', 'ap'],
  ['afp', 'afp'], ['agence france-presse', 'afp'], ['agence france presse', 'afp'],
]);

// ── independence analysis ──────────────────────────────────────────────────

export interface CountedRef {
  readonly sourceId: string;
}

/**
 * Builds the lineage graph over EVERY source supplied (links through a source
 * that carries no counted evidence still merge — Codex FV4-01) and counts the
 * independent voices among `counted`.
 *
 *   voices = (#components containing an ESTABLISHED original)
 *            + (1 if there is none but other counted components exist)
 *
 * so unestablished sources never add more than one voice, and two components
 * are two voices only when both are positively established originals.
 */
export function analyzeIndependence(
  counted: readonly CountedRef[],
  referenced: readonly string[],
  sources: ReadonlyMap<string, Source>,
  trustedProviders: ReadonlyMap<string, TrustedProviderRef>,
): IndependenceAnalysis {
  const all = [...sources.values()].sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  const trusted = (s: Source) => hasTrustedProvenance(s, trustedProviders);
  const refOf = (s: Source) => trustedProviders.get((s.acquisition as { providerId: string }).providerId);
  const established = (s: Source) => trusted(s) && refOf(s)?.primaryPublisher === true;

  // Descriptive graph: every supplied source (states and reported links).
  const full = buildGraph(all, () => null);
  // Voice graph: trusted-provenance sources only; same upstream origin = one voice.
  const voice = buildGraph(all.filter(trusted), (s) => `origin:${refOf(s)?.originId ?? refOf(s)?.id ?? ''}`);

  const stateOf = (s: Source): LineageState => {
    // A primary register publishes its own records: it is the origin even if
    // someone else copied it (an incoming similarity link does not demote it).
    if (established(s) && !s.syndicatedFrom && !s.derivedFrom) return 'ORIGINAL';
    if (full.syndicated.has(s.id)) return 'SYNDICATED';
    if (full.derived.has(s.id)) return 'DERIVED';
    if (full.possible.has(s.id)) return 'POSSIBLE_LINEAGE';
    return 'UNKNOWN';
  };

  const countedComponents = new Map<string, boolean>(); // voice root → has established original
  const rawPublishersPerRoot = new Map<string, Set<string>>();
  for (const c of counted) {
    const s = sources.get(c.sourceId);
    if (!s || !trusted(s)) continue; // counted items always have trusted provenance
    const root = voice.find(`src:${s.id}`);
    countedComponents.set(root, (countedComponents.get(root) ?? false) || stateOf(s) === 'ORIGINAL');
    rawPublishersPerRoot.set(root, new Set([...(rawPublishersPerRoot.get(root) ?? []), normalizedPublisherKey(s.publisher)]));
  }
  const establishedVoices = [...countedComponents.values()].filter(Boolean).length;
  const voices = establishedVoices + (establishedVoices === 0 && countedComponents.size > 0 ? 1 : 0);
  const mergedByLineage = [...rawPublishersPerRoot.values()].some((p) => p.size > 1);
  const touchesCounted = (l: LineageLink) => countedComponents.has(voice.endpointRoot(l.from)) || countedComponents.has(voice.endpointRoot(l.to));
  const possibleLineage = voice.links.some((l) => l.certainty === 'POSSIBLE' && touchesCounted(l));

  const refs = new Set(referenced);
  const relevantRoots = new Set([...refs].filter((id) => sources.has(id)).map((id) => full.find(`src:${id}`)));
  const reported = full.links
    .filter((l) => relevantRoots.has(full.endpointRoot(l.from)) || relevantRoots.has(full.endpointRoot(l.to)))
    .sort((a, b) => `${a.from}|${a.to}|${a.kind}`.localeCompare(`${b.from}|${b.to}|${b.kind}`))
    .slice(0, LINEAGE_LIMITS.maxReportedLinks);

  return Object.freeze({
    policyVersion: LINEAGE_POLICY_VERSION,
    voices,
    establishedVoices,
    sources: Object.freeze([...refs].filter((id) => sources.has(id)).sort().map((id) => {
      const s = sources.get(id)!;
      return Object.freeze({ sourceId: id, state: stateOf(s), established: stateOf(s) === 'ORIGINAL' });
    })),
    links: Object.freeze(reported),
    mergedByLineage,
    possibleLineage,
    comparisonTruncated: full.truncated || voice.truncated,
  });
}

/** Union-find lineage graph over `list` (deterministic: `list` is id-sorted). */
function buildGraph(list: readonly Source[], originOf: (s: Source) => string | null) {
  const parent = new Map<string, string>();
  const find = (x: string): string => {
    if (!parent.has(x)) parent.set(x, x);
    let r = x;
    while (parent.get(r) !== r) r = parent.get(r)!;
    let c = x;
    while (parent.get(c) !== r) { const n = parent.get(c)!; parent.set(c, r); c = n; }
    return r;
  };
  const union = (a: string, b: string) => {
    const [ra, rb] = [find(a), find(b)];
    if (ra !== rb) (ra < rb ? parent.set(rb, ra) : parent.set(ra, rb));
  };
  const links: LineageLink[] = [];
  const src = (id: string) => `src:${id}`;
  const pub = (k: string) => {
    const wire = WIRE_PUBLISHERS.get(k);
    return wire ? `wire:${wire}` : `publisher:${k}`;
  };
  const syndicated = new Set<string>();
  const derived = new Set<string>();
  const possible = new Set<string>();

  for (const s of list) {
    union(src(s.id), pub(normalizedPublisherKey(s.publisher))); // one publisher = one voice
    const origin = originOf(s);
    if (origin) union(src(s.id), origin); //                         one upstream origin = one voice
    if (s.syndicatedFrom) {
      union(pub(normalizedPublisherKey(s.publisher)), pub(normalizedPublisherKey(s.syndicatedFrom)));
      links.push({ from: s.id, to: pub(normalizedPublisherKey(s.syndicatedFrom)), kind: 'DECLARED_SYNDICATION', certainty: 'DECLARED' });
      syndicated.add(s.id);
    }
    if (s.derivedFrom) {
      union(src(s.id), pub(normalizedPublisherKey(s.derivedFrom)));
      links.push({ from: s.id, to: pub(normalizedPublisherKey(s.derivedFrom)), kind: 'DECLARED_DERIVATION', certainty: 'DECLARED' });
      derived.add(s.id);
    }
    for (const m of s.syndicationMarkers ?? []) {
      const wire = WIRE_OF_MARKER[m];
      if (wire) {
        union(src(s.id), `wire:${wire}`);
        links.push({ from: s.id, to: `wire:${wire}`, kind: 'WIRE_CREDIT', certainty: 'POSSIBLE' });
      }
      possible.add(s.id);
    }
  }

  // Identical normalized content: the earliest (publishedAt ?? retrievedAt,
  // then id) is the candidate original; later copies are SYNDICATED.
  const byPrint = new Map<string, Source[]>();
  for (const s of list) if (s.contentFingerprint) byPrint.set(s.contentFingerprint, [...(byPrint.get(s.contentFingerprint) ?? []), s]);
  for (const group of byPrint.values()) {
    if (group.length < 2) continue;
    const order = [...group].sort((a, b) => {
      const ta = a.publishedAt ?? a.retrievedAt;
      const tb = b.publishedAt ?? b.retrievedAt;
      return ta < tb ? -1 : ta > tb ? 1 : a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
    });
    for (const s of order.slice(1)) {
      union(src(s.id), src(order[0].id));
      links.push({ from: s.id, to: order[0].id, kind: 'IDENTICAL_CONTENT', certainty: 'DECLARED' });
      syndicated.add(s.id);
    }
  }

  // Near-duplicates: bounded pairwise comparison; overflow is disclosed, never silent.
  const allSketched = list.filter((s) => isSketch(s.similaritySketch));
  const truncated = allSketched.length > LINEAGE_LIMITS.maxSourcesCompared;
  const sketched = allSketched.slice(0, LINEAGE_LIMITS.maxSourcesCompared);
  for (let i = 0; i < sketched.length; i++) {
    for (let j = i + 1; j < sketched.length; j++) {
      const a = sketched[i];
      const b = sketched[j];
      if (a.contentFingerprint && a.contentFingerprint === b.contentFingerprint) continue; // already IDENTICAL
      if (sketchSimilarity(a.similaritySketch!, b.similaritySketch!) >= LINEAGE_LIMITS.nearDuplicateThreshold) {
        union(src(a.id), src(b.id));
        links.push({ from: b.id, to: a.id, kind: 'NEAR_DUPLICATE', certainty: 'POSSIBLE' });
        possible.add(a.id);
        possible.add(b.id);
      }
    }
  }
  const endpointRoot = (x: string) => find(x.includes(':') && !x.startsWith('src:') && /^(publisher|wire|origin):/.test(x) ? x : src(x));
  return { find, links, syndicated, derived, possible, truncated, endpointRoot };
}
