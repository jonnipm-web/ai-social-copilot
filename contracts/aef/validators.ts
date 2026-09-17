/**
 * Pure, side-effect-free validators for the AEF contract foundation.
 *
 * Design rules followed throughout (see README.md "core trust principle"):
 *  - Every function returns a ValidationResult; none throw for invalid
 *    input. Invalid input is an expected, first-class outcome.
 *  - Every function fails CLOSED: any ambiguity, unknown field, missing
 *    required value, or unsupported version is a rejection, never a
 *    best-effort pass-through.
 *  - No function here can execute anything. There is deliberately no
 *    execute()/run()/dispatch() anywhere in this file or this directory
 *    -- see NO_DIRECT_EXECUTION.md.
 *  - Nothing here does I/O. Replay/nonce stores, delegation resolution,
 *    and "current time" are all injected by the caller, so this file
 *    stays testable and has no hidden dependency on a database, clock,
 *    or network.
 */
import {
  DelegationEnvelope,
  Domain,
  ExecutionRequest,
  HumanGateState,
  NonceStore,
  QuantExecutionTier,
  RequestIdStore,
  ValidationResult,
  AUTHORITATIVE_SOURCE_ALLOWLIST,
} from "./types.ts";
import { scanForProhibitedFields } from "./prohibited_fields.ts";

const UUID_V4_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ACTION_RE = /^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/;
const AUDIENCE_RE = /^aef\.[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$/;
const SOURCE_RE = /^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$/;
const SCOPE_ITEM_RE = /^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*(\.\*)?$/;
const KNOWN_DOMAINS: readonly Domain[] = ["core", "quant", "impact", "internal"];
const KNOWN_QUANT_TIERS: readonly QuantExecutionTier[] = [
  "research",
  "backtest",
  "paper",
  "controlled_live",
  "expanded_live",
];
const HIGH_RISK_QUANT_TIERS: readonly QuantExecutionTier[] = [
  "controlled_live",
  "expanded_live",
];
const SUPPORTED_CONTRACT_VERSION = "1.0";

function fail(...errors: string[]): ValidationResult {
  return { ok: false, errors };
}
const OK: ValidationResult = { ok: true };

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function isIsoDateTime(v: unknown): v is string {
  if (typeof v !== "string") return false;
  const d = new Date(v);
  return !Number.isNaN(d.getTime()) && v.includes("T");
}

// ---------------------------------------------------------------------
// Actor
// ---------------------------------------------------------------------
export function validateActor(value: unknown, path = "actor"): ValidationResult {
  if (!isPlainObject(value)) return fail(`${path}: must be an object`);
  const errors: string[] = [];
  const { type, id, auth_ref, ...rest } = value as Record<string, unknown>;
  if (Object.keys(rest).length > 0) {
    errors.push(`${path}: unknown field(s): ${Object.keys(rest).join(", ")}`);
  }
  if (type !== "user" && type !== "service" && type !== "system") {
    errors.push(`${path}.type: must be one of user|service|system`);
  }
  if (typeof id !== "string" || id.length < 1 || id.length > 200) {
    errors.push(`${path}.id: required non-empty string (max 200 chars)`);
  }
  if (typeof auth_ref !== "string" || auth_ref.length < 1) {
    // auth_ref presence is required for EVERY actor type, including
    // system -- there is no "trust me" actor. See README trust principle:
    // an id alone, from any actor type, proves nothing on its own.
    errors.push(
      `${path}.auth_ref: required -- an actor id alone is never sufficient (Section 6)`,
    );
  } else {
    if (type === "user" && !auth_ref.startsWith("usr:")) {
      errors.push(`${path}.auth_ref: type=user requires an 'usr:' prefixed auth_ref, not a bare/self-declared identity`);
    }
    if (type === "service" && !auth_ref.startsWith("svc:")) {
      errors.push(`${path}.auth_ref: type=service requires an 'svc:' prefixed auth_ref -- service identity must never reuse or resemble a user auth_ref`);
    }
    if (type === "system" && auth_ref !== "system:internal") {
      errors.push(`${path}.auth_ref: type=system requires the fixed literal 'system:internal'`);
    }
  }
  return errors.length === 0 ? OK : fail(...errors);
}

// ---------------------------------------------------------------------
// ExecutionRequest
// ---------------------------------------------------------------------
export interface ValidateExecutionRequestOptions {
  /** Injectable "now" for deterministic expiry tests. Defaults to real time. */
  now?: Date;
  /** Execution-replay defense (Section 9): reject a request_id seen before. Optional -- omit in pure-schema-only tests. */
  requestIdStore?: RequestIdStore;
}

export function validateExecutionRequest(
  value: unknown,
  opts: ValidateExecutionRequestOptions = {},
): ValidationResult {
  if (!isPlainObject(value)) return fail("request: must be an object");
  const now = opts.now ?? new Date();
  const errors: string[] = [];

  const ALLOWED_KEYS = new Set([
    "contract_version",
    "request_id",
    "correlation_id",
    "requested_at",
    "expires_at",
    "actor",
    "intent",
    "domain",
    "action",
    "resource",
    "parameters",
    "constraints",
    "quant_execution_tier",
    "context_ref",
    "idempotency_key",
    "delegation_ref",
    "human_gate_ref",
    "metadata",
  ]);
  for (const key of Object.keys(value)) {
    if (!ALLOWED_KEYS.has(key)) errors.push(`request: unknown field '${key}'`);
  }

  // Version -- checked first and unconditionally. Missing or anything
  // other than the exact supported string is a reject for a
  // consequential-capable contract (Section 18).
  const version = (value as Record<string, unknown>).contract_version;
  if (version === undefined) {
    errors.push("request.contract_version: required, missing");
  } else if (version !== SUPPORTED_CONTRACT_VERSION) {
    errors.push(
      `request.contract_version: unsupported version '${String(version)}' (only '${SUPPORTED_CONTRACT_VERSION}' is supported) -- fail-closed on any other value`,
    );
  }

  const requestId = (value as Record<string, unknown>).request_id;
  if (typeof requestId !== "string" || !UUID_V4_RE.test(requestId)) {
    errors.push("request.request_id: required, must be a UUID v4");
  }

  const correlationId = (value as Record<string, unknown>).correlation_id;
  if (correlationId !== undefined && (typeof correlationId !== "string" || !UUID_V4_RE.test(correlationId))) {
    errors.push("request.correlation_id: must be a UUID v4 when present");
  }

  const requestedAt = (value as Record<string, unknown>).requested_at;
  if (!isIsoDateTime(requestedAt)) {
    errors.push("request.requested_at: required, must be an ISO 8601 date-time");
  }

  const expiresAt = (value as Record<string, unknown>).expires_at;
  if (!isIsoDateTime(expiresAt)) {
    errors.push("request.expires_at: required, must be an ISO 8601 date-time -- there is no non-expiring ExecutionRequest in v1");
  } else if (new Date(expiresAt).getTime() <= now.getTime()) {
    errors.push(`request.expires_at: request has expired (expires_at=${expiresAt}, now=${now.toISOString()})`);
  }

  const actorResult = validateActor((value as Record<string, unknown>).actor, "request.actor");
  if (!actorResult.ok) errors.push(...actorResult.errors);

  const intent = (value as Record<string, unknown>).intent;
  if (typeof intent !== "string" || intent.length < 1 || intent.length > 500) {
    errors.push("request.intent: required non-empty string (max 500 chars)");
  }

  const domain = (value as Record<string, unknown>).domain;
  if (typeof domain !== "string" || !KNOWN_DOMAINS.includes(domain as Domain)) {
    errors.push(`request.domain: required, must be one of ${KNOWN_DOMAINS.join("|")}`);
  }

  const action = (value as Record<string, unknown>).action;
  if (typeof action !== "string" || !ACTION_RE.test(action) || action.length > 200) {
    errors.push("request.action: required, must be dot-namespaced lowercase (e.g. 'core.generate_strategy')");
  } else if (typeof domain === "string" && !action.startsWith(`${domain}.`)) {
    errors.push(`request.action: '${action}' is not namespaced under declared domain '${domain}'`);
  }

  const resource = (value as Record<string, unknown>).resource;
  if (resource !== undefined) {
    if (!isPlainObject(resource)) {
      errors.push("request.resource: must be an object when present");
    } else {
      const { type: rType, id: rId, ...rRest } = resource;
      if (Object.keys(rRest).length > 0) errors.push(`request.resource: unknown field(s): ${Object.keys(rRest).join(", ")}`);
      if (typeof rType !== "string" || rType.length < 1) errors.push("request.resource.type: required non-empty string");
      if (typeof rId !== "string" || rId.length < 1) errors.push("request.resource.id: required non-empty string");
    }
  }

  const constraints = (value as Record<string, unknown>).constraints;
  if (constraints !== undefined) {
    if (!isPlainObject(constraints)) {
      errors.push("request.constraints: must be an object when present");
    } else {
      const { max_cost_estimate, note, ...cRest } = constraints;
      if (Object.keys(cRest).length > 0) errors.push(`request.constraints: unknown field(s): ${Object.keys(cRest).join(", ")}`);
      if (max_cost_estimate !== undefined && (typeof max_cost_estimate !== "number" || max_cost_estimate < 0)) {
        errors.push("request.constraints.max_cost_estimate: must be a non-negative number when present");
      }
      if (note !== undefined && (typeof note !== "string" || note.length > 500)) {
        errors.push("request.constraints.note: must be a string up to 500 chars when present");
      }
    }
  }

  const tier = (value as Record<string, unknown>).quant_execution_tier;
  if (tier !== undefined && !KNOWN_QUANT_TIERS.includes(tier as QuantExecutionTier)) {
    errors.push(`request.quant_execution_tier: must be one of ${KNOWN_QUANT_TIERS.join("|")} when present`);
  }
  if (domain === "quant") {
    if (tier === undefined) {
      errors.push("request.quant_execution_tier: required when domain='quant' (Section 14)");
    } else {
      // The tier must not be a freely-asserted, disconnected field --
      // Codex adversarial review (Finding F-07) demonstrated that a
      // caller could request action='quant.controlled_live.submit_order'
      // (a real-money action, by its own namespace) while separately
      // declaring quant_execution_tier='research', suppressing the
      // human_gate_ref requirement below. Fixed by requiring the action's
      // OWN second namespace segment (when it names a known tier) to
      // match the declared tier exactly. This makes the field redundant
      // with the action name rather than a separate, independently
      // lie-able classifier -- the action string is validated by
      // ACTION_RE above and is the same string a future AEF would
      // actually route on, so the two can no longer disagree.
      if (typeof action === "string") {
        const segments = action.split(".");
        const actionTierSegment = segments[1];
        if (
          actionTierSegment &&
          KNOWN_QUANT_TIERS.includes(actionTierSegment as QuantExecutionTier) &&
          actionTierSegment !== tier
        ) {
          errors.push(
            `request.quant_execution_tier ('${tier}') does not match the tier named in request.action ('${action}', tier segment '${actionTierSegment}') -- a request must never claim a lower-risk tier than the action it names`,
          );
        }
      }
      if (HIGH_RISK_QUANT_TIERS.includes(tier as QuantExecutionTier)) {
        const humanGateRef = (value as Record<string, unknown>).human_gate_ref;
        if (typeof humanGateRef !== "string" || humanGateRef.length < 1) {
          errors.push(
            `request.human_gate_ref: required when quant_execution_tier='${tier}' -- no real-money action may be requested without a human_gate_ref, regardless of any other field (Section 14/16)`,
          );
        }
      }
    }
  } else if (tier !== undefined) {
    errors.push("request.quant_execution_tier: must not be present when domain is not 'quant'");
  }

  for (const [field, max] of [
    ["context_ref", 300],
    ["idempotency_key", 200],
    ["delegation_ref", 200],
    ["human_gate_ref", 200],
  ] as const) {
    const v = (value as Record<string, unknown>)[field];
    if (v !== undefined && (typeof v !== "string" || v.length < 1 || v.length > max)) {
      errors.push(`request.${field}: must be a non-empty string up to ${max} chars when present`);
    }
  }

  const metadata = (value as Record<string, unknown>).metadata;
  if (metadata !== undefined) {
    if (!isPlainObject(metadata)) {
      errors.push("request.metadata: must be an object when present");
    } else if (Object.keys(metadata).length > 20) {
      errors.push("request.metadata: at most 20 keys allowed");
    } else {
      for (const [k, v] of Object.entries(metadata)) {
        if (typeof v !== "string" || v.length > 500) {
          errors.push(`request.metadata.${k}: must be a string up to 500 chars`);
        }
      }
    }
  }

  const parameters = (value as Record<string, unknown>).parameters;
  if (parameters !== undefined) {
    if (!isPlainObject(parameters)) {
      errors.push("request.parameters: must be an object when present");
    } else if (Object.keys(parameters).length > 50) {
      errors.push("request.parameters: at most 50 top-level keys allowed");
    }
  }

  // Defense-in-depth: recursively scan the WHOLE request (not just
  // parameters) for prohibited authority-shaped field names, at any
  // nesting depth. This is the real security boundary for `parameters`/
  // `metadata`/`constraints`, which the schema intentionally cannot lock
  // down structurally (Section 5).
  const findings = scanForProhibitedFields(value);
  for (const f of findings) {
    errors.push(
      `request: prohibited authority field '${f.field}' found at ${f.path} -- IVE (or any request-originating component) must never supply this; a request must NEVER carry authority, only intent`,
    );
  }

  // Execution-replay defense (Section 9): a request_id seen before is
  // rejected outright, independent of every other check. This is
  // deliberately checked LAST and only reached when every other field is
  // already valid -- tryConsume() has a side effect (it atomically marks
  // request_id as consumed), so a request that would fail for an
  // unrelated reason must not burn its request_id first (Codex
  // adversarial review, Finding F-05: hasSeen()+record() as two separate
  // calls is a check-then-act race under concurrency; tryConsume() closes
  // that by making check-and-mark one atomic operation).
  if (errors.length === 0 && opts.requestIdStore && typeof requestId === "string" && UUID_V4_RE.test(requestId)) {
    if (!opts.requestIdStore.tryConsume(requestId)) {
      errors.push(`request.request_id: '${requestId}' has already been processed (execution-replay defense)`);
    }
  }

  return errors.length === 0 ? OK : fail(...errors);
}

// ---------------------------------------------------------------------
// DelegationEnvelope
// ---------------------------------------------------------------------
export interface ValidateDelegationOptions {
  now?: Date;
  nonceStore?: NonceStore;
}

export function validateDelegationEnvelope(
  value: unknown,
  opts: ValidateDelegationOptions = {},
): ValidationResult {
  if (!isPlainObject(value)) return fail("delegation: must be an object");
  const now = opts.now ?? new Date();
  const errors: string[] = [];

  const ALLOWED_KEYS = new Set([
    "contract_version",
    "delegation_id",
    "issuer",
    "subject",
    "audience",
    "issued_at",
    "expires_at",
    "nonce",
    "purpose",
    "scope",
    "request_binding",
    "auth_assertion_ref",
  ]);
  for (const key of Object.keys(value)) {
    if (!ALLOWED_KEYS.has(key)) errors.push(`delegation: unknown field '${key}'`);
  }

  const version = (value as Record<string, unknown>).contract_version;
  if (version === undefined) {
    errors.push("delegation.contract_version: required, missing");
  } else if (version !== SUPPORTED_CONTRACT_VERSION) {
    errors.push(`delegation.contract_version: unsupported version '${String(version)}'`);
  }

  const delegationId = (value as Record<string, unknown>).delegation_id;
  if (typeof delegationId !== "string" || !UUID_V4_RE.test(delegationId)) {
    errors.push("delegation.delegation_id: required, must be a UUID v4");
  }

  // issuer is Actor-shaped (not a bare string) so the issuer's own claimed
  // identity requires an auth_ref -- fixed after Codex adversarial review
  // (Finding F-02): a bare issuer string let any caller simply declare
  // itself e.g. "aef_policy_engine" with no binding to anything a future
  // AEF could independently resolve, a textbook confused-deputy gap.
  const issuerResult = validateActor((value as Record<string, unknown>).issuer, "delegation.issuer");
  if (!issuerResult.ok) errors.push(...issuerResult.errors);
  const issuer = (value as Record<string, unknown>).issuer as { type?: string } | undefined;
  if (isPlainObject(issuer) && issuer.type === "user") {
    errors.push("delegation.issuer: type='user' is not valid for an issuer -- only a service or system component may issue a delegation, never an end-user identity");
  }

  const subjectResult = validateActor((value as Record<string, unknown>).subject, "delegation.subject");
  if (!subjectResult.ok) errors.push(...subjectResult.errors);

  const audience = (value as Record<string, unknown>).audience;
  if (typeof audience !== "string" || !AUDIENCE_RE.test(audience) || audience.length > 150) {
    errors.push("delegation.audience: required, must match 'aef.<component>[.<subcomponent>...]'");
  }

  const issuedAt = (value as Record<string, unknown>).issued_at;
  if (!isIsoDateTime(issuedAt)) errors.push("delegation.issued_at: required ISO 8601 date-time");

  const expiresAt = (value as Record<string, unknown>).expires_at;
  if (!isIsoDateTime(expiresAt)) {
    errors.push("delegation.expires_at: required ISO 8601 date-time");
  } else if (new Date(expiresAt).getTime() <= now.getTime()) {
    errors.push(`delegation.expires_at: delegation has expired (expires_at=${expiresAt}, now=${now.toISOString()})`);
  }

  const nonce = (value as Record<string, unknown>).nonce;
  let nonceWellFormed = false;
  if (typeof nonce !== "string" || nonce.length < 16 || nonce.length > 200) {
    errors.push("delegation.nonce: required, at least 16 chars");
  } else {
    nonceWellFormed = true;
  }

  const purpose = (value as Record<string, unknown>).purpose;
  if (typeof purpose !== "string" || purpose.length < 1 || purpose.length > 300) {
    errors.push("delegation.purpose: required non-empty string");
  }

  const scope = (value as Record<string, unknown>).scope;
  if (!Array.isArray(scope) || scope.length < 1 || scope.length > 50) {
    errors.push("delegation.scope: required non-empty array (max 50 items)");
  } else {
    for (const item of scope) {
      if (item === "*") {
        errors.push("delegation.scope: a bare '*' is never allowed -- scope must be an explicit, enumerable allow-list (Section 7)");
      } else if (typeof item !== "string" || !SCOPE_ITEM_RE.test(item) || item.length > 200) {
        errors.push(`delegation.scope: invalid entry '${String(item)}'`);
      }
    }
  }

  const requestBinding = (value as Record<string, unknown>).request_binding;
  if (typeof requestBinding !== "string" || !UUID_V4_RE.test(requestBinding)) {
    errors.push("delegation.request_binding: required, must be a UUID v4 -- v1 delegations are single-request only");
  }

  const authAssertionRef = (value as Record<string, unknown>).auth_assertion_ref;
  if (typeof authAssertionRef !== "string" || authAssertionRef.length < 1) {
    errors.push("delegation.auth_assertion_ref: required");
  }

  // NOTE: `scope` is deliberately excluded from this scan. It is a
  // legitimate, fixed-shape, already-typed top-level field on
  // DelegationEnvelope (the explicit action allow-list, checked above) --
  // it is only ever prohibited on ExecutionRequest, where "scope" would
  // instead be an attempt to smuggle authority in free-form territory.
  // The unknown-field allowlist check above already provides full
  // structural protection for every other DelegationEnvelope field, so
  // this scan exists purely to catch prohibited names smuggled inside
  // `subject` (an Actor, otherwise fully validated by validateActor).
  const { scope: _scope, ...delegationWithoutScope } = value as Record<string, unknown>;
  const findings = scanForProhibitedFields(delegationWithoutScope);
  for (const f of findings) {
    errors.push(`delegation: prohibited authority field '${f.field}' found at ${f.path}`);
  }

  // Authentication-replay defense (Section 9), deferred to the end and
  // atomic for the same reason as ExecutionRequest's request_id check
  // above (Finding F-05): only consume the nonce once everything else is
  // already known-valid, and do so as a single atomic operation so two
  // concurrent validations of the same nonce cannot both succeed.
  if (errors.length === 0 && nonceWellFormed && opts.nonceStore) {
    if (!opts.nonceStore.tryConsume(nonce as string)) {
      errors.push("delegation.nonce: has already been used (authentication-replay defense)");
    }
  }

  return errors.length === 0 ? OK : fail(...errors);
}

/** Matches an action against a scope pattern, supporting a trailing '.*' one-level-or-deeper wildcard. */
function scopeMatches(action: string, pattern: string): boolean {
  if (pattern === action) return true;
  if (pattern.endsWith(".*")) {
    const prefix = pattern.slice(0, -2);
    return action === prefix || action.startsWith(`${prefix}.`);
  }
  return false;
}

/**
 * Cross-checks an ExecutionRequest against the DelegationEnvelope it
 * claims to be authorized by (Section 8: audience binding). Both objects
 * must ALREADY independently pass their own validate*() first -- this
 * function assumes well-formed input and focuses purely on the binding
 * rules between them.
 */
export function validateRequestAgainstDelegation(
  request: unknown,
  delegation: unknown,
): ValidationResult {
  // Defensive guards first (Codex adversarial review, Finding F-08): this
  // function documents that it "assumes well-formed input," but an
  // uncaught exception on malformed input is itself a fail-open risk -- a
  // careless caller could treat a thrown error as "the check didn't run"
  // and proceed anyway. Every prior-validation assumption below is now
  // re-checked structurally before being relied upon.
  if (!isPlainObject(request) || !isPlainObject(delegation)) {
    return fail("validateRequestAgainstDelegation: both request and delegation must be objects (call validateExecutionRequest/validateDelegationEnvelope first)");
  }
  const req = request as unknown as ExecutionRequest;
  const del = delegation as unknown as DelegationEnvelope;
  if (
    typeof req.request_id !== "string" ||
    typeof req.domain !== "string" ||
    !isPlainObject(req.actor) ||
    typeof req.actor.type !== "string" ||
    typeof req.actor.id !== "string"
  ) {
    return fail("validateRequestAgainstDelegation: request is missing required fields (request_id/domain/actor) -- it must independently pass validateExecutionRequest first");
  }
  if (
    typeof del.request_binding !== "string" ||
    typeof del.audience !== "string" ||
    !isPlainObject(del.subject) ||
    typeof del.subject.type !== "string" ||
    typeof del.subject.id !== "string" ||
    !Array.isArray(del.scope)
  ) {
    return fail("validateRequestAgainstDelegation: delegation is missing required fields (request_binding/audience/subject/scope) -- it must independently pass validateDelegationEnvelope first");
  }

  const errors: string[] = [];

  if (del.request_binding !== req.request_id) {
    errors.push(
      `delegation.request_binding ('${del.request_binding}') does not match request.request_id ('${req.request_id}') -- a delegation is single-request only and cannot be reused`,
    );
  }

  if (
    del.subject.type !== req.actor.type ||
    del.subject.id !== req.actor.id
  ) {
    errors.push(
      "delegation.subject does not match request.actor -- a delegation issued for one actor cannot be used to authorize a different actor's request",
    );
  }

  // Boundary-aware audience matching (Codex adversarial review, Finding
  // F-03): a naive `.startsWith(prefix)` check let "aef.coreextra" pass
  // for a request whose domain is "core", since "coreextra" begins with
  // "core" as a plain substring. An audience must equal the domain
  // prefix exactly, or be followed by a '.' boundary into a subcomponent
  // -- "aef.core" and "aef.core.action_engine" both match domain=core;
  // "aef.coreextra" never does.
  const expectedAudiencePrefix = `aef.${req.domain}`;
  const audienceMatchesDomain =
    del.audience === expectedAudiencePrefix ||
    del.audience.startsWith(`${expectedAudiencePrefix}.`);
  if (!audienceMatchesDomain) {
    errors.push(
      `delegation.audience ('${del.audience}') does not match request.domain ('${req.domain}') -- expected exactly '${expectedAudiencePrefix}' or a '.'-delimited subcomponent of it (Section 8: audience mismatch)`,
    );
  }

  if (
    req.quant_execution_tier &&
    HIGH_RISK_QUANT_TIERS.includes(req.quant_execution_tier)
  ) {
    const expectedTierAudience = `aef.quant.${req.quant_execution_tier}`;
    if (del.audience !== expectedTierAudience) {
      errors.push(
        `delegation.audience must be exactly '${expectedTierAudience}' for quant_execution_tier='${req.quant_execution_tier}' -- high-risk tiers require an audience scoped to that exact tier, not a broader 'aef.quant' delegation`,
      );
    }
  }

  if (typeof req.action === "string") {
    const matchesScope = del.scope.some((pattern) => typeof pattern === "string" && scopeMatches(req.action, pattern));
    if (!matchesScope) {
      errors.push(
        `request.action ('${req.action}') is not covered by delegation.scope (${JSON.stringify(del.scope)})`,
      );
    }
  }

  return errors.length === 0 ? OK : fail(...errors);
}

// ---------------------------------------------------------------------
// HumanGateRecord
// ---------------------------------------------------------------------
const VALID_TRANSITIONS: Record<HumanGateState, readonly HumanGateState[]> = {
  REQUESTED: ["REVIEW_REQUIRED"],
  REVIEW_REQUIRED: ["AUTHORIZED", "REJECTED", "EXPIRED"],
  AUTHORIZED: ["EXECUTED"],
  REJECTED: [],
  EXPIRED: [],
  EXECUTED: [],
};

export interface ValidateHumanGateOptions {
  now?: Date;
  /** If provided, also validates that transitioning FROM this state TO the record's current state is legal. */
  previousState?: HumanGateState;
}

export function validateHumanGateRecord(
  value: unknown,
  opts: ValidateHumanGateOptions = {},
): ValidationResult {
  if (!isPlainObject(value)) return fail("gate: must be an object");
  const now = opts.now ?? new Date();
  const errors: string[] = [];

  const ALLOWED_GATE_KEYS = new Set([
    "contract_version",
    "gate_id",
    "request_id",
    "action",
    "state",
    "approver",
    "decided_at",
    "expires_at",
    "audit_ref",
  ]);
  for (const key of Object.keys(value)) {
    if (!ALLOWED_GATE_KEYS.has(key)) errors.push(`gate: unknown field '${key}'`);
  }

  const validStatesForPrevCheck: HumanGateState[] = [
    "REQUESTED",
    "REVIEW_REQUIRED",
    "AUTHORIZED",
    "REJECTED",
    "EXPIRED",
    "EXECUTED",
  ];
  if (opts.previousState !== undefined && !validStatesForPrevCheck.includes(opts.previousState)) {
    // Defensive guard (Codex adversarial review, Finding F-08): a caller
    // passing a bogus previousState used to reach `.includes()` on
    // `undefined` inside VALID_TRANSITIONS and throw. An invalid
    // previousState is itself invalid input, not a crash.
    return fail(`validateHumanGateRecord: opts.previousState '${String(opts.previousState)}' is not a recognized HumanGateState`);
  }

  const version = (value as Record<string, unknown>).contract_version;
  if (version !== SUPPORTED_CONTRACT_VERSION) {
    errors.push(`gate.contract_version: unsupported or missing version '${String(version)}'`);
  }

  const gateId = (value as Record<string, unknown>).gate_id;
  if (typeof gateId !== "string" || !UUID_V4_RE.test(gateId)) {
    errors.push("gate.gate_id: required, must be a UUID v4");
  }

  const requestId = (value as Record<string, unknown>).request_id;
  if (typeof requestId !== "string" || !UUID_V4_RE.test(requestId)) {
    errors.push("gate.request_id: required, must be a UUID v4");
  }

  const action = (value as Record<string, unknown>).action;
  if (typeof action !== "string" || !ACTION_RE.test(action)) {
    errors.push("gate.action: required, dot-namespaced");
  }

  const state = (value as Record<string, unknown>).state as HumanGateState | undefined;
  const validStates: HumanGateState[] = [
    "REQUESTED",
    "REVIEW_REQUIRED",
    "AUTHORIZED",
    "REJECTED",
    "EXPIRED",
    "EXECUTED",
  ];
  if (!state || !validStates.includes(state)) {
    errors.push(`gate.state: required, must be one of ${validStates.join("|")}`);
  } else if (opts.previousState) {
    const allowed = VALID_TRANSITIONS[opts.previousState];
    if (!allowed.includes(state)) {
      errors.push(
        `gate.state: illegal transition from '${opts.previousState}' to '${state}' (allowed: ${allowed.join(", ") || "none, terminal state"})`,
      );
    }
  }

  const approver = (value as Record<string, unknown>).approver;
  const decidedAt = (value as Record<string, unknown>).decided_at;
  const auditRef = (value as Record<string, unknown>).audit_ref;

  if (state === "AUTHORIZED" || state === "REJECTED") {
    if (approver === undefined) {
      errors.push(`gate.approver: required when state='${state}' -- a request never self-attests approval (Section 12)`);
    } else {
      const approverResult = validateActor(approver, "gate.approver");
      if (!approverResult.ok) errors.push(...approverResult.errors);
      else if (isPlainObject(approver) && approver.type === "system") {
        errors.push("gate.approver: type='system' is never valid for a human gate -- a human approval by 'the system' is a contradiction");
      }
    }
    if (typeof decidedAt !== "string" || !isIsoDateTime(decidedAt)) {
      errors.push(`gate.decided_at: required ISO 8601 date-time when state='${state}'`);
    }
    if (typeof auditRef !== "string" || auditRef.length < 1) {
      errors.push(`gate.audit_ref: required when state='${state}' -- an approval without durable, independent audit evidence is not trustworthy`);
    }
  }

  const expiresAt = (value as Record<string, unknown>).expires_at;
  if (!isIsoDateTime(expiresAt)) {
    errors.push("gate.expires_at: required ISO 8601 date-time");
  } else if (
    (state === "REQUESTED" || state === "REVIEW_REQUIRED") &&
    new Date(expiresAt).getTime() <= now.getTime()
  ) {
    errors.push(
      `gate: state is '${state}' but expires_at (${expiresAt}) has passed -- must be resolved to EXPIRED, never silently treated as approved or denied`,
    );
  } else if (
    state === "AUTHORIZED" &&
    new Date(expiresAt).getTime() <= now.getTime()
  ) {
    // Codex adversarial review, Finding F-04: the original check only
    // covered REQUESTED/REVIEW_REQUIRED, so a syntactically complete
    // AUTHORIZED record whose expiry had already passed was accepted --
    // a future AEF resolving human_gate_ref could treat stale approval
    // as currently valid. An approval past its own expiry is not
    // currently authorized; it must be re-derived (typically to EXPIRED)
    // by whatever system owns this record's lifecycle, never trusted
    // as-is by a caller that merely has an old copy of it.
    errors.push(
      `gate: state is 'AUTHORIZED' but expires_at (${expiresAt}) has already passed -- a stale approval must not be treated as currently valid`,
    );
  }

  const findings = scanForProhibitedFields(value);
  for (const f of findings) {
    errors.push(`gate: prohibited authority field '${f.field}' found at ${f.path}`);
  }

  return errors.length === 0 ? OK : fail(...errors);
}

// ---------------------------------------------------------------------
// PolicySignal
// ---------------------------------------------------------------------
export function validatePolicySignal(value: unknown): ValidationResult {
  if (!isPlainObject(value)) return fail("signal: must be an object");
  const errors: string[] = [];

  // Codex adversarial review, Finding F-06: the JSON Schema declares
  // additionalProperties=false, but this reference validator did not
  // enforce the same, so a field like "is_authoritative": true could
  // pass through this validator silently even though the canonical
  // schema would reject it -- schema/validator parity matters because a
  // real implementation is more likely to use one of these, not both.
  const ALLOWED_SIGNAL_KEYS = new Set([
    "contract_version",
    "kind",
    "source",
    "signal",
    "computed_at",
    "request_ref",
  ]);
  for (const key of Object.keys(value)) {
    if (!ALLOWED_SIGNAL_KEYS.has(key)) errors.push(`signal: unknown field '${key}'`);
  }

  const version = (value as Record<string, unknown>).contract_version;
  if (version !== SUPPORTED_CONTRACT_VERSION) {
    errors.push(`signal.contract_version: unsupported or missing version '${String(version)}'`);
  }

  const kind = (value as Record<string, unknown>).kind;
  if (kind !== "ADVISORY" && kind !== "AUTHORITATIVE") {
    errors.push("signal.kind: required, must be ADVISORY or AUTHORITATIVE");
  }

  const source = (value as Record<string, unknown>).source;
  if (typeof source !== "string" || !SOURCE_RE.test(source) || source.length > 150) {
    errors.push("signal.source: required, dot-namespaced lowercase identifier");
  } else if (kind === "AUTHORITATIVE" && !AUTHORITATIVE_SOURCE_ALLOWLIST.includes(source)) {
    errors.push(
      `signal.source: '${source}' is not on AUTHORITATIVE_SOURCE_ALLOWLIST and may only issue ADVISORY signals (Section 13) -- IVE and every other non-listed source can never be authoritative`,
    );
  }

  const signal = (value as Record<string, unknown>).signal;
  if (typeof signal !== "string" || signal.length < 1 || signal.length > 500) {
    errors.push("signal.signal: required non-empty string");
  }

  const computedAt = (value as Record<string, unknown>).computed_at;
  if (!isIsoDateTime(computedAt)) errors.push("signal.computed_at: required ISO 8601 date-time");

  const requestRef = (value as Record<string, unknown>).request_ref;
  if (requestRef !== undefined && (typeof requestRef !== "string" || requestRef.length < 1)) {
    errors.push("signal.request_ref: must be a non-empty string when present");
  }

  return errors.length === 0 ? OK : fail(...errors);
}

// ---------------------------------------------------------------------
// ExecutionReceipt
// ---------------------------------------------------------------------
export function validateExecutionReceipt(value: unknown): ValidationResult {
  if (!isPlainObject(value)) return fail("receipt: must be an object");
  const errors: string[] = [];

  // Codex adversarial review, Finding F-06: same schema/validator parity
  // gap as PolicySignal above.
  const ALLOWED_RECEIPT_KEYS = new Set([
    "contract_version",
    "receipt_id",
    "request_id",
    "actor",
    "action",
    "policy_decision",
    "human_gate_ref",
    "tool",
    "started_at",
    "completed_at",
    "outcome",
    "verification_ref",
    "error",
    "rollback_ref",
    "deployment_identity",
  ]);
  for (const key of Object.keys(value)) {
    if (!ALLOWED_RECEIPT_KEYS.has(key)) errors.push(`receipt: unknown field '${key}'`);
  }

  const version = (value as Record<string, unknown>).contract_version;
  if (version !== SUPPORTED_CONTRACT_VERSION) {
    errors.push(`receipt.contract_version: unsupported or missing version '${String(version)}'`);
  }

  const receiptId = (value as Record<string, unknown>).receipt_id;
  if (typeof receiptId !== "string" || !UUID_V4_RE.test(receiptId)) {
    errors.push("receipt.receipt_id: required, must be a UUID v4");
  }

  const requestId = (value as Record<string, unknown>).request_id;
  if (typeof requestId !== "string" || !UUID_V4_RE.test(requestId)) {
    errors.push("receipt.request_id: required, must be a UUID v4");
  }

  const actorResult = validateActor((value as Record<string, unknown>).actor, "receipt.actor");
  if (!actorResult.ok) errors.push(...actorResult.errors);

  const action = (value as Record<string, unknown>).action;
  if (typeof action !== "string" || !ACTION_RE.test(action)) {
    errors.push("receipt.action: required, dot-namespaced");
  }

  const policyDecision = (value as Record<string, unknown>).policy_decision;
  if (policyDecision !== "ALLOWED" && policyDecision !== "DENIED") {
    errors.push("receipt.policy_decision: required, must be ALLOWED or DENIED");
  }

  const startedAt = (value as Record<string, unknown>).started_at;
  if (!isIsoDateTime(startedAt)) errors.push("receipt.started_at: required ISO 8601 date-time");

  const outcome = (value as Record<string, unknown>).outcome;
  const validOutcomes = ["SUCCESS", "FAILURE", "PARTIAL", "ROLLED_BACK", "NOT_EXECUTED"];
  if (typeof outcome !== "string" || !validOutcomes.includes(outcome)) {
    errors.push(`receipt.outcome: required, must be one of ${validOutcomes.join("|")}`);
  }
  if (policyDecision === "DENIED" && outcome !== "NOT_EXECUTED") {
    errors.push("receipt.outcome: must be NOT_EXECUTED when policy_decision=DENIED -- a denied request must never show any other outcome");
  }

  const findings = scanForProhibitedFields(value);
  for (const f of findings) {
    errors.push(`receipt: prohibited authority field '${f.field}' found at ${f.path}`);
  }

  return errors.length === 0 ? OK : fail(...errors);
}
