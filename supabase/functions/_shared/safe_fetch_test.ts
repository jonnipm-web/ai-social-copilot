/**
 * IVE-X4C SSRF test suite.
 *
 * No test in this file makes a real network call against an actual metadata
 * service or any external host. Pure-function tests exercise the IP/scheme
 * validators directly. The two DNS-dependent and one redirect-dependent
 * tests stub `Deno.resolveDns` / the global `fetch` for the duration of the
 * test only, then restore them -- never a live call.
 *
 * Run with: deno test --allow-env supabase/functions/_shared/safe_fetch_test.ts
 */
import { assert, assertEquals, assertRejects } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  assertUrlShapeIsSafe,
  isBlockedIp,
  isBlockedIpv4,
  isBlockedIpv6,
  safeFetch,
  UnsafeUrlError,
} from "./safe_fetch.ts";

// ── Mission's required matrix — pure IP/scheme checks, no network ──────────

Deno.test("ALLOW: a representative public IPv4 address is not blocked", () => {
  assertEquals(isBlockedIpv4("93.184.216.34"), false); // example.com's public IP
});

Deno.test("DENY: 127.0.0.1 (loopback)", () => {
  assertEquals(isBlockedIpv4("127.0.0.1"), true);
});

Deno.test("DENY: 10.0.0.1 (RFC1918)", () => {
  assertEquals(isBlockedIpv4("10.0.0.1"), true);
});

Deno.test("DENY: 192.168.1.1 (RFC1918)", () => {
  assertEquals(isBlockedIpv4("192.168.1.1"), true);
});

Deno.test("DENY: 169.254.169.254 (link-local / cloud metadata)", () => {
  assertEquals(isBlockedIpv4("169.254.169.254"), true);
});

Deno.test("DENY: ::1 (IPv6 loopback)", () => {
  assertEquals(isBlockedIpv6("::1"), true);
  assertEquals(isBlockedIpv6("[::1]"), true);
});

Deno.test("DENY: fe80::1 (IPv6 link-local)", () => {
  assertEquals(isBlockedIpv6("fe80::1"), true);
});

Deno.test("DENY: fd00::1 (IPv6 unique-local, includes AWS's fd00:ec2::254 metadata)", () => {
  assertEquals(isBlockedIpv6("fd00:ec2::254"), true);
});

Deno.test("DENY: IPv4-mapped IPv6 embedding a blocked address (::ffff:169.254.169.254)", () => {
  assertEquals(isBlockedIpv6("::ffff:169.254.169.254"), true);
});

Deno.test("DENY: NAT64-mapped IPv6 embedding a blocked address (64:ff9b::169.254.169.254)", () => {
  assertEquals(isBlockedIpv6("64:ff9b::169.254.169.254"), true);
});

Deno.test("isBlockedIp dispatches correctly by address family", () => {
  assertEquals(isBlockedIp("10.0.0.1"), true);
  assertEquals(isBlockedIp("8.8.8.8"), false);
  assertEquals(isBlockedIp("::1"), true);
});

// ── Scheme / URL-shape checks ────────────────────────────────────────────

Deno.test("ALLOW: https scheme", () => {
  assertUrlShapeIsSafe(new URL("https://example.com/page"));
});

Deno.test("ALLOW: http scheme", () => {
  assertUrlShapeIsSafe(new URL("http://example.com/page"));
});

Deno.test("DENY: file:// scheme", () => {
  let threw = false;
  try {
    assertUrlShapeIsSafe(new URL("file:///etc/passwd"));
  } catch (e) {
    threw = e instanceof UnsafeUrlError;
  }
  assert(threw, "file:// must be rejected");
});

Deno.test("DENY: ftp:// scheme", () => {
  let threw = false;
  try {
    assertUrlShapeIsSafe(new URL("ftp://example.com/file"));
  } catch (e) {
    threw = e instanceof UnsafeUrlError;
  }
  assert(threw, "ftp:// must be rejected");
});

Deno.test("DENY: userinfo trick (http://trusted@evil.example/)", () => {
  let threw = false;
  try {
    assertUrlShapeIsSafe(new URL("http://trusted@evil.example/"));
  } catch (e) {
    threw = e instanceof UnsafeUrlError;
  }
  assert(threw, "embedded userinfo must be rejected");
});

// ── DNS-dependent and redirect-dependent cases — stubbed, no live calls ──

function stubDns(records: Record<string, { A?: string[]; AAAA?: string[] }>) {
  const original = Deno.resolveDns;
  // deno-lint-ignore no-explicit-any
  (Deno as any).resolveDns = (hostname: string, type: "A" | "AAAA") => {
    const entry = records[hostname];
    if (!entry) return Promise.reject(new Error("NXDOMAIN"));
    return Promise.resolve(type === "A" ? entry.A ?? [] : entry.AAAA ?? []);
  };
  return () => {
    // deno-lint-ignore no-explicit-any
    (Deno as any).resolveDns = original;
  };
}

function stubFetch(handler: (url: string) => Response) {
  const original = globalThis.fetch;
  globalThis.fetch = ((url: string | URL) => Promise.resolve(handler(url.toString()))) as typeof fetch;
  return () => {
    globalThis.fetch = original;
  };
}

Deno.test("DENY: http://localhost resolves via DNS to a blocked address", async () => {
  const restoreDns = stubDns({ localhost: { A: ["127.0.0.1"] } });
  const restoreFetch = stubFetch(() => new Response("should never be reached"));
  try {
    await assertRejects(() => safeFetch("http://localhost/"), UnsafeUrlError);
  } finally {
    restoreDns();
    restoreFetch();
  }
});

Deno.test("DENY: a public-looking hostname that resolves to a private IP (DNS-based SSRF)", async () => {
  const restoreDns = stubDns({ "attacker-controlled.example": { A: ["169.254.169.254"] } });
  const restoreFetch = stubFetch(() => new Response("should never be reached"));
  try {
    await assertRejects(() => safeFetch("http://attacker-controlled.example/"), UnsafeUrlError);
  } finally {
    restoreDns();
    restoreFetch();
  }
});

Deno.test("DENY: a public URL that redirects to a private target is rejected at the redirect hop", async () => {
  const restoreDns = stubDns({
    "public.example": { A: ["93.184.216.34"] },
    "internal.example": { A: ["10.0.0.5"] },
  });
  const restoreFetch = stubFetch((url) => {
    if (url === "http://public.example/") {
      return new Response(null, { status: 302, headers: { location: "http://internal.example/secret" } });
    }
    return new Response("should never be reached from the private hop");
  });
  try {
    await assertRejects(() => safeFetch("http://public.example/"), UnsafeUrlError);
  } finally {
    restoreDns();
    restoreFetch();
  }
});

Deno.test("ALLOW: a public URL resolving to a public IP succeeds", async () => {
  const restoreDns = stubDns({ "public.example": { A: ["93.184.216.34"] } });
  const restoreFetch = stubFetch((url) => {
    assertEquals(url, "http://public.example/");
    return new Response("ok content", { status: 200 });
  });
  try {
    const res = await safeFetch("http://public.example/");
    assertEquals(res.status, 200);
    assertEquals(await res.text(), "ok content");
  } finally {
    restoreDns();
    restoreFetch();
  }
});
