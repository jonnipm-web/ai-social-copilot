import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { getRule, isSupportedRule, RULE_CATALOG, rulesByCategory } from './rule_catalog.ts';

Deno.test('RC-01 every catalog entry has a unique ruleId', () => {
  const ids = RULE_CATALOG.map((r) => r.ruleId);
  assertEquals(ids.length, new Set(ids).size);
});

Deno.test('RC-02 V10s referenced rules all exist and are correctly categorized', () => {
  const expectations: [string, string][] = [
    ['ENTRY.PULLBACK_IN_TREND', 'ENTRY'],
    ['STOP.FIXED_DISTANCE', 'STOP'],
    ['TARGET.FIXED_DISTANCE', 'TARGET'],
    ['BREAK_EVEN.STEPPED', 'BREAK_EVEN'],
    ['SESSION.WINDOW', 'SESSION'],
    ['EXIT.FORCED_TIME', 'EXIT'],
    ['POSITION_SIZE.FIXED_CONTRACTS', 'POSITION_SIZE'],
  ];
  for (const [id, category] of expectations) {
    const def = getRule(id);
    assert(def, id);
    assertEquals(def?.category, category);
  }
});

Deno.test('RC-03 no rule claims liveExecutionEligible=true (hard boundary: no live order this macro)', () => {
  assert(RULE_CATALOG.every((r) => r.liveExecutionEligible === false));
});

Deno.test('RC-04 an unknown rule id is reported unsupported, not silently accepted', () => {
  assert(!isSupportedRule('ENTRY.DOES_NOT_EXIST'));
  assertEquals(getRule('ENTRY.DOES_NOT_EXIST'), undefined);
});

Deno.test('RC-05 rulesByCategory only returns rules of the requested category', () => {
  const stopRules = rulesByCategory('STOP');
  assert(stopRules.length > 0);
  assert(stopRules.every((r) => r.category === 'STOP'));
});
