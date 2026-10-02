/**
 * Trust boundary tests — IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01
 */
import { assertEquals, assertThrows } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { buildCallerContext, isKnownServiceId, validateProjectScope } from './trust.ts';

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
