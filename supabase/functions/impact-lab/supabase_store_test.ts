// IV-IMPACT-I1-PERSISTENCE-RLS-01 — SupabaseImpactLabStore: exact row
// round-trip (hashes survive persistence), read/write client separation,
// server-derived ownership fields on every write, no DELETE, error mapping.
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { goldenCases } from '../_shared/impact/fixtures/golden.ts';
import { verifyClaim } from '../_shared/impact/verification.ts';
import {
  claimToRow,
  type DbClient,
  evidenceToRow,
  mapDbError,
  rowToClaim,
  rowToEvidence,
  rowToSource,
  sourceToRow,
  SupabaseImpactLabStore,
} from './supabase_store.ts';

const INV = 'a2222222-0000-4000-8000-00000000000a';
const ACTOR = 'aaaaaaaa-0000-4000-8000-00000000000a';

Deno.test('SS-01 every golden case survives a DB round-trip with the SAME evidenceSetHash and status', async () => {
  for (const c of await goldenCases()) {
    const claim = rowToClaim({ ...claimToRow(c.claim.investigationId, c.claim, ACTOR), investigation_id: c.claim.investigationId });
    const evidence = c.evidence.map((e) => rowToEvidence({ ...evidenceToRow(e.investigationId, e, ACTOR), investigation_id: e.investigationId }));
    const sources = c.sources.map((s) => rowToSource(sourceToRow(INV, { source: s, snapshot: null }, ACTOR)).source);
    const a = await verifyClaim({ claim: c.claim, evidence: c.evidence, sources: c.sources }, c.ctx);
    const b = await verifyClaim({ claim, evidence, sources }, c.ctx);
    assert(a.ok && b.ok, c.id);
    assertEquals(b.value.evidenceSetHash, a.value.evidenceSetHash, c.id);
    assertEquals(b.value.resultId, a.value.resultId, c.id);
    assertEquals(b.value.status, a.value.status, c.id);
  }
});

type Call = { client: 'user' | 'service'; table: string; op: string; payload?: unknown; filters: [string, unknown][] };

function fakeClient(name: 'user' | 'service', calls: Call[], respond: (c: Call) => { data: unknown; error: unknown; count?: number }): DbClient {
  return {
    from(table: string) {
      const call: Call = { client: name, table, op: 'select', filters: [] };
      calls.push(call);
      const b: Record<string, unknown> = {};
      const chain = (f: (...a: unknown[]) => void) => (...a: unknown[]) => {
        f(...a);
        return b;
      };
      b.select = chain(() => {});
      b.insert = chain((p) => { call.op = 'insert'; call.payload = p; });
      b.update = chain((p) => { call.op = 'update'; call.payload = p; });
      b.upsert = chain(() => { call.op = 'upsert'; });
      b.delete = chain(() => { call.op = 'delete'; });
      for (const f of ['eq', 'is']) b[f] = chain((k, v) => call.filters.push([k as string, v]));
      b.order = chain(() => {});
      b.limit = chain(() => {});
      b.maybeSingle = () => Promise.resolve(respond(call));
      b.single = () => Promise.resolve(respond(call));
      b.then = (res: (v: unknown) => unknown, rej: (e: unknown) => unknown) => Promise.resolve(respond(call)).then(res, rej);
      return b;
    },
    rpc(fn: string) {
      calls.push({ client: name, table: fn, op: 'rpc', filters: [] });
      return Promise.resolve({ data: true, error: null });
    },
  };
}

Deno.test('SS-02 reads go through the caller-JWT client (RLS); writes through service with server ids; never DELETE', async () => {
  const calls: Call[] = [];
  const respond = (c: Call) => {
    if (c.op === 'insert' && c.table === 'impact_investigations') {
      return { data: { id: INV, owner_id: ACTOR, project_id: null, subject_org_ref: 'org-x', subject_org_type: 'NGO', subject_identity: {}, status: 'ACTIVE', audit_seq: 1, audit_head: 'a'.repeat(64), created_at: 'x' }, error: null };
    }
    if (c.op === 'insert' && c.table === 'impact_verifications') return { data: { version: 1, result: {}, idempotency_key: null }, error: null };
    if (c.op === 'update' && c.table === 'impact_disputes') return { data: [{ ref: 'd1' }], error: null };
    return { data: c.op === 'select' ? [] : null, error: null, count: 0 };
  };
  const store = new SupabaseImpactLabStore(fakeClient('user', calls, respond), fakeClient('service', calls, respond));
  const g = await goldenCases();
  const a = g.find((c) => c.id === 'A')!;
  const r = await verifyClaim({ claim: a.claim, evidence: a.evidence, sources: a.sources }, a.ctx);
  assert(r.ok);

  await store.getInvestigation(INV);
  await store.listInvestigations();
  await store.loadInvestigationData(INV);
  await store.listAudit(INV);
  await store.auditChainOk(INV);
  await store.projectOwnedByCaller(INV);
  const reads = calls.splice(0);
  assert(reads.every((c) => c.client === 'user'), 'every read uses the caller JWT client');
  assert(reads.some((c) => c.table === 'impact_latest_verifications'), 'latest versions come from the view');
  await store.countOwnedInvestigations(ACTOR);
  const count = calls.splice(0)[0];
  assertEquals([count.client, count.filters], ['service', [['owner_id', ACTOR]]]);
  assert(reads.filter((c) => c.op === 'select' && c.table.startsWith('impact_') && c.table !== 'impact_investigations').every((c) => c.filters.some(([k, v]) => k === 'investigation_id' && v === INV)));

  await store.createInvestigation({ ownerId: ACTOR, projectId: null, subjectOrgRef: 'org-x', subjectOrgType: 'NGO', subjectIdentity: {} });
  await store.insertSource(INV, { source: a.sources[0], snapshot: null }, ACTOR);
  await store.insertClaim(INV, a.claim, ACTOR);
  await store.insertEvidence(INV, a.evidence[0], ACTOR);
  await store.insertVerification(INV, r.value, null, ACTOR);
  await store.updateSourceStatus(INV, 'src-registry-hb', 'RETRACTED', ACTOR);
  await store.insertDispute(INV, { ref: 'd1', claimRef: 'claim-a', kind: 'ORGANIZATION_RESPONSE', openedAt: 'x', submittedEvidenceRefs: [], resolution: null, resolvedAt: null }, ACTOR);
  await store.resolveDispute(INV, 'd1', 'UPHELD', 'x', ACTOR);
  await store.archiveInvestigation(INV, ACTOR);
  const writes = calls.filter((c) => c.op !== 'select');
  assert(writes.every((c) => c.client === 'service'), 'writes use the service client');
  assertEquals(calls.filter((c) => c.op === 'delete' || c.op === 'upsert').length, 0);
  for (const w of writes.filter((c) => c.op === 'insert' && c.table !== 'impact_investigations')) {
    const p = w.payload as Record<string, unknown>;
    assertEquals([p.investigation_id, p.created_by], [INV, ACTOR], w.table);
  }
  const inv = writes.find((c) => c.table === 'impact_investigations' && c.op === 'insert')!.payload as Record<string, unknown>;
  assertEquals(inv.owner_id, ACTOR);
  for (const u of writes.filter((c) => c.op === 'update' && c.table !== 'impact_investigations')) {
    assert(u.filters.some(([k, v]) => k === 'investigation_id' && v === INV), u.table);
  }
});

Deno.test('SS-03 database errors map to stable codes and never leak SQL text', () => {
  assertEquals(mapDbError({ code: '23505', message: 'duplicate key value violates "impact_sources_ref_key"' }), 'ALREADY_EXISTS');
  assertEquals(mapDbError({ code: '42501', message: 'IMPACT_INVESTIGATION_NOT_ACTIVE' }), 'INVESTIGATION_NOT_ACTIVE');
  assertEquals(mapDbError({ code: '42501', message: 'IMPACT_PROJECT_NOT_OWNED' }), 'INVESTIGATION_NOT_FOUND');
  assertEquals(mapDbError({ code: '23503', message: 'fk' }), 'INVALID_REQUEST');
  assertEquals(mapDbError({ code: 'P0001', message: 'IMPACT_TEMPORAL: observed period extends past retrieval' }), 'INVALID_REQUEST');
  assertEquals(mapDbError({ code: 'XX000', message: 'boom' }), 'INTERNAL_ERROR');
});

Deno.test('SS-04 an idempotent retry that races returns the winning row, not a duplicate', async () => {
  const calls: Call[] = [];
  let inserted = false;
  const respond = (c: Call) => {
    if (c.op === 'insert') {
      inserted = true;
      return { data: null, error: { code: '23505', message: 'duplicate' } };
    }
    if (c.op === 'select' && c.filters.some(([k]) => k === 'idempotency_key')) {
      return inserted ? { data: { version: 3, result: { resultId: 'vr_x' }, idempotency_key: 'k' }, error: null } : { data: null, error: null };
    }
    return { data: null, error: null };
  };
  const store = new SupabaseImpactLabStore(fakeClient('user', calls, respond), fakeClient('service', calls, respond));
  const a = (await goldenCases()).find((c) => c.id === 'A')!;
  const r = await verifyClaim({ claim: a.claim, evidence: a.evidence, sources: a.sources }, a.ctx);
  assert(r.ok);
  const s = await store.insertVerification(INV, r.value, '9e9e9e9e-0000-4000-8000-000000000001', ACTOR);
  assert(s.ok);
  assertEquals(s.value.version, 3);
});
