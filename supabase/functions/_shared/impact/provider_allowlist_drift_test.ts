// IV-IMPACT-I1 — Codex Gate 1 (I1G1-01): the database provider allowlist
// (public.impact_trusted_provider in migration 20260924010000) must equal the
// server registry (trustedProviderRefs()). A provider added in code but not in
// SQL (or vice versa) fails CI.
import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { trustedProviderRefs } from './provider_registry.ts';
import { authorityFor } from './source_authority.ts';
import { CLAIM_KINDS, NEWS_GENRES, SOURCE_TYPES } from './provenance.ts';
import type { Claim, Source, TrustedProviderRef } from './types.ts';

Deno.test('PD-01 SQL provider allowlist == server provider registry', async () => {
  const sql = await Deno.readTextFile(new URL('../../../migrations/20260924010000_impact_lab_persistence.sql', import.meta.url));
  const block = sql.slice(sql.indexOf('-- BEGIN_IMPACT_PROVIDER_ALLOWLIST'), sql.indexOf('-- END_IMPACT_PROVIDER_ALLOWLIST'));
  const inSql = [...block.matchAll(/\('([^']+)',\s*'([^']+)',\s*'([^']+)'\)/g)].map((m) => `${m[1]}|${m[2]}|${m[3]}`).sort();
  const inCode = trustedProviderRefs().flatMap((p) => p.jurisdictions.map((j) => `${p.id}|${p.sourceType}|${j}`)).sort();
  assertEquals(inSql, inCode);
});


// Codex I1F-01: public.impact_independent_authority() must list exactly the
// (type, kind, genre) cells where authorityFor() can yield AUTHORITATIVE or
// INDEPENDENT for a trusted-provider source.
Deno.test('PD-02 SQL independent-authority table == source_authority.ts', async () => {
  const sql = await Deno.readTextFile(new URL('../../../migrations/20260924010000_impact_lab_persistence.sql', import.meta.url));
  const block = sql.slice(sql.indexOf('-- BEGIN_IMPACT_AUTHORITY_TABLE'), sql.indexOf('-- END_IMPACT_AUTHORITY_TABLE'));
  const inSql = [...block.matchAll(/\('([A-Z_]+)',\s*'([A-Z_]+)',\s*(NULL|'[A-Z_]+'),\s*'([A-Z_]+)'\)/g)]
    .map((m) => `${m[1]}|${m[2]}|${m[3] === 'NULL' ? '-' : m[3].replaceAll("'", '')}|${m[4]}`).sort();
  const trusted = new Map<string, TrustedProviderRef>(SOURCE_TYPES.map((t) => [`p-${t}`, { id: `p-${t}`, sourceType: t, jurisdictions: ['XA'] }]));
  const inCode: string[] = [];
  for (const t of SOURCE_TYPES) {
    for (const k of CLAIM_KINDS) {
      for (const g of (t === 'NEWS' ? NEWS_GENRES : [undefined])) {
        const src = { id: 's', type: t, publisher: 'x', retrievedAt: '2026-01-01', status: 'ACTIVE', retention: 'HASH_ONLY', acquisition: { method: 'PROVIDER', providerId: `p-${t}` }, jurisdiction: { country: 'XA' }, ...(g ? { newsGenre: g } : {}) } as Source;
        const a = authorityFor(src, { kind: k, subjectOrganizationId: 'o' } as Claim, trusted);
        if (a === 'AUTHORITATIVE' || a === 'INDEPENDENT') inCode.push(`${t}|${k}|${g ?? '-'}|${a}`);
      }
    }
  }
  assertEquals(inSql, inCode.sort());
});
