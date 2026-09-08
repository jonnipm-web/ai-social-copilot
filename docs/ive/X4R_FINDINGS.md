# IVE-X4R Findings — Security Remediation & Verification

Independent re-review of X4's two prepared fixes, before either is
applied/deployed to production. Nothing in this document was applied to
production. See commits `1bf8970` (migration 022 fix) and `615b2eb`
(safe_fetch fix) for the exact diffs.

## R1 — Migration 022 independent review: 3 real issues found

1. **INSERT-path bypass (the important one).** The X4 version of the
   trigger was `BEFORE UPDATE` only. RLS's `users_own_profile` policy
   (`FOR ALL`, no explicit `WITH CHECK`) uses its implicit fallback for
   INSERT too — meaning a user whose `profiles` row doesn't yet exist
   could `INSERT` one directly with `role='admin'`, bypassing an
   UPDATE-only trigger entirely. Fixed: trigger now covers
   `BEFORE INSERT OR UPDATE`, branching on `TG_OP`.
2. **Unnecessary `SECURITY DEFINER`.** The trigger function didn't need
   elevated privilege (`is_admin_user()` already self-elevates for the
   one check that needs it). Changed to `SECURITY INVOKER` — least
   privilege, and avoids adding another instance of exactly the
   anti-pattern Supabase's own advisor flags elsewhere in this schema.
3. **Factual correction, not a security issue:** X4's own report
   (`X4B_FINDINGS.md`) claimed `profiles.role` had no `CHECK` constraint.
   It does (`profiles_role_check`, since migration 001, allowing
   `free/pro/premium/beta_tester/admin`) — confirmed by grepping the
   local migration files. `'admin'` is a constraint-legal value, so this
   doesn't change the core vulnerability conclusion; it's corrected here
   because a security report with a wrong fact deserves an explicit
   correction trail, not a silent edit.

**Checklist coverage (mission section 4):** trigger timing (BEFORE, now
correct for both ops) — scope (FOR EACH ROW, unchanged, correct) — OLD
vs NEW (correctly used per TG_OP branch) — `auth.uid()` (unused directly
by the trigger; `is_admin_user()` uses it internally, unforgeable) —
`auth.role()` (used for the `service_role` exemption; confirmed this is
the standard Supabase mechanism for reading the JWT's role claim) —
service_role exemption (present, both branches) — admin behavior
(unaffected, `is_admin_user()`-gated actions still work) — NULL handling
(`IS DISTINCT FROM` is NULL-safe by design, used throughout) —
recursion (none: the trigger doesn't write to `profiles` itself,
`is_admin_user()` only reads) — search_path (now set on all 6 relevant
functions) — SECURITY DEFINER implications (removed where unneeded,
see #2) — privilege/grant implications (no GRANT changed) — partial
UPDATE bypass (`IS DISTINCT FROM` only fires the check when a privileged
column's value actually changes — updating only `full_name` is
unaffected) — RPC bypass (confirmed: `handle_new_user` is the *only*
function anywhere in `public` that writes to `profiles` — a fresh query
this session re-confirmed the complete function list) — upsert bypass
(`ON CONFLICT DO UPDATE` fires the UPDATE branch, `DO NOTHING` on an
existing row fires nothing; both covered) — INSERT bypass (see #1,
found and fixed) — impact on legitimate operations (`full_name`/`email`
unaffected; `handle_new_user()`'s own insert unaffected, verified by
construction, not merely asserted — see the migration's own comment).

## Privileged-field inventory (mission section 5)

Full, fresh column list re-queried this session (not reused from X4's
memory): `id, email, full_name, role, monthly_limit, is_active,
created_at, updated_at` — 8 columns, unchanged from X4.

- `role`, `monthly_limit`, `is_active` — privileged, now protected (see
  above).
- `id` — **already protected**, but not by this trigger: RLS's own
  `WITH CHECK` fallback requires `auth.uid() = NEW.id`, so a user
  attempting to change their own row's `id` to someone else's UUID is
  already rejected by the existing policy (confirmed by tracing the
  fallback semantics, not assumed) — no new gap, no new fix needed.
- `email`, `full_name` — cosmetic/display only; no RLS policy or
  function anywhere in this schema keys off either for authorization.
  Correctly left freely editable.
- `created_at`, `updated_at` — no known privilege/plan/quota dependency
  found anywhere in the schema or functions read this session.

**No additional privileged field found beyond the 3 X4 already
identified.** Scope of migration 022 was not expanded beyond
role/monthly_limit/is_active.

## Admin-promotion policy (mission section 6) — as implemented

| Actor | Can change role/monthly_limit/is_active? |
|---|---|
| Normal user, own row | NO (trigger blocks INSERT and UPDATE) |
| Normal user, own row, non-sensitive fields | YES (full_name/email unaffected) |
| Normal user, another user's row | NO (RLS already blocked this; trigger is a second, independent layer) |
| Admin (`is_admin_user()` true) | YES, own or any row |
| `service_role` | YES, own or any row (trusted administrative path) |

No client-side promotion endpoint exists or was created. No new RPC was
created. No RLS policy was loosened for testability.

## R2 — Production P0: NOT applied, preflight/postflight prepared only

See the final report, section 9/10, for the exact preflight/postflight
query set and the STOP FOR OWNER APPROVAL this document does not cross.

## R3 — SSRF independent re-review: 1 real bypass found

**Confirmed empirically** (Deno installed and used to actually call
`new URL(...)`, not assumed): a bracketed IPv6 literal wrapping a
blocked IPv4 address (`[::ffff:169.254.169.254]`, cloud metadata) gets
normalized by the URL parser to fully-compressed hex
(`[::ffff:a9fe:a9fe]`) with **no dots anywhere in the string**. The X4
version of `isBlockedIpv6` matched IPv4-mapped/NAT64 addresses via a
regex requiring a literal dotted-decimal suffix — it never matched this
form, so this exact request class would have been silently allowed
through the fix shipped in X4.

Root-caused and fixed properly: replaced the regex with a real IPv6
group-expansion function (`expandIpv6Groups`) that normalizes any
textual form to 8 canonical 16-bit groups, then compares numerically.
Every other blocklist check (loopback, link-local, unique-local,
multicast, documentation range) was also converted from string-prefix
matching to numeric group comparison for the same robustness reason,
even though the probe didn't find a live bug in those specific checks.

**Also verified, not assumed:** Deno's `URL()` parser already
canonicalizes alternative IPv4 representations (decimal integer `http://
2130706433/`, hex `0x7f000001`, octal `017700000001`, 2-part shorthand
`127.1`) to standard dotted-decimal *before* `safe_fetch` ever sees the
hostname — confirmed by printing `new URL(...).hostname` for each. The
existing dotted-decimal-only `ipv4ToInt` is therefore sufficient for
these cases without any change, and this is now pinned by 4 new
regression tests rather than left as an unverified assumption.

## R3 — Positive-regression check (mission section 14)

`ALLOW: a public URL resolving to a public IP succeeds` — re-run and
still passing. The X4 mission's own history (a bug that blocked every
legitimate hostname) is exactly why this test exists and is checked on
every run, not just once.

## Test results — actually executed this session, fresh

`deno check` / `deno lint`: clean on all 4 touched/reviewed files
(`safe_fetch.ts`, `safe_fetch_test.ts`, `analyze-website/index.ts`,
`extract-knowledge/index.ts`).

`deno test`: **31 passed, 0 failed** (20 from X4 + 2 new IPv4-literal
regression tests already covered conceptually in X4 but re-verified +
9 new: compressed-hex IPv6 bypass fix, alternative-IPv4-representation
pinning, redirect scheme-change, response-size cap).

## Residual SSRF risk (mission section 13's explicit instruction: do not
declare this resolved if it isn't)

The DNS-rebinding window between `Deno.resolveDns()` validation and the
actual `fetch()` call milliseconds later **remains open**. This session
did not find, and did not have the runtime access to test, a way to pin
the outbound TCP connection to the exact validated IP within the
Supabase Edge Runtime. **Not declared resolved.** Documented, accepted
as residual given every other threat-model item is now verified fixed
(not just claimed fixed) and no evidence exists that a better primitive
is available in this runtime.

## Test-environment decision (mission section 7)

No Docker, no Supabase CLI, no local PostgreSQL binary available in
this session's environment (all checked, all absent). Option 1 (local
reproducible stack) is **not available**. Option 2 (an existing,
already-isolated non-production environment) — none is known to this
session. Option 3 (a paid Supabase branch) requires cost confirmation
and explicit owner approval per the mission's own authorization rule —
**not created**. This means the authorization test matrix (mission
section 8) was **not dynamically executed** against any live database
this session; the SQL test script from X4
(`x4b_authorization_tests.sql`) remains unrun. The R1 findings above are
all static/adversarial-review findings, which is a different (and, for
the specific INSERT-bypass and SSRF-bypass findings, sufficient)
standard of evidence than a dynamic pass/fail run — but the mission's
own Migration Test Gate (section 9) contemplates an executed test table,
which this session cannot honestly claim to have produced.
