# AEF Sequence Privilege Model (P03)

Mission `IV-AEF-PRE-RUNTIME-CLOSURE-01`. **Status: P03 CLOSED in the Lab**
(migration `20260927000000_aef_sequence_privileges.sql`). Not applied in production.

## The finding

The read-only production preflight (`AEF_PRODUCTION_PRIVILEGE_PREFLIGHT.md`, P03)
showed that production's default privileges in `public` grant **sequences `rwU`**
(USAGE, SELECT, UPDATE) to `anon`, `authenticated` and `service_role`. The grantors
are `postgres` and `supabase_admin`.

The identity column `aef_audit_events.id` owns the sequence
`public.aef_audit_events_id_seq`. That sequence is created by `20260925000000` and
inherits these defaults when it is created. No AEF migration revoked them.

| | Value |
|---|---|
| EXPECTED | no API role holds any privilege on any AEF sequence; only the owner (`postgres`) and the SECURITY DEFINER RPCs running as the owner can use it |
| OBSERVED_PRODUCTION | default ACL for sequences in `public`: `rwU` for anon, authenticated and service_role (grantors `postgres` and `supabase_admin`); no AEF objects exist yet |
| OBSERVED_TEST (before this mission) | the stubs reproduced the table and function defaults but **not** the sequence defaults, so `aef_audit_events_id_seq` had ACL `(default)` = owner only, and every test passed on a DB *stricter than production* (a false green) |
| OBSERVED_TEST (reproduced) | once the production default is added to the stubs: ACL `{postgres=rwU/postgres,anon=rwU/postgres,authenticated=rwU/postgres,service_role=rwU/postgres}`; `anon` can call `setval(…, 1)`, and the next legitimate audit append fails with `unique_violation` (test `AEF_SEQUENCE: EXPOSED_BEFORE_FIX`) |
| DELTA | the missing sequence default in the stubs, plus the missing REVOKE in the AEF chain |
| ROOT_CAUSE | test fixture divergence (the stubs lacked production's `ALTER DEFAULT PRIVILEGES … ON SEQUENCES`), which hid an absent REVOKE on an identity sequence |
| IMPACT | no data exposure: sequences hold no user data, and a caller learns only a counter value. **Integrity/availability**: `setval` backwards makes audit appends collide. Because AEF fails closed, every governed operation is then refused (a denial of service on the governance plane). `nextval` by an API role burns ids, which is harmless but reveals approximate audit volume. |

## Contract (enforced)

1. `anon`, `authenticated`, `service_role` and `PUBLIC` hold **no** privilege
   (USAGE, SELECT or UPDATE) on any sequence in `public` that is named `aef_%` or
   owned by an `aef_%` table.
2. The only legitimate consumer is the `INSERT … RETURNING` inside the SECURITY
   DEFINER RPCs, which run as the owner.
3. `service_role` does not need the sequence. Its contract stays SELECT on the
   tables plus EXECUTE on the 13 RPCs. It is not broadened.

## Implementation

`20260927000000_aef_sequence_privileges.sql` is idempotent and makes no production
assumption beyond its precondition. It runs in three steps:

- **precondition**: the `aef_audit_events` table and its serial sequence must
  exist. Otherwise it raises `AEF_PRECONDITION` (`AE010`) and applies nothing.
- **revoke**: for every sequence it discovers (by name, or through `pg_depend`
  ownership by an `aef_` table), `REVOKE ALL … FROM PUBLIC, anon, authenticated,
  service_role`. Discovery by ownership also covers identity sequences that do not
  carry the `aef_` prefix.
- **postcondition**: `has_sequence_privilege` for the three API roles, and
  `aclexplode` for PUBLIC. On any failure it raises `AEF_POSTCONDITION` (`AE011`),
  so the migration cannot report success while a grant survives.

A separate migration was chosen over editing `20260925` so that the fix remains
correct even for a database where `20260925` had been applied before. Default
privileges apply per *creating* role: an object created by `postgres` receives
only the `postgres`-grantor defaults, with grantor = owner. The owner's REVOKE
removes those grants. The `supabase_admin` defaults apply only to objects that
`supabase_admin` creates. If a grant ever came from another grantor, the owner's
REVOKE would not remove it, and the postcondition, which checks the *effective*
privilege and not the grantor, fails the migration.

**Rollback** (`supabase/rollbacks/20260927000000_aef_sequence_privileges.down.sql`):
a verified **no-op**. Re-granting would restore a known weakness, so the security
state is kept. The script fails if the sequence is found exposed. Removing the
sequence is only done by the persistence rollback, which drops the table.

## Tests (disposable PostgreSQL 17, CI job `disposable-db`)

| Id | Where | Proves |
|---|---|---|
| S00 | both phases | the fixture reproduces production (anon has UPDATE on new sequences by default); without this, every other check could be a false green |
| S01/S02 | `phase=before`, DB without `20260927` | P03 reproduced: exposure plus a real `unique_violation` after an anon `setval` |
| S10 | `phase=after` | catalog contract: `has_sequence_privilege`, ACL beyond the owner (PUBLIC included), and `information_schema.usage_privileges` agree |
| S11 | `phase=after` | adversarial: nextval, setval, `SELECT last_value` and `ALTER SEQUENCE RESTART` as anon, authenticated and service_role are all denied; currval is denied; a direct INSERT into `aef_audit_events` is denied |
| S12 | `phase=after` | legitimate flows still work: denial, register → claim → complete → receipt verify → chain verify (the sequence advances), then purge and recover |
| S13 | `phase=after` | no AEF function references the pre-existing definer functions (P06/P07) |
| RB cycle | runner | UP → test → DOWN (no-op verify) → test → UP → test, after a full persistence DOWN/UP |

Mutants: removing the REVOKE, granting UPDATE again, and disabling the fixture are
all killed. See the mission report.

## Known limits

- The stubs reproduce the `postgres`-grantor sequence default only.
  `supabase_admin` does not exist in the disposable DB. The postcondition and
  tests check **effective** privileges, so they catch a grant from either grantor.
  The deploy preflight also checks effective privileges.
- **Exposure window**: between applying `20260925` and applying `20260927`, the
  sequence is exposed. The deployment runbook
  (`AEF_PRODUCTION_DEPLOYMENT_PRECONDITIONS.md`) requires applying the whole chain
  in one change window and re-running the preflight. The preflight FAILs when the
  sequence is exposed, and also FAILs on permissive sequence defaults if
  `aef_persistence` would be applied without `aef_sequence_privileges` after it.
- Future AEF tables with identity columns are covered **when `20260927`'s
  discovery runs**. Any new AEF migration that adds a sequence must repeat the
  REVOKE (or re-run the same block). This is recorded as a review rule in
  `AEF_SECURITY_MODEL.md`.
