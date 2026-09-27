/**
 * Synthetic OHLCV fixture — INSIGHTVALUES-ROBOT-BUILDER-MACRO-06 §11, §17.
 *
 * Deterministically generated, NOT real market data of any kind (no
 * relationship to WIN1!/WDO1! or any other real instrument). Exists so
 * the generic rule engine (and the second reference strategy proving the
 * architecture is not hardcoded to V10) has something safe and
 * licence-free to run against. Two trading sessions, hand-picked so the
 * expected trade outcome is exactly known and assertable in tests:
 *
 *   Session 2026-01-05: price rises -> a LONG entered at session open
 *     (100) hits a +10 target at 13:10Z.
 *   Session 2026-01-06: price falls -> a LONG entered at session open
 *     (100) hits a -5 stop at 13:05Z.
 *
 * Net (zero cost): +5. This is intentionally not "profitable" as a
 * demonstration -- its only purpose is to prove the generic engine
 * executes deterministically end-to-end (§11: "Do not claim
 * profitability. Do not optimize it for P&L.").
 */
import type { OhlcvBar } from './ohlcv.ts';

export const SYNTHETIC_FIXTURE_DATASET_ID = 'synthetic-fixture-5min-v1';

function bar(ts: string, o: number, h: number, l: number, c: number, v = 100): OhlcvBar {
  return { timestamp: ts, open: o, high: h, low: l, close: c, volume: v };
}

export function syntheticFixtureBars(): readonly OhlcvBar[] {
  return Object.freeze([
    // Session 1 (2026-01-05, Monday) -- rises into a target hit.
    bar('2026-01-05T13:00:00Z', 100, 101, 99, 100),
    bar('2026-01-05T13:05:00Z', 100, 106, 99, 105),
    bar('2026-01-05T13:10:00Z', 105, 111, 104, 110),
    bar('2026-01-05T13:15:00Z', 110, 112, 109, 111),
    bar('2026-01-05T13:55:00Z', 111, 112, 110, 111),

    // Session 2 (2026-01-06, Tuesday) -- falls into a stop hit.
    bar('2026-01-06T13:00:00Z', 100, 101, 99, 100),
    bar('2026-01-06T13:05:00Z', 100, 101, 93, 94),
    bar('2026-01-06T13:15:00Z', 94, 96, 93, 95),
    bar('2026-01-06T13:55:00Z', 95, 96, 94, 95),
  ]);
}
