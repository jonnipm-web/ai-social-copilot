/**
 * Natural-language Strategy Draft — INSIGHTVALUES-ROBOT-BUILDER-MACRO-05
 * §16, §41.
 *
 * USER LANGUAGE -> IVE PARSING -> DRAFT StrategySpecification fragment ->
 * VALIDATION -> HUMAN REVIEW -> SAVED STRATEGY. This module only performs
 * the parsing step, and deliberately produces a PARTIAL, draft-only
 * fragment -- never a complete, auto-activatable StrategySpecification
 * (§16: "IVE MUST NOT silently activate it"; market profile, session
 * calendar and instrument identity can never be inferred from prose alone
 * and are always left for the human/structured-builder side to supply).
 *
 * This is a bounded, rule-based extractor, not a general NLU model: it
 * recognizes a fixed vocabulary (stop/target distances, break-even
 * trigger, direction words, pullback-entry phrasing, a 5-minute timeframe
 * mention) and explicitly flags anything it cannot confidently parse as an
 * ambiguity rather than guessing (§16: "If ambiguity materially changes
 * strategy behavior, surface it rather than inventing an interpretation").
 * Both authoring paths funnel into the SAME strategy_spec.ts constructor
 * (§41) -- this module never becomes a second execution path.
 */
import type { Direction } from './strategy_spec.ts';

export interface DraftFields {
  readonly stopDistance: number | null;
  readonly targetDistance: number | null;
  readonly breakEvenTriggerDistance: number | null;
  readonly allowedDirections: readonly Direction[] | null;
  readonly signalTimeframe: string | null;
  readonly pullbackEntryMentioned: boolean;
}

export interface NaturalLanguageDraftResult {
  readonly sourceText: string;
  readonly extracted: DraftFields;
  /** Human-readable notes on anything the text implied but this parser
   * could not confidently resolve into a field -- shown to the user so
   * they can see exactly how IVE interpreted (or failed to interpret)
   * each rule, per §16. */
  readonly ambiguities: readonly string[];
  /** Always true -- a draft is never itself a SAVED strategy. */
  readonly requiresHumanReview: true;
}

const STOP_RE = /\bstop[^\d,;]{0,10}?(\d+(?:\.\d+)?)(?!\s*(?:min|h|d)\b)/i;
const TARGET_RE = /\btarget[^\d,;]{0,10}?(\d+(?:\.\d+)?)(?!\s*(?:min|h|d)\b)/i;
const BREAK_EVEN_RE = /break[\s-]?even[^\d,;]{0,20}?\+?(\d+(?:\.\d+)?)(?!\s*(?:min|h|d)\b)/i;
const FIVE_MIN_RE = /\b5[\s-]?(?:minute|min)\b/i;
const PULLBACK_RE = /\bpullback\b/i;
const TREND_ONLY_RE = /\b(only\s+(?:in\s+)?(?:the\s+)?trend\s+direction|trend[\s-]following)\b/i;
const LONG_RE = /\blong\b/i;
const SHORT_RE = /\bshort\b/i;
const BOTH_RE = /\b(both\s+directions?|bidirectional)\b/i;

export function parseNaturalLanguageStrategyDraft(sourceText: string): NaturalLanguageDraftResult {
  const text = typeof sourceText === 'string' ? sourceText : '';
  const ambiguities: string[] = [];

  const stopMatch = STOP_RE.exec(text);
  const stopDistance = stopMatch ? Number(stopMatch[1]) : null;
  if (!stopMatch) ambiguities.push('No stop distance recognized -- must be supplied manually.');

  const targetMatch = TARGET_RE.exec(text);
  const targetDistance = targetMatch ? Number(targetMatch[1]) : null;
  if (!targetMatch) ambiguities.push('No target distance recognized -- must be supplied manually.');

  const beMatch = BREAK_EVEN_RE.exec(text);
  const breakEvenTriggerDistance = beMatch ? Number(beMatch[1]) : null;
  if (/break[\s-]?even/i.test(text) && !beMatch) {
    ambiguities.push('Break-even mentioned but no trigger distance recognized.');
  }

  let allowedDirections: readonly Direction[] | null = null;
  const long = LONG_RE.test(text);
  const short = SHORT_RE.test(text);
  const both = BOTH_RE.test(text) || TREND_ONLY_RE.test(text);
  if (both) {
    allowedDirections = ['LONG', 'SHORT'];
  } else if (long && !short) {
    allowedDirections = ['LONG'];
  } else if (short && !long) {
    allowedDirections = ['SHORT'];
  } else if (long && short) {
    allowedDirections = ['LONG', 'SHORT'];
  } else {
    ambiguities.push('No direction (long/short/both) recognized -- must be selected manually.');
  }
  if (TREND_ONLY_RE.test(text) && !both) {
    ambiguities.push('"trend direction" phrasing implies both directions are eligible depending on trend -- confirm this matches intent.');
  }

  const signalTimeframe = FIVE_MIN_RE.test(text) ? '5min' : null;
  if (!signalTimeframe) ambiguities.push('No recognized signal timeframe -- must be selected manually.');

  const pullbackEntryMentioned = PULLBACK_RE.test(text);
  if (!pullbackEntryMentioned) {
    ambiguities.push('No entry rule recognized (only "pullback" entry phrasing is understood today) -- must be selected manually.');
  }

  return Object.freeze({
    sourceText: text,
    extracted: Object.freeze({
      stopDistance,
      targetDistance,
      breakEvenTriggerDistance,
      allowedDirections,
      signalTimeframe,
      pullbackEntryMentioned,
    }),
    ambiguities: Object.freeze(ambiguities),
    requiresHumanReview: true,
  });
}
