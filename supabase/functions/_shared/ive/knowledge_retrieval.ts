/**
 * Server-side Knowledge grounding (IVE-INTELLIGENCE-CORE-01).
 *
 * Deterministic port of the client's DocumentContextBuilder
 * (lib/data/services/document_context_builder.dart): 800-char chunks with
 * 100 overlap, word-overlap relevance against the query, best chunk per
 * document first, 8000-char total budget. No embeddings: the repository has
 * no vector infrastructure, and a deterministic lexical ranker is testable.
 *
 * Retrieval boundary: this module only ranks what the data source already
 * returned for (authenticated user, verified project). It never fetches.
 */
import { CONTEXT_BUDGET_CHARS } from './budget.ts';
import type { ProvenanceEntry } from './contracts.ts';

export interface KnowledgeRow {
  id: string;
  /** Owner — checked again by the assembler (Codex Gate 1 IG1-02). */
  user_id?: string;
  title: string | null;
  content: string | null;
  status: string | null;
  project_id: string | null;
  updated_at: string | null;
}

export interface KnowledgeExcerpt {
  documentId: string;
  title: string;
  text: string;
  score: number;
  provenance: ProvenanceEntry;
}

const CHUNK = 800;
const OVERLAP = 100;

export function chunk(text: string): string[] {
  if (text.length <= CHUNK) return [text];
  const out: string[] = [];
  for (let start = 0; start < text.length; start += CHUNK - OVERLAP) {
    out.push(text.slice(start, start + CHUNK));
    if (start + CHUNK >= text.length) break;
  }
  return out;
}

export function words(text: string): Set<string> {
  return new Set(
    text.toLowerCase().normalize('NFD').replace(/[\u0300-\u036F]/g, '')
      .split(/[^a-z0-9]+/).filter((w) => w.length > 3),
  );
}

function overlap(chunkWords: Set<string>, query: Set<string>): number {
  if (query.size === 0) return 0;
  let hits = 0;
  for (const w of chunkWords) if (query.has(w)) hits++;
  return hits / query.size;
}

/** Only processed documents with content are groundable; everything else is
 * registered-but-not-analysed and must not be presented as read. */
export function isGroundable(row: KnowledgeRow): boolean {
  return row.status === 'analyzed' && typeof row.content === 'string' && row.content.trim().length > 0;
}

export function selectKnowledge(
  rows: readonly KnowledgeRow[],
  query: string,
  budgetChars: number = CONTEXT_BUDGET_CHARS.knowledge,
): { excerpts: KnowledgeExcerpt[]; truncated: boolean; considered: number; ungroundable: number } {
  const q = words(query);
  const ranked: { row: KnowledgeRow; text: string; score: number }[] = [];
  let ungroundable = 0;
  for (const row of rows) {
    if (!isGroundable(row)) { ungroundable++; continue; }
    const scored = chunk(row.content!).map((text) => ({ text, score: overlap(words(text), q) }));
    scored.sort((a, b) => b.score - a.score);
    ranked.push({ row, text: scored[0].text, score: scored[0].score });
  }
  // Most relevant first; ties broken by recency, then id, for determinism.
  ranked.sort((a, b) =>
    b.score - a.score ||
    (b.row.updated_at ?? '').localeCompare(a.row.updated_at ?? '') ||
    a.row.id.localeCompare(b.row.id));

  const excerpts: KnowledgeExcerpt[] = [];
  let used = 0;
  let truncated = false;
  for (const r of ranked) {
    const remaining = budgetChars - used;
    if (remaining <= 0) { truncated = true; break; }
    const text = r.text.length > remaining ? r.text.slice(0, remaining) : r.text;
    if (text.length < r.text.length) truncated = true;
    used += text.length;
    excerpts.push({
      documentId: r.row.id,
      title: r.row.title ?? '',
      text,
      score: r.score,
      provenance: {
        sourceType: 'knowledge_document',
        sourceId: r.row.id,
        projectId: r.row.project_id,
        label: r.row.title ?? '',
        updatedAt: r.row.updated_at,
        reason: r.score > 0 ? 'lexical_relevance' : 'project_document',
        trust: 'untrusted_user_content',
      },
    });
  }
  return { excerpts, truncated, considered: rows.length, ungroundable };
}
