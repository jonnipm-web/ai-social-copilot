/**
 * Canonical Backtest Result — INSIGHTVALUES-ROBOT-BUILDER-MACRO-05 §26.
 *
 * The reusable result contract a backtest engine's output is mapped INTO
 * before the rest of the product (Quant analysis, IVE Strategy Analyst,
 * comparison, learning) ever sees it. This module does not RUN a backtest
 * -- Strategy #001 continues executing in the Python reference
 * implementation (§25), and this macro builds no live Python<->Supabase
 * execution bridge (that would be new infrastructure §22/§46 gives no
 * mandate for). `buildCanonicalBacktestResult` is the one place a
 * completed run's numbers (from Python today, from any future engine
 * later) become this product's canonical shape.
 */
import { sha256Hex } from '../../../../aef/persistence/canonical.ts';
import { fail, ok, type StrategyResult } from './errors.ts';

/** How the net/gross figures in this result were produced. Mirrors the
 * Python reference's ZERO_COST_RESEARCH/cost-adjusted distinction (§10) so
 * a UI/IVE consumer never has to guess whether costs are already applied. */
export type BacktestMethodologyStatus = 'ZERO_COST_RESEARCH' | 'COST_ADJUSTED';

export interface BacktestCostAssumptions {
  readonly brokeragePerContract: number;
  readonly exchangeFeePerContract: number;
  readonly slippageTicks: number;
  readonly source: string;
}

export interface CanonicalBacktestResultInput {
  readonly strategyId: string;
  readonly strategyVersion: number;
  readonly strategySpecHash: string;
  readonly datasetId: string;
  readonly datasetHash: string;
  readonly instrumentSymbol: string;
  readonly periodStart: string; // ISO 8601
  readonly periodEnd: string; // ISO 8601
  readonly timeframes: readonly string[];
  readonly tradeCount: number;
  readonly longCount: number;
  readonly shortCount: number;
  readonly wins: number;
  readonly losses: number;
  readonly grossPnl: number;
  /** Sum of winning trades' gross P&L (>= 0). Needed to compute
   * profitFactor honestly -- grossPnl alone (net of winners and losers)
   * cannot be decomposed back into a profit/loss ratio. */
  readonly grossProfit: number;
  /** Sum of losing trades' gross P&L, as a positive magnitude (>= 0). */
  readonly grossLoss: number;
  readonly totalCost: number;
  readonly netPnl: number;
  readonly maxDrawdown: number | null;
  readonly targetTouches: number;
  readonly stopTouches: number;
  /** Trades whose execution price had to fall back to a gap/ambiguous
   * source (Python reference's `execution_price_source` != TARGET_LEVEL/
   * STOP_LEVEL, e.g. BAR_OPEN_GAP) -- surfaced explicitly, never hidden
   * inside an aggregate (§11, §12: "19 BAR_OPEN_GAP cases remain
   * potentially ambiguous"). */
  readonly executionAmbiguityCount: number;
  readonly methodologyStatus: BacktestMethodologyStatus;
  readonly costAssumptions: BacktestCostAssumptions | null;
  readonly limitations: readonly string[];
  /** Free-text provenance pointer (e.g. "Python reference implementation,
   * codex/qt01c36-... @ 4b9eb19b, local worktree"). Not a structured
   * EvidenceConfidenceTier itself -- that classification happens where
   * this result is CONSUMED (IVE Strategy Analyst), not here. */
  readonly provenance: string;
}

export interface CanonicalBacktestResult extends CanonicalBacktestResultInput {
  readonly profitFactor: number | null;
  readonly expectancy: number | null;
  readonly resultHash: string;
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

/** Deterministic hash over the fields that define "the same result" --
 * strategy identity/version, dataset, cost methodology and outcome. Two
 * runs of the same spec against the same dataset with the same cost
 * assumptions must hash identically; anything else must not. */
async function computeResultHash(input: CanonicalBacktestResultInput): Promise<string> {
  const basis = [
    input.strategyId,
    String(input.strategyVersion),
    input.strategySpecHash,
    input.datasetId,
    input.datasetHash,
    input.methodologyStatus,
    String(input.tradeCount),
    String(input.netPnl),
  ].join('|');
  const full = await sha256Hex(basis);
  return full.slice(0, 16);
}

export async function buildCanonicalBacktestResult(
  input: CanonicalBacktestResultInput,
): Promise<StrategyResult<CanonicalBacktestResult>> {
  if (!input || typeof input !== 'object') return fail('INVALID_STRATEGY_SPEC', 'backtest result input must be an object');
  if (input.tradeCount < 0 || input.longCount < 0 || input.shortCount < 0) {
    return fail('INVALID_STRATEGY_SPEC', 'trade counts cannot be negative');
  }
  if (input.longCount + input.shortCount !== input.tradeCount) {
    return fail('INVALID_STRATEGY_SPEC', 'longCount + shortCount must equal tradeCount', {
      longCount: input.longCount,
      shortCount: input.shortCount,
      tradeCount: input.tradeCount,
    });
  }
  if (input.wins + input.losses > input.tradeCount) {
    return fail('INVALID_STRATEGY_SPEC', 'wins + losses cannot exceed tradeCount');
  }
  if (input.methodologyStatus === 'ZERO_COST_RESEARCH' && input.totalCost !== 0) {
    return fail('INVALID_STRATEGY_SPEC', 'ZERO_COST_RESEARCH must have zero total cost', { totalCost: input.totalCost });
  }
  if (input.methodologyStatus === 'COST_ADJUSTED' && !input.costAssumptions) {
    return fail('INVALID_STRATEGY_SPEC', 'COST_ADJUSTED requires costAssumptions to be stated');
  }

  if (input.grossProfit < 0 || input.grossLoss < 0) {
    return fail('INVALID_STRATEGY_SPEC', 'grossProfit/grossLoss must be non-negative magnitudes');
  }
  const profitFactor = input.grossLoss > 0 ? round2(input.grossProfit / input.grossLoss) : null;
  const expectancy = input.tradeCount > 0 ? round2(input.netPnl / input.tradeCount) : null;

  const resultHash = await computeResultHash(input);

  const out: CanonicalBacktestResult = Object.freeze({
    ...input,
    timeframes: Object.freeze([...input.timeframes]),
    limitations: Object.freeze([...input.limitations]),
    costAssumptions: input.costAssumptions ? Object.freeze({ ...input.costAssumptions }) : null,
    profitFactor,
    expectancy,
    resultHash,
  });
  return ok(out);
}
