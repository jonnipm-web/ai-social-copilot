// IV-IMPACT-FOUNDATION-01 — Verification Engine, source authority, temporal,
// provenance and adversarial cases. Fictitious organizations only.
import { assert, assertEquals, assertNotEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { EVALUATED_AT, FIXTURE_PROVIDERS, hash, providerFor, SOURCES } from './fixtures/golden.ts';
import { checkReferenceUri, sha256Hex } from './provenance.ts';
import { deriveIndicators } from './risk_indicators.ts';
import { authorityFor } from './source_authority.ts';
import type { Claim, EvidenceItem, Source } from './types.ts';
import { verifyClaim, type VerificationContext } from './verification.ts';

const CTX: VerificationContext = { evaluatedAt: EVALUATED_AT, subjectIdentity: 'CONFIRMED', trustedProviders: FIXTURE_PROVIDERS };
const TRUSTED = new Map(FIXTURE_PROVIDERS.map((p) => [p.id, p]));
const ORG = 'org-hopebridge';

const claim = (over: Partial<Claim> = {}): Claim => ({
  id: 'c1', investigationId: 'inv-1', kind: 'IMPACT_OUTPUT', level: 'OUTPUT', text: 'Built 20 wells in 2025.',
  quantity: { metric: 'wells_built', value: 20, unit: 'count' }, period: { from: '2025-01-01', to: '2025-12-31' },
  subjectOrganizationId: ORG, sourceId: SOURCES.hbWebsite.id, extractedAt: '2026-09-02T00:00:00Z', origin: 'MANUAL', ...over,
});
const ev = (id: string, sourceId: string, over: Partial<EvidenceItem> = {}): EvidenceItem => ({
  id, investigationId: 'inv-1', claimId: 'c1', sourceId, aboutOrganizationId: ORG, relationship: 'SUPPORTS',
  relationshipBasis: 'HUMAN_ASSESSED', personalData: 'NONE', addedAt: '2026-09-02T00:00:00Z',
  observedPeriod: { from: '2025-01-01', to: '2025-12-31' }, ...over,
});
const news = (id: string, publisher: string, over: Partial<Source> = {}): Source => ({
  id, type: 'NEWS', newsGenre: 'REPORTING', publisher, acquisition: providerFor('NEWS'), retrievedAt: '2026-09-01T00:00:00Z', status: 'ACTIVE',
  retention: 'EXCERPT_AND_HASH', contentHash: hash(id.replace(/[^a-f0-9]/g, '') + 'ab'), ...over,
});
async function run(c: Claim, evidence: EvidenceItem[], sources: Source[], ctx: VerificationContext = CTX) {
  const r = await verifyClaim({ claim: c, evidence, sources: [SOURCES.hbWebsite, ...sources] }, ctx);
  if (!r.ok) throw new Error(`${r.error.code}: ${r.error.message}`);
  return r.value;
}

// ── Source authority ───────────────────────────────────────────────────────

Deno.test('SA-1 self-published material is SELF_REPORTED whatever its type (even "official-looking")', () => {
  const c = claim({ kind: 'LEGAL_REGISTRATION' });
  assertEquals(authorityFor({ ...SOURCES.registry, publisherOrganizationId: ORG }, c, TRUSTED), 'SELF_REPORTED');
  assertEquals(authorityFor(SOURCES.hbAudited, claim({ kind: 'FINANCIAL' }), TRUSTED), 'INDEPENDENT');
  assertEquals(authorityFor({ ...SOURCES.hbAudited, publisherOrganizationId: ORG }, claim({ kind: 'FINANCIAL' }), TRUSTED), 'SELF_REPORTED');
});

Deno.test('SA-2 a registry is authoritative for registration but has NO scope over impact outputs', () => {
  assertEquals(authorityFor(SOURCES.registry, claim({ kind: 'LEGAL_REGISTRATION' }), TRUSTED), 'AUTHORITATIVE');
  assertEquals(authorityFor(SOURCES.registry, claim({ kind: 'IMPACT_OUTPUT' }), TRUSTED), 'NONE');
  assertEquals(authorityFor(SOURCES.registry, claim({ kind: 'BENEFICIARY_COUNT' }), TRUSTED), 'NONE');
});

Deno.test('SA-3 news: only REPORTING corroborates; journalism never establishes registration', () => {
  const c = claim();
  assertEquals(authorityFor(news('n1', 'Paper'), c, TRUSTED), 'INDEPENDENT');
  for (const g of ['OPINION', 'ALLEGATION', 'CORRECTION'] as const) {
    assertEquals(authorityFor(news('n1', 'Paper', { newsGenre: g }), c, TRUSTED), 'CONTEXTUAL');
  }
  assertEquals(authorityFor(news('n1', 'Paper'), claim({ kind: 'LEGAL_REGISTRATION' }), TRUSTED), 'CONTEXTUAL');
});

Deno.test('SA-4 social media proves attribution only; user uploads are USER_SUBMITTED even if labelled official', () => {
  const social: Source = { ...news('s1', 'account @x'), type: 'SOCIAL_MEDIA', newsGenre: undefined, retention: 'HASH_ONLY', acquisition: providerFor('SOCIAL_MEDIA') };
  assertEquals(authorityFor(social, claim(), TRUSTED), 'ATTRIBUTION_ONLY');
  assertEquals(authorityFor({ ...SOURCES.registry, userSubmitted: true }, claim({ kind: 'LEGAL_REGISTRATION' }), TRUSTED), 'USER_SUBMITTED');
});

// ── Engine rules ───────────────────────────────────────────────────────────

Deno.test('VE-1 registry evidence on an impact-output claim is excluded as OUT_OF_AUTHORITY_SCOPE', async () => {
  const v = await run(claim(), [ev('e1', SOURCES.registry.id)], [SOURCES.registry]);
  assertEquals(v.status, 'UNVERIFIED');
  assertEquals(v.excluded, [{ evidenceId: 'e1', reason: 'OUT_OF_AUTHORITY_SCOPE' }]);
});

Deno.test('VE-2 LLM-suggested relationship is never counted until confirmed', async () => {
  const v = await run(claim(), [ev('e1', SOURCES.govWells.id, { relationshipBasis: 'LLM_SUGGESTED' })], [SOURCES.govWells]);
  assertEquals(v.status, 'UNVERIFIED');
  assert(v.gaps.includes('UNCONFIRMED_LLM_LINKS'));
  const confirmed = await run(claim(), [ev('e1', SOURCES.govWells.id)], [SOURCES.govWells]);
  assertEquals(confirmed.status, 'SUPPORTED');
});

Deno.test('VE-3 STRUCTURED_MATCH derives the relationship itself (declared value is ignored)', async () => {
  const q = (v: number) => ({ metric: 'wells_built', value: v, unit: 'count' });
  const lie = await run(claim(), [ev('e1', SOURCES.govWells.id, { relationshipBasis: 'STRUCTURED_MATCH', relationship: 'SUPPORTS', reportedQuantity: q(0) })], [SOURCES.govWells]);
  assertEquals(lie.status, 'CONTRADICTED');
  const part = await run(claim(), [ev('e1', SOURCES.govWells.id, { relationshipBasis: 'STRUCTURED_MATCH', relationship: 'CONTRADICTS', reportedQuantity: q(8) })], [SOURCES.govWells]);
  assertEquals(part.status, 'PARTIALLY_SUPPORTED');
  const units = await run(claim(), [ev('e1', SOURCES.govWells.id, { relationshipBasis: 'STRUCTURED_MATCH', reportedQuantity: { metric: 'wells_built', value: 20, unit: 'litres' } })], [SOURCES.govWells]);
  assertEquals(units.excluded[0].reason, 'UNITS_NOT_COMPARABLE');
});

Deno.test('VE-4 outputs cannot substantiate an OUTCOME claim (level mismatch)', async () => {
  const v = await run(
    claim({ kind: 'IMPACT_OUTCOME', level: 'OUTCOME', quantity: undefined, text: 'Child malnutrition fell in 2025.' }),
    [ev('e1', SOURCES.govWells.id, { level: 'OUTPUT' })],
    [SOURCES.govWells],
  );
  assertEquals(v.status, 'UNVERIFIED');
  assertEquals(v.excluded[0].reason, 'LEVEL_MISMATCH');
});

Deno.test('VE-5 evidence about another period is not counted', async () => {
  const v = await run(claim(), [ev('e1', SOURCES.govWells.id, { observedPeriod: { from: '2019-01-01', to: '2019-12-31' } })], [SOURCES.govWells]);
  assertEquals(v.status, 'UNVERIFIED');
  assert(v.gaps.includes('PERIOD_NOT_COVERED'));
});

Deno.test('VE-6 source poisoning: many items from ONE publisher count as one publisher; copies are deduplicated', async () => {
  const s1 = news('n1', 'Same Outlet');
  const s2 = news('n2', ' same   OUTLET ');
  const s3 = news('n3', 'Syndicator', { contentHash: s1.contentHash });
  const v = await run(claim(), [ev('e1', 'n1'), ev('e2', 'n2'), ev('e3', 'n3')], [s1, s2, s3]);
  assertEquals(v.status, 'SUPPORTED');
  assertEquals(v.sufficiency, 'INDEPENDENT_SUPPORT'); // not MULTI_SOURCE
  assertEquals(v.excluded, [{ evidenceId: 'e3', reason: 'DUPLICATE_CONTENT' }]);
});

Deno.test('VE-7 a news ALLEGATION is context only: never a contradiction, flagged for review', async () => {
  const s = news('n1', 'Tabloid', { newsGenre: 'ALLEGATION' });
  const v = await run(claim(), [ev('e1', 'n1', { relationship: 'CONTRADICTS' })], [s]);
  assertEquals(v.status, 'UNVERIFIED');
  assertEquals(v.contradicting, []);
  assert(v.gaps.includes('ALLEGATION_UNRESOLVED'));
  assertEquals(v.reviewState, 'REVIEW_REQUIRED');
  const ind = deriveIndicators({ results: [v] });
  assert(ind.every((i) => i.polarity !== 'CONCERN'), 'an allegation alone is not a concern indicator');
  assert(ind.some((i) => i.code === 'UNRESOLVED_ALLEGATION' && i.polarity === 'INFORMATION_GAP'));
});

Deno.test('VE-8 court record: CHARGED is never guilt; CONVICTED is shown with its exact stage', async () => {
  const court: Source = { ...SOURCES.registry, id: 'src-court', type: 'COURT_RECORD', acquisition: providerFor('COURT_RECORD'), publisher: 'Exampleland Court (fixture)', retention: 'EXCERPT_AND_HASH', contentHash: hash('c0') };
  const c = claim({ kind: 'REGULATORY_STATUS', quantity: undefined, level: undefined, period: undefined, text: 'No regulatory action against us.' });
  const charged = await run(c, [ev('e1', 'src-court', { relationship: 'CONTRADICTS', legalStage: 'CHARGED', observedPeriod: { to: '2026-08-01' } })], [court]);
  assertNotEquals(charged.status, 'CONTRADICTED');
  const ci = deriveIndicators({ results: [charged] });
  assertEquals(ci.find((i) => i.legalStage)?.legalStage, 'CHARGED');
  assertEquals(ci.find((i) => i.legalStage)?.code, 'UNRESOLVED_ALLEGATION');

  const convicted = await run(c, [ev('e1', 'src-court', { relationship: 'CONTRADICTS', legalStage: 'CONVICTED', observedPeriod: { to: '2026-08-01' } })], [court]);
  assertEquals(convicted.status, 'CONTRADICTED');
  assertEquals(convicted.reviewState, 'REVIEW_REQUIRED');
  const vi = deriveIndicators({ results: [convicted] }).find((i) => i.code === 'REGULATORY_OR_COURT_RECORD')!;
  assertEquals(vi.legalStage, 'CONVICTED');
  assertEquals(vi.isProofOfWrongdoing, false);

  const dismissed = await run(c, [ev('e1', 'src-court', { relationship: 'SUPPORTS', legalStage: 'DISMISSED', observedPeriod: { to: '2026-08-01' } })], [court]);
  assert(deriveIndicators({ results: [dismissed] }).some((i) => i.code === 'FAVOURABLE_LEGAL_OUTCOME'));
});

Deno.test('VE-9 identity not CONFIRMED caps SUPPORTED/CONTRADICTED to INCONCLUSIVE (false-attribution guard)', async () => {
  for (const identity of ['PROBABLE', 'UNCERTAIN', 'UNRESOLVED'] as const) {
    const q = { metric: 'wells_built', value: 0, unit: 'count' };
    const v = await run(claim(), [ev('e1', SOURCES.govWells.id, { relationshipBasis: 'STRUCTURED_MATCH', reportedQuantity: q })], [SOURCES.govWells], { ...CTX, subjectIdentity: identity });
    assertEquals(v.status, 'INCONCLUSIVE', identity);
    assert(v.gaps.includes('IDENTITY_UNCONFIRMED'));
  }
});

Deno.test('VE-10 authoritative source decides within scope; lower-tier disagreement is still recorded', async () => {
  const c = claim({ kind: 'LEGAL_REGISTRATION', quantity: undefined, level: undefined, period: undefined, text: 'We are registered.' });
  const gov: Source = { ...SOURCES.govWells, id: 'src-gov-reg' };
  const v = await run(c, [
    ev('e1', SOURCES.registry.id, { relationship: 'SUPPORTS', observedPeriod: { to: '2026-09-01' } }),
    ev('e2', 'src-gov-reg', { relationship: 'CONTRADICTS', observedPeriod: { to: '2026-09-01' } }),
  ], [SOURCES.registry, gov]);
  assertEquals(v.status, 'SUPPORTED');
  assertEquals(v.conflicts.length, 1);
  assertEquals(v.reviewState, 'REVIEW_REQUIRED');
});

Deno.test('VE-11 retracted / updated sources are excluded; a correction changes the conclusion', async () => {
  const s = news('n1', 'Paper');
  const before = await run(claim(), [ev('e1', 'n1')], [s]);
  assertEquals(before.status, 'SUPPORTED');
  const retracted = await run(claim(), [ev('e1', 'n1')], [{ ...s, status: 'RETRACTED' }]);
  assertEquals(retracted.status, 'UNVERIFIED');
  assert(retracted.gaps.includes('SOURCE_RETRACTED'));
  const changed = await run(claim(), [ev('e1', 'n1')], [{ ...s, status: 'UPDATED' }]);
  assertEquals(changed.excluded[0].reason, 'SOURCE_CHANGED');
  assertNotEquals(before.evidenceSetHash, retracted.evidenceSetHash);
});

Deno.test('VE-12 open dispute → DISPUTED with the underlying status preserved', async () => {
  const v = await run(claim(), [ev('e1', SOURCES.govWells.id)], [SOURCES.govWells], { ...CTX, openDispute: true });
  assertEquals(v.status, 'DISPUTED');
  assertEquals(v.underlyingStatus, 'SUPPORTED');
  assertEquals(v.reviewState, 'REVIEW_REQUIRED');
});

Deno.test('VE-13 human review binds to the exact evidence set; new evidence re-opens review', async () => {
  const s = news('n1', 'Tabloid', { newsGenre: 'ALLEGATION' });
  const first = await run(claim(), [ev('e1', 'n1')], [s]);
  assertEquals(first.reviewState, 'REVIEW_REQUIRED');
  const review = { reviewedAt: '2026-09-22T00:00:00Z', reviewerRef: 'rev-1', reviewBindingHash: first.reviewBindingHash };
  const reviewed = await run(claim(), [ev('e1', 'n1')], [s], { ...CTX, humanReview: review });
  assertEquals(reviewed.reviewState, 'HUMAN_REVIEWED');
  const more = await run(claim(), [ev('e1', 'n1'), ev('e2', SOURCES.govWells.id)], [s, SOURCES.govWells], { ...CTX, humanReview: review });
  assertEquals(more.reviewState, 'REVIEW_REQUIRED');
});

Deno.test('VE-14 results are deeply frozen and versioned', async () => {
  const v = await run(claim(), [ev('e1', SOURCES.govWells.id)], [SOURCES.govWells]);
  assert(Object.isFrozen(v) && Object.isFrozen(v.supporting) && Object.isFrozen(v.supporting[0]));
  assert(v.policyVersion.startsWith('impact-verification/4+impact-source-authority/3+impact-temporal/2'));
  const later = await run(claim(), [ev('e1', SOURCES.govWells.id)], [SOURCES.govWells], { ...CTX, evaluatedAt: '2026-10-01T00:00:00Z' });
  assertNotEquals(v.resultId, later.resultId);
  assertEquals(v.evidenceSetHash, later.evidenceSetHash);
});

Deno.test('VE-15 commercial metadata (sponsor/advertiser) cannot change a result or its id', async () => {
  const base = await run(claim(), [ev('e1', SOURCES.govWells.id)], [SOURCES.govWells]);
  // deno-lint-ignore no-explicit-any
  const sponsoredClaim = { ...claim(), sponsored: true, advertiser: true, paidPlacement: 'premium' } as any;
  // deno-lint-ignore no-explicit-any
  const sponsoredEv = { ...ev('e1', SOURCES.govWells.id), sponsored: true, boost: 10 } as any;
  // deno-lint-ignore no-explicit-any
  const sponsoredSrc = { ...SOURCES.govWells, advertiser: true } as any;
  const r = await verifyClaim({ claim: sponsoredClaim, evidence: [sponsoredEv], sources: [SOURCES.hbWebsite, sponsoredSrc] }, CTX);
  assert(r.ok);
  assertEquals(r.value.resultId, base.resultId);
  assertEquals(r.value.status, base.status);
});

// ── Validation / provenance ────────────────────────────────────────────────

async function code(c: Claim, e: EvidenceItem[], s: Source[], ctx = CTX) {
  const r = await verifyClaim({ claim: c, evidence: e, sources: [SOURCES.hbWebsite, ...s] }, ctx);
  return r.ok ? 'OK' : r.error.code;
}

Deno.test('PV-1 cross-investigation evidence is refused (not silently counted)', async () => {
  assertEquals(await code(claim(), [ev('e1', SOURCES.govWells.id, { investigationId: 'inv-other' })], [SOURCES.govWells]), 'CROSS_INVESTIGATION_DENIED');
});

Deno.test('PV-2 evidence without a known source (no provenance) is invalid', async () => {
  assertEquals(await code(claim(), [ev('e1', 'src-ghost')], []), 'INVALID_EVIDENCE');
  const noClaimSource = await verifyClaim({ claim: claim(), evidence: [], sources: [] }, CTX);
  assertEquals(noClaimSource.ok ? 'OK' : noClaimSource.error.code, 'INVALID_CLAIM');
});

Deno.test('PV-3 personal / sensitive / minors data is rejected by the Foundation', async () => {
  for (const pd of ['PERSONAL', 'SENSITIVE', 'MINOR'] as const) {
    assertEquals(await code(claim(), [ev('e1', SOURCES.govWells.id, { personalData: pd })], [SOURCES.govWells]), 'SENSITIVE_DATA_REJECTED');
  }
});

Deno.test('PV-4 tampered excerpt (hash mismatch) is rejected; excerpt not allowed for hash-only sources', async () => {
  const good = 'Water Authority: 20 wells completed.';
  assertEquals(await code(claim(), [ev('e1', SOURCES.govWells.id, { excerpt: good, excerptHash: await sha256Hex(good) })], [SOURCES.govWells]), 'OK');
  assertEquals(await code(claim(), [ev('e1', SOURCES.govWells.id, { excerpt: 'Water Authority: 200 wells completed.', excerptHash: await sha256Hex(good) })], [SOURCES.govWells]), 'INVALID_EVIDENCE');
  const hashOnly: Source = { ...SOURCES.govWells, retention: 'HASH_ONLY' };
  assertEquals(await code(claim(), [ev('e1', SOURCES.govWells.id, { excerpt: good, excerptHash: await sha256Hex(good) })], [hashOnly]), 'INVALID_EVIDENCE');
});

Deno.test('PV-5 malformed sources: future retrieval, published-after-retrieval, over-retention, missing hash', async () => {
  assertEquals(await code(claim(), [], [{ ...SOURCES.govWells, retrievedAt: '2027-01-01T00:00:00Z' }]), 'INVALID_SOURCE');
  assertEquals(await code(claim(), [], [{ ...SOURCES.govWells, publishedAt: '2026-09-15T00:00:00Z' }]), 'INVALID_SOURCE');
  assertEquals(await code(claim(), [], [{ ...news('n1', 'P'), retention: 'SNAPSHOT' }]), 'INVALID_SOURCE');
  assertEquals(await code(claim(), [], [{ ...SOURCES.govWells, contentHash: undefined }]), 'INVALID_SOURCE');
  assertEquals(await code(claim(), [], [{ ...SOURCES.govWells, publisher: '  ' }]), 'INVALID_SOURCE');
});

Deno.test('PV-6 oversize inputs are bounded', async () => {
  assertEquals(await code(claim({ text: 'x'.repeat(4_001) }), [], []), 'INVALID_CLAIM');
  const many = Array.from({ length: 201 }, (_, i) => ev(`e${i}`, SOURCES.govWells.id));
  assertEquals(await code(claim(), many, [SOURCES.govWells]), 'INVALID_EVIDENCE');
  assertEquals(await code(claim({ quantity: { metric: 'wells_built', value: Number.NaN, unit: 'count' } }), [], []), 'INVALID_CLAIM');
});

Deno.test('SSRF-1 unsafe references are refused before they can ever reach a fetcher', () => {
  const bad = [
    'file:///etc/passwd', 'ftp://example.org/x', 'javascript:alert(1)', 'http://localhost/admin', 'http://127.0.0.1/',
    'http://169.254.169.254/latest/meta-data/', 'http://metadata.google.internal/', 'http://[::1]/', 'http://[fd00::1]/',
    'http://10.0.0.5/', 'http://192.168.1.1/', 'http://0x7f.1/', 'http://2130706433/', 'http://user:pass@example.org/',
    'https://evil.example@127.0.0.1/', 'http://printer.local/', 'http://svc.internal/', 'http://[::ffff:127.0.0.1]/',
  ];
  for (const u of bad) {
    const r = checkReferenceUri(u);
    assertEquals(r.ok, false, u);
  }
  for (const u of ['https://registry.example/charities/XA-1', 'http://8.8.8.8/report.pdf']) assert(checkReferenceUri(u).ok, u);
});

Deno.test('SSRF-2 a source carrying an unsafe uri is rejected as UNSAFE_REFERENCE', async () => {
  assertEquals(await code(claim(), [], [{ ...SOURCES.govWells, uri: 'http://169.254.169.254/' }]), 'UNSAFE_REFERENCE');
});
