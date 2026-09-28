import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { checkEngineAvailability, runV10ViaBridge } from './backtest_bridge.ts';
import { buildV10ReferenceSpecification } from './v10_reference.ts';

async function withFakeBridge(
  handler: (req: Request) => Response | Promise<Response>,
  fn: (baseUrl: string) => Promise<void>,
): Promise<void> {
  const controller = new AbortController();
  const server = Deno.serve({ port: 0, signal: controller.signal, onListen: () => {} }, handler);
  const addr = server.addr as Deno.NetAddr;
  try {
    await fn(`http://127.0.0.1:${addr.port}`);
  } finally {
    controller.abort();
    await server.finished;
  }
}

Deno.test('BB-01 the allowlist refuses a dataset/engine mismatch before any network call', async () => {
  const specResult = buildV10ReferenceSpecification();
  assert(specResult.ok);
  if (!specResult.ok) return;
  let called = false;
  await withFakeBridge(
    () => {
      called = true;
      return new Response('should never be reached', { status: 200 });
    },
    async (baseUrl) => {
      const result = await runV10ViaBridge({ baseUrl, timeoutMs: 2000 }, 'synthetic-fixture-5min-v1', specResult.value, null);
      assert(!result.ok);
      assertEquals(called, false);
    },
  );
});

Deno.test('BB-02 a successful bridge response maps cleanly into BacktestBridgeSuccess', async () => {
  const specResult = buildV10ReferenceSpecification();
  assert(specResult.ok);
  if (!specResult.ok) return;
  await withFakeBridge(
    () =>
      new Response(
        JSON.stringify({
          ok: true, engine: 'PAULO_TREND_FIBONACCI_V10', dataset_id: 'win1-5min-qt01c3',
          dataset_hash: '5220e7cc9f46987b8dcf6cb9', trade_count: 75, long_count: 40, short_count: 35,
          wins: 30, losses: 45, net_pnl: -57.0, gross_pnl: -57.0, gross_profit: 500, gross_loss: 557,
          total_cost: 0, target_touches: 8, stop_touches: 47, execution_ambiguity_count: 19,
          result_hash: 'c19661f4dfc61193',
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      ),
    async (baseUrl) => {
      const result = await runV10ViaBridge({ baseUrl, timeoutMs: 2000 }, 'win1-5min-qt01c3', specResult.value, null);
      assert(result.ok, JSON.stringify(!result.ok && result.error));
      if (!result.ok) return;
      assertEquals(result.value.tradeCount, 75);
      assertEquals(result.value.netPnl, -57.0);
      assertEquals(result.value.resultHash, 'c19661f4dfc61193');
    },
  );
});

Deno.test('BB-03 a refusal response from the bridge (ok:false) becomes a StrategyResult failure, never thrown', async () => {
  const specResult = buildV10ReferenceSpecification();
  assert(specResult.ok);
  if (!specResult.ok) return;
  await withFakeBridge(
    () => new Response(JSON.stringify({ ok: false, error: 'DATASET_UNAVAILABLE' }), { status: 422, headers: { 'Content-Type': 'application/json' } }),
    async (baseUrl) => {
      const result = await runV10ViaBridge({ baseUrl, timeoutMs: 2000 }, 'win1-5min-qt01c3', specResult.value, null);
      assert(!result.ok);
    },
  );
});

Deno.test('BB-04 an unreachable bridge (nothing listening) fails closed instead of throwing', async () => {
  const specResult = buildV10ReferenceSpecification();
  assert(specResult.ok);
  if (!specResult.ok) return;
  const result = await runV10ViaBridge({ baseUrl: 'http://127.0.0.1:1', timeoutMs: 1000 }, 'win1-5min-qt01c3', specResult.value, null);
  assert(!result.ok);
});

Deno.test('BB-05 a bridge that never responds is aborted at the configured timeout, not left hanging', async () => {
  const specResult = buildV10ReferenceSpecification();
  assert(specResult.ok);
  if (!specResult.ok) return;
  await withFakeBridge(
    () => new Promise<Response>((resolve) => setTimeout(() => resolve(new Response('late')), 5000)),
    async (baseUrl) => {
      const started = performance.now();
      const result = await runV10ViaBridge({ baseUrl, timeoutMs: 300 }, 'win1-5min-qt01c3', specResult.value, null);
      const elapsed = performance.now() - started;
      assert(!result.ok);
      assert(elapsed < 4000, `expected an early abort, took ${elapsed}ms`);
    },
  );
});

Deno.test('BB-09 (Codex final audit, Macro-06 deferred P3, closed) a bridge response with a non-numeric field is refused, never silently coerced to NaN', async () => {
  const specResult = buildV10ReferenceSpecification();
  assert(specResult.ok);
  if (!specResult.ok) return;
  await withFakeBridge(
    () =>
      new Response(
        JSON.stringify({
          ok: true, engine: 'PAULO_TREND_FIBONACCI_V10', dataset_id: 'win1-5min-qt01c3',
          dataset_hash: '5220e7cc9f46987b8dcf6cb9', trade_count: 'not-a-number', long_count: 40, short_count: 35,
          wins: 30, losses: 45, net_pnl: -57.0, gross_pnl: -57.0, gross_profit: 500, gross_loss: 557,
          total_cost: 0, target_touches: 8, stop_touches: 47, execution_ambiguity_count: 19,
          result_hash: 'c19661f4dfc61193',
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      ),
    async (baseUrl) => {
      const result = await runV10ViaBridge({ baseUrl, timeoutMs: 2000 }, 'win1-5min-qt01c3', specResult.value, null);
      assert(!result.ok);
      assertEquals(result.ok ? undefined : result.error.details?.field, 'tradeCount');
    },
  );
});

Deno.test('BB-10 (Codex final audit, Macro-06 deferred P3, closed) a bridge response with a missing/empty string field is refused', async () => {
  const specResult = buildV10ReferenceSpecification();
  assert(specResult.ok);
  if (!specResult.ok) return;
  await withFakeBridge(
    () =>
      new Response(
        JSON.stringify({
          ok: true, engine: 'PAULO_TREND_FIBONACCI_V10', dataset_id: 'win1-5min-qt01c3',
          dataset_hash: '', trade_count: 75, long_count: 40, short_count: 35,
          wins: 30, losses: 45, net_pnl: -57.0, gross_pnl: -57.0, gross_profit: 500, gross_loss: 557,
          total_cost: 0, target_touches: 8, stop_touches: 47, execution_ambiguity_count: 19,
          result_hash: 'c19661f4dfc61193',
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      ),
    async (baseUrl) => {
      const result = await runV10ViaBridge({ baseUrl, timeoutMs: 2000 }, 'win1-5min-qt01c3', specResult.value, null);
      assert(!result.ok);
      assertEquals(result.ok ? undefined : result.error.details?.field, 'dataset_hash');
    },
  );
});

Deno.test('BB-06 (§5) checkEngineAvailability reports true when the bridge health check says the engine is ready', async () => {
  await withFakeBridge(
    () => new Response(JSON.stringify({ ok: true, engines: { PAULO_TREND_FIBONACCI_V10: { available: true, reason: null } } }), {
      status: 200, headers: { 'Content-Type': 'application/json' },
    }),
    async (baseUrl) => {
      const result = await checkEngineAvailability({ baseUrl, timeoutMs: 2000 });
      assertEquals(result, { available: true, reason: null });
    },
  );
});

Deno.test('BB-07 (§5) checkEngineAvailability surfaces the bridges own unavailable reason, never fabricating one', async () => {
  await withFakeBridge(
    () => new Response(JSON.stringify({
      ok: true, engines: { PAULO_TREND_FIBONACCI_V10: { available: false, reason: 'win1_csv_path does not point at a real file' } },
    }), { status: 200, headers: { 'Content-Type': 'application/json' } }),
    async (baseUrl) => {
      const result = await checkEngineAvailability({ baseUrl, timeoutMs: 2000 });
      assertEquals(result.available, false);
      assertEquals(result.reason, 'win1_csv_path does not point at a real file');
    },
  );
});

Deno.test('BB-08 (§5) checkEngineAvailability against an unreachable bridge reports unavailable, never throws', async () => {
  const result = await checkEngineAvailability({ baseUrl: 'http://127.0.0.1:1', timeoutMs: 1000 });
  assertEquals(result.available, false);
  assert(typeof result.reason === 'string' && result.reason.length > 0);
});
