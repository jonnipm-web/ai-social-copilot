# Impact Egress Security

**Mission:** IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01  
**File:** `supabase/functions/_shared/impact/egress_policy.ts`

## Threat Model

Impact functions make outbound HTTP requests to:
1. User-submitted URLs (source documents)
2. Known registries (Companies House, IRS, Charity Commission)
3. Internal Supabase services
4. External systems for consequential actions (future)

Without egress pinning, a compromised user input could trigger SSRF (Server-Side Request Forgery), causing the backend to:
- Probe internal network topology (AWS metadata, 169.254.x.x, 10.x.x.x)
- Fetch internal Supabase management APIs
- Make side-effect calls to external systems without AEF authorization

## Defence Layers

```
User input
    ↓
safeFetch (safe_fetch.ts)           ← Layer 1: SSRF protection (private IPs, loopback, link-local)
    ↓
buildEgressOptions(purpose, hosts)  ← Layer 2: Host allowlist by purpose taxonomy
    ↓
validateEgressContentType(...)      ← Layer 3: Content-type guard
    ↓
Timeout + size limits               ← Layer 4: Resource exhaustion protection
```

## Purpose Taxonomy

```typescript
type EgressPurpose =
  | 'PUBLIC_SOURCE_FETCH'    // user-submitted URL → no host restriction (SSRF still blocks)
  | 'REGISTRY_QUERY'         // known registries → subset of REGISTRY_HOSTS allowlist
  | 'INTERNAL'               // Supabase services → explicit host required
  | 'EXTERNAL_SIDE_EFFECT';  // consequential external call → explicit host + AEF required
```

Every outbound request from Impact must:
1. Declare its purpose
2. Call `buildEgressOptions(purpose, hosts?)`
3. Pass the result to `safeFetch`

No `safeFetch` call may use `{}` or omit options.

## Registry Host Allowlist

```
api.company-information.service.gov.uk  ← UK Companies House
api.charitycommission.gov.uk            ← UK Charity Commission
apps.irs.gov                            ← IRS EO Business Master File
www.irs.gov                             ← IRS
```

For `REGISTRY_QUERY`, callers may pass a subset of hosts. Any host not in this list throws `EGRESS_POLICY_VIOLATION` immediately.

## Limits by Purpose

| Purpose | Timeout | Max Response |
|---|---|---|
| `PUBLIC_SOURCE_FETCH` | 15s | 2 MB |
| `REGISTRY_QUERY` | 20s | 5 MB |
| `INTERNAL` | 10s | 10 MB |
| `EXTERNAL_SIDE_EFFECT` | 30s | 1 MB |

## Fetch Success ≠ Evidence Credibility

A successful egress fetch does **not** make the retrieved content credible evidence. Content must pass through the evidence ingestion pipeline (I2) before any claim can cite it. The egress policy guards the network boundary; evidence credibility is governed separately.

## What buildEgressOptions Enforces

| Purpose | Caller-provided hosts | Result |
|---|---|---|
| `PUBLIC_SOURCE_FETCH` | ignored | no allowedHosts (SSRF still applies) |
| `REGISTRY_QUERY` | must be subset of REGISTRY_HOSTS | error if unknown host |
| `INTERNAL` | required, non-empty | error if missing |
| `EXTERNAL_SIDE_EFFECT` | required, non-empty | error if missing |

## Logging

Egress events emit structured log fields (via observability.ts):
- `egress_purpose` — the declared purpose
- `egress_outcome` — STARTED / COMPLETED / DENIED / TIMEOUT / TOO_LARGE / CONTENT_TYPE_REJECTED
- `egress_status_code` — HTTP status from remote

Full URL is **never** logged (may contain path parameters with PII). Hostname only is logged.
