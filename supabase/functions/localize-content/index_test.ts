/**
 * R16 — localize-content tests.
 * Run: DENO_TESTING=1 deno test --allow-env supabase/functions/localize-content/index_test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { handler, LocalizationDeps } from './index.ts';
import {
  applyTranslations,
  extractSegments,
  parseTranslationResponse,
} from '../_shared/content_localization.ts';
import type { AuthClient } from '../_shared/auth.ts';

const USER_A = '11111111-1111-4111-8111-111111111111';
const ROW_A = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const ROW_B = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

const authOk: AuthClient = {
  auth: { getUser: () => Promise.resolve({ data: { user: { id: USER_A } }, error: null }) },
};
const authFail: AuthClient = {
  auth: { getUser: () => Promise.resolve({ data: { user: null }, error: 'bad' }) },
};

function req(body: unknown, auth = true) {
  return new Request('http://x/localize-content', {
    method: 'POST',
    headers: auth ? { Authorization: 'Bearer t', 'Content-Type': 'application/json' } : {},
    body: JSON.stringify(body),
  });
}

interface Fake extends LocalizationDeps {
  saved: unknown[];
  translateCalls: number;
  ownedQueries: { userId: string; ids: string[] }[];
}

function fakeDeps(rows: Record<string, unknown>[], opts: { cache?: unknown[]; fresh?: number; active?: boolean } = {}): Fake {
  const f: Fake = {
    saved: [],
    translateCalls: 0,
    ownedQueries: [],
    fetchOwnedRows(userId, _t, ids) {
      f.ownedQueries.push({ userId, ids });
      // Simulates the user_id filter: only USER_A's rows are returned.
      return Promise.resolve(rows.filter((r) => r.user_id === userId && ids.includes(String(r.id))));
    },
    fetchCache: () => Promise.resolve((opts.cache ?? []) as never),
    countFreshToday: () => Promise.resolve(opts.fresh ?? 0),
    isActive: () => Promise.resolve(opts.active ?? true),
    saveCache(row) { f.saved.push(row); return Promise.resolve(); },
    translate(_s, user) {
      f.translateCalls++;
      const items = JSON.parse(user.split('\n')[1]) as string[];
      return Promise.resolve(JSON.stringify({ source_language: 'pt-BR', translations: items.map((t) => `EN(${t})`) }));
    },
  };
  return f;
}

Deno.test('R16-LC-1: rejects unauthenticated callers', async () => {
  const res = await handler(req({ table: 'opportunity_lab', ids: [ROW_A] }, false), fakeDeps([]), authFail);
  assertEquals(res.status, 401);
});

Deno.test('R16-LC-2: rejects tables outside the server allowlist', async () => {
  const res = await handler(req({ table: 'profiles', ids: [ROW_A] }), fakeDeps([]), authOk);
  assertEquals(res.status, 400);
});

Deno.test('R16-LC-3: only rows owned by the caller are read (cross-user isolation)', async () => {
  const deps = fakeDeps([
    { id: ROW_A, user_id: USER_A, title: 'Expandir mercado', description: 'Projeto voltado a RCBO' },
    { id: ROW_B, user_id: 'someone-else', title: 'Segredo', description: 'Dado de outro usuário' },
  ]);
  const res = await handler(req({ table: 'opportunity_lab', ids: [ROW_A, ROW_B], language: 'en-US' }), deps, authOk);
  const body = await res.json();
  assertEquals(Object.keys(body.items), [ROW_A]);
  assert(deps.ownedQueries.every((q) => q.userId === USER_A));
});

Deno.test('R16-LC-4: translates allow-listed text, keeps codes/numbers, caches, never returns original overwritten', async () => {
  const row = {
    id: ROW_A, user_id: USER_A,
    title: 'Expandir para o Brasil',
    description: 'Projeto voltado à introdução de dispositivos RCBO',
    risks: ['Concorrência alta'],
    action_steps: [{ step: 'Mapear distribuidores', effort: 'Médio', url: 'https://ex.com' }],
  };
  const deps = fakeDeps([row]);
  const res = await handler(req({ table: 'opportunity_lab', ids: [ROW_A], language: 'en' }), deps, authOk);
  const body = await res.json();
  const p = body.items[ROW_A].payload;
  assertEquals(body.language, 'en-US');
  assertEquals(p.title, 'EN(Expandir para o Brasil)');
  assertEquals(p.risks[0], 'EN(Concorrência alta)');
  assertEquals(p.action_steps[0].step, 'EN(Mapear distribuidores)');
  assertEquals(p.action_steps[0].effort, 'Médio'); // canonical code untouched
  assertEquals(p.action_steps[0].url, 'https://ex.com');
  assertEquals(body.items[ROW_A].source_language, 'pt-BR');
  assertEquals(deps.saved.length, 1);
  assertEquals(row.title, 'Expandir para o Brasil'); // source object not mutated
});

Deno.test('R16-LC-5: cache hit with same source hash makes no AI call', async () => {
  const row = { id: ROW_A, user_id: USER_A, title: 'Título', description: 'Descrição longa' };
  const first = fakeDeps([row]);
  const r1 = await (await handler(req({ table: 'opportunity_lab', ids: [ROW_A], language: 'en-US' }), first, authOk)).json();
  const saved = first.saved[0] as { source_hash: string };
  const second = fakeDeps([row], {
    cache: [{ source_id: ROW_A, source_hash: saved.source_hash, source_language: 'pt-BR', payload: r1.items[ROW_A].payload }],
  });
  await handler(req({ table: 'opportunity_lab', ids: [ROW_A], language: 'en-US' }), second, authOk);
  assertEquals(second.translateCalls, 0);
  assertEquals(second.saved.length, 0);
});

Deno.test('R16-LC-6: daily cap stops fresh translations gracefully (no error, no AI call)', async () => {
  const deps = fakeDeps([{ id: ROW_A, user_id: USER_A, title: 'Título', description: 'Texto' }], { fresh: 10_000 });
  const res = await handler(req({ table: 'opportunity_lab', ids: [ROW_A], language: 'en-US' }), deps, authOk);
  assertEquals(res.status, 200);
  assertEquals(deps.translateCalls, 0);
  assertEquals((await res.json()).items, {});
});

Deno.test('R16-LC-7: malformed model output is never served; the attempt is recorded (counts toward the cap)', async () => {
  const deps = fakeDeps([{ id: ROW_A, user_id: USER_A, title: 'Título', description: 'Texto' }]);
  deps.translate = () => Promise.resolve('{"translations":["only one"]}');
  const res = await handler(req({ table: 'opportunity_lab', ids: [ROW_A], language: 'en-US' }), deps, authOk);
  assertEquals((await res.json()).items, {});
  assertEquals(deps.saved.length, 1);
  const saved = deps.saved[0] as { model: string; payload: unknown };
  assertEquals(saved.model, 'failed');
  assertEquals(saved.payload, {});
});

Deno.test('R16-LC-7b: a recent failure with the same source is not retried (no retry storm)', async () => {
  const row = { id: ROW_A, user_id: USER_A, title: 'Título', description: 'Texto' };
  const first = fakeDeps([row]);
  first.translate = () => Promise.resolve('garbage');
  await handler(req({ table: 'opportunity_lab', ids: [ROW_A], language: 'en-US' }), first, authOk);
  const failed = first.saved[0] as { source_hash: string };
  const second = fakeDeps([row], {
    cache: [{ source_id: ROW_A, source_hash: failed.source_hash, source_language: null, payload: {}, model: 'failed', updated_at: new Date().toISOString() }],
  });
  await handler(req({ table: 'opportunity_lab', ids: [ROW_A], language: 'en-US' }), second, authOk);
  assertEquals(second.translateCalls, 0);
});

Deno.test('R16-LC-10: deactivated accounts get no AI capacity', async () => {
  const deps = fakeDeps([{ id: ROW_A, user_id: USER_A, title: 'Título', description: 'Texto' }], { active: false });
  const res = await handler(req({ table: 'opportunity_lab', ids: [ROW_A], language: 'en-US' }), deps, authOk);
  assertEquals(res.status, 403);
  assertEquals(deps.translateCalls, 0);
});

Deno.test('R16-LC-11: text already clearly in the target language is served without an AI call', async () => {
  const en = 'This project is focused on the introduction and expansion of the use of RCBO devices in the market, with a clear plan for the distribution of the products and the training of the installers that will work with our partners.';
  const deps = fakeDeps([{ id: ROW_A, user_id: USER_A, title: 'Market expansion plan for the partners', description: en, rationale: en }]);
  const res = await handler(req({ table: 'opportunity_lab', ids: [ROW_A], language: 'en-US' }), deps, authOk);
  assertEquals(res.status, 200);
  assertEquals(deps.translateCalls, 0);
  assertEquals((deps.saved[0] as { model: string }).model, 'none:same-language');
});

Deno.test('R16-LC-12: oversized rows are capped (bounded model calls)', () => {
  const steps = Array.from({ length: 5000 }, (_, i) => `Passo número ${i} do plano`);
  const segs = extractSegments('action_queue', { action_steps: steps });
  assert(segs.length <= 250);
});

Deno.test('R16-LC-8: extraction skips SEO keywords, entities, ids and bare URLs', () => {
  const segs = extractSegments('knowledge_analysis', {
    summary: 'Resumo do documento',
    topics: ['Energia', 'https://site.com'],
    keywords_primary: ['rcbo preço'], // column not allow-listed
    score_details: { seo: 'Bom potencial', keywords: ['x y'], project_id: 'abc' },
  });
  assertEquals(segs.map((s) => s.text), ['Resumo do documento', 'Energia', 'Bom potencial']);
});

Deno.test('R16-LC-9: parse/apply helpers', () => {
  assertEquals(parseTranslationResponse('{"translations":["a","b"]}', 3), null);
  assertEquals(parseTranslationResponse('garbage', 1), null);
  const row = { description: 'Olá', plan: { steps: ['Um', 'Dois'] } };
  const segs = extractSegments('action_queue', row);
  const out = applyTranslations('action_queue', row, segs, ['Hello', 'One', 'Two']);
  assertEquals(out, { description: 'Hello', plan: { steps: ['One', 'Two'] } });
  assertEquals(row.plan.steps[0], 'Um');
});
