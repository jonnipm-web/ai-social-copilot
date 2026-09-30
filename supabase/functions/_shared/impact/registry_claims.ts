/**
 * Registry-statement claims — IV-IMPACT-I2-REGISTRY-INTELLIGENCE-01.
 *
 * Registry data may originate LIMITED factual claims of exactly one shape:
 *
 *   "<Registry> lists <scheme> <number> (<name>) with status <STATUS> as of <date>."
 *
 * The claim is about what the registry LISTS at a date — never an inference
 * ("the organization is legitimate / fraudulent / closed down for cause").
 * Its period is the registry's as-of date, so a later snapshot never rewrites
 * an earlier statement and today's status is never applied to the past.
 * Evidence is the provider record itself (basis REGISTRY_RECORD), built by the
 * server; a client can neither submit this basis nor choose the text. Pure.
 */
import { parseIsoMs } from './provenance.ts';
import type { CanonicalRegistryRecord } from './provider.ts';
import type { Claim, EvidenceItem, Source } from './types.ts';

export interface RegistryStatement {
  readonly claim: Claim;
  readonly evidence: EvidenceItem;
}

/** Date the registry says its data describes (never later than retrieval). */
export function registryAsOf(r: CanonicalRegistryRecord): string {
  const cands = [r.statusAsOf, r.sourceAsOf, r.retrievedAt].filter((d): d is string => !!d && parseIsoMs(d) !== null);
  const earliest = cands.reduce((a, b) => ((parseIsoMs(a) as number) <= (parseIsoMs(b) as number) ? a : b));
  return earliest.slice(0, 10);
}

export function registryStatement(p: {
  readonly record: CanonicalRegistryRecord;
  readonly source: Source;
  readonly investigationId: string;
  readonly subjectRef: string;
  readonly claimRef: string;
  readonly now: string;
}): RegistryStatement {
  const r = p.record;
  const asOf = registryAsOf(r);
  const synthetic = r.synthetic ? ' [synthetic fixture]' : '';
  const text = `${p.source.publisher} lists ${r.scheme} ${r.registrationNumber} ("${r.name}") with status ${r.status} as of ${asOf}.${synthetic}`;
  const claim: Claim = Object.freeze({
    id: p.claimRef,
    investigationId: p.investigationId,
    kind: 'LEGAL_REGISTRATION',
    text,
    textLanguage: 'en',
    claimantLabel: p.source.publisher,
    subjectOrganizationId: p.subjectRef,
    period: Object.freeze({ from: asOf, to: asOf }),
    sourceId: p.source.id,
    extractedAt: p.now,
    origin: 'REGISTRY_IMPORT', // server-only origin (Codex I2F2-01)
  });
  const from = r.status === 'REGISTERED' && r.registeredOn && r.registeredOn.slice(0, 10) <= asOf ? r.registeredOn.slice(0, 10) : asOf;
  const evidence: EvidenceItem = Object.freeze({
    id: `${p.claimRef}.rec`,
    investigationId: p.investigationId,
    claimId: p.claimRef,
    sourceId: p.source.id,
    aboutOrganizationId: p.subjectRef,
    relationship: 'SUPPORTS',
    relationshipBasis: 'REGISTRY_RECORD',
    observedPeriod: Object.freeze({ from, to: asOf }),
    personalData: 'NONE',
    addedAt: p.now,
  });
  return Object.freeze({ claim, evidence });
}
