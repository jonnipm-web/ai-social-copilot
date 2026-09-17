/**
 * Schema/validator parity tests (Codex adversarial review, round 3,
 * Finding N-03).
 *
 * validators.ts is the enforced runtime boundary, but README.md also
 * describes the JSON Schemas under schema/ as the "canonical,
 * language-agnostic source of truth." Round 3 found that a
 * schema-ONLY implementation (validating against the JSON Schema alone,
 * with no TypeScript validator involved) could still accept inputs the
 * validator rejects -- specifically the Finding F-01 homoglyph bypass and
 * the Finding F-02 degenerate auth_ref values, because those restrictions
 * only lived in validators.ts/prohibited_fields.ts, not in the schema
 * itself. This file exercises the schemas directly with a generic JSON
 * Schema validator (ajv), independent of validators.ts, to prove the
 * schema alone now enforces the same restrictions -- not merely that our
 * own hand-written validator does.
 */
import AjvModule from "npm:ajv@8";
import addFormatsModule from "npm:ajv-formats@2";
import { assert, assertFalse } from "https://deno.land/std@0.224.0/assert/mod.ts";

// deno's type resolution for these packages' default exports lacks a
// construct/call signature even though they work fine at runtime -- cast
// at the boundary rather than fight the npm compat shim's .d.ts.
// deno-lint-ignore no-explicit-any
const Ajv = AjvModule as any;
// deno-lint-ignore no-explicit-any
const addFormats = addFormatsModule as any;

const execRequestSchema = JSON.parse(
  await Deno.readTextFile(new URL("./schema/execution-request.v1.schema.json", import.meta.url)),
);
const delegationSchema = JSON.parse(
  await Deno.readTextFile(new URL("./schema/delegation-envelope.v1.schema.json", import.meta.url)),
);

const ajv = new Ajv({ allErrors: true, strict: false });
addFormats(ajv);
const validateRequest = ajv.compile(execRequestSchema);
ajv.addSchema(delegationSchema, "delegation-envelope.v1.schema.json");
const validateDelegation = ajv.getSchema("delegation-envelope.v1.schema.json")!;

function baseRequest(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    contract_version: "1.0",
    request_id: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
    requested_at: "2026-09-18T11:55:00.000Z",
    expires_at: "2027-01-01T00:00:00.000Z",
    actor: { type: "user", id: "user-42", auth_ref: "usr:session-abc123" },
    intent: "test",
    domain: "core",
    action: "core.generate_strategy",
    ...overrides,
  };
}

Deno.test("schema parity: baseline valid request passes the schema alone", () => {
  assert(validateRequest(baseRequest()), `schema rejected a baseline-valid request: ${JSON.stringify(validateRequest.errors)}`);
});

Deno.test("schema parity (N-03/F-01): homoglyph key at parameters top level is rejected by the schema alone", () => {
  const v = baseRequest({ parameters: { ["pаid"]: true } });
  assertFalse(validateRequest(v), "schema must reject a Cyrillic-homoglyph key in parameters");
});

Deno.test("schema parity (N-03/F-01): homoglyph key nested inside parameters is rejected by the schema alone (recursion)", () => {
  const v = baseRequest({ parameters: { nested: { ["rаle"]: "admin" } } });
  assertFalse(validateRequest(v), "schema must reject a Cyrillic-homoglyph key nested inside parameters");
});

Deno.test("schema parity: legitimate nested ASCII parameters are accepted by the schema alone", () => {
  const v = baseRequest({ parameters: { nested: { topic: "quarterly report" }, list: [1, 2, { ok: true }] } });
  assert(validateRequest(v), `schema rejected legitimate nested ASCII parameters: ${JSON.stringify(validateRequest.errors)}`);
});

Deno.test("schema parity (N-03/F-01): homoglyph key in metadata is rejected by the schema alone", () => {
  const v = baseRequest({ metadata: { ["pаid"]: "x" } });
  assertFalse(validateRequest(v), "schema must reject a Cyrillic-homoglyph key in metadata");
});

Deno.test("schema parity (N-03/F-02): degenerate service auth_ref is rejected by the schema alone", () => {
  const v = baseRequest({ actor: { type: "service", id: "svc-x", auth_ref: "svc:x" } });
  assertFalse(validateRequest(v), "schema must reject a near-empty service auth_ref suffix");
});

Deno.test("schema parity (N-03/F-02): degenerate user auth_ref is rejected by the schema alone", () => {
  const v = baseRequest({ actor: { type: "user", id: "u1", auth_ref: "usr:a" } });
  assertFalse(validateRequest(v), "schema must reject a near-empty user auth_ref suffix");
});

Deno.test("schema parity (N-03/F-02): substantive auth_ref is accepted by the schema alone", () => {
  const v = baseRequest({ actor: { type: "service", id: "svc-x", auth_ref: "svc:ive-core" } });
  assert(validateRequest(v), `schema rejected a substantive service auth_ref: ${JSON.stringify(validateRequest.errors)}`);
});

Deno.test("schema parity: system actor requires the exact 'system:internal' literal", () => {
  const good = baseRequest({ actor: { type: "system", id: "sys", auth_ref: "system:internal" } });
  assert(validateRequest(good), `schema rejected system:internal: ${JSON.stringify(validateRequest.errors)}`);
  const bad = baseRequest({ actor: { type: "system", id: "sys", auth_ref: "system:other" } });
  assertFalse(validateRequest(bad), "schema must reject a non-canonical system auth_ref literal");
});

Deno.test("schema parity (N-03/F-02): delegation issuer with a degenerate auth_ref is rejected by the schema alone (cross-file $ref)", () => {
  const d = {
    contract_version: "1.0",
    delegation_id: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeef",
    issuer: { type: "service", id: "ive", auth_ref: "svc:x" },
    subject: { type: "user", id: "user-42", auth_ref: "usr:session-abc123" },
    audience: "aef.core",
    issued_at: "2026-09-18T11:55:00.000Z",
    expires_at: "2027-01-01T00:00:00.000Z",
    nonce: "nonce-1111111111111111",
    purpose: "test",
    scope: ["core.generate_strategy"],
    request_binding: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
    auth_assertion_ref: "ref-1",
  };
  assertFalse(validateDelegation(d), "schema must reject a delegation issuer with a degenerate auth_ref, via the shared Actor $ref");
});
