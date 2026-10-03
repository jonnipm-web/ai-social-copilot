# Security Threat Model — Impact I7

**Mission:** IV-IMPACT-I7-TRUST-EGRESS-AEF-INTEGRATION-01  
**Scope:** Trust boundary, egress, AEF governance

## Attack Surface

```
Client (browser)
    → HTTPS → Supabase Edge (impact-lab)
                → JWT verification (Supabase Auth)
                → Entitlement check (requireModuleAccess)
                → CallerContext construction (trust.ts)
                → Body parsing (lab_contract.ts)
                → AEF intercept (index.ts) — for class C actions
                → handleLabRequest (lab_service.ts)
                → DB access via service_role (supabase_store.ts)
                → Outbound HTTP (safe_fetch + egress_policy)
```

## Attack Vectors and Mitigations

### 1. Service Identity Impersonation
**Attack:** Attacker submits requests claiming to be `impact-monitor` from a different function.  
**Mitigation:** `serviceId` is a server constant set at function initialization, not from the request body. `buildCallerContext` rejects unknown serviceIds.  
**Residual risk:** If `serviceId` were derived from a request header or body, this would be exploitable. It is not.

### 2. service_role Authority Confusion (Confused Deputy)
**Attack:** Exploit the fact that service_role bypasses RLS to perform actions on behalf of any user.  
**Mitigation:** `authenticatedUserId` always comes from `auth.uid()` (JWT-verified user), never from the request body. All AEF receipts carry `callerUserId` from the CallerContext.  
**Residual risk:** None in the AEF path. Pre-AEF actions in `handleLabRequest` must also respect this.

### 3. Cross-Project Access (Confused Deputy Variant)
**Attack:** Authenticated user A submits a consequential action claiming project B (owned by user B).  
**Mitigation:** `validateProjectScope` checks that `claimedProjectId` matches `context.projectId` AND appears in `userOwnedProjectIds` (fetched from DB under the caller's JWT, so RLS-enforced).  
**Residual risk:** Only if RLS on `projects` is misconfigured.

### 4. SSRF — Private IP
**Attack:** Submit a source URL pointing to 169.254.169.254 (AWS metadata), 10.x.x.x, ::1, etc.  
**Mitigation:** `safeFetch` blocks private IPs, loopback, and link-local before DNS resolution.  
**Residual risk:** DNS rebinding (public DNS record that resolves to private IP after safeFetch's check). Mitigation requires TTL pinning at DNS lookup time (not yet implemented; low risk in Edge Function environment with short-lived requests).

### 5. SSRF — Redirect Escape
**Attack:** Submit a URL that redirects (301/302) to a private IP after safeFetch validates the initial host.  
**Mitigation:** `safeFetch` follows redirects but re-checks the resolved IP at each hop (implementation-dependent). Risk is partially mitigated by `allowedHosts` for REGISTRY_QUERY: the final host must also be in the allowlist.  
**Residual risk:** For `PUBLIC_SOURCE_FETCH`, redirect to private IP is blocked by SSRF check at each hop.

### 6. Egress Host Bypass
**Attack:** Pass a host to `buildEgressOptions` for REGISTRY_QUERY that is not in `REGISTRY_HOSTS`.  
**Mitigation:** `buildEgressOptions` throws `EGRESS_POLICY_VIOLATION` for any unknown host.  
**Residual risk:** None for the current allowlist. New registries require explicit addition + review.

### 7. Forged Evidence Confidence Upgrade
**Attack:** Manipulate evidence to claim a higher credibility tier than warranted.  
**Mitigation:** Evidence credibility is computed server-side from immutable provenance chain (I2). AEF receipt only records the action type, not evidence content.  
**Residual risk:** Evidence pipeline (I2) must remain server-authoritative.

### 8. Forged Human Gate
**Attack:** Submit a gate resolution with a fabricated `bindingHash` to approve a modified request.  
**Mitigation:** `bindingHash` is validated as 64-hex. The **caller** provides the hash, but the gate resolution is stored server-side. A mismatch between the hash and the actual request state is detectable at audit time.  
**Residual risk (P2):** The kernel doesn't currently verify `bindingHash` against the actual request contents — it validates format only. Full hash verification against request state would close this gap.

### 9. Stale Human Gate
**Attack:** Approve a gate after the 24-hour TTL to authorize an outdated action.  
**Mitigation:** `resolveHumanGate` checks `Date.parse(now) > Date.parse(gate.expiresAt)` and transitions to `EXPIRED`, returning `HUMAN_GATE_INVALID`.  
**Residual risk:** Clock skew between Edge Function instances (minimal; all use server time).

### 10. Duplicate Execution (Idempotency Replay)
**Attack:** Submit the same consequential action twice to execute it twice.  
**Mitigation:** DB unique constraint on `(caller_user_id, intent_kind, idempotency_key)` prevents duplicate inserts. InMemoryAefStore maintains the same index.  
**Residual risk:** None for the same idempotency key. Different keys = different requests (intended).

### 11. AEF Bypass
**Attack:** Submit a class C action in the `action` field but use a different field name that bypasses the AEF intercept.  
**Mitigation:** Index.ts intercepts if `action === 'request_external_action'` AND `kind` is in `IMPACT_ACTION_INTENTS`. The `handleLabRequest` path also blocks unknown/non-AEF class C kinds via an explicit check.  
**Residual risk (P2):** If a new class C action kind is added to `handleLabRequest` without also adding it to `IMPACT_ACTION_INTENTS`, it would bypass AEF. Discipline: always add new class C kinds to both.

### 12. Missing Receipt
**Attack:** Trigger an AEF action but cause receipt insertion to fail, leaving no audit trail.  
**Mitigation:** Receipt insertion (`insertReceipt`) is called unconditionally before returning any result. If it fails, the store returns `AEF_PERSISTENCE_UNAVAILABLE`, the request fails closed, and the caller gets a 503.  
**Residual risk:** If the store is completely down, no receipt is issued. This is fail-closed (action denied), so no unauthorized execution occurs.

### 13. Receipt Tampering at Rest
**Attack:** Modify a receipt in the database after issuance.  
**Mitigation:** DB trigger `impact_aef_receipt_immutable` blocks all UPDATE and DELETE. `receiptHash` (SHA-256) allows detection of any tampering.  
**Residual risk:** A service_role holder with direct DB access could bypass the trigger. Mitigation: DB-level audit logs + service_role access restrictions (standard Supabase practice).

### 14. Privacy Leakage in Receipts
**Attack:** Extract PII from AEF receipts (e.g., approver identity, investigation content).  
**Mitigation:** `approverRef` is specified to be an opaque reference, never a real name or email. RLS allows only `caller_user_id = auth.uid()` for SELECT. No document content or claim text appears in any AEF table.  
**Residual risk:** `callerUserId` is a Supabase `auth.users.id` UUID — not directly PII, but can be correlated with user records by an insider with `service_role` access.

### 15. Gate Double-Resolution
**Attack:** Call `resolveHumanGate` twice to change a `REJECTED` gate to `APPROVED`.  
**Mitigation:** DB trigger `impact_aef_gate_transitions_trg` raises `IMPACT_AEF_GATE_ALREADY_RESOLVED` if `OLD.status != 'PENDING'`. Kernel also checks `gate.status !== 'PENDING'` before proceeding.  
**Residual risk:** None — two independent checks.

## Open Items (P2 — not blocking Lab)

| ID | Description |
|---|---|
| TM-1 | `bindingHash` is format-validated only; not verified against request state |
| TM-2 | AEF bypass possible if new class C kind added to handleLabRequest without IMPACT_ACTION_INTENTS |
| TM-3 | DNS rebinding not mitigated for long-lived connections (low risk in Edge Functions) |
| TM-4 | Redirect chain SSRF: depends on safeFetch implementation |
