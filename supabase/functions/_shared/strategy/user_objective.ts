/**
 * User Objective Profile & Risk Constraints —
 * INSIGHTVALUES-STRATEGY-INTELLIGENCE-MACRO-07 §11-12.
 *
 * A research objective a user attaches to a strategy version. It shapes
 * analysis/ranking/IVE recommendation language (§11) -- it NEVER
 * authorizes trading, and checking a constraint against HISTORICAL data
 * never implies future compliance (§12) -- every compliance report this
 * module produces carries `historicalComplianceDoesNotGuaranteeFuture:
 * true` unconditionally, not as an optional flag someone could omit.
 */
import type { StrategySpecification, Direction } from './strategy_spec.ts';
import type { CanonicalBacktestResult } from './backtest_result.ts';
import { fail, ok, type StrategyResult } from './errors.ts';

export type StrategyObjective =
  | 'CAPITAL_PRESERVATION'
  | 'LOW_DRAWDOWN'
  | 'BALANCED'
  | 'RETURN_WITHIN_RISK_LIMIT'
  | 'STABILITY'
  | 'LOW_FREQUENCY'
  | 'CUSTOM_CONSTRAINTS';

export const STRATEGY_OBJECTIVES: readonly StrategyObjective[] = Object.freeze([
  'CAPITAL_PRESERVATION', 'LOW_DRAWDOWN', 'BALANCED', 'RETURN_WITHIN_RISK_LIMIT', 'STABILITY', 'LOW_FREQUENCY', 'CUSTOM_CONSTRAINTS',
]);

export interface RiskConstraints {
  readonly maxAcceptableDrawdown?: number;
  readonly maxPositionSize?: number;
  readonly maxSimulatedDailyLoss?: number;
  readonly maxTradeFrequencyPerDay?: number;
  readonly allowedDirections?: readonly Direction[];
}

export interface UserObjectiveProfileInput {
  readonly objective: StrategyObjective;
  readonly riskConstraints?: RiskConstraints;
  readonly notes?: string;
}

export interface UserObjectiveProfile {
  readonly objective: StrategyObjective;
  readonly riskConstraints: RiskConstraints;
  readonly notes: string | null;
}

const MAX_NOTES_LENGTH = 500;

function isFinitePositive(x: unknown): x is number {
  return typeof x === 'number' && Number.isFinite(x) && x > 0;
}

export function createUserObjectiveProfile(input: UserObjectiveProfileInput): StrategyResult<UserObjectiveProfile> {
  if (!input || typeof input !== 'object') return fail('INVALID_STRATEGY_SPEC', 'objective profile must be an object');
  if (!STRATEGY_OBJECTIVES.includes(input.objective)) {
    return fail('INVALID_STRATEGY_SPEC', 'unknown objective', { field: 'objective', value: String(input.objective) });
  }
  const c = input.riskConstraints ?? {};
  for (const field of ['maxAcceptableDrawdown', 'maxPositionSize', 'maxSimulatedDailyLoss', 'maxTradeFrequencyPerDay'] as const) {
    const v = c[field];
    if (v !== undefined && !isFinitePositive(v)) {
      return fail('INVALID_RISK_PARAMETER', `${field} must be a finite number > 0 when provided`, { field });
    }
  }
  if (c.allowedDirections !== undefined) {
    if (!Array.isArray(c.allowedDirections) || c.allowedDirections.length === 0) {
      return fail('INVALID_RISK_PARAMETER', 'allowedDirections must be a non-empty array when provided', { field: 'allowedDirections' });
    }
    for (const d of c.allowedDirections) {
      if (d !== 'LONG' && d !== 'SHORT') return fail('INVALID_RISK_PARAMETER', 'allowedDirections entries must be LONG or SHORT', { field: 'allowedDirections' });
    }
  }
  if (input.notes !== undefined && (typeof input.notes !== 'string' || input.notes.length > MAX_NOTES_LENGTH)) {
    return fail('INVALID_STRATEGY_SPEC', `notes must be a string of at most ${MAX_NOTES_LENGTH} characters`, { field: 'notes' });
  }
  return ok(Object.freeze({
    objective: input.objective,
    riskConstraints: Object.freeze({ ...c, ...(c.allowedDirections ? { allowedDirections: Object.freeze([...c.allowedDirections]) } : {}) }),
    notes: input.notes ?? null,
  }));
}

export type ConstraintStatus = 'COMPLIANT' | 'VIOLATED' | 'UNKNOWN';

export interface RiskConstraintCheck {
  readonly constraint: string;
  readonly limit: number;
  readonly measured: number | null;
  readonly status: ConstraintStatus;
  /** Present only for UNKNOWN -- explains what data would be needed,
   * never silently omitted. */
  readonly unknownReason?: string;
}

export interface RiskComplianceReport {
  readonly checks: readonly RiskConstraintCheck[];
  readonly anyViolated: boolean;
  readonly anyUnknown: boolean;
  readonly historicalComplianceDoesNotGuaranteeFuture: true;
}

/** Checks the constraints that are properties of the CONFIGURATION
 * itself (position size, allowed directions) -- no backtest needed,
 * these are either satisfied by the spec or they are not. */
export function checkRiskConstraintsAgainstSpec(
  constraints: RiskConstraints,
  spec: StrategySpecification,
): RiskComplianceReport {
  const checks: RiskConstraintCheck[] = [];
  if (constraints.maxPositionSize !== undefined) {
    checks.push({
      constraint: 'MAX_POSITION_SIZE',
      limit: constraints.maxPositionSize,
      measured: spec.positionSize.quantity,
      status: spec.positionSize.quantity <= constraints.maxPositionSize ? 'COMPLIANT' : 'VIOLATED',
    });
  }
  if (constraints.allowedDirections !== undefined) {
    const violatesDirection = spec.allowedDirections.some((d) => !constraints.allowedDirections!.includes(d));
    checks.push({
      constraint: 'ALLOWED_DIRECTIONS',
      limit: constraints.allowedDirections.length,
      measured: spec.allowedDirections.length,
      status: violatesDirection ? 'VIOLATED' : 'COMPLIANT',
    });
  }
  return Object.freeze({
    checks: Object.freeze(checks),
    anyViolated: checks.some((c) => c.status === 'VIOLATED'),
    anyUnknown: false,
    historicalComplianceDoesNotGuaranteeFuture: true,
  });
}

/** Checks the constraints that can only be evaluated against a REAL,
 * already-persisted backtest result. `maxSimulatedDailyLoss` is
 * reported UNKNOWN, honestly -- CanonicalBacktestResult carries
 * aggregate P&L, not per-day granularity, so no single-day loss figure
 * can be measured from it without fabricating one. */
export function checkRiskConstraintsAgainstResult(
  constraints: RiskConstraints,
  result: CanonicalBacktestResult,
): RiskComplianceReport {
  const checks: RiskConstraintCheck[] = [];
  if (constraints.maxAcceptableDrawdown !== undefined) {
    if (result.maxDrawdown === null) {
      checks.push({
        constraint: 'MAX_ACCEPTABLE_DRAWDOWN',
        limit: constraints.maxAcceptableDrawdown,
        measured: null,
        status: 'UNKNOWN',
        unknownReason: 'this backtest result did not measure maxDrawdown',
      });
    } else {
      checks.push({
        constraint: 'MAX_ACCEPTABLE_DRAWDOWN',
        limit: constraints.maxAcceptableDrawdown,
        measured: result.maxDrawdown,
        status: Math.abs(result.maxDrawdown) <= constraints.maxAcceptableDrawdown ? 'COMPLIANT' : 'VIOLATED',
      });
    }
  }
  if (constraints.maxTradeFrequencyPerDay !== undefined) {
    const periodMs = Date.parse(result.periodEnd) - Date.parse(result.periodStart);
    const periodDays = periodMs / 86_400_000;
    if (!(periodDays > 0)) {
      checks.push({
        constraint: 'MAX_TRADE_FREQUENCY_PER_DAY',
        limit: constraints.maxTradeFrequencyPerDay,
        measured: null,
        status: 'UNKNOWN',
        unknownReason: 'result period is zero-length; trades-per-day is not computable',
      });
    } else {
      const tradesPerDay = result.tradeCount / periodDays;
      checks.push({
        constraint: 'MAX_TRADE_FREQUENCY_PER_DAY',
        limit: constraints.maxTradeFrequencyPerDay,
        measured: tradesPerDay,
        status: tradesPerDay <= constraints.maxTradeFrequencyPerDay ? 'COMPLIANT' : 'VIOLATED',
      });
    }
  }
  if (constraints.maxSimulatedDailyLoss !== undefined) {
    checks.push({
      constraint: 'MAX_SIMULATED_DAILY_LOSS',
      limit: constraints.maxSimulatedDailyLoss,
      measured: null,
      status: 'UNKNOWN',
      unknownReason: 'CanonicalBacktestResult carries aggregate P&L only, not per-day granularity',
    });
  }
  return Object.freeze({
    checks: Object.freeze(checks),
    anyViolated: checks.some((c) => c.status === 'VIOLATED'),
    anyUnknown: checks.some((c) => c.status === 'UNKNOWN'),
    historicalComplianceDoesNotGuaranteeFuture: true,
  });
}
