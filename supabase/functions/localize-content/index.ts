/**
 * R16 — localize-content: lazy, cached PRESENTATION localization of persisted
 * content (historical AI output + allow-listed original user fields).
 *
 * Contract:
 *   POST { table: string, ids: string[] (<= 25), language: 'pt-BR'|'en-US' }
 *   -> { items: { [id]: { source_language, payload } } }
 *
 * Security (R16 §15/§23):
 *   - real user session required (resolveAuthenticatedUser / getUser);
 *   - rows are read with the service client ALWAYS filtered by the
 *     authenticated user's id -> a caller can only localize rows they own;
 *   - the client never supplies text: tables/columns are a server allowlist;
 *   - the row content is treated as untrusted DATA inside a delimiter; the
 *     translation policy lives in the trusted system prompt;
 *   - `language` is a presentation preference only.
 * Monetization (R16 §21/§30): this is presentation localization, not a new
 * analysis -> it does NOT consume analysis quota. Cost is bounded by the
 * per-(user,row,language,source-hash) cache and a per-user daily cap on
 * fresh translations.
 * Data preservation (R16 §8): originals are never written; translations live
 * only in public.content_localizations.
 */
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { AuthClient, AuthError, resolveAuthenticatedUser, unauthorizedResponse } from '../_shared/auth.ts';
import { resolveOutputLanguage } from '../_shared/language.ts';
import {
  applyTranslations,
  batchSegments,
  confidentlyInLanguage,
  extractSegments,
  LOCALIZABLE_FIELDS,
  majorityLanguage,
  parseTranslationResponse,
  sourceHash,
  TargetLanguage,
  translationSystemPrompt,
  translationUserMessage,
} from '../_shared/content_localization.ts';

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';
const MODEL = 'openai/gpt-oss-120b';
export const MAX_IDS_PER_REQUEST = 25;
/** Max model-backed attempts (successful OR failed) per user per 24h. */
export const DAILY_FRESH_TRANSLATION_CAP = 300;
/** Model marker for rows served without an LLM call (already in target language). */
export const MODEL_SAME_LANGUAGE = 'none:same-language';
/** Model marker for a failed attempt (counts toward the cap; retried after 24h). */
export const MODEL_FAILED = 'failed';
const RETRY_FAILED_AFTER_MS = 24 * 3600 * 1000;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export interface CachedLocalization {
  source_id: string;
  source_hash: string;
  source_language: string | null;
  payload: Record<string, unknown>;
  model?: string;
  updated_at?: string;
}

/** I/O boundary, injectable for tests. */
export interface LocalizationDeps {
  fetchOwnedRows(userId: string, table: string, ids: string[], columns: string[]): Promise<Record<string, unknown>[]>;
  fetchCache(userId: string, table: string, ids: string[], lang: TargetLanguage): Promise<CachedLocalization[]>;
  /** Counts model-backed attempts (success + failure) in the last 24h. */
  countFreshToday(userId: string): Promise<number>;
  /** profiles.is_active — deactivated accounts get no paid capacity. */
  isActive(userId: string): Promise<boolean>;
  saveCache(row: {
    user_id: string; source_table: string; source_id: string; target_language: TargetLanguage;
    source_hash: string; source_language: string | null; payload: Record<string, unknown>; model: string;
  }): Promise<void>;
  translate(system: string, user: string): Promise<string>;
}

export async function handler(req: Request, deps?: LocalizationDeps, authClient?: AuthClient): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  let userId: string;
  try {
    userId = (await resolveAuthenticatedUser(req, authClient)).id;
  } catch (e) {
    if (e instanceof AuthError) return unauthorizedResponse(corsHeaders);
    throw e;
  }

  const d = deps ?? defaultDeps();
  // Same boundary requireModuleAccess enforces for module functions: a
  // deactivated account must not spend AI capacity (fail closed).
  if (!(await d.isActive(userId).catch(() => false))) return json({ error: 'account_inactive' }, 403);

  const body = await req.json().catch(() => null) as Record<string, unknown> | null;
  if (!body) return json({ error: 'invalid_body' }, 400);
  const table = typeof body.table === 'string' ? body.table : '';
  const columns = LOCALIZABLE_FIELDS[table];
  if (!columns) return json({ error: 'table_not_localizable' }, 400);
  const ids = Array.isArray(body.ids)
    ? [...new Set(body.ids.filter((x): x is string => typeof x === 'string' && UUID_RE.test(x)))]
    : [];
  if (ids.length === 0) return json({ items: {} });
  if (ids.length > MAX_IDS_PER_REQUEST) return json({ error: 'too_many_ids', max: MAX_IDS_PER_REQUEST }, 400);
  const lang = resolveOutputLanguage(body);

  const rows = await d.fetchOwnedRows(userId, table, ids, [...columns]);
  const cache = new Map((await d.fetchCache(userId, table, rows.map((r) => String(r.id)), lang)).map((c) => [c.source_id, c]));

  const items: Record<string, { source_language: string | null; payload: Record<string, unknown> }> = {};
  const fresh = DAILY_FRESH_TRANSLATION_CAP - await d.countFreshToday(userId);
  let freshBudget = fresh;

  const work = async (row: Record<string, unknown>) => {
    const id = String(row.id);
    const segments = extractSegments(table, row);
    if (segments.length === 0) return;
    const hash = await sourceHash(segments);
    const hit = cache.get(id);
    if (hit && hit.source_hash === hash) {
      if (hit.model !== MODEL_FAILED) {
        items[id] = { source_language: hit.source_language, payload: hit.payload };
        return;
      }
      // A failed attempt is not retried for 24h (no retry storm on bad rows).
      const age = Date.now() - Date.parse(hit.updated_at ?? '');
      if (!(age > RETRY_FAILED_AFTER_MS)) return;
    }

    // Cost optimization: text that is overwhelmingly already in the target
    // language is served as-is, cached, with no model call.
    if (confidentlyInLanguage(segments, lang)) {
      await d.saveCache({
        user_id: userId, source_table: table, source_id: id, target_language: lang,
        source_hash: hash, source_language: lang, payload: {}, model: MODEL_SAME_LANGUAGE,
      }).catch(() => {});
      return;
    }

    if (freshBudget <= 0) return; // graceful: row stays original this time
    freshBudget -= 1;
    const recordFailure = () => d.saveCache({
      user_id: userId, source_table: table, source_id: id, target_language: lang,
      source_hash: hash, source_language: null, payload: {}, model: MODEL_FAILED,
    }).catch(() => {});

    const translations: string[] = [];
    const langs: (string | null)[] = [];
    for (const batch of batchSegments(segments)) {
      const raw = await d.translate(translationSystemPrompt(lang), translationUserMessage(batch)).catch(() => '');
      const parsed = parseTranslationResponse(raw, batch.length);
      if (!parsed) { await recordFailure(); return; } // never cache partial output
      translations.push(...parsed.translations);
      langs.push(parsed.sourceLanguage);
    }
    const payload = applyTranslations(table, row, segments, translations);
    const sourceLanguage = majorityLanguage(langs);
    await d.saveCache({
      user_id: userId, source_table: table, source_id: id, target_language: lang,
      source_hash: hash, source_language: sourceLanguage, payload, model: MODEL,
    }).catch(() => {});
    items[id] = { source_language: sourceLanguage, payload };
  };

  // Bounded concurrency keeps latency low without bursting the provider.
  const queue = [...rows];
  await Promise.all(Array.from({ length: Math.min(4, queue.length) }, async () => {
    while (queue.length > 0) await work(queue.shift()!);
  }));

  return json({ items, language: lang });
}

function defaultDeps(): LocalizationDeps {
  // Lazy import keeps unit tests free of network modules.
  let svc: ReturnType<typeof createServiceClientSync> | null = null;
  const db = () => (svc ??= createServiceClientSync());
  return {
    async fetchOwnedRows(userId, table, ids, columns) {
      const { data, error } = await (await db()).from(table)
        .select(['id', ...columns].join(','))
        .eq('user_id', userId)
        .in('id', ids);
      if (error) throw error;
      return (data ?? []) as unknown as Record<string, unknown>[];
    },
    async fetchCache(userId, table, ids, lang) {
      if (ids.length === 0) return [];
      const { data, error } = await (await db()).from('content_localizations')
        .select('source_id, source_hash, source_language, payload, model, updated_at')
        .eq('user_id', userId).eq('source_table', table).eq('target_language', lang)
        .in('source_id', ids);
      if (error) throw error;
      return (data ?? []) as CachedLocalization[];
    },
    async countFreshToday(userId) {
      const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
      const { count, error } = await (await db()).from('content_localizations')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', userId).gte('updated_at', since)
        .neq('model', MODEL_SAME_LANGUAGE);
      if (error) throw error;
      return count ?? 0;
    },
    async isActive(userId) {
      const { data, error } = await (await db()).from('profiles')
        .select('is_active').eq('id', userId).maybeSingle();
      if (error) throw error;
      if (!data) return false; // no profile -> fail closed (same as entitlement.ts)
      return (data as { is_active?: boolean }).is_active !== false;
    },
    async saveCache(row) {
      const { error } = await (await db()).from('content_localizations')
        .upsert({ ...row, updated_at: new Date().toISOString() }, { onConflict: 'user_id,source_table,source_id,target_language' });
      if (error) throw error;
    },
    async translate(system, user) {
      const key = Deno.env.get('GROQ_API_KEY') ?? '';
      const res = await fetch(GROQ_URL, {
        method: 'POST',
        headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: MODEL,
          temperature: 0.1,
          max_completion_tokens: 8000,
          response_format: { type: 'json_object' },
          messages: [{ role: 'system', content: system }, { role: 'user', content: user }],
        }),
      });
      if (!res.ok) throw new Error(`groq_${res.status}`);
      const j = await res.json();
      return String(j?.choices?.[0]?.message?.content ?? '');
    },
  };
}

async function createServiceClientSync() {
  const { createServiceClient } = await import('../_shared/service_client.ts');
  return createServiceClient();
}

if (Deno.env.get('DENO_TESTING') !== '1') {
  serve((req) => handler(req));
}
