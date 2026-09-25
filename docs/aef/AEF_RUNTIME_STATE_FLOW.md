# AEF Runtime State Flow

Mission `IV-IVE-AEF-RUNTIME-INTEGRATION-01`. The persistent state machine is
unchanged: it is enforced by the PostgreSQL functions of `20260925`/`20260926`.
The runtime adapter cannot skip a state, because it only calls
`AefGovernance`.

```
                  (client only)
                    PROPOSED
                       │ propose
                       ▼
                AWAITING_APPROVAL ──reject──▶ REJECTED (terminal, NOT_EXECUTED)
                  │     │ gate TTL ───────────▶ EXPIRED  (terminal, NOT_EXECUTED)
                  │     │ cancel ─────────────▶ CANCELLED (terminal)
                  │     │ policy version change ▶ INVALIDATED (terminal)
                  │ approve (bound: gate id + binding hash + subject)
                  ▼
                AUTHORIZED ──cancel / TTL / policy change──▶ CANCELLED / EXPIRED / INVALIDATED
                  │ execute (same proposal) → claim (lease, attempt 0→1)
                  ▼
                EXECUTING ──lease expires (crash)──▶ UNKNOWN_OUTCOME (via recovery)
                  │ tool result, persisted
                  ├──▶ SUCCEEDED        receipt SUCCESS   → "done" (only here)
                  ├──▶ FAILED           receipt FAILURE / PARTIAL
                  └──▶ UNKNOWN_OUTCOME  receipt UNKNOWN_OUTCOME
                                        (timeout, throw, undeclared failure,
                                         or a completion that could not be
                                         persisted) — never retried; needs
                                         reconciliation (verifier; operator
                                         path OFF, D4); blocks erasure (D2)
```

## Presentation mapping

| Governance result | Phase | `completed` | `reconciliationRequired` |
|---|---|---|---|
| DENIED | DENIED | false | false |
| AWAITING_APPROVAL | AWAITING_APPROVAL (with gate) | false | false |
| AUTHORIZED / EXECUTING | same | false | false |
| FINAL + SUCCEEDED + SUCCESS receipt | SUCCEEDED | **true** | false |
| FINAL + any other terminal state | that state | false | UNKNOWN_OUTCOME only |
| OUTCOME_UNCONFIRMED | UNKNOWN_OUTCOME | false | true |
| REMAINS_UNKNOWN | UNKNOWN_OUTCOME | false | true |

`retryAllowed` is always false.
