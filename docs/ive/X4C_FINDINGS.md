# IVE-X4C Findings — SSRF Closure

## Inventory

Searched the entire `supabase/functions` tree on `main` @ `7795421` for
`fetch(`, `.url`, `webhook`, `redirect_url`, `callback_url`, `image_url`,
`website_url`, excluding the fixed, hardcoded `GROQ_URL`/`OPENAI_URL`
constants every function already uses safely.

| Function | User-controlled URL fetched server-side? | Prior validation |
|---|---|---|
| `analyze-website` | Yes — `body.url`, fetched directly | `url.startsWith("http")` only |
| `extract-knowledge` | Yes — `body.url` (or extracted Google Docs/Drive ID), generic branch fetches directly | none on the generic branch |
| All other 15 edge functions | No — no URL-shaped input found | n/a |

Both confirmed functions shared the identical unmitigated pattern IVE-X3
predicted others might: no private-IP blocking, no metadata-endpoint
blocking, `redirect: "follow"` with no re-validation of the final
destination.

## Threat model coverage

The shared helper (`supabase/functions/_shared/safe_fetch.ts`) implements
every item in the mission's threat list:

- loopback: `127.0.0.0/8` (IPv4), `::1` (IPv6)
- RFC1918: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`
- link-local incl. cloud metadata: `169.254.0.0/16` (covers
  `169.254.169.254`), `fe80::/10`
- unique-local IPv6: `fc00::/7` (covers AWS's `fd00:ec2::254` IPv6
  metadata address)
- multicast/reserved/benchmarking/documentation/carrier-NAT ranges:
  `224.0.0.0/4`, `240.0.0.0/4`, `198.18.0.0/15`, `192.0.2.0/24`,
  `198.51.100.0/24`, `203.0.113.0/24`, `100.64.0.0/10`, `2001:db8::/32`
- IPv4-mapped / NAT64 IPv6 (`::ffff:...`, `64:ff9b::...`): decoded and the
  embedded IPv4 address re-checked, not trusted as a wrapper
- non-http(s) schemes: `file://`, `ftp://`, anything not `http:`/`https:`
- userinfo tricks (`http://trusted@evil/`): rejected
- DNS-based SSRF (public-looking hostname resolving to a private IP):
  every `A`/`AAAA` record from `Deno.resolveDns` is validated, not just
  the hostname string
- redirects to a private target: followed **manually** (`redirect:
  "manual"`), every hop re-validated against the same rules, capped at 3
  hops

**Documented, not silently accepted, residual gap:** a theoretical
DNS-rebinding window between the `resolveDns` check and the actual
`fetch()` call a few milliseconds later — closing it fully would need
pinning the TCP connection to the exact validated IP, which requires a
raw-socket capability this codebase has no evidence the Supabase Edge
Runtime exposes. Every other item in the threat model is fully mitigated,
not partially.

Fail-closed throughout: an unparseable IP, a failed DNS resolution, or an
unavailable `Deno.resolveDns` all reject the request rather than silently
allow it.

## Tests — actually executed, not just written

Deno was not present in this environment; it was installed for this
session specifically to run these tests for real rather than assert they
would pass. Full transcript below is the genuine `deno test` output.

**First run: 19 passed, 1 failed.** The failure was real: the initial
`assertHostnameIsSafe` implementation ran the IPv4-literal blocklist check
(which fails closed on anything that doesn't parse as an IPv4 address) on
every hostname unconditionally — including plain domain names — so every
non-IP-literal hostname was rejected before DNS resolution ever ran. This
would have broken every legitimate public URL, not just malicious ones.
Fixed by branching cleanly on "is this hostname already a literal
IPv4/IPv6 address" before falling through to DNS resolution for anything
else. Re-ran: **20 passed, 0 failed.**

```
running 20 tests from ./supabase/functions/_shared/safe_fetch_test.ts
ALLOW: a representative public IPv4 address is not blocked ... ok
DENY: 127.0.0.1 (loopback) ... ok
DENY: 10.0.0.1 (RFC1918) ... ok
DENY: 192.168.1.1 (RFC1918) ... ok
DENY: 169.254.169.254 (link-local / cloud metadata) ... ok
DENY: ::1 (IPv6 loopback) ... ok
DENY: fe80::1 (IPv6 link-local) ... ok
DENY: fd00::1 (IPv6 unique-local, includes AWS's fd00:ec2::254 metadata) ... ok
DENY: IPv4-mapped IPv6 embedding a blocked address (::ffff:169.254.169.254) ... ok
DENY: NAT64-mapped IPv6 embedding a blocked address (64:ff9b::169.254.169.254) ... ok
isBlockedIp dispatches correctly by address family ... ok
ALLOW: https scheme ... ok
ALLOW: http scheme ... ok
DENY: file:// scheme ... ok
DENY: ftp:// scheme ... ok
DENY: userinfo trick (http://trusted@evil.example/) ... ok
DENY: http://localhost resolves via DNS to a blocked address ... ok
DENY: a public-looking hostname that resolves to a private IP (DNS-based SSRF) ... ok
DENY: a public URL that redirects to a private target is rejected at the redirect hop ... ok
ALLOW: a public URL resolving to a public IP succeeds ... ok

ok | 20 passed | 0 failed (28ms)
```

No test made a real network call against an actual external host or
metadata service — `Deno.resolveDns` and the global `fetch` are stubbed
for the duration of each DNS-/redirect-dependent test only, then restored.

`deno check` and `deno lint` both pass clean on `safe_fetch.ts`,
`safe_fetch_test.ts`, and the two patched `index.ts` files.

## Patches applied (this branch only, not deployed)

- `analyze-website/index.ts`, `extract-knowledge/index.ts`: `fetch(` →
  `safeFetch(`, `UnsafeUrlError` mapped to a generic user-facing message
  that reveals nothing about the internal validation reasoning.
- No other function was touched. `extract-knowledge`'s Google
  Docs/Drive-specific branches were routed through `safeFetch` too for
  consistency even though their target host is fixed
  (`docs.google.com`/`drive.google.com`, not attacker-controlled) — lower
  priority, zero behavior change expected since Google's IPs are public.
