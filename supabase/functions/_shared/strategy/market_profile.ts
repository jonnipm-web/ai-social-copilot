/**
 * Market/Instrument Profile — INSIGHTVALUES-ROBOT-BUILDER-MACRO-05 §19.
 *
 * A strategy cannot be evaluated independently of the market it is
 * configured against. This wraps quant/instrument.ts's InstrumentIdentity
 * (the shared identity the rest of Quant already uses) with the extra
 * facts a Strategy Builder specifically needs and Quant Foundation does
 * not: tick economics, session/data-timeframe availability, and a default
 * cost model. Deliberately NOT a WIN-specific type -- WIN1!'s real values
 * (tickSize=5, tickValue=1.0, contractMultiplier=0.20) are DATA supplied
 * to this generic shape by whoever registers the profile, never hardcoded
 * into the validator below (§19: "Do NOT hardcode WIN assumptions into
 * generic Strategy Builder logic").
 */
import { createInstrument, type InstrumentIdentity } from '../quant/instrument.ts';
import { fail, ok, type StrategyResult } from './errors.ts';

/** A default (non-binding) cost assumption set a market profile may carry,
 * so a backtest run without an explicit cost override still has a
 * documented basis rather than silently defaulting to zero. */
export interface CostAssumptions {
  readonly brokeragePerContract: number;
  readonly exchangeFeePerContract: number;
  readonly slippageTicks: number;
  /** Free-text source of these numbers (e.g. "discount broker, day trade,
   * manually declared QT-01C.3") -- cost assumptions without a stated
   * source are exactly the kind of fabricated-expertise §23 forbids. */
  readonly source: string;
}

export interface MarketProfile {
  readonly instrument: InstrumentIdentity;
  /** Smallest price increment the instrument trades in. */
  readonly tickSize: number;
  /** Monetary value of one tick move, in `instrument.currency`. */
  readonly tickValue: number;
  /** gross_pnl = priceDelta * contractMultiplier * quantity. For most
   * futures this is tickValue / tickSize; kept explicit rather than
   * derived so a profile can state it directly from a public contract
   * spec, the way the Python reference does. */
  readonly contractMultiplier: number;
  /** IANA timezone the session/calendar below is expressed in. */
  readonly timezone: string;
  /** Opaque reference to a session/holiday calendar (e.g. "b3-win-2026").
   * The calendar's actual content is NOT this module's concern -- it is
   * validated to exist by whoever resolves it, not reproduced here. */
  readonly sessionCalendarId: string;
  /** Timeframes this market profile has certified historical data for
   * (e.g. ["5min"]). A Strategy Specification's signalTimeframe must be a
   * member of this set -- see strategy_spec.ts's DATA_REQUIREMENT_UNMET. */
  readonly availableTimeframes: readonly string[];
  readonly defaultCostAssumptions?: CostAssumptions;
}

const TIMEZONE_RE = /^[A-Za-z_]+(\/[A-Za-z0-9_+\-]+){0,2}$/;
const CALENDAR_ID_RE = /^[a-z0-9][a-z0-9-]{0,63}$/;
const TIMEFRAME_RE = /^[0-9]+(min|h|d)$/;

export interface MarketProfileInput {
  readonly instrument: InstrumentIdentity;
  readonly tickSize: number;
  readonly tickValue: number;
  readonly contractMultiplier: number;
  readonly timezone: string;
  readonly sessionCalendarId: string;
  readonly availableTimeframes: readonly string[];
  readonly defaultCostAssumptions?: CostAssumptions;
}

/** Validates and canonicalizes. Fails closed: an instrument that itself
 * fails createInstrument's checks never reaches a MarketProfile. */
export function createMarketProfile(input: MarketProfileInput): StrategyResult<MarketProfile> {
  if (!input || typeof input !== 'object') return fail('INVALID_MARKET_PROFILE', 'market profile must be an object');
  const instrumentResult = createInstrument(input.instrument);
  if (!instrumentResult.ok) {
    return fail('INVALID_MARKET_PROFILE', 'invalid instrument', { field: 'instrument', reason: instrumentResult.error.code });
  }
  if (!(input.tickSize > 0)) return fail('INVALID_MARKET_PROFILE', 'tickSize must be > 0', { field: 'tickSize' });
  if (!(input.tickValue > 0)) return fail('INVALID_MARKET_PROFILE', 'tickValue must be > 0', { field: 'tickValue' });
  if (!(input.contractMultiplier > 0)) {
    return fail('INVALID_MARKET_PROFILE', 'contractMultiplier must be > 0', { field: 'contractMultiplier' });
  }
  if (typeof input.timezone !== 'string' || !TIMEZONE_RE.test(input.timezone)) {
    return fail('INVALID_MARKET_PROFILE', 'timezone must be an IANA zone name', { field: 'timezone' });
  }
  if (typeof input.sessionCalendarId !== 'string' || !CALENDAR_ID_RE.test(input.sessionCalendarId)) {
    return fail('INVALID_MARKET_PROFILE', 'invalid sessionCalendarId', { field: 'sessionCalendarId' });
  }
  if (!Array.isArray(input.availableTimeframes) || input.availableTimeframes.length === 0) {
    return fail('INVALID_MARKET_PROFILE', 'availableTimeframes must be non-empty', { field: 'availableTimeframes' });
  }
  for (const tf of input.availableTimeframes) {
    if (typeof tf !== 'string' || !TIMEFRAME_RE.test(tf)) {
      return fail('INVALID_MARKET_PROFILE', 'invalid timeframe token', { field: 'availableTimeframes', value: String(tf) });
    }
  }
  if (input.defaultCostAssumptions) {
    const c = input.defaultCostAssumptions;
    if (c.brokeragePerContract < 0 || c.exchangeFeePerContract < 0 || c.slippageTicks < 0) {
      return fail('INVALID_MARKET_PROFILE', 'cost assumptions must be >= 0', { field: 'defaultCostAssumptions' });
    }
    if (typeof c.source !== 'string' || c.source.trim().length === 0) {
      return fail('INVALID_MARKET_PROFILE', 'cost assumptions must state a source', { field: 'defaultCostAssumptions.source' });
    }
  }
  const out: MarketProfile = Object.freeze({
    instrument: instrumentResult.value,
    tickSize: input.tickSize,
    tickValue: input.tickValue,
    contractMultiplier: input.contractMultiplier,
    timezone: input.timezone,
    sessionCalendarId: input.sessionCalendarId,
    availableTimeframes: Object.freeze([...input.availableTimeframes]),
    ...(input.defaultCostAssumptions ? { defaultCostAssumptions: Object.freeze({ ...input.defaultCostAssumptions }) } : {}),
  });
  return ok(out);
}

export function supportsTimeframe(profile: MarketProfile, timeframe: string): boolean {
  return profile.availableTimeframes.includes(timeframe);
}
