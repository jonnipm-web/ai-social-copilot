/**
 * In-memory HumanGateRecord store + the authorization transition
 * (Section 16). TESTS/HARNESS ONLY -- a real deployment needs a durable
 * store; see contracts/aef/README.md's persistence-interface pattern
 * (Section 27 of this mission: interfaces + in-memory implementations
 * now, no migration/table yet).
 *
 * The critical design point, closing Section 16's "fabricated approver:
 * DENY" requirement for REAL, not just by convention: this store does
 * NOT let a caller directly set state=AUTHORIZED with an arbitrary
 * `approver` field and expect it to be trusted. The ONLY way a record
 * can transition to AUTHORIZED is through `authorize()`, which
 * independently resolves the approver's identity via the SAME
 * IdentityResolver used for the original request (Section 7) -- an
 * approver whose credential does not verify can never produce an
 * AUTHORIZED record, no matter what Actor shape they claim. This mirrors,
 * for the approval side, the exact confused-deputy fix F-02 applies to
 * the requesting side.
 */
import { validateHumanGateRecord } from "../contracts/aef/validators.ts";
import type { Actor, HumanGateRecord } from "../contracts/aef/types.ts";
import type { HumanGateResolver, IdentityResolver, RawCredential } from "./types.ts";

export type AuthorizeResult = { ok: true } | { ok: false; reason: string };

/**
 * Codex adversarial review (round 2, Finding 1): `#records` being a true
 * private field stops `(store as any).records.set(...)`, but `resolve()`
 * previously returned the SAME live object stored internally -- a caller
 * could take that reference and mutate its `state`/`approver`/
 * `decided_at`/`audit_ref` fields directly, bypassing `authorize()`'s
 * identity verification entirely (the mutated object IS the stored
 * object, no `.set()` call needed). Symmetrically, `create()` previously
 * stored the caller's OWN object by reference, so a caller retaining
 * their original reference could mutate it after the fact with the same
 * effect. Fixed by defensively cloning on every write AND every read --
 * `structuredClone` is sufficient here since HumanGateRecord is plain
 * JSON-shaped data (strings, nested Actor objects, nulls), no functions
 * or exotic types.
 */
function cloneRecord(record: HumanGateRecord): HumanGateRecord {
  return structuredClone(record);
}

export class InMemoryHumanGateStore implements HumanGateResolver {
  // A true ECMAScript private field (runtime-enforced, unlike TypeScript's
  // compile-time-only `private`) -- Codex adversarial review (round 1,
  // Finding "approval spoofing") correctly demonstrated that
  // `(store as any).records.set(...)` could write a forged AUTHORIZED
  // record directly, bypassing authorize()'s independent approver
  // verification entirely. `#records` cannot be reached that way: there
  // is no `as any` cast that grants access to a `#`-private field from
  // outside this class, in any JS engine. This does not defend against
  // an attacker with arbitrary code execution INSIDE this process (no
  // in-process boundary can, in any language) -- it defends against
  // exactly what was demonstrated: a casual/careless type-cast bypass by
  // legitimate calling code, which is the actual class of mistake this
  // hardening closes.
  #records = new Map<string, HumanGateRecord>();

  constructor(
    private readonly identityResolver: IdentityResolver,
    /** Injectable clock (Section 20 test determinism). Defaults to real time. Distinct from the kernel's own injected clock so a gate's creation/authorization time and the kernel's evaluation time can be tested independently. */
    private readonly now: () => Date = () => new Date(),
  ) {}

  /** Seeds a gate in REQUESTED/REVIEW_REQUIRED state -- the only states a caller may create directly. Never accepts AUTHORIZED/REJECTED/EXECUTED here (those only exist via authorize()/reject()). */
  create(record: HumanGateRecord): void {
    if (record.state !== "REQUESTED" && record.state !== "REVIEW_REQUIRED") {
      throw new Error(
        `InMemoryHumanGateStore.create: only REQUESTED/REVIEW_REQUIRED records may be seeded directly (got '${record.state}') -- use authorize()/reject() for terminal states, so approver identity is always independently verified`,
      );
    }
    const check = validateHumanGateRecord(record, { now: this.now() });
    if (!check.ok) {
      throw new Error(`InMemoryHumanGateStore.create: refusing to store an invalid HumanGateRecord: ${check.errors?.join("; ")}`);
    }
    this.#records.set(record.gate_id, cloneRecord(record));
  }

  /** Returns a defensive CLONE -- never the live stored object (Codex round-2, Finding 1). Mutating the returned value has no effect on this store's internal state. */
  resolve(gateId: string): HumanGateRecord | undefined {
    const record = this.#records.get(gateId);
    return record ? cloneRecord(record) : undefined;
  }

  /**
   * The ONLY path to state=AUTHORIZED. Independently verifies `approver`
   * via the kernel's real IdentityResolver before ever writing
   * state=AUTHORIZED. A fabricated approver (unverifiable identity) is
   * rejected here -- the record is left untouched in its current state,
   * so a later HumanGateEvaluator check will correctly see "not
   * AUTHORIZED" and DENY (Section 16/29 test #19).
   */
  async authorize(
    gateId: string,
    approver: Actor,
    approverCredential: RawCredential,
    decidedAt: Date,
    auditRef: string,
  ): Promise<AuthorizeResult> {
    const existing = this.#records.get(gateId);
    if (!existing) return { ok: false, reason: `no HumanGateRecord found for gate_id '${gateId}'` };
    if (existing.state !== "REQUESTED" && existing.state !== "REVIEW_REQUIRED") {
      return { ok: false, reason: `gate '${gateId}' is in terminal/non-pending state '${existing.state}', cannot authorize` };
    }

    // Independently verify the approver -- and require verifiedType==="user"
    // explicitly (Codex round-1 Finding, area 13: don't just check
    // status==="VERIFIED" and trust whatever type came back).
    const identity = await this.identityResolver.resolve(approver, approverCredential);
    if (identity.status !== "VERIFIED" || identity.verifiedType !== "user") {
      return { ok: false, reason: `approver identity could not be independently verified as a user (status=${identity.status}) -- fabricated or unverifiable approver, gate remains '${existing.state}'` };
    }

    const authorized: HumanGateRecord = {
      ...existing,
      state: "AUTHORIZED",
      approver,
      decided_at: decidedAt.toISOString(),
      audit_ref: auditRef,
    };
    const check = validateHumanGateRecord(authorized, { now: this.now() });
    if (!check.ok) {
      return { ok: false, reason: `resulting AUTHORIZED record failed contract validation: ${check.errors?.join("; ")}` };
    }
    this.#records.set(gateId, cloneRecord(authorized));
    return { ok: true };
  }

  /**
   * Explicit rejection path. The schema requires `approver`/`decided_at`/
   * `audit_ref` for REJECTED too (a rejection is still a recorded human
   * decision, for audit purposes), so this independently verifies the
   * rejecter's identity exactly like authorize() -- rejection grants no
   * authority, but a fabricated *rejecter* claim would still corrupt the
   * audit trail if left unverified.
   */
  async reject(
    gateId: string,
    approver: Actor,
    approverCredential: RawCredential,
    decidedAt: Date,
    auditRef: string,
  ): Promise<AuthorizeResult> {
    const existing = this.#records.get(gateId);
    if (!existing) return { ok: false, reason: `no HumanGateRecord found for gate_id '${gateId}'` };
    if (existing.state !== "REQUESTED" && existing.state !== "REVIEW_REQUIRED") {
      return { ok: false, reason: `gate '${gateId}' is in terminal/non-pending state '${existing.state}', cannot reject` };
    }
    const identity = await this.identityResolver.resolve(approver, approverCredential);
    if (identity.status !== "VERIFIED" || identity.verifiedType !== "user") {
      return { ok: false, reason: `rejecter identity could not be independently verified as a user (status=${identity.status})` };
    }
    this.#records.set(gateId, cloneRecord({
      ...existing,
      state: "REJECTED",
      approver,
      decided_at: decidedAt.toISOString(),
      audit_ref: auditRef,
    }));
    return { ok: true };
  }
}
