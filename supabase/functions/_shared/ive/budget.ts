/**
 * IVE context budget + priority (IVE-INTELLIGENCE-CORE-01).
 *
 * Unlimited context is forbidden. Budgets are in characters (the only
 * unit the current Groq integration exposes deterministically) and per
 * category, so one noisy source can never crowd out a more important one.
 *
 * Priority (highest first) — what survives when a request is large:
 *   1 SYSTEM POLICY          fixed text, never truncated
 *   2 AUTH / CAPABILITIES    server-verified, tiny, never truncated
 *   3 CURRENT PROJECT        server-verified metadata of the owned project
 *   4 USER REQUEST           the message itself (validated ≤ 4000 chars upstream)
 *   5 RELEVANT KNOWLEDGE     retrieved excerpts, relevance-ranked
 *   6 PROJECT STATE          top opportunities / actions
 *   7 DURABLE MEMORY         active, non-superseded, most recent first
 *   8 OLD CONVERSATION       oldest turns dropped first
 *
 * USER REQUEST ranks above knowledge/memory because answering what was
 * asked beats background; CURRENT PROJECT ranks above the request because
 * it is the scope the request is interpreted in (and is small).
 */

export const CONTEXT_BUDGET_CHARS = {
  project: 1200,
  knowledge: 8000, // same delivery budget the client-side DocumentContextBuilder used
  opportunities: 1500,
  actions: 1500,
  memory: 1500,
  conversation: 6000,
} as const;

export const CONTEXT_ITEM_LIMITS = {
  opportunities: 5,
  actions: 5,
  knowledgeDocuments: 20, // candidates fetched; excerpts selected by relevance within the char budget
  memories: 10,
} as const;

export interface Fitted<T> {
  items: T[];
  truncated: boolean;
  dropped: number;
  usedChars: number;
}

/** Keeps items in the given (priority) order until the budget is spent.
 * An item that does not fit is dropped, not cut, unless `cut` is given. */
export function fitToBudget<T>(
  items: readonly T[],
  size: (t: T) => number,
  budget: number,
  cut?: (t: T, remaining: number) => T | null,
): Fitted<T> {
  const out: T[] = [];
  let used = 0;
  let truncated = false;
  for (const item of items) {
    const n = size(item);
    if (used + n <= budget) {
      out.push(item);
      used += n;
      continue;
    }
    truncated = true;
    const remaining = budget - used;
    if (cut && remaining > 0) {
      const partial = cut(item, remaining);
      if (partial !== null) {
        out.push(partial);
        used += size(partial);
      }
    }
    break;
  }
  return { items: out, truncated, dropped: items.length - out.length, usedChars: used };
}

/** Conversation: keep the NEWEST turns that fit (oldest are least useful). */
export function fitConversation<T extends { content: string }>(turns: readonly T[], budget: number): Fitted<T> {
  const reversed = [...turns].reverse();
  const fitted = fitToBudget(reversed, (t) => t.content.length, budget);
  return { ...fitted, items: fitted.items.reverse() };
}
