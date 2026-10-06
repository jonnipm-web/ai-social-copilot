# Quant Entitlement Tiers

**Mission:** IV-QUANT-MACRO-05 FASE 20  
**Status date:** 2026-10-04  
**Status:** DESIGN — not yet activated  
**Decision authority:** Agente Martins + Paulo (commercial gate required)

---

## 1. Current State

All Quant routes are under module `quant-analytics` (lifecycle: INTERNAL).
Module `quant-watchlists` is also INTERNAL. Module `ive-quant` is EXPERIMENTAL
with no Edge Function.

INTERNAL lifecycle means only admin-role users can access the module (enforced
server-side by `requireModuleAccess()` + `route_policy.dart`). No tier
differentiation exists yet — access is all-or-nothing.

---

## 2. Proposed Tier Structure (pending authorisation)

| Tier | Quant capabilities | Notes |
|---|---|---|
| **FREE** | Read-only access to `/quant` shell; no analysis | Placeholder; shows upgrade prompt |
| **PRO** | `quant.analyze.v1` (user CSV) + up to 5 watchlist items | Requires `quant-analytics` EXPOSED |
| **BUSINESS** | All PRO + `quant.analyze.watchlist.v1` (up to 50 items) + server-side data | Requires real provider (BLOCKED_OWNER) |
| **ENTERPRISE** | All BUSINESS + custom limits + priority data refresh | Requires commercial agreement |

---

## 3. Module Lifecycle Transition Required

Moving from INTERNAL → EXPOSED requires:
1. Agente Martins architectural approval
2. Paulo commercial approval
3. Databento rights YELLOW → GREEN (written confirmation)
4. Class D Codex review PASS
5. Legal disclaimer review (OQ-01, OQ-02 from QUANT_RESEARCH_ADVICE_BOUNDARY.md)

This transition is **not yet authorised**. The `/quant` route exists but is
gated INTERNAL — only admins can reach it in the current build.

---

## 4. Rate Limits by Tier (proposed)

| Tier | Requests / min | Requests / day |
|---|---|---|
| FREE | — | — |
| PRO | 10 | 100 |
| BUSINESS | 30 | 500 |
| ENTERPRISE | 100 | configurable |

Current limits (all users, INTERNAL phase): 60 req/min, 1000 req/day
(from `QUANT_RATE_LIMIT_POLICY.md`).

---

## 5. AEF Tier Mapping

| Quant tier (AEF) | Entitlement tier | AEF v0 status |
|---|---|---|
| `research` | FREE / PRO / BUSINESS | ALLOWED (read-only engine) |
| `backtest` | BUSINESS / ENTERPRISE | Requires human gate + AEF persistence |
| `paper` | ENTERPRISE | Requires human gate |
| `controlled_live` | NOT AVAILABLE | DENY_BY_V0 (hard-coded) |
| `expanded_live` | NOT AVAILABLE | DENY_BY_V0 (hard-coded) |

Real-money tiers remain hard-denied regardless of entitlement tier.

---

## 6. Implementation Path (when authorised)

1. Promote `quant-analytics` lifecycle to EXPOSED in `module_policy.ts`
2. Add entitlement vector tests for FREE/PRO/BUSINESS/ENTERPRISE Quant limits
3. Update `route_policy.dart` comment (route mapping stays the same)
4. Update `QuantScreen` to show tier-appropriate content and upgrade prompts
5. Add i18n keys for tier messaging (`quant.tier.*`)
6. Run full entitlement test matrix
7. Codex CLASS D review of entitlement changes
8. Gate: Agente Martins + Paulo
