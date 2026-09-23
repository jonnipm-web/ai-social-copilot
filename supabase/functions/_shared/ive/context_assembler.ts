/**
 * IVE Context Assembler (IVE-INTELLIGENCE-CORE-01) — ONE context architecture
 * for every surface. Screens no longer decide what the model sees.
 *
 * Steps (fixed order):
 *   1 subject (already authenticated + entitled by the caller)
 *   2 authorized capabilities   ← Entitlement Core (listModuleDecisions)
 *   3 project                   ← requested id, VERIFIED owned (fail closed)
 *   4 project state             ← opportunities / actions, only if the
 *                                  module is authorized, project-scoped
 *   5 knowledge                 ← only if knowledge-vault is authorized;
 *                                  user + verified project only; ranked, capped
 *   6 memory                    ← this project + user-level, active only
 *   7 provenance + budgets + degradation flags
 *
 * Authorization-bearing steps (2, 3) fail closed. Optional context (4–6)
 * degrades: the answer continues without it and says so in `degraded`.
 *
 * Data minimization: bounded queries (limits below), only the columns the
 * prompt uses, never "all projects", never another project's rows.
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.116.0';
import { type EntitlementSubject, listModuleDecisions } from '../entitlement.ts';
import { CONTEXT_BUDGET_CHARS, CONTEXT_ITEM_LIMITS, type Fitted, fitToBudget } from './budget.ts';
import type { ContextSourceStatus, DegradedSource, IveIntelligenceRequest, ProvenanceEntry } from './contracts.ts';
import { type KnowledgeExcerpt, type KnowledgeRow, selectKnowledge } from './knowledge_retrieval.ts';
import { type MemoryRow, selectMemories } from './memory_policy.ts';

export interface ProjectRow {
  id: string;
  user_id: string;
  name: string | null;
  description: string | null;
  type: string | null;
  status: string | null;
  updated_at: string | null;
}
export interface OpportunityRow {
  id: string;
  user_id?: string;
  project_id: string | null;
  title: string | null;
  final_score: number | null;
  status: string | null;
  opportunity_type: string | null;
}
export interface ActionRow {
  id: string;
  user_id?: string;
  project_id: string | null;
  title: string | null;
  status: string | null;
  priority: number | null;
  impact_score: number | null;
  effort_score: number | null;
}

/** Everything the assembler may read. Every method receives the
 * authenticated user id and MUST filter by it (RLS is the second wall).
 * Injectable so tests never touch a database. */
export interface IveDataSource {
  getOwnedProject(userId: string, projectId: string): Promise<ProjectRow | null>;
  listOpportunities(userId: string, projectId: string, limit: number): Promise<OpportunityRow[]>;
  listActions(userId: string, projectId: string, limit: number): Promise<ActionRow[]>;
  listKnowledge(userId: string, projectId: string | null, limit: number): Promise<KnowledgeRow[]>;
  listMemories(userId: string, projectId: string | null, limit: number): Promise<MemoryRow[]>;
}

export class ProjectForbiddenError extends Error {}
export class ContextUnavailableError extends Error {}

export interface IveIntelligenceContext {
  subject: { type: string; plan: string | null; roles: string[] };
  surface: string;
  locale: string;
  authorizedModules: string[];
  project: ProjectRow | null;
  opportunities: OpportunityRow[];
  actions: ActionRow[];
  knowledge: KnowledgeExcerpt[];
  memories: MemoryRow[];
  provenance: ProvenanceEntry[];
  degraded: DegradedSource[];
  contextStatus: Record<DegradedSource, ContextSourceStatus>;
  counts: { knowledgeConsidered: number; knowledgeUngroundable: number; memoriesConsidered: number };
  truncation: Partial<Record<'project' | 'knowledge' | 'opportunities' | 'actions' | 'memory', boolean>>;
}

function clip(s: string | null | undefined, n: number): string {
  const t = (s ?? '').replace(/\s+/g, ' ').trim();
  return t.length > n ? t.slice(0, n) : t;
}

async function optional<T>(allowed: boolean, source: DegradedSource, degraded: DegradedSource[], load: () => Promise<T[]>): Promise<T[]> {
  if (!allowed) return [];
  try {
    return await load();
  } catch {
    degraded.push(source);
    return [];
  }
}

export async function assembleContext(
  subject: EntitlementSubject,
  request: IveIntelligenceRequest,
  data: IveDataSource,
): Promise<IveIntelligenceContext> {
  // 2 — capabilities come from the server authority, never the client.
  const decisions = listModuleDecisions(subject);
  const authorized = new Set(decisions.filter((d) => d.allowed).map((d) => d.moduleId));

  // 3 — project ownership is verified before ANY project-scoped read.
  let project: ProjectRow | null = null;
  if (request.projectId) {
    let row: ProjectRow | null;
    try {
      row = await data.getOwnedProject(subject.id, request.projectId);
    } catch {
      throw new ContextUnavailableError('project lookup failed');
    }
    // Defense in depth: even if a data source returned a row, it must be
    // exactly the requested project AND owned by this subject.
    if (!row || row.id.toLowerCase() !== request.projectId || row.user_id !== subject.id) {
      throw new ProjectForbiddenError('project not owned');
    }
    project = row;
  }

  const degraded: DegradedSource[] = [];
  const pid = project?.id ?? null;
  // Codex Gate 1 IG1-02 — every returned row must belong to THIS subject
  // (rows without an owner are rejected) before any project check.
  const owned = <T extends { user_id?: string }>(rows: T[]) => rows.filter((r) => r.user_id === subject.id);
  const onlyThisProject = <T extends { project_id: string | null; user_id?: string }>(rows: T[]) =>
    owned(rows).filter((r) => pid !== null && r.project_id === pid);

  const [oppRows, actRows, knowRows, memRows] = await Promise.all([
    optional(pid !== null && authorized.has('opportunity-lab'), 'opportunities', degraded,
      () => data.listOpportunities(subject.id, pid!, CONTEXT_ITEM_LIMITS.opportunities)),
    optional(pid !== null && authorized.has('action-engine'), 'actions', degraded,
      () => data.listActions(subject.id, pid!, CONTEXT_ITEM_LIMITS.actions)),
    optional(authorized.has('knowledge-vault'), 'knowledge', degraded,
      () => data.listKnowledge(subject.id, pid, CONTEXT_ITEM_LIMITS.knowledgeDocuments)),
    optional(true, 'memory', degraded,
      () => data.listMemories(subject.id, pid, CONTEXT_ITEM_LIMITS.memories)),
  ]);

  // Second filter on every returned row: nothing from another project (or,
  // for knowledge/memory, from a project other than the verified one) can
  // enter the context even if a data source misbehaves.
  const opportunities = onlyThisProject(oppRows);
  const actions = onlyThisProject(actRows);
  const knowledgeRows = owned(knowRows).filter((r) => r.project_id === null || r.project_id === pid);
  const memoryRows = owned(memRows);

  const oppFit: Fitted<OpportunityRow> = fitToBudget(opportunities, (o) => clip(o.title, 200).length + 40, CONTEXT_BUDGET_CHARS.opportunities);
  const actFit: Fitted<ActionRow> = fitToBudget(actions, (a) => clip(a.title, 200).length + 40, CONTEXT_BUDGET_CHARS.actions);
  const k = selectKnowledge(knowledgeRows, `${request.message} ${project?.name ?? ''} ${project?.description ?? ''}`);
  const memSelected = selectMemories(memoryRows, pid).slice(0, CONTEXT_ITEM_LIMITS.memories);
  const memFit: Fitted<MemoryRow> = fitToBudget(memSelected, (m) => clip(m.content, 500).length + 20, CONTEXT_BUDGET_CHARS.memory);

  const status = (applicable: boolean, allowed: boolean, source: DegradedSource, n: number): ContextSourceStatus =>
    !applicable ? 'not_applicable' : !allowed ? 'not_authorized' : degraded.includes(source) ? 'unavailable' : n > 0 ? 'included' : 'empty';

  const provenance: ProvenanceEntry[] = [
    { sourceType: 'user_input', sourceId: null, projectId: pid, label: 'request', updatedAt: null, reason: 'user_request', trust: 'untrusted_user_content' },
  ];
  if (project) {
    provenance.push({ sourceType: 'project', sourceId: project.id, projectId: project.id, label: clip(project.name, 120), updatedAt: project.updated_at, reason: 'active_project_verified_owner', trust: 'server_verified_user_data' });
  }
  for (const o of oppFit.items) provenance.push({ sourceType: 'opportunity', sourceId: o.id, projectId: pid, label: clip(o.title, 120), updatedAt: null, reason: 'top_project_opportunity', trust: 'server_verified_user_data' });
  for (const a of actFit.items) provenance.push({ sourceType: 'action', sourceId: a.id, projectId: pid, label: clip(a.title, 120), updatedAt: null, reason: 'top_project_action', trust: 'server_verified_user_data' });
  for (const e of k.excerpts) provenance.push(e.provenance);
  for (const m of memFit.items) provenance.push({ sourceType: 'memory', sourceId: m.id, projectId: m.project_id, label: clip(m.title ?? m.memory_type, 120), updatedAt: m.updated_at ?? m.created_at, reason: m.project_id ? 'project_memory' : 'user_memory', trust: 'untrusted_user_content' });

  return {
    subject: { type: subject.type, plan: subject.plan, roles: [...subject.roles].sort() },
    surface: request.surface,
    locale: request.locale,
    authorizedModules: [...authorized].sort(),
    project,
    opportunities: oppFit.items,
    actions: actFit.items,
    knowledge: k.excerpts,
    memories: memFit.items,
    provenance,
    degraded,
    contextStatus: {
      opportunities: status(pid !== null, authorized.has('opportunity-lab'), 'opportunities', oppFit.items.length),
      actions: status(pid !== null, authorized.has('action-engine'), 'actions', actFit.items.length),
      knowledge: status(true, authorized.has('knowledge-vault'), 'knowledge', k.excerpts.length),
      memory: status(true, true, 'memory', memFit.items.length),
    },
    counts: { knowledgeConsidered: k.considered, knowledgeUngroundable: k.ungroundable, memoriesConsidered: memRows.length },
    truncation: {
      project: (project?.description ?? '').length > CONTEXT_BUDGET_CHARS.project,
      knowledge: k.truncated,
      opportunities: oppFit.truncated,
      actions: actFit.truncated,
      memory: memFit.truncated,
    },
  };
}

/** Production data source: the caller's own JWT (RLS) + explicit filters. */
export class SupabaseIveDataSource implements IveDataSource {
  // deno-lint-ignore no-explicit-any
  private readonly client: any;
  constructor(accessToken: string) {
    const url = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    if (!url || !anonKey) throw new ContextUnavailableError('context source misconfigured');
    this.client = createClient(url, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
    });
  }

  private async rows<T>(q: Promise<{ data: T[] | null; error: unknown }>): Promise<T[]> {
    const { data, error } = await q;
    if (error) throw new ContextUnavailableError('read failed');
    return data ?? [];
  }

  async getOwnedProject(userId: string, projectId: string): Promise<ProjectRow | null> {
    const { data, error } = await this.client.from('projects')
      .select('id, user_id, name, description, type, status, updated_at')
      .eq('id', projectId).eq('user_id', userId).maybeSingle();
    if (error) throw new ContextUnavailableError('project read failed');
    return data ?? null;
  }
  listOpportunities(userId: string, projectId: string, limit: number): Promise<OpportunityRow[]> {
    return this.rows(this.client.from('opportunity_lab')
      .select('id, user_id, project_id, title, final_score, status, opportunity_type')
      .eq('user_id', userId).eq('project_id', projectId)
      .order('final_score', { ascending: false }).limit(limit));
  }
  listActions(userId: string, projectId: string, limit: number): Promise<ActionRow[]> {
    return this.rows(this.client.from('action_queue')
      .select('id, user_id, project_id, title, status, priority, impact_score, effort_score')
      .eq('user_id', userId).eq('project_id', projectId)
      .order('priority', { ascending: false }).limit(limit));
  }
  listKnowledge(userId: string, projectId: string | null, limit: number): Promise<KnowledgeRow[]> {
    let q = this.client.from('knowledge_items')
      .select('id, user_id, title, content, status, project_id, updated_at')
      .eq('user_id', userId);
    // With a verified project: that project's documents + unassigned ones.
    // Without a project: unassigned documents only (never another project's).
    q = projectId ? q.or(`project_id.eq.${projectId},project_id.is.null`) : q.is('project_id', null);
    return this.rows(q.order('updated_at', { ascending: false }).limit(limit));
  }
  listMemories(userId: string, projectId: string | null, limit: number): Promise<MemoryRow[]> {
    // Codex Gate 1 IG1-06 — explicit columns (no select('*')), and only
    // ACTIVE, unexpired rows so stale memories cannot crowd out valid ones.
    // Requires migration 20260924000000 (deploy order: migration first;
    // if it is missing this read fails and memory degrades, never leaks).
    let q = this.client.from('business_memory')
      .select('id, user_id, project_id, memory_type, title, content, source, created_at, scope, origin, status, expires_at, updated_at')
      .eq('user_id', userId).eq('status', 'active');
    // Expiry is enforced by selectMemories() (a second `or` filter in the same
    // PostgREST query would not compose predictably with the scope filter).
    q = projectId ? q.or(`project_id.eq.${projectId},project_id.is.null`) : q.is('project_id', null);
    return this.rows(q.order('updated_at', { ascending: false }).limit(limit));
  }
}
