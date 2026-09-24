// quant-analyze — IV-QUANT-DATA-PLANE-AND-API-02.
//
// First read-only Quant API (module 'quant-analytics', READ_ONLY, INTERNAL).
// Order: authenticate → entitlement → method/body limits → strict schema →
// project ownership (if project_id) → data plane (CSV → canonical series →
// deterministic engine) → structured QuantAnalysisResult.
//
// Deliberately NOT here: any URL/remote fetch of market data (no SSRF
// surface), any LLM call (numbers come only from the engine), any write,
// any broker/order path, any quota reservation (no paid dependency; the
// resource bounds below are the protection — see QUANT_API_CONTRACT.md §6).
//
// NOT DEPLOYED (Quant Lab). Not on .github/deploy-allowlist.tsv.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { AuthClient, AuthenticatedUser, AuthError, resolveAuthenticatedUser, unauthorizedResponse } from '../_shared/auth.ts';
import { EntitlementSubjectSource, requireModuleAccess } from '../_shared/entitlement.ts';
import type { QuotaClient } from '../_shared/quota.ts';
import { ANALYZE_CONTRACT_VERSION, MAX_ANALYZE_BODY_BYTES, parseAnalyzeRequest, runAnalyze } from '../_shared/quant/api_contract.ts';
import type { QuantErrorCode } from '../_shared/quant/errors.ts';
import { quantLogEvent } from '../_shared/quant/observability.ts';
import {
  bearerToken,
  enforceRateLimit,
  type ProjectAccessSource,
  quantCorsHeaders,
  quantError,
  type QuantHttpErrorCode,
  quantJson,
  type QuantRateLimiter,
  readJsonBody,
  SupabaseProjectAccess,
  SupabaseRateLimiter,
} from '../_shared/quant_server.ts';

export interface AnalyzeDeps {
  projectAccess?: ProjectAccessSource;
  /** Server clock (injected in tests). Used for provenance.retrievedAt and freshness only. */
  clock?: () => number;
  log?: (line: string) => void;
  rateLimiter?: QuantRateLimiter;
}

export async function handler(
  req: Request,
  authClient?: AuthClient,
  _quotaClient?: QuotaClient,
  subjectSource?: EntitlementSubjectSource,
  deps: AnalyzeDeps = {},
): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: quantCorsHeaders });

  let authUser: AuthenticatedUser;
  try {
    authUser = await resolveAuthenticatedUser(req, authClient);
  } catch (e) {
    if (e instanceof AuthError) return unauthorizedResponse(quantCorsHeaders);
    throw e;
  }

  // Server-side entitlement for the READ_ONLY analytics module. 'ive-quant'
  // (CONSEQUENTIAL) is never served by an Edge Function (MP-09).
  const access = await requireModuleAccess(req, authUser, 'quant-analytics', quantCorsHeaders, subjectSource);
  if (!access.allowed) return access.response;

  const started = performance.now();
  const clock = deps.clock ?? (() => Date.now());
  const log = deps.log ?? ((line: string) => console.log(line));
  const cid = access.correlationId;
  const done = (res: Response, extra: { errorCode?: QuantErrorCode | null; analysisId?: string; bars?: number; period?: [string, string]; calcs?: string[]; freshness?: 'FRESH' | 'DELAYED' | 'STALE' | 'UNKNOWN' }) => {
    log(JSON.stringify(quantLogEvent({
      analysisId: extra.analysisId ?? null,
      providerId: 'user-csv',
      instrumentCount: extra.analysisId ? 1 : 0,
      datasetSize: extra.bars ?? 0,
      periodStart: extra.period?.[0] ?? null,
      periodEnd: extra.period?.[1] ?? null,
      calculations: extra.calcs ?? [],
      freshness: extra.freshness ?? null,
      latencyMs: performance.now() - started,
      errorCode: extra.errorCode ?? null,
    })));
    return res;
  };
  const failWith = (code: QuantHttpErrorCode, details?: Record<string, string | number | boolean | null>) =>
    done(quantError(code, cid, details), { errorCode: (code in HTTP_ONLY ? null : code) as QuantErrorCode | null });

  if (req.method !== 'POST') return failWith('METHOD_NOT_ALLOWED');
  // Rate limit BEFORE reading the (up to 6 MiB) body — server identity only.
  const limited = await enforceRateLimit(deps.rateLimiter ?? new SupabaseRateLimiter(), authUser.id, 'quant-analyze', bearerToken(req) ?? '', cid);
  if (limited) return done(limited, { errorCode: null });
  const body = await readJsonBody(req, MAX_ANALYZE_BODY_BYTES);
  if (!body.ok) return failWith(body.code, body.code === 'DATASET_TOO_LARGE' ? { maxBytes: MAX_ANALYZE_BODY_BYTES } : undefined);

  const parsed = parseAnalyzeRequest(body.value);
  if (!parsed.ok) return failWith(parsed.error.code, parsed.error.details);

  if (parsed.value.projectId) {
    const token = bearerToken(req) ?? '';
    let owns: boolean;
    try {
      owns = await (deps.projectAccess ?? new SupabaseProjectAccess()).ownsProject(authUser.id, parsed.value.projectId, token);
    } catch {
      return failWith('OWNERSHIP_UNAVAILABLE');
    }
    if (!owns) return failWith('PROJECT_ACCESS_DENIED');
  }

  const result = await runAnalyze(parsed.value, clock());
  if (!result.ok) return failWith(result.error.code, result.error.details);
  const a = result.value;
  return done(
    quantJson({ contract_version: ANALYZE_CONTRACT_VERSION, correlation_id: cid, analysis: a }),
    { analysisId: a.analysisId, bars: a.period.bars, period: [a.period.start, a.period.end], calcs: a.metrics.map((m) => m.id), freshness: a.dataSnapshot.freshness.state },
  );
}

/** Transport-only codes are not QuantErrorCodes; they log as error_code null + HTTP status. */
const HTTP_ONLY: Record<string, true> = { METHOD_NOT_ALLOWED: true, UNSUPPORTED_MEDIA_TYPE: true, INVALID_JSON: true, OWNERSHIP_UNAVAILABLE: true, INTERNAL_ERROR: true, RATE_LIMITED: true, RATE_LIMIT_UNAVAILABLE: true };

if (Deno.env.get('DENO_TESTING') !== '1') {
  serve((req) => handler(req));
}
