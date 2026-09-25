// IV-IMPACT-I6 — presentation privacy (closes Codex I5F-03). Adversarial.
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { parseLabRequest } from './lab_contract.ts';
import { handleLabRequest, type LabResponse } from './lab_service.ts';
import { InMemoryImpactDatabase, InMemoryImpactLabStore } from './lab_store.ts';
import { present, presentUri, privateAddressSignal, privateNameSignal, PRIVACY_POLICY_VERSION, PRIVACY_SCAN_MAX, redactStructured } from './privacy.ts';

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
  assertEquals(presentUri('https://register.example/jane.placeholder/posts/1?token=abc', 'OFFICIAL_REGISTRY').text, 'https://register.example');
  assertEquals(presentUri('http://hopebridge.example/', undefined, ['hopebridge.example']).text, 'http://hopebridge.example');
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

// ── Codex I6 Gate 1 regressions (I6G1-01..08) ───────────────────────────────
Deno.test('PV-12 (I6G1-01) all-caps, initials, surname-first and caseless-script names are withheld', () => {
  for (const s of [
    'JOHN SMITH received the grant.',
    'Payment approved by J. Smith.',
    'Signed: SMITH, JOHN.',
    'Approved by J.R. SMITH on site.',
    '王小明 received the grant.',
    'تم التبرع من محمد علي',
    'Maria\nSilva received a grant.',
    'Maria\u200b Silva received a grant.',
  ]) {
    assertEquals(free(s).withheld, 'PERSONAL_DATA_RISK', s);
  }
  // Not names: acronyms, mixed-case instruction text, PT ordinal indicator, all-caps org words.
  for (const s of ['The UN and NGO partners met.', 'Set FACT and publish.', 'Relatório nº 12 publicado.', 'ANNUAL REPORT 2025 is out.']) {
    assertEquals(free(s).withheld, null, s);
  }
});

Deno.test('PV-13 (I6G1-02) a client-declared identity can NOT whitelist a person; only a registry name can', async () => {
  const t = lab();
  const inv = (await t.must({ action: 'create_investigation', subject: { ref: 'org-x', type: 'FOUNDATION', identity: { legalName: 'Jane Smith', publicName: 'Mary Major', aliases: ['John Doe'] } } })).data.investigationId as string;
  await t.must({ action: 'add_source', investigation_id: inv, source: { ref: 'src-web', type: 'ORGANIZATION_WEBSITE', publisher: 'Jane Smith', retrievedAt: '2026-09-01T00:00:00Z', retention: 'EXCERPT_AND_HASH', contentHash: 'b'.repeat(64) } });
  for (const [ref, text] of [['c1', 'Jane Smith received a grant.'], ['c2', 'John Doe signed.'], ['c3', 'Mary Major paid.']]) {
    await t.must({ action: 'add_claim', investigation_id: inv, claim: { ref, kind: 'OTHER', text, sourceRef: 'src-web', origin: 'MANUAL' } });
  }
  const d = (await t.must({ action: 'get_dossier', investigation_id: inv, lang: 'en' })).data as { dossier: { content: { claims: { textWithheld: string | null }[]; sources: { publisher: string }[] } } };
  assertEquals(d.dossier.content.claims.map((c) => c.textWithheld), ['PERSONAL_DATA_RISK', 'PERSONAL_DATA_RISK', 'PERSONAL_DATA_RISK']);
  assertEquals(d.dossier.content.sources[0].publisher, '—');
});

Deno.test('PV-14 (I6G1-03) a person as publisher is withheld under ANY source type unless registry-confirmed', () => {
  for (const type of ['NEWS', 'ORGANIZATION_WEBSITE', 'COURT_RECORD', 'ACADEMIC', 'SOCIAL_MEDIA', 'OTHER']) {
    assertEquals(present('PUBLISHER', 'Jane Smith', ORG, type).withheld, 'PERSONAL_DATA_RISK', type);
    assertEquals(present('PUBLISHER', 'JANE SMITH', ORG, type).withheld, 'PERSONAL_DATA_RISK', type);
  }
  assertEquals(present('PUBLISHER', 'BBC News', ORG, 'NEWS').text, 'BBC News');
  assertEquals(present('PUBLISHER', 'Exampleland Charity Registry (fixture)', ORG, 'OFFICIAL_REGISTRY').text, 'Exampleland Charity Registry (fixture)');
  assertEquals(present('PUBLISHER', 'Jane Smith', { orgNames: ['Jane Smith'] }, 'NEWS').text, 'Jane Smith', 'registry-confirmed name');
});

Deno.test('PV-15 (I6G1-05) Unicode e-mail / digits, labelled ids, MRZ and compact cards are redacted; ordinary words are not', () => {
  const cases: [string, string][] = [
    ['contato José@exemplo.com.br', 'José@'],
    ['رقم ١٢٣٤٥٦٧٨٩٠١٢ للتواصل', '٣٤٥'],
    ['call ０２０７９４６０９５８', '０９５８'],
    ['EIN 12-3456789', '3456789'],
    ['NIF 12345678Z', '12345678Z'],
    ['NIE X1234567L', 'X1234567L'],
    ['passport no. P1234567', 'P1234567'],
    ['P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<', 'ERIKSSON'],
    ['card 4111111111111111', '4111111111111111'],
  ];
  for (const [input, leak] of cases) {
    const r = redactStructured(input);
    assert(!r.text.includes(leak), `${input} → ${r.text}`);
    assert(r.redacted, input);
  }
  for (const s of ['tin roofs for 20 homes', 'the pan was donated', 'RG report', 'We built 20 wells in 2025.']) {
    assertEquals(redactStructured(s), { text: s, redacted: false }, s);
  }
});

Deno.test('PV-16 (I6G1-06) URLs: userinfo / port / path never shown; personal-host source types withheld entirely', () => {
  assertEquals(presentUri('https://user:pass@host.example:8443/a?b=c#d', 'REGULATOR').text, 'https://host.example');
  assertEquals(presentUri('https://bücher.example/x', 'GOVERNMENT_RECORD').text, 'https://xn--bcher-kva.example');
  assertEquals(presentUri('http://192.0.2.10:8080/p', 'COURT_RECORD').text, 'http://192.0.2.10');
  for (const type of ['SOCIAL_MEDIA', 'OTHER', 'USER_DOCUMENT']) assertEquals(presentUri('https://janedoe.example/', type).text, null, type);
  assertEquals(presentUri('https://hopebridge.example/about', 'ORGANIZATION_WEBSITE', ['hopebridge.example']).text, 'https://hopebridge.example');
});

Deno.test('PV-17 (I6G1-04/07) owner review DTOs are explicitly classified and withhold minor data; the dossier never includes them', async () => {
  const t = lab();
  const inv = (await t.must({ action: 'create_investigation', subject: SUBJECT })).data.investigationId as string;
  await t.must({ action: 'add_source', investigation_id: inv, source: { ref: 'src-web', type: 'ORGANIZATION_WEBSITE', publisher: 'HopeBridge Foundation', retrievedAt: '2026-09-01T00:00:00Z', retention: 'EXCERPT_AND_HASH', contentHash: 'b'.repeat(64) } });
  await t.must({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c-minor', kind: 'OTHER', text: 'Ana, a girl aged 9, lives near the well.', sourceRef: 'src-web', origin: 'MANUAL' } });
  const g = await t.must({ action: 'get_investigation', investigation_id: inv });
  assert(!JSON.stringify(g.data).includes('aged 9'), 'minor data withheld even in the owner review DTO');
  assertEquals((g.data as { privacy: { class: string } }).privacy.class, 'OWNER_REVIEW_RAW');
  const d = await t.must({ action: 'get_dossier', investigation_id: inv, lang: 'en' });
  const dj = JSON.stringify(d.data);
  assert(!dj.includes('OWNER_REVIEW_RAW') && !dj.includes('aged 9'));
});

// ── Codex I6 Gate 1 re-audit regressions (I6G1R-01..06) ─────────────────────
Deno.test('PV-18 (I6G1R-01) text with no PII is returned byte-identical (Unicode digits untouched); redaction is always flagged', () => {
  for (const s of ['Projeto 𞥐𞥑 wells', 'مشروع ١٢ بئر', 'Relatório nº ١٢٣', 'HopeBridge Foundation built ２０ wells.']) {
    const r = redactStructured(s);
    assertEquals(r, { text: s, redacted: false }, s);
  }
  const r = redactStructured('call ٠٢٠٧٩٤٦٠٩٥٨ now');
  assert(r.redacted && !r.text.includes('٩٤٦'));
});

Deno.test('PV-19 (I6G1R-02) e-mails with combining marks / IDN and social handles are redacted as whole tokens', () => {
  for (const [s, leak] of [
    ['contato jos\u0301e@example.com', 'jos'],
    ['write to (maria.silva@exemplo.com.br).', 'maria.silva'],
    ['mail ānna@bücher.example today', 'ānna'],
    ['follow @jane.placeholder for updates', 'jane.placeholder'],
  ] as [string, string][]) {
    const r = redactStructured(s);
    assert(r.redacted && !r.text.includes(leak), `${s} → ${r.text}`);
  }
});

Deno.test('PV-20 (I6G1R-03) adversarial inputs at the maximum accepted size stay within a time budget; oversize is withheld', () => {
  const max = 4_000;
  const inputs = [
    'A.'.repeat(max / 2),
    'a'.repeat(max - 1) + '@',
    'x'.repeat(max - 10) + ' at foo dot',
    'P<' + 'A'.repeat(max - 2),
    '1 '.repeat(max / 2),
    'EIN ' + '1-'.repeat((max - 4) / 2),
    'Aa '.repeat(max / 3),
    'J. '.repeat(max / 3),
  ];
  for (const s of inputs) {
    const t0 = performance.now();
    for (const kind of ['FREE_TEXT', 'PUBLISHER', 'DECLARED_ORG_NAME', 'ORGANIZATION_NAME'] as const) present(kind, s, ORG, 'NEWS');
    const ms = performance.now() - t0;
    assert(ms < 500, `${s.slice(0, 12)}… took ${ms.toFixed(0)} ms`);
  }
  assertEquals(free('a '.repeat(2_001)).withheld, 'PERSONAL_DATA_RISK', 'longer than the scan limit ⇒ withheld');
});

Deno.test('PV-21 (I6G1R-04) a person declared as the subject is withheld in the identity block, with a limitation', async () => {
  const t = lab();
  const inv = (await t.must({ action: 'create_investigation', subject: { ref: 'org-x', type: 'FOUNDATION', identity: { legalName: 'Jane Smith', aliases: ['Mr Doe'], domains: ['janesmith.example'] } } })).data.investigationId as string;
  const d = (await t.must({ action: 'get_dossier', investigation_id: inv, lang: 'en' })).data as { dossier: { content: { subject: { declaredIdentity: { legalName: string; aliases: string[] } }; limitations: { code: string; scope: string }[] } }; text: string };
  assertEquals(d.dossier.content.subject.declaredIdentity.legalName, '—');
  assertEquals(d.dossier.content.subject.declaredIdentity.aliases, ['—']);
  assert(d.dossier.content.limitations.some((l) => l.code === 'EXCERPT_WITHHELD' && l.scope === 'IDENTITY'));
  assert(!JSON.stringify(d).includes('Jane Smith') && !d.text.includes('Jane Smith'));
  // An organization name keeps showing.
  const t2 = lab();
  const inv2 = (await t2.must({ action: 'create_investigation', subject: SUBJECT })).data.investigationId as string;
  const d2 = (await t2.must({ action: 'get_dossier', investigation_id: inv2, lang: 'en' })).data as { dossier: { content: { subject: { declaredIdentity: { legalName: string } } } } };
  assertEquals(d2.dossier.content.subject.declaredIdentity.legalName, 'HopeBridge Foundation');
});

Deno.test('PV-22 (I6G1R-06) URL origin shown only for institutional types or the subject\'s own domains', () => {
  assertEquals(presentUri('https://janedoe.example/x', 'NEWS').text, null);
  assertEquals(presentUri('https://janedoe.example/x', 'ORGANIZATION_WEBSITE').text, null);
  assertEquals(presentUri('https://www.hopebridge.example/about', 'ORGANIZATION_WEBSITE', ['hopebridge.example']).text, 'https://www.hopebridge.example');
  assertEquals(presentUri('https://evilhopebridge.example/', 'ORGANIZATION_WEBSITE', ['hopebridge.example']).text, null, 'suffix trick');
  assertEquals(presentUri('https://register.gov.example/entry/1', 'OFFICIAL_REGISTRY').text, 'https://register.gov.example');
  assertEquals(presentUri('https://court.example/case/9', 'COURT_RECORD').text, 'https://court.example');
});

Deno.test('PV-23 (I6G1R-05) the owner review DTO is scrubbed for minor data in EVERY string field', async () => {
  const t = lab();
  const inv = (await t.must({ action: 'create_investigation', subject: SUBJECT })).data.investigationId as string;
  await t.must({ action: 'add_source', investigation_id: inv, source: { ref: 'src-web', type: 'ORGANIZATION_WEBSITE', publisher: 'Parents of a boy aged 7', retrievedAt: '2026-09-01T00:00:00Z', retention: 'EXCERPT_AND_HASH', contentHash: 'b'.repeat(64) } });
  await t.must({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c1', kind: 'OTHER', text: 'Ana, a girl aged 9, lives near the well.', sourceRef: 'src-web', origin: 'MANUAL' } });
  const g = await t.must({ action: 'get_investigation', investigation_id: inv });
  const raw = JSON.stringify(g.data);
  assert(!raw.includes('aged 7') && !raw.includes('aged 9'), raw.slice(0, 200));
});

// ── Codex I6 Gate 1 re-audit #2 regressions (I6G1R2-01/02) ──────────────────
Deno.test('PV-24 (I6G1R2-01) e-mails / handles next to ANY punctuation are redacted', () => {
  const around = ['—', '…', '/', '–', '»', '«', '"', '”', '“', '(', ')', '[', ']', ',', '.', ';', ':', '!', '?', '·', '|', '¿', '¡', '、', '。'];
  for (const p of around) {
    for (const id of ['josé@example.com', 'jane.doe@mail.example', '@jane', '@jane.placeholder']) {
      for (const s of [`${id}${p}`, `${p}${id}`, `x${p}${id}${p}y`]) {
        const r = redactStructured(s);
        assert(r.redacted && !r.text.includes(id.replace(/^@/, '')), `${JSON.stringify(s)} → ${JSON.stringify(r.text)}`);
      }
    }
  }
  // Separators other than ASCII space also split tokens.
  assert(!redactStructured('mail\u00a0josé@example.com\u3000now').text.includes('josé'));
});

Deno.test('PV-25 (I6G1R2-01) end-to-end: punctuation-wrapped identifiers never reach dossier JSON or text', async () => {
  const t = lab();
  const inv = (await t.must({ action: 'create_investigation', subject: SUBJECT })).data.investigationId as string;
  await t.must({ action: 'add_source', investigation_id: inv, source: { ref: 'src-web', type: 'ORGANIZATION_WEBSITE', publisher: 'HopeBridge Foundation', retrievedAt: '2026-09-01T00:00:00Z', retention: 'EXCERPT_AND_HASH', contentHash: 'b'.repeat(64) } });
  await t.must({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c1', kind: 'OTHER', text: 'Write to josé@example.com— or @jane… for the wells.', sourceRef: 'src-web', origin: 'MANUAL' } });
  for (const action of ['get_dossier', 'export_dossier']) {
    const all = JSON.stringify((await t.must({ action, investigation_id: inv, lang: 'en' })).data);
    assert(!all.includes('josé@') && !all.includes('@jane'), action);
  }
});

Deno.test('PV-26 (contract) no presented free-text field can exceed the 4,000-char scan limit; oversize is rejected at the door', () => {
  const inv = '00000000-0000-4000-8000-000000000001';
  const claim = (n: number) => parseLabRequest({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c', kind: 'OTHER', text: 'a'.repeat(n), sourceRef: 's', origin: 'MANUAL' } });
  assert(claim(4_000).ok);
  for (const n of [4_001, 10_000, 100_000]) assert(!claim(n).ok, `claim ${n}`);
  const ev = (n: number) => parseLabRequest({ action: 'add_evidence', investigation_id: inv, evidence: { ref: 'e', claimRef: 'c', sourceRef: 's', aboutOrgRef: 'o', relationship: 'SUPPORTS', basis: 'HUMAN_ASSESSED', personalData: 'NONE', excerpt: 'a'.repeat(n) } });
  assert(ev(2_000).ok);
  for (const n of [2_001, 10_000, 100_000]) assert(!ev(n).ok, `excerpt ${n}`);
  assertEquals(PRIVACY_SCAN_MAX, 4_000);
});

Deno.test('PV-27 (I6G1R2-02) the only change to safe text is the intentional removal of invisible / bidi characters', () => {
  assertEquals(free('HopeBridge\u200b Foundation built 20 wells.').text, 'HopeBridge Foundation built 20 wells.');
  assertEquals(free('HopeBridge Foundation built ２０ wells in ٢٠٢٥.').text, 'HopeBridge Foundation built ２０ wells in ٢٠٢٥.');
});

Deno.test('PV-28 (I6G1R3-01) look-alike @ and spelled-out "at" e-mails are redacted; safe text keeps NBSP and digits', () => {
  for (const s of [
    'maria\uFF20example.com', 'maria\uFE6Bexample.com', 'maria (at) example.com', 'maria [at] example [dot] com',
    'maria at example.com', 'maria arroba exemplo.com.br', 'maria (arroba) exemplo (ponto) com', 'write to maria (at) example.com—now',
  ]) {
    const r = redactStructured(s);
    assert(r.redacted && !r.text.includes('maria'), `${s} → ${r.text}`);
  }
  for (const s of ['We met at 10.30 am.', 'Wells built that year.', 'HopeBridge Foundation\u00a02025']) {
    assertEquals(redactStructured(s), { text: s, redacted: false }, s);
  }
  assertEquals(free('HopeBridge Foundation\u00a0built 20 wells.').text, 'HopeBridge Foundation\u00a0built 20 wells.');
});

Deno.test('PV-29 (I6G1R4) every realistic encoding from the exhaustive pass is withheld by the backstop (whole value)', () => {
  for (const s of [
    'maria&#64;example.com', 'maria&#x40;example.com', 'maria&commat;example.com', 'follow &#64;jane',
    'maria em exemplo.com', 'maria chez example.com', 'maria arroba exemplo punto com', 'maria at sign example dot com',
    'maria @ example.com', 'm a r i a @ e x a m p l e . c o m',
    'call 020/7946/0958', 'call 020\u20127946\u20120958', 'call 020\u20117946\u20110958', 'call 020\u00b77946\u00b70958',
    'pay gb82 west 1234 5698 7654 32', 'acct 123456', 'account no 123456', 'a/c 123456', 'VAT 123456789', 'USt-IdNr DE123456789',
    'GSTIN 22AAAAA0000A1Z5', 'numéro de compte 12345678', 'contact @a now',
  ]) {
    const r = present('FREE_TEXT', s, ORG);
    assertEquals(r.text, null, `${s} → ${r.text}`);
  }
});

Deno.test('PV-30 (I6G1R4) the backstop does not fire on ordinary PT / EN impact prose', () => {
  for (const s of [
    'HopeBridge Foundation built 20 wells in 2025.',
    'O projeto começou em 2019. Hoje atende 3 distritos.',
    'The charity raised £1,250,000 in 2024.',
    'A fundação arrecadou R$ 1.250.000,50 em 2023.',
    'Between 2019-2025 the programme reached 12 000 000 people.',
    'The report was published on 2026-09-01.',
    'Meet at the school. Then visit the well.',
    'Relatório nº 12 publicado em março.',
    'Coverage rose to 87% at 14 sites.',
  ]) {
    assertEquals(present('FREE_TEXT', s, ORG).text, s, s);
  }
});

Deno.test('PV-31 (I6G1R4) end-to-end: encoded identifiers never reach dossier JSON or text', async () => {
  const t = lab();
  const inv = (await t.must({ action: 'create_investigation', subject: SUBJECT })).data.investigationId as string;
  await t.must({ action: 'add_source', investigation_id: inv, source: { ref: 'src-web', type: 'ORGANIZATION_WEBSITE', publisher: 'HopeBridge Foundation', retrievedAt: '2026-09-01T00:00:00Z', retention: 'EXCERPT_AND_HASH', contentHash: 'b'.repeat(64) } });
  await t.must({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c1', kind: 'OTHER', text: 'Donations to maria&#64;example.com or 020/7946/0958 fund wells.', sourceRef: 'src-web', origin: 'MANUAL' } });
  for (const action of ['get_dossier', 'export_dossier']) {
    const all = JSON.stringify((await t.must({ action, investigation_id: inv, lang: 'pt' })).data);
    assert(!all.includes('maria') && !all.includes('7946'), action);
  }
});

Deno.test('PV-32 (I6G1R5-02) a withheld lineage name leaves a visible limitation', async () => {
  const t = lab();
  const inv = (await t.must({ action: 'create_investigation', subject: SUBJECT })).data.investigationId as string;
  await t.must({ action: 'add_source', investigation_id: inv, source: { ref: 'src-news', type: 'NEWS', newsGenre: 'REPORTING', publisher: 'Daily Fixture', syndicatedFrom: 'Jane Smith', retrievedAt: '2026-09-01T00:00:00Z', retention: 'EXCERPT_AND_HASH', contentHash: 'c'.repeat(64) } });
  const d = (await t.must({ action: 'get_dossier', investigation_id: inv, lang: 'en' })).data as { dossier: { content: { sources: { ref: string; syndicatedFrom: string | null }[]; limitations: { code: string; scope: string; ref: string | null }[] } } };
  assertEquals(d.dossier.content.sources.find((s) => s.ref === 'src-news')!.syndicatedFrom, null);
  assert(d.dossier.content.limitations.some((l) => l.code === 'EXCERPT_WITHHELD' && l.scope === 'SOURCE' && l.ref === 'src-news'));
});
