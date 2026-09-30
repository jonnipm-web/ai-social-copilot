/**
 * Real-registry catalog — IV-IMPACT-I2-REGISTRY-INTELLIGENCE-01.
 *
 * Server-owned metadata of the real registries assessed in
 * docs/impact/IMPACT_REGISTRY_SOURCE_DOSSIER.md. NONE is enabled in the Lab:
 * terms/licence need Owner confirmation, two need Owner credentials, and a
 * real provider may only be composed into the Lab registry together with its
 * row in public.impact_trusted_provider (drift-tested) by an explicit Owner
 * decision. Until then, the adapters run only in offline tests and in the
 * separate, manual, read-only smoke script.
 */
import type { ProviderDescriptor } from '../impact/provider.ts';
import { CHARITY_COMMISSION, CHARITY_COMMISSION_HOST } from './charity_commission.ts';
import { COMPANIES_HOUSE, COMPANIES_HOUSE_HOST } from './companies_house.ts';
import { IRS_EO_BMF, IRS_HOST } from './irs_eo_bmf.ts';

export type EnablementBlocker =
  | 'OWNER_CREDENTIAL_REQUIRED'
  | 'TERMS_REQUIRE_CONFIRMATION'
  | 'BULK_INGESTION_PIPELINE_REQUIRED'
  // Codex I2G3-01: safe_fetch validates DNS and then fetch() resolves again
  // (rebinding window). Before ANY real registry is composed, egress must be
  // pinned to the validated address or routed through an allowlisting proxy.
  | 'EGRESS_PINNING_REQUIRED';

export interface RealRegistryEntry {
  readonly descriptor: ProviderDescriptor;
  readonly hosts: readonly string[];
  readonly enabledInLab: false;
  readonly blockers: readonly EnablementBlocker[];
}

export const REAL_REGISTRY_CATALOG: readonly RealRegistryEntry[] = Object.freeze([
  Object.freeze({ descriptor: COMPANIES_HOUSE, hosts: [COMPANIES_HOUSE_HOST], enabledInLab: false as const, blockers: ['OWNER_CREDENTIAL_REQUIRED', 'TERMS_REQUIRE_CONFIRMATION', 'EGRESS_PINNING_REQUIRED'] as const }),
  Object.freeze({ descriptor: CHARITY_COMMISSION, hosts: [CHARITY_COMMISSION_HOST], enabledInLab: false as const, blockers: ['OWNER_CREDENTIAL_REQUIRED', 'TERMS_REQUIRE_CONFIRMATION', 'EGRESS_PINNING_REQUIRED'] as const }),
  Object.freeze({ descriptor: IRS_EO_BMF, hosts: [IRS_HOST], enabledInLab: false as const, blockers: ['TERMS_REQUIRE_CONFIRMATION', 'BULK_INGESTION_PIPELINE_REQUIRED', 'EGRESS_PINNING_REQUIRED'] as const }),
]);
