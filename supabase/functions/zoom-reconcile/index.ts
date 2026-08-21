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
//   4. Backstop for the Google Drive recording archive: any meetings row still
//      pointing at a zoom.us recording is copied into the shared drive via
//      archive-meeting-recording, which is what makes it playable in the CRM.
//      See the block above archiveStrandedRecordings for why this lives here
//      and not in zoom-webhook. Bounded to ARCHIVE_MAX_PER_RUN per run.
//   5. Sweeps for INCOMPLETE rows, not just missing ones. See the block above
//      sweepStuckMeetings. This is the leg that would have caught the three
//      stranded Executive Committee meetings on day one.
//   6. Sends a Telegram summary ONLY when it replayed misses, archived a
//      recording, newly found a stuck meeting, or hit errors. Fully reconciled
//      days are silent.
//
// Invocation: pg_cron job `zoom-reconcile-daily` (see cron.job) calls this via
// net.http_post daily at 12:00 UTC (07:00 America/Chicago during DST, 06:00
// CST in winter — pg_cron on Supabase schedules in UTC only). Deployed WITH
// JWT verification (default), so only service-role callers can trigger it.
//
// Optional POST body: { "days": 7, "dry_run": false, "force_uuids": [] }
//   dry_run     lists misses without replaying or alerting.
//   force_uuids replays those specific Zoom occurrence UUIDs even though
//               public.meetings already knows them. Added 2026-08-20 for rows
//               that carry a uuid (so the normal diff skips them) but whose n8n
//               enrichment never landed — the 401-on-missing-signature class of
//               failure fixed in zoom-webhook v38, which left three Executive
//               Committee rows with a recording_url and nothing else while
//               reading processing_status='completed'. A forced uuid still has
//               to appear in the Zoom listing for the chosen window, so widen
//               `days` to cover it; any that Zoom does not return come back in
//               `force_uuids_not_found` rather than being silently dropped.
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

// ==================== Drive archive backstop ====================
// The CRM plays whatever `meetings.recording_embed_url` holds, in an iframe.
// A zoom.us link there does not play: fetched unauthenticated, an aged share /
// play URL returns Zoom's "Error - Zoom" page, because those links are passcode
// and expiry gated. A Drive `/preview` link returns the file and a video player
// with no framing restriction, which is why every meeting that plays holds one.
//
// Putting the Drive copy there is n8n's job on the live path: workflow
// gthxKZBBsAcnr9aB ("Meeting Minutes - Google Doc & Supabase") carries
// Extract MP4 URL → Fetch MP4 Binary → Upload to Drive and then writes the row.
// This is the backstop for when that does not happen, which is what left eight
// meetings between 2026-01 and 2026-07 pointing at Zoom.
//
// It belongs HERE rather than in zoom-webhook. n8n uploads after a Wait node,
// so an immediate archive from the webhook would win the race and n8n would
// then upload a SECOND copy of every recording — hundreds of megabytes per
// meeting, forever. By the time this daily sweep runs, n8n has either done the
// upload (row holds a Drive link, archive-meeting-recording skips) or it has
// not (row still holds Zoom, and this repairs it). No duplicates either way.
//
// Bounded per run because each copy moves 150-450 MB and this function has its
// own wall clock. A backlog drains over consecutive days.
const ARCHIVE_MAX_PER_RUN = 2;

async function archiveStrandedRecordings(
  supabase: ReturnType<typeof createClient>,
  errors: string[],
): Promise<{ meeting_id: string; title: string; status: number; detail: string }[]> {
  const done: { meeting_id: string; title: string; status: number; detail: string }[] = [];
  const { data, error } = await supabase
    .from('meetings')
    .select('id, meeting_title, meeting_date')
    .not('recording_url', 'is', null)
    .like('recording_url', '%zoom.us%')
    .order('meeting_date', { ascending: false })
    .limit(ARCHIVE_MAX_PER_RUN);
  if (error) {
    errors.push(`drive-archive lookup failed: ${error.message}`);
    return done;
  }
  if (!data || data.length === 0) return done;

  const url = `${Deno.env.get('SUPABASE_URL')}/functions/v1/archive-meeting-recording`;
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
  for (const row of data as any[]) {
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${key}`,
          'apikey': key,
        },
        body: JSON.stringify({ meeting_id: row.id }),
      });
      const text = (await res.text()).slice(0, 300);
      done.push({ meeting_id: row.id, title: row.meeting_title, status: res.status, detail: text });
      if (!res.ok) {
        errors.push(`drive-archive ${row.meeting_title} (${row.id}) → HTTP ${res.status}: ${text}`);
      }
    } catch (e) {
      errors.push(`drive-archive ${row.meeting_title} (${row.id}) threw: ${String(e?.message || e)}`);
    }
  }
  return done;
}

// ==================== stuck-meeting sweep ====================
// The diff above answers "does a row exist for this recording". That question
// read TRUE for the three Executive Committee meetings (2026-07-22, 07-29,
// 08-12) that carried a recording and nothing else for a month, so this function
// reported a clean reconcile every single day while the pipeline was broken.
// Row EXISTENCE is not row COMPLETENESS, and diffing only on existence is the
// third of the three defects that let that hide.
//
// So: a meeting older than the grace period, with no transcript AND no recap
// AND no recorded processing_error, is STUCK. Since 20260821_01 that is exactly
// the set reading processing_status='recorded' or 'received', because the status
// is derived from the row rather than claimed by a writer — but the predicate is
// written out against the underlying columns here on purpose, so this sweep
// does not depend on the trigger being present to be correct.
//
// GRACE PERIOD, chosen deliberately. Enrichment is not instant: n8n waits on
// Zoom's transcript, then generates minutes, then uploads the recording to
// Drive. On the observed live path that lands within roughly an hour of the
// recording completing. Six hours is comfortably past that and still catches a
// failure the same day, before the next meeting.
//
// ALERT ONCE PER STUCK MEETING, NOT ONCE PER SWEEP. This is the project rule
// learned the hard way: judge ENTITIES, not EVENTS. A watchdog that re-reports
// the same meeting every night trains its reader to ignore it and burns quota
// (96 percent of Sentry's, once). meetings.stuck_alerted_at is the latch: set
// on first report, and cleared by the derive trigger the moment the row reaches
// 'completed', so a meeting that is repaired and later regresses can alert
// again. Already-alerted meetings are still returned in the JSON result for
// anyone reading it, they just do not raise a new Telegram message.
const STUCK_GRACE_HOURS = 6;
const STUCK_MAX_REPORTED = 50;

type StuckMeeting = {
  id: string;
  title: string;
  meeting_date: string;
  zoom_meeting_uuid: string | null;
  has_recording: boolean;
  status: string | null;
  already_alerted: boolean;
};

async function sweepStuckMeetings(
  supabase: ReturnType<typeof createClient>,
  errors: string[],
  dryRun: boolean,
): Promise<{ stuck: StuckMeeting[]; newlyStuck: StuckMeeting[] }> {
  const cutoff = new Date(Date.now() - STUCK_GRACE_HOURS * 60 * 60 * 1000).toISOString();
  // Explicit limit: a bare select() silently caps at 1000 rows, and an invisible
  // cap on a growing table is the same class of bug this whole function exists
  // to prevent. 50 stuck meetings at once is already a pipeline-wide outage.
  const { data, error } = await supabase
    .from('meetings')
    .select('id, meeting_title, meeting_date, zoom_meeting_uuid, recording_url, processing_status, stuck_alerted_at')
    .lt('meeting_date', cutoff)
    .is('transcript_file_path', null)
    .is('executive_recap', null)
    .is('processing_error', null)
    .order('meeting_date', { ascending: false })
    .limit(STUCK_MAX_REPORTED);
  if (error) {
    errors.push(`stuck-sweep lookup failed: ${error.message}`);
    return { stuck: [], newlyStuck: [] };
  }

  const stuck: StuckMeeting[] = (data || []).map((r: any) => ({
    id: String(r.id),
    title: r.meeting_title,
    meeting_date: r.meeting_date,
    zoom_meeting_uuid: r.zoom_meeting_uuid ?? null,
    has_recording: r.recording_url != null,
    status: r.processing_status ?? null,
    already_alerted: r.stuck_alerted_at != null,
  }));
  const newlyStuck = stuck.filter((m) => !m.already_alerted);

  // Stamp the latch BEFORE the Telegram send would happen, so a Telegram outage
  // cannot turn one stuck meeting into a nightly repeat. The cost of that
  // ordering is a missed first alert if Telegram is down; the JSON result and
  // the row itself both still carry it, and a repeating alarm is the failure
  // mode that actually destroyed a monitor here.
  if (!dryRun && newlyStuck.length > 0) {
    const now = new Date().toISOString();
    const { error: stampError } = await supabase
      .from('meetings')
      .update({ stuck_alerted_at: now })
      .in('id', newlyStuck.map((m) => m.id));
    if (stampError) errors.push(`stuck-sweep latch update failed: ${stampError.message}`);
  }

  for (const m of newlyStuck) {
    console.log(`[zoom-reconcile] STUCK id=${m.id} uuid=${m.zoom_meeting_uuid} date=${m.meeting_date} status=${m.status} topic=${m.title}`);
  }
  return { stuck, newlyStuck };
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  const startedAt = new Date().toISOString();
  let days = 7;
  let dryRun = false;
  let forceUuids = new Set<string>();
  try {
    const body = await req.json().catch(() => ({}));
    if (Number.isFinite(Number(body?.days)) && Number(body.days) > 0 && Number(body.days) <= 30) {
      days = Math.floor(Number(body.days));
    }
    dryRun = body?.dry_run === true;
    if (Array.isArray(body?.force_uuids)) {
      forceUuids = new Set(body.force_uuids.map((u: unknown) => String(u)).filter((u: string) => u.length > 0));
    }
  } catch (_) { /* defaults */ }

  const errors: string[] = [];
  const replayed: { id: string; topic: string; status?: number; forced?: boolean }[] = [];
  const forcedSeen = new Set<string>();
  let recordings: any[] = [];
  let driveArchived: { meeting_id: string; title: string; status: number; detail: string }[] = [];
  let stuck: StuckMeeting[] = [];
  let newlyStuck: StuckMeeting[] = [];

  // Built OUTSIDE the try on purpose. The stuck sweep below needs only the
  // database, so a Zoom OAuth or listing failure must not blind the
  // completeness check as well as the existence check.
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    { auth: { autoRefreshToken: false, persistSession: false } }
  );

  try {
    const accountId = Deno.env.get('ZOOM_RECORDINGS_ACCOUNT_ID') || Deno.env.get('ZOOM_ACCOUNT_ID') || '';
    const token = await getZoomAccessToken();
    const me = await zoomGet('/v2/users/me', token);
    const to = new Date();
    const from = new Date(to.getTime() - days * 24 * 60 * 60 * 1000);
    const fmt = (d: Date) => d.toISOString().slice(0, 10);
    recordings = await listRecordings(token, me.id, fmt(from), fmt(to));
    console.log(`[zoom-reconcile] zoom reports ${recordings.length} cloud recording(s) ${fmt(from)}..${fmt(to)}`);

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
      const forced = forceUuids.has(uuid);
      if (forced) forcedSeen.add(uuid);
      // A forced uuid overrides the "already known" skip and nothing else. The
      // per-run `seen` dedupe still applies, so one occurrence is replayed once.
      if ((known.has(uuid) && !forced) || seen.has(uuid)) continue;
      seen.add(uuid);
      console.log(`[zoom-reconcile] ${forced ? 'FORCED' : 'MISS'} zoom_meeting_uuid=${uuid} id=${id} topic=${m.topic} start=${m.start_time}`);
      if (dryRun) {
        replayed.push({ id, topic: m.topic, forced });
        continue;
      }
      try {
        const r = await replayToZoomWebhook(m, accountId);
        replayed.push({ id, topic: m.topic, status: r.status, forced });
        if (r.status !== 200) errors.push(`replay ${id} (${m.topic}) → HTTP ${r.status}: ${r.text}`);
      } catch (e) {
        errors.push(`replay ${id} (${m.topic}) threw: ${String(e?.message || e)}`);
      }
    }

    // Backstop: repair any meeting still pointing at a zoom.us recording.
    // Deliberately independent of the replay diff above — the rows this catches
    // are ones Zoom and the CRM both already know about, so the diff skips them.
    if (!dryRun) {
      driveArchived = await archiveStrandedRecordings(supabase, errors);
    }
  } catch (e) {
    errors.push(String(e?.message || e));
  }

  // Runs regardless of whether the Zoom half above succeeded, per the comment on
  // the client construction. A row that is present but empty is invisible to the
  // diff by construction, so this is the only leg that can see it.
  try {
    const swept = await sweepStuckMeetings(supabase, errors, dryRun);
    stuck = swept.stuck;
    newlyStuck = swept.newlyStuck;
  } catch (e) {
    errors.push(`stuck-sweep threw: ${String(e?.message || e)}`);
  }

  // A forced uuid Zoom did not return is a requested replay that did NOT happen.
  // Surface it as an error rather than returning 200 on a silent no-op, which is
  // the exact failure shape this function exists to catch.
  const forceNotFound = [...forceUuids].filter((u) => !forcedSeen.has(u));
  for (const u of forceNotFound) {
    errors.push(`force_uuid ${u} not present in Zoom recordings for the last ${days} day(s) — not replayed`);
  }

  const result = {
    started_at: startedAt,
    window_days: days,
    dry_run: dryRun,
    zoom_recordings_found: recordings.length,
    force_uuids_requested: [...forceUuids],
    force_uuids_not_found: forceNotFound,
    misses_replayed: replayed,
    drive_archived: driveArchived,
    stuck_grace_hours: STUCK_GRACE_HOURS,
    stuck_meetings: stuck,
    stuck_meetings_new: newlyStuck.map((m) => m.id),
    errors
  };
  console.log('[zoom-reconcile] result:', JSON.stringify(result));

  // Telegram ONLY when something happened — silent when fully reconciled.
  // newlyStuck rather than stuck: a meeting already reported stays in the JSON
  // result and out of the alert, which is what makes this a per-entity watchdog
  // instead of a nightly repeat.
  if (!dryRun && (replayed.length > 0 || driveArchived.length > 0 || newlyStuck.length > 0 || errors.length > 0)) {
    const lines = [
      newlyStuck.length > 0
        ? '🛑 Zoom reconcile: meeting stuck without minutes'
        : (replayed.length > 0
          ? '🔁 Zoom reconcile: replayed missing meetings'
          : (driveArchived.length > 0 ? '🎬 Zoom reconcile: archived recordings to Drive' : '⚠️ Zoom reconcile ran with errors')),
      `Window: last ${days} day(s), ${recordings.length} cloud recording(s)`,
      ...newlyStuck.map((m) =>
        `🛑 no transcript and no recap ${STUCK_GRACE_HOURS}h+ after ${String(m.meeting_date).slice(0, 16)}: ${m.title}`
        + ` (status=${m.status}, recording=${m.has_recording ? 'yes' : 'no'}, uuid=${m.zoom_meeting_uuid ?? 'none'})`),
      ...replayed.map((r) => `• ${r.topic} (${r.id}) → ${r.status ?? 'dry-run'}`),
      ...driveArchived.map((d) => `🎬 archived to Drive: ${d.title} → ${d.status}`),
      ...errors.map((e) => `❌ ${e}`)
    ];
    if (stuck.length > newlyStuck.length) {
      lines.push(`(${stuck.length - newlyStuck.length} more still stuck, already reported)`);
    }
    await sendTelegram(lines.join('\n').slice(0, 4000));
  }

  return json(errors.length > 0 ? 500 : 200, result);
});
