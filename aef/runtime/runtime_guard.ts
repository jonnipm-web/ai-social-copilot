/**
 * LAB runtime kill switches (IV-IVE-AEF-RUNTIME-INTEGRATION-01).
 *
 * The IVE → AEF runtime of this mission may run ONLY:
 *   - when explicitly enabled for the LAB  (AEF_RUNTIME_MODE = "LAB");
 *   - with mock tools only                 (AEF_TOOLS = "MOCK_ONLY");
 *   - against a LOCAL Supabase stack        (SUPABASE_URL host is loopback /
 *     the local docker gateway) — never a hosted project, and never the
 *     production project, whatever else is configured.
 * Every value must be present and exact; anything missing, extra or
 * inconsistent fails closed. There is deliberately no override variable:
 * enabling a real environment requires a code change under its own gated
 * mission (AEF_PRODUCTION_READINESS.md).
 */

export interface RuntimeEnv {
  get(name: string): string | undefined;
}

/** Production project(s) of this repository — refused even if every other check passed. */
export const PRODUCTION_PROJECT_REFS: readonly string[] = Object.freeze(["nzngvbajrnruknpzzjbf"]);

/** Hosts of a local Supabase stack (`supabase start` / `supabase functions serve`). */
const LOCAL_HOSTS: readonly string[] = Object.freeze(["127.0.0.1", "localhost", "[::1]", "kong", "host.docker.internal"]);

export type RuntimeGuardResult =
  | { ok: true }
  | { ok: false; reason: "RUNTIME_NOT_ENABLED" | "TOOLS_NOT_MOCK_ONLY" | "NOT_LOCAL_STACK" | "PRODUCTION_LOCKED" | "OVERRIDE_REFUSED" };

export function checkLabRuntime(env: RuntimeEnv): RuntimeGuardResult {
  // Any attempt to configure an override is itself a refusal (no such switch exists).
  for (const name of ["AEF_RUNTIME_ALLOW_PRODUCTION", "AEF_RUNTIME_FORCE", "AEF_TOOLS_ALLOW_REAL"]) {
    if (env.get(name) !== undefined) return { ok: false, reason: "OVERRIDE_REFUSED" };
  }
  if (env.get("AEF_RUNTIME_MODE") !== "LAB") return { ok: false, reason: "RUNTIME_NOT_ENABLED" };
  if (env.get("AEF_TOOLS") !== "MOCK_ONLY") return { ok: false, reason: "TOOLS_NOT_MOCK_ONLY" };

  const raw = env.get("SUPABASE_URL") ?? "";
  if (PRODUCTION_PROJECT_REFS.some((ref) => raw.toLowerCase().includes(ref))) return { ok: false, reason: "PRODUCTION_LOCKED" };
  let host: string;
  try {
    const url = new URL(raw);
    if (url.protocol !== "http:" && url.protocol !== "https:") return { ok: false, reason: "NOT_LOCAL_STACK" };
    host = url.hostname.toLowerCase();
  } catch {
    return { ok: false, reason: "NOT_LOCAL_STACK" };
  }
  if (!LOCAL_HOSTS.includes(host)) return { ok: false, reason: "NOT_LOCAL_STACK" };
  return { ok: true };
}
