/**
 * Action boundary, AEF boundary, commercial firewall and entitlement
 * binding — IV-IMPACT-FOUNDATION-01.
 *
 * ACTION CLASSES (IMPACT_SECURITY_MODEL.md §6)
 *   A  read / search / analyze                    → READ_ONLY
 *   B  create internal investigation records      → REVERSIBLE
 *   C  public accusation, external contact, report to an authority,
 *      payment/donation, external publication     → CONSEQUENTIAL
 * Class C is NOT IMPLEMENTED. There is no executor for it anywhere in the
 * Impact core: requestImpactAction() can only return an intent that says
 * BLOCKED and names the future path
 *   Impact → ActionIntent → AEF → policy → Human Gate → tool → receipt.
 * Unknown actions fail closed as class C.
 *
 * COMMERCIAL FIREWALL: advertising, sponsorship, affiliate and partner
 * relationships are recorded as metadata ABOUT the platform's relationship
 * with an organization. That metadata has no field in any engine input type,
 * and the evidence-set hash reads an explicit field list, so it cannot
 * change a verification result or even its id (tested). Paying never buys a
 * positive verification.
 */

export const IMPACT_MODULE_ID = 'impact';

export type ImpactActionKind =
  // A
  | 'SEARCH_ORGANIZATION'
  | 'VIEW_REPORT'
  | 'ANALYZE_EVIDENCE'
  // B
  | 'CREATE_INVESTIGATION'
  | 'ADD_CLAIM'
  | 'ADD_EVIDENCE'
  | 'RUN_VERIFICATION'
  | 'ADD_NOTE'
  | 'RECORD_ORGANIZATION_RESPONSE'
  // C
  | 'PUBLISH_FINDING'
  | 'PUBLIC_ACCUSATION'
  | 'CONTACT_ORGANIZATION'
  | 'REPORT_TO_AUTHORITY'
  | 'DONATE'
  | 'TRANSFER_FUNDS'
  | 'EXTERNAL_PUBLICATION';

export type ImpactActionClass = 'A' | 'B' | 'C';
/** Mirrors aef/types.ts ActionClassification (parity checked in tests). */
export type AefActionClassification = 'READ_ONLY' | 'REVERSIBLE' | 'CONSEQUENTIAL';

const CLASS: Readonly<Record<ImpactActionKind, ImpactActionClass>> = {
  SEARCH_ORGANIZATION: 'A',
  VIEW_REPORT: 'A',
  ANALYZE_EVIDENCE: 'A',
  CREATE_INVESTIGATION: 'B',
  ADD_CLAIM: 'B',
  ADD_EVIDENCE: 'B',
  RUN_VERIFICATION: 'B',
  ADD_NOTE: 'B',
  RECORD_ORGANIZATION_RESPONSE: 'B',
  PUBLISH_FINDING: 'C',
  PUBLIC_ACCUSATION: 'C',
  CONTACT_ORGANIZATION: 'C',
  REPORT_TO_AUTHORITY: 'C',
  DONATE: 'C',
  TRANSFER_FUNDS: 'C',
  EXTERNAL_PUBLICATION: 'C',
};

export function classifyImpactAction(kind: string): ImpactActionClass {
  return Object.prototype.hasOwnProperty.call(CLASS, kind) ? CLASS[kind as ImpactActionKind] : 'C';
}

export function toAefClassification(c: ImpactActionClass): AefActionClassification {
  return c === 'A' ? 'READ_ONLY' : c === 'B' ? 'REVERSIBLE' : 'CONSEQUENTIAL';
}

export type ActionDecision =
  | { readonly decision: 'ALLOWED_INTERNAL'; readonly actionClass: 'A' | 'B'; readonly executable: true }
  | {
    readonly decision: 'BLOCKED';
    readonly actionClass: 'C';
    readonly code: 'ACTION_BLOCKED';
    readonly requires: 'AEF_HUMAN_GATE';
    readonly executable: false;
  };

/** The only entry point for "may Impact do X?". Class C never executes. */
export function requestImpactAction(kind: string): ActionDecision {
  const c = classifyImpactAction(kind);
  if (c === 'C') {
    return Object.freeze({ decision: 'BLOCKED', actionClass: 'C', code: 'ACTION_BLOCKED', requires: 'AEF_HUMAN_GATE', executable: false });
  }
  return Object.freeze({ decision: 'ALLOWED_INTERNAL', actionClass: c, executable: true });
}

// ── Commercial firewall ─────────────────────────────────────────────────────

export type CommercialRelationshipKind = 'SPONSORED' | 'ADVERTISER' | 'AFFILIATE' | 'COMMERCIAL_PARTNER' | 'CUSTOMER';

/** Disclosure metadata only. Never an input to verification/indicators. */
export interface CommercialRelationship {
  readonly organizationId: string;
  readonly kind: CommercialRelationshipKind;
  readonly since: string;
  /** Must be shown next to any report about this organization. */
  readonly mustDisclose: true;
}

export const EDITORIAL_INDEPENDENCE = Object.freeze({
  adsInfluenceVerification: false,
  paymentBuysPositiveVerification: false,
  sponsoredOrganizationsRankedHigher: false,
  publicRankingExists: false,
});
