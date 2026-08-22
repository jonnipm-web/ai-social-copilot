// SEC-01 SSRF test suite — isPrivateIp + URL/hostname validation
// Run: deno test --allow-env supabase/functions/analyze-website/ssrf_test.ts

import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";

// ─── Functions under test (inlined — same logic as index.ts) ─────────────────

export function isPrivateIp(ip: string): boolean {
  const v4 = ip.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (v4) {
    const [, a, b, c] = v4.map(Number);
    if (a === 0)   return true;
    if (a === 10)  return true;
    if (a === 100 && b >= 64 && b <= 127) return true;
    if (a === 127) return true;
    if (a === 169 && b === 254) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 192 && b === 0 && c === 0) return true;
    if (a === 192 && b === 168) return true;
    if (a === 198 && (b === 18 || b === 19)) return true;
    if (a >= 224) return true;
    return false;
  }
  const lc = ip.toLowerCase().replace(/^\[|\]$/g, "");
  if (lc === "::1" || lc === "::" || lc === "0:0:0:0:0:0:0:0" || lc === "0:0:0:0:0:0:0:1") return true;
  if (/^fe[89ab][0-9a-f]:/.test(lc)) return true;
  if (/^fc|^fd/.test(lc)) return true;
  if (/^ff/.test(lc)) return true;
  if (lc.startsWith("::ffff:")) return isPrivateIp(lc.slice(7));
  if (lc.startsWith("::ffff:0:")) return isPrivateIp(lc.slice(9));
  if (lc.startsWith("64:ff9b::")) return isPrivateIp(lc.slice(9));
  return false;
}

function validateUrlProtocol(rawUrl: string): URL {
  let parsed: URL;
  try {
    parsed = new URL(rawUrl);
  } catch {
    throw new Error("URL inválida.");
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new Error("Protocolo não permitido.");
  }
  return parsed;
}

function validateHostname(hostname: string): void {
  const lc = hostname.toLowerCase();
  if (lc === "localhost" || lc === "0.0.0.0") throw new Error("Host privado.");
  if (!lc.includes(".") && !lc.startsWith("[")) throw new Error("Hostname sem TLD.");
  if (["169.254.169.254", "metadata.google.internal", "metadata.internal"].includes(lc)) {
    throw new Error("Metadados de nuvem.");
  }
  if (/^[\d.:]+$/.test(lc) && isPrivateIp(lc)) {
    throw new Error("IP privado.");
  }
}

// ─── isPrivateIp: IPv4 ────────────────────────────────────────────────────────

Deno.test("isPrivateIp: 127.0.0.1 = loopback", () => {
  assertEquals(isPrivateIp("127.0.0.1"), true);
});

Deno.test("isPrivateIp: 127.255.255.255 = loopback range", () => {
  assertEquals(isPrivateIp("127.255.255.255"), true);
});

Deno.test("isPrivateIp: 0.0.0.0 = unspecified", () => {
  assertEquals(isPrivateIp("0.0.0.0"), true);
});

Deno.test("isPrivateIp: 10.0.0.1 = RFC-1918", () => {
  assertEquals(isPrivateIp("10.0.0.1"), true);
});

Deno.test("isPrivateIp: 10.255.255.255 = RFC-1918", () => {
  assertEquals(isPrivateIp("10.255.255.255"), true);
});

Deno.test("isPrivateIp: 172.16.0.1 = RFC-1918", () => {
  assertEquals(isPrivateIp("172.16.0.1"), true);
});

Deno.test("isPrivateIp: 172.31.255.255 = RFC-1918", () => {
  assertEquals(isPrivateIp("172.31.255.255"), true);
});

Deno.test("isPrivateIp: 172.15.0.1 = public (NOT private)", () => {
  assertEquals(isPrivateIp("172.15.0.1"), false);
});

Deno.test("isPrivateIp: 172.32.0.1 = public (NOT private)", () => {
  assertEquals(isPrivateIp("172.32.0.1"), false);
});

Deno.test("isPrivateIp: 192.168.0.1 = RFC-1918", () => {
  assertEquals(isPrivateIp("192.168.0.1"), true);
});

Deno.test("isPrivateIp: 192.167.0.1 = public", () => {
  assertEquals(isPrivateIp("192.167.0.1"), false);
});

Deno.test("isPrivateIp: 169.254.169.254 = cloud metadata / link-local", () => {
  assertEquals(isPrivateIp("169.254.169.254"), true);
});

Deno.test("isPrivateIp: 169.254.0.1 = link-local", () => {
  assertEquals(isPrivateIp("169.254.0.1"), true);
});

Deno.test("isPrivateIp: 100.64.0.1 = CGNAT", () => {
  assertEquals(isPrivateIp("100.64.0.1"), true);
});

Deno.test("isPrivateIp: 100.127.255.255 = CGNAT", () => {
  assertEquals(isPrivateIp("100.127.255.255"), true);
});

Deno.test("isPrivateIp: 100.128.0.1 = public (outside CGNAT)", () => {
  assertEquals(isPrivateIp("100.128.0.1"), false);
});

Deno.test("isPrivateIp: 224.0.0.1 = multicast", () => {
  assertEquals(isPrivateIp("224.0.0.1"), true);
});

Deno.test("isPrivateIp: 255.255.255.255 = broadcast/reserved", () => {
  assertEquals(isPrivateIp("255.255.255.255"), true);
});

Deno.test("isPrivateIp: 8.8.8.8 = public (Google DNS)", () => {
  assertEquals(isPrivateIp("8.8.8.8"), false);
});

Deno.test("isPrivateIp: 1.1.1.1 = public (Cloudflare DNS)", () => {
  assertEquals(isPrivateIp("1.1.1.1"), false);
});

// ─── isPrivateIp: IPv6 ────────────────────────────────────────────────────────

Deno.test("isPrivateIp: ::1 = IPv6 loopback", () => {
  assertEquals(isPrivateIp("::1"), true);
});

Deno.test("isPrivateIp: :: = IPv6 unspecified", () => {
  assertEquals(isPrivateIp("::"), true);
});

Deno.test("isPrivateIp: fc00::1 = ULA", () => {
  assertEquals(isPrivateIp("fc00::1"), true);
});

Deno.test("isPrivateIp: fd12:3456::1 = ULA", () => {
  assertEquals(isPrivateIp("fd12:3456::1"), true);
});

Deno.test("isPrivateIp: fe80::1 = link-local", () => {
  assertEquals(isPrivateIp("fe80::1"), true);
});

Deno.test("isPrivateIp: ff02::1 = multicast", () => {
  assertEquals(isPrivateIp("ff02::1"), true);
});

// ─── isPrivateIp: IPv4-mapped IPv6 ───────────────────────────────────────────

Deno.test("isPrivateIp: ::ffff:10.0.0.1 = IPv4-mapped private", () => {
  assertEquals(isPrivateIp("::ffff:10.0.0.1"), true);
});

Deno.test("isPrivateIp: ::ffff:192.168.1.1 = IPv4-mapped private", () => {
  assertEquals(isPrivateIp("::ffff:192.168.1.1"), true);
});

Deno.test("isPrivateIp: ::ffff:8.8.8.8 = IPv4-mapped public", () => {
  assertEquals(isPrivateIp("::ffff:8.8.8.8"), false);
});

Deno.test("isPrivateIp: ::ffff:169.254.169.254 = metadata via IPv6", () => {
  assertEquals(isPrivateIp("::ffff:169.254.169.254"), true);
});

// ─── validateUrlProtocol ──────────────────────────────────────────────────────

Deno.test("validateUrlProtocol: rejects file:// protocol", () => {
  assertThrows(
    () => validateUrlProtocol("file:///etc/passwd"),
    Error,
    "Protocolo",
  );
});

Deno.test("validateUrlProtocol: rejects ftp:// protocol", () => {
  assertThrows(
    () => validateUrlProtocol("ftp://example.com"),
    Error,
    "Protocolo",
  );
});

Deno.test("validateUrlProtocol: rejects data: URI", () => {
  assertThrows(
    () => validateUrlProtocol("data:text/html,<script>alert(1)</script>"),
    Error,
    "Protocolo",
  );
});

Deno.test("validateUrlProtocol: rejects malformed URL", () => {
  assertThrows(
    () => validateUrlProtocol("not-a-url"),
    Error,
    "URL inválida",
  );
});

Deno.test("validateUrlProtocol: accepts https://", () => {
  const parsed = validateUrlProtocol("https://example.com");
  assertEquals(parsed.hostname, "example.com");
});

Deno.test("validateUrlProtocol: accepts http://", () => {
  const parsed = validateUrlProtocol("http://example.com");
  assertEquals(parsed.hostname, "example.com");
});

// ─── validateHostname ─────────────────────────────────────────────────────────

Deno.test("validateHostname: rejects localhost", () => {
  assertThrows(
    () => validateHostname("localhost"),
    Error,
    "privado",
  );
});

Deno.test("validateHostname: rejects LOCALHOST (case-insensitive)", () => {
  assertThrows(
    () => validateHostname("LOCALHOST"),
    Error,
  );
});

Deno.test("validateHostname: rejects 0.0.0.0", () => {
  assertThrows(
    () => validateHostname("0.0.0.0"),
    Error,
  );
});

Deno.test("validateHostname: rejects bare hostname without TLD", () => {
  assertThrows(
    () => validateHostname("internal"),
    Error,
    "TLD",
  );
});

Deno.test("validateHostname: rejects metadata.google.internal", () => {
  assertThrows(
    () => validateHostname("metadata.google.internal"),
    Error,
    "Metadados",
  );
});

Deno.test("validateHostname: rejects metadata.internal", () => {
  assertThrows(
    () => validateHostname("metadata.internal"),
    Error,
  );
});

Deno.test("validateHostname: rejects 169.254.169.254 as IP literal", () => {
  assertThrows(
    () => validateHostname("169.254.169.254"),
    Error,
  );
});

Deno.test("validateHostname: rejects 10.0.0.1 as IP literal", () => {
  assertThrows(
    () => validateHostname("10.0.0.1"),
    Error,
  );
});

Deno.test("validateHostname: rejects 192.168.1.1 as IP literal", () => {
  assertThrows(
    () => validateHostname("192.168.1.1"),
    Error,
  );
});
