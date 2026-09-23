// IV-IMPACT-I1 — Codex Gate 1 (I1G1-01): the database provider allowlist
// (public.impact_trusted_provider in migration 20260924010000) must equal the
// server registry (trustedProviderRefs()). A provider added in code but not in
// SQL (or vice versa) fails CI.
import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { trustedProviderRefs } from './provider_registry.ts';

Deno.test('PD-01 SQL provider allowlist == server provider registry', async () => {
  const sql = await Deno.readTextFile(new URL('../../../migrations/20260924010000_impact_lab_persistence.sql', import.meta.url));
  const block = sql.slice(sql.indexOf('-- BEGIN_IMPACT_PROVIDER_ALLOWLIST'), sql.indexOf('-- END_IMPACT_PROVIDER_ALLOWLIST'));
  const inSql = [...block.matchAll(/\('([^']+)',\s*'([^']+)',\s*'([^']+)'\)/g)].map((m) => `${m[1]}|${m[2]}|${m[3]}`).sort();
  const inCode = trustedProviderRefs().flatMap((p) => p.jurisdictions.map((j) => `${p.id}|${p.sourceType}|${j}`)).sort();
  assertEquals(inSql, inCode);
});
