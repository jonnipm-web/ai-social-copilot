// IV-IMPACT-I5 — writes the Flutter UI fixtures from the real Lab service.
//   deno run --allow-read --allow-write supabase/tests/impact_ui_fixtures.ts
import { buildUiFixtures, fixtureText } from '../functions/_shared/impact/fixtures/ui_fixtures.ts';

const dir = new URL('../../test/fixtures/impact/', import.meta.url);
await Deno.mkdir(dir, { recursive: true });
const fixtures = await buildUiFixtures();
for (const [name, value] of Object.entries(fixtures)) {
  await Deno.writeTextFile(new URL(`${name}.json`, dir), fixtureText(value));
}
console.log(`wrote ${Object.keys(fixtures).length} fixtures`);
