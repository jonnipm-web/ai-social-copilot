import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { createStrategySpecification, type StrategySpecificationInput } from './strategy_spec.ts';
import { V10_REFERENCE_SPEC_INPUT, buildV10ReferenceSpecification } from './v10_reference.ts';

const VALID_INPUT: StrategySpecificationInput = V10_REFERENCE_SPEC_INPUT;

function withOverride(overrides: Partial<StrategySpecificationInput>): StrategySpecificationInput {
  return { ...VALID_INPUT, ...overrides };
}

Deno.test('SS-01 V10 reference spec (§27) validates through the generic constructor with no special-casing', () => {
  const result = buildV10ReferenceSpecification();
  assert(result.ok, JSON.stringify(!result.ok && result.error));
  if (!result.ok) return;
  assertEquals(result.value.stop.distance, 100.0);
  assertEquals(result.value.target.distance, 250.0);
  assertEquals(result.value.breakEven?.triggerDistance, 50.0);
  assertEquals(result.value.breakEven?.initialProtectedDistance, 10.0);
  assertEquals(result.value.breakEven?.stepDistance, 10.0);
  assertEquals(result.value.allowedDirections, ['LONG', 'SHORT']);
  assertEquals(result.value.allowReversals, false);
  assertEquals(result.value.session.startTime, '10:00');
  assertEquals(result.value.session.endTime, '16:00');
  assertEquals(result.value.session.allowedWeekdays, [1, 2, 3, 4]);
  assertEquals(result.value.forcedExit.time, '16:00');
  assertEquals(result.value.positionSize.quantity, 1);
});

Deno.test('SS-02 rejects stop <= 0', () => {
  const result = createStrategySpecification(withOverride({ stop: { ruleId: 'STOP.FIXED_DISTANCE', distance: 0 } }));
  assert(!result.ok);
  assertEquals(result.ok ? null : result.error.code, 'INVALID_RISK_PARAMETER');
});

Deno.test('SS-03 rejects target <= 0', () => {
  const result = createStrategySpecification(withOverride({ target: { ruleId: 'TARGET.FIXED_DISTANCE', distance: -1 } }));
  assert(!result.ok);
  assertEquals(result.ok ? null : result.error.code, 'INVALID_RISK_PARAMETER');
});

Deno.test('SS-04 rejects an unsupported rule id', () => {
  const result = createStrategySpecification(withOverride({ entry: { ruleId: 'ENTRY.MADE_UP_RULE' } }));
  assert(!result.ok);
  assertEquals(result.ok ? null : result.error.code, 'UNSUPPORTED_RULE');
});

Deno.test('SS-05 rejects a rule id from the wrong category (e.g. a STOP rule used as entry)', () => {
  const result = createStrategySpecification(withOverride({ entry: { ruleId: 'STOP.FIXED_DISTANCE' } }));
  assert(!result.ok);
  assertEquals(result.ok ? null : result.error.code, 'UNSUPPORTED_RULE');
});

Deno.test('SS-06 rejects break-even trigger >= target distance (contradictory)', () => {
  const result = createStrategySpecification(
    withOverride({
      breakEven: { ruleId: 'BREAK_EVEN.STEPPED', triggerDistance: 250, initialProtectedDistance: 10, stepDistance: 10 },
    }),
  );
  assert(!result.ok);
  assertEquals(result.ok ? null : result.error.code, 'CONTRADICTORY_CONFIGURATION');
});

Deno.test('SS-07 rejects break-even AND trailing both enabled', () => {
  const result = createStrategySpecification(
    withOverride({
      breakEven: { ruleId: 'BREAK_EVEN.STEPPED', triggerDistance: 50, initialProtectedDistance: 10, stepDistance: 10 },
      trailing: { ruleId: 'TRAILING.FIXED_DISTANCE', distance: 20 },
    }),
  );
  assert(!result.ok);
  assertEquals(result.ok ? null : result.error.code, 'CONTRADICTORY_CONFIGURATION');
});

Deno.test('SS-08 rejects a signalTimeframe absent from the market profile (fail-closed data requirement)', () => {
  const result = createStrategySpecification(withOverride({ signalTimeframe: '1min' }));
  assert(!result.ok);
  assertEquals(result.ok ? null : result.error.code, 'DATA_REQUIREMENT_UNMET');
});

Deno.test('SS-09 rejects session start >= end, and forced exit before session end', () => {
  const badWindow = createStrategySpecification(
    withOverride({ session: { ruleId: 'SESSION.WINDOW', startTime: '16:00', endTime: '10:00', allowedWeekdays: [1] } }),
  );
  assert(!badWindow.ok);
  assertEquals(badWindow.ok ? null : badWindow.error.code, 'INVALID_SESSION_WINDOW');

  const earlyExit = createStrategySpecification(withOverride({ forcedExit: { ruleId: 'EXIT.FORCED_TIME', time: '09:00' } }));
  assert(!earlyExit.ok);
  assertEquals(earlyExit.ok ? null : earlyExit.error.code, 'INVALID_SESSION_WINDOW');
});

Deno.test('SS-10 rejects non-integer or zero position size', () => {
  const zero = createStrategySpecification(withOverride({ positionSize: { ruleId: 'POSITION_SIZE.FIXED_CONTRACTS', quantity: 0 } }));
  assert(!zero.ok);
  assertEquals(zero.ok ? null : zero.error.code, 'INVALID_POSITION_SIZE');

  const fractional = createStrategySpecification(
    withOverride({ positionSize: { ruleId: 'POSITION_SIZE.FIXED_CONTRACTS', quantity: 1.5 } }),
  );
  assert(!fractional.ok);
  assertEquals(fractional.ok ? null : fractional.error.code, 'INVALID_POSITION_SIZE');
});

Deno.test('SS-11 rejects empty allowedDirections and an invalid direction token', () => {
  const empty = createStrategySpecification(withOverride({ allowedDirections: [] }));
  assert(!empty.ok);

  // deno-lint-ignore no-explicit-any
  const invalid = createStrategySpecification(withOverride({ allowedDirections: ['UP' as any] }));
  assert(!invalid.ok);
});

Deno.test('SS-12 rejects riskLimits with maxDailyLoss > maxStrategyLoss', () => {
  const result = createStrategySpecification(
    withOverride({ riskLimits: { maxDailyLossRuleId: 'RISK.MAX_DAILY_LOSS', maxDailyLoss: 5000, maxStrategyLossRuleId: 'RISK.MAX_STRATEGY_LOSS', maxStrategyLoss: 1000 } }),
  );
  assert(!result.ok);
  assertEquals(result.ok ? null : result.error.code, 'CONTRADICTORY_CONFIGURATION');
});

Deno.test('SS-13 an unsupported asset instrument (bad symbol) fails through market profile validation, not silently accepted', () => {
  const result = createStrategySpecification(
    withOverride({
      marketProfile: {
        ...VALID_INPUT.marketProfile,
        instrument: { ...VALID_INPUT.marketProfile.instrument, symbol: '' },
      },
    }),
  );
  assert(!result.ok);
  assertEquals(result.ok ? null : result.error.code, 'INVALID_MARKET_PROFILE');
});

Deno.test('SS-14 configuration alone never executes anything -- construction is pure and returns data only', () => {
  const result = createStrategySpecification(VALID_INPUT);
  assert(result.ok);
  if (!result.ok) return;
  // No side effects/executability signal exists on the spec at all.
  assertEquals('execute' in result.value, false);
  assertEquals('run' in result.value, false);
});
