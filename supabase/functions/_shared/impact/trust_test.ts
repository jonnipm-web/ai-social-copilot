/**
 * Trust boundary tests — IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01
 */
import { assertEquals, assertThrows } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  assertNoBillingFieldInTrustObject,
  buildCallerContext,
  isKnownServiceId,
  TRUST_NEUTRALITY_POLICY,
  validateProjectScope,
} from './trust.ts';

// ── isKnownServiceId ──────────────────────────────────────────────────────────

Deno.test('isKnownServiceId: known services', () => {
  assertEquals(isKnownServiceId('impact-lab'), true);
  assertEquals(isKnownServiceId('impact-monitor'), true);
});

Deno.test('isKnownServiceId: unknown services rejected', () => {
  assertEquals(isKnownServiceId('stripe-webhook'), false);
  assertEquals(isKnownServiceId('ive-agent-runner'), false);
  assertEquals(isKnownServiceId(''), false);
  assertEquals(isKnownServiceId('SERVICE_ROLE'), false);
  assertEquals(isKnownServiceId('admin'), false);
});

// ── buildCallerContext ────────────────────────────────────────────────────────

Deno.test('buildCallerContext: valid inputs produce frozen context', () => {
  const ctx = buildCallerContext({
    authenticatedUserId: 'user-abc',
    correlationId: 'corr-001',
    projectId: null,
    serviceId: 'impact-lab',
  });
  assertEquals(ctx.authenticatedUserId, 'user-abc');
  assertEquals(ctx.correlationId, 'corr-001');
  assertEquals(ctx.projectId, null);
  assertEquals(ctx.serviceId, 'impact-lab');
  assertEquals(ctx.moduleId, 'impact');
  assertEquals(Object.isFrozen(ctx), true);
});

Deno.test('buildCallerContext: with project', () => {
  const ctx = buildCallerContext({
    authenticatedUserId: 'user-abc',
    correlationId: 'corr-001',
    projectId: 'proj-xyz',
    serviceId: 'impact-lab',
  });
  assertEquals(ctx.projectId, 'proj-xyz');
});

Deno.test('buildCallerContext: unknown serviceId throws', () => {
  assertThrows(
    () => buildCallerContext({ authenticatedUserId: 'u', correlationId: 'c', projectId: null, serviceId: 'evil-service' }),
    Error,
    'TRUST_VIOLATION',
  );
});

Deno.test('buildCallerContext: empty userId throws', () => {
  assertThrows(
    () => buildCallerContext({ authenticatedUserId: '', correlationId: 'c', projectId: null, serviceId: 'impact-lab' }),
    Error,
    'TRUST_VIOLATION',
  );
});

Deno.test('buildCallerContext: empty correlationId throws', () => {
  assertThrows(
    () => buildCallerContext({ authenticatedUserId: 'u', correlationId: '', projectId: null, serviceId: 'impact-lab' }),
    Error,
    'TRUST_VIOLATION',
  );
});

// ── validateProjectScope ──────────────────────────────────────────────────────

Deno.test('validateProjectScope: null project is always valid', () => {
  const ctx = buildCallerContext({ authenticatedUserId: 'u', correlationId: 'c', projectId: null, serviceId: 'impact-lab' });
  assertEquals(validateProjectScope(null, ctx, new Set()), true);
});

Deno.test('validateProjectScope: matching project in owned set', () => {
  const ctx = buildCallerContext({ authenticatedUserId: 'u', correlationId: 'c', projectId: 'proj-1', serviceId: 'impact-lab' });
  assertEquals(validateProjectScope('proj-1', ctx, new Set(['proj-1', 'proj-2'])), true);
});

Deno.test('validateProjectScope: claimed project not in owned set', () => {
  const ctx = buildCallerContext({ authenticatedUserId: 'u', correlationId: 'c', projectId: 'proj-1', serviceId: 'impact-lab' });
  assertEquals(validateProjectScope('proj-1', ctx, new Set(['proj-2'])), false);
});

Deno.test('validateProjectScope: claimed project mismatches context', () => {
  const ctx = buildCallerContext({ authenticatedUserId: 'u', correlationId: 'c', projectId: 'proj-1', serviceId: 'impact-lab' });
  assertEquals(validateProjectScope('proj-2', ctx, new Set(['proj-1', 'proj-2'])), false);
});

// ── Service identity cannot substitute for user identity ─────────────────────

Deno.test('buildCallerContext: service identity does not imply user identity', () => {
  // This test documents the invariant: even a known serviceId requires an
  // authenticatedUserId. A service acting without a user context is rejected.
  assertThrows(
    () => buildCallerContext({ authenticatedUserId: '', correlationId: 'c', projectId: null, serviceId: 'impact-lab' }),
    Error,
  );
});

// ── TRUST_NEUTRALITY_POLICY (anti-pay-to-rank) ───────────────────────────────

Deno.test('TRUST_NEUTRALITY_POLICY: policy version is declared', () => {
  assertEquals(TRUST_NEUTRALITY_POLICY.version, '1.0.0');
  assertEquals(TRUST_NEUTRALITY_POLICY.rule, 'PAYMENT_MUST_NOT_INFLUENCE_TRUST');
});

Deno.test('assertNoBillingFieldInTrustObject: clean object passes', () => {
  // A CallerContext without billing fields — must not throw
  const ctx = buildCallerContext({ authenticatedUserId: 'u1', correlationId: 'c1', projectId: null, serviceId: 'impact-lab' });
  assertNoBillingFieldInTrustObject(ctx as unknown as Record<string, unknown>, 'CallerContext');
});

Deno.test('assertNoBillingFieldInTrustObject: "plan" field throws', () => {
  assertThrows(
    () => assertNoBillingFieldInTrustObject({ plan: 'pro', source: 'example' }, 'VerificationContext'),
    Error,
    'TRUST_NEUTRALITY_VIOLATION',
  );
});

Deno.test('assertNoBillingFieldInTrustObject: "isPro" field throws', () => {
  assertThrows(
    () => assertNoBillingFieldInTrustObject({ isPro: true, score: 0.9 }, 'TrustScore'),
    Error,
    'TRUST_NEUTRALITY_VIOLATION',
  );
});

Deno.test('assertNoBillingFieldInTrustObject: "billing" field throws', () => {
  assertThrows(
    () => assertNoBillingFieldInTrustObject({ billing: 'active', confidence: 0.8 }, 'EvidenceWeight'),
    Error,
    'TRUST_NEUTRALITY_VIOLATION',
  );
});

Deno.test('CallerContext has no billing fields (pay-to-rank prevention)', () => {
  // A paying user's CallerContext must be structurally identical to a free user's.
  // If a billing field were ever added, this guard would catch it.
  const ctx = buildCallerContext({ authenticatedUserId: 'u1', correlationId: 'c1', projectId: null, serviceId: 'impact-lab' });
  assertNoBillingFieldInTrustObject(ctx as unknown as Record<string, unknown>, 'CallerContext');
  // Additional: the trust object for a "pro" user is the same shape as for "free"
  const proCtx = buildCallerContext({ authenticatedUserId: 'pro-user-id', correlationId: 'c2', projectId: null, serviceId: 'impact-lab' });
  assertNoBillingFieldInTrustObject(proCtx as unknown as Record<string, unknown>, 'CallerContext-pro');
  // They must be structurally identical
  assertEquals(Object.keys(ctx), Object.keys(proCtx));
});
