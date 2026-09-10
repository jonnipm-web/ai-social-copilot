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
import { QuotaClient, quotaBlockedResponse, refundQuota, reserveQuota } from './quota.ts';

function req(authHeader = 'Bearer test-session-jwt'): Request {
  const headers = new Headers({ Authorization: authHeader });
  return new Request('https://example.test/fn', { method: 'POST', headers });
}

const CORS = { 'Access-Control-Allow-Origin': '*' };

function fakeClient(rpcResults: Record<string, { data: unknown; error: unknown }>): QuotaClient {
  return {
    // deno-lint-ignore require-await
    async rpc(fn: string) {
      return rpcResults[fn] ?? { data: null, error: new Error(`unexpected rpc: ${fn}`) };
    },
  };
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
