# AEF Automation Foundation Mapping

**Mission:** INSIGHTVALUES-COMMERCIAL-MACRO-01, Tranche 3. Scope, per Tranche 1's own §18 recommendation: map which existing user workflows are shaped so that a future AEF-governed `recommend → approve → execute → receipt → result → learn` loop would not require rearchitecting — **without building any of that loop now.** This document is the mapping. No AEF code, wiring, or dependency was added to this branch.

---

## 1. AEF's real current state (evidence-based, re-verified this tranche)

Re-confirmed against this repository's actual git history (not assumed from prior docs):

- **`origin/main` (HEAD `ff8ef34`)** already contains AEF's contract layer (`contracts/aef/` — typed/versioned/fail-closed wire schemas) and the v0 in-memory kernel (`aef/kernel.ts`, `aef/policy_evaluator.ts`, `aef/human_gate_evaluator.ts`, `aef/tool_registry.ts`, etc.) — merged via PR #101 and PR #102. This is real, tested, Codex-adversarially-reviewed code (238 Deno tests at the most advanced checkpoint inspected).
- **This branch (`claude/commercial-macro-01`) does NOT have any of it.** `git merge-base 84928cf origin/main` returns `f9c20f7` — this branch's base and `main` **diverged** at that point and were never reconciled. 20 commits exist on `main` since (AEF contracts+kernel, plus unrelated CI/governance security fixes) that this branch's lineage never received; conversely this branch's lineage carries ~25 commits (the Commercial/Play-readiness/IVE work from this session) that never reached `main`. Confirmed by `grep`: zero `aef/` or `contracts/aef/` files, zero `AefActionCard`/`IveActionIntent` references anywhere in this branch.
- **The full persistence + LAB runtime + Human Gate UI layer (Postgres-backed state machine, receipts, audit chain, `AefActionCard` widget) exists only on a third, still-unmerged branch** (`claude/insightvalues-module-architecture`, tip `5bc767a`) — a strict superset of what's in `main`, itself explicitly marked `READY_FOR_PRODUCTION_DEPLOYMENT_GATE: NO` by its own docs.
- **A live, external, out-of-repo agent already writes directly to `action_queue`** using the end user's JWT, with zero AEF governance (no Human Gate, no receipt, no idempotency guard) — this is the same `action_queue` this repository's own in-app Action Engine reads from. Documented in this repo's own architecture audit as an OPEN, ESCALATED finding (`MPA-F04`).

**→ ARCHITECTURAL FINDING, flagged not fixed (see §5).** This branch's relationship to AEF is not "AEF doesn't exist yet, so there's nothing to integrate with" — it's "AEF exists, twice, on two other branches, and neither has been reconciled with this one." That reconciliation is a real decision, not something this tranche's scope (mapping only) authorizes touching.

## 2. The existing candidate workflow, verified against this branch's real code

Tranche 1's own recommendation named Opportunity Lab → Action Engine as the mapping candidate. Verified end-to-end against this branch's actual source (not assumed):

| Step | What exists today | Where | Governance today |
|---|---|---|---|
| **Recommend** | `generate-project-opportunities` and `opportunity-discovery` Edge Functions produce AI-derived opportunities | `supabase/functions/generate-project-opportunities/`, `supabase/functions/opportunity-discovery/` | None needed — read-only suggestion, nothing to govern yet |
| **Propose** | `ActionQueueNotifier.addFromOpportunityItem()` inserts a row into `action_queue` with `status: 'pending'`, tagged `origin: 'opportunity_lab'` | `lib/providers/action_queue_provider.dart:191-210` | RLS-bounded insert only; no policy check |
| **Approve** | `ActionQueueNotifier.approve()` → `ActionQueueService.updateStatus(id, 'approved')` — a **direct client-side Supabase table update** | `lib/providers/action_queue_provider.dart:73-86`, `lib/data/services/action_queue_service.dart:38-` | **None.** No server-side re-verification of who approved, no Human Gate, no binding to the original proposal beyond the row's own id |
| **Execute** | `ActionQueueNotifier.execute()` → same pattern, `status: 'executing'` | `action_queue_provider.dart:88-101` | **None.** No policy evaluation, no classification (READ_ONLY/REVERSIBLE/CONSEQUENTIAL), no tool registry — "execute" here means "flip a status string," not "actually perform an action through a governed tool" |
| **Complete** | `ActionQueueNotifier.complete()` → `status: 'completed'` | `action_queue_provider.dart:103-116` | **None.** No receipt, no idempotency guard |
| **Receipt** | Does not exist | — | — |
| **Learn** | Does not exist (no feedback loop from outcome back into future recommendations) | — | — |

**Reading this table is the actual point of this mapping exercise.** The verb shape (`recommend → propose → approve → execute → complete`) already matches AEF's target loop (`recommend → approve → execute → receipt → result → learn`) almost one-for-one — this is genuinely good news, and confirms Tranche 1's hypothesis. But every governance-bearing step (`approve`, `execute`, `complete`) is today a bare client-side status write, not a policy decision. This is structurally the same class of gap CAP-011 (the external agent) was already flagged for — except it's the **first-party in-app client** doing it, not just an external actor.

## 3. What would NOT require rearchitecting (the actual finding this tranche exists to produce)

- **The data model already has the right shape.** `ActionQueueItem` already carries `origin`, `sources`, `rationale`, `plan`, `risks`, `confidence`, `impactScore`/`effortScore`/`roiScore` — richer provenance than AEF's own `ExecutionRequest` currently requires. A future governed path would not need a new proposal schema; it would need to make the *existing* schema the payload of an `ExecutionRequest`.
- **The verb sequence already matches.** No redesign of the user-facing recommend→approve→execute flow is implied by adding governance underneath it — the screens (`action_engine_screen.dart`, `opportunity_lab_screen.dart`) would keep their current shape; only what `approve()`/`execute()`/`complete()` *call* would change (from a direct table write to a call that runs the AEF pipeline).
- **`action_queue`'s RLS-bounded, per-user isolation is already compatible** with AEF's identity model (`subject_id = auth.uid()`) — no ownership-model change is implied.
- **The event bus pattern (`IveEventBus.instance.emit(IveEvent.actionMutationFailed(...))`) already exists** for surfacing failures to the UI — a future receipt/denial event would slot into the same pattern rather than needing a new notification mechanism.

## 4. What WOULD need real decisions (explicitly not started here)

1. **Branch reconciliation** (§5, escalated below) — a prerequisite, not a detail.
2. **Which executor runs AEF in production** — the persistence-layer branch's own docs already flag this as an open, Owner-deferred question (`AEF_PRODUCTION_READINESS.md`'s own "executor decision pending").
3. **Registering Action Engine's real actions in AEF's Tool Registry** with real classifications (READ_ONLY/REVERSIBLE/CONSEQUENTIAL) — today's "execute" is a status flip, not a real side-effecting tool; a governed version would need each real action (e.g., actually posting content, actually sending an email) registered as a distinct, classified tool, which does not exist yet for Action Engine's real underlying effects (only for AEF's own mock/LAB tools).
4. **Closing the external agent gap (CAP-011 / `MPA-F04`)** — this repository's own architecture audit already escalated this; it is unrelated to this app's Flutter code and outside this mission's reach (a separate Cloud Run service, separate repo).
5. **A "learn" step does not exist anywhere yet**, in AEF or in Action Engine — this is a net-new capability, not a reconciliation of two existing things.

## 5. ARCHITECTURAL DECISION REQUIRED (escalated, not resolved)

```
CURRENT STATE: `main` has AEF v0 (contracts + in-memory kernel, merged via PR #101/#102).
A separate, still-unmerged branch (`claude/insightvalues-module-architecture`) has the full
persistent/governed/UI layer. This Commercial branch (`claude/commercial-macro-01`, and by
extension every Commercial-track mission this session was built on) diverged from `main`
before either merge and has never been reconciled with either.

PROBLEM: Any real (not just mapped) AEF integration into Action Engine requires AEF's code
to exist on whichever branch does that work. Today it doesn't, on this line of work. Three
independent lines of development (Commercial features, AEF foundation, AEF persistence/LAB)
have been proceeding in parallel without ever merging into a shared base.

OPTIONS:
  A. Reconcile branches first (rebase/merge main's AEF work into the Commercial line, then
     decide separately whether to also pull in the unmerged persistence/LAB branch) before
     any real AEF↔Action-Engine wiring is attempted.
  B. Treat this mapping document as sufficient preparation and defer reconciliation to
     whichever future mission is explicitly chartered to wire AEF into Action Engine —
     that mission would do the reconciliation as its own first step.
  C. Escalate the three-way divergence itself as its own dedicated mission
     (e.g. IV-BRANCH-RECONCILIATION-01) before any further feature work compounds it.

RECOMMENDATION: B for this mission chain's own continuity (matches the "map, don't build"
scope actually granted), but C should not be deferred indefinitely — every commit added to
any of these three lines makes eventual reconciliation more expensive, and this is now the
second mission (after the prior AGENT-ORPHAN investigation) to surface a real, unaddressed
divergence between parallel InsightValues work streams.

RISKS: If left unreconciled, a future "wire AEF into Action Engine" mission will spend real
effort just re-deriving what this document already found, plus resolving merge conflicts
that get larger with every tranche added to either line.

COST/IMPACT: Reconciliation itself was not estimated (out of this mapping tranche's scope) —
20 commits on the `main` side, ~25 on this side, no conflicting file paths found between the
two diffs inspected (AEF work touches only `aef/`/`contracts/aef/`; this session's work
touches `lib/`/`docs/commercial/`/`web/` — a first-pass merge may be low-conflict, but this
was not verified by attempting one).
```

Decision authority: Agente Martins + Paulo, per this mission's own governance policy on architectural escalations. No branch was merged, rebased, or otherwise touched to produce this finding — it was discovered entirely via read-only `git log`/`git merge-base`/`grep` inspection.

## 6. What this tranche explicitly did NOT do

- No AEF dependency added to `pubspec.yaml` or any Dart/TS import.
- No branch merge, rebase, or reconciliation attempt.
- No change to `action_queue_provider.dart`, `action_queue_service.dart`, or any Action Engine/Opportunity Lab screen.
- No new Edge Function, migration, or Supabase schema change.
- No Owner-facing UI change of any kind.

This document is read-only architecture mapping, exactly as scoped.
