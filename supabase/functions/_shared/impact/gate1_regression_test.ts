// IV-IMPACT-FOUNDATION-01 — regression tests for Codex Gate 1 findings
// (G1-01..G1-06) and Claude's own review findings (C-01..C-03).
import { assert, assertEquals, assertNotEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { EVALUATED_AT, FIXTURE_PROVIDERS, goldenCases, hash, providerFor, SOURCES } from './fixtures/golden.ts';
import { type Actor, Investigation } from './investigation.ts';
import { buildImpactEvent } from './observability.ts';
import { parseIsoMs } from './provenance.ts';
import { deriveIndicators } from './risk_indicators.ts';
import { checkNarrative, findVerdictLanguage, hasMixedScript, statusesMentioned } from './safety.ts';
import { authorityFor } from './source_authority.ts';
import type { Claim, EvidenceItem, Source, SourceStatus } from './types.ts';
import { verifyClaim, type VerificationContext } from './verification.ts';

const CTX: VerificationContext = { evaluatedAt: EVALUATED_AT, subjectIdentity: 'CONFIRMED', trustedProviders: FIXTURE_PROVIDERS };
const TRUSTED = new Map(FIXTURE_PROVIDERS.map((p) => [p.id, p]));
const ORG = 'org-hopebridge';
const cases = await goldenCases();

const finClaim: Claim = {
  id: 'c1', investigationId: 'inv-1', kind: 'FINANCIAL', text: 'Our 2025 accounts were audited.',
  subjectOrganizationId: ORG, sourceId: SOURCES.hbWebsite.id, extractedAt: '2026-09-02T00:00:00Z', origin: 'MANUAL',
};
const ev = (id: string, sourceId: string, over: Partial<EvidenceItem> = {}): EvidenceItem => ({
  id, investigationId: 'inv-1', claimId: 'c1', sourceId, aboutOrganizationId: ORG, relationship: 'SUPPORTS',
  relationshipBasis: 'HUMAN_ASSESSED', personalData: 'NONE', addedAt: '2026-09-02T00:00:00Z', ...over,
});
async function run(c: Claim, evidence: EvidenceItem[], sources: Source[], ctx: VerificationContext = CTX) {
  const r = await verifyClaim({ claim: c, evidence, sources: [SOURCES.hbWebsite, ...sources] }, ctx);
  if (!r.ok) throw new Error(`${r.error.code}: ${r.error.message}`);
  return r.value;
}
async function code(c: Claim, e: EvidenceItem[], s: Source[]) {
  const r = await verifyClaim({ claim: c, evidence: e, sources: [SOURCES.hbWebsite, ...s] }, CTX);
  return r.ok ? 'OK' : r.error.code;
}

// ── G1-01 forgeable provenance ─────────────────────────────────────────────

Deno.test('G1-01a a "fake audit" typed by an analyst or uploaded by a user is never independent', async () => {
  const fake: Source = { ...SOURCES.hbAudited, id: 'src-fake-audit', publisher: 'Fake Audit Co', acquisition: { method: 'ANALYST_ENTRY' } };
  assertEquals(authorityFor(fake, finClaim, TRUSTED), 'CONTEXTUAL');
  const v = await run(finClaim, [ev('e1', fake.id)], [fake]);
  assertEquals(v.status, 'UNVERIFIED');
  assertEquals(deriveIndicators({ results: [v] }).some((i) => i.code === 'AUDITED_ACCOUNTS'), false);
  const upload: Source = { ...fake, id: 'src-upload', acquisition: { method: 'USER_UPLOAD' } };
  assertEquals(authorityFor(upload, finClaim, TRUSTED), 'USER_SUBMITTED');
});

Deno.test('G1-01b a provider may only vouch for its own source type and jurisdiction; unknown providers are untrusted', async () => {
  const relabelled: Source = { ...SOURCES.hbAudited, id: 'src-relabel', acquisition: providerFor('ORGANIZATION_WEBSITE') };
  assertEquals(authorityFor(relabelled, finClaim, TRUSTED), 'CONTEXTUAL');
  const unknown: Source = { ...SOURCES.hbAudited, id: 'src-unknown', acquisition: { method: 'PROVIDER', providerId: 'attacker-provider' } };
  assertEquals(authorityFor(unknown, finClaim, TRUSTED), 'CONTEXTUAL');
  const otherCountry: Source = { ...SOURCES.registry, id: 'src-xb', jurisdiction: { country: 'XB' } };
  assertEquals(authorityFor(otherCountry, { ...finClaim, kind: 'LEGAL_REGISTRATION' }, TRUSTED), 'CONTEXTUAL');
  // No trusted providers at all → nothing can be independent (fail closed).
  const none = await run(finClaim, [ev('e1', SOURCES.hbAudited.id)], [SOURCES.hbAudited], { ...CTX, trustedProviders: [] });
  assertEquals(none.status, 'UNVERIFIED');
  const trusted = await run(finClaim, [ev('e1', SOURCES.hbAudited.id)], [SOURCES.hbAudited]);
  assertEquals(trusted.status, 'SUPPORTED');
});

Deno.test('G1-01c a source without acquisition, or with a missing trustedProviders context, is rejected', async () => {
  // deno-lint-ignore no-explicit-any
  const noAcq = { ...SOURCES.hbAudited, acquisition: undefined } as any;
  assertEquals(await code(finClaim, [], [noAcq]), 'INVALID_SOURCE');
  // deno-lint-ignore no-explicit-any
  const r = await verifyClaim({ claim: finClaim, evidence: [], sources: [SOURCES.hbWebsite] }, { evaluatedAt: EVALUATED_AT, subjectIdentity: 'CONFIRMED' } as any);
  assertEquals(r.ok ? 'OK' : r.error.code, 'INTERNAL_ERROR');
});

// ── G1-02 future / reversed periods ────────────────────────────────────────

const regClaim: Claim = { ...finClaim, kind: 'LEGAL_REGISTRATION', text: 'We are registered.' };

Deno.test('G1-02a a future observedPeriod.to is rejected; 2020 evidence stays OUTDATED', async () => {
  const old: Source = { ...SOURCES.registry, id: 'src-reg-2020', retrievedAt: '2020-01-01T00:00:00Z', contentHash: hash('20') };
  assertEquals(await code(regClaim, [ev('e1', old.id, { observedPeriod: { to: '2099-01-01' } })], [old]), 'INVALID_EVIDENCE');
  const v = await run(regClaim, [ev('e1', old.id, { observedPeriod: { to: '2020-01-01' } })], [old]);
  assertEquals(v.status, 'OUTDATED');
});

Deno.test('G1-02b reversed periods, periods starting after retrieval and impossible dates are rejected', async () => {
  assertEquals(await code(regClaim, [ev('e1', SOURCES.registry.id, { observedPeriod: { from: '2026-05-01', to: '2026-01-01' } })], [SOURCES.registry]), 'INVALID_EVIDENCE');
  assertEquals(await code(regClaim, [ev('e1', SOURCES.registry.id, { observedPeriod: { from: '2026-09-10' } })], [SOURCES.registry]), 'INVALID_EVIDENCE');
  assertEquals(await code({ ...regClaim, period: { from: '2025-12-31', to: '2025-01-01' } }, [], []), 'INVALID_CLAIM');
  assertEquals(parseIsoMs('2025-02-30'), null);
  assertEquals(parseIsoMs('2025-13-01'), null);
  assert(parseIsoMs('2024-02-29') !== null);
});

// ── G1-03 case / homoglyph bypass of the narrative guards ──────────────────

Deno.test('G1-03a status smuggling is detected case-insensitively and in PT/EN phrasing', async () => {
  const g = cases.find((c) => c.id === 'G')!;
  const r = await verifyClaim({ claim: g.claim, evidence: g.evidence, sources: g.sources }, g.ctx);
  assert(r.ok && r.value.status === 'SUPPORTED');
  for (const n of ['The claim is contradicted.', 'A alegação foi desmentida.', 'The claim is Inconclusive', 'status: partially supported']) {
    assertEquals(checkNarrative(n, r.value).ok, false, n);
  }
  assertEquals(checkNarrative('Two independent sources support the claim; it is supported.', r.value).ok, true);
  assertEquals([...statusesMentioned('A alegação não verificada')], ['UNVERIFIED']);
  assertEquals([...statusesMentioned('partially supported')], ['PARTIALLY_SUPPORTED']);
});

Deno.test('G1-03b homoglyphs, invisible characters and combining marks cannot hide verdict language', async () => {
  const f = cases.find((c) => c.id === 'F')!;
  const r = await verifyClaim({ claim: f.claim, evidence: f.evidence, sources: f.sources }, f.ctx);
  assert(r.ok);
  const tricks = [
    'The organization is a frаud.', //        Cyrillic a
    'The organization is a fr​aud.', //       zero-width space
    'The organization is a f́raud.', //       combining acute
    'The organization is a ѕcam.', //         Cyrillic dze
    'Eles são corruptοs.', //            Greek omicron
    'This charity is тrustworthy.', //        Cyrillic te
  ];
  for (const t of tricks) {
    assert(findVerdictLanguage(t).length > 0 || hasMixedScript(t), t);
    assertEquals(checkNarrative(t, r.value).ok, false, t);
  }
  assertEquals(hasMixedScript('Organização Esperança'), false);
});

// ── G1-04 review binding covers flags / identity / providers ───────────────

Deno.test('G1-04 a human review is invalidated when a source is newly flagged, identity changes or providers change', async () => {
  const g = cases.find((c) => c.id === 'C')!;
  const first = await verifyClaim({ claim: g.claim, evidence: g.evidence, sources: g.sources }, g.ctx);
  assert(first.ok);
  const review = { reviewedAt: '2026-09-22T00:00:00Z', reviewerRef: 'rev-1', reviewBindingHash: first.value.reviewBindingHash };
  const same = await verifyClaim({ claim: g.claim, evidence: g.evidence, sources: g.sources }, { ...g.ctx, humanReview: review });
  assert(same.ok && same.value.reviewState === 'HUMAN_REVIEWED');
  const variants: VerificationContext[] = [
    { ...g.ctx, humanReview: review, flaggedSourceIds: [SOURCES.newsSchools.id] },
    { ...g.ctx, humanReview: review, subjectIdentity: 'PROBABLE' },
    { ...g.ctx, humanReview: review, trustedProviders: FIXTURE_PROVIDERS.slice(1) },
  ];
  for (const ctx of variants) {
    const r = await verifyClaim({ claim: g.claim, evidence: g.evidence, sources: g.sources }, ctx);
    assert(r.ok);
    assertEquals(r.value.reviewState, 'REVIEW_REQUIRED');
  }
  // A flag on a source NOT in this evidence set does not re-open review.
  const unrelated = await verifyClaim({ claim: g.claim, evidence: g.evidence, sources: g.sources }, { ...g.ctx, humanReview: review, flaggedSourceIds: ['src-elsewhere'] });
  assert(unrelated.ok && unrelated.value.reviewState === 'HUMAN_REVIEWED');
});

// ── G1-05 unknown enum values fail closed ──────────────────────────────────

Deno.test('G1-05a unknown or prototype-key enum values are rejected everywhere', async () => {
  for (const status of ['UNKNOWN_STATUS', 'retracted', 'constructor', '__proto__', 'toString']) {
    assertEquals(await code(finClaim, [], [{ ...SOURCES.govWells, status: status as SourceStatus }]), 'INVALID_SOURCE', status);
  }
  for (const type of ['constructor', 'toString', 'AUDIT']) {
    assertEquals(await code(finClaim, [], [{ ...SOURCES.govWells, type: type as Source['type'] }]), 'INVALID_SOURCE', type);
  }
  assertEquals(await code(finClaim, [], [{ ...SOURCES.govWells, retention: 'constructor' as Source['retention'] }]), 'INVALID_SOURCE');
  assertEquals(await code({ ...finClaim, kind: 'toString' as Claim['kind'] }, [], []), 'INVALID_CLAIM');
  assertEquals(await code({ ...finClaim, level: '__proto__' as Claim['level'] }, [], []), 'INVALID_CLAIM');
  assertEquals(await code(finClaim, [ev('e1', SOURCES.govWells.id, { legalStage: 'GUILTY' as EvidenceItem['legalStage'] })], [SOURCES.govWells]), 'INVALID_EVIDENCE');
});

Deno.test('G1-05b updateSourceStatus refuses unknown statuses', async () => {
  const owner: Actor = { subjectRef: 'subj-owner', projectIds: [] };
  const inv = await Investigation.create(owner, { id: 'inv-1', subjectOrganizationId: ORG, createdAt: '2026-09-02T00:00:00Z' });
  assert(inv.ok);
  assert((await inv.value.addSource(owner, SOURCES.govWells, EVALUATED_AT)).ok);
  const r = await inv.value.updateSourceStatus(owner, SOURCES.govWells.id, 'UNKNOWN_STATUS' as SourceStatus, EVALUATED_AT);
  assertEquals(r.ok ? 'OK' : r.error.code, 'INVALID_SOURCE');
});

// ── G1-06 hash covers all provenance fields ────────────────────────────────

Deno.test('G1-06 evidenceSetHash changes when jurisdiction, uri, retention or acquisition change', async () => {
  const base = await run(finClaim, [ev('e1', SOURCES.hbAudited.id)], [SOURCES.hbAudited]);
  const changes: Partial<Source>[] = [
    { jurisdiction: { country: 'XA' } },
    { uri: 'https://auditor.example/report-2025.pdf' },
    { retention: 'HASH_ONLY' },
    { acquisition: { method: 'ANALYST_ENTRY' } },
  ];
  for (const c of changes) {
    const v = await run(finClaim, [ev('e1', SOURCES.hbAudited.id)], [{ ...SOURCES.hbAudited, ...c }]);
    assertNotEquals(v.evidenceSetHash, base.evidenceSetHash, JSON.stringify(c));
  }
});

// ── Codex Final findings ───────────────────────────────────────────────────

Deno.test('CF-01 an investigation only accepts claims about its own subject', async () => {
  const owner: Actor = { subjectRef: 'subj-owner', projectIds: [] };
  const inv = await Investigation.create(owner, { id: 'inv-1', subjectOrganizationId: ORG, createdAt: '2026-09-02T00:00:00Z' });
  assert(inv.ok);
  assert((await inv.value.addSource(owner, SOURCES.hbWebsite, EVALUATED_AT)).ok);
  const r = await inv.value.addClaim(owner, { ...finClaim, subjectOrganizationId: 'org-other' }, EVALUATED_AT);
  assertEquals(r.ok ? 'OK' : r.error.code, 'CROSS_INVESTIGATION_DENIED');
  assert((await inv.value.addClaim(owner, finClaim, EVALUATED_AT)).ok);
});

Deno.test('CF-02 an observed period extending past retrieval is rejected', async () => {
  const src: Source = { ...SOURCES.govWells, id: 'src-gov-mid', retrievedAt: '2026-06-01T00:00:00Z', contentHash: hash('26') };
  const q = { metric: 'wells_built', value: 20, unit: 'count' };
  const c: Claim = { ...finClaim, kind: 'IMPACT_OUTPUT', quantity: q, period: { from: '2026-01-01', to: '2026-12-31' }, text: '20 wells in 2026.' };
  assertEquals(await code(c, [ev('e1', src.id, { relationshipBasis: 'STRUCTURED_MATCH', reportedQuantity: q, observedPeriod: { from: '2026-01-01', to: '2026-12-31' } })], [src]), 'INVALID_EVIDENCE');
  const ok = await run(c, [ev('e1', src.id, { relationshipBasis: 'STRUCTURED_MATCH', reportedQuantity: q, observedPeriod: { from: '2026-01-01', to: '2026-06-01' } })], [src]);
  assertEquals(ok.status, 'SUPPORTED');
});

Deno.test('CF-03 jurisdiction-bound sources without a jurisdiction are never independent', () => {
  for (const type of ['OFFICIAL_REGISTRY', 'REGULATOR', 'COURT_RECORD', 'GOVERNMENT_RECORD'] as const) {
    const s: Source = { ...SOURCES.registry, id: `src-${type}`, type, acquisition: providerFor(type), jurisdiction: undefined, retention: 'EXCERPT_AND_HASH' };
    const kind = type === 'GOVERNMENT_RECORD' ? 'IMPACT_OUTPUT' : 'REGULATORY_STATUS';
    assertEquals(authorityFor(s, { ...finClaim, kind }, TRUSTED), 'CONTEXTUAL', type);
  }
  assertEquals(authorityFor(SOURCES.registry, regClaim, TRUSTED), 'AUTHORITATIVE');
});

Deno.test('CF-04 syndicated copies and repeated statements are one voice per publisher', async () => {
  const q = (v: number) => ({ metric: 'wells_built', value: v, unit: 'count' });
  const c: Claim = { ...finClaim, kind: 'IMPACT_OUTPUT', quantity: q(20), text: '20 wells.' };
  const news = (id: string, publisher: string, over: Partial<Source> = {}): Source => ({
    id, type: 'NEWS', newsGenre: 'REPORTING', publisher, acquisition: providerFor('NEWS'), retrievedAt: '2026-09-01T00:00:00Z',
    status: 'ACTIVE', retention: 'EXCERPT_AND_HASH', contentHash: hash(id.replace(/[^a-f0-9]/g, '') + 'cd'), ...over,
  });
  const wire = news('n1', 'Wire Service', { publishedAt: '2026-03-01T00:00:00Z' });
  const copy = news('n2', 'Wire Service via Outlet', { syndicatedFrom: 'Wire Service', publishedAt: '2026-03-02T00:00:00Z' });
  const sx = (v: number) => ({ relationshipBasis: 'STRUCTURED_MATCH' as const, reportedQuantity: q(v) });
  // wire supports, syndicated copy (with wrapper) contradicts → no artificial conflict
  const v = await run(c, [ev('e1', 'n1', sx(20)), ev('e2', 'n2', sx(0))], [wire, copy]);
  assertEquals(v.conflicts, []);
  assert(v.excluded.some((x) => x.reason === 'SUPERSEDED_BY_SAME_PUBLISHER'));
  assertEquals(deriveIndicators({ results: [v] }).some((i) => i.code === 'CONFLICTING_CLAIMS'), false);
  // two corroborating copies of the same wire story are not MULTI_SOURCE
  const both = await run(c, [ev('e1', 'n1', sx(20)), ev('e2', 'n2', sx(20))], [wire, copy]);
  assertEquals(both.sufficiency, 'INDEPENDENT_SUPPORT');
  // a publisher's later correction supersedes its earlier report
  const later = news('n3', 'Wire Service', { publishedAt: '2026-05-01T00:00:00Z' });
  const corrected = await run(c, [ev('e1', 'n1', sx(20)), ev('e3', 'n3', sx(12))], [wire, later]);
  assertEquals(corrected.status, 'PARTIALLY_SUPPORTED');
});

Deno.test('CF-05 dispute kinds, resolutions and timestamps are validated at runtime', async () => {
  const owner: Actor = { subjectRef: 'subj-owner', projectIds: [] };
  const inv = await Investigation.create(owner, { id: 'inv-1', subjectOrganizationId: ORG, createdAt: '2026-09-02T00:00:00Z' });
  assert(inv.ok);
  const w = inv.value;
  assert((await w.addSource(owner, SOURCES.hbWebsite, EVALUATED_AT)).ok);
  assert((await w.addClaim(owner, finClaim, EVALUATED_AT)).ok);
  const bad = [
    { id: 'd1', claimId: 'c1', kind: 'UNKNOWN_KIND', openedAt: EVALUATED_AT, submittedEvidenceIds: [] },
    { id: 'd2', claimId: 'c1', kind: 'constructor', openedAt: EVALUATED_AT, submittedEvidenceIds: [] },
    { id: 'd3', claimId: 'c1', kind: 'ORGANIZATION_RESPONSE', openedAt: 'not-a-date', submittedEvidenceIds: [] },
  ];
  // deno-lint-ignore no-explicit-any
  for (const d of bad) assertEquals((await w.openDispute(owner, d as any)).ok, false, d.id);
  assert((await w.openDispute(owner, { id: 'd4', claimId: 'c1', kind: 'ORGANIZATION_RESPONSE', openedAt: EVALUATED_AT, submittedEvidenceIds: [] })).ok);
  // deno-lint-ignore no-explicit-any
  assertEquals((await w.resolveDispute(owner, 'd4', 'UNKNOWN_RESOLUTION' as any, EVALUATED_AT)).ok, false);
  assertEquals((await w.resolveDispute(owner, 'd4', 'CORRECTED', 'yesterday')).ok, false);
  assert((await w.resolveDispute(owner, 'd4', 'CORRECTED', EVALUATED_AT)).ok);
});

// ── Claude review findings ─────────────────────────────────────────────────

Deno.test('C-01 an organization disagreeing with its own earlier figure is an information gap, not a CONCERN', async () => {
  const q = (v: number) => ({ metric: 'wells_built', value: v, unit: 'count' });
  const c: Claim = { ...finClaim, kind: 'IMPACT_OUTPUT', quantity: q(20), text: 'We built 20 wells.' };
  const v = await run(c, [ev('e1', SOURCES.hbAnnualReport.id, { relationshipBasis: 'STRUCTURED_MATCH', reportedQuantity: q(18) })], [SOURCES.hbAnnualReport]);
  assertEquals(v.conflicts[0].basis, 'SELF_REPORTED_ONLY');
  const ind = deriveIndicators({ results: [v] });
  assertEquals(ind.filter((i) => i.polarity === 'CONCERN'), []);
  assert(ind.some((i) => i.code === 'INCONSISTENT_SELF_REPORTING' && i.polarity === 'INFORMATION_GAP'));
});

Deno.test('C-02 observability refuses bare JWTs and prototype-key field names', () => {
  assertEquals(buildImpactEvent({ event: 'x', investigation_id: 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.sig' }), null);
  assertEquals(buildImpactEvent({ event: 'x', constructor: 'abc' }), null);
  assertEquals(buildImpactEvent({ event: 'x', toString: 'abc' }), null);
});
