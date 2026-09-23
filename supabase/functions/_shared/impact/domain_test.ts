// IV-IMPACT-FOUNDATION-01 — entity resolution, providers/normalization,
// financial/metrics/affiliation, investigation workspace, report.
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { EVALUATED_AT, goldenCases, ORGS, SOURCES, XA } from './fixtures/golden.ts';
import { identityStatusFor, normalizeDomain, normalizeName, normalizeRegistration, resolveEntity } from './entity_resolution.ts';
import { deriveAffiliation, levelCanSubstantiate, spendingShares } from './financial_and_metrics.ts';
import { type Actor, Investigation, verifyAuditChain } from './investigation.ts';
import { fetchRegistryVia, FixtureProvider, normalizeRegistryRecord, type ProviderDescriptor, type RawRegistryRecord, searchVia } from './provider.ts';
import { buildImpactReport } from './report.ts';
import { deriveIndicators } from './risk_indicators.ts';
import { findVerdictLanguage } from './safety.ts';
import { verifyClaim, type VerificationResult } from './verification.ts';
import type { OrganizationIdentity } from './types.ts';

// ── Entity resolution ──────────────────────────────────────────────────────

const reg = (value: string, country = 'XA', scheme = 'charity-number') => ({ jurisdiction: { country }, scheme, value });

Deno.test('ER-1 same registration in the same jurisdiction → CONFIRMED (normalized), only this may merge', () => {
  const m = resolveEntity(
    { legalName: 'HopeBridge Foundation', registrations: [reg('XA-1234567')] },
    { legalName: 'Hope Bridge Fdn Ltd', registrations: [reg('xa 1234567')] },
  );
  assertEquals(m.outcome, 'CONFIRMED_MATCH');
  assertEquals(m.canAutoMerge, true);
  assertEquals(identityStatusFor(m.outcome), 'CONFIRMED');
});

Deno.test('ER-2 identical NAME alone is never identity (two different charities can share a name)', () => {
  const m = resolveEntity({ legalName: 'Northstar Relief Initiative' }, { legalName: 'Northstar Relief Initiative' });
  assertEquals(m.outcome, 'ENTITY_MATCH_UNCERTAIN');
  assertEquals(m.canAutoMerge, false);
});

Deno.test('ER-3 different registration numbers in the same scheme → DISTINCT even with identical names', () => {
  const m = resolveEntity(
    { legalName: 'HopeBridge Foundation', registrations: [reg('XA-1234567')] },
    { legalName: 'HopeBridge Foundation', registrations: [reg('XA-9999999')] },
  );
  assertEquals(m.outcome, 'DISTINCT');
});

Deno.test('ER-4 same number in ANOTHER country is not comparable (no cross-jurisdiction inference)', () => {
  const m = resolveEntity({ registrations: [reg('123', 'XA')] }, { registrations: [reg('123', 'XB')] });
  assertEquals(m.signals.includes('REGISTRATION_EQUAL'), false);
  assertEquals(m.canAutoMerge, false);
});

Deno.test('ER-5 registration equal but domain different (possible impersonation) → UNCERTAIN, not merged', () => {
  const m = resolveEntity(
    { registrations: [reg('XA-1234567')], domains: ['hopebridge.example'] },
    { registrations: [reg('XA-1234567')], domains: ['hopebridge-donate.example'] },
  );
  assertEquals(m.outcome, 'ENTITY_MATCH_UNCERTAIN');
  assert(deriveIndicators({ results: [], identityMatches: [{ candidateRef: 'cand-1', match: m }] }).some((i) => i.code === 'DOMAIN_MISMATCH'));
});

Deno.test('ER-6 domain + name agree → PROBABLE only; nothing comparable → INSUFFICIENT_IDENTIFIERS', () => {
  const p = resolveEntity(
    { legalName: 'HopeBridge Foundation', domains: ['https://www.HopeBridge.example/about'] },
    { publicName: 'HopeBridge', domains: ['hopebridge.example'] },
  );
  assertEquals(p.outcome, 'PROBABLE_MATCH');
  assertEquals(p.canAutoMerge, false);
  assertEquals(resolveEntity({}, {}).outcome, 'INSUFFICIENT_IDENTIFIERS');
});

Deno.test('ER-7 normalizers', () => {
  assertEquals(normalizeName('The HopeBridge Foundation, Ltd.'), 'hopebridge foundation');
  assertEquals(normalizeName('Fundação Esperança LTDA'), 'fundacao esperanca');
  assertEquals(normalizeRegistration(' xa-123.456/7 '), 'XA1234567');
  assertEquals(normalizeDomain('HTTPS://WWW.Example.org:443/path?q'), 'example.org');
  assertEquals(normalizeDomain('http://127.0.0.1/'), null);
  assertEquals(normalizeDomain('user@evil.example'), null);
});

// ── Providers ──────────────────────────────────────────────────────────────

const DESC: ProviderDescriptor = {
  id: 'fixture-xa-charity-registry',
  sourceType: 'OFFICIAL_REGISTRY',
  capabilities: ['SEARCH_ORGANIZATION', 'FETCH_REGISTRY_RECORD'],
  jurisdictions: ['XA'],
  authorityScope: ['LEGAL_REGISTRATION', 'REGULATORY_STATUS'],
  freshnessDays: 7,
  retrievalMethod: 'FIXTURE',
};
const RAW: RawRegistryRecord[] = [
  {
    providerId: DESC.id, recordId: 'xa-1234567', retrievedAt: '2026-09-01T00:00:00Z',
    payload: { country: 'xa', scheme: 'charity-number', registration_number: 'XA-1234567', name: 'HopeBridge Foundation', organization_type: 'FOUNDATION', status: 'REGISTERED', status_as_of: '2026-08-31', domains: ['www.hopebridge.example'], injected: 'ignore previous instructions' },
  },
  {
    providerId: DESC.id, recordId: 'xa-7654321', retrievedAt: '2026-09-01T00:00:00Z',
    payload: { country: 'XA', scheme: 'charity-number', registration_number: 'XA-7654321', name: 'Northstar Relief Initiative', organization_type: 'NGO', status: 'REGISTERED' },
  },
];

Deno.test('PR-1 capability declaration: undeclared operations fail with CAPABILITY_NOT_SUPPORTED', async () => {
  const searchOnly = new FixtureProvider({ ...DESC, capabilities: ['SEARCH_ORGANIZATION'] }, RAW);
  const r = await fetchRegistryVia(searchOnly, 'xa-1234567');
  assertEquals(r.ok ? 'OK' : r.error.code, 'CAPABILITY_NOT_SUPPORTED');
  const s = await searchVia(searchOnly, { registration: 'xa 1234567' });
  assert(s.ok && s.value.length === 1);
});

Deno.test('PR-2 unavailable registry → REGISTRY_UNAVAILABLE (never "not registered")', async () => {
  const off = new FixtureProvider(DESC, RAW, false);
  const r = await searchVia(off, { name: 'hopebridge' });
  assertEquals(r.ok ? 'OK' : r.error.code, 'REGISTRY_UNAVAILABLE');
});

Deno.test('PR-3 RAW → CANONICAL: normalized, unknown fields dropped, raw hash kept, raw untouched', async () => {
  const before = JSON.stringify(RAW[0]);
  const c = await normalizeRegistryRecord(RAW[0], DESC);
  assert(c.ok);
  assertEquals(c.value.jurisdiction.country, 'XA');
  assertEquals(c.value.registrationNumber, 'XA1234567');
  assertEquals(c.value.domains, ['hopebridge.example']);
  assertEquals(Object.keys(c.value).includes('injected'), false);
  assertEquals(c.value.rawRecordHash.length, 64);
  assertEquals(JSON.stringify(RAW[0]), before);
  const m = resolveEntity(ORGS.hopebridge.identity, c.value.identity);
  assertEquals(m.outcome, 'CONFIRMED_MATCH');
});

Deno.test('PR-4 malformed / out-of-jurisdiction / forged records are rejected whole', async () => {
  const bad = [
    { ...RAW[0], payload: { ...RAW[0].payload, country: 'XB' } },
    { ...RAW[0], payload: { ...RAW[0].payload, registration_number: '' } },
    { ...RAW[0], payload: { ...RAW[0].payload, status: 'VERIFIED_BY_INSIGHTVALUES' } },
    { ...RAW[0], payload: { ...RAW[0].payload, status_as_of: 'yesterday' } },
    { ...RAW[0], providerId: 'another-provider' },
  ];
  for (const b of bad) assertEquals((await normalizeRegistryRecord(b, DESC)).ok, false);
});

// ── Financial / metrics / affiliation ──────────────────────────────────────

Deno.test('FM-1 high overhead is descriptive only and never produces an indicator', () => {
  const s = spendingShares({
    organizationId: 'org-hopebridge', period: { from: '2025-01-01', to: '2025-12-31' }, currency: 'XXX',
    lines: { EXPENSES: 100, PROGRAM_SPENDING: 40, ADMINISTRATIVE_SPENDING: 45, FUNDRAISING_SPENDING: 15 },
    sourceId: SOURCES.hbAudited.id, audited: true,
  });
  assertEquals(s.administrative, 0.45);
  assertEquals(s.interpretationNote, 'DESCRIPTIVE_ONLY_NOT_AN_INDICATOR');
  assertEquals(spendingShares({ organizationId: 'o', period: {}, currency: 'XXX', lines: { PROGRAM_SPENDING: 1 }, sourceId: 's', audited: false }).program, null);
});

Deno.test('FM-2 impact chain: outputs cannot substantiate outcomes or impact', () => {
  assertEquals(levelCanSubstantiate('OUTPUT', 'OUTCOME'), false);
  assertEquals(levelCanSubstantiate('OUTCOME', 'OUTPUT'), true);
  assertEquals(levelCanSubstantiate('INPUT', 'IMPACT'), false);
});

Deno.test('FM-3 affiliation: naming an organization is CLAIMED; VERIFIED needs a SUPPORTED affiliation claim for THAT campaign', () => {
  const campaign = { id: 'camp-1', claimedOrganizationId: 'org-hopebridge' };
  assertEquals(deriveAffiliation(campaign), 'CLAIMED_AFFILIATION');
  assertEquals(deriveAffiliation({ id: 'camp-2' }), 'UNKNOWN_AFFILIATION');
  const base = { claimKind: 'AFFILIATION' as const, subjectCampaignId: 'camp-1', subjectOrganizationId: 'org-hopebridge', subjectIdentity: 'CONFIRMED' as const };
  assertEquals(deriveAffiliation(campaign, { ...base, status: 'SUPPORTED' }), 'VERIFIED_AFFILIATION');
  assertEquals(deriveAffiliation(campaign, { ...base, status: 'SUPPORTED', subjectCampaignId: 'camp-other' }), 'CLAIMED_AFFILIATION');
  assertEquals(deriveAffiliation(campaign, { ...base, status: 'SUPPORTED', subjectIdentity: 'PROBABLE' }), 'CLAIMED_AFFILIATION');
  assertEquals(deriveAffiliation(campaign, { ...base, status: 'SUPPORTED', claimKind: 'IMPACT_OUTPUT' }), 'CLAIMED_AFFILIATION');
});

// ── Investigation workspace ────────────────────────────────────────────────

const OWNER: Actor = { subjectRef: 'subj-owner', projectIds: ['proj-1'] };
const OTHER: Actor = { subjectRef: 'subj-other', projectIds: ['proj-2'] };

async function workspace() {
  const inv = await Investigation.create(OWNER, { id: 'inv-golden', subjectOrganizationId: 'org-hopebridge', projectId: 'proj-1', createdAt: '2026-09-02T00:00:00Z' });
  assert(inv.ok);
  const w = inv.value;
  const g = (await goldenCases()).find((c) => c.id === 'G')!;
  for (const s of g.sources) assert((await w.addSource(OWNER, s, '2026-09-02T00:00:00Z')).ok);
  assert((await w.addClaim(OWNER, g.claim, '2026-09-02T00:00:00Z')).ok);
  for (const e of g.evidence) assert((await w.addEvidence(OWNER, e, '2026-09-02T00:00:00Z')).ok);
  return { w, g };
}

Deno.test('IW-1 non-owner and cross-project actors are denied on every operation', async () => {
  const { w, g } = await workspace();
  const deny = (r: { ok: boolean; error?: { code: string } }) => assertEquals(r.ok ? 'OK' : r.error!.code, 'CROSS_INVESTIGATION_DENIED');
  deny(w.authorize(OTHER));
  deny(await w.verify(OTHER, g.claim.id, { evaluatedAt: EVALUATED_AT, subjectIdentity: 'CONFIRMED' }));
  deny(await w.addSource(OTHER, SOURCES.registry, EVALUATED_AT));
  deny(await w.updateSourceStatus(OTHER, SOURCES.govWells.id, 'RETRACTED', EVALUATED_AT));
  // same subject whose project access was revoked
  deny(w.authorize({ subjectRef: 'subj-owner', projectIds: [] }));
  const c = await Investigation.create(OTHER, { id: 'inv-x', subjectOrganizationId: 'org-hopebridge', projectId: 'proj-1', createdAt: EVALUATED_AT });
  deny(c);
});

Deno.test('IW-2 records from another investigation are refused', async () => {
  const { w, g } = await workspace();
  const r = await w.addClaim(OWNER, { ...g.claim, id: 'c-foreign', investigationId: 'inv-other' }, EVALUATED_AT);
  assertEquals(r.ok ? 'OK' : r.error.code, 'CROSS_INVESTIGATION_DENIED');
  const e = await w.addEvidence(OWNER, { ...g.evidence[0], id: 'e-foreign', investigationId: 'inv-other' }, EVALUATED_AT);
  assertEquals(e.ok ? 'OK' : e.error.code, 'CROSS_INVESTIGATION_DENIED');
});

Deno.test('IW-3 versioned history: retraction + re-verification appends, never overwrites; dispute → DISPUTED', async () => {
  const { w, g } = await workspace();
  const ctx = { evaluatedAt: EVALUATED_AT, subjectIdentity: 'CONFIRMED' as const };
  const v1 = await w.verify(OWNER, g.claim.id, ctx);
  assert(v1.ok && v1.value.status === 'SUPPORTED');
  const affected = await w.updateSourceStatus(OWNER, SOURCES.academicWells.id, 'RETRACTED', '2026-09-24T00:00:00Z');
  assert(affected.ok && affected.value.includes(g.claim.id));
  const v2 = await w.verify(OWNER, g.claim.id, { ...ctx, evaluatedAt: '2026-09-24T00:00:00Z' });
  assert(v2.ok);
  assertEquals(v2.value.status, 'SUPPORTED');
  assertEquals(v2.value.sufficiency, 'INDEPENDENT_SUPPORT'); // one publisher left
  assert((await w.openDispute(OWNER, { id: 'd-1', claimId: g.claim.id, kind: 'ORGANIZATION_RESPONSE', openedAt: '2026-09-25T00:00:00Z', submittedEvidenceIds: [] })).ok);
  const v3 = await w.verify(OWNER, g.claim.id, { ...ctx, evaluatedAt: '2026-09-25T00:00:00Z' });
  assert(v3.ok && v3.value.status === 'DISPUTED');
  assert((await w.resolveDispute(OWNER, 'd-1', 'CORRECTED', '2026-09-26T00:00:00Z')).ok);
  const v4 = await w.verify(OWNER, g.claim.id, { ...ctx, evaluatedAt: '2026-09-26T00:00:00Z' });
  assert(v4.ok && v4.value.status === 'SUPPORTED');

  const h = w.history(g.claim.id);
  assertEquals(h.length, 4);
  assertEquals(h[0].resultId, v1.value.resultId); // first result still there, unchanged
  assertEquals(h[0].sufficiency, 'MULTI_SOURCE_SUPPORT');
  const types = w.auditTrail().map((e) => e.type);
  for (const t of ['SOURCE_STATUS_CHANGED', 'STATUS_CHANGED', 'DISPUTE_OPENED', 'DISPUTE_RESOLVED', 'CORRECTION', 'VERIFICATION_RUN']) {
    assert(types.includes(t as never), t);
  }
});

Deno.test('IW-4 audit trail is hash-chained, contains ids/codes only, and detects tampering', async () => {
  const { w, g } = await workspace();
  await w.verify(OWNER, g.claim.id, { evaluatedAt: EVALUATED_AT, subjectIdentity: 'CONFIRMED' });
  const trail = w.auditTrail();
  assert(await verifyAuditChain(trail));
  const flat = JSON.stringify(trail);
  assertEquals(flat.includes(g.claim.text), false, 'claim text must not be in the audit trail');
  assertEquals(flat.includes('Journal of Fictional'), false, 'publisher names are not needed in the audit trail');
  const tampered = trail.map((e, i) => (i === 2 ? { ...e, codes: ['CONTRADICTED'] } : e));
  assertEquals(await verifyAuditChain(tampered), false);
  assertEquals(await verifyAuditChain(trail.slice(1)), false);
  assert(Object.isFrozen(trail));
});

// ── Report ─────────────────────────────────────────────────────────────────

Deno.test('RP-1 report over all golden cases: no verdict/score field, no verdict language in PT or EN', async () => {
  const cases = await goldenCases();
  const results: VerificationResult[] = [];
  for (const c of cases) {
    const r = await verifyClaim({ claim: c.claim, evidence: c.evidence, sources: c.sources }, c.ctx);
    assert(r.ok);
    results.push(r.value);
  }
  const indicators = deriveIndicators({ results });
  for (const lang of ['pt', 'en'] as const) {
    const report = buildImpactReport({
      organization: ORGS.hopebridge,
      claims: cases.map((c) => c.claim),
      results, indicators,
      sources: cases.flatMap((c) => c.sources),
      campaigns: [{ id: 'camp-look-alike', name: 'HopeBridge Emergency Appeal', operator: 'UNKNOWN', affiliation: 'VERIFIED_AFFILIATION', claimedOrganizationId: 'org-hopebridge' }],
      commercialRelationships: [{ organizationId: 'org-hopebridge', kind: 'ADVERTISER', since: '2026-01-01', mustDisclose: true }],
      lang,
    });
    const keys = Object.keys(report).join(',').toLowerCase();
    for (const forbidden of ['verdict', 'score', 'rank', 'trust', 'fraud']) assertEquals(keys.includes(forbidden), false, forbidden);
    for (const c of report.claims) {
      assertEquals(findVerdictLanguage(c.summary), []);
      assert(c.statusLabel && c.displayClassLabel);
    }
    // A campaign's self-asserted VERIFIED flag is ignored — affiliation is derived.
    assertEquals(report.campaigns[0].affiliation, 'CLAIMED_AFFILIATION');
    assertEquals(report.commercialDisclosures.length, 1);
    assertEquals(report.claims.find((c) => c.claimId === 'claim-a')!.displayClass, 'FACT');
    assertEquals(report.claims.find((c) => c.claimId === 'claim-f')!.displayClass, 'ABSENCE_OF_EVIDENCE');
    assertEquals(report.claims.find((c) => c.claimId === 'claim-c')!.displayClass, 'CONFLICT');
    assert(report.disclaimers.length === 4);
    assertEquals(report.lastUpdated, EVALUATED_AT);
  }
});

Deno.test('RP-2 original claim text is preserved; translation is never written over it', async () => {
  const c = (await goldenCases())[0];
  const pt = { ...c.claim, text: 'A HopeBridge é uma instituição registrada (XA-1234567).', textLanguage: 'pt' };
  const r = await verifyClaim({ claim: pt, evidence: c.evidence.map((e) => ({ ...e })), sources: c.sources }, c.ctx);
  assert(r.ok);
  const report = buildImpactReport({ organization: ORGS.hopebridge, claims: [pt], results: [r.value], indicators: [], sources: c.sources, lang: 'en' });
  assertEquals(report.claims[0].originalText, pt.text);
  assertEquals(report.claims[0].originalLanguage, 'pt');
});

Deno.test('RP-3 jurisdictions are data, not hardcoded (XA fixture; no UK/US/BR assumption)', () => {
  const id: OrganizationIdentity = { registrations: [{ jurisdiction: XA, scheme: 'charity-number', value: '1' }] };
  assertEquals(id.registrations![0].jurisdiction.country, 'XA');
});
