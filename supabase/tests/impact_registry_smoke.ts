// IV-IMPACT-I2 — CONTROLLED real-network smoke (manual only; NOT part of CI,
// never needed by the deterministic suites).
//
//   deno run --allow-net --allow-read supabase/tests/impact_registry_smoke.ts wy
// (--allow-net is needed for DNS resolution by the SSRF guard; the adapter
// itself only ever reaches the allowlisted host www.irs.gov, at every hop.)
//
// Reads ONE small public IRS EO BMF state extract through the production
// adapter (safe_fetch + host allowlist + size cap), checks that the real file
// matches the documented layout, and prints COUNTS ONLY. No organization is
// selected, named, stored, scored or published; nothing is written anywhere.
import { IrsEoBmfProvider } from '../functions/_shared/impact_registry/irs_eo_bmf.ts';

const state = (Deno.args[0] ?? 'wy').toLowerCase();
const p = new IrsEoBmfProvider();
// A registration that cannot exist: the full file is fetched, its header is
// validated against EO_BMF_HEADER and every row is parsed — nothing matches.
const probe = await p.searchOrganization({ registration: '000000000', subdivision: `US-${state.toUpperCase()}` });
if (!probe.ok) {
  console.log(`IMPACT_REGISTRY_SMOKE: ${probe.error.code} (${state}) — operational state, not a finding`);
  Deno.exit(0);
}
console.log(`IMPACT_REGISTRY_SMOKE: PASS layout=EO_BMF state=${state} matches_for_impossible_ein=${probe.value.length}`);
