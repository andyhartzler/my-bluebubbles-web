// zoom-reconcile — daily sweep that guarantees no Zoom cloud recording is ever
// missing from public.meetings.
//
// Created 2026-06-11 as part of the Zoom→CRM pipeline durability work
// (replaces the Mac-bound backfill script /Users/moyd/n8n-data/patches/
// backfill_zoom_meetings.py as the ongoing safety net; that script remains for
// ad-hoc historical backfills).
//
// What it does:
//   1. Lists Zoom cloud recordings for the past N days (default 7) via the
//      recordings S2S OAuth app (same API calls as the proven backfill script:
//      GET /v2/users/me → GET /v2/users/{id}/recordings, paginated).
//   2. Diffs the Zoom meeting ids against public.meetings.zoom_meeting_id.
//   3. For every miss, POSTs a recording.completed-shaped payload to the
//      zoom-webhook relay, signed with ZOOM_WEBHOOK_SECRET_TOKEN so it passes
//      the relay's x-zm-signature verification. The relay then writes the
//      minimal row immediately and fans out to n8n for full enrichment
//      (minutes, Google Doc, Notion, attendance) — identical to an organic
//      Zoom event.
//   4. Sends a Telegram summary ONLY when it replayed misses or hit errors.
//      Fully reconciled days are silent.
//
// Invocation: pg_cron job `zoom-reconcile-daily` (see cron.job) calls this via
// net.http_post daily at 12:00 UTC (07:00 America/Chicago during DST, 06:00
// CST in winter — pg_cron on Supabase schedules in UTC only). Deployed WITH
// JWT verification (default), so only service-role callers can trigger it.
//
// Optional POST body: { "days": 7, "dry_run": false }
//   dry_run lists misses without replaying or alerting.
//
// Env required:
//   ZOOM_RECORDINGS_CLIENT_ID / _SECRET / _ACCOUNT_ID  (preferred; proven scopes:
//     meeting:read:list_recordings:admin, user:read:user:admin)
//     — falls back to ZOOM_CLIENT_ID / ZOOM_CLIENT_SECRET / ZOOM_ACCOUNT_ID
//   ZOOM_WEBHOOK_SECRET_TOKEN     to sign replayed events for zoom-webhook
//   TELEGRAM_ALERT_BOT_TOKEN / TELEGRAM_ALERT_CHAT_ID
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY (auto-injected)
import { serve as stdServe } from "https://deno.land/std@0.168.0/http/server.ts";
import { withSentry } from "../_shared/sentry.ts";
// Sentry-wrapped serve: errors + 5xx responses report to supabase-edge project.
const serve = (h: (req: Request) => Promise<Response> | Response) => stdServe(withSentry("zoom-reconcile", h));
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  });
}

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), {
    name: 'HMAC',
    hash: 'SHA-256'
  }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function getZoomAccessToken(): Promise<string> {
  const clientId = Deno.env.get('ZOOM_RECORDINGS_CLIENT_ID') || Deno.env.get('ZOOM_CLIENT_ID');
  const clientSecret = Deno.env.get('ZOOM_RECORDINGS_CLIENT_SECRET') || Deno.env.get('ZOOM_CLIENT_SECRET');
  const accountId = Deno.env.get('ZOOM_RECORDINGS_ACCOUNT_ID') || Deno.env.get('ZOOM_ACCOUNT_ID');
  if (!clientId || !clientSecret || !accountId) throw new Error('Missing Zoom credentials in env');
  const res = await fetch(`https://zoom.us/oauth/token?grant_type=account_credentials&account_id=${encodeURIComponent(accountId)}`, {
    method: 'POST',
    headers: { 'Authorization': `Basic ${btoa(`${clientId}:${clientSecret}`)}` }
  });
  if (!res.ok) throw new Error(`Zoom OAuth error: ${res.status} ${await res.text()}`);
  return (await res.json()).access_token;
}

async function zoomGet(path: string, token: string) {
  const res = await fetch(`https://api.zoom.us${path}`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  if (!res.ok) throw new Error(`Zoom GET ${path} failed: ${res.status} ${await res.text()}`);
  return await res.json();
}

// List all cloud recordings in [from, to] (YYYY-MM-DD), following pagination.
async function listRecordings(token: string, userId: string, from: string, to: string) {
  const meetings: any[] = [];
  let nextPageToken = '';
  do {
    const qs = `from=${from}&to=${to}&page_size=100${nextPageToken ? `&next_page_token=${encodeURIComponent(nextPageToken)}` : ''}`;
    const page = await zoomGet(`/v2/users/${encodeURIComponent(userId)}/recordings?${qs}`, token);
    meetings.push(...(page.meetings || []));
    nextPageToken = page.next_page_token || '';
  } while (nextPageToken);
  return meetings;
}

// Replay a recording.completed-shaped event to the zoom-webhook relay, signed
// so it passes x-zm-signature verification (same payload shape as the proven
// backfill script).
async function replayToZoomWebhook(m: any, accountId: string): Promise<{ status: number; text: string }> {
  const secretToken = Deno.env.get('ZOOM_WEBHOOK_SECRET_TOKEN');
  if (!secretToken) throw new Error('ZOOM_WEBHOOK_SECRET_TOKEN not set — cannot sign replay');
  const body = JSON.stringify({
    event: 'recording.completed',
    event_ts: Date.now(),
    _moyd_replay: { source: 'zoom-reconcile', replayed_at: new Date().toISOString() },
    payload: {
      account_id: accountId,
      object: {
        id: m.id,
        uuid: m.uuid,
        host_id: m.host_id,
        account_id: accountId,
        topic: m.topic,
        type: m.type ?? 2,
        start_time: m.start_time,
        duration: m.duration,
        timezone: m.timezone || 'America/Chicago',
        total_size: m.total_size,
        share_url: m.share_url,
        recording_count: (m.recording_files || []).length,
        recording_files: m.recording_files || []
      }
    }
  });
  const ts = Math.floor(Date.now() / 1000).toString();
  const signature = `v0=${await hmacSha256Hex(secretToken, `v0:${ts}:${body}`)}`;
  const res = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/zoom-webhook`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-zm-request-timestamp': ts,
      'x-zm-signature': signature
    },
    body
  });
  return { status: res.status, text: (await res.text()).slice(0, 300) };
}

async function sendTelegram(text: string) {
  try {
    const token = Deno.env.get('TELEGRAM_ALERT_BOT_TOKEN');
    const chatId = Deno.env.get('TELEGRAM_ALERT_CHAT_ID');
    if (!token || !chatId) {
      console.error('[zoom-reconcile] telegram secrets not set — summary not sent');
      return;
    }
    const res = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: chatId, text })
    });
    if (!res.ok) console.error(`[zoom-reconcile] telegram non-2xx: ${res.status} ${await res.text()}`);
  } catch (e) {
    console.error('[zoom-reconcile] telegram failed:', String(e?.message || e));
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  const startedAt = new Date().toISOString();
  let days = 7;
  let dryRun = false;
  try {
    const body = await req.json().catch(() => ({}));
    if (Number.isFinite(Number(body?.days)) && Number(body.days) > 0 && Number(body.days) <= 30) {
      days = Math.floor(Number(body.days));
    }
    dryRun = body?.dry_run === true;
  } catch (_) { /* defaults */ }

  const errors: string[] = [];
  const replayed: { id: string; topic: string; status?: number }[] = [];
  let recordings: any[] = [];

  try {
    const accountId = Deno.env.get('ZOOM_RECORDINGS_ACCOUNT_ID') || Deno.env.get('ZOOM_ACCOUNT_ID') || '';
    const token = await getZoomAccessToken();
    const me = await zoomGet('/v2/users/me', token);
    const to = new Date();
    const from = new Date(to.getTime() - days * 24 * 60 * 60 * 1000);
    const fmt = (d: Date) => d.toISOString().slice(0, 10);
    recordings = await listRecordings(token, me.id, fmt(from), fmt(to));
    console.log(`[zoom-reconcile] zoom reports ${recordings.length} cloud recording(s) ${fmt(from)}..${fmt(to)}`);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // Diff on the per-occurrence Zoom UUID, not the numeric meeting id. Recurring
    // meetings reuse one numeric id for every occurrence; only the uuid is unique
    // per occurrence, and public.meetings now keys on zoom_meeting_uuid. Diffing
    // on the numeric id would treat every occurrence after the first as "known"
    // and never replay it.
    const zoomUuids = [...new Set(recordings.map((m) => String(m.uuid)).filter((u) => u && u !== 'undefined'))];
    let known = new Set<string>();
    if (zoomUuids.length > 0) {
      const { data, error } = await supabase
        .from('meetings')
        .select('zoom_meeting_uuid')
        .in('zoom_meeting_uuid', zoomUuids);
      if (error) throw new Error(`meetings lookup failed: ${error.message}`);
      known = new Set((data || []).map((r: any) => String(r.zoom_meeting_uuid)));
    }

    // Replay each missing occurrence (unique uuid) once. Distinct occurrences of
    // a recurring meeting share a numeric id but have distinct uuids, so each is
    // reconciled independently.
    const seen = new Set<string>();
    for (const m of recordings) {
      const id = String(m.id);
      const uuid = String(m.uuid || '');
      if (!uuid) {
        errors.push(`recording ${id} (${m.topic}) missing uuid — cannot reconcile`);
        continue;
      }
      if (known.has(uuid) || seen.has(uuid)) continue;
      seen.add(uuid);
      console.log(`[zoom-reconcile] MISS zoom_meeting_uuid=${uuid} id=${id} topic=${m.topic} start=${m.start_time}`);
      if (dryRun) {
        replayed.push({ id, topic: m.topic });
        continue;
      }
      try {
        const r = await replayToZoomWebhook(m, accountId);
        replayed.push({ id, topic: m.topic, status: r.status });
        if (r.status !== 200) errors.push(`replay ${id} (${m.topic}) → HTTP ${r.status}: ${r.text}`);
      } catch (e) {
        errors.push(`replay ${id} (${m.topic}) threw: ${String(e?.message || e)}`);
      }
    }
  } catch (e) {
    errors.push(String(e?.message || e));
  }

  const result = {
    started_at: startedAt,
    window_days: days,
    dry_run: dryRun,
    zoom_recordings_found: recordings.length,
    misses_replayed: replayed,
    errors
  };
  console.log('[zoom-reconcile] result:', JSON.stringify(result));

  // Telegram ONLY when something happened — silent when fully reconciled.
  if (!dryRun && (replayed.length > 0 || errors.length > 0)) {
    const lines = [
      replayed.length > 0 ? '🔁 Zoom reconcile: replayed missing meetings' : '⚠️ Zoom reconcile ran with errors',
      `Window: last ${days} day(s), ${recordings.length} cloud recording(s)`,
      ...replayed.map((r) => `• ${r.topic} (${r.id}) → ${r.status ?? 'dry-run'}`),
      ...errors.map((e) => `❌ ${e}`)
    ];
    await sendTelegram(lines.join('\n').slice(0, 4000));
  }

  return json(errors.length > 0 ? 500 : 200, result);
});
