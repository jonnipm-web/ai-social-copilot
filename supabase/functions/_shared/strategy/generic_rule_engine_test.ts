import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { runGenericRuleEngine } from './generic_rule_engine.ts';
import { syntheticFixtureBars } from './generic_engine_fixtures.ts';
import { buildGenericReferenceSpecification } from './generic_reference_strategy.ts';
import type { OhlcvBar } from './ohlcv.ts';
import type { StrategySpecificationInput } from './strategy_spec.ts';
import { GENERIC_REFERENCE_SPEC_INPUT } from './generic_reference_strategy.ts';
import { createStrategySpecification } from './strategy_spec.ts';

function specWith(overrides: Partial<StrategySpecificationInput>) {
  const result = createStrategySpecification({ ...GENERIC_REFERENCE_SPEC_INPUT, ...overrides });
  assert(result.ok, JSON.stringify(!result.ok && result.error));
  return result.ok ? result.value : (null as never);
}

Deno.test('GE-01 the hand-computed fixture produces exactly the expected 2 trades (target hit, then stop hit)', () => {
  const specResult = buildGenericReferenceSpecification();
  assert(specResult.ok);
  if (!specResult.ok) return;
  const result = runGenericRuleEngine(specResult.value, syntheticFixtureBars());
  assert(result.ok, JSON.stringify(!result.ok && result.error));
  if (!result.ok) return;
  assertEquals(result.value.trades.length, 2);
  assertEquals(result.value.sessionsProcessed, 2);

  const [t1, t2] = result.value.trades;
  assertEquals(t1.exitReason, 'TARGET');
  assertEquals(t1.entryPrice, 100);
  assertEquals(t1.exitPrice, 110);
  assertEquals(t1.grossPnlPoints, 10);

  assertEquals(t2.exitReason, 'STOP');
  assertEquals(t2.entryPrice, 100);
  assertEquals(t2.exitPrice, 95);
  assertEquals(t2.grossPnlPoints, -5);
});

Deno.test('GE-02 running twice on the same input produces byte-identical trades (deterministic)', () => {
  const specResult = buildGenericReferenceSpecification();
  assert(specResult.ok);
  if (!specResult.ok) return;
  const a = runGenericRuleEngine(specResult.value, syntheticFixtureBars());
  const b = runGenericRuleEngine(specResult.value, syntheticFixtureBars());
  assert(a.ok && b.ok);
  if (!a.ok || !b.ok) return;
  assertEquals(JSON.stringify(a.value.trades), JSON.stringify(b.value.trades));
});

Deno.test('GE-03 rejects a spec whose entry rule is not ENTRY.SESSION_OPEN (V10s own rule must run only under the Python bridge)', () => {
  // A hand-built object bypassing createStrategySpecification's own
  // entry-category check would still be rejected by the ENGINE itself --
  // exercised directly against the pure engine function.
  const spec = specWith({});
  const forced = { ...spec, entry: { ruleId: 'ENTRY.PULLBACK_IN_TREND' } };
  const result = runGenericRuleEngine(forced, syntheticFixtureBars());
  assert(!result.ok);
  assertEquals(result.ok ? null : result.error.code, 'UNSUPPORTED_RULE');
});

Deno.test('GE-04 rejects a spec with more than one allowed direction', () => {
  const spec = specWith({});
  const forced = { ...spec, allowedDirections: ['LONG', 'SHORT'] as const };
  const result = runGenericRuleEngine(forced, syntheticFixtureBars());
  assert(!result.ok);
});

Deno.test('GE-05 rejects an empty bar array instead of reporting zero trades as success', () => {
  const specResult = buildGenericReferenceSpecification();
  assert(specResult.ok);
  if (!specResult.ok) return;
  const result = runGenericRuleEngine(specResult.value, []);
  assert(!result.ok);
  assertEquals(result.ok ? null : result.error.code, 'DATA_REQUIREMENT_UNMET');
});

Deno.test('GE-06 break-even ratchets protection up and never lets it retreat, closing at the protected level not the raw stop', () => {
  const spec = specWith({
    breakEven: { ruleId: 'BREAK_EVEN.STEPPED', triggerDistance: 4, initialProtectedDistance: 1, stepDistance: 2 },
  });
  // Protection only takes effect starting the bar AFTER it is earned
  // (see the engine's own comment on intrabar sequencing) -- traced by
  // hand bar-by-bar against that exact rule:
  //   bar1: protection=95 (initial stop); checked against 95, not touched.
  //         favorableExtreme->101 (no ratchet yet, move=1 < trigger=4).
  //   bar2: checked against 95 (still); high=104 -> move=4 >= trigger=4,
  //         0 steps beyond -> ratchet to entry+1=101 for NEXT bar.
  //   bar3: checked against 101; low=101.5 does NOT touch (101.5 > 101).
  //         high=108 -> move=8, 2 steps beyond trigger -> ratchet to
  //         entry+1+2*2=105 for NEXT bar.
  //   bar4: checked against 105; low=102 touches (102 <= 105) -> STOP at 105.
  const bars: OhlcvBar[] = [
    { timestamp: '2026-01-05T13:00:00Z', open: 100, high: 101, low: 99, close: 100, volume: 100 },
    { timestamp: '2026-01-05T13:05:00Z', open: 100, high: 104, low: 100, close: 103, volume: 100 },
    { timestamp: '2026-01-05T13:10:00Z', open: 103, high: 108, low: 101.5, close: 106, volume: 100 },
    { timestamp: '2026-01-05T13:15:00Z', open: 106, high: 106, low: 102, close: 103, volume: 100 },
  ];
  const result = runGenericRuleEngine(spec, bars);
  assert(result.ok, JSON.stringify(!result.ok && result.error));
  if (!result.ok) return;
  assertEquals(result.value.trades.length, 1);
  assertEquals(result.value.trades[0].exitReason, 'STOP');
  assertEquals(result.value.trades[0].exitPrice, 105);
});

Deno.test('GE-07 a position still open at the forced-exit time closes at that bars open, not the raw stop/target', () => {
  const spec = specWith({});
  const bars: OhlcvBar[] = [
    { timestamp: '2026-01-05T13:00:00Z', open: 100, high: 101, low: 99, close: 100, volume: 100 },
    { timestamp: '2026-01-05T13:30:00Z', open: 101, high: 102, low: 100, close: 101, volume: 100 },
    { timestamp: '2026-01-05T14:00:00Z', open: 102, high: 103, low: 101, close: 102, volume: 100 },
  ];
  const result = runGenericRuleEngine(spec, bars);
  assert(result.ok);
  if (!result.ok) return;
  assertEquals(result.value.trades.length, 1);
  assertEquals(result.value.trades[0].exitReason, 'FORCED_EXIT');
  assertEquals(result.value.trades[0].exitPrice, 102);
});

Deno.test('GE-08 a day with no bar inside the session window produces no trade for that day', () => {
  const spec = specWith({});
  const bars: OhlcvBar[] = [
    { timestamp: '2026-01-05T20:00:00Z', open: 100, high: 101, low: 99, close: 100, volume: 100 },
  ];
  const result = runGenericRuleEngine(spec, bars);
  assert(result.ok);
  if (!result.ok) return;
  assertEquals(result.value.trades.length, 0);
});
