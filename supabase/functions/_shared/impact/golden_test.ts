// IV-IMPACT-FOUNDATION-01 — golden evidence datasets A–H (fixtures/golden.ts).
// Every expected field of every case is asserted; a behaviour change in the
// engine must show up here as an explicit golden diff.
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { goldenCases } from './fixtures/golden.ts';
import { deriveIndicators } from './risk_indicators.ts';
import { acceptLlmClaimCandidates, scanUntrustedContent } from './safety.ts';
import { verifyClaim } from './verification.ts';

const cases = await goldenCases();

for (const c of cases) {
  Deno.test(`GOLDEN-${c.id} ${c.title}`, async () => {
    const r = await verifyClaim({ claim: c.claim, evidence: c.evidence, sources: c.sources }, c.ctx);
    assert(r.ok, r.ok ? '' : `${r.error.code}: ${r.error.message}`);
    const v = r.value;
    const x = c.expected;
    assertEquals(v.status, x.status, 'status');
    assertEquals(v.sufficiency, x.sufficiency, 'sufficiency');
    assertEquals(v.displayClass, x.displayClass, 'displayClass');
    assertEquals(v.reviewState, x.reviewState, 'reviewState');
    for (const g of x.gapsInclude) assert(v.gaps.includes(g), `gap ${g} expected, got ${v.gaps}`);
    for (const g of x.gapsExclude ?? []) assert(!v.gaps.includes(g), `gap ${g} must be absent`);
    if (x.supportingIds) assertEquals(v.supporting.map((a) => a.evidenceId).sort(), [...x.supportingIds].sort());
    if (x.contradictingIds) assertEquals(v.contradicting.map((a) => a.evidenceId).sort(), [...x.contradictingIds].sort());
    if (x.excludedIds) assertEquals(v.excluded.map((a) => a.evidenceId).sort(), [...x.excludedIds].sort());
    if (x.conflictValues) {
      assertEquals(v.conflicts.length, 1);
      assertEquals(v.conflicts[0].resolution, 'UNRESOLVED');
      assertEquals(v.conflicts[0].positions.map((p) => p.reportedValue).sort((a, b) => a! - b!), [...x.conflictValues]);
    }
    assertEquals(v.isFindingOfWrongdoing, false);
    assertEquals(v.absenceOfEvidenceIsNotEvidenceOfWrongdoing, true);

    const indicators = deriveIndicators({ results: [v] });
    const codes = indicators.map((i) => i.code);
    for (const i of x.indicatorsInclude) assert(codes.includes(i), `indicator ${i} expected, got ${codes}`);
    for (const i of x.indicatorsExclude) assert(!codes.includes(i), `indicator ${i} must be absent`);
    if (x.noConcernIndicators) assertEquals(indicators.filter((i) => i.polarity === 'CONCERN'), []);
    for (const i of indicators) assertEquals(i.isProofOfWrongdoing, false);

    if (x.injectionMarkers) {
      const scan = scanUntrustedContent(c.documentText!);
      assertEquals(scan.markers, [...x.injectionMarkers]);
      assertEquals(scan.treatedAs, 'UNTRUSTED_DATA');
    }
  });
}

Deno.test('GOLDEN-H2 LLM extraction from the injected document: grounded claims only, never verified', () => {
  const h = cases.find((c) => c.id === 'H')!;
  const out = acceptLlmClaimCandidates(
    [
      // grounded; the "verified"/"status" fields the model adds are ignored
      { kind: 'IMPACT_OUTPUT', quote: 'We built 50 schools across the region in 2025.', subjectOrganizationId: 'org-hopebridge', verified: true, status: 'SUPPORTED' },
      // hallucinated — not in the document
      { kind: 'IMPACT_OUTPUT', quote: 'We built 500 hospitals in 2025.', subjectOrganizationId: 'org-hopebridge' },
      // a subject the investigation does not know
      { kind: 'LEGAL_REGISTRATION', quote: 'HopeBridge Foundation Annual Report 2025.', subjectOrganizationId: 'org-real-world-charity' },
    ],
    { sourceId: h.sources[0].id, text: h.documentText!, language: 'en' },
    { investigationId: 'inv-golden', extractedAt: '2026-09-02T00:00:00Z', knownOrganizationIds: new Set(['org-hopebridge']), idPrefix: 'llm-h-' },
  );
  assertEquals(out.accepted.length, 1);
  assertEquals(out.accepted[0].origin, 'LLM_EXTRACTED');
  assertEquals(Object.keys(out.accepted[0]).includes('verified'), false);
  assertEquals(Object.keys(out.accepted[0]).includes('status'), false);
  assertEquals(out.rejected.map((r) => r.reason), ['NOT_GROUNDED', 'UNKNOWN_SUBJECT']);
});

Deno.test('GOLDEN-ALL same inputs → same resultId and evidenceSetHash (reproducibility)', async () => {
  for (const c of cases) {
    const a = await verifyClaim({ claim: c.claim, evidence: c.evidence, sources: c.sources }, c.ctx);
    const b = await verifyClaim({ claim: c.claim, evidence: [...c.evidence].reverse(), sources: [...c.sources].reverse() }, c.ctx);
    assert(a.ok && b.ok);
    assertEquals(a.value.resultId, b.value.resultId, c.id);
    assertEquals(a.value.evidenceSetHash, b.value.evidenceSetHash, c.id);
    assertEquals(a.value.status, b.value.status, c.id);
  }
});
