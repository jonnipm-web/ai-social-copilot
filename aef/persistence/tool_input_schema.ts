/**
 * Server-side tool input schemas (IV-IVE-AEF-RUNTIME-INTEGRATION-01).
 *
 * A tool may declare the exact shape of `request.parameters` it accepts.
 * AefGovernance checks it BEFORE anything is persisted, so a malformed,
 * oversized, nested or unexpected input never becomes an operation, a gate
 * or an approval. The schema is deliberately flat and closed:
 *   - only the declared fields are accepted (no additional properties);
 *   - values are scalars (string / integer / boolean) — objects and arrays
 *     are refused, so nothing can be smuggled in a nested structure;
 *   - strings are bounded and may be restricted to an enum or a pattern.
 * Anything the validator does not recognise fails closed.
 */

export type ToolFieldSpec =
  | { type: "string"; required: boolean; minLength?: number; maxLength: number; enum?: readonly string[]; pattern?: RegExp }
  | { type: "integer"; required: boolean; min: number; max: number }
  | { type: "boolean"; required: boolean };

export interface ToolInputSchema {
  readonly fields: Readonly<Record<string, ToolFieldSpec>>;
}

/** Hard ceiling for any declared string field, whatever the schema says. */
export const TOOL_STRING_MAX = 4_000;

function isPlainObject(v: unknown): v is Record<string, unknown> {
  if (typeof v !== "object" || v === null || Array.isArray(v)) return false;
  const proto = Object.getPrototypeOf(v);
  return proto === Object.prototype || proto === null;
}

/** Throws on an unusable schema (startup wiring error, never a request path). */
export function defineToolInputSchema(fields: Record<string, ToolFieldSpec>): ToolInputSchema {
  const names = Object.keys(fields);
  if (names.length === 0 || names.length > 32) throw new Error("tool input schema: 1..32 fields");
  for (const name of names) {
    if (!/^[a-z][a-z0-9_]{0,63}$/.test(name)) throw new Error(`tool input schema: invalid field name '${name}'`);
    const f = fields[name];
    if (f.type === "string") {
      if (!(f.maxLength >= 1 && f.maxLength <= TOOL_STRING_MAX)) throw new Error(`tool input schema: ${name}.maxLength`);
      if (f.minLength !== undefined && !(f.minLength >= 0 && f.minLength <= f.maxLength)) throw new Error(`tool input schema: ${name}.minLength`);
      if (f.enum !== undefined && (f.enum.length === 0 || f.enum.some((e) => typeof e !== "string"))) throw new Error(`tool input schema: ${name}.enum`);
    } else if (f.type === "integer") {
      if (!Number.isSafeInteger(f.min) || !Number.isSafeInteger(f.max) || f.min > f.max) throw new Error(`tool input schema: ${name} bounds`);
    } else if (f.type !== "boolean") {
      throw new Error(`tool input schema: ${name} has an unsupported type`);
    }
  }
  const frozen: Record<string, ToolFieldSpec> = Object.create(null);
  for (const name of names) frozen[name] = Object.freeze({ ...fields[name] }) as ToolFieldSpec;
  return Object.freeze({ fields: Object.freeze(frozen) });
}

/** True only when `params` matches `schema` exactly. */
export function validateToolInput(schema: ToolInputSchema, params: unknown): boolean {
  if (!isPlainObject(params)) return false;
  for (const key of Object.keys(params)) {
    if (!Object.prototype.hasOwnProperty.call(schema.fields, key)) return false; // extra / forbidden field
  }
  for (const [name, spec] of Object.entries(schema.fields)) {
    const has = Object.prototype.hasOwnProperty.call(params, name);
    if (!has) {
      if (spec.required) return false;
      continue;
    }
    const v = params[name];
    switch (spec.type) {
      case "string": {
        if (typeof v !== "string") return false;
        if (v.length > Math.min(spec.maxLength, TOOL_STRING_MAX)) return false;
        if (v.length < (spec.minLength ?? 0)) return false;
        if (spec.enum && !spec.enum.includes(v)) return false;
        if (spec.pattern && !spec.pattern.test(v)) return false;
        break;
      }
      case "integer":
        if (typeof v !== "number" || !Number.isSafeInteger(v) || v < spec.min || v > spec.max) return false;
        break;
      case "boolean":
        if (typeof v !== "boolean") return false;
        break;
      default:
        return false;
    }
  }
  return true;
}
