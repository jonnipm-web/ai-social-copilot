# IVE → AEF Runtime Integration (LAB)

Mission `IV-IVE-AEF-RUNTIME-INTEGRATION-01`. **Status: LAB only.** The runtime
uses mock tools only and runs against a local stack only. It is not deployed and
not deployable.

## Principle

IVE is an **intent producer**. AEF is the **sole governed execution boundary**.

An `IveActionIntent` is not an authorization, an execution, an approval, a
receipt or a tool invocation. Nothing in this integration lets IVE, the client
or the intent itself do any of the following:
- execute;
- approve;
- mark a request authorized;
- build a receipt;
- change the audit chain;
- choose a tool, a risk class or a role;
- bypass policy or the Human Gate.

## Current flow (before this mission)

1. `ive-intelligence` routes the request through AUTH → ENTITLEMENT → VALIDATE →
   INTENT/RISK.
2. A consequential request stops there and returns `ACTION_REQUIRES_AEF` with an
   `IveActionIntent` whose `parameters` are empty. No context, quota or model is
   used.
3. `mapIveActionIntent` existed, but only against actions with no registered
   tool, and nothing was wired to it.

## Target flow (this mission)

```
IVE  ──ACTION_REQUIRES_AEF + IveActionIntent──▶ client (LAB card, AEF_RUNTIME_LAB)
client ─{op: propose, intent + reviewed parameters}─▶ aef-runtime (Edge Function, LAB)
  AUTH (JWT) → ENTITLEMENT 'aef-runtime-lab' (EXPERIMENTAL: admin only)
  → KILL SWITCH (LAB + MOCK_ONLY + local stack; production refused)
  → STRICT BODY → IveAefRuntime
       mapIveActionIntentWith(LAB table)  subject = verified JWT holder
       → AefGovernance.submit()           identity↔credential, contract,
                                          input schema, policy, canonical
                                          payload hash, durable request,
                                          Human Gate (PostgreSQL)
  ◀─ AWAITING_APPROVAL + {gateId, bindingHash}
client ─{op: decide, gate}─▶  bound decision by the subject (APPROVE / REJECT)
client ─{op: execute, same proposal}─▶  claim (lease) → MOCK tool → complete
  ◀─ SUCCEEDED + persisted receipt   (or FAILED / UNKNOWN_OUTCOME / …)
```

## Components

| Component | File | Role |
|---|---|---|
| Kill switch | `aef/runtime/runtime_guard.ts` | Requires `AEF_RUNTIME_MODE=LAB`, `AEF_TOOLS=MOCK_ONLY` and a local `SUPABASE_URL` (loopback / `kong` / `host.docker.internal`). The production project ref is refused. Any override variable is refused. |
| LAB registry | `aef/runtime/lab_tools.ts` | Two `internal.mock_*` tools, CONSEQUENTIAL, with a mandatory gate and a closed input schema. It is the only registry the runtime can build, and it is sealed. The LAB action table maps only `publish_content` / `send_message`; `trade_order` is denied, everything else is unknown. |
| Input schema | `aef/persistence/tool_input_schema.ts` | Flat, closed, bounded scalars. It is checked by `AefGovernance` **before** anything is persisted (`TOOL_INPUT_INVALID`), and `requireInputSchema` refuses any tool without a schema. The denial is audited as `INVALID_REQUEST` (the database's closed code list). |
| Adapter | `aef/runtime/ive_aef_runtime.ts` | `propose` / `execute` / `decide` / `status` / `cancel`. It has no tool capability and no store access, and it never authorizes. |
| Presentation | `aef/runtime/presentation.ts` | `completed` only for a persisted SUCCEEDED with a SUCCESS receipt. UNKNOWN_OUTCOME is its own phase, `reconciliationRequired`, and `retryAllowed` is always false. |
| Endpoint | `supabase/functions/_shared/aef_runtime_endpoint.ts`, `supabase/functions/aef-runtime/index.ts` | Auth → entitlement → kill switch → strict body. Only after that is the runtime built (service_role RPC transport). |
| Client | `lib/data/models/aef_runtime.dart`, `lib/data/services/aef_runtime_service.dart`, `lib/shared/widgets/aef_action_card.dart` | LAB Human Gate card, off by default (`--dart-define=AEF_RUNTIME_LAB=true`). |

## Authority

- **Subject.** It comes from the JWT (`resolveAuthenticatedUser`). The
  governance checks it again, credential ↔ actor, through the identity
  resolver. A body `subjectId` is refused (strict keys); so is an intent
  `subjectId` (six exact keys), and so are authority aliases inside the
  parameters.
- **Entitlement.** `requireModuleAccess(req, user, 'aef-runtime-lab')` reads
  plan and role from the server source. The module is EXPERIMENTAL (admin
  only).
- **Tool, risk and gate.** These come from the server registry and policy. The
  `riskClass` field of the intent is ignored for authority (test RT-07).
- **SERVICE/SYSTEM actors.** They remain unsupported: the identity resolver
  accepts only verified users, and nothing was widened.

## Canonicalization and payload binding

The idempotency key is `ive:sha256(canonical {contextRef, requestedAction,
projectId, parameters})`. The operation's payload hash covers the parameters,
and the gate's binding hash covers the payload. So:
- a changed parameter maps to a new operation, which needs its own approval;
- approval A never authorizes payload B, and the binding hash of A is refused
  for gate B;
- the client card locks the fields once the proposal is sent.

## Time bounds (Codex RG2-01)

| Bound | Value | Enforced by | What it limits |
|---|---|---|---|
| Request envelope | 5 min (`expires_at` of each mapped request) | contract validation, per submission | the freshness of *one* message; it is re-minted on each resubmission, and it is **not** the approval window |
| **Approval window** | **15 min** (gate TTL, from registration) | PostgreSQL `aef__expire_if_due` on decide / replay / claim | approving **and executing**: an AUTHORIZED operation whose gate has expired becomes EXPIRED and never runs (RT-15, PG-14) |
| Operation lifetime | 1 h | PostgreSQL | the durable record; for gated tools the gate window always ends first |

PG-14 and RT-15 are `ignore`d only when no disposable database is configured
(`AEF_PG_DB`). The runner sets it, and CI executes both tests. See
`docs/aef/evidence/ci_run_36199257974_approval_window.txt`: PG-14 ok, RT-15 ok,
60 passed.

## Operation identity and `contextRef`

The operation identity is `(subject, requestedAction, projectId, parameters,
contextRef)`. `contextRef` is the IVE turn that produced the suggestion.

The same payload suggested in two different IVE turns is therefore two
operations, and **each needs its own explicit approval** (RT-16). Approving
one never authorizes the other. This is intentional: a repeated effect
requires a repeated human decision.

## Audit of refusals (Codex RG2-02)

Intents refused before AEF can register anything (malformed, unknown or
forbidden action) are still recorded in the subject's audit chain, through
`AefGovernance.auditRefusal`. The subject is re-verified from the credential,
and the code is mapped onto the database's closed denial list (for example,
INTENT_ACTION_UNKNOWN is recorded as UNKNOWN_TOOL). Schema denials are
recorded as INVALID_REQUEST.

Requests the HTTP boundary refuses before identity is known (401/400) are not
AEF events.

## States shown to the user

The client can show these phases:
- PROPOSED (client-only);
- AWAITING_APPROVAL, AUTHORIZED, EXECUTING;
- SUCCEEDED, FAILED, UNKNOWN_OUTCOME;
- REJECTED, EXPIRED, CANCELLED, INVALIDATED;
- DENIED.

"Done" appears only when the phase is SUCCEEDED, the server reports
`completed`, and the persisted receipt says SUCCESS. A network interruption is
shown as "not confirmed". UNKNOWN_OUTCOME is amber with a help icon, distinct
from FAILED (red), and offers no retry.

## Why `aef-runtime-lab` is REVERSIBLE

`aef-runtime-lab` is EXPERIMENTAL and **REVERSIBLE** (not CONSEQUENTIAL). Its
only reachable tools are in-process mocks: nothing leaves the process.
Test RU-15 ties that classification to every LAB tool being `internal.mock_*`.

A real tool would make the module CONSEQUENTIAL. The Promotion Gate (MP-03/MP-09)
refuses to serve a CONSEQUENTIAL module while `AEF_PERSISTENCE_AVAILABLE` is
false, so the classification is not a loophole.

## Not in this mission

- Deploy, production migrations, real tools and any production runtime are
  PROHIBITED, and this mission did none of them (`AEF_PRODUCTION_READINESS.md`).
- Operator reconciliation stays disabled (D4).
- There is no automatic retry of anything.
