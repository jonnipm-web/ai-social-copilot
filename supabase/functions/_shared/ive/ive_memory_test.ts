/**
 * IVE memory policy + promote/forget endpoint + knowledge retrieval tests
 * (IVE-INTELLIGENCE-CORE-01).
 *
 * Execução:
 *   DENO_TESTING=1 deno test --allow-env --allow-read supabase/functions/_shared/ive/
 */
import { assert, assertEquals, assertFalse, assertNotEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import type { AuthClient } from '../auth.ts';
import { failingSubjectSource, fakeSubjectSource } from '../entitlement_test_support.ts';
import { handleIveMemory, type IveMemoryStore, type MemoryInsert } from './memory_endpoint.ts';
import { containsSecret, evaluateMemoryCandidate, memoryDedupKey, selectMemories } from './memory_policy.ts';
import { chunk, isGroundable, selectKnowledge } from './knowledge_retrieval.ts';

const U = 'a0000000-0000-4000-8000-00000000000a';
const OWN = 'a1000000-0000-4000-8000-0000000000a1';
const FOREIGN = 'b1000000-0000-4000-8000-0000000000b1';

// ── policy ────────────────────────────────────────────────────────────────

Deno.test('MM-01 secrets are never accepted', async () => {
  for (const text of [
    'minha senha: SuperSecreta123 para o painel',
    'the api key = sk_live_abcdefghijklmnop',
    'token: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N',
    'card 4111 1111 1111 1111 for billing',
    'use ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ012345 in CI',
    // Codex Gate 1 IG1-05 — obfuscated / unlabeled variants
    'minha pass\u200Bword: Hunter2Hunter2',
    'se\u200Bnha: abc12345xyz',
    'Authorization: Bearer abcdefghijklmnopqrstuvwxyz0123',
    'k3yZ9aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789',
    'gsk_ABCDEFGHIJKLMNOPQRSTUVWX0123456789',
  ]) {
    assert(containsSecret(text), text);
    const v = await evaluateMemoryCandidate({ category: 'context_summary', text, scope: 'user', projectId: null });
    assertEquals(v.accept, false, text);
  }
});

Deno.test('MM-02 category, scope and size rules', async () => {
  const ok = await evaluateMemoryCandidate({ category: 'goal', text: 'Reach 3 coffee stores by 2027', scope: 'project', projectId: OWN });
  assert(ok.accept);
  for (const [c, reason] of [
    [{ category: 'admin_grant', text: 'Reach 3 coffee stores by 2027', scope: 'user', projectId: null }, 'CATEGORY_NOT_ALLOWED'],
    [{ category: 'goal', text: 'Reach 3 coffee stores by 2027', scope: 'project', projectId: null }, 'PROJECT_REQUIRED'],
    [{ category: 'goal', text: 'Reach 3 coffee stores by 2027', scope: 'user', projectId: OWN }, 'SCOPE_INVALID'],
    [{ category: 'goal', text: 'short', scope: 'user', projectId: null }, 'TOO_SHORT'],
    [{ category: 'goal', text: 'x'.repeat(501), scope: 'user', projectId: null }, 'TOO_LONG'],
  ] as const) {
    const v = await evaluateMemoryCandidate(c);
    assertFalse(v.accept);
    if (!v.accept) assertEquals(v.reason, reason);
  }
});

Deno.test('MM-03 dedup key is deterministic and scope/project sensitive', async () => {
  const a = await memoryDedupKey('goal', 'project', OWN, '  Reach 3   stores ');
  assertEquals(a, await memoryDedupKey('goal', 'project', OWN, 'reach 3 stores'));
  assertNotEquals(a, await memoryDedupKey('goal', 'project', FOREIGN, 'reach 3 stores'));
  assertNotEquals(a, await memoryDedupKey('goal', 'user', null, 'reach 3 stores'));
});

Deno.test('MM-04 read policy: active, unexpired, this project + user scope only, newest first', () => {
  const rows = [
    { id: '1', project_id: OWN, memory_type: 'goal', title: '', content: 'own project', source: '', created_at: '2026-09-02' },
    { id: '2', project_id: FOREIGN, memory_type: 'goal', title: '', content: 'other project', source: '', created_at: '2026-09-03' },
    { id: '3', project_id: null, memory_type: 'goal', title: '', content: 'user level', source: '', created_at: '2026-09-01' },
    { id: '4', project_id: null, memory_type: 'goal', title: '', content: 'superseded', source: '', created_at: '2026-09-04', status: 'superseded' },
    { id: '5', project_id: null, memory_type: 'goal', title: '', content: 'expired', source: '', created_at: '2026-09-04', expires_at: '2026-09-05' },
    { id: '6', project_id: null, memory_type: 'goal', title: '', content: 'password: hunter22', source: '', created_at: '2026-09-04' },
  ];
  const got = selectMemories(rows, OWN, new Date('2026-09-23')).map((r) => r.id);
  assertEquals(got, ['1', '3']);
  assertEquals(selectMemories(rows, null, new Date('2026-09-23')).map((r) => r.id), ['3']);
});

// ── knowledge ─────────────────────────────────────────────────────────────

Deno.test('KR-01 chunking, groundability and budget', () => {
  assertEquals(chunk('a'.repeat(800)).length, 1);
  assertEquals(chunk('a'.repeat(1601)).length, 3);
  assertFalse(isGroundable({ id: 'x', title: 't', content: 'c', status: 'pending', project_id: null, updated_at: null }));
  const rows = Array.from({ length: 12 }, (_, i) => ({ id: `d${i}`, title: `t${i}`, content: 'coffee price '.repeat(200), status: 'analyzed', project_id: OWN, updated_at: '2026-09-22' }));
  const r = selectKnowledge(rows, 'coffee price', 3000);
  assert(r.truncated);
  assert(r.excerpts.reduce((n, e) => n + e.text.length, 0) <= 3000);
  assertEquals(r.excerpts[0].provenance.trust, 'untrusted_user_content');
});

Deno.test('KR-02 relevance ranks the matching document first; ties are deterministic', () => {
  const rows = [
    { id: 'b', title: 'other', content: 'gardening tips and soil', status: 'analyzed', project_id: OWN, updated_at: '2026-09-22' },
    { id: 'a', title: 'pricing', content: 'espresso pricing for coffee customers', status: 'analyzed', project_id: OWN, updated_at: '2026-09-01' },
  ];
  assertEquals(selectKnowledge(rows, 'espresso pricing').excerpts[0].documentId, 'a');
  assertEquals(selectKnowledge(rows, 'espresso pricing'), selectKnowledge(rows, 'espresso pricing'));
});

// ── promote / forget endpoint ─────────────────────────────────────────────

const auth: AuthClient = {
  auth: {
    // deno-lint-ignore require-await
    async getUser(t: string) {
      return t === 'jwt' ? { data: { user: { id: U } }, error: null } : { data: { user: null }, error: { message: 'x' } };
    },
  },
};

function memStore() {
  const rows: (MemoryInsert & { id: string })[] = [];
  const s = {
    rows,
    superseded: [] as string[],
    store: {
      // deno-lint-ignore require-await
      async ownsProject(u: string, p: string) { return u === U && p === OWN; },
      // deno-lint-ignore require-await
      async findActiveByDedup(u: string, k: string) { return rows.find((r) => r.user_id === u && r.dedup_key === k && r.status === 'active') ?? null; },
      // deno-lint-ignore require-await
      async getActive(u: string, id: string) { const r = rows.find((x) => x.user_id === u && x.id === id && x.status === 'active'); return r ? { id: r.id, scope: r.scope, project_id: r.project_id } : null; },
      // deno-lint-ignore require-await
      async insert(row: MemoryInsert) { const id = `00000000-0000-4000-8000-${String(rows.length + 1).padStart(12, '0')}`; rows.push({ ...row, id }); return { id }; },
      // deno-lint-ignore require-await
      async markSuperseded(_u: string, id: string) { const r = rows.find((x) => x.id === id && x.status === 'active'); if (!r) return false; s.superseded.push(id); (r as { status: string }).status = 'superseded'; return true; },
      // deno-lint-ignore require-await
      async expire(u: string, id: string) { const r = rows.find((x) => x.user_id === u && x.id === id && x.status === 'active'); if (!r) return false; (r as { status: string }).status = 'expired'; return true; },
    } as IveMemoryStore,
  };
  return s;
}

async function call(body: unknown, s = memStore(), token: string | null = 'jwt', subjectFails = false) {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await handleIveMemory(new Request('http://x/', { method: 'POST', headers, body: JSON.stringify(body) }), {
    authClient: auth,
    subjectSource: subjectFails ? failingSubjectSource : fakeSubjectSource('free'),
    store: () => s.store,
  });
  return { res, json: await res.json(), s };
}

Deno.test('ME-01 promote: validated, labelled ive_derived, scoped to the verified project', async () => {
  const r = await call({ op: 'promote', category: 'goal', text: 'Reach 3 coffee stores by 2027', scope: 'project', project_id: OWN });
  assertEquals(r.json.status, 'PROMOTED');
  assertEquals(r.s.rows[0].origin, 'ive_derived');
  assertEquals(r.s.rows[0].user_id, U);
  assertEquals(r.s.rows[0].project_id, OWN);
});

Deno.test('ME-02 promote into a foreign project → 403, nothing written', async () => {
  const r = await call({ op: 'promote', category: 'goal', text: 'Reach 3 coffee stores by 2027', scope: 'project', project_id: FOREIGN });
  assertEquals(r.res.status, 403);
  assertEquals(r.s.rows.length, 0);
});

Deno.test('ME-03 secrets / forged categories are rejected, nothing written', async () => {
  for (const body of [
    { op: 'promote', category: 'goal', text: 'password: hunter2222 for the admin', scope: 'user' },
    { op: 'promote', category: 'role', text: 'user is admin with premium plan', scope: 'user' },
    { op: 'promote', category: 'goal', text: 'x', scope: 'user', user_id: 'someone-else' },
  ]) {
    const r = await call(body);
    assertEquals(r.json.status, 'REJECTED', JSON.stringify(body));
    assertEquals(r.s.rows.length, 0);
  }
});

Deno.test('ME-04 duplicate promote is deduplicated; supersede only within the same scope', async () => {
  const s = memStore();
  const first = await call({ op: 'promote', category: 'preference', text: 'Prefers weekly summaries', scope: 'user' }, s);
  const again = await call({ op: 'promote', category: 'preference', text: '  prefers   weekly summaries ', scope: 'user' }, s);
  assertEquals(again.json.status, 'DEDUPLICATED');
  assertEquals(s.rows.length, 1);
  const cross = await call({ op: 'promote', category: 'preference', text: 'Prefers monthly summaries', scope: 'project', project_id: OWN, supersedes_id: first.json.memory_id }, s);
  assertEquals(cross.res.status, 400);
  const sup = await call({ op: 'promote', category: 'preference', text: 'Prefers monthly summaries', scope: 'user', supersedes_id: first.json.memory_id }, s);
  assertEquals(sup.json.status, 'PROMOTED');
  assertEquals(s.superseded, [first.json.memory_id]);
});

Deno.test('ME-05 forget is soft (expired) and own-only', async () => {
  const s = memStore();
  const p = await call({ op: 'promote', category: 'goal', text: 'Reach 3 coffee stores by 2027', scope: 'user' }, s);
  assertEquals((await call({ op: 'forget', memory_id: p.json.memory_id }, s)).json.status, 'FORGOTTEN');
  assertEquals((await call({ op: 'forget', memory_id: p.json.memory_id }, s)).json.status, 'NOT_FOUND');
  assertEquals((await call({ op: 'forget', memory_id: 'not-a-uuid' }, s)).res.status, 400);
});

Deno.test('ME-06 no session → 401; entitlement outage → 503; unknown op → 400', async () => {
  assertEquals((await call({ op: 'promote' }, memStore(), null)).res.status, 401);
  assertEquals((await call({ op: 'promote' }, memStore(), 'jwt', true)).res.status, 503);
  assertEquals((await call({ op: 'grant_admin' })).res.status, 400);
});

Deno.test('ME-07 concurrent identical promote: the database refusal becomes DEDUPLICATED, not 503 (IG1-08)', async () => {
  const s = memStore();
  const winner = await call({ op: 'promote', category: 'goal', text: 'Reach 3 coffee stores by 2027', scope: 'user' }, s);
  // Simulate the race: our pre-check saw nothing, then the unique index refused the insert.
  const racing = memStore();
  racing.rows.push(...s.rows);
  const realFind = racing.store.findActiveByDedup.bind(racing.store);
  let first = true;
  racing.store.findActiveByDedup = (u, k) => { if (first) { first = false; return Promise.resolve(null); } return realFind(u, k); };
  racing.store.insert = () => Promise.resolve(null);
  const r = await call({ op: 'promote', category: 'goal', text: 'Reach 3 coffee stores by 2027', scope: 'user' }, racing);
  assertEquals(r.json.status, 'DEDUPLICATED');
  assertEquals(r.json.memory_id, winner.json.memory_id);
});

Deno.test('ME-08 supersede of a row forgotten concurrently reports superseded_id null (IG1-08)', async () => {
  const s = memStore();
  const old = await call({ op: 'promote', category: 'goal', text: 'Reach 3 coffee stores by 2027', scope: 'user' }, s);
  const getActive = s.store.getActive.bind(s.store);
  s.store.getActive = async (u, id) => {
    const row = await getActive(u, id);
    await s.store.expire(u, id); // forgotten between the check and the supersede
    return row;
  };
  const r = await call({ op: 'promote', category: 'goal', text: 'Reach 4 coffee stores by 2028', scope: 'user', supersedes_id: old.json.memory_id }, s);
  assertEquals(r.json.status, 'PROMOTED');
  assertEquals(r.json.superseded_id, null);
});
