# AEF Contract Foundation

**Mission:** `IVE-AEF-CONTRACT-SECURITY-GATE-01`
**Status:** Contract foundation only. **No AEF service, job engine, queue, or production endpoint exists or is created by this directory.** Nothing here is wired into the Core app (`lib/`) or into any deployed Edge Function (`supabase/functions/`). It is safe to delete this entire directory today with zero runtime impact — that is a deliberate design property, not an oversight.

---

## Why this exists

Three prior missions in this chain (`IV-EVIDENCE-TRUST-BOUNDARY-DESIGN-01`, `INSIGHTVALUES-ECOSYSTEM-TARGET-ARCHITECTURE-01`, `IV-SECURITY-REMEDIATION-02/03`) approved the architectural shape `IVE → AEF → domain/tool`, but every one of them explicitly deferred building AEF until the *contract* between IVE and AEF was formalized as something a validator can mechanically enforce — not just a paragraph of prose. This directory is that formalization. It contains:

- JSON Schemas (`schema/`) — the language-agnostic, canonical definition of each contract type. Any future implementation (Dart, Python, another TypeScript service) validates against these, not against this directory's own validator.
- A TypeScript/Deno reference validator (`validators.ts`, `prohibited_fields.ts`, `types.ts`) — a **pure**, side-effect-free implementation used to prove the schemas are enforceable and to run the required test matrix. It is a reference, not "the" implementation AEF must use.
- A test suite (`validators_test.ts`) covering the full adversarial matrix required by this mission, plus fixtures.
- Cross-domain examples (`fixtures/examples/`) showing the same contract shape used for Core, Quant, and Impact without domain-specific contamination.

## Repository decision (Section 20)

**Decision: lives inside the Core repository (`InsightValues-Showcase`), in this new top-level directory, not in a new repository, not inside `lib/`, and not inside `supabase/functions/`.**

Rationale:
- A new repository is not justified yet — there is no AEF runtime to consume this externally, and creating one now would be exactly the kind of premature infrastructure the architecture mission's "no unnecessary complexity" rule warns against.
- Placing it inside `lib/` would wrongly imply it is Flutter/Dart application code, and risks accidental import into the running app before AEF exists to enforce anything.
- Placing it inside `supabase/functions/` risks it being swept into a future bulk-bundle or accidentally deployed as if it were a real function.
- A dedicated top-level directory is trivially extractable later into its own package or repository (it has no imports into `lib/` or `supabase/functions/`, and nothing imports it back) — this is the "smallest reversible change that preserves future extraction" the mission asked for.
- JSON Schema as the canonical format (rather than TypeScript-only types) means the contract is not accidentally coupled to whatever language AEF v0 eventually gets built in.

## The core trust principle

> **IVE MAY REQUEST. IVE MUST NOT AUTHORIZE.**

Every design choice below exists to make this structurally true, not just documented. Concretely:

- No field IVE (or any request-originating component) supplies can, by itself, grant authority, entitlement, tenant membership, or approval. See `prohibited_fields.ts` — this list is enforced by the validator, not left to code review discipline.
- Identity claimed by an actor (`actor.id`) is never trusted on its own — it must carry an `auth_ref` that some *other*, independent, trusted component resolves. This directly generalizes the lesson already proven in production by `IVE-COMMERCIAL-AUTH-01`: `verify_jwt=true` alone was not proof of a real user; `resolveAuthenticatedUser()` — an independent resolution step — was the actual boundary. This contract assumes the same pattern will exist for every actor type, not just Supabase end users.
- Delegation from one component to the next (`DelegationEnvelope`) is scoped to one `audience` and, in this version, one `request_id` — a delegation issued for the Core domain cannot silently satisfy a Quant or Impact request, and a delegation issued for one request cannot be replayed against a different one.
- Nothing in this package can execute anything. There is no `execute()`, `run()`, or `dispatch()` function anywhere in this directory — only `validate*()` functions that return a verdict. See `NO_DIRECT_EXECUTION.md` for why that absence is itself a tested property, not an accident.

## Contents

| File | Purpose |
|---|---|
| `schema/execution-request.v1.schema.json` | The request IVE (or any component) submits describing an intent. |
| `schema/delegation-envelope.v1.schema.json` | A narrow, scoped, single-use proof that one component may ask a specific other component to act on a specific request. |
| `schema/human-gate-record.v1.schema.json` | The only legitimate source of "a human approved this" — never a field on the request itself. |
| `schema/policy-signal.v1.schema.json` | Distinguishes advisory reasoning (IVE, Evidence & Trust, anything) from authoritative policy decisions (only a small, explicit allow-list of sources may produce these). |
| `schema/execution-receipt.v1.schema.json` | What a (future) AEF would record after governing and executing an action. Deliberately distinct from Evidence & Trust's own provenance schema — see the schema's own header comment. |
| `prohibited_fields.ts` | The closed list of authority-shaped field names, plus a recursive scanner that rejects them anywhere in a request, including nested inside `parameters`. |
| `types.ts` | TypeScript types mirroring the schemas, for the reference validator only. |
| `validators.ts` | Pure validation functions. No network, no filesystem, no database, no `Date.now()`-only nondeterminism where a test needs to inject time. |
| `validators_test.ts` | The full required adversarial test matrix (Section 21) plus lightweight fuzz-style cases (Section 22). Run with `deno test --allow-read validators_test.ts`. |
| `schema_parity_test.ts` | Exercises the JSON Schemas directly with a generic validator (`npm:ajv`), independent of `validators.ts`, proving the schema alone -- not just the TypeScript reference validator -- enforces the same restrictions (added after Codex adversarial review, round 3, Finding N-03, found a schema/validator parity gap). This is the only file in this directory with an external dependency and requires network access to resolve `npm:ajv`/`npm:ajv-formats`: run with `deno test --allow-read --allow-net=registry.npmjs.org schema_parity_test.ts` (subsequent runs use deno's local npm cache). |
| `fixtures/valid/`, `fixtures/invalid/` | A representative selection of standalone JSON fixtures, named after the case they demonstrate, for manual inspection/documentation. The *complete* 28-case adversarial matrix (Section 21) plus fuzz-lite cases (Section 22) live as executable test cases directly in `validators_test.ts`, not as one file per case -- that keeps every case's expectation next to its assertion, which is easier to audit than cross-referencing a JSON file against a separate expectation list. |
| `fixtures/examples/` | `core-example.json`, `quant-example.json`, `impact-example.json` — the cross-domain proof (Section 24). |
| `NO_DIRECT_EXECUTION.md` | The availability/durability rule (Section 16) and why this package structurally cannot be used to bypass AEF. |
| `FAILURE_MODEL.md` | Section 15/16 in full: what happens when each dependency is unavailable. |
| `VERSIONING_POLICY.md` | Section 18 in full. |

## What this mission explicitly does NOT do

Per the mission's own Section 19/25, this directory contains **only**: types/schemas, pure validators, tests, fixtures, and documentation. It does not contain, and this mission did not build: a job engine, a real AEF service, a new production endpoint, a queue, billing integration, a broker adapter, Impact execution, or any production deployment. Nothing in `lib/` or `supabase/functions/` was modified by this mission. Commercial V1 is untouched.

## Known, acknowledged gap: Impact has no consequential-action registry yet (Codex Finding F-09)

Quant's `quant_execution_tier` field is validated for consistency against the tier named in the action's own namespace (e.g. `quant.controlled_live.submit_order` must declare `quant_execution_tier: "controlled_live"`) -- this makes it impossible for a caller to under-declare the risk of a real-money action. **Impact has no equivalent mechanism in v1.** `fixtures/examples/impact-example.json` is a `Discover/Verify/Investigate`-shaped example that correctly needs no `human_gate_ref`, but a prior architecture mission (`INSIGHTVALUES-ECOSYSTEM-TARGET-ARCHITECTURE-01`) already described "Monitor automatizado L3+" as needing human review, and this contract does not yet enforce that for any Impact action. This is an **explicit, acknowledged scope boundary for this v1 foundation**, not an oversight: building an Impact action-risk taxonomy analogous to Quant's tiers requires product decisions about Impact (Discover/Verify/Investigate/Monitor) that are out of scope for a domain-neutral contract mission (Section 24: "não implementar Quant/Impact"). **This must be resolved before any Impact action is treated as consequential enough to route through a future AEF.**

## Escalated architectural decision: `auth_ref` cannot cryptographically resolve confused-deputy risk within this mission's scope (Codex Finding F-02, both rounds)

`Actor.auth_ref` (used by every `actor`/`issuer`/`subject`/`approver` field across all five contract types) requires a namespaced prefix (`usr:`/`svc:`/the fixed literal `system:internal`) and, as of round 3 remediation, a minimum substantive suffix length (>= 8 characters after the prefix). Codex adversarial review correctly identified, in **both** review rounds, that this is necessarily incomplete: a value like `svc:not-a-real-service` is syntactically well-formed, passes every check this contract can express, and still proves nothing. This is not a bug to be fixed inside `contracts/aef/` -- it is a structural consequence of Section 7's explicit instruction that this mission **does not implement cryptographic verification**. Closing the confused-deputy risk for real requires an independent authentication/authorization resolver (e.g. verifying `auth_ref` against a real session store, service-identity registry, or signed assertion) that lives outside a pure, side-effect-free, no-I/O validator by design (see "The core trust principle" above -- resolution is explicitly a future AEF's job, never this contract's). **Recommendation:** track "implement the real `auth_ref` resolver" as an explicit acceptance criterion of whichever future mission first builds a live AEF component (e.g. `IV-AEF-FOUNDATION-01`), not as an open item against this contract mission. Until that resolver exists, no component may treat a schema-valid `auth_ref` as proof of anything beyond "well-formed."
