/**
 * IVE-COMMERCIAL-QUOTA-HARDENING-13V — real-Postgres integration suite.
 *
 * quota_test.ts (the sibling file) proves the Edge Function layer's own
 * forwarding/fail-closed logic against a FAKE QuotaClient — it explicitly
 * disclaims proving the underlying SQL's concurrency/race guarantees,
 * because this repository's CI has no Postgres service to test against.
 * This file is that missing piece: it runs the ACTUAL
 * try_reserve_ai_quota/refund_ai_quota functions (applied from this
 * repo's real migration files, unmodified) against a REAL, disposable
 * Postgres database, including genuine concurrent connections for the
 * race-safety proof no unit test (fake or real) can substitute for.
 *
 * SKIPPED BY DEFAULT: every test here is gated on the DATABASE_URL env
 * var. Locally / in CI without a Postgres service available, `deno test`
 * on this file exits 0 having run zero tests — it does not silently
 * report false confidence, and does not fail a pipeline that has no DB.
 *
 * HOW TO RUN LOCALLY (no Docker required):
 *   1. Get a disposable real Postgres server. One way that needs no
 *      installer/admin rights (validated in mission 13V): download the
 *      portable Windows/Linux/macOS binaries this project's own CI can
 *      also use, e.g.
 *      https://repo1.maven.org/maven2/io/zonky/test/postgres/embedded-postgres-binaries-<platform>/<version>/
 *      (a .jar that is really a zip containing a .txz of real `postgres`/
 *      `initdb`/`pg_ctl` binaries — no install, no service, no admin).
 *      `initdb -D ./data --auth=trust` then
 *      `pg_ctl -D ./data -o "-p 55433 -c listen_addresses=127.0.0.1" start`.
 *   2. Create the minimum prerequisite schema (NOT the full 12-migration
 *      production history — just what these two migrations' own
 *      functions read): a `auth` schema with `auth.users(id uuid pk)`
 *      and Supabase's real, documented `auth.uid()` (reads the `sub`
 *      claim off `request.jwt.claims`, exactly what PostgREST sets per
 *      request from a caller's verified JWT); and a minimal
 *      `public.profiles(id uuid pk, role text, monthly_limit int)`.
 *   3. Apply supabase/migrations/20260910190000_commercial_ai_quota.sql
 *      then supabase/migrations/20260918000000_ai_quota_idempotency.sql
 *      verbatim — these are the real files, never rewritten for testing.
 *   4. `DATABASE_URL=postgres://postgres@127.0.0.1:55433/postgres deno test --allow-net --allow-env supabase/functions/_shared/quota_realdb_test.ts`
 *
 * CI: this can run in GitHub Actions the same way edge-function-tests.yml
 * already spins up a service container — add a `postgres:16` (or newer)
 * service, run steps 2-3 above via `psql`/a setup script, then run this
 * file with DATABASE_URL pointed at the service. Not wired into CI yet
 * (the setup script itself, step 2, is deliberately hand-rolled per
 * mission Section 04 rather than committed as auto-run SQL, since it
 * intentionally diverges from the real `auth` schema Supabase's platform
 * actually provisions and should not be mistaken for it or drift
 * un-reviewed).
 */
import { Pool } from "https://deno.land/x/postgres@v0.19.3/mod.ts";
import { assertEquals, assertNotEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";

const DATABASE_URL = Deno.env.get("DATABASE_URL");

function uuid(): string {
  return crypto.randomUUID();
}

if (!DATABASE_URL) {
  console.log(
    "quota_realdb_test.ts: DATABASE_URL not set — skipping (see this file's own header for how to run it against a real disposable Postgres).",
  );
} else {
  const pool = new Pool(DATABASE_URL, 30, true);

  async function asUser<T>(
    userId: string | null,
    fn: (query: (sql: string, params?: unknown[]) => Promise<any>) => Promise<T>,
  ): Promise<T> {
    const conn = await pool.connect();
    try {
      await conn.queryArray("BEGIN");
      await conn.queryArray(
        "SELECT set_config('request.jwt.claims', $1, true)",
        [userId ? JSON.stringify({ sub: userId }) : ""],
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

  const reserve = (userId: string, key: string | null, op: string | null) =>
    asUser(userId, async (query) => {
      const r = await query(`SELECT public.try_reserve_ai_quota($1::uuid, $2::text) AS result`, [key, op]);
      return r.rows[0].result;
    });

  const refund = (userId: string, reservationId: string | null) =>
    asUser(userId, async (query) => {
      const r = await query(`SELECT public.refund_ai_quota($1::uuid) AS result`, [reservationId]);
      return r.rows[0].result;
    });

  async function usage(userId: string): Promise<number> {
    const conn = await pool.connect();
    try {
      const r = await conn.queryObject(
        `SELECT request_count FROM public.ai_usage WHERE user_id=$1 AND period_start=date_trunc('month', now())::date`,
        [userId],
      );
      return r.rows.length ? (r.rows[0] as any).request_count : 0;
    } finally {
      conn.release();
    }
  }

  async function activeReservationCount(userId: string, key: string, op: string): Promise<number> {
    const conn = await pool.connect();
    try {
      const r = await conn.queryObject(
        `SELECT count(*)::int AS c FROM public.ai_quota_reservations WHERE user_id=$1 AND idempotency_key=$2 AND operation_type=$3 AND status='reserved'`,
        [userId, key, op],
      );
      return (r.rows[0] as any).c;
    } finally {
      conn.release();
    }
  }

  async function makeUser(role = "free", limit = 5): Promise<string> {
    const id = uuid();
    const conn = await pool.connect();
    try {
      await conn.queryArray(`INSERT INTO auth.users (id, email) VALUES ($1,$2)`, [id, `${id}@test.local`]);
      await conn.queryArray(`INSERT INTO public.profiles (id, role, monthly_limit) VALUES ($1,$2,$3)`, [id, role, limit]);
    } finally {
      conn.release();
    }
    return id;
  }

  Deno.test("REALDB-01: single reservation reserves exactly one unit", async () => {
    const user = await makeUser();
    const r = await reserve(user, uuid(), "op");
    assertEquals(r.allowed, true);
    assertEquals(await usage(user), 1);
  });

  Deno.test("REALDB-02: sequential replay of the same key is idempotent (usage stays +1)", async () => {
    const user = await makeUser();
    const key = uuid();
    const first = await reserve(user, key, "op");
    for (let i = 0; i < 5; i++) {
      const r = await reserve(user, key, "op");
      assertEquals(r.idempotent_replay, true);
      assertEquals(r.reservation_id, first.reservation_id);
    }
    assertEquals(await usage(user), 1);
  });

  // Codex adversarial review (mission 13V) — the original version of this
  // test only asserted aggregate usage==1 and allowed==30, which a defect
  // producing multiple active ledger rows while still only incrementing
  // usage once could have passed. Strengthened to assert, per round:
  // exactly ONE active ledger row for the key, exactly ONE non-replay
  // response among the 30, and every response (replay or not) naming the
  // SAME reservation_id — not just "usage looks right" but "the ledger
  // itself has no duplicate active row." Also repeated across 3 fresh
  // keys/rounds (mission Section 08: "repeat multiple rounds with fresh
  // keys") — the original committed version ran only a single round.
  Deno.test("REALDB-03: 30-way concurrent same-key race produces exactly one reservation (mandatory gate, 3 rounds)", async () => {
    const user = await makeUser();
    for (let round = 0; round < 3; round++) {
      const key = uuid();
      const results = await Promise.all(Array.from({ length: 30 }, () => reserve(user, key, "op")));
      const allowedCount = results.filter((r) => r.allowed).length;
      const nonReplayCount = results.filter((r) => r.allowed && !r.idempotent_replay).length;
      const reservationIds = new Set(results.filter((r) => r.allowed).map((r) => r.reservation_id));
      assertEquals(allowedCount, 30, `round ${round}: every concurrent request must still report allowed=true`);
      assertEquals(nonReplayCount, 1, `round ${round}: exactly one of the 30 requests may be the actual winner (non-replay)`);
      assertEquals(reservationIds.size, 1, `round ${round}: all 30 responses must name the SAME reservation_id, no duplicates`);
      assertEquals(
        await activeReservationCount(user, key, "op"),
        1,
        `round ${round}: exactly one ACTIVE ledger row must exist for this key, regardless of how many concurrent requests raced for it`,
      );
    }
    assertEquals(await usage(user), 3, "3 rounds x 1 real unit each = usage must be exactly 3, never more");
  });

  Deno.test("REALDB-04: different keys are independent operations", async () => {
    const user = await makeUser();
    await reserve(user, uuid(), "op");
    await reserve(user, uuid(), "op");
    assertEquals(await usage(user), 2);
  });

  Deno.test("REALDB-05: cross-user same key never interferes", async () => {
    const userA = await makeUser();
    const userB = await makeUser();
    const sharedKey = uuid();
    const rA = await reserve(userA, sharedKey, "op");
    const rB = await reserve(userB, sharedKey, "op");
    assertNotEquals(rA.reservation_id, rB.reservation_id);
    assertEquals(await usage(userA), 1);
    assertEquals(await usage(userB), 1);
  });

  Deno.test("REALDB-06: refund is idempotent under sequential AND concurrent replay", async () => {
    const user = await makeUser();
    const r = await reserve(user, uuid(), "op");
    const seq = [await refund(user, r.reservation_id), await refund(user, r.reservation_id)];
    assertEquals(seq, [true, false]);
    const key2 = uuid();
    const r2 = await reserve(user, key2, "op2");
    const concurrent = await Promise.all(Array.from({ length: 10 }, () => refund(user, r2.reservation_id)));
    assertEquals(concurrent.filter((x) => x === true).length, 1, "exactly one concurrent refund call may succeed");
    assertEquals(await usage(user), 0, "usage must never go negative");
  });

  Deno.test("REALDB-07: user B cannot refund user A's reservation", async () => {
    const userA = await makeUser();
    const userB = await makeUser();
    const r = await reserve(userA, uuid(), "op");
    const attack = await refund(userB, r.reservation_id);
    assertEquals(attack, false);
    assertEquals(await usage(userA), 1, "the attack must have zero effect on the real owner's usage");
  });

  Deno.test("REALDB-08: quota exhaustion denies without exceeding the limit, and frees a slot on refund", async () => {
    const user = await makeUser("free", 2);
    const r1 = await reserve(user, uuid(), "op");
    await reserve(user, uuid(), "op");
    const denied = await reserve(user, uuid(), "op");
    assertEquals(denied.allowed, false);
    assertEquals(denied.reason, "quota_exceeded");
    assertEquals(await usage(user), 2);
    await refund(user, r1.reservation_id);
    const retry = await reserve(user, uuid(), "op");
    assertEquals(retry.allowed, true, "a legitimate retry after quota frees up must not be permanently blocked");
  });

  // Codex adversarial review (mission 13V) — this scenario existed only in
  // an untracked scratch script, not the committed suite. It regression-
  // tests an earlier (pre-13V) Codex finding: a delayed refund must
  // decrement the PERIOD THE RESERVATION ACTUALLY BELONGS TO, never
  // whatever period date_trunc('month', now()) resolves to at refund
  // time.
  Deno.test("REALDB-09: a delayed refund decrements the reservation's OWN period, not the current one", async () => {
    const user = await makeUser();
    const key = uuid();
    const r = await reserve(user, key, "op");
    const conn = await pool.connect();
    try {
      await conn.queryArray(
        `UPDATE public.ai_quota_reservations SET period_start = (date_trunc('month', now()) - interval '1 month')::date WHERE id=$1`,
        [r.reservation_id],
      );
      await conn.queryArray(`DELETE FROM public.ai_usage WHERE user_id=$1`, [user]);
      await conn.queryArray(
        `INSERT INTO public.ai_usage (user_id, period_start, request_count) VALUES ($1, date_trunc('month', now())::date, 0), ($1, (date_trunc('month', now()) - interval '1 month')::date, 1)`,
        [user],
      );
    } finally {
      conn.release();
    }
    const currentBefore = await usage(user);
    await refund(user, r.reservation_id);
    const currentAfter = await usage(user);
    const pastUsage = await (async () => {
      const c = await pool.connect();
      try {
        const row = await c.queryObject(
          `SELECT request_count FROM public.ai_usage WHERE user_id=$1 AND period_start=(date_trunc('month', now()) - interval '1 month')::date`,
          [user],
        );
        return (row.rows[0] as any).request_count;
      } finally {
        c.release();
      }
    })();
    assertEquals(currentBefore, currentAfter, "the CURRENT period's usage must be untouched by a delayed refund of a PAST-period reservation");
    assertEquals(pastUsage, 0, "the PAST period (the reservation's own period_start) must be what actually got decremented");
  });
}
