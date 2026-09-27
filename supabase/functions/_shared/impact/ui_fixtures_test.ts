// IV-IMPACT-I5 — the Flutter UI fixtures (test/fixtures/impact/*.json) must
// be exactly what the real Lab service produces today. Regenerate with:
//   deno run --allow-read --allow-write supabase/tests/impact_ui_fixtures.ts
import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { buildUiFixtures, fixtureText } from './fixtures/ui_fixtures.ts';

const DIR = new URL('../../../../test/fixtures/impact/', import.meta.url);

Deno.test('UI-FIX-01 committed Flutter fixtures match the real I4 contract (no drift)', async () => {
  const fixtures = await buildUiFixtures();
  for (const [name, value] of Object.entries(fixtures)) {
    const committed = await Deno.readTextFile(new URL(`${name}.json`, DIR));
    assertEquals(committed.replace(/\r\n/g, '\n'), fixtureText(value), `${name}.json drifted — regenerate the fixtures`);
  }
});
