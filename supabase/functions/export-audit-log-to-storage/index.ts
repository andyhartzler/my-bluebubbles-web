// Export Audit Log to Storage Edge Function
// Nightly archival job: copies one calendar day of `public.audit_log` rows to
// the private `audit-archive` Storage bucket as NDJSON.
//
// Invocation: pg_cron via pg_net.http_post, daily at 03:00 UTC.
//   POST { "date": "YYYY-MM-DD" }   // defaults to yesterday (UTC) if omitted
//   Header: x-cron-secret: <CRON_SECRET>
//
// Environment variables (set via Supabase Dashboard → Edge Functions → Secrets):
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY
//   CRON_SECRET — shared secret between pg_cron caller and this function
//
// Idempotency: uploads with upsert=true, so a retry overwrites the previous
// NDJSON for the same date (a warning is logged). The summary EDGE_FN row in
// `public.audit_log` is written on every run — that's by design for an audit
// trail of the archive job itself.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";
const BUCKET = "audit-archive";
const BATCH_SIZE = 10_000;

if (!CRON_SECRET) {
  console.warn("[export-audit-log-to-storage] CRON_SECRET is not set — all requests will be rejected.");
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function yesterdayUtcIso(): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - 1);
  return d.toISOString().slice(0, 10); // YYYY-MM-DD
}

function isValidDate(s: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const d = new Date(`${s}T00:00:00Z`);
  return !isNaN(d.getTime()) && d.toISOString().slice(0, 10) === s;
}

async function logSummary(
  supabase: ReturnType<typeof createClient>,
  archivedDate: string,
  rowCount: number,
  storagePath: string | null,
  status: "success" | "failure",
  errorMessage?: string,
): Promise<void> {
  const context: Record<string, unknown> = {
    event: "archive",
    archived_date: archivedDate,
    row_count: rowCount,
    storage_path: storagePath,
    status,
  };
  if (errorMessage) context.error = errorMessage;

  const { error } = await supabase.from("audit_log").insert({
    actor_role: "service_role",
    action: "EDGE_FN",
    schema_name: "public",
    table_name: "audit_log",
    context,
  });
  if (error) {
    console.error("[export-audit-log-to-storage] Failed to write summary audit row:", error);
  }
}

serve(async (req) => {
  // Authenticate via shared secret.
  const presented = req.headers.get("x-cron-secret") ?? "";
  if (!CRON_SECRET || presented !== CRON_SECRET) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method not allowed" }, 405);
  }

  // Parse body; date defaults to yesterday UTC.
  let dateStr = yesterdayUtcIso();
  try {
    const raw = await req.text();
    if (raw && raw.trim().length > 0) {
      const body = JSON.parse(raw) as { date?: string };
      if (body.date) {
        if (!isValidDate(body.date)) {
          return jsonResponse({ error: "date must be YYYY-MM-DD" }, 400);
        }
        dateStr = body.date;
      }
    }
  } catch (_) {
    return jsonResponse({ error: "invalid JSON body" }, 400);
  }

  const [yyyy, mm] = dateStr.split("-");
  const fileName = `audit_log_${dateStr}.ndjson`;
  const storagePath = `daily/${yyyy}/${mm}/${fileName}`;
  const dayStartIso = `${dateStr}T00:00:00Z`;
  const dayEndIso = `${dateStr}T23:59:59.999Z`;

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Check for pre-existing archive (warn on overwrite for retry idempotency).
  try {
    const { data: existing } = await supabase.storage
      .from(BUCKET)
      .list(`daily/${yyyy}/${mm}`, { limit: 100, search: fileName });
    if (existing?.some((o) => o.name === fileName)) {
      console.warn(
        `[export-audit-log-to-storage] Overwriting existing archive at ${storagePath} (pg_cron retry?)`,
      );
    }
  } catch (e) {
    // Non-fatal — `.list()` can fail on a missing prefix; we proceed to upload.
    console.warn("[export-audit-log-to-storage] pre-check list() failed:", e);
  }

  // Stream rows in batches of BATCH_SIZE, accumulate as NDJSON.
  // TODO(scale): once partitions reach >100K rows/day, swap to a streaming
  // upload via a signed upload URL rather than in-memory buffering.
  const chunks: string[] = [];
  let rowCount = 0;
  try {
    // Keyset pagination over (occurred_at, id) — stable ordering + cheap with
    // a BTREE on (occurred_at, id) which the audit_log PK already provides.
    let offset = 0;
    for (;;) {
      const { data, error } = await supabase
        .from("audit_log")
        .select("*")
        .gte("occurred_at", dayStartIso)
        .lte("occurred_at", dayEndIso)
        .order("occurred_at", { ascending: true })
        .order("id", { ascending: true })
        .range(offset, offset + BATCH_SIZE - 1);
      if (error) throw error;
      if (!data || data.length === 0) break;

      for (const row of data) {
        chunks.push(JSON.stringify(row));
      }
      rowCount += data.length;
      if (data.length < BATCH_SIZE) break;
      offset += BATCH_SIZE;
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("[export-audit-log-to-storage] Query failed:", msg);
    await logSummary(supabase, dateStr, 0, null, "failure", `query: ${msg}`);
    return jsonResponse({ error: "query failed", detail: msg }, 500);
  }

  // Zero-row days: skip the upload so we never plant empty files.
  if (rowCount === 0) {
    await logSummary(supabase, dateStr, 0, null, "success");
    return jsonResponse({
      ok: true,
      archived_date: dateStr,
      row_count: 0,
      storage_path: null,
      note: "no rows — upload skipped",
    });
  }

  // Serialize to NDJSON (trailing newline for POSIX friendliness).
  const ndjson = chunks.join("\n") + "\n";
  const bytes = new TextEncoder().encode(ndjson);

  // Upload with upsert=true so retries overwrite cleanly.
  const { error: uploadErr } = await supabase.storage
    .from(BUCKET)
    .upload(storagePath, bytes, {
      contentType: "application/x-ndjson",
      upsert: true,
    });
  if (uploadErr) {
    console.error("[export-audit-log-to-storage] Upload failed:", uploadErr);
    await logSummary(
      supabase,
      dateStr,
      rowCount,
      storagePath,
      "failure",
      `upload: ${uploadErr.message}`,
    );
    return jsonResponse({ error: "upload failed", detail: uploadErr.message }, 500);
  }

  // Verify the object landed.
  const { data: verify, error: verifyErr } = await supabase.storage
    .from(BUCKET)
    .list(`daily/${yyyy}/${mm}`, { limit: 100, search: fileName });
  if (verifyErr || !verify?.some((o) => o.name === fileName)) {
    const msg = verifyErr?.message ?? "object not found after upload";
    console.error("[export-audit-log-to-storage] Verification failed:", msg);
    await logSummary(supabase, dateStr, rowCount, storagePath, "failure", `verify: ${msg}`);
    return jsonResponse({ error: "verification failed", detail: msg }, 500);
  }

  await logSummary(supabase, dateStr, rowCount, storagePath, "success");

  return jsonResponse({
    ok: true,
    archived_date: dateStr,
    row_count: rowCount,
    storage_path: storagePath,
    bucket: BUCKET,
    bytes: bytes.byteLength,
  });
});
