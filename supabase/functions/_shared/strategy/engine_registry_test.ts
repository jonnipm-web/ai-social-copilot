import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { engineAcceptsRunRequest, getEngine } from './engine_registry.ts';

Deno.test('ER-01 an unknown engine id is refused with a reason, never silently accepted', () => {
  assertEquals(getEngine('SOME_MADE_UP_ENGINE'), undefined);
  const reason = engineAcceptsRunRequest('SOME_MADE_UP_ENGINE', [], 'synthetic-fixture-5min-v1');
  assert(reason !== null);
});

Deno.test('ER-02 GENERIC_RULE_ENGINE accepts its own rules/dataset and rejects V10s entry rule', () => {
  assertEquals(
    engineAcceptsRunRequest('GENERIC_RULE_ENGINE', ['ENTRY.SESSION_OPEN', 'STOP.FIXED_DISTANCE'], 'synthetic-fixture-5min-v1'),
    null,
  );
  const reason = engineAcceptsRunRequest('GENERIC_RULE_ENGINE', ['ENTRY.PULLBACK_IN_TREND'], 'synthetic-fixture-5min-v1');
  assert(reason !== null);
});

Deno.test('ER-03 PAULO_TREND_FIBONACCI_V10 is only accepted against the WIN1! dataset, never the synthetic fixture', () => {
  assertEquals(
    engineAcceptsRunRequest('PAULO_TREND_FIBONACCI_V10', ['ENTRY.PULLBACK_IN_TREND'], 'win1-5min-qt01c3'),
    null,
  );
  const reason = engineAcceptsRunRequest('PAULO_TREND_FIBONACCI_V10', ['ENTRY.PULLBACK_IN_TREND'], 'synthetic-fixture-5min-v1');
  assert(reason !== null);
});

Deno.test('ER-04 GENERIC_RULE_ENGINE is IN_PROCESS; PAULO_TREND_FIBONACCI_V10 is the only EXTERNAL_PYTHON_SERVICE engine', () => {
  assertEquals(getEngine('GENERIC_RULE_ENGINE')?.kind, 'IN_PROCESS');
  assertEquals(getEngine('PAULO_TREND_FIBONACCI_V10')?.kind, 'EXTERNAL_PYTHON_SERVICE');
});
