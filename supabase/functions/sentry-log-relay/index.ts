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
  // postgres_logs metadata.parsed.application_name. Null for anything the
  // postmaster raises before a session exists, which is every connection probe.
  app: string | null;
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

// Connection probes against the public direct-connect endpoint on 5432.
//
// Every shape below is raised by the postmaster BEFORE authentication
// completes, so no statement of ours can produce one: there is no session, no
// transaction and no query behind them. They are unattributable from here by
// construction, because the rollup carries no client address (the dashboard
// log explorer keeps the unscrubbed line, and that is where the attribution
// question has to be settled). Reporting them one Sentry event per five minute
// window bought nothing and cost about 40 percent of this issue's volume.
//
// Suppressed rather than deleted: the count still rides along on any event that
// does fire, and a burst above the threshold gets its own fingerprint, so a
// genuine escalation stays visible while the routine drip stops paying rent.
// The real remediation is network restrictions or dropping the direct-connect
// endpoint for the pooler, which is infrastructure and not a code change.
const PROBE_PATTERNS: readonly RegExp[] = [
  /^password authentication failed for user/,
  /^unsupported frontend protocol /,
  /^no PostgreSQL user name specified in startup packet/,
  /^expected SASL response/,
  /^canceling authentication due to timeout/,
];

// Sized against observed history: routine probe windows carry 1 to 6 lines,
// while the anomalous ones on record carry 7, 14 and 24. This lets those three
// through and stops the drip.
const PROBE_BURST_THRESHOLD = 20;

// The severity guard matters. These strings are only ever FATAL when the
// postmaster raises them, so requiring FATAL means an ERROR level line that
// merely quotes one (a RAISE, a probe harness, an application log) is never
// silently dropped.
function isConnectionProbe(r: PgRow): boolean {
  return r.sev === "FATAL" && PROBE_PATTERNS.some((re) => re.test(r.msg));
}

// Statements typed by an operator through the Supabase Management API.
//
// `mgmt-api` is the application_name Postgres records for a connection opened
// by POST /v1/projects/:ref/database/query and its migrations sibling. Reaching
// that endpoint requires a personal access token, so no product code and no end
// user can ever appear under it: the CRM and the website both reach Postgres as
// `postgrest`, edge functions and scripts connect under their own names, and
// pg_cron background workers carry none at all. Verified rather than assumed,
// by reading application_name back through that same endpoint.
//
// The consequence is that an error under this name has already been delivered
// to a human, synchronously, as the HTTP response to the statement that raised
// it. Reporting it again five minutes later tells nobody anything they do not
// have. Over 2026-08-11 it was 18 of the 155 non-probe lines but NINE of the
// twenty five-minute windows that fired an event, because ad-hoc SQL arrives in
// ones and twos across many windows while product errors arrive in bursts.
//
// This is the same category as PROBE_PATTERNS above and it is a REPORTING
// change, not a defect fix: nothing here is broken, and the two families it
// removes are a security-hardening verification harness deliberately calling
// just-revoked functions to prove they are blocked, and operator introspection
// with column-name typos.
//
// Scope it narrowly, in two ways that both matter.
//
// It does NOT reach the same harness's probes through PostgREST. Verifying a
// revoke with the publishable anon key raises `permission denied for function
// ...` under `postgrest`, on the exact path a genuine refused caller uses, and
// those two are indistinguishable by construction. That family stays reported,
// for the same reason storage 401 and 403 stay reported: it is the RLS and
// grant regression case worth waking up for.
//
// And it is ERROR only. A FATAL or PANIC on an operator session describes the
// server rather than the statement, so it still reports.
const OPERATOR_APPS = new Set(["mgmt-api"]);

function isOperatorSession(r: PgRow): boolean {
  return r.sev === "ERROR" && r.app !== null && OPERATOR_APPS.has(r.app);
}

// Storage statuses that describe the CALLER rather than storage health.
//
// 404 was always excluded here. 400 belongs with it and had not been, which is
// the whole of SUPABASE-PLATFORM-4: Supabase Storage answers 400, not 404, for
// an object or bucket that does not exist, a keyless path, a malformed list
// body, and a public-path read of a bucket that is deliberately private. All
// four mean the request could not be served as asked, and none of them says
// anything about storage working.
//
// Every one of the 18 events that group carried between 2026-07-25 and
// 2026-08-11 was a 400 of exactly that kind, from four different source
// addresses including two datacenter ranges, with 0 users impacted and not one
// upload or download among them. Twenty-nine triage sections in AGENTS.md
// carry this group and not one of them found anything to fix. An error-level
// event every five minutes for traffic we neither emit nor control is not a
// signal.
//
// What still reports: 401 and 403, which is an authenticated caller being
// refused and therefore the RLS-regression case worth waking up for, plus 409,
// 413, 429 and every 5xx. Storage breaking does not answer 400.
//
// A user-facing failure keeps a better reporting path than this one anyway:
// the CRM's own Sentry project captures the failed request with a stack trace
// and a session, where this rollup has attributed 0 users in its entire life.
const STORAGE_CALLER_ERRORS = new Set([400, 404]);

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
             t.event_message as msg, p.application_name as app
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
      r.path.startsWith("/storage/v1") && r.status >= 400 &&
      !STORAGE_CALLER_ERRORS.has(r.status)
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
      const storageByStatus = tally(storageErrs, (r) => String(r.status));
      const storageByPath = tally(storageErrs, (r) => `${r.method} ${pathGroup(r.path)}`);
      // The old title asserted "(uploads/downloads)" unconditionally, and not
      // one of the 18 events it produced was either. Lead with the dominant
      // status and path shape instead, the way the postgres title already
      // does. Grouping is unaffected: the fingerprint is explicit and does not
      // read the title, so this stays SUPABASE-PLATFORM-4 rather than opening
      // a new issue.
      const topShape =
        `${Object.keys(storageByStatus)[0] ?? "?"} ${Object.keys(storageByPath)[0] ?? "?"}`;
      const id = await sendSentryEvent({
        message: `Storage errors: ${storageErrs.length} failed storage requests - ${topShape}`,
        level: "error",
        fingerprint: ["supabase-platform", "storage-errors"],
        tags: { category: "storage" },
        extra: {
          count: storageErrs.length,
          by_status: storageByStatus,
          by_path: storageByPath,
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

    // Normalize messages for grouping (strip volatile literals)
    const norm = (m: string) =>
      m.replace(/"[^"]*"/g, '"?"').replace(/\d+/g, "N").slice(0, 160);

    const probeRows = pgRows.filter(isConnectionProbe);
    const operatorRows = pgRows.filter((r) =>
      !isConnectionProbe(r) && isOperatorSession(r)
    );
    const appRows = pgRows.filter((r) =>
      !isConnectionProbe(r) && !isOperatorSession(r)
    );

    if (appRows.length > 0) {
      const byMessage = tally(appRows, (r) => norm(r.msg), 15);
      const fatal = appRows.some((r) => r.sev === "FATAL" || r.sev === "PANIC");
      // The title used to be a count and a severity flag, so two events with
      // identical titles routinely carried completely different errors and the
      // group could not be decomposed without opening every event. Lead with
      // the dominant shape instead. Grouping is unaffected: the fingerprint is
      // explicit and does not read the title.
      const topShape = (Object.keys(byMessage)[0] ?? "unknown").slice(0, 80);
      const id = await sendSentryEvent({
        message:
          `Postgres errors: ${appRows.length} (${fatal ? "includes FATAL" : "ERROR level"}) - ${topShape}`,
        level: fatal ? "error" : "warning",
        fingerprint: ["supabase-platform", "postgres-errors"],
        tags: { category: "postgres" },
        extra: {
          count: appRows.length,
          by_message: byMessage,
          by_severity: tally(appRows, (r) => r.sev),
          // Who ran the statement. Forty triage passes over this group inferred
          // that from message shape, aliases and burst timing and said each time
          // that it was an inference; this is the field that settles it, so read
          // it before reaching for any of that.
          by_app: tally(appRows, (r) => r.app ?? "none"),
          sample: appRows.slice(0, 5),
          // Both carried even when zero, so a reader can tell "none in this
          // window" from "this build does not know about them".
          probes_suppressed: probeRows.length,
          operator_suppressed: operatorRows.length,
          ...windowTag,
        },
      });
      if (id) sent.push(`postgres:${id}`);
    }

    // Its own fingerprint, so an escalation never lands back in the catch-all.
    if (probeRows.length >= PROBE_BURST_THRESHOLD) {
      const id = await sendSentryEvent({
        message: `Connection probes: ${probeRows.length} rejected pre-auth connections in window`,
        level: "warning",
        fingerprint: ["supabase-platform", "connection-probes"],
        tags: { category: "postgres-probes" },
        extra: {
          count: probeRows.length,
          by_message: tally(probeRows, (r) => norm(r.msg), 15),
          sample: probeRows.slice(0, 5),
          ...windowTag,
        },
      });
      if (id) sent.push(`probes:${id}`);
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
        postgres_errors: appRows.length,
        connection_probes: probeRows.length,
        // A window whose postgres rows are ALL operator or probe rows sends no
        // event, so these two counts ride only here. That is the same trade the
        // probe suppression already makes, and the runtime log is the record.
        operator_sessions: operatorRows.length,
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
