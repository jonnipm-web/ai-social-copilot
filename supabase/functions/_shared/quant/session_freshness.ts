/**
 * Calendar-aware freshness — IV-QUANT-DATA-PLANE-AND-API-02
 * (QUANT_MARKET_CALENDAR.md §3).
 *
 * DAILY bars on a supported calendar are judged in SESSIONS, not days: a
 * Friday bar read on Sunday is as fresh as it can be, and a bar missing the
 * previous session is one session behind regardless of weekends/holidays.
 *   sessionsBehind = trading days in (newest bar session, last completed session]
 *   0 → FRESH, 1 → DELAYED, ≥ 2 → STALE
 * INTRADAY bars measure age against the market clock: while the market is
 * closed, "now" is the last session close, so a bar from the final minutes
 * of Friday is FRESH all weekend.
 * WEEKLY/MONTHLY bars, unknown MICs and dates outside the supported range
 * fall back to the calendar-naive policy and say so (basis CALENDAR_NAIVE,
 * calendarStatus CALENDAR_UNKNOWN) — an open/closed state is never invented.
 */
import {
  type CalendarId,
  calendarForMic,
  isTradingDay,
  localDateTime,
  marketClock,
  type MarketState,
  tradingDaysBetween,
} from './calendar.ts';
import { assessFreshness, DEFAULT_FRESHNESS_POLICIES, type FreshnessAssessment, type Frequency } from './provenance.ts';
import type { PriceBar } from './timeseries.ts';

export interface CalendarContext {
  readonly basis: 'MARKET_CALENDAR' | 'CALENDAR_NAIVE';
  readonly calendar: CalendarId | null;
  readonly calendarStatus: 'SUPPORTED' | 'CALENDAR_UNKNOWN';
  readonly timezone: string | null;
  /** Market state at evaluation time; null when the calendar cannot say. */
  readonly marketState: MarketState | null;
  readonly lastCompletedSession: string | null;
  /** DAILY only: sessions between the newest bar and the last completed session. */
  readonly sessionsBehind: number | null;
  /** DAILY only: trading sessions inside the analyzed period with no bar. */
  readonly missingSessions: number | null;
  /** DAILY only: bars dated on a non-trading day. */
  readonly nonSessionBars: number | null;
  /** DAILY only: newest bar belongs to a session that has not completed yet. */
  readonly partialSessionBar: boolean;
}

export interface SessionFreshness {
  readonly freshness: FreshnessAssessment;
  readonly context: CalendarContext;
}

const CALENDAR_FREQUENCIES: ReadonlySet<Frequency> = new Set(['DAILY', 'INTRADAY_1M', 'INTRADAY_5M', 'INTRADAY_1H']);
const MAX_MISSING_SCAN_DAYS = 40_000; // ~110 years; bounded by the series itself in practice.

function naive(asOfMs: number, nowMs: number, frequency: Frequency, cal: CalendarId | null, tz: string | null): SessionFreshness {
  return {
    freshness: assessFreshness(asOfMs, nowMs, DEFAULT_FRESHNESS_POLICIES[frequency]),
    context: {
      basis: 'CALENDAR_NAIVE', calendar: cal, calendarStatus: 'CALENDAR_UNKNOWN', timezone: tz, marketState: null,
      lastCompletedSession: null, sessionsBehind: null, missingSessions: null, nonSessionBars: null, partialSessionBar: false,
    },
  };
}

/**
 * Session date of a bar. A DAILY bar stamped exactly 00:00Z is a date-only
 * session LABEL (CSV `YYYY-MM-DD`) → that date. Any other instant (e.g.
 * `2026-01-16T21:00:00-05:00`) is converted to the exchange-local date, so a
 * Friday-evening New York bar is not misfiled as Saturday UTC (Claude finding
 * H-F: it produced UNKNOWN freshness and a false NON_SESSION_BARS).
 */
function barSession(t: number, frequency: Frequency, tz: string): string {
  if (frequency === 'DAILY' && t % 86_400_000 === 0) return new Date(t).toISOString().slice(0, 10);
  return localDateTime(t, tz).date;
}

export function assessSessionFreshness(
  bars: readonly PriceBar[],
  frequency: Frequency,
  exchangeMic: string | undefined,
  asOfMs: number,
  nowMs: number,
): SessionFreshness {
  const cal = calendarForMic(exchangeMic);
  if (!cal || !CALENDAR_FREQUENCIES.has(frequency) || bars.length === 0) {
    return naive(asOfMs, nowMs, frequency, null, null);
  }
  const clock = marketClock(cal, nowMs);
  if (!clock) return naive(asOfMs, nowMs, frequency, cal.id, cal.timezone); // naive handles unusable clocks without throwing
  const evaluatedAt = new Date(nowMs).toISOString();

  if (frequency === 'DAILY') {
    const first = barSession(bars[0].t, 'DAILY', cal.timezone);
    const newest = barSession(bars[bars.length - 1].t, 'DAILY', cal.timezone);
    const completed = clock.lastCompletedSession;
    if (completed === null || isTradingDay(cal, newest) === null) {
      return naive(asOfMs, nowMs, frequency, cal.id, cal.timezone);
    }
    let nonSession = 0;
    const present = new Set<string>();
    for (const b of bars) {
      const d = barSession(b.t, 'DAILY', cal.timezone);
      present.add(d);
      if (isTradingDay(cal, d) === false) nonSession++;
    }
    // Bars outside the supported range are not judged (null ≠ "non-session").
    let missing: number | null = null;
    if (isTradingDay(cal, first) !== null && (bars[bars.length - 1].t - bars[0].t) / 86_400_000 <= MAX_MISSING_SCAN_DAYS) {
      const sessions = tradingDaysBetween(cal, first, newest);
      missing = sessions === null ? null : sessions.filter((d) => !present.has(d)).length;
    }
    const base = {
      basis: 'MARKET_CALENDAR' as const, calendar: cal.id, calendarStatus: 'SUPPORTED' as const, timezone: cal.timezone,
      marketState: clock.state, lastCompletedSession: completed, missingSessions: missing, nonSessionBars: nonSession,
    };
    const asOf = new Date(asOfMs).toISOString();
    const ageMs = Math.max(0, nowMs - asOfMs);
    if (newest > completed) {
      // A bar for the session in progress (or today before publication) is a partial bar;
      // a bar for a later date is a clock/provider error.
      const partial = newest === clock.localDate && clock.currentSession !== null;
      return {
        freshness: { state: partial ? 'FRESH' : 'UNKNOWN', ageMs: partial ? ageMs : null, asOf, evaluatedAt },
        context: { ...base, sessionsBehind: partial ? 0 : null, partialSessionBar: partial },
      };
    }
    const behind = tradingDaysBetween(cal, newest, completed);
    if (behind === null) return naive(asOfMs, nowMs, frequency, cal.id, cal.timezone);
    const n = behind.length;
    return {
      freshness: { state: n === 0 ? 'FRESH' : n === 1 ? 'DELAYED' : 'STALE', ageMs, asOf, evaluatedAt },
      context: { ...base, sessionsBehind: n, partialSessionBar: false },
    };
  }

  // Intraday: while closed, measure age from the last session close (an
  // extended-hours bar after that close counts from its own time).
  const effectiveNow = clock.state === 'OPEN' || clock.lastCloseMs === null
    ? nowMs
    : Math.min(nowMs, Math.max(clock.lastCloseMs, asOfMs));
  const f = assessFreshness(asOfMs, effectiveNow, DEFAULT_FRESHNESS_POLICIES[frequency]);
  return {
    freshness: { ...f, evaluatedAt },
    context: {
      basis: 'MARKET_CALENDAR', calendar: cal.id, calendarStatus: 'SUPPORTED', timezone: cal.timezone, marketState: clock.state,
      lastCompletedSession: clock.lastCompletedSession, sessionsBehind: null, missingSessions: null, nonSessionBars: null,
      partialSessionBar: false,
    },
  };
}
