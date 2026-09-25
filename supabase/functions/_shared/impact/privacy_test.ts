// IV-IMPACT-I6 — presentation privacy (closes Codex I5F-03). Adversarial.
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { parseLabRequest } from './lab_contract.ts';
import { handleLabRequest, type LabResponse } from './lab_service.ts';
import { InMemoryImpactDatabase, InMemoryImpactLabStore } from './lab_store.ts';
import { present, presentUri, privateAddressSignal, privateNameSignal, PRIVACY_POLICY_VERSION, redactStructured } from './privacy.ts';

const ORG = { orgNames: ['HopeBridge Foundation', 'HopeBridge'] };
const free = (s: string) => present('FREE_TEXT', s, ORG);

Deno.test('PV-01 structured identifiers are redacted in every field kind', () => {
  const cases: [string, string][] = [
    ['write to jane.doe@mail.example', 'jane.doe@mail.example'],
    ['jane [at] mail [dot] example', 'mail [dot] example'],
    ['call +44 20 7946 0958 today', '7946'],
    ['IBAN GB29 NWBK 6016 1331 9268 19', 'NWBK'],
    ['card 4111 1111 1111 1111 on file', '4111'],
    ['sort code 12-34-56 12345678', '12345678'],
    ['NI number AB 12 34 56 C', 'AB 12 34 56 C'],
    ['conta nº 12345-6 agência 0001', '12345-6'],
    ['CPF 123.456.789-09', '123.456.789'],
    ['SSN 123-45-6789', '123-45-6789'],
    ['id 12345678901', '12345678901'],
  ];
  for (const kind of ['FREE_TEXT', 'ORGANIZATION_NAME', 'PUBLISHER'] as const) {
    for (const [input, leak] of cases) {
      const r = present(kind, input, ORG, 'NEWS');
      assert(r.text === null || !r.text.includes(leak), `${kind}: ${input} → ${r.text}`);
      if (r.text !== null) assert(r.redacted, `${kind}: ${input} must be flagged redacted`);
    }
  }
  // Not every long number is a card: a non-Luhn 16-digit run is still caught as a long/phone-like number, never shown.
  assert(!redactStructured('ref 1234 5678 9012 3456').text.includes('9012'));
});

Deno.test('PV-02 private-name signals withhold the whole free text (fail-closed)', () => {
  for (const s of [
    'Mr Smith donated the pump.',
    'Maria Silva received a grant.',
    'In January Maria Silva opened the site.',
    'Volunteer João da Silva manages the well.',
    'Sra. Ana confirmou a entrega.',
    'Our treasurer Jones signed the accounts.',
    'The donor Priya Raman paid for it.',
    'Trustee Jane Example signed the report.',
  ]) {
    const r = free(s);
    assertEquals([r.text, r.withheld], [null, 'PERSONAL_DATA_RISK'], s);
  }
});

Deno.test('PV-03 private-address signals withhold the whole free text', () => {
  for (const s of [
    'Deliveries go to 12 Station Road.',
    'Sede na Rua das Flores, 123.',
    'Flat 4 above the shop.',
    'Post to SW1A 1AA.',
    'CEP 01310-100.',
    'Write to PO Box 123.',
    'Apartamento 42, bloco B.',
  ]) {
    assertEquals(free(s).withheld, 'PERSONAL_DATA_RISK', s);
  }
});

Deno.test('PV-04 organizational text stays visible (no signal)', () => {
  for (const s of [
    'HopeBridge Foundation built 20 wells in 2025.',
    'HopeBridge Foundation operates in two districts.',
    'A reporter counted 12 wells.',
    'The donor list is published every year.',
    '10,000 children received meals in the United Kingdom.',
    'The Exampleland Company Registry lists the charity as active.',
    'We built 20 wells.',
  ]) {
    const r = free(s);
    assertEquals([r.withheld, r.text], [null, s], s);
  }
});

Deno.test('PV-05 minors: MINOR_DATA_RISK wins over every other rule, in every field kind', () => {
  for (const kind of ['FREE_TEXT', 'ORGANIZATION_NAME', 'PUBLISHER'] as const) {
    const r = present(kind, 'Maria, a girl aged 9, lives at 12 Station Road', ORG, 'NEWS');
    assertEquals([r.text, r.withheld], [null, 'MINOR_DATA_RISK'], kind);
  }
});

Deno.test('PV-06 a known ORGANIZATION name is exempt only when it comes from a trusted origin', () => {
  assertEquals(free('HopeBridge Foundation thanked its partners.').withheld, null);
  // The same capitalized pair NOT on record is treated as a possible person.
  assertEquals(free('Lumen Partners thanked its partners.').withheld, 'PERSONAL_DATA_RISK');
  assert(privateNameSignal('Jane Placeholder spoke.', []));
  assert(!privateNameSignal('Jane Placeholder spoke.', ['Jane Placeholder']), 'only a trusted org list can exempt');
});

Deno.test('PV-07 publishers: organizational types shown; SOCIAL_MEDIA / OTHER only when on record', () => {
  assertEquals(present('PUBLISHER', 'Daily Fixture', ORG, 'NEWS').text, 'Daily Fixture');
  assertEquals(present('PUBLISHER', 'Jane Placeholder (@jane.placeholder)', ORG, 'SOCIAL_MEDIA').withheld, 'PERSONAL_DATA_RISK');
  assertEquals(present('PUBLISHER', '@janeplaceholder', ORG, 'OTHER').withheld, 'PERSONAL_DATA_RISK');
  assertEquals(present('PUBLISHER', 'HopeBridge Foundation', ORG, 'SOCIAL_MEDIA').text, 'HopeBridge Foundation');
});

Deno.test('PV-08 URLs are presented as origin only; non-http and garbage are withheld', () => {
  assertEquals(presentUri('https://social.example/jane.placeholder/posts/1?token=abc').text, 'https://social.example');
  assertEquals(presentUri('http://hopebridge.example/').text, 'http://hopebridge.example');
  assertEquals(presentUri('javascript:alert(1)').text, null);
  assertEquals(presentUri('mailto:jane@mail.example').text, null);
  assertEquals(presentUri('not a url').text, null);
  assertEquals(presentUri(null).text, null);
});

Deno.test('PV-09 invisible / bidi characters cannot split a signal', () => {
  assertEquals(free('Maria\u200b Silva received a grant.').withheld, 'PERSONAL_DATA_RISK');
  assert(privateAddressSignal('12 Station\u00a0Road'));
});

// ── end-to-end through the real Lab service ─────────────────────────────────
const UA = 'aaaaaaaa-0000-4000-8000-00000000000a';
function lab() {
  const db = new InMemoryImpactDatabase();
  let clock = Date.UTC(2026, 8, 25, 9, 0, 0);
  const must = async (body: Record<string, unknown>): Promise<LabResponse> => {
    const p = parseLabRequest(body);
    if (!p.ok) throw new Error(p.error.code);
    clock += 60_000;
    const r = await handleLabRequest(new InMemoryImpactLabStore(db, UA), { userId: UA }, p.value, new Date(clock).toISOString());
    if (!r.ok) throw new Error(`${body.action}: ${r.error.code} ${r.error.message}`);
    return r.value;
  };
  return { db, must };
}
const SUBJECT = {
  ref: 'org-hopebridge', type: 'FOUNDATION',
  identity: { legalName: 'HopeBridge Foundation', registrations: [{ country: 'XA', scheme: 'charity-number', value: 'XA-1234567' }], domains: ['hopebridge.example'] },
};
const PRIVATE = ['Maria Placeholder', '12 Example Road', 'Mr Placeholder', 'jane.placeholder', 'Jane Placeholder'];

async function privateInvestigation() {
  const t = lab();
  const inv = (await t.must({ action: 'create_investigation', subject: SUBJECT })).data.investigationId as string;
  await t.must({ action: 'add_source', investigation_id: inv, source: { ref: 'src-web', type: 'ORGANIZATION_WEBSITE', publisher: 'HopeBridge Foundation', publisherOrgRef: 'org-hopebridge', retrievedAt: '2026-09-01T00:00:00Z', retention: 'EXCERPT_AND_HASH', contentHash: 'b'.repeat(64) } });
  await t.must({ action: 'add_source', investigation_id: inv, source: { ref: 'src-social', type: 'SOCIAL_MEDIA', publisher: 'Jane Placeholder (@jane.placeholder)', uri: 'https://social.example/jane.placeholder', retrievedAt: '2026-09-01T00:00:00Z', retention: 'REFERENCE_ONLY' } });
  await t.must({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c-private', kind: 'OTHER', text: 'Volunteer Maria Placeholder lives at 12 Example Road.', sourceRef: 'src-web', origin: 'MANUAL' } });
  await t.must({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c-org', kind: 'OTHER', text: 'HopeBridge Foundation operates in two districts.', sourceRef: 'src-web', origin: 'MANUAL' } });
  await t.must({ action: 'add_evidence', investigation_id: inv, evidence: { ref: 'e-private', claimRef: 'c-org', sourceRef: 'src-web', aboutOrgRef: 'org-hopebridge', relationship: 'CONTEXTUALIZES', basis: 'HUMAN_ASSESSED', personalData: 'NONE', excerpt: 'Our treasurer Mr Placeholder confirmed the two districts.' } });
  return { t, inv };
}

Deno.test('PV-10 live dossier, export JSON, snapshot and text never carry the withheld data; stored evidence is untouched', async () => {
  const { t, inv } = await privateInvestigation();
  for (const action of ['get_dossier', 'export_dossier']) {
    for (const lang of ['pt', 'en']) {
      const r = await t.must({ action, investigation_id: inv, lang });
      const everything = JSON.stringify(r.data);
      for (const leak of PRIVATE) assert(!everything.includes(leak), `${action}/${lang} leaked ${leak}`);
      const d = (r.data as { dossier: { content: Record<string, unknown> } }).dossier.content as {
        claims: { ref: string; text: string | null; textWithheld: string | null }[];
        evidence: { ref: string; excerptWithheld: string | null }[];
        limitations: { code: string; ref: string | null }[];
        policyVersions: Record<string, string>;
      };
      assertEquals(d.claims.find((c) => c.ref === 'c-private')!.textWithheld, 'PERSONAL_DATA_RISK');
      assertEquals(d.claims.find((c) => c.ref === 'c-org')!.text, 'HopeBridge Foundation operates in two districts.');
      assertEquals(d.evidence.find((e) => e.ref === 'e-private')!.excerptWithheld, 'PERSONAL_DATA_RISK');
      assert(d.limitations.some((l) => l.code === 'EXCERPT_WITHHELD' && l.ref === 'c-private'));
      assert(d.limitations.some((l) => l.code === 'EXCERPT_WITHHELD' && l.ref === 'src-social'));
      assertEquals(d.policyVersions.privacy, PRIVACY_POLICY_VERSION);
    }
  }
  // stored evidence ≠ safe presentation: the store keeps the original text.
  const stored = JSON.stringify([...t.db.investigations.values()], (_k, v) => (v instanceof Map ? [...v.values()] : v));
  assert(stored.includes('Volunteer Maria Placeholder lives at 12 Example Road.'), 'presentation policy must not destroy stored evidence');
});

Deno.test('PV-11 an issued snapshot verifies CURRENT under the same policy (the policy is part of the hashed content)', async () => {
  const { t, inv } = await privateInvestigation();
  const exp = await t.must({ action: 'export_dossier', investigation_id: inv, lang: 'en' });
  const doc = (exp.data as { dossier: { integrity: { contentHash: string }; envelope: Record<string, unknown> } }).dossier;
  const v = await t.must({ action: 'verify_dossier', investigation_id: inv, content_hash: doc.integrity.contentHash, envelope: doc.envelope });
  assertEquals((v.data as { state: string }).state, 'CURRENT');
});
