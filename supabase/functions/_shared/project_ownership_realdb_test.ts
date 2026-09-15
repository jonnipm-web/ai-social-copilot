/**
 * IVE-COMMERCIAL-EXPERIENCE-14S — real-Postgres security proof for the
 * project-ownership RLS boundary added by migration
 * 20260919000000_project_ownership_boundary_closure.sql.
 *
 * Same rationale and technique as quota_realdb_test.ts (mission 13V):
 * this proves ACTUAL RLS POLICY enforcement, which cannot be
 * meaningfully tested any other way (a fake/mocked client would just
 * assert against itself). Runs the real CREATE TABLE statements
 * (verbatim, copied from supabase/migrations/
 * 20260907120000_baseline_production_pre_x4r.sql) and the real,
 * unmodified migration file against a genuine disposable Postgres
 * instance, connecting as a NON-superuser, NON-table-owning role
 * (table owners and superusers bypass RLS by default — testing as the
 * bootstrap `postgres` role would silently prove nothing).
 *
 * SKIPPED BY DEFAULT: gated on DATABASE_URL, same as quota_realdb_test.ts.
 *
 * HOW TO RUN LOCALLY (no Docker required — validated in missions 13V
 * and 14S using the same portable io.zonky.test.postgres binaries):
 *   1. Get a disposable real Postgres server (see quota_realdb_test.ts's
 *      own header for the no-admin-rights download method), then:
 *      initdb -D ./data --auth=trust -U postgres
 *      pg_ctl -D ./data -o "-p 55433 -c listen_addresses=127.0.0.1" start
 *   2. Apply, in order, against that instance (as the postgres role):
 *      a. CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid primary
 *         key); the real, documented Supabase auth.uid():
 *           CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid AS $$
 *             SELECT NULLIF(current_setting('request.jwt.claims', true)
 *               ::json->>'sub', '')::uuid
 *           $$ LANGUAGE sql STABLE;
 *      b. CREATE TABLE public.assets (id uuid primary key default
 *         gen_random_uuid()); -- minimal stub, only exists to satisfy
 *         opportunity_lab's asset_id FK; never populated by these tests.
 *      c. The verbatim CREATE TABLE statements for public.projects,
 *         public.market_analyses, public.opportunity_lab from
 *         supabase/migrations/20260907120000_baseline_production_pre_x4r.sql.
 *      d. ALTER TABLE ... ENABLE ROW LEVEL SECURITY + the three
 *         ORIGINAL baseline policies (also verbatim from that same
 *         migration file) -- so this suite can optionally prove the
 *         pre-fix behavior too if you want to see it fail first.
 *      e. supabase/migrations/20260919000000_project_ownership_boundary_closure.sql
 *         verbatim -- the real fix.
 *      f. CREATE ROLE app_user LOGIN; GRANT ALL ON public.projects,
 *         public.market_analyses, public.opportunity_lab, public.assets
 *         TO app_user; GRANT USAGE ON SCHEMA public TO app_user;
 *   3. DATABASE_URL=postgres://postgres@127.0.0.1:55433/postgres
 *      APP_USER_DATABASE_URL=postgres://app_user@127.0.0.1:55433/postgres
 *      deno test --allow-net --allow-env
 *      supabase/functions/_shared/project_ownership_realdb_test.ts
 *
 * Every INSERT/UPDATE test below connects via APP_USER_DATABASE_URL
 * (the non-superuser role) and sets request.jwt.claims per statement,
 * exactly mirroring how PostgREST authenticates a real request.
 */
import { Pool } from "https://deno.land/x/postgres@v0.19.3/mod.ts";
import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";

const ADMIN_URL = Deno.env.get("DATABASE_URL");
const APP_URL = Deno.env.get("APP_USER_DATABASE_URL");

function uuid(): string {
  return crypto.randomUUID();
}

// Codex Gate (mission 14S) P2 finding: an RLS test that silently connects
// as a superuser or as the tables' own owner would "pass" every rejection
// test for the WRONG reason — RLS is bypassed for those roles by default,
// so nothing would ever be rejected regardless of policy correctness. This
// asserts the app-role connection is genuinely subject to RLS BEFORE any
// other test runs, so a misconfigured APP_USER_DATABASE_URL fails loudly
// instead of producing false-positive passes.
async function assertAppRoleIsRlsSubject(pool: Pool): Promise<void> {
  const conn = await pool.connect();
  try {
    const r = await conn.queryObject<{ usesuper: boolean; ownsany: boolean }>(
      `SELECT
         (SELECT usesuper FROM pg_user WHERE usename = current_user) AS usesuper,
         EXISTS (
           SELECT 1 FROM pg_class c
           JOIN pg_roles r ON r.oid = c.relowner
           WHERE r.rolname = current_user
             AND c.relname IN ('projects','market_analyses','opportunity_lab')
         ) AS ownsany`,
    );
    const row = r.rows[0];
    if (row.usesuper) {
      throw new Error(
        `APP_USER_DATABASE_URL connects as a SUPERUSER (${await currentUser(conn)}) — RLS is bypassed entirely, every test below would false-positive-pass. Use a plain LOGIN role, not postgres.`,
      );
    }
    if (row.ownsany) {
      throw new Error(
        `APP_USER_DATABASE_URL connects as the OWNER of one of the target tables — table owners bypass RLS by default (unless FORCE ROW LEVEL SECURITY is set), every test below would false-positive-pass. Use a role that only has GRANTed access, not ownership.`,
      );
    }
  } finally {
    conn.release();
  }
}

async function currentUser(conn: Awaited<ReturnType<Pool["connect"]>>): Promise<string> {
  const r = await conn.queryObject<{ u: string }>(`SELECT current_user AS u`);
  return r.rows[0].u;
}

// Codex Gate P2 finding: assertRejects() alone doesn't confirm WHY a
// statement failed — a typo, a missing column, or a connection drop would
// also make it "reject" and the test would false-positive-pass. This
// requires the specific Postgres SQLSTATE for an RLS policy violation
// (42501 / insufficient_privilege — the exact code Postgres raises for
// "new row violates row-level security policy").
async function assertRlsRejects(fn: () => Promise<unknown>): Promise<void> {
  let threw = false;
  try {
    await fn();
  } catch (e) {
    threw = true;
    const code = (e as { fields?: { code?: string } }).fields?.code;
    if (code !== "42501") {
      throw new Error(
        `expected an RLS policy violation (SQLSTATE 42501), got ${code ?? "no SQLSTATE"} instead: ${(e as Error).message}`,
      );
    }
  }
  if (!threw) {
    throw new Error("expected the statement to be rejected by RLS, but it succeeded");
  }
}

if (!ADMIN_URL || !APP_URL) {
  console.log(
    "project_ownership_realdb_test.ts: DATABASE_URL / APP_USER_DATABASE_URL not set — skipping (see this file's own header for how to run it against a real disposable Postgres).",
  );
} else {
  const adminPool = new Pool(ADMIN_URL, 5, true);
  const appPool = new Pool(APP_URL, 30, true);

  Deno.test("PRECONDITION: app role is genuinely subject to RLS (not superuser, not table owner)", async () => {
    await assertAppRoleIsRlsSubject(appPool);
  });

  async function asAdmin<T>(fn: (query: (sql: string, params?: unknown[]) => Promise<any>) => Promise<T>): Promise<T> {
    const conn = await adminPool.connect();
    try {
      return await fn((sql, params) => conn.queryObject(sql, params));
    } finally {
      conn.release();
    }
  }

  async function asUser<T>(
    userId: string,
    fn: (query: (sql: string, params?: unknown[]) => Promise<any>) => Promise<T>,
  ): Promise<T> {
    const conn = await appPool.connect();
    try {
      await conn.queryArray("BEGIN");
      await conn.queryArray(
        "SELECT set_config('request.jwt.claims', $1, true)",
        [JSON.stringify({ sub: userId })],
      );
      const result = await fn((sql, params) => conn.queryObject(sql, params));
      await conn.queryArray("COMMIT");
      return result;
    } catch (e) {
      await conn.queryArray("ROLLBACK").catch(() => {});
      throw e;
    } finally {
      conn.release();
    }
  }

  async function makeUserWithProject(): Promise<{ userId: string; projectId: string }> {
    const userId = uuid();
    const projectId = uuid();
    await asAdmin((query) => query(`INSERT INTO auth.users (id) VALUES ($1)`, [userId]));
    await asAdmin((query) =>
      query(`INSERT INTO public.projects (id, user_id, name) VALUES ($1,$2,$3)`, [projectId, userId, "test project"])
    );
    return { userId, projectId };
  }

  Deno.test("OWN-01: INSERT market_analyses referencing own project — allowed", async () => {
    const { userId, projectId } = await makeUserWithProject();
    await asUser(userId, (query) =>
      query(`INSERT INTO public.market_analyses (user_id, input, project_id) VALUES ($1,$2,$3)`, [
        userId,
        "own",
        projectId,
      ])
    );
    const rows = await asAdmin((query) =>
      query(`SELECT project_id FROM public.market_analyses WHERE user_id=$1 AND input='own'`, [userId])
    );
    assertEquals(rows.rows[0].project_id, projectId);
  });

  Deno.test("FORGE-01: INSERT market_analyses referencing ANOTHER user's project — rejected", async () => {
    const { userId } = await makeUserWithProject();
    const other = await makeUserWithProject(); // other.projectId belongs to a different user
    await assertRlsRejects(() =>
      asUser(userId, (query) =>
        query(`INSERT INTO public.market_analyses (user_id, input, project_id) VALUES ($1,$2,$3)`, [
          userId,
          "forged",
          other.projectId,
        ])
      )
    );
    const rows = await asAdmin((query) =>
      query(`SELECT count(*)::int AS c FROM public.market_analyses WHERE user_id=$1 AND input='forged'`, [userId])
    );
    assertEquals((rows.rows[0] as any).c, 0, "the forged row must not exist — rejected, not silently stored");
  });

  Deno.test("FORGE-02: UPDATE market_analyses project_id from own to another user's project — rejected", async () => {
    const { userId, projectId } = await makeUserWithProject();
    const other = await makeUserWithProject();
    await asUser(userId, (query) =>
      query(`INSERT INTO public.market_analyses (user_id, input, project_id) VALUES ($1,$2,$3)`, [
        userId,
        "update-target",
        projectId,
      ])
    );
    await assertRlsRejects(() =>
      asUser(userId, (query) =>
        query(`UPDATE public.market_analyses SET project_id=$1 WHERE user_id=$2 AND input='update-target'`, [
          other.projectId,
          userId,
        ])
      )
    );
    const rows = await asAdmin((query) =>
      query(`SELECT project_id FROM public.market_analyses WHERE user_id=$1 AND input='update-target'`, [userId])
    );
    assertEquals(rows.rows[0].project_id, projectId, "project_id must remain the original owned project, not the forged one");
  });

  Deno.test("NULL-01: INSERT market_analyses with project_id NULL — allowed (existing semantics preserved)", async () => {
    const { userId } = await makeUserWithProject();
    await asUser(userId, (query) =>
      query(`INSERT INTO public.market_analyses (user_id, input, project_id) VALUES ($1,$2,NULL)`, [userId, "no-project"])
    );
    const rows = await asAdmin((query) =>
      query(`SELECT project_id FROM public.market_analyses WHERE user_id=$1 AND input='no-project'`, [userId])
    );
    assertEquals(rows.rows[0].project_id, null);
  });

  Deno.test("NULL-02: UPDATE market_analyses project_id from NULL to own project — allowed", async () => {
    const { userId, projectId } = await makeUserWithProject();
    await asUser(userId, (query) =>
      query(`INSERT INTO public.market_analyses (user_id, input, project_id) VALUES ($1,$2,NULL)`, [userId, "fill-in"])
    );
    await asUser(userId, (query) =>
      query(`UPDATE public.market_analyses SET project_id=$1 WHERE user_id=$2 AND input='fill-in'`, [projectId, userId])
    );
    const rows = await asAdmin((query) =>
      query(`SELECT project_id FROM public.market_analyses WHERE user_id=$1 AND input='fill-in'`, [userId])
    );
    assertEquals(rows.rows[0].project_id, projectId);
  });

  // Codex Gate P3 finding: the policy expression statically allows
  // project_id IS NULL unconditionally, but that was never exercised in
  // the reverse direction (owned project -> NULL) — clear it explicitly.
  Deno.test("NULL-03: UPDATE market_analyses project_id from own project to NULL — allowed", async () => {
    const { userId, projectId } = await makeUserWithProject();
    await asUser(userId, (query) =>
      query(`INSERT INTO public.market_analyses (user_id, input, project_id) VALUES ($1,$2,$3)`, [
        userId,
        "clear-out",
        projectId,
      ])
    );
    await asUser(userId, (query) =>
      query(`UPDATE public.market_analyses SET project_id=NULL WHERE user_id=$1 AND input='clear-out'`, [userId])
    );
    const rows = await asAdmin((query) =>
      query(`SELECT project_id FROM public.market_analyses WHERE user_id=$1 AND input='clear-out'`, [userId])
    );
    assertEquals(rows.rows[0].project_id, null);
  });

  Deno.test("CROSS-USER-01: USER_B cannot mutate USER_A's row at all", async () => {
    const a = await makeUserWithProject();
    const b = await makeUserWithProject();
    await asUser(a.userId, (query) =>
      query(`INSERT INTO public.market_analyses (user_id, input, project_id) VALUES ($1,$2,$3)`, [
        a.userId,
        "a-owned",
        a.projectId,
      ])
    );
    const result = await asUser(b.userId, (query) =>
      query(`UPDATE public.market_analyses SET input='tampered' WHERE user_id=$1 AND input='a-owned'`, [a.userId])
    );
    assertEquals(result.rowCount, 0, "USER_B must affect zero rows — RLS USING hides USER_A's row entirely");
  });

  Deno.test("LEGIT-01: plain analysis with no project association still works end-to-end", async () => {
    const { userId } = await makeUserWithProject();
    await asUser(userId, (query) =>
      query(`INSERT INTO public.market_analyses (user_id, input) VALUES ($1,$2)`, [userId, "legit-plain"])
    );
    const rows = await asAdmin((query) =>
      query(`SELECT project_id FROM public.market_analyses WHERE user_id=$1 AND input='legit-plain'`, [userId])
    );
    assertEquals(rows.rows.length, 1);
    assertEquals(rows.rows[0].project_id, null);
  });

  // ── opportunity_lab — same invariant, separate table ─────────────────

  Deno.test("OPP-OWN-01: INSERT opportunity_lab referencing own project — allowed", async () => {
    const { userId, projectId } = await makeUserWithProject();
    await asUser(userId, (query) =>
      query(`INSERT INTO public.opportunity_lab (user_id, project_id, title) VALUES ($1,$2,$3)`, [
        userId,
        projectId,
        "lab-own",
      ])
    );
    const rows = await asAdmin((query) =>
      query(`SELECT project_id FROM public.opportunity_lab WHERE user_id=$1 AND title='lab-own'`, [userId])
    );
    assertEquals(rows.rows[0].project_id, projectId);
  });

  Deno.test("OPP-FORGE-01: INSERT opportunity_lab referencing ANOTHER user's project — rejected", async () => {
    const { userId } = await makeUserWithProject();
    const other = await makeUserWithProject();
    await assertRlsRejects(() =>
      asUser(userId, (query) =>
        query(`INSERT INTO public.opportunity_lab (user_id, project_id, title) VALUES ($1,$2,$3)`, [
          userId,
          other.projectId,
          "lab-forged",
        ])
      )
    );
    const rows = await asAdmin((query) =>
      query(`SELECT count(*)::int AS c FROM public.opportunity_lab WHERE user_id=$1 AND title='lab-forged'`, [userId])
    );
    assertEquals((rows.rows[0] as any).c, 0);
  });

  Deno.test("OPP-FORGE-02: UPDATE opportunity_lab project_id to another user's project — rejected", async () => {
    const { userId, projectId } = await makeUserWithProject();
    const other = await makeUserWithProject();
    await asUser(userId, (query) =>
      query(`INSERT INTO public.opportunity_lab (user_id, project_id, title) VALUES ($1,$2,$3)`, [
        userId,
        projectId,
        "lab-update-target",
      ])
    );
    await assertRlsRejects(() =>
      asUser(userId, (query) =>
        query(`UPDATE public.opportunity_lab SET project_id=$1 WHERE user_id=$2 AND title='lab-update-target'`, [
          other.projectId,
          userId,
        ])
      )
    );
  });

  Deno.test("OPP-NULL-01: UPDATE opportunity_lab project_id from own project to NULL — allowed", async () => {
    const { userId, projectId } = await makeUserWithProject();
    await asUser(userId, (query) =>
      query(`INSERT INTO public.opportunity_lab (user_id, project_id, title) VALUES ($1,$2,$3)`, [
        userId,
        projectId,
        "lab-clear-out",
      ])
    );
    await asUser(userId, (query) =>
      query(`UPDATE public.opportunity_lab SET project_id=NULL WHERE user_id=$1 AND title='lab-clear-out'`, [userId])
    );
    const rows = await asAdmin((query) =>
      query(`SELECT project_id FROM public.opportunity_lab WHERE user_id=$1 AND title='lab-clear-out'`, [userId])
    );
    assertEquals(rows.rows[0].project_id, null);
  });

  Deno.test("PROJECTS-01: projects table's own RLS is unaffected by this migration", async () => {
    const { userId, projectId } = await makeUserWithProject();
    await asUser(userId, (query) =>
      query(`UPDATE public.projects SET name=$1 WHERE id=$2`, ["renamed", projectId])
    );
    const rows = await asAdmin((query) => query(`SELECT name FROM public.projects WHERE id=$1`, [projectId]));
    assertEquals(rows.rows[0].name, "renamed");
  });
}
