# Impact — RLS and Authorization Model (I1)

## 1. Layers (defense in depth)

1. **Edge Function** `impact-lab`: session JWT required
   (`resolveAuthenticatedUser`), server-side entitlement (`requireModuleAccess
   'impact'` → EXPERIMENTAL → admin only), strict schema, ownership check.
2. **Reads with the caller's JWT** (anon key + Authorization): PostgreSQL RLS
   decides visibility; a foreign investigation reads as "not found".
3. **Writes only via `service_role`** from the Edge Function, after 1–2, with
   the server-verified investigation id and the caller id as
   `created_by`/`updated_by`.
4. **Database invariants for every writer** (including `service_role`):
   composite FKs, subject binding, project-owner trigger, immutable
   ownership/provenance, append-only history, no direct DELETE, archive final,
   temporal/enum/privacy CHECKs, trigger-written audit chain.

## 2. Why clients cannot write at all

`anon` and `authenticated` hold **no INSERT/UPDATE/DELETE/TRUNCATE** privilege
and there is no write policy. Otherwise any authenticated user could call
PostgREST directly — bypassing entitlement (Impact is admin-only), the engine
(forging `SUPPORTED`), and the audit trail. This mirrors
`public.subject_roles` (writes only through `service_role`). `service_role`
use is confined to `impact-lab/supabase_store.ts` and only reached after the
checks above.

## 3. Policies

| Table | authenticated SELECT | anon |
|---|---|---|
| `impact_investigations` | `owner_id = auth.uid()` AND (no project OR project still owned by the caller) | none |
| every child table | `EXISTS (investigation WHERE id = row.investigation_id AND owner_id = auth.uid())` | none |

`FORCE ROW LEVEL SECURITY` on all 8 tables. `impact_audit_chain_ok()` is
SECURITY INVOKER (a caller can only verify chains it can read);
`impact_append_audit()` is not executable by `anon`/`authenticated`.

## 4. Matrix (tested on PostgreSQL 17 — `impact_lab_rls_test.sql`, 85 checks)

| Case | Result | Checks |
|---|---|---|
| Owner SELECT own investigation and children | ALLOW | A01, A10–A12 |
| Owner INSERT/UPDATE/DELETE via PostgREST | DENY (only the Edge Function writes) | A14, A17–A18, A22, A25–A26 |
| Other user SELECT (by id, unfiltered, each child table, audit, chain) | DENY | A02–A09, A13 |
| Other user INSERT child into B / link evidence in B / forge verification / forge audit | DENY | A15–A16, A18–A20 |
| Other user UPDATE / DELETE / move A→B | DENY | A21, A23–A24 |
| Anonymous read / write | DENY | N01–N03 |
| Cross-project (project handed to another user) | DENY for both | P01–P03 |
| Cross-investigation link (even as service_role) | DENY (composite FK) | S06–S07 |
| Claim about another organization | DENY | S08 |
| Link to another user's / nonexistent project | DENY | S01–S03 |
| Ownership / subject / provenance reassignment | DENY | S04–S05, S09–S11 |
| History rewrite / direct delete | DENY | S13–S19 |
| Status forgery / wrongdoing finding | DENY | S20–S21 |
| Minors / personal data | DENY | S22–S23 |
| Temporal abuse | DENY | S24–S28 |
| Account erasure | complete, isolated | E01–E02 |

The suite was mutation-tested: a permissive child policy, a client insert
grant, a mutable verification history, a removed owner/project guard and a
removed subject FK were each caught.

## 5. Entitlement

Unchanged Entitlement Core. `impact` stays EXPERIMENTAL: free, pro, premium and
beta testers get `403 MODULE_NOT_AVAILABLE`; admins pass. Forged body fields
(`plan`, `role`, `impact_access`) and headers (`x-role`, `x-plan`) are never
read (EF-02, GH tests).
