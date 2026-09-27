import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { createMarketProfile, supportsTimeframe } from './market_profile.ts';
import { V10_REFERENCE_MARKET_PROFILE_INPUT } from './v10_reference.ts';

Deno.test('MP-01 the real WIN1! profile validates and is FUTURE-classed, not hardcoded elsewhere', () => {
  const result = createMarketProfile(V10_REFERENCE_MARKET_PROFILE_INPUT);
  assert(result.ok);
  if (!result.ok) return;
  assertEquals(result.value.instrument.assetClass, 'FUTURE');
  assertEquals(result.value.instrument.symbol, 'WIN1!');
  assertEquals(result.value.tickSize, 5.0);
  assertEquals(result.value.tickValue, 1.0);
  assertEquals(result.value.contractMultiplier, 0.20);
  assert(supportsTimeframe(result.value, '5min'));
  assert(!supportsTimeframe(result.value, '1min'));
});

Deno.test('MP-02 rejects non-positive tickSize/tickValue/contractMultiplier', () => {
  for (const field of ['tickSize', 'tickValue', 'contractMultiplier'] as const) {
    const result = createMarketProfile({ ...V10_REFERENCE_MARKET_PROFILE_INPUT, [field]: 0 });
    assert(!result.ok, field);
    assertEquals(result.ok ? null : result.error.code, 'INVALID_MARKET_PROFILE');
  }
});

Deno.test('MP-03 rejects an empty availableTimeframes list and a malformed timeframe token', () => {
  const empty = createMarketProfile({ ...V10_REFERENCE_MARKET_PROFILE_INPUT, availableTimeframes: [] });
  assert(!empty.ok);

  const malformed = createMarketProfile({ ...V10_REFERENCE_MARKET_PROFILE_INPUT, availableTimeframes: ['five minutes'] });
  assert(!malformed.ok);
});

Deno.test('MP-04 cost assumptions require a stated source and non-negative figures', () => {
  const noSource = createMarketProfile({
    ...V10_REFERENCE_MARKET_PROFILE_INPUT,
    defaultCostAssumptions: { brokeragePerContract: 1, exchangeFeePerContract: 1, slippageTicks: 1, source: '' },
  });
  assert(!noSource.ok);

  const negative = createMarketProfile({
    ...V10_REFERENCE_MARKET_PROFILE_INPUT,
    defaultCostAssumptions: { brokeragePerContract: -1, exchangeFeePerContract: 1, slippageTicks: 1, source: 'x' },
  });
  assert(!negative.ok);
});

Deno.test('MP-05 an invalid instrument (bad currency) is rejected through the shared instrument validator, not duplicated logic', () => {
  const result = createMarketProfile({
    ...V10_REFERENCE_MARKET_PROFILE_INPUT,
    instrument: { ...V10_REFERENCE_MARKET_PROFILE_INPUT.instrument, currency: 'brl'.repeat(5) },
  });
  assert(!result.ok);
  assertEquals(result.ok ? null : result.error.code, 'INVALID_MARKET_PROFILE');
});
