/**
 * Minimal Stripe REST client + manual webhook signature verification —
 * IVE-COMMERCIAL-BILLING-01 (Fast Track IV), TEST MODE.
 *
 * Deliberately does NOT use the `stripe` npm SDK: the IVE-PROCESS-FILE-
 * CLOSURE mission found `npm:pdf-parse` alone added ~91MB to an Edge
 * Function's deployed bundle for a feature that didn't need most of what
 * it pulled in. Stripe's REST API is plain HTTPS + form-encoded bodies,
 * and webhook signature verification is a documented ~15-line HMAC-SHA256
 * check (https://docs.stripe.com/webhooks#verify-manually) that Deno's
 * built-in Web Crypto API covers with zero extra dependencies. This file
 * is the entire integration surface with Stripe.
 *
 * API version pinned explicitly (not left to the account's dashboard
 * default) so behavior can't silently change: 2026-08-26.dahlia, the
 * current stable monthly release as of this mission (verified against
 * https://docs.stripe.com/api/versioning).
 */

const STRIPE_API_VERSION = '2026-08-26.dahlia';
const STRIPE_API_BASE = 'https://api.stripe.com/v1';

function stripeSecretKey(): string {
  const key = Deno.env.get('STRIPE_SECRET_KEY');
  if (!key) throw new Error('STRIPE_SECRET_KEY not configured');
  return key;
}

/** Encodes a (possibly nested) params object as Stripe expects for
 * x-www-form-urlencoded bodies, e.g. {line_items: [{price: 'x'}]} ->
 * line_items[0][price]=x. */
function encodeStripeParams(params: Record<string, unknown>, prefix = ''): string[] {
  const pairs: string[] = [];
  for (const [key, value] of Object.entries(params)) {
    const paramKey = prefix ? `${prefix}[${key}]` : key;
    if (value === undefined || value === null) continue;
    if (Array.isArray(value)) {
      value.forEach((item, i) => {
        if (item !== null && typeof item === 'object') {
          pairs.push(...encodeStripeParams(item as Record<string, unknown>, `${paramKey}[${i}]`));
        } else {
          pairs.push(`${encodeURIComponent(`${paramKey}[${i}]`)}=${encodeURIComponent(String(item))}`);
        }
      });
    } else if (typeof value === 'object') {
      pairs.push(...encodeStripeParams(value as Record<string, unknown>, paramKey));
    } else {
      pairs.push(`${encodeURIComponent(paramKey)}=${encodeURIComponent(String(value))}`);
    }
  }
  return pairs;
}

export interface StripeFetch {
  (path: string, opts: { method: 'GET' | 'POST'; params?: Record<string, unknown> }): Promise<
    { ok: boolean; status: number; json: () => Promise<Record<string, unknown>> }
  >;
}

/** Default implementation -- real network call to Stripe. Injectable for
 * tests via the `client` parameter on callers below. */
export const defaultStripeFetch: StripeFetch = async (path, { method, params }) => {
  const url = new URL(`${STRIPE_API_BASE}${path}`);
  let body: string | undefined;
  if (method === 'GET' && params) {
    for (const p of encodeStripeParams(params)) {
      const [k, v] = p.split('=');
      url.searchParams.set(decodeURIComponent(k), decodeURIComponent(v));
    }
  } else if (params) {
    body = encodeStripeParams(params).join('&');
  }
  const res = await fetch(url.toString(), {
    method,
    headers: {
      Authorization: `Bearer ${stripeSecretKey()}`,
      'Stripe-Version': STRIPE_API_VERSION,
      ...(body ? { 'Content-Type': 'application/x-www-form-urlencoded' } : {}),
    },
    body,
  });
  return { ok: res.ok, status: res.status, json: () => res.json() };
};

/**
 * Verifies a Stripe webhook signature per
 * https://docs.stripe.com/webhooks#verify-manually. Returns the parsed
 * timestamp on success, throws on any failure (missing header, malformed
 * header, signature mismatch, or timestamp outside tolerance). Callers
 * MUST pass the raw request body text -- never a re-serialized/parsed
 * version, which would not match what Stripe actually signed.
 */
export async function verifyStripeSignature(
  rawBody: string,
  signatureHeader: string | null,
  webhookSecret: string,
  toleranceSeconds = 300,
): Promise<void> {
  if (!signatureHeader) throw new Error('Missing Stripe-Signature header');

  let timestamp: string | undefined;
  let v1: string | undefined;
  for (const part of signatureHeader.split(',')) {
    const [k, v] = part.split('=');
    if (k === 't') timestamp = v;
    // Ignore v0 entirely -- it's a fake scheme Stripe includes only for
    // test-event convenience; trusting it would defeat verification.
    if (k === 'v1') v1 = v;
  }
  if (!timestamp || !v1) throw new Error('Malformed Stripe-Signature header');

  const nowSeconds = Math.floor(Date.now() / 1000);
  const tsSeconds = Number(timestamp);
  if (!Number.isFinite(tsSeconds) || Math.abs(nowSeconds - tsSeconds) > toleranceSeconds) {
    throw new Error('Stripe webhook timestamp outside tolerance (possible replay)');
  }

  const signedPayload = `${timestamp}.${rawBody}`;
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(webhookSecret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sigBytes = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(signedPayload));
  const expectedHex = Array.from(new Uint8Array(sigBytes))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');

  if (!constantTimeEqual(expectedHex, v1)) {
    throw new Error('Stripe webhook signature mismatch');
  }
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export interface StripeCustomer {
  id: string;
  [key: string]: unknown;
}

export interface StripeCheckoutSession {
  id: string;
  url: string | null;
  [key: string]: unknown;
}

export interface StripeSubscription {
  id: string;
  status: string;
  cancel_at_period_end: boolean;
  current_period_end: number;
  items: { data: Array<{ price: { id: string } }> };
  [key: string]: unknown;
}

export async function createStripeCustomer(
  params: { email?: string; supabaseUserId: string },
  client: StripeFetch = defaultStripeFetch,
): Promise<StripeCustomer> {
  const res = await client('/customers', {
    method: 'POST',
    params: {
      email: params.email,
      'metadata[supabase_user_id]': params.supabaseUserId,
    },
  });
  if (!res.ok) throw new Error(`Stripe createCustomer failed: ${res.status}`);
  return (await res.json()) as unknown as StripeCustomer;
}

export async function createCheckoutSession(
  params: { customerId: string; priceId: string; successUrl: string; cancelUrl: string; supabaseUserId: string },
  client: StripeFetch = defaultStripeFetch,
): Promise<StripeCheckoutSession> {
  const res = await client('/checkout/sessions', {
    method: 'POST',
    params: {
      mode: 'subscription',
      customer: params.customerId,
      'line_items[0][price]': params.priceId,
      'line_items[0][quantity]': 1,
      success_url: params.successUrl,
      cancel_url: params.cancelUrl,
      // Defense-in-depth only, NEVER trusted as authoritative -- the
      // webhook resolves the user via subscriptions.stripe_customer_id,
      // written server-side before checkout, not via this field.
      client_reference_id: params.supabaseUserId,
    },
  });
  if (!res.ok) throw new Error(`Stripe createCheckoutSession failed: ${res.status}`);
  return (await res.json()) as unknown as StripeCheckoutSession;
}

export async function retrieveSubscription(
  subscriptionId: string,
  client: StripeFetch = defaultStripeFetch,
): Promise<StripeSubscription> {
  const res = await client(`/subscriptions/${encodeURIComponent(subscriptionId)}`, { method: 'GET' });
  if (!res.ok) throw new Error(`Stripe retrieveSubscription failed: ${res.status}`);
  return (await res.json()) as unknown as StripeSubscription;
}
