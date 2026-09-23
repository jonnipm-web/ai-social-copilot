/**
 * IVE durable-memory write path (IVE-INTELLIGENCE-CORE-01).
 *
 * The only sanctioned way IVE-derived memory becomes durable: the client
 * asks to PROMOTE a candidate the user accepted, and the server re-runs the
 * memory policy (category, secrets, size, scope), verifies project
 * ownership, de-duplicates, and writes with the caller's own JWT (RLS).
 * No service role. No AI call, so no quota.
 *
 * Ops:
 *   promote { category, text, scope, project_id?, supersedes_id? }
 *   forget  { memory_id }        → status 'expired' (soft, auditable)
 */
import { type AuthClient, AuthError, type AuthenticatedUser, resolveAuthenticatedUser, unauthorizedResponse } from '../auth.ts';
import { type EntitlementSubjectSource, requireModuleAccess } from '../entitlement.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.116.0';
import { corsHeaders, errorResponse } from './intelligence.ts';
import { evaluateMemoryCandidate } from './memory_policy.ts';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface MemoryInsert {
  user_id: string;
  project_id: string | null;
  scope: 'project' | 'user';
  memory_type: string;
  title: string;
  content: string;
  source: string;
  origin: 'ive_derived';
  status: 'active';
  dedup_key: string;
}

/** Every method filters by the authenticated user id; RLS is the second wall. */
export interface IveMemoryStore {
  ownsProject(userId: string, projectId: string): Promise<boolean>;
  findActiveByDedup(userId: string, dedupKey: string): Promise<{ id: string } | null>;
  getActive(userId: string, memoryId: string): Promise<{ id: string; scope: string | null; project_id: string | null } | null>;
  /** Returns null when the database refused a duplicate ACTIVE dedup key
   * (unique index uq_business_memory_active_dedup) — a concurrent promote won. */
  insert(row: MemoryInsert): Promise<{ id: string } | null>;
  /** Returns true only when exactly one own ACTIVE row was superseded. */
  markSuperseded(userId: string, memoryId: string, supersededBy: string): Promise<boolean>;
  expire(userId: string, memoryId: string): Promise<boolean>;
}

export interface IveMemoryDeps {
  authClient?: AuthClient;
  subjectSource?: EntitlementSubjectSource;
  store?: (accessToken: string) => IveMemoryStore;
}

function ok(body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

export async function handleIveMemory(req: Request, deps: IveMemoryDeps = {}): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  let user: AuthenticatedUser;
  try {
    user = await resolveAuthenticatedUser(req, deps.authClient);
  } catch (e) {
    if (e instanceof AuthError) return unauthorizedResponse(corsHeaders);
    throw e;
  }
  const access = await requireModuleAccess(req, user, 'context-copilot', corsHeaders, deps.subjectSource);
  if (!access.allowed) return access.response;
  const cid = access.correlationId;

  if (req.method !== 'POST') return errorResponse('INVALID_REQUEST', cid, { field: 'method' });
  const body = await req.json().catch(() => null);
  if (typeof body !== 'object' || body === null || Array.isArray(body)) return errorResponse('INVALID_REQUEST', cid, { field: 'body' });

  const token = req.headers.get('Authorization')?.match(/^Bearer\s+(.+)$/i)?.[1]?.trim() ?? '';
  let store: IveMemoryStore;
  try {
    store = (deps.store ?? ((t: string) => new SupabaseIveMemoryStore(t)))(token);
  } catch {
    return errorResponse('CONTEXT_UNAVAILABLE', cid);
  }

  try {
    if (body.op === 'forget') {
      if (typeof body.memory_id !== 'string' || !UUID_RE.test(body.memory_id)) return errorResponse('INVALID_REQUEST', cid, { field: 'memory_id' });
      const done = await store.expire(user.id, body.memory_id.toLowerCase());
      return ok({ status: done ? 'FORGOTTEN' : 'NOT_FOUND', correlation_id: cid });
    }
    if (body.op !== 'promote') return errorResponse('INVALID_REQUEST', cid, { field: 'op' });

    let projectId: string | null = null;
    if (body.project_id !== undefined && body.project_id !== null) {
      if (typeof body.project_id !== 'string' || !UUID_RE.test(body.project_id)) return errorResponse('INVALID_REQUEST', cid, { field: 'project_id' });
      projectId = body.project_id.toLowerCase();
    }
    const verdict = await evaluateMemoryCandidate({ category: body.category, text: body.text, scope: body.scope, projectId });
    if (!verdict.accept) return ok({ status: 'REJECTED', reason: verdict.reason, correlation_id: cid });

    if (projectId && !(await store.ownsProject(user.id, projectId))) return errorResponse('PROJECT_FORBIDDEN', cid);

    const existing = await store.findActiveByDedup(user.id, verdict.dedupKey);
    if (existing) return ok({ status: 'DEDUPLICATED', memory_id: existing.id, correlation_id: cid });

    let supersedes: string | null = null;
    if (body.supersedes_id !== undefined && body.supersedes_id !== null) {
      if (typeof body.supersedes_id !== 'string' || !UUID_RE.test(body.supersedes_id)) return errorResponse('INVALID_REQUEST', cid, { field: 'supersedes_id' });
      const old = await store.getActive(user.id, body.supersedes_id.toLowerCase());
      // Only an own, active memory of the SAME scope/project can be superseded.
      if (!old || old.scope !== verdict.scope || old.project_id !== projectId) return errorResponse('INVALID_REQUEST', cid, { field: 'supersedes_id' });
      supersedes = old.id;
    }

    const created = await store.insert({
      user_id: user.id,
      project_id: projectId,
      scope: verdict.scope,
      memory_type: verdict.category,
      title: verdict.text.slice(0, 120),
      content: verdict.text,
      source: 'ive_intelligence_core',
      origin: 'ive_derived',
      status: 'active',
      dedup_key: verdict.dedupKey,
    });
    if (!created) {
      // Codex Gate 1 IG1-08 — a concurrent identical promote won the race.
      const winner = await store.findActiveByDedup(user.id, verdict.dedupKey);
      return ok({ status: 'DEDUPLICATED', memory_id: winner?.id ?? null, correlation_id: cid });
    }
    // The old row may have been forgotten/superseded concurrently: report
    // what actually happened instead of assuming success.
    const supersededOk = supersedes ? await store.markSuperseded(user.id, supersedes, created.id) : false;
    console.log(JSON.stringify({ event: 'ive_memory', op: 'promote', correlation_id: cid, scope: verdict.scope, category: verdict.category, superseded: supersededOk }));
    return ok({ status: 'PROMOTED', memory_id: created.id, superseded_id: supersededOk ? supersedes : null, correlation_id: cid });
  } catch {
    return errorResponse('CONTEXT_UNAVAILABLE', cid);
  }
}

export class SupabaseIveMemoryStore implements IveMemoryStore {
  // deno-lint-ignore no-explicit-any
  private readonly c: any;
  constructor(accessToken: string) {
    const url = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    if (!url || !anonKey) throw new Error('memory store misconfigured');
    this.c = createClient(url, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
    });
  }
  async ownsProject(userId: string, projectId: string): Promise<boolean> {
    const { data, error } = await this.c.from('projects').select('id').eq('id', projectId).eq('user_id', userId).maybeSingle();
    if (error) throw new Error('read failed');
    return !!data;
  }
  async findActiveByDedup(userId: string, dedupKey: string) {
    const { data, error } = await this.c.from('business_memory').select('id')
      .eq('user_id', userId).eq('dedup_key', dedupKey).eq('status', 'active').maybeSingle();
    if (error) throw new Error('read failed');
    return data ?? null;
  }
  async getActive(userId: string, memoryId: string) {
    const { data, error } = await this.c.from('business_memory').select('id, scope, project_id')
      .eq('user_id', userId).eq('id', memoryId).eq('status', 'active').maybeSingle();
    if (error) throw new Error('read failed');
    return data ?? null;
  }
  async insert(row: MemoryInsert) {
    const { data, error } = await this.c.from('business_memory').insert(row).select('id').single();
    if (error && (error as { code?: string }).code === '23505') return null; // unique_violation
    if (error || !data) throw new Error('insert failed');
    return data as { id: string };
  }
  async markSuperseded(userId: string, memoryId: string, supersededBy: string) {
    const { data, error } = await this.c.from('business_memory').update({ status: 'superseded', superseded_by: supersededBy })
      .eq('user_id', userId).eq('id', memoryId).eq('status', 'active').select('id');
    if (error) throw new Error('update failed');
    return Array.isArray(data) && data.length === 1;
  }
  async expire(userId: string, memoryId: string) {
    const { data, error } = await this.c.from('business_memory').update({ status: 'expired', expires_at: new Date().toISOString() })
      .eq('user_id', userId).eq('id', memoryId).eq('status', 'active').select('id');
    if (error) throw new Error('update failed');
    return Array.isArray(data) && data.length > 0;
  }
}
