/**
 * IV-WEB-ECOSYSTEM-UNIFICATION-01 — Entitlement Reconcile Worker
 *
 * Scheduled Edge Function that processes pending_retry product entitlement
 * events. Called by Supabase cron (or any external scheduler) at regular
 * intervals (e.g. every 5 minutes).
 *
 * Endpoints:
 *   POST /entitlement-reconcile           — run a reconciliation batch
 *   POST /entitlement-reconcile?batch=N   — run with custom batch size (default 50)
 *
 * Auth: SUPABASE_SERVICE_ROLE_KEY (must be provided as Authorization header
 * or via the Supabase internal invocation mechanism). Rejects unauthenticated
 * requests to prevent accidental public exposure.
 *
 * Scheduler (P2-B DEFERRED): this function must be invoked on a schedule.
 * Configure in Supabase dashboard → Edge Functions → Schedule, or via pg_cron:
 *   SELECT cron.schedule('entitlement-reconcile', '* /5 * * *',
 *     $$SELECT net.http_post('https://<project>.supabase.co/functions/v1/entitlement-reconcile',
 *       headers := '{"Authorization":"Bearer <service_role_key>"}')$$);
 * Without this, pending_retry rows remain unprocessed after transient failures.
 *
 * Calls process_pending_entitlement_events(p_batch_size) RPC which:
 *   - Finds pending_retry events (attempts < max_attempts, not processed)
 *   - Locks each event with pg_try_advisory_xact_lock (concurrent-safe)
 *   - Re-applies upsert_product_subscription
 *   - Marks processed on success, increments attempts on failure
 *   - Marks final_failure after max_attempts
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL       = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY   = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
// EA-01 (2026-10-09): dedicated reconciler credential from Vault (via ENTITLEMENT_RECONCILE_SECRET
// env var). pg_cron uses this token so service_role_key is never stored in pg_settings.
// The Supabase client still uses SERVICE_ROLE_KEY (unchanged); only the inbound auth token
// also accepts ENTITLEMENT_RECONCILE_SECRET. If set, it is the PREFERRED credential for
// the pg_cron caller; SERVICE_ROLE_KEY remains accepted for backward compat during rollout.
const RECONCILE_SECRET   = Deno.env.get('ENTITLEMENT_RECONCILE_SECRET') ?? '';
const DEFAULT_BATCH_SIZE = 50;
const MAX_BATCH_SIZE     = 200;

// P1-D fix + R16-A fix: parse STRIPE_PRICE_MAP for automatic re-resolution of unmapped events.
// Uses the same JSON-object format as stripe-webhook: {"price_id": {"product": "...", "tier": "..."}}.
// Invalid entries are skipped with a console.error so one bad entry does not block all processing.
const VALID_PRODUCTS = new Set(['core', 'impact', 'quant', 'suite']);
const VALID_TIERS    = new Set(['free', 'pro', 'premium']);

function parsePriceMap(): Map<string, { product: string; tier: string }> {
  const raw = Deno.env.get('STRIPE_PRICE_MAP') ?? '';
  const map = new Map<string, { product: string; tier: string }>();
  if (!raw) return map;
  let obj: Record<string, unknown>;
  try {
    obj = JSON.parse(raw) as Record<string, unknown>;
  } catch (e) {
    console.error(`[entitlement-reconcile] STRIPE_PRICE_MAP invalid JSON: ${String(e)}`);
    return map;
  }
  for (const [priceId, v] of Object.entries(obj)) {
    if (v && typeof v === 'object') {
      const e = v as Record<string, unknown>;
      if (typeof e.product === 'string' && typeof e.tier === 'string') {
        if (!VALID_PRODUCTS.has(e.product)) {
          console.error(`[entitlement-reconcile] STRIPE_PRICE_MAP invalid product "${e.product}" for price "${priceId}"`);
          continue;
        }
        if (!VALID_TIERS.has(e.tier)) {
          console.error(`[entitlement-reconcile] STRIPE_PRICE_MAP invalid tier "${e.tier}" for price "${priceId}"`);
          continue;
        }
        map.set(priceId, { product: e.product, tier: e.tier });
      }
    }
  }
  return map;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  // Auth: accept ENTITLEMENT_RECONCILE_SECRET (dedicated pg_cron token, EA-01) OR
  // SERVICE_ROLE_KEY (backward compat during rollout). At least one must be configured.
  // ENTITLEMENT_RECONCILE_SECRET is the preferred credential post-EA-01; pg_cron reads
  // it from Vault via invoke_entitlement_reconciler — service_role_key never in GUC.
  const authHeader = req.headers.get('Authorization') ?? '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : authHeader;
  const validToken = (RECONCILE_SECRET && token === RECONCILE_SECRET)
                  || (SERVICE_ROLE_KEY  && token === SERVICE_ROLE_KEY);
  if (!validToken) {
    return new Response('Unauthorized', { status: 401 });
  }

  const url = new URL(req.url);
  const rawBatch = url.searchParams.get('batch');
  const batchSize = Math.min(
    MAX_BATCH_SIZE,
    Math.max(1, parseInt(rawBatch ?? String(DEFAULT_BATCH_SIZE), 10) || DEFAULT_BATCH_SIZE),
  );

  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    console.error('entitlement-reconcile: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not configured');
    return new Response('Server misconfigured', { status: 500 });
  }

  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const startMs = Date.now();

  // P1-D fix: before calling the SQL worker, re-resolve any events with product='unknown'.
  // When STRIPE_PRICE_MAP is updated and this function is redeployed, previously-unknown
  // events are automatically resolved without operator SQL action.
  //
  // P1-J fix: also persist mappings into stripe_price_configs so the pg_cron SQL worker
  // can resolve unknown-price events independently of this Edge Function being scheduled.
  let priceResolved = 0;
  {
    const priceMap = parsePriceMap();
    if (priceMap.size > 0) {
      // Persist all known price mappings into stripe_price_configs (upsert idempotent).
      // This enables the SQL worker to resolve unknown events even without this function running.
      for (const [priceId, mapping] of priceMap.entries()) {
        const { error: cfgErr } = await db
          .from('stripe_price_configs')
          .upsert({ price_id: priceId, product: mapping.product, tier: mapping.tier, updated_at: new Date().toISOString() }, { onConflict: 'price_id' })
          .select()
          .maybeSingle();
        if (cfgErr) {
          console.error(`entitlement-reconcile: stripe_price_configs upsert failed for ${priceId}:`, cfgErr);
        }
      }

      const { data: unknowns } = await db
        .from('product_entitlement_events')
        .select('id, stripe_price_id')
        .eq('event_type', 'pending_retry')
        .eq('is_processed', false)
        .eq('product', 'unknown')
        .not('stripe_price_id', 'is', null)
        .limit(batchSize);

      for (const row of (unknowns ?? [])) {
        const mapping = priceMap.get(row.stripe_price_id);
        if (mapping) {
          const { error: resolveErr } = await db
            .from('product_entitlement_events')
            .update({
              product:          mapping.product,
              to_tier:          mapping.tier,
              processing_error: null,
              attempts:         0,
            })
            .eq('id', row.id);
          if (resolveErr) {
            console.error(`entitlement-reconcile: price resolution update failed for event ${row.id}:`, resolveErr);
          } else {
            priceResolved++;
          }
        }
      }
    }
  }

  const { data, error } = await db.rpc('process_pending_entitlement_events', {
    p_batch_size: batchSize,
  });

  const durationMs = Date.now() - startMs;

  if (error) {
    console.error('entitlement-reconcile: RPC failed:', error);
    return new Response(
      JSON.stringify({ ok: false, error: String(error), duration_ms: durationMs }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const result = data as {
    processed: number; failed: number; final: number; skipped: number; resolved: number;
  } | null ?? { processed: 0, failed: 0, final: 0, skipped: 0, resolved: 0 };

  console.log(
    `entitlement-reconcile: batch=${batchSize} processed=${result.processed} ` +
    `failed=${result.failed} final=${result.final} skipped=${result.skipped} ` +
    `resolved=${result.resolved} price_resolved=${priceResolved} duration_ms=${durationMs}`,
  );

  return new Response(
    JSON.stringify({ ok: true, ...result, price_resolved: priceResolved, batch_size: batchSize, duration_ms: durationMs, resolved: result.resolved }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});
