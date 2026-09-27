/**
 * Generic Rule Engine — INSIGHTVALUES-ROBOT-BUILDER-MACRO-06 §15.
 *
 * A deterministic, safe, IN-PROCESS backtester for the constrained rule
 * subset engine_registry.ts's GENERIC_RULE_ENGINE actually declares
 * support for. This is NOT an attempt to reproduce Strategy #001/V10's
 * Fibonacci/trend/pullback logic (that stays Python-only, reached through
 * backtest_bridge.ts) -- it exists to prove the generic Strategy
 * Specification architecture end-to-end on a rule set simple enough to
 * implement correctly and safely (§15: "Do NOT attempt to support
 * arbitrary programming").
 *
 * Documented limitations (honest, not hidden):
 *   - entry.ruleId must be ENTRY.SESSION_OPEN (enter once per session, at
 *     the FIRST bar inside the session window, no signal condition).
 *   - allowedDirections must be exactly one direction (LONG or SHORT) --
 *     this engine does not decide which direction to take; it is told.
 *   - bars are assumed to already be expressed in marketProfile.timezone
 *     (no IANA timezone conversion is performed here); only 'UTC' has
 *     been exercised.
 *   - on a bar that touches both the stop/protection level AND the
 *     target, the stop is assumed to have been hit first (conservative).
 *   - no no-trade-reason taxonomy (unlike the V10 Python reference) --
 *     a session with no bar inside the window simply has no trade.
 */
import type { StrategySpecification } from './strategy_spec.ts';
import type { OhlcvBar } from './ohlcv.ts';
import { fail, ok, type StrategyResult } from './errors.ts';

export interface GenericEngineTrade {
  readonly direction: 'LONG' | 'SHORT';
  readonly entryTimestamp: string;
  readonly entryPrice: number;
  readonly exitTimestamp: string;
  readonly exitPrice: number;
  readonly exitReason: 'TARGET' | 'STOP' | 'FORCED_EXIT';
  readonly grossPnlPoints: number;
}

export interface GenericEngineRunResult {
  readonly trades: readonly GenericEngineTrade[];
  readonly barsProcessed: number;
  readonly sessionsProcessed: number;
}

function timeOfDayMinutes(iso: string): number {
  const d = new Date(iso);
  return d.getUTCHours() * 60 + d.getUTCMinutes();
}
function dateKey(iso: string): string {
  return iso.slice(0, 10);
}
function toMinutes(hhmm: string): number {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
}

export function runGenericRuleEngine(
  spec: StrategySpecification,
  bars: readonly OhlcvBar[],
): StrategyResult<GenericEngineRunResult> {
  if (spec.entry.ruleId !== 'ENTRY.SESSION_OPEN') {
    return fail('UNSUPPORTED_RULE', 'the generic rule engine only executes ENTRY.SESSION_OPEN', {
      ruleId: spec.entry.ruleId,
    });
  }
  if (spec.allowedDirections.length !== 1) {
    return fail('UNSUPPORTED_RULE', 'the generic rule engine requires exactly one allowed direction', {
      count: spec.allowedDirections.length,
    });
  }
  if (!Array.isArray(bars) || bars.length === 0) {
    return fail('DATA_REQUIREMENT_UNMET', 'no bars supplied to the generic rule engine');
  }

  const direction = spec.allowedDirections[0];
  const sign = direction === 'LONG' ? 1 : -1;
  const sessionStart = toMinutes(spec.session.startTime);
  const sessionEnd = toMinutes(spec.session.endTime);
  const forcedExit = toMinutes(spec.forcedExit.time);

  const byDay = new Map<string, OhlcvBar[]>();
  for (const b of bars) {
    const key = dateKey(b.timestamp);
    const list = byDay.get(key) ?? [];
    list.push(b);
    byDay.set(key, list);
  }

  const trades: GenericEngineTrade[] = [];
  for (const [, dayBars] of byDay) {
    const inWindow = dayBars.filter((b) => {
      const t = timeOfDayMinutes(b.timestamp);
      return t >= sessionStart && t < sessionEnd;
    });
    if (inWindow.length === 0) continue;
    const entryBar = inWindow[0];
    const entryPrice = entryBar.open;
    const stopLevel0 = entryPrice - sign * spec.stop.distance;
    const targetLevel = entryPrice + sign * spec.target.distance;

    let protection = stopLevel0;
    let favorableExtreme = entryPrice;
    let exited = false;

    const afterEntry = dayBars.filter((b) => new Date(b.timestamp) >= new Date(entryBar.timestamp));
    for (const b of afterEntry) {
      // Codex-style self-review during implementation: protection/target
      // are checked against the level carried in FROM PRIOR bars only --
      // a favorable move THIS bar cannot both earn a new break-even step
      // and have that same step's protection immediately violated by
      // this same bar's adverse extreme (intrabar order is unknown, so a
      // same-bar update-then-check would silently assume the favorable
      // move happened before the adverse one, which is not something the
      // data can support). The ratchet update below happens strictly
      // AFTER this bar's touches are evaluated, taking effect starting
      // the next bar.
      const adverse = direction === 'LONG' ? b.low : b.high;
      const favorableTouch = direction === 'LONG' ? b.high : b.low;
      const stopTouched = sign > 0 ? adverse <= protection : adverse >= protection;
      const targetTouched = sign > 0 ? favorableTouch >= targetLevel : favorableTouch <= targetLevel;

      if (stopTouched) {
        trades.push({
          direction, entryTimestamp: entryBar.timestamp, entryPrice,
          exitTimestamp: b.timestamp, exitPrice: protection, exitReason: 'STOP',
          grossPnlPoints: sign * (protection - entryPrice),
        });
        exited = true;
        break;
      }
      if (targetTouched) {
        trades.push({
          direction, entryTimestamp: entryBar.timestamp, entryPrice,
          exitTimestamp: b.timestamp, exitPrice: targetLevel, exitReason: 'TARGET',
          grossPnlPoints: sign * (targetLevel - entryPrice),
        });
        exited = true;
        break;
      }
      if (timeOfDayMinutes(b.timestamp) >= forcedExit) {
        trades.push({
          direction, entryTimestamp: entryBar.timestamp, entryPrice,
          exitTimestamp: b.timestamp, exitPrice: b.open, exitReason: 'FORCED_EXIT',
          grossPnlPoints: sign * (b.open - entryPrice),
        });
        exited = true;
        break;
      }

      // Ratchet update for the NEXT bar's checks only (see comment above).
      const barFavorable = direction === 'LONG' ? b.high : b.low;
      if (sign * (barFavorable - favorableExtreme) > 0) favorableExtreme = barFavorable;
      if (spec.breakEven) {
        const favorableMove = sign * (favorableExtreme - entryPrice);
        if (favorableMove >= spec.breakEven.triggerDistance) {
          const stepsBeyondTrigger = Math.floor((favorableMove - spec.breakEven.triggerDistance) / spec.breakEven.stepDistance);
          const protectedDistance = spec.breakEven.initialProtectedDistance + stepsBeyondTrigger * spec.breakEven.stepDistance;
          const candidate = entryPrice + sign * protectedDistance;
          if (sign * (candidate - protection) > 0) protection = candidate; // never retreats
        }
      }
    }
    if (!exited && afterEntry.length > 0) {
      const last = afterEntry[afterEntry.length - 1];
      trades.push({
        direction, entryTimestamp: entryBar.timestamp, entryPrice,
        exitTimestamp: last.timestamp, exitPrice: last.close, exitReason: 'FORCED_EXIT',
        grossPnlPoints: sign * (last.close - entryPrice),
      });
    }
  }

  return ok({ trades: Object.freeze(trades), barsProcessed: bars.length, sessionsProcessed: byDay.size });
}
