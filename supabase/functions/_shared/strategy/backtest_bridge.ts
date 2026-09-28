/**
 * Python Backtest Bridge (TS client) — INSIGHTVALUES-ROBOT-BUILDER-
 * MACRO-06 §12-13.
 *
 * The ONLY code path in this repository that ever calls out to an
 * external process for a backtest. Every call:
 *   - is refused up front by engine_registry.ts if the engine/rule/
 *     dataset combination is not on the allowlist (never reaches fetch);
 *   - is bounded by an AbortController timeout (the realistic place to
 *     enforce "bounded execution" for a bridge to a synchronous,
 *     stdlib-only HTTP service -- see tools/backtest_bridge/
 *     backtest_service.py's own header comment for why no OS-level
 *     sandboxing exists on the Python side beyond that);
 *   - sends only numeric/string PARAMETERS derived from an already
 *     server-validated StrategySpecification, never a path, never a
 *     module name, never anything resembling code.
 */
import type { StrategySpecification } from './strategy_spec.ts';
import { engineAcceptsRunRequest } from './engine_registry.ts';
import { fail, ok, type StrategyResult } from './errors.ts';

export interface BacktestBridgeConfig {
  readonly baseUrl: string;
  readonly timeoutMs: number;
}

export const DEFAULT_BRIDGE_TIMEOUT_MS = 30_000;

export interface BridgeCostConfig {
  readonly brokeragePerContract: number;
  readonly exchangeFeePerContract: number;
  readonly slippageTicks: number;
}

export interface BacktestBridgeSuccess {
  readonly engine: string;
  readonly datasetId: string;
  readonly datasetHash: string;
  readonly tradeCount: number;
  readonly longCount: number;
  readonly shortCount: number;
  readonly wins: number;
  readonly losses: number;
  readonly netPnl: number;
  readonly grossPnl: number;
  readonly grossProfit: number;
  readonly grossLoss: number;
  readonly totalCost: number;
  readonly targetTouches: number;
  readonly stopTouches: number;
  readonly executionAmbiguityCount: number;
  readonly resultHash: string;
}

function specToV10Params(spec: StrategySpecification, costConfig: BridgeCostConfig | null) {
  return {
    quantity: spec.positionSize.quantity,
    stop_distance: spec.stop.distance,
    target_distance: spec.target.distance,
    break_even_trigger: spec.breakEven?.triggerDistance ?? null,
    break_even_initial: spec.breakEven?.initialProtectedDistance ?? null,
    break_even_step: spec.breakEven?.stepDistance ?? null,
    ...(costConfig
      ? {
        cost_config: {
          brokerage_per_contract: costConfig.brokeragePerContract,
          exchange_fee_per_contract: costConfig.exchangeFeePerContract,
          slippage_ticks: costConfig.slippageTicks,
        },
      }
      : {}),
  };
}

export interface BridgeEngineAvailability {
  readonly available: boolean;
  readonly reason: string | null;
}

/**
 * MACRO-07 §5: queries the bridge's GET /health so a caller can know
 * whether PAULO_TREND_FIBONACCI_V10 is actually usable right now
 * (operator-configured local dataset/pythonpath present) BEFORE
 * spending a POST /backtest round-trip. Never throws -- an unreachable
 * or slow bridge is reported as unavailable, exactly like any other
 * "the engine isn't ready" case, never as an exception a caller must
 * remember to catch.
 */
export async function checkEngineAvailability(
  config: BacktestBridgeConfig,
): Promise<BridgeEngineAvailability> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), config.timeoutMs);
  try {
    const res = await fetch(`${config.baseUrl}/health`, { signal: controller.signal });
    const body = await res.json().catch(() => null);
    const entry = body?.engines?.PAULO_TREND_FIBONACCI_V10;
    if (!res.ok || !body?.ok || !entry || typeof entry.available !== 'boolean') {
      return { available: false, reason: 'backtest bridge health check returned an unexpected response' };
    }
    return { available: entry.available, reason: entry.reason ?? null };
  } catch (e) {
    const timedOut = e instanceof Error && e.name === 'AbortError';
    return { available: false, reason: timedOut ? 'backtest bridge health check timed out' : 'backtest bridge unreachable' };
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Runs Strategy #001/V10 through the external Python bridge. Refuses
 * closed before any network call if the engine registry does not accept
 * this (engineId, rules, datasetId) combination.
 */
export async function runV10ViaBridge(
  config: BacktestBridgeConfig,
  datasetId: string,
  spec: StrategySpecification,
  costConfig: BridgeCostConfig | null,
): Promise<StrategyResult<BacktestBridgeSuccess>> {
  const ruleIds = [
    spec.entry.ruleId, spec.stop.ruleId, spec.target.ruleId,
    ...(spec.breakEven ? [spec.breakEven.ruleId] : []),
    spec.session.ruleId, spec.forcedExit.ruleId, spec.positionSize.ruleId,
  ];
  const refusal = engineAcceptsRunRequest('PAULO_TREND_FIBONACCI_V10', ruleIds, datasetId);
  if (refusal) return fail('DATA_REQUIREMENT_UNMET', refusal);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), config.timeoutMs);
  try {
    const res = await fetch(`${config.baseUrl}/backtest`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        engine: 'PAULO_TREND_FIBONACCI_V10',
        dataset_id: datasetId,
        params: specToV10Params(spec, costConfig),
      }),
      signal: controller.signal,
    });
    const body = await res.json().catch(() => null);
    if (!body || typeof body !== 'object') return fail('DATA_REQUIREMENT_UNMET', 'backtest bridge returned a non-JSON response');
    if (!body.ok) {
      return fail('DATA_REQUIREMENT_UNMET', `backtest bridge refused: ${body.error ?? 'UNKNOWN'}`, {
        detail: String(body.detail ?? ''),
      });
    }
    return ok({
      engine: String(body.engine),
      datasetId: String(body.dataset_id),
      datasetHash: String(body.dataset_hash),
      tradeCount: Number(body.trade_count),
      longCount: Number(body.long_count),
      shortCount: Number(body.short_count),
      wins: Number(body.wins),
      losses: Number(body.losses),
      netPnl: Number(body.net_pnl),
      grossPnl: Number(body.gross_pnl),
      grossProfit: Number(body.gross_profit),
      grossLoss: Number(body.gross_loss),
      totalCost: Number(body.total_cost),
      targetTouches: Number(body.target_touches),
      stopTouches: Number(body.stop_touches),
      executionAmbiguityCount: Number(body.execution_ambiguity_count),
      resultHash: String(body.result_hash),
    });
  } catch (e) {
    const timedOut = e instanceof Error && e.name === 'AbortError';
    return fail('DATA_REQUIREMENT_UNMET', timedOut ? 'backtest bridge timed out' : 'backtest bridge unreachable');
  } finally {
    clearTimeout(timer);
  }
}
