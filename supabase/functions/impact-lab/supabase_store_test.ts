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
      for (const f of ['eq', 'is', 'in']) b[f] = chain((k, v) => call.filters.push([k as string, v]));
      b.order = chain(() => {});
      b.limit = chain(() => {});
      b.maybeSingle = () => Promise.resolve(respond(call));
      b.single = () => Promise.resolve(respond(call));
      b.then = (res: (v: unknown) => unknown, rej: (e: unknown) => unknown) => Promise.resolve(respond(call)).then(res, rej);
      return b;
    },
    rpc(fn: string, args: Record<string, unknown>) {
      const call: Call = { client: name, table: fn, op: 'rpc', filters: [], payload: args };
      calls.push(call);
      return Promise.resolve(respond(call));
    },
  };
}

Deno.test('SS-02 reads go through the caller-JWT client (RLS); atomic write RPCs use user JWT; other writes through service', async () => {
  const calls: Call[] = [];
  const respond = (c: Call) => {
    // MACRO-08 TOCTOU fix: createInvestigation uses user.rpc + user.select
    if (c.op === 'rpc' && c.table === 'impact_atomic_create_investigation') {
      return { data: [{ investigation_id: INV, subject_org_ref: 'org-x', denied: false, denied_reason: 'ok' }], error: null };
    }
    // After atomic create, the store uses service.select (avoids RLS gap — P2-Q11).
    if (c.op === 'select' && c.table === 'impact_investigations' && c.client === 'service' && c.filters.some(([k]) => k === 'id')) {
      return { data: { id: INV, owner_id: ACTOR, project_id: null, subject_org_ref: 'org-x', subject_org_type: 'NGO', subject_identity: {}, status: 'ACTIVE', audit_seq: 0, audit_head: '0'.repeat(64), created_at: 'x' }, error: null };
    }
    // MACRO-08 TOCTOU fix: insertVerification uses user.rpc + service.select
    if (c.op === 'rpc' && c.table === 'impact_atomic_insert_verification') {
      return { data: [{ stored_version: 1, denied: false, denied_reason: 'ok' }], error: null };
    }
    // After atomic insert, store does a service SELECT to get full verification row
    if (c.op === 'select' && c.table === 'impact_verifications' && c.client === 'service') {
      return { data: { version: 1, result: {}, idempotency_key: null }, error: null };
    }
    if (c.op === 'rpc' && c.table === 'impact_audit_chain_ok') return { data: true, error: null };
    if (c.op === 'rpc') return { data: true, error: null };
    if (c.op === 'update') return { data: [{ ref: 'x' }], error: null };
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

  await store.createInvestigation({ ownerId: ACTOR, projectId: null, subjectOrgRef: 'org-x', subjectOrgType: 'NGO', subjectIdentity: {} });
  const createCalls = calls.splice(0);
  // SS-02a TOCTOU: createInvestigation uses user.rpc (atomic write), then service.select (read-back, P2-Q11)
  assert(createCalls.some((c) => c.client === 'user' && c.op === 'rpc' && c.table === 'impact_atomic_create_investigation'),
    'createInvestigation uses user.rpc for atomic write');
  assert(!createCalls.some((c) => c.client === 'service' && c.op === 'insert' && c.table === 'impact_investigations'),
    'createInvestigation must NOT use service.insert (TOCTOU fix)');

  await store.insertSource(INV, { source: a.sources[0], snapshot: null }, ACTOR);
  await store.insertClaim(INV, a.claim, ACTOR);
  await store.insertEvidence(INV, a.evidence[0], ACTOR);
  await store.insertVerification(INV, r.value, null, ACTOR);
  const verCalls = calls.filter((c) => c.table === 'impact_atomic_insert_verification' || (c.table === 'impact_verifications' && c.op === 'insert'));
  // SS-02b TOCTOU: insertVerification uses user.rpc (atomic write), not service.insert
  assert(verCalls.some((c) => c.client === 'user' && c.op === 'rpc' && c.table === 'impact_atomic_insert_verification'),
    'insertVerification uses user.rpc for atomic write');
  assert(!verCalls.some((c) => c.client === 'service' && c.op === 'insert' && c.table === 'impact_verifications'),
    'insertVerification must NOT use service.insert (TOCTOU fix)');

  await store.updateSourceStatus(INV, 'src-registry-hb', 'RETRACTED', ACTOR);
  await store.insertDispute(INV, { ref: 'd1', claimRef: 'claim-a', kind: 'ORGANIZATION_RESPONSE', openedAt: 'x', submittedEvidenceRefs: [], resolution: null, resolvedAt: null }, ACTOR);
  await store.resolveDispute(INV, 'd1', 'UPHELD', 'x', ACTOR);
  await store.archiveInvestigation(INV, ACTOR);
  // All remaining writes (sources, claims, evidence, disputes, archive) still go through service client
  const serviceWrites = calls.filter((c) => c.client === 'service' && c.op === 'insert');
  assert(serviceWrites.length > 0, 'other inserts still use service client');
  assertEquals(calls.filter((c) => c.op === 'delete' || c.op === 'upsert').length, 0, 'no DELETE or upsert');
  for (const w of serviceWrites.filter((c) => !['impact_investigations', 'impact_verifications'].includes(c.table))) {
    const p = w.payload as Record<string, unknown>;
    assertEquals([p.investigation_id, p.created_by], [INV, ACTOR], w.table);
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

Deno.test('SS-04 an idempotent retry that races returns the winning row via idempotency_key fallback', async () => {
  // MACRO-08 TOCTOU fix: user.rpc atomic call returns 23505; store falls back
  // to service read by idempotency_key to return the winning row.
  const IDEM = '9e9e9e9e-0000-4000-8000-000000000001';
  const calls: Call[] = [];
  const respond = (c: Call) => {
    if (c.op === 'rpc' && c.table === 'impact_atomic_insert_verification') {
      return { data: null, error: { code: '23505', message: 'duplicate' } };
    }
    if (c.op === 'select' && c.filters.some(([k]) => k === 'idempotency_key')) {
      return { data: { version: 3, result: { resultId: 'vr_x' }, idempotency_key: IDEM }, error: null };
    }
    return { data: null, error: null };
  };
  const store = new SupabaseImpactLabStore(fakeClient('user', calls, respond), fakeClient('service', calls, respond));
  const a = (await goldenCases()).find((c) => c.id === 'A')!;
  const r = await verifyClaim({ claim: a.claim, evidence: a.evidence, sources: a.sources }, a.ctx);
  assert(r.ok);
  const s = await store.insertVerification(INV, r.value, IDEM, ACTOR);
  assert(s.ok);
  assertEquals(s.value.version, 3);
  // Assert exact fallback arguments (P2-Q19)
  const fallback = calls.find((c) => c.op === 'select' && c.filters.some(([k]) => k === 'idempotency_key'));
  assert(fallback, 'idempotency_key fallback read must occur');
  assertEquals(fallback!.client, 'service', 'fallback uses service client');
  assert(fallback!.filters.some(([k, v]) => k === 'investigation_id' && v === INV), 'fallback filters on investigation_id');
  assert(fallback!.filters.some(([k, v]) => k === 'idempotency_key' && v === IDEM), 'fallback filters on exact idempotency_key');
});

Deno.test('SS-04b an idempotent retry without idempotency_key falls back to result_id lookup', async () => {
  // When no idempotency_key is provided, 23505 triggers a result_id fallback.
  const calls: Call[] = [];
  const respond = (c: Call) => {
    if (c.op === 'rpc' && c.table === 'impact_atomic_insert_verification') {
      return { data: null, error: { code: '23505', message: 'duplicate' } };
    }
    if (c.op === 'select' && c.filters.some(([k]) => k === 'result_id')) {
      return { data: { version: 7, result: { resultId: 'vr_y' }, idempotency_key: null }, error: null };
    }
    return { data: null, error: null };
  };
  const store = new SupabaseImpactLabStore(fakeClient('user', calls, respond), fakeClient('service', calls, respond));
  const a = (await goldenCases()).find((c) => c.id === 'A')!;
  const r = await verifyClaim({ claim: a.claim, evidence: a.evidence, sources: a.sources }, a.ctx);
  assert(r.ok);
  // null idempotency key → must NOT look up by idempotency_key, must use result_id
  const s = await store.insertVerification(INV, r.value, null, ACTOR);
  assert(s.ok);
  assertEquals(s.value.version, 7);
  assert(!calls.some((c) => c.filters.some(([k]) => k === 'idempotency_key')), 'no idempotency_key lookup when key is null');
  const fallback = calls.find((c) => c.op === 'select' && c.filters.some(([k]) => k === 'result_id'));
  assert(fallback, 'result_id fallback must occur');
  assertEquals(fallback!.client, 'service', 'fallback uses service client');
  assert(fallback!.filters.some(([k, v]) => k === 'investigation_id' && v === INV), 'fallback filters on investigation_id');
});

Deno.test('SS-05 an archive or status update that changes no row is reported as a failure, not success (I1F-03)', async () => {
  const calls: Call[] = [];
  const respond = (c: Call) => (c.op === 'update' ? { data: [], error: null } : { data: null, error: null });
  const store = new SupabaseImpactLabStore(fakeClient('user', calls, respond), fakeClient('service', calls, respond));
  const a = await store.archiveInvestigation(INV, ACTOR);
  assertEquals(a.ok ? 'OK' : a.error.code, 'INVESTIGATION_NOT_ACTIVE');
  const u = await store.updateSourceStatus(INV, 'src-x', 'RETRACTED', ACTOR);
  assertEquals(u.ok ? 'OK' : u.error.code, 'INVALID_REQUEST');
});

// TOCTOU atomic write tests (MACRO-08 security hardening)

Deno.test('SS-TOCTOU-01 createInvestigation: atomic RPC denied=pro_required → INVALID_REQUEST', async () => {
  // Simulates a user whose entitlement was revoked between the pre-flight
  // check_impact_access call and the atomic write RPC.
  const calls: Call[] = [];
  const respond = (c: Call) => {
    if (c.op === 'rpc' && c.table === 'impact_atomic_create_investigation') {
      return { data: [{ investigation_id: null, subject_org_ref: 'org-x', denied: true, denied_reason: 'pro_required' }], error: null };
    }
    return { data: null, error: null };
  };
  const store = new SupabaseImpactLabStore(fakeClient('user', calls, respond), fakeClient('service', calls, respond));
  const result = await store.createInvestigation({ ownerId: ACTOR, projectId: null, subjectOrgRef: 'org-x', subjectOrgType: 'NGO', subjectIdentity: {} });
  assert(!result.ok, 'must fail when entitlement denied');
  assertEquals(result.error.code, 'INVALID_REQUEST', 'denied=pro_required maps to INVALID_REQUEST');
  // Verify no fallback service.insert was attempted
  assert(!calls.some((c) => c.client === 'service' && c.op === 'insert'), 'no service insert after RPC denial');
});

Deno.test('SS-TOCTOU-02 createInvestigation: atomic RPC denied=limit_exceeded → LIMIT_EXCEEDED', async () => {
  const calls: Call[] = [];
  const respond = (c: Call) => {
    if (c.op === 'rpc' && c.table === 'impact_atomic_create_investigation') {
      return { data: [{ investigation_id: null, subject_org_ref: 'org-x', denied: true, denied_reason: 'limit_exceeded' }], error: null };
    }
    return { data: null, error: null };
  };
  const store = new SupabaseImpactLabStore(fakeClient('user', calls, respond), fakeClient('service', calls, respond));
  const result = await store.createInvestigation({ ownerId: ACTOR, projectId: null, subjectOrgRef: 'org-x', subjectOrgType: 'NGO', subjectIdentity: {} });
  assert(!result.ok, 'must fail when limit exceeded');
  assertEquals(result.error.code, 'LIMIT_EXCEEDED');
});

Deno.test('SS-TOCTOU-03 createInvestigation: atomic RPC denied=no_session → INTERNAL_ERROR', async () => {
  const calls: Call[] = [];
  const respond = (c: Call) => {
    if (c.op === 'rpc' && c.table === 'impact_atomic_create_investigation') {
      return { data: [{ investigation_id: null, subject_org_ref: 'org-x', denied: true, denied_reason: 'no_session' }], error: null };
    }
    return { data: null, error: null };
  };
  const store = new SupabaseImpactLabStore(fakeClient('user', calls, respond), fakeClient('service', calls, respond));
  const result = await store.createInvestigation({ ownerId: ACTOR, projectId: null, subjectOrgRef: 'org-x', subjectOrgType: 'NGO', subjectIdentity: {} });
  assert(!result.ok);
  assertEquals(result.error.code, 'INTERNAL_ERROR');
});

Deno.test('SS-TOCTOU-04 insertVerification: atomic RPC denied=not_owner → INVESTIGATION_NOT_FOUND', async () => {
  // Simulates a cross-user forgery attempt: the investigation is owned by
  // another user; the atomic RPC ownership check catches it.
  const calls: Call[] = [];
  const respond = (c: Call) => {
    if (c.op === 'rpc' && c.table === 'impact_atomic_insert_verification') {
      return { data: [{ stored_version: null, denied: true, denied_reason: 'not_owner' }], error: null };
    }
    return { data: null, error: null };
  };
  const store = new SupabaseImpactLabStore(fakeClient('user', calls, respond), fakeClient('service', calls, respond));
  const a = (await goldenCases()).find((c) => c.id === 'A')!;
  const r = await verifyClaim({ claim: a.claim, evidence: a.evidence, sources: a.sources }, a.ctx);
  assert(r.ok);
  const result = await store.insertVerification(INV, r.value, null, ACTOR);
  assert(!result.ok, 'must fail when caller does not own investigation');
  assertEquals(result.error.code, 'INVESTIGATION_NOT_FOUND');
  assert(!calls.some((c) => c.client === 'service' && c.op === 'insert'), 'no service insert after ownership denial');
});

Deno.test('SS-TOCTOU-05 insertVerification: atomic RPC denied=pro_required → INVALID_REQUEST', async () => {
  // Simulates entitlement revoked between pre-flight check and write.
  const calls: Call[] = [];
  const respond = (c: Call) => {
    if (c.op === 'rpc' && c.table === 'impact_atomic_insert_verification') {
      return { data: [{ stored_version: null, denied: true, denied_reason: 'pro_required' }], error: null };
    }
    return { data: null, error: null };
  };
  const store = new SupabaseImpactLabStore(fakeClient('user', calls, respond), fakeClient('service', calls, respond));
  const a = (await goldenCases()).find((c) => c.id === 'A')!;
  const r = await verifyClaim({ claim: a.claim, evidence: a.evidence, sources: a.sources }, a.ctx);
  assert(r.ok);
  const result = await store.insertVerification(INV, r.value, null, ACTOR);
  assert(!result.ok);
  assertEquals(result.error.code, 'INVALID_REQUEST');
});

Deno.test('SS-TOCTOU-06 createInvestigation: atomic RPC denied=no_profile → INTERNAL_ERROR', async () => {
  // Caller has a valid JWT but no profiles row — entitlement gate must fail closed.
  // Codex CLASS D Round 3 P1 fix: NOT FOUND after FOR UPDATE returns no_profile.
  const calls: Call[] = [];
  const respond = (c: Call) => {
    if (c.op === 'rpc' && c.table === 'impact_atomic_create_investigation') {
      return { data: [{ investigation_id: null, subject_org_ref: 'org-x', denied: true, denied_reason: 'no_profile' }], error: null };
    }
    return { data: null, error: null };
  };
  const store = new SupabaseImpactLabStore(fakeClient('user', calls, respond), fakeClient('service', calls, respond));
  const result = await store.createInvestigation({ ownerId: ACTOR, projectId: null, subjectOrgRef: 'org-x', subjectOrgType: 'NGO', subjectIdentity: {} });
  assert(!result.ok, 'must fail when profiles row is absent');
  assertEquals(result.error.code, 'INTERNAL_ERROR', 'no_profile is a server-side invariant violation → INTERNAL_ERROR');
  assert(!calls.some((c) => c.client === 'service' && c.op === 'insert'), 'no service insert after no_profile denial');
});

Deno.test('SS-TOCTOU-07 insertVerification: atomic RPC denied=no_profile → INTERNAL_ERROR', async () => {
  // Codex CLASS D Round 3 P1 fix coverage for insertVerification path.
  const calls: Call[] = [];
  const respond = (c: Call) => {
    if (c.op === 'rpc' && c.table === 'impact_atomic_insert_verification') {
      return { data: [{ stored_version: null, denied: true, denied_reason: 'no_profile' }], error: null };
    }
    return { data: null, error: null };
  };
  const store = new SupabaseImpactLabStore(fakeClient('user', calls, respond), fakeClient('service', calls, respond));
  const a = (await goldenCases()).find((c) => c.id === 'A')!;
  const r = await verifyClaim({ claim: a.claim, evidence: a.evidence, sources: a.sources }, a.ctx);
  assert(r.ok);
  const result = await store.insertVerification(INV, r.value, null, ACTOR);
  assert(!result.ok, 'must fail when profiles row is absent');
  assertEquals(result.error.code, 'INTERNAL_ERROR');
  assert(!calls.some((c) => c.client === 'service' && c.op === 'insert'), 'no service insert after no_profile denial');
});
