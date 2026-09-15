/**
 * IVE-COMMERCIAL-ENTITLEMENTS-01 — regression suite for the quota helper.
 * The atomic reserve/refund SQL logic itself lives in Postgres (migration
 * 20260910190000) and is exercised directly against the real database as
 * part of this mission's verification, not re-implemented here. This
 * suite proves the Edge Function side: reserveQuota()/refundQuota() call
 * the RPCs correctly and quotaBlockedResponse() maps results to the right
 * HTTP shape, using a fake QuotaClient so it needs no network access.
 *
 * Run: deno test --allow-env supabase/functions/_shared/quota_test.ts
 */
import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { QuotaClient, isValidIdempotencyKey, quotaBlockedResponse, refundQuota, reserveQuota } from './quota.ts';

function req(authHeader = 'Bearer test-session-jwt'): Request {
  const headers = new Headers({ Authorization: authHeader });
  return new Request('https://example.test/fn', { method: 'POST', headers });
}

const CORS = { 'Access-Control-Allow-Origin': '*' };
const VALID_KEY = 'a1b2c3d4-e5f6-4789-a012-3456789abcde';

function fakeClient(rpcResults: Record<string, { data: unknown; error: unknown }>): QuotaClient {
  return {
    // deno-lint-ignore require-await
    async rpc(fn: string) {
      return rpcResults[fn] ?? { data: null, error: new Error(`unexpected rpc: ${fn}`) };
    },
  };
}

/** Records the exact (fn, params) pairs it was called with, so tests can
 * assert the idempotency key was actually threaded through rather than
 * silently dropped. */
function recordingClient(rpcResults: Record<string, { data: unknown; error: unknown }>) {
  const calls: Array<{ fn: string; params: Record<string, unknown> | undefined }> = [];
  const client: QuotaClient = {
    // deno-lint-ignore require-await
    async rpc(fn: string, params?: Record<string, unknown>) {
      calls.push({ fn, params });
      return rpcResults[fn] ?? { data: null, error: new Error(`unexpected rpc: ${fn}`) };
    },
  };
  return { client, calls };
}

Deno.test('QUOTA-A: allowed=true passes through used/limit/role', async () => {
  const client = fakeClient({
    try_reserve_ai_quota: { data: { allowed: true, used: 3, limit: 5, role: 'free' }, error: null },
  });
  const result = await reserveQuota(req(), client);
  assertEquals(result.allowed, true);
  assertEquals(result.used, 3);
  assertEquals(result.limit, 5);
});

Deno.test(
  'QUOTA-A2: reserveQuota maps the RPC\'s snake_case reservation_id/idempotent_replay ' +
  'to camelCase reservationId/idempotentReplay (a blind cast would leave these undefined)',
  async () => {
    const client = fakeClient({
      try_reserve_ai_quota: {
        data: {
          allowed: true,
          used: 1,
          limit: 5,
          role: 'free',
          reservation_id: 'r-123',
          idempotent_replay: true,
        },
        error: null,
      },
    });
    const result = await reserveQuota(req(), client);
    assertEquals(result.reservationId, 'r-123');
    assertEquals(result.idempotentReplay, true);
  },
);

Deno.test('QUOTA-B: quota_exceeded -> quotaBlockedResponse returns 429 with used/limit', async () => {
  const client = fakeClient({
    try_reserve_ai_quota: {
      data: { allowed: false, reason: 'quota_exceeded', used: 5, limit: 5, role: 'free' },
      error: null,
    },
  });
  const result = await reserveQuota(req(), client);
  assertEquals(result.allowed, false);
  const res = quotaBlockedResponse(CORS, result);
  assertEquals(res.status, 429);
  const body = await res.json();
  assertEquals(body.error, 'QUOTA_EXCEEDED');
  assertEquals(body.used, 5);
  assertEquals(body.limit, 5);
});

Deno.test('QUOTA-C: RPC error -> fails closed as quota_service_error, 500 (never treated as allowed)', async () => {
  const client = fakeClient({
    try_reserve_ai_quota: { data: null, error: new Error('connection reset') },
  });
  const result = await reserveQuota(req(), client);
  assertEquals(result.allowed, false);
  assertEquals(result.reason, 'quota_service_error');
  const res = quotaBlockedResponse(CORS, result);
  assertEquals(res.status, 500);
});

Deno.test('QUOTA-D: unauthenticated/no_profile reasons also fail closed (not treated as quota_exceeded shape)', async () => {
  const client = fakeClient({
    try_reserve_ai_quota: { data: { allowed: false, reason: 'no_profile' }, error: null },
  });
  const result = await reserveQuota(req(), client);
  assertEquals(result.allowed, false);
  const res = quotaBlockedResponse(CORS, result);
  assertEquals(res.status, 500);
});

Deno.test('QUOTA-E: refundQuota calls the refund RPC and never throws even on error', async () => {
  let called = false;
  const client: QuotaClient = {
    // deno-lint-ignore require-await
    async rpc(fn: string) {
      if (fn === 'refund_ai_quota') called = true;
      return { data: null, error: new Error('should be swallowed') };
    },
  };
  await refundQuota(req(), client); // must not throw
  assertEquals(called, true);
});

Deno.test('QUOTA-F: refundQuota with no injected client and no Authorization header does not throw', async () => {
  const bareReq = new Request('https://example.test/fn', { method: 'POST' });
  await refundQuota(bareReq); // buildUserScopedClient() throws internally; caught and swallowed
});

// ── IVE-COMMERCIAL-QUOTA-HARDENING-13 — idempotency key threading ──────────
// The atomic single-vs-double-reservation SQL semantics live in Postgres
// (migration 20260918000000) and are NOT re-exercised here — this suite
// only proves the Edge Function layer correctly forwards (or withholds)
// the key, and fails closed on a malformed one, per mission Section 22's
// own acknowledgment that DB-level concurrency proof needs a real/isolated
// database this repository's test infra does not provide.

Deno.test('QUOTA-G: isValidIdempotencyKey accepts a real UUID, rejects everything else', () => {
  assertEquals(isValidIdempotencyKey(VALID_KEY), true);
  assertEquals(isValidIdempotencyKey('not-a-uuid'), false);
  assertEquals(isValidIdempotencyKey(''), false);
  assertEquals(isValidIdempotencyKey(null), false);
  assertEquals(isValidIdempotencyKey(undefined), false);
  assertEquals(isValidIdempotencyKey(12345), false);
  // A UUID missing hyphens/wrong grouping shape.
  assertEquals(isValidIdempotencyKey('a1b2c3d4e5f64789a0123456789abcde'), false);
});

const OP = 'gap-analysis';

Deno.test('QUOTA-H: reserveQuota forwards a valid key + operationType as p_idempotency_key/p_operation_type', async () => {
  const { client, calls } = recordingClient({
    try_reserve_ai_quota: { data: { allowed: true, used: 1, limit: 5, role: 'free' }, error: null },
  });
  const result = await reserveQuota(req(), client, VALID_KEY, OP);
  assertEquals(result.allowed, true);
  assertEquals(calls.length, 1);
  assertEquals(calls[0].fn, 'try_reserve_ai_quota');
  assertEquals(calls[0].params, { p_idempotency_key: VALID_KEY, p_operation_type: OP });
});

Deno.test('QUOTA-I: reserveQuota with no key calls the RPC with no params (legacy behavior unchanged)', async () => {
  const { client, calls } = recordingClient({
    try_reserve_ai_quota: { data: { allowed: true, used: 1, limit: 5, role: 'free' }, error: null },
  });
  await reserveQuota(req(), client);
  assertEquals(calls[0].params, undefined);
});

Deno.test(
  'QUOTA-J: reserveQuota with a malformed key fails closed WITHOUT ever calling the RPC',
  async () => {
    const { client, calls } = recordingClient({
      try_reserve_ai_quota: { data: { allowed: true, used: 1, limit: 5, role: 'free' }, error: null },
    });
    const result = await reserveQuota(req(), client, 'not-a-real-uuid', OP);
    assertEquals(result.allowed, false);
    assertEquals(result.reason, 'invalid_idempotency_key');
    assertEquals(calls.length, 0, 'a malformed key must never reach Postgres as a type-cast attempt');
  },
);

Deno.test('QUOTA-K: quotaBlockedResponse maps invalid_idempotency_key to 400, not 429/500', async () => {
  const res = quotaBlockedResponse(CORS, { allowed: false, reason: 'invalid_idempotency_key' });
  assertEquals(res.status, 400);
  const body = await res.json();
  assertEquals(body.error, 'INVALID_IDEMPOTENCY_KEY');
});

// ── Codex round-2 fix — refund targets an immutable reservation id ────────
// (Found that refunding by re-deriving "the current row for this
// key+operation+period" let a DELAYED DUPLICATE refund match a NEWER
// reservation created by a legitimate retry, silently un-charging a real,
// successful AI call. refundQuota's contract changed accordingly: it now
// takes the reserve call's own QuotaResult, never the key/operation.)

Deno.test('QUOTA-L: refundQuota forwards quota.reservationId as p_reservation_id', async () => {
  const { client, calls } = recordingClient({
    refund_ai_quota: { data: null, error: null },
  });
  await refundQuota(req(), client, { reservationId: 'reservation-abc-123' });
  assertEquals(calls[0].fn, 'refund_ai_quota');
  assertEquals(calls[0].params, { p_reservation_id: 'reservation-abc-123' });
});

Deno.test('QUOTA-M: refundQuota with no quota argument calls the RPC with no params (legacy unconditional decrement)', async () => {
  const { client, calls } = recordingClient({
    refund_ai_quota: { data: null, error: null },
  });
  await refundQuota(req(), client);
  assertEquals(calls[0].params, undefined);
});

// ── Codex round-3 fix — a REPLAY must never refund the shared reservation ──
// (A replayed request (idempotentReplay: true) is handed the SAME
// reservationId as the request that actually created it. If the replay's
// own downstream call failed, refunding that shared reservation would undo
// the ORIGINAL request's charge even if the original had already
// succeeded. This is enforced centrally in refundQuota, not repeated at
// each of the 16 Edge Function call sites, so it can never be forgotten.)

Deno.test(
  'QUOTA-R: refundQuota REFUSES to call the RPC at all when quota.idempotentReplay is true, ' +
  'even though a reservationId is present',
  async () => {
    const { client, calls } = recordingClient({
      refund_ai_quota: { data: null, error: null },
    });
    await refundQuota(req(), client, { reservationId: 'shared-reservation-id', idempotentReplay: true });
    assertEquals(calls.length, 0, 'a replay must never be able to refund the reservation it does not own');
  },
);

Deno.test(
  'QUOTA-S: refundQuota DOES refund when idempotentReplay is false (the actual owner of a fresh reservation)',
  async () => {
    const { client, calls } = recordingClient({
      refund_ai_quota: { data: null, error: null },
    });
    await refundQuota(req(), client, { reservationId: 'my-own-reservation-id', idempotentReplay: false });
    assertEquals(calls.length, 1);
    assertEquals(calls[0].params, { p_reservation_id: 'my-own-reservation-id' });
  },
);

// ── Codex Gate 1 P1 fix — operationType required whenever a key is given ──
// (Gate 1 found that a bare (user_id, idempotency_key) scope let the SAME
// key be replayed against a DIFFERENT operation and be mistaken for an
// already-successful reservation, bypassing quota entirely. Requiring —
// and never trusting the client for — operationType is the fix.)

Deno.test(
  'QUOTA-N: reserveQuota with a key but NO operationType fails closed as invalid_request, RPC never called',
  async () => {
    const { client, calls } = recordingClient({
      try_reserve_ai_quota: { data: { allowed: true, used: 1, limit: 5, role: 'free' }, error: null },
    });
    const result = await reserveQuota(req(), client, VALID_KEY);
    assertEquals(result.allowed, false);
    assertEquals(result.reason, 'invalid_request');
    assertEquals(calls.length, 0);
  },
);

Deno.test(
  'QUOTA-O: reserveQuota with a key and an EMPTY-STRING operationType also fails closed',
  async () => {
    const { client, calls } = recordingClient({
      try_reserve_ai_quota: { data: { allowed: true, used: 1, limit: 5, role: 'free' }, error: null },
    });
    const result = await reserveQuota(req(), client, VALID_KEY, '   ');
    assertEquals(result.allowed, false);
    assertEquals(result.reason, 'invalid_request');
    assertEquals(calls.length, 0);
  },
);

Deno.test('QUOTA-P: quotaBlockedResponse maps invalid_request to 400, not 429/500', async () => {
  const res = quotaBlockedResponse(CORS, { allowed: false, reason: 'invalid_request' });
  assertEquals(res.status, 400);
  const body = await res.json();
  assertEquals(body.error, 'INVALID_REQUEST');
});

