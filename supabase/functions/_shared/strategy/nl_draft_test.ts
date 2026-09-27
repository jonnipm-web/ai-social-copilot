import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { parseNaturalLanguageStrategyDraft } from './nl_draft.ts';

Deno.test('NL-01 the §16 example phrase extracts stop/target/break-even/direction/timeframe with no ambiguity on those fields', () => {
  const draft = parseNaturalLanguageStrategyDraft(
    'Operate only in the trend direction on 5-minute signals after a pullback, stop 100, target 250, break-even after +50...',
  );
  assertEquals(draft.extracted.stopDistance, 100);
  assertEquals(draft.extracted.targetDistance, 250);
  assertEquals(draft.extracted.breakEvenTriggerDistance, 50);
  assertEquals(draft.extracted.allowedDirections, ['LONG', 'SHORT']);
  assertEquals(draft.extracted.signalTimeframe, '5min');
  assertEquals(draft.extracted.pullbackEntryMentioned, true);
  assertEquals(draft.requiresHumanReview, true);
});

Deno.test('NL-02 a draft is NEVER a complete, activatable spec -- it always requires human review', () => {
  const draft = parseNaturalLanguageStrategyDraft('stop 100, target 250');
  assertEquals(draft.requiresHumanReview, true);
  assert(!('execute' in draft));
});

Deno.test('NL-03 vague text with no recognizable rules surfaces ambiguities instead of inventing values', () => {
  const draft = parseNaturalLanguageStrategyDraft('make me a strategy that wins a lot');
  assertEquals(draft.extracted.stopDistance, null);
  assertEquals(draft.extracted.targetDistance, null);
  assertEquals(draft.extracted.allowedDirections, null);
  assert(draft.ambiguities.length >= 4);
});

Deno.test('NL-04 "long only" and "short only" are distinguished, not collapsed to bidirectional', () => {
  const long = parseNaturalLanguageStrategyDraft('long only, stop 50, target 100, 5min, pullback entry');
  assertEquals(long.extracted.allowedDirections, ['LONG']);

  const short = parseNaturalLanguageStrategyDraft('short only, stop 50, target 100, 5min, pullback entry');
  assertEquals(short.extracted.allowedDirections, ['SHORT']);
});

Deno.test('NL-05 break-even mentioned without a parseable trigger distance is flagged as ambiguous, not silently dropped', () => {
  const draft = parseNaturalLanguageStrategyDraft('stop 100, target 250, use break-even protection, 5min, pullback');
  assertEquals(draft.extracted.breakEvenTriggerDistance, null);
  assert(draft.ambiguities.some((a) => a.toLowerCase().includes('break-even')));
});
