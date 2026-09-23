/**
 * Observability — IV-IMPACT-FOUNDATION-01.
 *
 * Allowlist-only structured events. Counts, ids, codes and versions only:
 * never document content, excerpts, claim text, organization names, personal
 * data, JWTs or secrets. Any field outside the allowlist, or any string
 * value that is not a plain identifier/code, makes the builder refuse the
 * event (fail closed — a dropped log line is better than a leaked one).
 */

const ID_OR_CODE = /^[A-Za-z0-9][A-Za-z0-9_.:+/-]{0,127}$/;

const ALLOWED: Readonly<Record<string, 'id' | 'count' | 'code'>> = {
  event: 'code',
  investigation_id: 'id',
  claim_id: 'id',
  source_provider: 'id',
  source_type: 'code',
  claims_count: 'count',
  evidence_count: 'count',
  conflicts_count: 'count',
  verification_status: 'code',
  review_state: 'code',
  latency_ms: 'count',
  error_code: 'code',
  policy_version: 'code',
  correlation_id: 'id',
};

export type ImpactLogEvent = Readonly<Record<string, string | number>>;

export function buildImpactEvent(fields: Record<string, unknown>): ImpactLogEvent | null {
  const out: Record<string, string | number> = {};
  for (const [k, v] of Object.entries(fields)) {
    const kind = ALLOWED[k];
    if (!kind) return null;
    if (kind === 'count') {
      if (typeof v !== 'number' || !Number.isFinite(v) || v < 0) return null;
      out[k] = Math.round(v);
    } else {
      if (typeof v !== 'string' || !ID_OR_CODE.test(v)) return null;
      out[k] = v;
    }
  }
  if (typeof out.event !== 'string') return null;
  return Object.freeze(out);
}
