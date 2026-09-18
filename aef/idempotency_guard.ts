/**
 * IdempotencyGuard (Section 19/20). Sits right before tool execution in
 * the pipeline (Section 3's stated order: ... -> Human Gate -> Idempotency
 * -> Controlled Tool Registry -> Mock Execution -> ...) -- replay/
 * idempotency checks are deliberately NOT consumed earlier, so a request
 * that gets DENIED at the policy/human-gate stage never burns its
 * request_id or idempotency_key. This mirrors the same principle
 * contracts/aef's Finding F-05 fix already applies at the contract layer
 * (replay checks run only after all other validation passes).
 *
 * Three distinct concepts, deliberately not conflated (see
 * contracts/aef/README.md):
 *   - request_id  -> pure execution-replay defense (exact same request
 *                    sent twice, e.g. a network-level retry or replay
 *                    attack). Reuses contracts/aef's RequestIdStore.
 *   - idempotency_key -> business idempotency (a legitimate client retry
 *                    after a timeout gets a NEW request_id but the SAME
 *                    idempotency_key -- "don't double-execute the same
 *                    business operation").
 *   - nonce       -> DelegationEnvelope authentication replay, handled
 *                    entirely inside contracts/aef/validators.ts, not
 *                    duplicated here.
 *
 * Concurrency (Section 20): naive get()-then-later-put() on a Map is a
 * TOCTOU race under Deno's single-threaded-but-interleaving-at-await
 * event loop -- two concurrent submissions for the same idempotency_key
 * can both observe "not found" before either finishes and both execute a
 * CONSEQUENTIAL tool. `claim()` closes this by being synchronous
 * (no `await` inside it) and atomic-by-construction: it reads AND writes
 * the map in one non-interleavable step, exactly like
 * contracts/aef's NonceStore.tryConsume().
 */
import type { ExecutionRequest } from "../contracts/aef/types.ts";
import type { KernelResult } from "./types.ts";
import type { RequestIdStore } from "../contracts/aef/types.ts";

export type ClaimOutcome =
  | { status: "CLAIMED" }
  | { status: "IN_FLIGHT" }
  | { status: "COMPLETED"; result: KernelResult }
  | { status: "REQUEST_ID_REPLAYED" };

/**
 * In-memory, single-process idempotency-key store. TESTS/HARNESS ONLY
 * (Section 20: "Classificar implementação: IN_MEMORY_ONLY. Persistência
 * distribuída pertence a gate posterior.") -- a real deployment needs a
 * durable store with a real unique-constraint/compare-and-swap guarantee
 * (e.g. a DB unique index + INSERT ... ON CONFLICT), exactly per
 * contracts/aef's own InMemoryNonceStore caveat.
 */
export class InMemoryIdempotencyStore {
  private readonly entries = new Map<string, KernelResult | "IN_FLIGHT">();

  /** Synchronous, atomic claim -- no await inside, so no interleaving window exists between the read and the write. */
  claim(key: string): "CLAIMED" | "IN_FLIGHT" | { COMPLETED: KernelResult } {
    const existing = this.entries.get(key);
    if (existing === undefined) {
      this.entries.set(key, "IN_FLIGHT");
      return "CLAIMED";
    }
    if (existing === "IN_FLIGHT") return "IN_FLIGHT";
    // Codex round-4 adversarial review (P2, systematic aliasing sweep):
    // returning the stored object by reference let a caller mutate a
    // completed result (e.g. `result.receipt.outcome = "..."`), and that
    // mutation would corrupt what a LATER duplicate lookup returns, since
    // it is the exact same object. KernelResult/ExecutionReceipt are
    // plain JSON-shaped data (no functions), so structuredClone is a
    // correct, cheap defensive copy here -- same pattern already applied
    // to HumanGateRecord in human_gate_store.ts (round-2 Finding 1).
    return { COMPLETED: structuredClone(existing) };
  }

  complete(key: string, result: KernelResult): void {
    this.entries.set(key, structuredClone(result));
  }

  /** Releases a claim without recording a result -- used when the attempt failed for a reason that should NOT permanently block retries (e.g. a transient tool failure), so a legitimate retry with the same idempotency_key is not wedged forever behind a stale IN_FLIGHT marker. */
  release(key: string): void {
    if (this.entries.get(key) === "IN_FLIGHT") this.entries.delete(key);
  }
}

export class IdempotencyGuard {
  constructor(
    private readonly requestIdStore: RequestIdStore,
    private readonly idempotencyStore: InMemoryIdempotencyStore,
  ) {}

  checkBeforeExecution(request: ExecutionRequest): ClaimOutcome {
    // Business idempotency first: a legitimate retry (new request_id,
    // same idempotency_key) of an already-completed operation must
    // return the SAME result, never re-execute.
    if (request.idempotency_key) {
      const claim = this.idempotencyStore.claim(request.idempotency_key);
      if (claim === "IN_FLIGHT") return { status: "IN_FLIGHT" };
      if (typeof claim === "object") return { status: "COMPLETED", result: claim.COMPLETED };
      // claim === "CLAIMED": fall through to the request_id check below.
    }

    // Pure execution-replay defense: the exact same request_id must
    // never be allowed to reach tool execution twice, with or without an
    // idempotency_key.
    const firstTime = this.requestIdStore.tryConsume(request.request_id);
    if (!firstTime) {
      if (request.idempotency_key) this.idempotencyStore.release(request.idempotency_key);
      return { status: "REQUEST_ID_REPLAYED" };
    }

    return { status: "CLAIMED" };
  }

  recordCompletion(request: ExecutionRequest, result: KernelResult): void {
    if (request.idempotency_key) this.idempotencyStore.complete(request.idempotency_key, result);
  }

  /** For a failure that occurred before any real side effect (e.g. the tool itself threw), release the idempotency claim so a legitimate retry is not wedged forever -- but request_id remains consumed (that exact wire message must never be reprocessed, regardless of outcome). */
  releaseOnTechnicalFailure(request: ExecutionRequest): void {
    if (request.idempotency_key) this.idempotencyStore.release(request.idempotency_key);
  }
}
