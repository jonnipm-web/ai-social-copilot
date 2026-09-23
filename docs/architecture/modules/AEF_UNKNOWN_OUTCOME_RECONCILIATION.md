# UNKNOWN_OUTCOME Reconciliation

Mission `IV-AEF-HARDENING-01`. RPC `aef_reconcile`, table
`aef_reconciliations`, service methods `AefGovernance.reconcile` /
`reconcileByOperator`. Tests: H06, HP-01..HP-08, RV-*.

## Baseline (unchanged)

Timeout, crash, throw or an undeclared failure → `UNKNOWN_OUTCOME` (terminal
for automation). No automatic retry; a late completion is refused; the tool
may have applied its effect anyway.

## Decision: option A — append-only complementary record

The operation **stays** `UNKNOWN_OUTCOME` and its original receipt is never
touched. A reconciliation is a separate, immutable record with its own
receipt (`aef-receipt/1.1`, `receipt_kind: RECONCILIATION`) that references
the original receipt by id and hash and is anchored in the subject's hash
chain (`RECONCILIATION_RECORDED`, `ref_hash` = its receipt hash).

Why not a new operation state: the state machine's terminal states are
immutable by construction (guard triggers); a new transition out of a
terminal state would weaken that guarantee for every operation. Keeping the
operation as recorded and adding evidence beside it preserves history.

## Verdicts

| Verdict | Meaning |
|---|---|
| `CONFIRMED_APPLIED` | the effect is established to have happened |
| `CONFIRMED_NOT_APPLIED` | the effect is established not to have happened |
| *(no record)* | still unknown — `REMAINS_UNKNOWN` to the caller; nothing is written |

There is no "SUCCEEDED" verdict: reconciliation never turns an unknown
outcome into a success of the original execution; it records what was
established afterwards, by whom, and on what evidence.

## Authority

| Reconciler | Accepted only if | Identity in the receipt |
|---|---|---|
| `VERIFIER` | a server-side verifier (`ReconciliationVerifierRegistry`, sealed) that queries the external system, **and** registered for the operation's tool in `aef_reconciliation_verifiers` (owner-managed, empty by default) | `sha256('aef-reconciler/1:VERIFIER:' || id)` |
| `OPERATOR` | a verified user with role `admin` in `subject_roles`, who is **not** the operation's subject, whose account still exists and who was never erased (Codex HG1-02) | `sha256('aef-reconciler/1:OPERATOR:' || uuid)` only — the raw operator id is never stored (Codex HG3-03) |

The subject can *ask* for a verifier check (`reconcile`) but can never
supply a verdict; a request carrying a verdict is refused (`INPUT_REJECTED`).
Refused attempts are audited (`RECONCILIATION_DENIED`).

## Record content (minimized)

verdict · reconciler kind + hashed reference · evidence kind (code) +
`sha256` of the evidence reference (≤ 200 chars, never stored in clear) ·
the operation's policy/risk versions **and** the versions in force at
reconciliation · server timestamp · original receipt id/hash · binding hash.

## Guarantees (tested)

- One reconciliation per operation (`UNIQUE`); 40 concurrent attempts →
  exactly one (HP-05); later ones `ALREADY_RECONCILED`.
- Only `UNKNOWN_OUTCOME` operations (`NOT_RECONCILABLE` otherwise, including
  one still `EXECUTING` while recovery races — HP-07).
- Never re-executes, never compensates; replay returns the operation, the
  original receipt and the reconciliation (H06n, HP-06).
- Inconclusive / failing / slow verifier → nothing recorded (HP-02).
- Forged or altered reconciliation receipts are refused by
  `aef_verify_receipt` (H06m); the receipt must stay anchored, the chain
  intact, and the referenced original receipt must exist with exactly the
  referenced hash — enforced at insert (guard) and at verification, so even
  an owner-level re-pointing with every hash recomputed is refused
  (`RECEIPT_ORIGINAL_MISMATCH`, Codex HG3-02, H11).
- Reconciled operations become purgeable only after the reconciliation
  itself is past retention; unreconciled ones never are (H03b, HP-08).
