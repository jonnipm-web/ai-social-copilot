/**
 * IVE memory policy (IVE-INTELLIGENCE-CORE-01) — the single place that
 * decides what may become DURABLE memory and which memories are read back.
 *
 * Levels (only the ones the real architecture justifies — no new table):
 *   SESSION   the visible chat transcript; never persisted by the core,
 *             sent back by the client as `conversation`, budget-trimmed.
 *   PROJECT   business_memory rows with project_id = a project the user owns.
 *   USER      business_memory rows with scope 'user' (project_id null).
 *
 * A chat message never becomes memory automatically. The core only returns
 * CANDIDATES; persistence happens through the explicit promote path
 * (ive-memory function), which re-runs this policy server-side.
 *
 * Memory is ALWAYS untrusted data in the prompt: origin is provenance, not
 * privilege. No memory row can grant a capability, a plan or a role.
 */

import { canonicalize } from './text_normalize.ts';

export type MemoryCategory = 'preference' | 'decision' | 'goal' | 'constraint' | 'context_summary';
export type MemoryScope = 'project' | 'user';
export type MemoryOrigin = 'user_authored' | 'ive_derived' | 'system_derived' | 'external_agent_derived';

export const MEMORY_CATEGORIES: ReadonlySet<MemoryCategory> = new Set(['preference', 'decision', 'goal', 'constraint', 'context_summary']);

export const MEMORY_LIMITS = {
  minChars: 12,
  maxChars: 500,
  maxTitleChars: 120,
} as const;

/** Patterns that must never be persisted: credentials, tokens, keys, card
 * numbers. Deliberately broad — a false positive only means "not saved". */
const SECRET_PATTERNS: readonly RegExp[] = [
  /\b(senha|password|passwd|pwd|secret|segredo|token|api[_ -]?key|chave de api|private key|chave privada)\b\s*[:=]/i,
  /\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}/, // JWT
  /\b(sk|pk|rk)_(live|test)_[A-Za-z0-9]{8,}/, // Stripe-like keys
  /\bgh[pousr]_[A-Za-z0-9]{20,}/, // GitHub tokens
  /\bAKIA[0-9A-Z]{16}\b/, // AWS access key id
  /-----BEGIN [A-Z ]*PRIVATE KEY-----/,
  /\b(?:\d[ -]?){13,19}\b/, // card-like digit runs
  /\bsb_(secret|publishable)_[A-Za-z0-9_-]{10,}/,
  /\bbearer\s+[A-Za-z0-9._~+/=-]{16,}/i, // Authorization header values
  /\b(AIza[0-9A-Za-z_-]{30,}|xox[abpr]-[0-9A-Za-z-]{10,}|gsk_[0-9A-Za-z]{20,})/, // Google / Slack / Groq keys
  // Unlabeled high-entropy tokens: 32+ chars mixing letters and digits.
  /\b(?=[A-Za-z0-9_-]*\d)(?=[A-Za-z0-9_-]*[A-Za-z])[A-Za-z0-9_-]{32,}\b/,
];

/** Checked on the raw text AND on its canonical form (Codex Gate 1 IG1-05),
 * so zero-width characters, full-width forms or look-alike letters inside a
 * credential (a zero-width space inside "password:") do not slip through. Pattern-based by
 * nature: a residual risk remains for arbitrary unlabeled secrets, which is
 * why memory is also never sent anywhere but the user's own prompt. */
export function containsSecret(text: string): boolean {
  const views = [text, text.normalize('NFKC').replace(/[\u00AD\u200B-\u200F\u2060-\u206F\uFEFF]/g, ''), canonicalize(text)];
  return views.some((v) => SECRET_PATTERNS.some((re) => re.test(v)));
}

export interface MemoryCandidate {
  category: string;
  text: string;
  scope: string;
  projectId: string | null;
}

export type MemoryVerdict =
  | { accept: true; category: MemoryCategory; scope: MemoryScope; text: string; dedupKey: string }
  | { accept: false; reason: 'CATEGORY_NOT_ALLOWED' | 'SCOPE_INVALID' | 'PROJECT_REQUIRED' | 'TOO_SHORT' | 'TOO_LONG' | 'SECRET_DETECTED' };

export function normalizeMemoryText(text: string): string {
  return text.replace(/\s+/g, ' ').trim();
}

/** Deterministic dedup key: same category + same normalized wording in the
 * same scope/project is the same memory (newer supersedes older). */
export async function memoryDedupKey(category: string, scope: string, projectId: string | null, text: string): Promise<string> {
  const canonical = `${category}|${scope}|${projectId ?? '-'}|${normalizeMemoryText(text).toLowerCase()}`;
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(canonical));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}

export async function evaluateMemoryCandidate(c: MemoryCandidate): Promise<MemoryVerdict> {
  if (!MEMORY_CATEGORIES.has(c.category as MemoryCategory)) return { accept: false, reason: 'CATEGORY_NOT_ALLOWED' };
  if (c.scope !== 'project' && c.scope !== 'user') return { accept: false, reason: 'SCOPE_INVALID' };
  if (c.scope === 'project' && !c.projectId) return { accept: false, reason: 'PROJECT_REQUIRED' };
  if (c.scope === 'user' && c.projectId) return { accept: false, reason: 'SCOPE_INVALID' };
  const text = normalizeMemoryText(typeof c.text === 'string' ? c.text : '');
  if (text.length < MEMORY_LIMITS.minChars) return { accept: false, reason: 'TOO_SHORT' };
  if (text.length > MEMORY_LIMITS.maxChars) return { accept: false, reason: 'TOO_LONG' };
  if (containsSecret(text)) return { accept: false, reason: 'SECRET_DETECTED' };
  return {
    accept: true,
    category: c.category as MemoryCategory,
    scope: c.scope,
    text,
    dedupKey: await memoryDedupKey(c.category, c.scope, c.projectId, text),
  };
}

export interface MemoryRow {
  id: string;
  /** Owner — checked again by the assembler (Codex Gate 1 IG1-02). */
  user_id?: string;
  project_id: string | null;
  memory_type: string | null;
  title: string | null;
  content: string | null;
  source: string | null;
  created_at: string | null;
  scope?: string | null;
  origin?: string | null;
  status?: string | null;
  expires_at?: string | null;
  updated_at?: string | null;
}

/** Read-side policy: only active, unexpired memories of the verified scope
 * (this project + user-level), newest first. Works on legacy rows (no
 * scope/status columns yet) by treating them as active. */
export function selectMemories(rows: readonly MemoryRow[], projectId: string | null, now: Date = new Date()): MemoryRow[] {
  return rows
    .filter((r) => (r.status ?? 'active') === 'active')
    .filter((r) => !r.expires_at || new Date(r.expires_at).getTime() > now.getTime())
    .filter((r) => (r.project_id === null) || (projectId !== null && r.project_id === projectId))
    .filter((r) => typeof r.content === 'string' && r.content.trim().length > 0)
    .filter((r) => !containsSecret(r.content!))
    .sort((a, b) => (b.updated_at ?? b.created_at ?? '').localeCompare(a.updated_at ?? a.created_at ?? '') || a.id.localeCompare(b.id));
}

/** Candidate extraction from a user message: only explicit, durable
 * statements ("lembre que…", "remember that…", "nossa meta é…"), never the
 * whole message and never the model's answer. Returned to the client as a
 * suggestion; persisted only through the explicit promote path. */
export function extractMemoryCandidates(message: string): { category: MemoryCategory; text: string }[] {
  const rules: { re: RegExp; category: MemoryCategory }[] = [
    { re: /\b(?:lembre(?:-se)?(?: de)? que|remember that)\s+(.{12,500})/i, category: 'context_summary' },
    { re: /\b(?:nossa meta é|nosso objetivo é|our goal is|my goal is)\s+(.{12,500})/i, category: 'goal' },
    { re: /\b(?:decidimos|we decided)\s+(.{12,500})/i, category: 'decision' },
    { re: /\b(?:prefiro|i prefer)\s+(.{12,500})/i, category: 'preference' },
    { re: /\b(?:não podemos|we cannot|we can't)\s+(.{12,500})/i, category: 'constraint' },
  ];
  const out: { category: MemoryCategory; text: string }[] = [];
  for (const { re, category } of rules) {
    const m = re.exec(message);
    if (!m) continue;
    const text = normalizeMemoryText(m[1]).slice(0, MEMORY_LIMITS.maxChars);
    if (text.length >= MEMORY_LIMITS.minChars && !containsSecret(text)) out.push({ category, text });
  }
  return out;
}
