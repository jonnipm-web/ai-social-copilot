/**
 * IV-IMPACT-I5 — Flutter UI fixtures produced by the REAL Lab service over
 * the in-memory store (synthetic XA organizations only), in the exact
 * impact-lab response shape. The Flutter tests consume these files, so the
 * UI is proven against the true I4 contract, not a hand-written imitation.
 * `ui_fixtures_test.ts` fails CI when the committed files drift from what
 * the engine produces. Deterministic: fixed clock, fixed ids.
 */
import { parseLabRequest } from '../lab_contract.ts';
import { handleLabRequest } from '../lab_service.ts';
import { InMemoryImpactDatabase, InMemoryImpactLabStore } from '../lab_store.ts';

const UA = 'aaaaaaaa-0000-4000-8000-00000000000a';
type Json = Record<string, unknown>;

const HOPEBRIDGE = {
  ref: 'org-hopebridge', type: 'FOUNDATION',
  identity: { legalName: 'HopeBridge Foundation', registrations: [{ country: 'XA', scheme: 'charity-number', value: 'XA-1234567' }], domains: ['hopebridge.example'] },
};

function harness() {
  const db = new InMemoryImpactDatabase();
  let clock = Date.UTC(2026, 8, 25, 9, 0, 0);
  const call = async (body: Json) => {
    const p = parseLabRequest(body);
    if (!p.ok) throw new Error(`${String(body.action)}: ${p.error.code}`);
    clock += 60_000;
    const r = await handleLabRequest(new InMemoryImpactLabStore(db, UA), { userId: UA }, p.value, new Date(clock).toISOString());
    if (!r.ok) throw new Error(`${String(body.action)}: ${r.error.code} ${r.error.message}`);
    // exactly the impact-lab success envelope
    return { ok: true, action: r.value.action, data: r.value.data, correlation_id: '00000000-0000-4000-8000-00000000c0de' };
  };
  return { call };
}

async function base(h: ReturnType<typeof harness>, registry = true) {
  const inv = ((await h.call({ action: 'create_investigation', subject: HOPEBRIDGE })).data as Json).investigationId as string;
  if (registry) await h.call({ action: 'ingest_provider_record', investigation_id: inv, provider_id: 'fixture-xa-charity-registry', record_id: 'xa-1234567', ref: 'src-reg' });
  await h.call({ action: 'add_source', investigation_id: inv, source: { ref: 'src-web', type: 'ORGANIZATION_WEBSITE', publisher: 'HopeBridge Foundation', publisherOrgRef: 'org-hopebridge', retrievedAt: '2026-09-01T00:00:00Z', retention: 'EXCERPT_AND_HASH', contentHash: 'b'.repeat(64) } });
  return inv;
}

const regClaim = (inv: string) => ({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c-reg', kind: 'LEGAL_REGISTRATION', text: 'HopeBridge Foundation is a registered charity.', sourceRef: 'src-web', origin: 'MANUAL' } });
const regEvidence = (inv: string) => ({ action: 'add_evidence', investigation_id: inv, evidence: { ref: 'e-reg', claimRef: 'c-reg', sourceRef: 'src-reg', aboutOrgRef: 'org-hopebridge', relationship: 'SUPPORTS', basis: 'HUMAN_ASSESSED', observedPeriod: { to: '2026-09-01' }, personalData: 'NONE' } });

export async function buildUiFixtures(): Promise<Record<string, unknown>> {
  const out: Record<string, unknown> = {};

  // A — confirmed identity, official record (FACT from the engine) + an unverified claim + document provenance.
  {
    const h = harness();
    const inv = await base(h);
    await h.call(regClaim(inv));
    await h.call(regEvidence(inv));
    await h.call({ action: 'run_verification', investigation_id: inv, claim_ref: 'c-reg' });
    await h.call({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c-wells', kind: 'IMPACT_OUTPUT', text: 'HopeBridge Foundation built 20 wells.', quantity: { metric: 'wells_built', value: 20, unit: 'count' }, sourceRef: 'src-web', origin: 'MANUAL' } });
    const doc = ['HopeBridge Foundation annual report (fixture)', 'HopeBridge Foundation built 20 wells in 2025.', ''].join('\n');
    await h.call({ action: 'ingest_artifact', investigation_id: inv, artifact: { ref: 'art-report', filename: 'report.txt', contentBase64: btoa(doc), origin: 'CLOUD_IMPORT', cloud: { provider: 'GOOGLE_DRIVE', fileRef: 'drive-file-1' } } });
    await h.call({ action: 'review_candidate', investigation_id: inv, candidate_ref: 'art-report.auto1', decision: 'ACCEPTED', relationship: 'SUPPORTS', claim_ref: 'c-wells', about_org_ref: 'org-hopebridge', personal_data: 'NONE' });
    await h.call({ action: 'run_verification', investigation_id: inv, claim_ref: 'c-wells' });
    out['list_investigations'] = await h.call({ action: 'list_investigations' });
    out['dossier_confirmed_pt'] = await h.call({ action: 'get_dossier', investigation_id: inv, lang: 'pt' });
    out['dossier_confirmed_en'] = await h.call({ action: 'get_dossier', investigation_id: inv, lang: 'en' });
    const exp = await h.call({ action: 'export_dossier', investigation_id: inv, lang: 'en' });
    out['export_confirmed_en'] = exp;
    const docJ = (exp.data as Json).dossier as { integrity: { contentHash: string }; envelope: Json };
    out['verify_current'] = await h.call({ action: 'verify_dossier', investigation_id: inv, content_hash: docJ.integrity.contentHash, envelope: docJ.envelope });
    out['verify_envelope_mismatch'] = await h.call({ action: 'verify_dossier', investigation_id: inv, content_hash: docJ.integrity.contentHash, envelope: { ...docJ.envelope, auditHead: 'f'.repeat(64) } });
    // E — stale: material change after the export
    await h.call({ action: 'add_evidence', investigation_id: inv, evidence: { ref: 'e-web', claimRef: 'c-reg', sourceRef: 'src-web', aboutOrgRef: 'org-hopebridge', relationship: 'SUPPORTS', basis: 'HUMAN_ASSESSED', personalData: 'NONE' } });
    out['verify_stale'] = await h.call({ action: 'verify_dossier', investigation_id: inv, content_hash: docJ.integrity.contentHash, envelope: docJ.envelope });
    out['dossier_stale_en'] = await h.call({ action: 'get_dossier', investigation_id: inv, lang: 'en' });
    out['verify_not_issued'] = await h.call({ action: 'verify_dossier', investigation_id: inv, content_hash: '0'.repeat(64) });
  }

  // B + C — insufficient evidence, contextual positions, registry conflict, redacted personal data, withheld excerpt.
  {
    const h = harness();
    const inv = await base(h);
    await h.call({ action: 'ingest_provider_record', investigation_id: inv, provider_id: 'fixture-xa-company-registry', record_id: 'xa-c-778899', ref: 'src-co' });
    await h.call({ action: 'add_source', investigation_id: inv, source: { ref: 'src-news', type: 'NEWS', newsGenre: 'REPORTING', publisher: 'Daily Fixture', retrievedAt: '2026-09-01T00:00:00Z', retention: 'EXCERPT_AND_HASH', contentHash: 'c'.repeat(64) } });
    await h.call({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c-wells', kind: 'IMPACT_OUTPUT', text: 'We built 20 wells. Contact office@hopebridge.example.', sourceRef: 'src-web', origin: 'MANUAL' } });
    await h.call({ action: 'add_evidence', investigation_id: inv, evidence: { ref: 'e-self', claimRef: 'c-wells', sourceRef: 'src-web', aboutOrgRef: 'org-hopebridge', relationship: 'SUPPORTS', basis: 'HUMAN_ASSESSED', personalData: 'NONE' } });
    await h.call({ action: 'add_evidence', investigation_id: inv, evidence: { ref: 'e-news', claimRef: 'c-wells', sourceRef: 'src-news', aboutOrgRef: 'org-hopebridge', relationship: 'CONTRADICTS', basis: 'HUMAN_ASSESSED', personalData: 'NONE', excerpt: 'A reporter counted 12 wells; call +44 20 7946 0958.' } });
    await h.call({ action: 'add_evidence', investigation_id: inv, evidence: { ref: 'e-board', claimRef: 'c-wells', sourceRef: 'src-web', aboutOrgRef: 'org-hopebridge', relationship: 'CONTEXTUALIZES', basis: 'HUMAN_ASSESSED', personalData: 'PUBLIC_OFFICIAL_ROLE', excerpt: 'Trustee Jane Example signed the report.' } });
    await h.call({ action: 'run_verification', investigation_id: inv, claim_ref: 'c-wells' });
    out['dossier_conflict_en'] = await h.call({ action: 'get_dossier', investigation_id: inv, lang: 'en' });
  }

  // D — unresolved identity, no registry record, claim never verified.
  {
    const h = harness();
    const inv = await base(h, false);
    await h.call({ action: 'add_claim', investigation_id: inv, claim: { ref: 'c1', kind: 'OTHER', text: 'HopeBridge Foundation operates in two districts.', sourceRef: 'src-web', origin: 'MANUAL' } });
    out['dossier_unresolved_pt'] = await h.call({ action: 'get_dossier', investigation_id: inv, lang: 'pt' });
  }

  // F — open dispute.
  {
    const h = harness();
    const inv = await base(h);
    await h.call(regClaim(inv));
    await h.call(regEvidence(inv));
    await h.call({ action: 'run_verification', investigation_id: inv, claim_ref: 'c-reg' });
    await h.call({ action: 'open_dispute', investigation_id: inv, ref: 'd1', claim_ref: 'c-reg', kind: 'ORGANIZATION_RESPONSE', submitted_evidence_refs: ['e-reg'] });
    out['dossier_disputed_en'] = await h.call({ action: 'get_dossier', investigation_id: inv, lang: 'en' });
  }

  // Empty — no claims yet.
  {
    const h = harness();
    const inv = await base(h, false);
    out['dossier_empty_en'] = await h.call({ action: 'get_dossier', investigation_id: inv, lang: 'en' });
  }
  return out;
}

/** Stable serialization shared by the writer and the drift test. */
export function fixtureText(v: unknown): string {
  return JSON.stringify(v, null, 2) + '\n';
}
