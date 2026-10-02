# Provider Lifecycle Policy — IV Quant Lab
# Mission: IV-QUANT-LICENSED-PROVIDER-PILOT-04 (§29)
# Effective Date: 2026-10-03
# Authority: Agente Martins + Paulo

---

## 1. Policy Statement

Market data providers deprecate products, change pricing, and revoke rights
without notice. The Quant Lab must maintain a current, evidence-based view
of every active provider to avoid runtime failures, rights violations, and
commercial surprises.

**This policy is mandatory. No adapter may reference a provider product without
a corresponding entry in PROVIDER_EVIDENCE_REGISTER.md and a lifecycle review
within the past 90 days.**

---

## 2. Revalidation Schedule

| Trigger | Action |
|---|---|
| Every 90 days (calendar) | Full revalidation of all active providers |
| Before production promotion | Mandatory revalidation of PRIMARY_BOOTSTRAP_PROVIDER |
| Before any new adapter creation | Validate CURRENT=YES, DEPRECATED=NO before writing code |
| Before Owner commits (account/key) | Confirm pricing and rights still match the decision |
| After any provider announcement | Evaluate impact on active adapters |

Next scheduled revalidation: **2027-01-03**

---

## 3. Revalidation Procedure

For each active provider in PROVIDER_EVIDENCE_REGISTER.md:

1. Check the provider's official website for:
   - Is the product still listed?
   - Are there deprecation or sunset notices?
   - Has pricing changed?
   - Have terms/licensing changed?

2. Record updated evidence in PROVIDER_EVIDENCE_REGISTER.md:
   - Keep old entries (mark as SUPERSEDED)
   - Add new EV-ID with updated URL and access date

3. Update CURRENT_PROVIDER_MARKET_2026-10.md:
   - Rename the file to reflect the new review date
   - Update STATUS column

4. If DEPRECATED=YES:
   - Mark adapter as LEGACY (see §5)
   - Dispatch a new provider selection (do NOT use deprecated adapter in production)
   - Notify Agente Martins and Paulo

5. If pricing changes break the cost model:
   - Update REAL_DATA_COST_MODEL.md
   - Re-evaluate PRIMARY_BOOTSTRAP_PROVIDER

---

## 4. Deprecation Guard Requirements

Every adapter must have a deprecation guard test:

```typescript
Deno.test('DEPRECATION GUARD: adapter uses current dataset, not deprecated DATASET_NAME', () => {
  const result = adapter.buildRequest(req, baseUrl);
  assertEquals(result.ok, true);
  const u = new URL(result.value.url);
  assertEquals(u.searchParams.get('dataset'), 'CURRENT_DATASET_NAME');
  // Explicit guard against regression to deprecated name:
  assertNotEquals(u.searchParams.get('dataset'), 'DEPRECATED_DATASET_NAME');
});
```

This test must fail if the adapter reverts to a deprecated dataset.
It serves as a canary in the CI pipeline.

---

## 5. Adapter Lifecycle States

| State | Meaning | Allowed in Production |
|---|---|---|
| ACTIVE | Current product, verified rights, within revalidation window | YES |
| LEGACY | Product deprecated or superseded; adapter disabled, no network calls | NO |
| EXPERIMENTAL | Not yet verified; lab only; no real credentials | NO |
| DISABLED | Manually disabled; build-time constant prevents activation | NO |

When an adapter is marked LEGACY:
1. Set a build-time constant (e.g. `const EQUS_LEGACY = true as const`) that is checked by the runtime
2. The runtime MUST refuse to call the provider if the flag is set
3. Add a test that the runtime returns `PROVIDER_UNAVAILABLE` for LEGACY adapters
4. Keep the adapter code for diagnostic/forensic purposes

---

## 6. Evidence Requirements

Every claim about a provider that influences a technical or commercial decision
must have an entry in PROVIDER_EVIDENCE_REGISTER.md:

| Claim Type | Required Evidence |
|---|---|
| "Product is current" | Official product page URL, access date |
| "Product is deprecated" | Official announcement or release note URL |
| "Commercial display allowed" | Terms of service URL, specific clause, access date |
| "No redistribution" | Terms of service URL, specific clause, access date |
| "Pricing is X/month" | Official pricing page URL, access date |
| "Pay-as-you-go available" | Official pricing or documentation URL |
| "Free credits available" | Official documentation URL |

Claims derived only from memory, third-party reviews, or AI-generated summaries
are **NOT SUFFICIENT**. They must be cross-referenced with official sources.

---

## 7. Vendor Selection Gate

Before implementing any adapter for a new provider, Claude Code MUST verify:

```
CURRENT_PRODUCT  = YES
DEPRECATED       = NO
SUNSET_DATE      = N/A or future
CURRENT_DATASET  = confirmed
CURRENT_ENDPOINT = confirmed
RIGHTS_STATUS    = GREEN (for Phase 1) or YELLOW accepted by Owner
PRICING_MODEL    = within budget constraints
EVIDENCE_REGISTERED = YES (at least one EV-ID per critical claim)
```

If any field is UNKNOWN or UNVERIFIED: **STATUS = UNKNOWN; adapter BLOCKED.**
Do not write code against an unverified provider.

---

## 8. Reporting

Lifecycle status is reported in:
- `docs/quant/IV-QUANT-LICENSED-PROVIDER-PILOT-04.md` (mission report)
- `docs/quant/CURRENT_PROVIDER_MARKET_2026-10.md` (market snapshot, rename on update)
- `docs/quant/PROVIDER_EVIDENCE_REGISTER.md` (individual evidence records)
- `docs/quant/BOOTSTRAP_PROVIDER_DECISION.md` (decision record)

Codex adversarial audit MUST independently verify provider claims when:
- A new PRIMARY_BOOTSTRAP_PROVIDER is selected
- Rights or pricing assumptions change materially
- An existing provider announces significant product changes
