/**
 * TEST-ONLY RpcTransport over the psql CLI (IV-AEF-PERSISTENCE-01).
 *
 * Each call spawns one psql process = one real PostgreSQL connection, so
 * concurrent calls are genuinely concurrent transactions. Every call runs
 * `SET ROLE service_role` first, exactly the role production uses through
 * PostgREST. Refuses non-local hosts, like the disposable DB runner.
 * Never used by production code.
 */
import { AEF_RPC_NAMES, type AefRpcName, type RpcTransport } from "../store.ts";

export interface PsqlOptions {
  psql: string;
  host: string;
  port: string;
  user: string;
  database: string;
  password?: string;
}

export function psqlOptionsFromEnv(): PsqlOptions | null {
  const database = Deno.env.get("AEF_PG_DB");
  if (!database) return null;
  const host = Deno.env.get("PGHOST") ?? "127.0.0.1";
  if (host !== "127.0.0.1" && host !== "localhost") throw new Error(`refusing non-local host '${host}'`);
  return {
    psql: Deno.env.get("PSQL") ?? "psql",
    host,
    port: Deno.env.get("PGPORT") ?? "5432",
    user: Deno.env.get("PGUSER") ?? "postgres",
    database,
    password: Deno.env.get("PGPASSWORD") ?? undefined,
  };
}

/** Runs SQL (as the connecting superuser unless the SQL sets a role) and returns stdout lines. */
export async function runPsql(opts: PsqlOptions, sql: string): Promise<string[]> {
  const env: Record<string, string> = {};
  if (opts.password) env.PGPASSWORD = opts.password;
  const child = new Deno.Command(opts.psql, {
    args: ["-X", "-q", "-A", "-t", "-v", "ON_ERROR_STOP=1", "-h", opts.host, "-p", opts.port, "-U", opts.user, "-d", opts.database, "-f", "-"],
    stdin: "piped",
    stdout: "piped",
    stderr: "piped",
    env,
  }).spawn();
  const writer = child.stdin.getWriter();
  await writer.write(new TextEncoder().encode(sql));
  await writer.close();
  const { code, stdout, stderr } = await child.output();
  if (code !== 0) throw new Error(`psql failed (${code}): ${new TextDecoder().decode(stderr).trim()}`);
  return new TextDecoder().decode(stdout).split(/\r?\n/).filter((l) => l.length > 0);
}

function dollarQuote(text: string): string {
  const tag = `aef${crypto.randomUUID().replaceAll("-", "")}`;
  if (text.includes(`$${tag}$`)) throw new Error("dollar-quote tag collision");
  return `$${tag}$${text}$${tag}$`;
}

export class PsqlTransport implements RpcTransport {
  constructor(private readonly opts: PsqlOptions) {}

  async call(fn: AefRpcName, args: Record<string, unknown>): Promise<unknown> {
    if (!(AEF_RPC_NAMES as readonly string[]).includes(fn)) throw new Error(`unknown rpc ${fn}`);
    const lines = await runPsql(this.opts, `SET ROLE service_role;\nSELECT public.${fn}(${dollarQuote(JSON.stringify(args))}::jsonb);\n`);
    return JSON.parse(lines[lines.length - 1]);
  }
}
