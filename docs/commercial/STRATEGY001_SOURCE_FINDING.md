# Strategy001 / "Paulo Trend Fibonacci" — source verification finding

**Mission:** INSIGHTVALUES-INTELLIGENCE-AUTOMATION-MACRO-04, §13 ("Locate the
REAL existing Strategy001 / Paulo Trend Fibonacci implementation/assets
identified by prior reconciliation. Use repository/history/available local
project evidence. Do not invent algorithm logic.")

---

## UPDATE — INSIGHTVALUES-ROBOT-BUILDER-MACRO-05 (2026-09-27)

**The real source was found.** Macro-05's §5 mandated recovering
`C:\Users\jpaul\Documents\Codex\2026-08-10\referenced-chatgpt-conversation-
this-is-an\insightvalues-quant` (a LOCAL worktree, not the GitHub remote
this MACRO-04 finding investigated) before any other work. That worktree:

- is a real git checkout, branch
  `codex/qt01c36-hierarchical-fibonacci-structural-fidelity` @ `4b9eb19b`,
  remote `https://github.com/jonnipm-web/insightvalues-quant.git` (the SAME
  named repo MACRO-04 found empty on `main`) — the real work existed on an
  unpushed feature branch this environment simply had not looked at before;
- contains a genuine, working `insightvalues_quant/strategy_fidelity/`
  package with V4 through V11 (17 uncommitted/untracked files plus 2
  modified tracked files — see the Macro-05 recovery checkpoint,
  `RECOVERY_MANIFEST.txt`, for the exact list);
- **also** contains a genuine, working `insightvalues_quant/strategy001/`
  package (`engine.py`, `evaluator.py`, `state_machine.py`, `events.py`,
  `models.py`, `config.py`, `audit.py`, `README.md`) and
  `insightvalues_quant/fibonacci/` package (`engine.py`, `anchors.py`,
  `levels.py`, `zones.py`, `lifecycle.py`, `config.py`, `models.py`,
  `audit.py`) — this IS the module the original Tranche 2 positioning doc
  and `strategy001_contracts.dart` describe, directly inspected this time,
  not inferred from a description;
- `strategy001/README.md`'s text is a **word-for-word match** for the
  positioning doc's quote ("This module produces state transitions and
  events only. It never generates BUY, SELL, LONG, SHORT, or any trading
  signal. It never integrates with Backtest, Portfolio, Risk, or any
  broker."), and its documented state machine's event vocabulary
  (TREND_DETECTED, PULLBACK_DETECTED, FIB_READY, CONFIRMATION_1,
  CONFIRMATION_2, READY, TRIGGERED, TARGET_REACHED, EXPANSION_CANDIDATE,
  RESET_REQUIRED, STRATEGY_INVALIDATED) is an exact match for
  `strategy001_contracts.dart`'s `EventKind` enum;
- has **2541 passing tests** (`python -m pytest tests/`, this macro, real
  execution, zero failures) across BOTH packages, including
  `test_strategy001_*.py` (7 files) and `test_fibonacci_*.py` (9 files);
- **exactly reproduces** every historical reference number this macro was
  given for V10 against the real WIN1! TradingView dataset: 75 trades, net
  -R$57.00 (zero cost, hash `c19661f4dfc61193`), net -R$270.75 (with the
  QT-01C.3 Run B cost assumptions, hash `e79067f77120956d`), and exactly 19
  of 75 trades executed at a `BAR_OPEN_GAP` price source — a bit-for-bit
  match, not an approximation.

**What this does and does not change:** the diligence below (the GitHub
`main` branch containing only a README as of MACRO-04) remains factually
correct for that specific branch — it was never wrong, only incomplete: it
never checked local, unpushed worktrees outside the repositories it could
`gh repo list`/clone directly. The original Tranche 2 claim ("Strategy001
lives entirely in the separate `insightvalues-quant` Python repository...
a validated, tested state machine") is now **CORROBORATED**, not merely
no-longer-disproven. `lib/core/quant/strategy001_contracts.dart`'s shape is
confirmed to match this real, tested source. This macro still did NOT
port, reconstruct or modify the Fibonacci/trend/confirmation algorithm
itself (Robot Rule, §14/§56) — it only read and reproduced against it.

**Residual, still-open question (not resolved by this macro):** why the
real work sat on an unpushed local branch while the positioning doc's
"verified against its real source" claim was written seven weeks after
that branch's remote counterpart (`main`) last saw a commit is still
unknown — plausibly the author worked locally and simply never pushed,
which this finding is consistent with but does not prove. This is a
process/handoff question for the Owner, not a code-correctness one.

**Dataset licensing (§39):** the historical WIN1!/WDO1! CSVs
(`BMFBOVESPA_DLY_WIN1_5_1.csv` etc.) are TradingView exports whose
redistribution rights this macro did not assess (that is an Owner/legal
question, not a code one). Per §39's fallback, the raw data was kept
strictly local to the Python worktree: it was never copied into, committed
to, or referenced by path from `ai-social-copilot`. Every reference to it
in this repo (`v10_reference.ts`, `strategy_lab_reference.dart`) is
metadata only -- a dataset id/hash and the already-computed result
numbers, never a row of price data. `DATASET_LICENSE_STATUS: UNCLEAR, NOT
DISTRIBUTED` in the final report reflects exactly this.

---

## What this mission actually verified

`docs/commercial/FINANCIAL_INTELLIGENCE_POSITIONING.md` (written during
Commercial-Macro-01 Tranche 2, commits `088d904`/`c8310dc`) states, under the
heading "What Strategy001 actually is (verified against its real source)":

> Strategy001 ("Paulo Trend Fibonacci") lives entirely in the separate
> `insightvalues-quant` Python repository, at `insightvalues_quant/strategy001/`
> and `insightvalues_quant/fibonacci/`. It is a validated, tested state machine
> (`test_strategy001_*.py`, `test_fibonacci_*.py` — engine, evaluator, state
> machine, golden files, audit trail, all present)...

This mission independently re-verified that claim, per §13's own instruction,
rather than taking it on faith:

1. **GitHub org listing** (`gh repo list jonnipm-web`) confirms a repository
   named `jonnipm-web/insightvalues-quant` exists, described "Quantitative
   trading research and backtesting framework", private.
2. **Cloned it directly** (read-only, this mission's scratchpad). Its entire
   contents: one file, `README.md`, containing only the repo name and
   description. **No `insightvalues_quant/` package, no `strategy001/`
   directory, no `fibonacci/` directory, no test files of any kind.**
3. **Its git history is a single commit**, `73d7ec0`, dated **2026-08-05**,
   message "Initial commit" — no other commits exist, on `main` or any other
   branch (only `main` exists).
4. **The positioning doc's own commits** (`088d904`, `c8310dc`) are dated
   **2026-09-27**, roughly seven weeks *after* that repository's only commit.
   At the moment the doc says the source was "verified", the repository it
   names already contained nothing but that README stub.
5. **Searched this repository's own full git history** (`ai-social-copilot`,
   every branch) for any other mention of `strategy001`/`fibonacci`: the
   *only* commits are the two that created the Dart contract mirror itself.
   No branch, past or present, ever held real Strategy001 algorithm code.
6. **Checked the other locally-available Quant-related checkout and branch**
   (`claude/insightvalues-quant-foundation`, `claude/insightvalues-quant-setup-65c7on`)
   for any trace of Strategy001/Fibonacci content: none found.

## What this means

The claim "verified against its real source" in the positioning doc **cannot
be substantiated from any repository, branch, or local file this mission had
access to.** This is not proof the real Strategy001 engine never existed
anywhere — the discrepancy could be explained by the source living in a
location outside this environment's reach (a different, unlisted repository;
a private location; a machine not available here), or by the repository
having been reset/recreated after an earlier state this environment cannot
see. But it is also not something this mission can respond to by simply
trusting the earlier doc's specific claims (file paths, test file counts, an
exact README quote) as verified fact going forward.

## What this mission did as a result

Per §13 ("do not invent algorithm logic") and §14 (Robot Rule — "do not
create another robot"), this mission did **not** attempt to reconstruct,
port, or approximate the Fibonacci/trend/confirmation algorithm from the
existing Dart contract's shape. `lib/core/quant/strategy001_contracts.dart`
is left exactly as Tranche 2 built it: an inert, harmless type mirror with
zero algorithm logic — nothing about it is false or dangerous on its own,
only its provenance claim is now unverifiable, not disproven.

Instead, this mission built the **safe internal integration seam** §13/§15-16
call for regardless of where the real engine lives: the Quant → Action
Intent → AEF governance bridge (`aef/runtime/quant_tools.ts`,
`supabase/functions/quant-runtime/`, see the mission's final report,
QUANT_TO_ACTION_INTENT_RESULT). That bridge does not depend on Strategy001's
algorithm existing anywhere — it governs *acknowledgment of a structural
signal*, whatever produces it, the same way `action-engine`'s own bridge
governs a self-attested task completion regardless of what triggered it.

## Recommended next step (Owner-level, not resolved by this mission)

Confirm directly with Agente Martins/Paulo where the real Strategy001 /
Paulo Trend Fibonacci implementation actually is. If it exists in a location
this environment cannot reach, either share it with a future mission's
environment or authorize a from-scratch reconstruction with its own full
test suite — a materially different, larger, and separately-scoped
engineering effort from anything this mission attempted.
