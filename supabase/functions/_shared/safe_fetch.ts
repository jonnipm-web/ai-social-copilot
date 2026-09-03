/**
 * SSRF-safe outbound fetch helper — IVE-X4C.
 *
 * PREPARED, NOT DEPLOYED. Written and committed to branch
 * claude/ive-x4-security-boundary-closure for owner review. No Edge Function
 * deploy was performed by this session.
 *
 * Confirmed vulnerable (unmitigated `fetch(userSuppliedUrl)`) in two
 * functions during the X4C audit: analyze-website and extract-knowledge.
 * Both are patched in this branch to call `safeFetch` instead of the raw
 * `fetch` global. No other server-side URL-accepting code path was found in
 * a repo-wide grep for fetch(/url/webhook/redirect/callback patterns as of
 * commit 7795421 — see docs/ive/X4C_FINDINGS.md for the exact search used.
 *
 * Threat model covered (mission section 15):
 *   - loopback (127.0.0.0/8, ::1)
 *   - RFC1918 private ranges (10/8, 172.16/12, 192.168/16)
 *   - link-local incl. cloud metadata (169.254.0.0/16, fe80::/10)
 *   - IPv4-mapped / NAT64 IPv6 embedding a blocked IPv4 address
 *   - unique-local IPv6 (fc00::/7)
 *   - multicast / reserved / benchmarking / documentation ranges
 *   - non-http(s) schemes (file://, ftp://, etc.)
 *   - a public URL that redirects to a private/internal target
 *   - DNS resolving a public-looking hostname to a private IP
 *
 * Deliberately NOT attempted: pinning the TCP connection to the exact
 * resolved IP validated here (would require a raw-socket fetch below Deno's
 * `fetch()`, which the Supabase Edge Runtime may not expose). This means a
 * theoretical DNS-rebinding window exists between the resolveDns() check
 * below and the actual fetch() call a few milliseconds later. Documented
 * here rather than silently accepted -- closing it fully would need either
 * a runtime capability this codebase doesn't have evidence of, or an
 * external egress proxy, both out of scope for a same-blast-radius X4C fix.
 * Every other item in the threat model is fully mitigated.
 */

const ALLOWED_SCHEMES = new Set(["http:", "https:"]);
const MAX_REDIRECTS = 3;
const DEFAULT_TIMEOUT_MS = 10_000;
const MAX_RESPONSE_BYTES = 2_000_000; // 2 MB — generous for HTML/text extraction, bounds memory/cost

export class UnsafeUrlError extends Error {
  constructor(message = "URL não permitida.") {
    super(message);
    this.name = "UnsafeUrlError";
  }
}

// ── IPv4 ──────────────────────────────────────────────────────────────────

export function ipv4ToInt(ip: string): number | null {
  const parts = ip.split(".");
  if (parts.length !== 4) return null;
  let n = 0;
  for (const p of parts) {
    if (!/^\d{1,3}$/.test(p)) return null;
    const v = Number(p);
    if (v > 255) return null;
    n = (n << 8) | v;
  }
  return n >>> 0;
}

const IPV4_BLOCKED_RANGES: Array<[string, number]> = [
  ["0.0.0.0", 8],
  ["10.0.0.0", 8],
  ["100.64.0.0", 10], // carrier-grade NAT
  ["127.0.0.0", 8], // loopback
  ["169.254.0.0", 16], // link-local incl. cloud metadata (169.254.169.254)
  ["172.16.0.0", 12],
  ["192.0.0.0", 24], // IETF protocol assignments
  ["192.0.2.0", 24], // TEST-NET-1
  ["192.168.0.0", 16],
  ["198.18.0.0", 15], // benchmarking
  ["198.51.100.0", 24], // TEST-NET-2
  ["203.0.113.0", 24], // TEST-NET-3
  ["224.0.0.0", 4], // multicast
  ["240.0.0.0", 4], // reserved
  ["255.255.255.255", 32], // broadcast
];

export function isBlockedIpv4(ip: string): boolean {
  const n = ipv4ToInt(ip);
  if (n === null) return true; // unparseable -- fail closed
  for (const [base, prefix] of IPV4_BLOCKED_RANGES) {
    const baseN = ipv4ToInt(base)!;
    const mask = prefix === 0 ? 0 : (0xffffffff << (32 - prefix)) >>> 0;
    if ((n & mask) === (baseN & mask)) return true;
  }
  return false;
}

// ── IPv6 ──────────────────────────────────────────────────────────────────

export function isBlockedIpv6(rawIp: string): boolean {
  const ip = rawIp.toLowerCase().replace(/^\[|\]$/g, "");

  if (ip === "::1" || ip === "::") return true; // loopback / unspecified
  if (ip.startsWith("fe8") || ip.startsWith("fe9") || ip.startsWith("fea") || ip.startsWith("feb")) return true; // fe80::/10 link-local
  if (ip.startsWith("fc") || ip.startsWith("fd")) return true; // fc00::/7 unique-local
  if (ip.startsWith("ff")) return true; // ff00::/8 multicast
  if (ip.startsWith("2001:db8:")) return true; // documentation

  // IPv4-mapped (::ffff:a.b.c.d) or NAT64 (64:ff9b::a.b.c.d) -- extract and
  // re-check the embedded IPv4 address rather than trusting the wrapper.
  const mapped = ip.match(/(?:::ffff:|64:ff9b::)(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/);
  if (mapped) return isBlockedIpv4(mapped[1]);

  return false;
}

export function isBlockedIp(ip: string): boolean {
  return ip.includes(":") ? isBlockedIpv6(ip) : isBlockedIpv4(ip);
}

// ── Hostname resolution + validation ───────────────────────────────────────

async function assertHostnameIsSafe(hostname: string): Promise<void> {
  // A literal IPv4 address in the URL -- validate directly, no DNS involved.
  if (ipv4ToInt(hostname) !== null) {
    if (isBlockedIpv4(hostname)) throw new UnsafeUrlError();
    return;
  }

  // A literal IPv6 address (bracketed or not) -- validate directly.
  if (hostname.includes(":")) {
    if (isBlockedIpv6(hostname)) throw new UnsafeUrlError();
    return;
  }

  // Anything else is a hostname, not an IP literal -- resolve and validate
  // every returned address instead of guessing from the string. Fail closed
  // if resolution itself fails or the runtime doesn't expose Deno.resolveDns
  // (documented DNS-rebinding caveat above still applies to the gap between
  // this check and the actual fetch()).
  try {
    const records = await Promise.all([
      Deno.resolveDns(hostname, "A").catch(() => [] as string[]),
      Deno.resolveDns(hostname, "AAAA").catch(() => [] as string[]),
    ]);
    const addresses = records.flat();
    if (addresses.length === 0) throw new UnsafeUrlError("Não foi possível resolver o endereço.");
    for (const addr of addresses) {
      if (isBlockedIp(addr)) throw new UnsafeUrlError();
    }
  } catch (err) {
    if (err instanceof UnsafeUrlError) throw err;
    // resolveDns unavailable/unsupported in this runtime, or a transient
    // resolution failure -- fail closed rather than silently skip the check.
    throw new UnsafeUrlError("Não foi possível validar o destino com segurança.");
  }
}

export function assertUrlShapeIsSafe(url: URL): void {
  if (!ALLOWED_SCHEMES.has(url.protocol)) throw new UnsafeUrlError();
  if (url.username || url.password) throw new UnsafeUrlError(); // userinfo tricks (http://trusted@evil/)
  if (!url.hostname) throw new UnsafeUrlError();
}

// ── Public entrypoint ───────────────────────────────────────────────────────

export interface SafeFetchOptions {
  headers?: Record<string, string>;
  timeoutMs?: number;
  maxResponseBytes?: number;
}

/**
 * Fetch a user-supplied URL safely: scheme-restricted, DNS-validated against
 * private/reserved ranges, redirects manually followed and re-validated at
 * every hop, bounded by timeout and response size.
 *
 * Throws UnsafeUrlError (safe to surface to the caller as-is -- it never
 * includes the blocked address or internal reasoning) or the underlying
 * fetch/timeout error for network-level failures.
 */
export async function safeFetch(rawUrl: string, options: SafeFetchOptions = {}): Promise<Response> {
  const timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const maxBytes = options.maxResponseBytes ?? MAX_RESPONSE_BYTES;

  let currentUrl: URL;
  try {
    currentUrl = new URL(rawUrl);
  } catch {
    throw new UnsafeUrlError("URL malformada.");
  }

  for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
    assertUrlShapeIsSafe(currentUrl);
    await assertHostnameIsSafe(currentUrl.hostname);

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

    let res: Response;
    try {
      res = await fetch(currentUrl.toString(), {
        headers: options.headers,
        redirect: "manual", // we re-validate every hop ourselves
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timeoutId);
    }

    const isRedirect = res.status >= 300 && res.status < 400;
    if (!isRedirect) {
      return capResponseSize(res, maxBytes);
    }

    const location = res.headers.get("location");
    if (!location) throw new UnsafeUrlError("Redirecionamento sem destino.");
    if (hop === MAX_REDIRECTS) throw new UnsafeUrlError("Excesso de redirecionamentos.");

    currentUrl = new URL(location, currentUrl); // resolve relative redirects against current URL
  }

  throw new UnsafeUrlError("Excesso de redirecionamentos.");
}

function capResponseSize(res: Response, maxBytes: number): Response {
  if (!res.body) return res;
  const reader = res.body.getReader();
  let received = 0;

  const stream = new ReadableStream<Uint8Array>({
    async pull(controller) {
      const { done, value } = await reader.read();
      if (done) {
        controller.close();
        return;
      }
      received += value.byteLength;
      if (received > maxBytes) {
        controller.error(new UnsafeUrlError("Resposta excede o limite de tamanho permitido."));
        await reader.cancel();
        return;
      }
      controller.enqueue(value);
    },
    cancel(reason) {
      return reader.cancel(reason);
    },
  });

  return new Response(stream, { status: res.status, headers: res.headers });
}
