// sentry-log-relay: forwards Supabase platform-level failures to Sentry.
// Runs every 5 minutes via pg_cron (x-cron-secret auth, vault-stored).
// Categories: auth failures, storage errors, API 5xx, 429s/traffic bursts, postgres errors.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PROJECT_REF = "faajpcarasilbfndzkmd";
const MGMT_BASE = `https://api.supabase.com/v1/projects/${PROJECT_REF}/analytics/endpoints/logs.all`;

const CRON_SECRET = Deno.env.get("RELAY_CRON_SECRET") ?? "";
const MGMT_TOKEN = Deno.env.get("MGMT_API_TOKEN") ?? "";
const SENTRY_DSN = Deno.env.get("SENTRY_DSN_PLATFORM") ?? "";
const BURST_THRESHOLD = Number(Deno.env.get("BURST_THRESHOLD") ?? "5000");

interface EdgeRow {
  ts: string;
  method: string;
  path: string;
  status: number;
  ip: string | null;
}
interface PgRow {
  ts: string;
  sev: string;
  msg: string;
}

function dsnParts(dsn: string) {
  const u = new URL(dsn);
  return {
    key: u.username,
    host: u.host,
    projectId: u.pathname.replace("/", ""),
  };
}

async function sendSentryEvent(opts: {
  message: string;
  level: "error" | "warning" | "info";
  fingerprint: string[];
  tags: Record<string, string>;
  extra: Record<string, unknown>;
}): Promise<string | null> {
  const { key, host, projectId } = dsnParts(SENTRY_DSN);
  const eventId = crypto.randomUUID().replace(/-/g, "");
  const now = new Date().toISOString();
  const event = {
    event_id: eventId,
    timestamp: now,
    platform: "other",
    level: opts.level,
    logger: "sentry-log-relay",
    message: opts.message,
    fingerprint: opts.fingerprint,
    tags: { source: "supabase-platform-logs", ...opts.tags },
    extra: opts.extra,
    server_name: `supabase/${PROJECT_REF}`,
  };
  const body =
    JSON.stringify({ event_id: eventId, sent_at: now }) + "\n" +
    JSON.stringify({ type: "event" }) + "\n" +
    JSON.stringify(event);
  const res = await fetch(`https://${host}/api/${projectId}/envelope/`, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-sentry-envelope",
      "X-Sentry-Auth":
        `Sentry sentry_key=${key}, sentry_version=7, sentry_client=sentry-log-relay/1.0`,
    },
    body,
  });
  if (!res.ok) {
    console.error("sentry ingest failed", res.status, await res.text());
    return null;
  }
  return eventId;
}

// The management API fronts the logs endpoint behind a CDN that intermittently
// answers 5xx with an HTML error page, and throttles bursts with 429. Retry
// both, and network-level failures, before giving up on the window.
const LOGS_QUERY_ATTEMPTS = 3;
const LOGS_RETRY_BASE_MS = 750;
// A throttle clears on its own clock rather than on ours, so a 429 waits
// longer than the 5xx backoff and honours the wait the server names. The
// floor stops a zero or already elapsed Retry-After from becoming an instant
// retry into the same throttle; the cap stops a long one from parking the run
// into the next 5 minute cron tick.
const THROTTLE_MIN_MS = 5_000;
const THROTTLE_CAP_MS = 30_000;

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// Retry-After is either a seconds count or an HTTP date. Returns null when the
// header is absent or unparseable, so the caller can apply its own floor.
function parseRetryAfter(header: string | null): number | null {
  if (!header) return null;
  const seconds = Number(header);
  if (Number.isFinite(seconds)) return seconds * 1000;
  const until = Date.parse(header);
  if (Number.isNaN(until)) return null;
  return until - Date.now();
}

function throttleDelayMs(res: Response): number {
  const requested = parseRetryAfter(res.headers.get("retry-after"));
  return Math.min(Math.max(requested ?? 0, THROTTLE_MIN_MS), THROTTLE_CAP_MS);
}

// Carries the upstream body out of band so it stays out of the error message.
// The message is the Sentry issue title, so it has to stay stable and short;
// the body goes in extra, where a 300-line HTML page is harmless.
class LogsQueryError extends Error {
  readonly status: number;
  readonly body: string;
  constructor(status: number, attempts: number, body: string) {
    super(`logs query failed ${status} after ${attempts} attempt(s)`);
    this.name = "LogsQueryError";
    this.status = status;
    this.body = body;
  }
}

async function queryLogs<T>(sql: string, startIso: string, endIso: string): Promise<T[]> {
  const url = `${MGMT_BASE}?iso_timestamp_start=${encodeURIComponent(startIso)}` +
    `&iso_timestamp_end=${encodeURIComponent(endIso)}&sql=${encodeURIComponent(sql)}`;

  for (let attempt = 1; ; attempt++) {
    const last = attempt >= LOGS_QUERY_ATTEMPTS;
    let res: Response;
    try {
      res = await fetch(url, { headers: { Authorization: `Bearer ${MGMT_TOKEN}` } });
    } catch (e) {
      if (last) throw new LogsQueryError(0, attempt, String(e));
      await sleep(LOGS_RETRY_BASE_MS * attempt);
      continue;
    }
    if (res.ok) {
      const data = await res.json();
      return (data.result ?? []) as T[];
    }
    // Body must be consumed either way so the connection is not left open.
    const body = (await res.text()).slice(0, 300);
    // 429 is a throttle: the identical request succeeds once the window
    // clears. Every other 4xx is a bad token or a bad query, where retrying
    // cannot change the answer.
    const retryable = res.status >= 500 || res.status === 429;
    if (!retryable || last) throw new LogsQueryError(res.status, attempt, body);
    // A 5xx is a transient CDN fault, and the linear backoff already suits it.
    // A 429 is a throttle with its own window, so wait as the server asks.
    await sleep(
      res.status === 429 ? throttleDelayMs(res) : LOGS_RETRY_BASE_MS * attempt,
    );
  }
}

function tally<T>(rows: T[], keyFn: (r: T) => string, cap = 10): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const r of rows) {
    const k = keyFn(r);
    counts[k] = (counts[k] ?? 0) + 1;
  }
  return Object.fromEntries(
    Object.entries(counts).sort((a, b) => b[1] - a[1]).slice(0, cap),
  );
}

// Collapse volatile path segments (uuids, numeric ids, object names) for grouping
function pathGroup(path: string): string {
  return path
    .split("?")[0]
    .replace(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, ":id")
    .replace(/\/\d+(\/|$)/g, "/:n$1")
    .split("/").slice(0, 5).join("/");
}

Deno.serve(async (req: Request) => {
  if (req.headers.get("x-cron-secret") !== CRON_SECRET || !CRON_SECRET) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  try {
    // Window: [last watermark, now - 60s ingestion lag], capped at 60 min after downtime
    const { data: state, error: stateErr } = await supabase
      .from("sentry_log_relay_state").select("last_end").eq("id", 1).single();
    if (stateErr) throw new Error(`state read failed: ${stateErr.message}`);

    const start = new Date(state.last_end);
    const maxEnd = new Date(Date.now() - 60_000);
    const cappedEnd = new Date(Math.min(maxEnd.getTime(), start.getTime() + 3_600_000));
    if (cappedEnd <= start) {
      return new Response(JSON.stringify({ skipped: "window not ready" }), { status: 200 });
    }
    const startIso = start.toISOString();
    const endIso = cappedEnd.toISOString();

    const EDGE_SQL = `
      select cast(t.timestamp as string) as ts, r.method as method, r.path as path,
             resp.status_code as status, h.x_real_ip as ip
      from edge_logs t
      cross join unnest(t.metadata) m
      cross join unnest(m.request) r
      cross join unnest(m.response) resp
      cross join unnest(r.headers) h
      where resp.status_code >= 400
      limit 1000`;
    const TOTAL_SQL = `select count(*) as total from edge_logs t`;
    const PG_SQL = `
      select cast(t.timestamp as string) as ts, p.error_severity as sev,
             t.event_message as msg
      from postgres_logs t
      cross join unnest(t.metadata) m
      cross join unnest(m.parsed) p
      where p.error_severity in ('ERROR','FATAL','PANIC')
      limit 200`;

    const [edgeRows, totalRows, pgRows] = await Promise.all([
      queryLogs<EdgeRow>(EDGE_SQL, startIso, endIso),
      queryLogs<{ total: number }>(TOTAL_SQL, startIso, endIso),
      queryLogs<PgRow>(PG_SQL, startIso, endIso).catch((e) => {
        console.error("postgres_logs query failed (non-fatal):", e.message);
        return [] as PgRow[];
      }),
    ]);
    const totalRequests = totalRows[0]?.total ?? 0;

    const authFails = edgeRows.filter((r) =>
      r.path.startsWith("/auth/v1/token") && [400, 401, 403].includes(r.status)
    );
    const storageErrs = edgeRows.filter((r) =>
      r.path.startsWith("/storage/v1") && r.status >= 400 && r.status !== 404
    );
    const any5xx = edgeRows.filter((r) => r.status >= 500);
    const tooMany = edgeRows.filter((r) => r.status === 429);

    const windowTag = { window_start: startIso, window_end: endIso };
    const sent: string[] = [];

    if (authFails.length > 0) {
      const byIp = tally(authFails, (r) => r.ip ?? "unknown");
      const id = await sendSentryEvent({
        message: `Auth failures: ${authFails.length} failed sign-in/token attempts`,
        level: authFails.length >= 20 ? "error" : "warning",
        fingerprint: ["supabase-platform", "auth-failures"],
        tags: { category: "auth" },
        extra: { count: authFails.length, top_ips: byIp, sample: authFails.slice(0, 5), ...windowTag },
      });
      if (id) sent.push(`auth-failures:${id}`);
    }

    if (storageErrs.length > 0) {
      const id = await sendSentryEvent({
        message: `Storage errors: ${storageErrs.length} failed storage requests (uploads/downloads)`,
        level: "error",
        fingerprint: ["supabase-platform", "storage-errors"],
        tags: { category: "storage" },
        extra: {
          count: storageErrs.length,
          by_status: tally(storageErrs, (r) => String(r.status)),
          by_path: tally(storageErrs, (r) => `${r.method} ${pathGroup(r.path)}`),
          sample: storageErrs.slice(0, 5),
          ...windowTag,
        },
      });
      if (id) sent.push(`storage-errors:${id}`);
    }

    if (any5xx.length > 0) {
      const id = await sendSentryEvent({
        message: `API 5xx: ${any5xx.length} server errors at the gateway`,
        level: "error",
        fingerprint: ["supabase-platform", "api-5xx"],
        tags: { category: "api-5xx" },
        extra: {
          count: any5xx.length,
          by_path: tally(any5xx, (r) => `${r.method} ${pathGroup(r.path)}`),
          by_status: tally(any5xx, (r) => String(r.status)),
          sample: any5xx.slice(0, 5),
          ...windowTag,
        },
      });
      if (id) sent.push(`api-5xx:${id}`);
    }

    if (tooMany.length > 0 || totalRequests > BURST_THRESHOLD) {
      const id = await sendSentryEvent({
        message: tooMany.length > 0
          ? `Rate limiting: ${tooMany.length} requests hit 429 (total ${totalRequests} reqs in window)`
          : `Traffic burst: ${totalRequests} requests in window (threshold ${BURST_THRESHOLD})`,
        level: "warning",
        fingerprint: ["supabase-platform", "traffic-burst"],
        tags: { category: "traffic" },
        extra: {
          total_requests: totalRequests,
          count_429: tooMany.length,
          top_429_ips: tally(tooMany, (r) => r.ip ?? "unknown"),
          top_429_paths: tally(tooMany, (r) => pathGroup(r.path)),
          ...windowTag,
        },
      });
      if (id) sent.push(`traffic:${id}`);
    }

    if (pgRows.length > 0) {
      // Normalize messages for grouping (strip volatile literals)
      const norm = (m: string) =>
        m.replace(/"[^"]*"/g, '"?"').replace(/\d+/g, "N").slice(0, 160);
      const fatal = pgRows.some((r) => r.sev === "FATAL" || r.sev === "PANIC");
      const id = await sendSentryEvent({
        message: `Postgres errors: ${pgRows.length} (${fatal ? "includes FATAL" : "ERROR level"})`,
        level: fatal ? "error" : "warning",
        fingerprint: ["supabase-platform", "postgres-errors"],
        tags: { category: "postgres" },
        extra: {
          count: pgRows.length,
          by_message: tally(pgRows, (r) => norm(r.msg), 15),
          by_severity: tally(pgRows, (r) => r.sev),
          sample: pgRows.slice(0, 5),
          ...windowTag,
        },
      });
      if (id) sent.push(`postgres:${id}`);
    }

    const { error: updErr } = await supabase
      .from("sentry_log_relay_state")
      .update({ last_end: endIso })
      .eq("id", 1);
    if (updErr) throw new Error(`watermark update failed: ${updErr.message}`);

    const summary = {
      window: { start: startIso, end: endIso },
      total_requests: totalRequests,
      counts: {
        auth_failures: authFails.length,
        storage_errors: storageErrs.length,
        api_5xx: any5xx.length,
        http_429: tooMany.length,
        postgres_errors: pgRows.length,
      },
      sentry_events: sent,
    };
    console.log("relay summary", JSON.stringify(summary));
    return new Response(JSON.stringify(summary), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("sentry-log-relay failed:", err);
    // Report the relay's own failure so a broken relay is not silent
    try {
      const reason = err instanceof Error ? err.message : String(err);
      await sendSentryEvent({
        message: `sentry-log-relay failure: ${reason.slice(0, 300)}`,
        level: "error",
        fingerprint: ["supabase-platform", "relay-failure"],
        tags: { category: "relay-internal" },
        extra: {
          error: String(err),
          ...(err instanceof LogsQueryError
            ? { upstream_status: err.status, upstream_body: err.body }
            : {}),
        },
      });
    } catch (_) { /* last resort: runtime logs only */ }
    // Detail belongs in Sentry, not in the response body.
    return new Response(JSON.stringify({ error: "relay run failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
