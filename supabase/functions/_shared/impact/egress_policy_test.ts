/**
 * Egress policy tests — IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01
 *
 * Covers: allowlist enforcement, content-type validation, purpose taxonomy,
 * SSRF-adjacent policy decisions.
 */
import { assertEquals, assertThrows } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { buildEgressOptions, validateEgressContentType } from './egress_policy.ts';

// ── buildEgressOptions: REGISTRY_QUERY ───────────────────────────────────────

Deno.test('buildEgressOptions: REGISTRY_QUERY without hosts returns full registry set', () => {
  const opts = buildEgressOptions('REGISTRY_QUERY');
  assertEquals(opts.allowedHosts instanceof Set, true);
  assertEquals(opts.allowedHosts!.has('api.company-information.service.gov.uk'), true);
  assertEquals(opts.allowedHosts!.has('api.charitycommission.gov.uk'), true);
  assertEquals(opts.allowedHosts!.has('apps.irs.gov'), true);
});

Deno.test('buildEgressOptions: REGISTRY_QUERY with valid subset', () => {
  const hosts = new Set(['api.company-information.service.gov.uk']);
  const opts = buildEgressOptions('REGISTRY_QUERY', hosts);
  assertEquals(opts.allowedHosts, hosts);
});

Deno.test('buildEgressOptions: REGISTRY_QUERY with unknown host throws', () => {
  assertThrows(
    () => buildEgressOptions('REGISTRY_QUERY', new Set(['evil.host.example.com'])),
    Error,
    'EGRESS_POLICY_VIOLATION',
  );
});

Deno.test('buildEgressOptions: REGISTRY_QUERY with internal host throws', () => {
  // An internal Supabase host is not in the registry allowlist.
  assertThrows(
    () => buildEgressOptions('REGISTRY_QUERY', new Set(['supabase.io'])),
    Error,
    'EGRESS_POLICY_VIOLATION',
  );
});

// ── buildEgressOptions: PUBLIC_SOURCE_FETCH ───────────────────────────────────

Deno.test('buildEgressOptions: PUBLIC_SOURCE_FETCH has no host restriction', () => {
  const opts = buildEgressOptions('PUBLIC_SOURCE_FETCH');
  assertEquals(opts.allowedHosts, undefined);
  assertEquals(opts.timeoutMs, 15_000);
  assertEquals(opts.maxResponseBytes, 2_000_000);
});

// ── buildEgressOptions: INTERNAL ──────────────────────────────────────────────

Deno.test('buildEgressOptions: INTERNAL without hosts throws', () => {
  assertThrows(() => buildEgressOptions('INTERNAL'), Error, 'EGRESS_POLICY');
});

Deno.test('buildEgressOptions: INTERNAL with explicit host', () => {
  const hosts = new Set(['myproject.supabase.co']);
  const opts = buildEgressOptions('INTERNAL', hosts);
  assertEquals(opts.allowedHosts, hosts);
});

// ── buildEgressOptions: EXTERNAL_SIDE_EFFECT ─────────────────────────────────

Deno.test('buildEgressOptions: EXTERNAL_SIDE_EFFECT without hosts throws', () => {
  assertThrows(() => buildEgressOptions('EXTERNAL_SIDE_EFFECT'), Error, 'EGRESS_POLICY');
});

Deno.test('buildEgressOptions: EXTERNAL_SIDE_EFFECT with explicit host', () => {
  const hosts = new Set(['partner-api.example.com']);
  const opts = buildEgressOptions('EXTERNAL_SIDE_EFFECT', hosts);
  assertEquals(opts.allowedHosts, hosts);
});

// ── Timeout / size limits ─────────────────────────────────────────────────────

Deno.test('buildEgressOptions: timeouts match purpose risk', () => {
  const source = buildEgressOptions('PUBLIC_SOURCE_FETCH');
  const registry = buildEgressOptions('REGISTRY_QUERY');
  // Registry gets more time than public source fetch
  assertEquals(registry.timeoutMs! > source.timeoutMs!, true);
});

// ── validateEgressContentType ─────────────────────────────────────────────────

Deno.test('validateEgressContentType: allowed types for PUBLIC_SOURCE_FETCH', () => {
  assertEquals(validateEgressContentType('text/html; charset=utf-8', 'PUBLIC_SOURCE_FETCH'), null);
  assertEquals(validateEgressContentType('application/json', 'PUBLIC_SOURCE_FETCH'), null);
  assertEquals(validateEgressContentType('application/pdf', 'PUBLIC_SOURCE_FETCH'), null);
  assertEquals(validateEgressContentType('text/plain', 'PUBLIC_SOURCE_FETCH'), null);
  assertEquals(validateEgressContentType('text/csv', 'PUBLIC_SOURCE_FETCH'), null);
});

Deno.test('validateEgressContentType: disallowed type for PUBLIC_SOURCE_FETCH', () => {
  const err = validateEgressContentType('application/octet-stream', 'PUBLIC_SOURCE_FETCH');
  assertEquals(typeof err, 'string');
});

Deno.test('validateEgressContentType: missing content-type', () => {
  assertEquals(typeof validateEgressContentType(null, 'PUBLIC_SOURCE_FETCH'), 'string');
});

Deno.test('validateEgressContentType: image rejected for registry query', () => {
  const err = validateEgressContentType('image/png', 'REGISTRY_QUERY');
  assertEquals(typeof err, 'string');
});

// ── User-controlled destinations blocked for non-PUBLIC_SOURCE_FETCH ──────────

Deno.test('buildEgressOptions: user cannot widen REGISTRY_QUERY allowlist', () => {
  // This documents the invariant: passing hosts not in the registry set
  // must throw, preventing user-supplied URLs from becoming registry calls.
  assertThrows(
    () => buildEgressOptions('REGISTRY_QUERY', new Set(['user-controlled.example.com'])),
    Error,
  );
});
