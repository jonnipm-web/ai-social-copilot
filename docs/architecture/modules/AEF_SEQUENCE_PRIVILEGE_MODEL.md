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

**In `20260925000000_aef_persistence.sql` itself** (Codex G1-06 / G2-04): the
migration that creates the sequence revokes it from PUBLIC and the API roles
before it finishes. Applied with `--single-transaction`, as the runbook requires,
the sequence is **never** visible in an exposed state, so there is no window
between migrations. Test: `20260925` applied alone leaves zero exposed AEF
sequences.

**`20260927000000_aef_sequence_privileges.sql`** re-asserts the contract. It is
idempotent and makes no production assumption beyond its precondition. It also
repairs a database where the earlier revision of `20260925` (b38ee2e, without
the revoke) had been applied. It runs in three steps:

- **precondition**: the `aef_audit_events` table and its serial sequence must
  exist. Otherwise it raises `AEF_PRECONDITION` (`AE010`) and applies nothing.
- **revoke**: for every AEF sequence, `REVOKE ALL … FROM PUBLIC, anon,
  authenticated, service_role`. An AEF sequence is any sequence in `public` named
  `aef_*` **or** owned (identity or serial, `pg_depend` deptype `a`/`i`) by an
  `aef_*` table. The same predicate is used by `20260925`, the postcondition, the
  rollback verifier, tests S10/S11 and the deploy preflight (Codex G1-01/02).
- **postcondition**: over the same set, `has_sequence_privilege` USAGE, SELECT
  and UPDATE for each of the three API roles, plus `aclexplode` for PUBLIC. On any
  failure it raises `AEF_POSTCONDITION` (`AE011`). These are *effective*
  privileges. A grant the owner cannot revoke (another grantor, or membership in a
  group role that holds the privilege) therefore **fails the migration** instead
  of passing silently. This is tested with a group role.

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
state is kept. The script fails if **any** AEF sequence is exposed: any API role
and any privilege (USAGE, SELECT, UPDATE), or PUBLIC (Codex G1-03). This is tested
for service_role SELECT, PUBLIC USAGE and a group role. Removing the
sequence is only done by the persistence rollback, which drops the table.

## Tests (disposable PostgreSQL 17, CI job `disposable-db`)

| Id | Where | Proves |
|---|---|---|
| S00 | both phases | the fixture reproduces production for **every** API role and every privilege (USAGE, SELECT, UPDATE in the sequence default ACL); without this, every other check could be a false green |
| S01a | `phase=before` | root cause: a fresh identity sequence in `public` inherits USAGE+UPDATE for all three API roles |
| S01/S02 | `phase=before`, pre-fix state | P03 reproduced: exposure; anon `setval(1)` takes effect (last_value = 1); the next append fails with `unique_violation` **on `aef_audit_events_pkey`**, which ties the collision to the rewound sequence (Codex G1-05) |
| S10 | `phase=after` | catalog contract: `has_sequence_privilege`, ACL beyond the owner (PUBLIC included), and `information_schema.usage_privileges` agree |
| S11 | `phase=after` | adversarial: nextval, setval, `SELECT last_value` and `ALTER SEQUENCE RESTART` as anon, authenticated and service_role are all denied; currval is denied; a direct INSERT into `aef_audit_events` is denied |
| S12 | `phase=after` | legitimate flows still work: denial, register → claim → complete → receipt verify → chain verify (the sequence advances), then purge and recover |
| S13 | `phase=after` | no AEF function references the pre-existing definer functions (P06/P07) |
| RB cycle | runner | UP → test → DOWN (no-op verify) → test → UP → test, after a full persistence DOWN/UP |
| REPAIR | runner (`AEF_SEQUENCE_REPAIR`) | pre-fix state (the grants inheritance produced under the b38ee2e revision) → `20260927` repairs it → an owner `setval` to `max(id)` restores appends after a rewind → `phase=after` passes |
| POSTCONDITION | runner (`AEF_SEQUENCE_POSTCONDITION`) | a non-prefixed sequence `OWNED BY` an AEF table is discovered and revoked; a group-role grant makes the migration fail with `AEF_POSTCONDITION`; the rollback verifier refuses service_role SELECT, PUBLIC USAGE and group-role exposure |
| no window | runner (`AEF_FAIL_FAST`) | after `20260925` alone, zero AEF sequences are exposed |

Mutants: removing either REVOKE (in 25 or in 27), removing the postcondition,
narrowing the predicate to names, weakening the rollback verifier, re-granting
UPDATE, and disabling the fixture are all killed. See the mission report.

**Reachability note.** PostgREST exposes only functions in the exposed schemas,
so `nextval`/`setval` (in `pg_catalog`) are not callable through `/rest/v1/rpc`.
The P03 exposure is therefore reachable from a direct SQL session running as an
API role, not from the public REST API. The defect is still closed on principle:
the contract must hold on every path.

## Known limits

- The stubs reproduce the `postgres`-grantor sequence default only.
  `supabase_admin` does not exist in the disposable DB. The postcondition and
  tests check **effective** privileges, so they catch a grant from either grantor.
  The deploy preflight also checks effective privileges.
- **Exposure window: closed.** `20260925` revokes the sequence inside the same
  migration (Codex G1-06). The preflight still FAILs on any exposed AEF sequence,
  and on permissive sequence defaults if `aef_persistence` would be applied
  without `aef_sequence_privileges` also remaining in the plan.
- **After an actual rewind**, revoking does not undo the damage. The owner must
  `setval` the sequence to `max(id)` (runbook step; tested as REPAIR).
- Future AEF tables with identity columns are covered **when `20260927`'s
  discovery runs**. Any new AEF migration that adds a sequence must repeat the
  REVOKE (or re-run the same block). This is recorded as a review rule in
  `AEF_SECURITY_MODEL.md`.
