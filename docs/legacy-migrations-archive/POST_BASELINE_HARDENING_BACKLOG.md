# Post-baseline hardening backlog

Design/documentation only — **not implemented**. Neither item is
included in the canonical baseline (`20260907120000_baseline_
production_pre_x4r.sql`), which intentionally captures live production
as-is, not a desired future state. Both items were identified read-only
during IVE-X4R-MB1.5 and reconfirmed not to block the baseline
(`CONDITIONAL_PASS`).

## H1 — Least-privilege table grants

**Current state (verified live, MB1.5):** every one of the 35 tables in
`public` grants `SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES,
TRIGGER` uniformly to `anon`, `authenticated`, and `service_role`,
sourced from an explicit schema-wide `ALTER DEFAULT PRIVILEGES` (found
in `pg_default_acl`) rather than 35 independent grants — meaning any
new table created in `public` today inherits the same broad set
automatically.

**Verified not currently exploitable, but broader than necessary:**
`anon` and `authenticated` are both `NOLOGIN` roles (confirmed via
`pg_roles.rolcanlogin`) — no direct database connection is possible as
either. PostgREST, the only path that actually uses these roles,
exposes no `TRUNCATE` operation. No function anywhere in `public`
executes dynamic SQL (`prosrc ILIKE '%EXECUTE%'` search returned zero
results) that could indirectly invoke `TRUNCATE`/`REFERENCES` on their
behalf. `SELECT`/`INSERT`/`UPDATE`/`DELETE` are the only privileges
actually reachable via the application, and RLS correctly governs all
four everywhere.

**Proposed future migration (not written here):**
1. `ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE TRUNCATE, REFERENCES, TRIGGER FROM anon, authenticated;` (governs future tables).
2. Per-table `REVOKE TRUNCATE, REFERENCES, TRIGGER ON <table> FROM anon, authenticated;` for all 35 existing tables.
3. Leave `service_role`'s grants untouched — it is a trusted, `BYPASSRLS` role by design, not a client-facing surface.
4. Verify no regression: confirm the app (already audited, MB1.5 item 7) never relies on any of `TRUNCATE`/`REFERENCES`/`TRIGGER` for `anon`/`authenticated` (it doesn't — PostgREST cannot invoke them regardless).

## H2 — `asset_id` referential integrity — CORRECTED, NOT A BACKLOG ITEM

**MB1.5 reported no foreign-key constraint on `action_queue.asset_id` /
`opportunity_lab.asset_id`. This was re-checked with a precise,
literal `pg_get_constraintdef` query during MB2's baseline-capture pass
and found to be incorrect** — both foreign keys already exist live in
production:

```sql
-- action_queue_asset_id_fkey
FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE SET NULL
-- opportunity_lab_asset_id_fkey
FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE SET NULL
```

Both are captured as-is in the canonical baseline
(`20260907120000_baseline_production_pre_x4r.sql`) — no future
migration is needed for this item. Flagged here, rather than silently
dropped, as an explicit correction to MB1.5's finding, consistent with
this engagement's practice of recording corrections rather than quietly
editing prior reports.
