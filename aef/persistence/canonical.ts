/**
 * Canonical JSON + SHA-256 for payload binding (IV-AEF-PERSISTENCE-01).
 *
 * The payload is never stored: only its canonical hash and size. An approval
 * is bound to that hash, so the exact bytes that were approved are the only
 * ones that can execute. Canonical form:
 *   - object keys sorted (UTF-16 code unit order), no whitespace;
 *   - only JSON values: null, boolean, finite number, well-formed string,
 *     array, plain object — anything else (undefined, function, symbol,
 *     bigint, NaN/Infinity, Date, Map, class instance, lone surrogate) is
 *     rejected, never silently coerced;
 *   - -0 becomes 0 (JSON has no negative zero);
 *   - depth, node count and byte size are bounded.
 * Strings are hashed as given (no Unicode normalization): normalizing would
 * let two different payloads share one approval.
 */
import { MAX_PAYLOAD_BYTES, MAX_PAYLOAD_DEPTH, MAX_PAYLOAD_NODES } from "./limits.ts";

export type CanonicalResult =
  | { ok: true; json: string; bytes: number }
  | { ok: false; code: "PAYLOAD_INVALID" | "PAYLOAD_TOO_LARGE"; reason: string };

class CanonicalError extends Error {
  constructor(readonly code: "PAYLOAD_INVALID" | "PAYLOAD_TOO_LARGE", reason: string) {
    super(reason);
  }
}

function isPlainObject(v: object): boolean {
  const proto = Object.getPrototypeOf(v);
  return proto === Object.prototype || proto === null;
}

export function canonicalJson(value: unknown): CanonicalResult {
  let nodes = 0;
  const walk = (v: unknown, depth: number): string => {
    nodes += 1;
    if (nodes > MAX_PAYLOAD_NODES) throw new CanonicalError("PAYLOAD_TOO_LARGE", "too many nodes");
    if (depth > MAX_PAYLOAD_DEPTH) throw new CanonicalError("PAYLOAD_TOO_LARGE", "too deep");
    if (v === null) return "null";
    switch (typeof v) {
      case "boolean":
        return v ? "true" : "false";
      case "number":
        if (!Number.isFinite(v)) throw new CanonicalError("PAYLOAD_INVALID", "non-finite number");
        return JSON.stringify(Object.is(v, -0) ? 0 : v);
      case "string":
        if (!v.isWellFormed()) throw new CanonicalError("PAYLOAD_INVALID", "string is not well-formed UTF-16");
        return JSON.stringify(v);
      case "object": {
        if (Array.isArray(v)) {
          return `[${v.map((item) => walk(item, depth + 1)).join(",")}]`;
        }
        if (!isPlainObject(v)) throw new CanonicalError("PAYLOAD_INVALID", "only plain objects are allowed");
        const keys = Object.keys(v).sort();
        const parts: string[] = [];
        for (const k of keys) {
          if (!k.isWellFormed()) throw new CanonicalError("PAYLOAD_INVALID", "key is not well-formed UTF-16");
          parts.push(`${JSON.stringify(k)}:${walk((v as Record<string, unknown>)[k], depth + 1)}`);
        }
        return `{${parts.join(",")}}`;
      }
      default:
        throw new CanonicalError("PAYLOAD_INVALID", `unsupported value of type ${typeof v}`);
    }
  };
  try {
    const json = walk(value, 0);
    const bytes = new TextEncoder().encode(json).length;
    if (bytes > MAX_PAYLOAD_BYTES) return { ok: false, code: "PAYLOAD_TOO_LARGE", reason: `${bytes} bytes > ${MAX_PAYLOAD_BYTES}` };
    return { ok: true, json, bytes };
  } catch (err) {
    if (err instanceof CanonicalError) return { ok: false, code: err.code, reason: err.message };
    return { ok: false, code: "PAYLOAD_INVALID", reason: "payload could not be canonicalized" };
  }
}

export async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}
