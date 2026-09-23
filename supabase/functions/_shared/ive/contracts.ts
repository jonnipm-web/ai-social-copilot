/**
 * IVE Intelligence Core — contracts (IVE-INTELLIGENCE-CORE-01).
 *
 * CLIENT-SUPPLIED (untrusted, validated here): message, surface, locale,
 * project_id (a request, verified against ownership by the assembler),
 * conversation (the visible transcript), requested_capability (a hint),
 * source_module (telemetry hint), idempotency_key, correlation_id.
 *
 * SERVER-VERIFIED (never read from the request): identity, roles, plan,
 * authorized modules (Entitlement Core), project ownership and data,
 * knowledge, memory, provenance, suggested actions, AEF routing.
 *
 * Any other field the client sends (plan, role, entitlements, context,
 * documents, memory, ...) is ignored — there is no code path that reads it.
 */

export type IveSurface = 'android' | 'web' | 'ios' | 'pwa' | 'browser_extension' | 'desktop' | 'api';

/** Surfaces this core serves today. The others are reserved in the
 * contract so future clients do not need a new wire format; they are
 * rejected until explicitly enabled. A surface changes UX, never authority. */
export const ACTIVE_SURFACES: ReadonlySet<IveSurface> = new Set(['android', 'web']);
const ALL_SURFACES: ReadonlySet<string> = new Set(['android', 'web', 'ios', 'pwa', 'browser_extension', 'desktop', 'api']);

export type IveLocale = 'pt-BR' | 'en';

export type ConversationRole = 'user' | 'assistant';
export interface ConversationTurn {
  role: ConversationRole;
  content: string;
}

export interface IveIntelligenceRequest {
  message: string;
  surface: IveSurface;
  locale: IveLocale;
  projectId: string | null;
  conversation: ConversationTurn[];
  requestedCapability: string | null;
  sourceModule: string | null;
  idempotencyKey: string | undefined;
  correlationId: string | null;
}

/** Public, stable failure codes. The client translates them (PT/EN);
 * logic never depends on human text. Entitlement codes keep the names of
 * _shared/entitlement.ts; QUOTA_* keep _shared/quota.ts's. */
export type IveErrorCode =
  | 'AUTH_REQUIRED'
  | 'INVALID_REQUEST'
  | 'SURFACE_NOT_SUPPORTED'
  | 'PROJECT_FORBIDDEN'
  | 'CONTEXT_UNAVAILABLE'
  | 'MODEL_UNAVAILABLE'
  | 'INTERNAL_ERROR';

/** Optional context that may be missing without failing the request.
 * Authorization-bearing context (identity, entitlement, project ownership)
 * is never "degraded": it fails closed. */
export type DegradedSource = 'knowledge' | 'memory' | 'opportunities' | 'actions';

/** Per optional source: why it is (not) in the answer's context, so the
 * client never presents a context-poor answer as fully grounded
 * (Codex Gate 1 design objection). */
export type ContextSourceStatus = 'included' | 'empty' | 'not_authorized' | 'not_applicable' | 'unavailable';

export const LIMITS = {
  messageChars: 4000,
  conversationTurns: 10,
  conversationTurnChars: 2000,
  shortStringChars: 200,
} as const;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const LOCALE_RE = /^[a-z]{2}(-[A-Za-z]{2})?$/;
const SHORT_ID_RE = /^[A-Za-z0-9._:-]{1,200}$/;

/** "pt", "pt-BR", "pt-PT" → pt-BR; "en", "en-US"… → en; any other
 * well-formed language → en (the product's second language); malformed →
 * null (request rejected). */
export function normalizeLocale(raw: unknown): IveLocale | null {
  if (raw === undefined || raw === null || raw === '') return 'pt-BR';
  if (typeof raw !== 'string' || !LOCALE_RE.test(raw)) return null;
  return raw.toLowerCase().startsWith('pt') ? 'pt-BR' : 'en';
}

export type ParseResult =
  | { ok: true; request: IveIntelligenceRequest }
  | { ok: false; code: IveErrorCode; field: string };

// deno-lint-ignore no-explicit-any
export function parseIntelligenceRequest(body: any): ParseResult {
  const bad = (field: string, code: IveErrorCode = 'INVALID_REQUEST'): ParseResult => ({ ok: false, code, field });
  if (typeof body !== 'object' || body === null || Array.isArray(body)) return bad('body');

  const message = body.message;
  if (typeof message !== 'string' || message.trim().length === 0 || message.length > LIMITS.messageChars) return bad('message');

  const surfaceRaw = body.surface;
  if (typeof surfaceRaw !== 'string' || !ALL_SURFACES.has(surfaceRaw)) return bad('surface');
  const surface = surfaceRaw as IveSurface;
  if (!ACTIVE_SURFACES.has(surface)) return bad('surface', 'SURFACE_NOT_SUPPORTED');

  const locale = normalizeLocale(body.locale);
  if (!locale) return bad('locale');

  let projectId: string | null = null;
  if (body.project_id !== undefined && body.project_id !== null) {
    if (typeof body.project_id !== 'string' || !UUID_RE.test(body.project_id)) return bad('project_id');
    projectId = body.project_id.toLowerCase();
  }

  const conversation: ConversationTurn[] = [];
  if (body.conversation !== undefined) {
    if (!Array.isArray(body.conversation) || body.conversation.length > LIMITS.conversationTurns) return bad('conversation');
    for (const t of body.conversation) {
      if (typeof t !== 'object' || t === null || (t.role !== 'user' && t.role !== 'assistant')) return bad('conversation');
      if (typeof t.content !== 'string' || t.content.length > LIMITS.conversationTurnChars) return bad('conversation');
      conversation.push({ role: t.role, content: t.content });
    }
  }

  const optionalId = (v: unknown, field: string): string | null | ParseResult => {
    if (v === undefined || v === null) return null;
    if (typeof v !== 'string' || !SHORT_ID_RE.test(v)) return bad(field);
    return v;
  };
  const requestedCapability = optionalId(body.requested_capability, 'requested_capability');
  if (typeof requestedCapability === 'object' && requestedCapability !== null) return requestedCapability;
  const sourceModule = optionalId(body.source_module, 'source_module');
  if (typeof sourceModule === 'object' && sourceModule !== null) return sourceModule;
  const correlationId = optionalId(body.correlation_id, 'correlation_id');
  if (typeof correlationId === 'object' && correlationId !== null) return correlationId;

  return {
    ok: true,
    request: {
      message,
      surface,
      locale,
      projectId,
      conversation,
      requestedCapability: requestedCapability as string | null,
      sourceModule: sourceModule as string | null,
      idempotencyKey: typeof body.idempotency_key === 'string' ? body.idempotency_key : undefined,
      correlationId: correlationId as string | null,
    },
  };
}

// ── Provenance ──────────────────────────────────────────────────────────

export type SourceType =
  | 'user_input'
  | 'conversation'
  | 'project'
  | 'opportunity'
  | 'action'
  | 'knowledge_document'
  | 'memory'
  | 'module_state'
  | 'system_policy';

/** Trust class: only system_policy is authoritative. Everything the user or
 * their documents supplied is data to analyse, never an instruction. */
export type TrustClass = 'system' | 'server_verified_user_data' | 'untrusted_user_content';

export interface ProvenanceEntry {
  sourceType: SourceType;
  sourceId: string | null;
  projectId: string | null;
  label: string;
  updatedAt: string | null;
  reason: string;
  trust: TrustClass;
}

// ── IVE ↔ AEF boundary ──────────────────────────────────────────────────

/** What IVE hands to AEF for anything consequential. Contract only in
 * this mission: nothing persists or executes it. The AEF (not IVE) will
 * authorize, gate and execute, and issue the receipt. */
export interface IveActionIntent {
  capabilityId: string | null;
  requestedAction: string;
  projectId: string | null;
  riskClass: 'READ_ONLY' | 'REVERSIBLE' | 'CONSEQUENTIAL';
  contextRef: string;
  parameters: Record<string, never>;
}

// ── Response ────────────────────────────────────────────────────────────

export type SuggestedActionKind = 'open_module' | 'upgrade' | 'aef_handoff';

export interface SuggestedAction {
  kind: SuggestedActionKind;
  /** Always a module id validated against the server policy. */
  capabilityId: string;
  available: boolean;
  requiredPlan?: string;
}

export interface IveIntelligenceResponse {
  status: 'ANSWERED' | 'ACTION_REQUIRES_AEF';
  answer: string | null;
  locale: IveLocale;
  capabilitiesUsed: string[];
  sources: { sourceType: SourceType; sourceId: string | null; label: string }[];
  suggestedActions: SuggestedAction[];
  requiresAef: boolean;
  actionIntent: IveActionIntent | null;
  memoryCandidates: { category: string; text: string }[];
  degraded: DegradedSource[];
  contextStatus: Record<DegradedSource, ContextSourceStatus> | null;
  correlationId: string;
}
