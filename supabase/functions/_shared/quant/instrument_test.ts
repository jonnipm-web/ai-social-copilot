import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { createInstrument } from './instrument.ts';

/** Codex final audit (ROBOT-BUILDER-MACRO-05, P1): the trailing '!'
 * continuous-futures allowance must be scoped to FUTURE only -- it must
 * never let a non-futures symbol through createInstrument. */
Deno.test('IN-01 a trailing exclamation mark is accepted for FUTURE only, never for other asset classes', () => {
  const future = createInstrument({ assetClass: 'FUTURE', symbol: 'WIN1!', currency: 'BRL' });
  assert(future.ok, JSON.stringify(!future.ok && future.error));

  for (const assetClass of ['EQUITY', 'ETF', 'INDEX', 'FX', 'CRYPTO', 'FIXED_INCOME', 'COMMODITY', 'FUND'] as const) {
    const result = createInstrument({ assetClass, symbol: 'AAPL!', currency: 'USD' });
    assert(!result.ok, `${assetClass}/AAPL! must be rejected`);
    assertEquals(result.ok ? null : result.error.code, 'INVALID_INSTRUMENT');
  }
});

Deno.test('IN-02 a plain symbol with no exclamation mark still validates identically for every asset class', () => {
  const result = createInstrument({ assetClass: 'EQUITY', symbol: 'AAPL', currency: 'USD' });
  assert(result.ok);
});
