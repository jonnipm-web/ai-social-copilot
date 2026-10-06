/**
 * QUANT_PROVIDER_MODE — MACRO-05 FASE 3 explicit provider mode.
 *
 * Replaces the binary QUANT_REQUIRE_LIVE_DATA with a three-value enum:
 *
 *   synthetic   Always use SyntheticInProcessProvider, regardless of API key.
 *               Use in TEST, DEV, and CI environments that must never touch
 *               a real data vendor.
 *
 *   real        Require DATABENTO_API_KEY; fail closed if absent.
 *               Use in PRODUCTION and staging environments where synthetic
 *               data must NEVER be silently served as market data.
 *
 *   auto_lab    (DEFAULT) Use the real provider if DATABENTO_API_KEY is
 *               configured, otherwise fall back to SyntheticInProcessProvider.
 *               Suitable for LAB and developer environments where the key
 *               may or may not be present.
 *
 * Legacy alias: QUANT_REQUIRE_LIVE_DATA=true is treated as QUANT_PROVIDER_MODE=real.
 *
 * Environment precedence:
 *   1. QUANT_PROVIDER_MODE (explicit) — any recognised value takes effect.
 *   2. QUANT_REQUIRE_LIVE_DATA=true   — maps to 'real' (backward compat).
 *   3. Default → 'auto_lab'.
 *
 * Unrecognised non-empty QUANT_PROVIDER_MODE values throw an error (fail closed).
 */

export type ProviderMode = 'synthetic' | 'real' | 'auto_lab';

/**
 * Resolves the provider mode from environment variables.
 *
 * @param env Optional env accessor for testing (defaults to Deno.env.get).
 *            Pass `(k) => vars[k]` in tests to exercise all branches without
 *            a live Edge Function environment.
 */
export function resolveProviderMode(env?: (k: string) => string | undefined): ProviderMode {
  const getEnv = env ?? ((k: string) => Deno.env.get(k));

  // QUANT_PROVIDER_MODE takes precedence over the legacy flag.
  const explicit = (getEnv('QUANT_PROVIDER_MODE') ?? '').trim().toLowerCase();
  if (explicit === 'synthetic' || explicit === 'real' || explicit === 'auto_lab') {
    return explicit as ProviderMode;
  }

  // Non-empty, unrecognised QUANT_PROVIDER_MODE → fail closed BEFORE the legacy
  // alias is evaluated. A typo like 'prod' combined with QUANT_REQUIRE_LIVE_DATA=true
  // must still throw: an explicit but invalid mode is always a configuration error,
  // regardless of what the legacy flag says.
  if (explicit !== '') {
    throw new Error(
      `Invalid QUANT_PROVIDER_MODE value: "${explicit}". ` +
        `Must be 'synthetic', 'real', or 'auto_lab'.`,
    );
  }

  // Legacy alias: QUANT_REQUIRE_LIVE_DATA=true → 'real' (backward compat).
  if ((getEnv('QUANT_REQUIRE_LIVE_DATA') ?? '').trim().toLowerCase() === 'true') {
    return 'real';
  }

  return 'auto_lab';
}
