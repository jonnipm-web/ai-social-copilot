import { assert, assertEquals } from "jsr:@std/assert@1";
import { canonicalJson, sha256Hex } from "./canonical.ts";
import { MAX_PAYLOAD_BYTES } from "./limits.ts";

function json(v: unknown): string {
  const r = canonicalJson(v);
  assert(r.ok, JSON.stringify(r));
  return r.json;
}
function code(v: unknown): string {
  const r = canonicalJson(v);
  assert(!r.ok, `expected rejection for ${String(v)}`);
  return r.code;
}

Deno.test("CJ-01 key order does not change the canonical form; nested keys are sorted too", () => {
  assertEquals(json({ b: 1, a: { d: [1, 2], c: null } }), '{"a":{"c":null,"d":[1,2]},"b":1}');
  assertEquals(json({ a: { c: null, d: [1, 2] }, b: 1 }), json({ b: 1, a: { d: [1, 2], c: null } }));
});

Deno.test("CJ-02 array order is significant; -0 becomes 0; strings are not normalized", () => {
  assert(json([1, 2]) !== json([2, 1]));
  assertEquals(json({ x: -0 }), '{"x":0}');
  // NFC vs NFD "e with acute": two different payloads must not share one approval.
  assert(json("\u00e9") !== json("e\u0301"));
});

Deno.test("CJ-03 non-JSON values are rejected, never coerced", () => {
  assertEquals(code({ x: undefined }), "PAYLOAD_INVALID");
  assertEquals(code({ x: NaN }), "PAYLOAD_INVALID");
  assertEquals(code({ x: Infinity }), "PAYLOAD_INVALID");
  assertEquals(code({ x: 1n }), "PAYLOAD_INVALID");
  assertEquals(code({ x: () => 1 }), "PAYLOAD_INVALID");
  assertEquals(code({ x: Symbol("s") }), "PAYLOAD_INVALID");
  assertEquals(code({ x: new Date(0) }), "PAYLOAD_INVALID");
  assertEquals(code({ x: new Map() }), "PAYLOAD_INVALID");
  assertEquals(code({ x: "\ud800" }), "PAYLOAD_INVALID");
  assertEquals(code({ ["\udc00"]: 1 }), "PAYLOAD_INVALID");
});

Deno.test("CJ-04 depth, node count and byte size are bounded", () => {
  let deep: unknown = 1;
  for (let i = 0; i < 12; i++) deep = { d: deep };
  assertEquals(code(deep), "PAYLOAD_TOO_LARGE");
  assertEquals(code(Array.from({ length: 2_000 }, () => 0)), "PAYLOAD_TOO_LARGE");
  assertEquals(code({ s: "x".repeat(MAX_PAYLOAD_BYTES) }), "PAYLOAD_TOO_LARGE");
  const fits = canonicalJson({ s: "x".repeat(MAX_PAYLOAD_BYTES - 10) });
  assert(fits.ok && fits.bytes <= MAX_PAYLOAD_BYTES);
  // Multi-byte characters are counted in UTF-8 bytes, not code units.
  assertEquals(code({ s: "\u00e9".repeat(MAX_PAYLOAD_BYTES / 2) }), "PAYLOAD_TOO_LARGE");
});

Deno.test("CJ-05 sha256Hex matches the standard test vector and is stable", async () => {
  assertEquals(await sha256Hex("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
  assertEquals(await sha256Hex(json({ b: 2, a: 1 })), await sha256Hex(json({ a: 1, b: 2 })));
});
