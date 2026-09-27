/**
 * Canonical Strategy Specification — INSIGHTVALUES-ROBOT-BUILDER-MACRO-05
 * §13-15, §27.
 *
 * The one machine-readable shape both authoring paths (structured builder,
 * §17; IVE natural-language draft, §16) must produce, and the one shape
 * Quant/backtest consumes (§25-26). Every field is a value the USER
 * configures, not a fact about one particular strategy -- V10 is proven to
 * be representable by this shape in v10_reference.ts, without any
 * V10-specific branch anywhere in this file (§13: "Do NOT hardcode V10 as
 * the schema").
 *
 * Configuration is not authorization: constructing/validating a spec never
 * runs a backtest, never touches AEF, never executes anything (§14).
 */
import {
  createMarketProfile,
  supportsTimeframe,
  type MarketProfile,
  type MarketProfileInput,
} from './market_profile.ts';
import { getRule, type RuleCategory } from './rule_catalog.ts';
import { fail, ok, type StrategyResult } from './errors.ts';

export type Direction = 'LONG' | 'SHORT';

export interface EntryRule {
  readonly ruleId: string; // must resolve to category ENTRY
}

export interface StopRule {
  readonly ruleId: string; // must resolve to category STOP
  readonly distance: number;
}

export interface TargetRule {
  readonly ruleId: string; // must resolve to category TARGET
  readonly distance: number;
}

export interface BreakEvenRule {
  readonly ruleId: string; // must resolve to category BREAK_EVEN
  readonly triggerDistance: number;
  readonly initialProtectedDistance: number;
  readonly stepDistance: number;
}

export interface TrailingRule {
  readonly ruleId: string; // must resolve to category TRAILING
  readonly distance: number;
}

export interface SessionRule {
  readonly ruleId: string; // must resolve to category SESSION
  /** "HH:MM", 24h, local to marketProfile.timezone. */
  readonly startTime: string;
  readonly endTime: string;
  /** ISO weekday numbers, 1=Monday .. 7=Sunday. */
  readonly allowedWeekdays: readonly number[];
}

export interface ForcedExitRule {
  readonly ruleId: string; // must resolve to category EXIT
  readonly time: string; // "HH:MM"
}

export interface PositionSizeRule {
  readonly ruleId: string; // must resolve to category POSITION_SIZE
  readonly quantity: number;
}

export interface RiskLimits {
  readonly maxDailyLossRuleId?: string; // category RISK
  readonly maxDailyLoss?: number;
  readonly maxStrategyLossRuleId?: string; // category RISK
  readonly maxStrategyLoss?: number;
}

export interface StrategySpecification {
  readonly schemaVersion: 1;
  readonly name: string;
  readonly description: string;
  readonly marketProfile: MarketProfile;
  readonly signalTimeframe: string;
  readonly executionTimeframe: string | null;
  readonly allowedDirections: readonly Direction[];
  readonly allowReversals: boolean;
  readonly entry: EntryRule;
  readonly stop: StopRule;
  readonly target: TargetRule;
  readonly breakEven: BreakEvenRule | null;
  readonly trailing: TrailingRule | null;
  readonly session: SessionRule;
  readonly forcedExit: ForcedExitRule;
  readonly positionSize: PositionSizeRule;
  readonly riskLimits: RiskLimits | null;
}

export interface StrategySpecificationInput {
  readonly name: string;
  readonly description?: string;
  readonly marketProfile: MarketProfileInput;
  readonly signalTimeframe: string;
  readonly executionTimeframe?: string | null;
  readonly allowedDirections: readonly Direction[];
  readonly allowReversals: boolean;
  readonly entry: EntryRule;
  readonly stop: StopRule;
  readonly target: TargetRule;
  readonly breakEven?: BreakEvenRule | null;
  readonly trailing?: TrailingRule | null;
  readonly session: SessionRule;
  readonly forcedExit: ForcedExitRule;
  readonly positionSize: PositionSizeRule;
  readonly riskLimits?: RiskLimits | null;
}

const TIME_RE = /^([01]\d|2[0-3]):([0-5]\d)$/;

function timeToMinutes(t: string): number {
  const [h, m] = t.split(':').map(Number);
  return h * 60 + m;
}

/** Codex final audit (P2): a bare `x > 0` check accepts Infinity, and
 * NaN > 0 is false but silent -- both must be explicitly excluded before
 * any range check, everywhere a user-supplied distance/loss limit is
 * validated. */
function isFinitePositive(x: unknown): x is number {
  return typeof x === 'number' && Number.isFinite(x) && x > 0;
}
function isFiniteNonNegative(x: unknown): x is number {
  return typeof x === 'number' && Number.isFinite(x) && x >= 0;
}

function requireRule<T extends string>(ruleId: string, expected: RuleCategory, field: string): StrategyResult<T> {
  const def = getRule(ruleId);
  if (!def) return fail('UNSUPPORTED_RULE', `unknown rule id`, { field, ruleId });
  if (def.category !== expected) {
    return fail('UNSUPPORTED_RULE', `rule is not in category ${expected}`, { field, ruleId, category: def.category });
  }
  return ok(ruleId as T);
}

/**
 * Builds and validates a Strategy Specification from raw input. Fails
 * closed on the first violated invariant (§15) rather than collecting a
 * partial spec and silently reinterpreting the rest.
 */
export function createStrategySpecification(input: StrategySpecificationInput): StrategyResult<StrategySpecification> {
  if (!input || typeof input !== 'object') return fail('INVALID_STRATEGY_SPEC', 'spec must be an object');
  const name = typeof input.name === 'string' ? input.name.trim() : '';
  if (name.length === 0 || name.length > 200) return fail('INVALID_STRATEGY_SPEC', 'name required, max 200 chars', { field: 'name' });

  const marketProfileResult = createMarketProfile(input.marketProfile);
  if (!marketProfileResult.ok) return marketProfileResult;
  const marketProfile = marketProfileResult.value;

  if (!supportsTimeframe(marketProfile, input.signalTimeframe)) {
    return fail('DATA_REQUIREMENT_UNMET', 'signalTimeframe not available for this market profile', {
      field: 'signalTimeframe',
      value: input.signalTimeframe,
    });
  }
  if (input.executionTimeframe && !supportsTimeframe(marketProfile, input.executionTimeframe)) {
    return fail('DATA_REQUIREMENT_UNMET', 'executionTimeframe not available for this market profile', {
      field: 'executionTimeframe',
      value: input.executionTimeframe,
    });
  }

  if (!Array.isArray(input.allowedDirections) || input.allowedDirections.length === 0) {
    return fail('INVALID_STRATEGY_SPEC', 'allowedDirections must be non-empty', { field: 'allowedDirections' });
  }
  for (const d of input.allowedDirections) {
    if (d !== 'LONG' && d !== 'SHORT') return fail('INVALID_STRATEGY_SPEC', 'invalid direction', { field: 'allowedDirections', value: String(d) });
  }
  const dedupedDirections = [...new Set(input.allowedDirections)];

  const entryRuleId = requireRule(input.entry?.ruleId, 'ENTRY', 'entry.ruleId');
  if (!entryRuleId.ok) return entryRuleId;

  if (!isFinitePositive(input.stop?.distance)) return fail('INVALID_RISK_PARAMETER', 'stop distance must be a finite number > 0', { field: 'stop.distance' });
  const stopRuleId = requireRule(input.stop?.ruleId, 'STOP', 'stop.ruleId');
  if (!stopRuleId.ok) return stopRuleId;

  if (!isFinitePositive(input.target?.distance)) return fail('INVALID_RISK_PARAMETER', 'target distance must be a finite number > 0', { field: 'target.distance' });
  const targetRuleId = requireRule(input.target?.ruleId, 'TARGET', 'target.ruleId');
  if (!targetRuleId.ok) return targetRuleId;

  if (input.breakEven && input.trailing) {
    return fail('CONTRADICTORY_CONFIGURATION', 'break-even and trailing cannot both be enabled', {
      field: 'breakEven/trailing',
    });
  }

  let breakEven: BreakEvenRule | null = null;
  if (input.breakEven) {
    const beRuleId = requireRule(input.breakEven.ruleId, 'BREAK_EVEN', 'breakEven.ruleId');
    if (!beRuleId.ok) return beRuleId;
    const { triggerDistance, initialProtectedDistance, stepDistance } = input.breakEven;
    if (!isFinitePositive(triggerDistance)) return fail('INVALID_RISK_PARAMETER', 'break-even trigger must be a finite number > 0', { field: 'breakEven.triggerDistance' });
    if (!isFiniteNonNegative(initialProtectedDistance)) {
      return fail('INVALID_RISK_PARAMETER', 'break-even initial protected distance must be a finite number >= 0', { field: 'breakEven.initialProtectedDistance' });
    }
    if (!isFinitePositive(stepDistance)) return fail('INVALID_RISK_PARAMETER', 'break-even step must be a finite number > 0', { field: 'breakEven.stepDistance' });
    if (triggerDistance >= input.target.distance) {
      return fail('CONTRADICTORY_CONFIGURATION', 'break-even trigger must be below the target distance', {
        field: 'breakEven.triggerDistance',
      });
    }
    if (initialProtectedDistance > triggerDistance) {
      return fail('CONTRADICTORY_CONFIGURATION', 'break-even initial protected distance cannot exceed its own trigger', {
        field: 'breakEven.initialProtectedDistance',
      });
    }
    breakEven = { ...input.breakEven };
  }

  let trailing: TrailingRule | null = null;
  if (input.trailing) {
    const trRuleId = requireRule(input.trailing.ruleId, 'TRAILING', 'trailing.ruleId');
    if (!trRuleId.ok) return trRuleId;
    if (!isFinitePositive(input.trailing.distance)) return fail('INVALID_RISK_PARAMETER', 'trailing distance must be a finite number > 0', { field: 'trailing.distance' });
    trailing = { ...input.trailing };
  }

  const sessionRuleId = requireRule(input.session?.ruleId, 'SESSION', 'session.ruleId');
  if (!sessionRuleId.ok) return sessionRuleId;
  if (!TIME_RE.test(input.session?.startTime ?? '') || !TIME_RE.test(input.session?.endTime ?? '')) {
    return fail('INVALID_SESSION_WINDOW', 'session times must be HH:MM', { field: 'session' });
  }
  if (timeToMinutes(input.session.startTime) >= timeToMinutes(input.session.endTime)) {
    return fail('INVALID_SESSION_WINDOW', 'session start must be before end', { field: 'session' });
  }
  if (!Array.isArray(input.session.allowedWeekdays) || input.session.allowedWeekdays.length === 0) {
    return fail('INVALID_SESSION_WINDOW', 'allowedWeekdays must be non-empty', { field: 'session.allowedWeekdays' });
  }
  for (const wd of input.session.allowedWeekdays) {
    if (!Number.isInteger(wd) || wd < 1 || wd > 7) {
      return fail('INVALID_SESSION_WINDOW', 'weekday must be 1..7 (ISO, 1=Monday)', { field: 'session.allowedWeekdays', value: String(wd) });
    }
  }
  const allowedWeekdays = [...new Set(input.session.allowedWeekdays)].sort((a, b) => a - b);

  const exitRuleId = requireRule(input.forcedExit?.ruleId, 'EXIT', 'forcedExit.ruleId');
  if (!exitRuleId.ok) return exitRuleId;
  if (!TIME_RE.test(input.forcedExit?.time ?? '')) return fail('INVALID_SESSION_WINDOW', 'forcedExit.time must be HH:MM', { field: 'forcedExit.time' });
  if (timeToMinutes(input.forcedExit.time) < timeToMinutes(input.session.endTime)) {
    return fail('INVALID_SESSION_WINDOW', 'forced exit must not be before the session window ends', { field: 'forcedExit.time' });
  }

  const sizeRuleId = requireRule(input.positionSize?.ruleId, 'POSITION_SIZE', 'positionSize.ruleId');
  if (!sizeRuleId.ok) return sizeRuleId;
  if (!Number.isInteger(input.positionSize?.quantity) || input.positionSize.quantity < 1) {
    return fail('INVALID_POSITION_SIZE', 'quantity must be a positive integer', { field: 'positionSize.quantity' });
  }

  let riskLimits: RiskLimits | null = null;
  if (input.riskLimits) {
    const rl = input.riskLimits;
    if (rl.maxDailyLossRuleId) {
      const r = requireRule(rl.maxDailyLossRuleId, 'RISK', 'riskLimits.maxDailyLossRuleId');
      if (!r.ok) return r;
    }
    if (rl.maxStrategyLossRuleId) {
      const r = requireRule(rl.maxStrategyLossRuleId, 'RISK', 'riskLimits.maxStrategyLossRuleId');
      if (!r.ok) return r;
    }
    if (rl.maxDailyLoss !== undefined && !isFinitePositive(rl.maxDailyLoss)) {
      return fail('INVALID_RISK_PARAMETER', 'maxDailyLoss must be a finite number > 0', { field: 'riskLimits.maxDailyLoss' });
    }
    if (rl.maxStrategyLoss !== undefined && !isFinitePositive(rl.maxStrategyLoss)) {
      return fail('INVALID_RISK_PARAMETER', 'maxStrategyLoss must be a finite number > 0', { field: 'riskLimits.maxStrategyLoss' });
    }
    if (rl.maxDailyLoss !== undefined && rl.maxStrategyLoss !== undefined && rl.maxDailyLoss > rl.maxStrategyLoss) {
      return fail('CONTRADICTORY_CONFIGURATION', 'maxDailyLoss cannot exceed maxStrategyLoss', { field: 'riskLimits' });
    }
    riskLimits = { ...rl };
  }

  const spec: StrategySpecification = Object.freeze({
    schemaVersion: 1,
    name,
    description: typeof input.description === 'string' ? input.description.trim() : '',
    marketProfile,
    signalTimeframe: input.signalTimeframe,
    executionTimeframe: input.executionTimeframe ?? null,
    allowedDirections: Object.freeze(dedupedDirections),
    allowReversals: Boolean(input.allowReversals),
    entry: { ruleId: entryRuleId.value },
    stop: Object.freeze({ ...input.stop }),
    target: Object.freeze({ ...input.target }),
    breakEven: breakEven ? Object.freeze(breakEven) : null,
    trailing: trailing ? Object.freeze(trailing) : null,
    session: Object.freeze({ ...input.session, allowedWeekdays: Object.freeze(allowedWeekdays) }),
    forcedExit: Object.freeze({ ...input.forcedExit }),
    positionSize: Object.freeze({ ...input.positionSize }),
    riskLimits: riskLimits ? Object.freeze(riskLimits) : null,
  });
  return ok(spec);
}

/** Re-validates an already-constructed spec (e.g. before a DRAFT/VALIDATED
 * promotion) without re-parsing raw input. Delegates to the same
 * construction path so there is exactly one place invariants live. */
export function validateStrategySpecification(spec: StrategySpecification): StrategyResult<StrategySpecification> {
  return createStrategySpecification({
    ...spec,
    marketProfile: spec.marketProfile,
  });
}
