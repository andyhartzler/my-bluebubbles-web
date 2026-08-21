// Zoom webhook ingest — always-on relay for the Zoom → CRM meetings pipeline.
//
// Brought into the repo 2026-06-11 (previously deploy-only, v8). v9 rewrite:
//
//   1. MINIMAL-ROW-FIRST: on recording.completed / meeting.ended /
//      meeting.summary_completed we synchronously upsert a skeleton row into
//      public.meetings (processing_status='received') BEFORE any Zoom API call
//      or downstream invocation. ON CONFLICT DO NOTHING + a guarded update so a
//      richer row (status 'processing'/'completed'/'failed') is never clobbered.
//      Guarantees every Zoom event leaves a durable trace even if everything
//      downstream is broken.
//   2. LEG A FIXED: the direct meetings-zap call had silently 401'd since the
//      project's migration to new-format Supabase API keys. meetings-zap's auth
//      gate accepts either (a) x-zoom-request-token containing
//      ZOOM_WEBHOOK_SECRET or (b) a *JWT-shaped* (eyJ...) Bearer token. This
//      function sent `Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}` —
//      but after the key migration that env var holds an `sb_secret_...` key,
//      which is not JWT-shaped, so every call failed the gate with 401
//      "Invalid or missing Zoom webhook secret" and the relay swallowed it.
//      Fix: send x-zoom-request-token: ZOOM_WEBHOOK_SECRET (shared env), which
//      passes gate (a) regardless of API-key format. Leg A is kept (not
//      removed) because it is the backstop that writes recording URLs +
//      attendance when the n8n container is down; n8n's richer write (leg B)
//      still lands afterwards and wins.
//   3. ALERTING: any failure (minimal upsert error, meetings-zap non-2xx,
//      n8n fan-out non-2xx) fires a Telegram alert to Andrew and writes an
//      audit_log row. Alerting failures can never break the 200 to Zoom.
//   4. FAST 200: heavy leg-A work (Zoom token + recordings + participants +
//      meetings-zap) runs via EdgeRuntime.waitUntil after the response; only
//      the minimal upsert is awaited.
//
// Env required (set via `supabase secrets`):
//   ZOOM_CLIENT_ID / ZOOM_CLIENT_SECRET / ZOOM_ACCOUNT_ID   CRM S2S app (meeting mgmt)
//   ZOOM_RECORDINGS_CLIENT_ID / _SECRET / _ACCOUNT_ID       recordings S2S app
//     (the "MOYD Zoom Server-to-Server" app with meeting:read:list_recordings /
//      participant / summary scopes — preferred for recording/participant
//      fetches; falls back to ZOOM_CLIENT_ID app if unset)
//   ZOOM_WEBHOOK_SECRET_TOKEN    Zoom Marketplace webhook secret (CRC + x-zm-signature)
//   ZOOM_WEBHOOK_SECRET          shared secret for meetings-zap's auth gate
//   TELEGRAM_ALERT_BOT_TOKEN / TELEGRAM_ALERT_CHAT_ID       failure alerts
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY                auto-injected
//   MEETINGS_ZAP_URL             optional override of the leg-A target (testing)
//
// Zoom events handled:
//   - endpoint.url_validation   → CRC handshake
//   - recording.completed       → minimal row → [bg] leg A meetings-zap → leg B n8n fan-out
//   - meeting.ended             → minimal row only (no recording yet; n8n has no hook)
//   - meeting.summary_completed → minimal row → [bg] leg A summary → leg B n8n fan-out
//   All other events are 200'd and ignored.
//
// Test affordance: a signed payload may carry `_moyd_synthetic: { skip_n8n: true }`
// to suppress the n8n fan-out (used by synthetic end-to-end tests so fake
// meetings never reach the production n8n workflows). Honored only after
// x-zm-signature verification, so only holders of ZOOM_WEBHOOK_SECRET_TOKEN
// can set it.
import { serve as stdServe } from "https://deno.land/std@0.168.0/http/server.ts";
import { withSentry } from "../_shared/sentry.ts";
// Sentry-wrapped serve: errors + 5xx responses report to supabase-edge project.
const serve = (h: (req: Request) => Promise<Response> | Response) => stdServe(withSentry("zoom-webhook", h));
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const N8N_FORWARD_BASE = 'https://n8n.moydchat.org/webhook/zoom';
// Cloudflare's default WAF blocks Deno's default User-Agent. Identify the fan-out
// traffic clearly so n8n's tunnel accepts it and so operators can audit if needed.
const FANOUT_USER_AGENT = 'MOYD-Zoom-Relay/2.0 (Supabase Edge Function; zoom-webhook)';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-zm-signature, x-zm-request-timestamp',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  });
}

// ==================== crypto ====================
async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), {
    name: 'HMAC',
    hash: 'SHA-256'
  }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

// ==================== supabase service client ====================
let _client: ReturnType<typeof createClient> | null = null;
function getServiceClient() {
  if (!_client) {
    _client = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    );
  }
  return _client;
}

// ==================== background task helper ====================
// Supabase Edge Runtime keeps promises passed to EdgeRuntime.waitUntil alive
// after the response is returned. Falls back to a plain floating promise.
function background(p: Promise<unknown>) {
  const guarded = p.catch((e) => console.error('background task error:', String(e?.message || e)));
  try {
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(guarded);
  } catch (_) { /* best effort */ }
}

// ==================== failure reporting ====================
// Telegram alert + audit_log row. MUST never throw — the webhook's 200 to Zoom
// is sacred. Both sinks are independently try/caught.
async function reportFailure(args: {
  leg: string;            // 'minimal-upsert' | 'leg-A meetings-zap' | 'leg-B n8n fan-out' | ...
  event: string;
  topic?: string;
  zoomMeetingId?: string;
  status?: number | string;
  detail?: string;
}) {
  const { leg, event, topic, zoomMeetingId, status, detail } = args;
  console.error(`[zoom-webhook] FAILURE leg=${leg} event=${event} meeting=${zoomMeetingId} topic=${topic} status=${status} detail=${detail}`);
  // Telegram
  try {
    const token = Deno.env.get('TELEGRAM_ALERT_BOT_TOKEN');
    const chatId = Deno.env.get('TELEGRAM_ALERT_CHAT_ID');
    if (token && chatId) {
      const text = [
        '🚨 Zoom→CRM pipeline failure',
        `Leg: ${leg}`,
        `Event: ${event}`,
        topic ? `Meeting: ${topic}` : null,
        zoomMeetingId ? `Zoom ID: ${zoomMeetingId}` : null,
        status !== undefined ? `Status: ${status}` : null,
        detail ? `Detail: ${String(detail).slice(0, 300)}` : null
      ].filter(Boolean).join('\n');
      const res = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ chat_id: chatId, text })
      });
      if (!res.ok) console.error(`[zoom-webhook] telegram alert non-2xx: ${res.status} ${await res.text()}`);
    } else {
      console.error('[zoom-webhook] TELEGRAM_ALERT_BOT_TOKEN / TELEGRAM_ALERT_CHAT_ID not set — alert not sent');
    }
  } catch (e) {
    console.error('[zoom-webhook] telegram alert failed:', String(e?.message || e));
  }
  // audit_log
  try {
    const { error } = await getServiceClient().from('audit_log').insert({
      action: 'EDGE_FN',
      actor_id: null,
      actor_role: 'service_role',
      schema_name: 'public',
      table_name: 'edge_fn:zoom-webhook',
      row_id: zoomMeetingId ?? null,
      context: {
        event: 'zoom-webhook:failure',
        leg,
        zoom_event: event,
        topic: topic ?? null,
        status: status ?? null,
        detail: detail ? String(detail).slice(0, 500) : null
      }
    });
    if (error) console.error('[zoom-webhook] audit_log insert failed:', error.message);
  } catch (e) {
    console.error('[zoom-webhook] audit_log insert threw:', String(e?.message || e));
  }
}

// ==================== minimal-row-first upsert ====================
// Synchronous skeleton write so the meeting can never be lost. Never clobbers
// a richer row: insert is ON CONFLICT DO NOTHING; the follow-up update only
// touches rows still in processing_status='received'.
//
// DEDUP KEY = the per-occurrence Zoom UUID (zoom_meeting_uuid), NOT the numeric
// meeting id. Recurring meetings (e.g. the monthly Executive Committee Meeting)
// reuse ONE numeric id for every occurrence; only the UUID is unique per
// occurrence. Keying on the numeric id collapsed every occurrence onto the
// first row. recording.completed and meeting.summary_completed for the same
// occurrence carry the same UUID, so they still merge onto one row. The numeric
// zoom_meeting_id is still written for display/back-compat. Fallback to the
// numeric id only if a UUID is somehow absent (never happens for real events).
async function upsertMinimalRow(args: {
  zoomMeetingId: string;
  zoomMeetingUuid?: string;
  topic?: string;
  startTime?: string;
  durationMinutes?: number;
}): Promise<{ ok: boolean; error?: string }> {
  const supabase = getServiceClient();
  const uuidKey = (args.zoomMeetingUuid && args.zoomMeetingUuid.trim())
    ? args.zoomMeetingUuid.trim()
    : args.zoomMeetingId;
  const row = {
    zoom_meeting_id: args.zoomMeetingId,
    zoom_meeting_uuid: uuidKey,
    meeting_title: args.topic || '(untitled Zoom meeting)',
    meeting_date: args.startTime && !isNaN(new Date(args.startTime).getTime())
      ? new Date(args.startTime).toISOString()
      : new Date().toISOString(),
    duration_minutes: Math.round(Number(args.durationMinutes) || 0),
    processing_status: 'received'
  };
  const { data, error } = await supabase
    .from('meetings')
    .upsert(row, { onConflict: 'zoom_meeting_uuid', ignoreDuplicates: true })
    .select('id');
  if (error) return { ok: false, error: error.message };
  if (data && data.length > 0) {
    console.log(`[zoom-webhook] minimal row inserted for zoom_meeting_uuid=${uuidKey} (id=${args.zoomMeetingId})`);
    return { ok: true };
  }
  // Row already existed. Refresh skeleton fields only if it is still a skeleton.
  const { error: updError } = await supabase
    .from('meetings')
    .update({
      meeting_title: row.meeting_title,
      meeting_date: row.meeting_date,
      duration_minutes: row.duration_minutes
    })
    .eq('zoom_meeting_uuid', uuidKey)
    .eq('processing_status', 'received');
  if (updError) return { ok: false, error: updError.message };
  console.log(`[zoom-webhook] minimal row already present for zoom_meeting_uuid=${uuidKey} (left intact)`);
  return { ok: true };
}

// ==================== Zoom API ====================
// Prefer the dedicated recordings app (read scopes proven for list_recordings /
// participants / summaries); fall back to the CRM meeting-management app.
async function getZoomAccessToken(): Promise<string> {
  const clientId = Deno.env.get('ZOOM_RECORDINGS_CLIENT_ID') || Deno.env.get('ZOOM_CLIENT_ID');
  const clientSecret = Deno.env.get('ZOOM_RECORDINGS_CLIENT_SECRET') || Deno.env.get('ZOOM_CLIENT_SECRET');
  const accountId = Deno.env.get('ZOOM_RECORDINGS_ACCOUNT_ID') || Deno.env.get('ZOOM_ACCOUNT_ID');
  if (!clientId || !clientSecret || !accountId) {
    throw new Error('Missing Zoom credentials in env');
  }
  const creds = btoa(`${clientId}:${clientSecret}`);
  const res = await fetch('https://zoom.us/oauth/token', {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${creds}`,
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: `grant_type=account_credentials&account_id=${accountId}`
  });
  if (!res.ok) throw new Error(`Zoom OAuth error: ${res.status} ${await res.text()}`);
  const data = await res.json();
  return data.access_token;
}

async function fetchZoomRecordings(meetingId: string, token: string) {
  const url = `https://api.zoom.us/v2/meetings/${encodeURIComponent(meetingId)}/recordings`;
  const res = await fetch(url, { headers: { 'Authorization': `Bearer ${token}` } });
  if (!res.ok) throw new Error(`Zoom recordings fetch failed: ${res.status} ${await res.text()}`);
  return await res.json();
}

async function fetchZoomParticipants(meetingId: string, token: string) {
  const url = `https://api.zoom.us/v2/report/meetings/${encodeURIComponent(meetingId)}/participants?page_size=300`;
  const res = await fetch(url, { headers: { 'Authorization': `Bearer ${token}` } });
  if (!res.ok) {
    console.error(`participants fetch failed: ${res.status}`);
    return [];
  }
  const data = await res.json();
  return data.participants || [];
}

function pickEmbedUrl(files: any[]) {
  const mp4 = (files || []).find((f) => (f.file_type || '').toUpperCase() === 'MP4');
  return mp4?.play_url || null;
}
function pickThumbnailUrl(files: any[]) {
  const thumb = (files || []).find((f) => (f.file_type || '').toUpperCase() === 'TB' || (f.recording_type || '').includes('thumbnail'));
  return thumb?.download_url || null;
}
function pickDownloadUrl(files: any[]) {
  const mp4 = (files || []).find((f) => (f.file_type || '').toUpperCase() === 'MP4');
  return mp4?.download_url || null;
}

// ==================== leg A: meetings-zap ====================
async function invokeMeetingsZap(payload: Record<string, unknown>): Promise<Response> {
  const url = Deno.env.get('MEETINGS_ZAP_URL') ||
    `${Deno.env.get('SUPABASE_URL')}/functions/v1/meetings-zap`;
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY') || '';
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    // Root-cause fix (2026-06-11): meetings-zap's gate requires either a
    // JWT-shaped Bearer token or x-zoom-request-token containing
    // ZOOM_WEBHOOK_SECRET. SUPABASE_SERVICE_ROLE_KEY is now an sb_secret_*
    // key (not JWT-shaped), so the shared secret header is the reliable gate.
    'Authorization': `Bearer ${key}`,
    'apikey': key
  };
  const zapSecret = Deno.env.get('ZOOM_WEBHOOK_SECRET');
  if (zapSecret) headers['x-zoom-request-token'] = zapSecret;
  return await fetch(url, { method: 'POST', headers, body: JSON.stringify(payload) });
}

// Heavy leg-A work for recording.completed — runs in the background after the
// 200 has been returned to Zoom.
async function runLegARecording(obj: any, meetingId: string, meetingUuid: string, event: string) {
  const topic = obj.topic || '';
  try {
    let recordings: any = { recording_files: obj.recording_files || [] };
    let participants: any[] = [];
    try {
      const token = await getZoomAccessToken();
      try {
        recordings = await fetchZoomRecordings(meetingId, token);
      } catch (e) {
        console.error('[zoom-webhook] recordings fetch failed, using webhook payload files:', String(e?.message || e));
      }
      participants = await fetchZoomParticipants(meetingId, token);
    } catch (e) {
      // Token mint failed — proceed with what the webhook payload carried.
      console.error('[zoom-webhook] zoom token mint failed for leg A:', String(e?.message || e));
    }
    const files = recordings.recording_files || [];
    const zapPayload = {
      meeting_id: meetingId,
      meeting_uuid: meetingUuid || obj.uuid || '',
      meeting_topic: topic || recordings.topic,
      meeting_host: obj.host_email || recordings.host_email || '',
      start_time: obj.start_time || recordings.start_time,
      duration: obj.duration || recordings.duration,
      recording_url: recordings.share_url || obj.share_url || null,
      recording_embed_url: pickEmbedUrl(files) || pickDownloadUrl(files),
      recording_thumbnail_url: pickThumbnailUrl(files),
      participants,
      _source: 'zoom-webhook edge function'
    };
    const zap = await invokeMeetingsZap(zapPayload);
    const text = await zap.text();
    console.log(`meetings-zap response: ${zap.status} ${text.slice(0, 300)}`);
    if (!zap.ok) {
      await reportFailure({
        leg: 'leg-A meetings-zap', event, topic, zoomMeetingId: meetingId,
        status: zap.status, detail: text.slice(0, 300)
      });
    }
  } catch (e) {
    await reportFailure({
      leg: 'leg-A meetings-zap', event, topic, zoomMeetingId: meetingId,
      status: 'exception', detail: String(e?.message || e)
    });
  }
}

// Leg-A work for meeting.summary_completed.
async function runLegASummary(obj: any, meetingId: string, meetingUuid: string, event: string) {
  const topic = obj.meeting_topic || obj.topic || '';
  try {
    const zapPayload = {
      meeting_id: meetingId,
      meeting_uuid: meetingUuid || obj.meeting_uuid || '',
      meeting_topic: topic,
      meeting_host: obj.meeting_host_email || '',
      start_time: obj.meeting_start_time || obj.start_time,
      duration: obj.duration || 0,
      executive_recap: obj.summary_overview || null,
      action_items: (obj.next_steps || []).join('\n') || null,
      discussion_highlights: JSON.stringify(obj.summary_details || []),
      _source: 'zoom-webhook edge function (summary)'
    };
    const zap = await invokeMeetingsZap(zapPayload);
    const text = await zap.text();
    console.log(`meetings-zap (summary) response: ${zap.status} ${text.slice(0, 300)}`);
    if (!zap.ok) {
      await reportFailure({
        leg: 'leg-A meetings-zap (summary)', event, topic, zoomMeetingId: meetingId,
        status: zap.status, detail: text.slice(0, 300)
      });
    }
  } catch (e) {
    await reportFailure({
      leg: 'leg-A meetings-zap (summary)', event, topic, zoomMeetingId: meetingId,
      status: 'exception', detail: String(e?.message || e)
    });
  }
}

// ==================== leg B: n8n fan-out ====================
// Fire-and-forget forward of the original Zoom event to n8n. We POST the raw
// body so n8n's existing "Zoom New Recording" / summary Code nodes see exactly
// what Zoom would have sent. Non-2xx or network failure → alert (the n8n
// pipeline does the enrichment: Google Doc, minutes, Notion, attendance).
// THE SIGNATURE HEADERS MUST BE FORWARDED. This is what broke the pipeline.
//
// Both n8n workflows verify the Zoom signature themselves and answer
// `401 missing Zoom signature` without them. This function used to send only
// Content-Type and User-Agent, so every fan-out was refused, and because the fan
// out is fire-and-forget the relay still answered Zoom 200 and still wrote the
// minimal row. The result was a meetings row with a recording and nothing else:
// no transcript, no minutes, no recap, and processing_status reading 'completed'.
// Three executive meetings landed that way (2026-07-22, 07-29, 08-12).
//
// Forwarding the ORIGINAL headers is correct rather than re-signing. The signature
// is an HMAC over `v0:{timestamp}:{rawBody}` with ZOOM_WEBHOOK_SECRET_TOKEN, and
// this function forwards that same rawBody byte for byte, so the original pair
// still verifies downstream. It also keeps one signer: zoom-reconcile already
// signs its replays with the same secret, so replayed events carry a valid pair
// too and take the identical path as organic ones.
//
// Verified against the running n8n before and after: an unsigned POST to
// /webhook/zoom/recording-completed answers 401 missing Zoom signature, which is
// exactly what the relay was sending.
function forwardToN8n(
  event: string,
  rawBody: string,
  zoomSignature: string,
  zoomTimestamp: string,
  topic?: string,
  zoomMeetingId?: string,
) {
  const path = event === 'meeting.summary_completed' ? 'meeting-summary' : 'recording-completed';
  const url = `${N8N_FORWARD_BASE}/${path}`;
  background(fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': FANOUT_USER_AGENT,
      'x-zm-signature': zoomSignature,
      'x-zm-request-timestamp': zoomTimestamp
    },
    body: rawBody
  }).then(async (r) => {
    console.log(`n8n fan-out ${event} → ${url} → ${r.status}`);
    if (!r.ok) {
      await reportFailure({
        leg: 'leg-B n8n fan-out', event, topic, zoomMeetingId,
        status: r.status, detail: (await r.text()).slice(0, 300)
      });
    }
  }).catch(async (e) => {
    await reportFailure({
      leg: 'leg-B n8n fan-out', event, topic, zoomMeetingId,
      status: 'exception', detail: String(e?.message || e)
    });
  }));
}

// ==================== main handler ====================
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  const secretToken = Deno.env.get('ZOOM_WEBHOOK_SECRET_TOKEN') || '';
  let body: any = null;
  const rawBody = await req.text();
  try {
    body = rawBody ? JSON.parse(rawBody) : {};
  } catch (e) {
    return json(400, { error: 'Invalid JSON body', detail: String(e) });
  }

  // 1. CRC handshake — Zoom sends this when the subscription URL is set/verified.
  if (body?.event === 'endpoint.url_validation') {
    const plainToken = body?.payload?.plainToken || '';
    if (!secretToken) {
      return json(200, { plainToken, encryptedToken: null, warn: 'ZOOM_WEBHOOK_SECRET_TOKEN not set' });
    }
    const encryptedToken = await hmacSha256Hex(secretToken, plainToken);
    return json(200, { plainToken, encryptedToken });
  }

  // 2. Signature verification (Zoom signs every request). Skip if no secret configured.
  //
  // Read OUTSIDE the `if (secretToken)` block on purpose. The n8n fan-out below
  // forwards this pair verbatim, and its call sites are outside this block, so
  // declaring them inside it puts them out of scope there and every event throws
  // a ReferenceError before the fan-out can run.
  const ts = req.headers.get('x-zm-request-timestamp') || '';
  const sig = req.headers.get('x-zm-signature') || '';
  if (secretToken) {
    const message = `v0:${ts}:${rawBody}`;
    const computed = `v0=${await hmacSha256Hex(secretToken, message)}`;
    if (!sig || sig !== computed) {
      console.warn(`signature mismatch: got=${sig} expected=${computed}`);
      return json(401, { error: 'Invalid signature' });
    }
  }

  const event = body?.event || 'unknown';
  // Only trusted (signature-verified) callers can set this; used by synthetic
  // tests + reconciliation tooling to keep fake events away from production n8n.
  const skipN8n = body?._moyd_synthetic?.skip_n8n === true;
  console.log(`zoom webhook event=${event}${skipN8n ? ' (synthetic, n8n fan-out suppressed)' : ''}`);

  try {
    if (event === 'recording.completed' || event === 'meeting.ended') {
      const obj = body?.payload?.object || {};
      const meetingId = String(obj.id || '');
      if (!meetingId) throw new Error('payload.object.id missing');
      // Per-occurrence key. Zoom sends a unique `uuid` per occurrence even when
      // recurring meetings share one numeric id — this is the real dedup key.
      const meetingUuid = String(obj.uuid || '');
      const topic = obj.topic || '';

      // STEP 1 — minimal row, synchronous, before anything else can fail.
      const minimal = await upsertMinimalRow({
        zoomMeetingId: meetingId,
        zoomMeetingUuid: meetingUuid,
        topic,
        startTime: obj.start_time,
        durationMinutes: obj.duration
      });
      if (!minimal.ok) {
        await reportFailure({
          leg: 'minimal-upsert', event, topic, zoomMeetingId: meetingId,
          status: 'db-error', detail: minimal.error
        });
      }

      // meeting.ended carries no recording; the skeleton row is the whole job.
      if (event === 'meeting.ended') {
        return json(200, { received: event, meeting_id: meetingId, minimal_row: minimal.ok });
      }

      // STEP 2 — leg A (background): full payload → meetings-zap (backstop for n8n).
      background(runLegARecording(obj, meetingId, meetingUuid, event));

      // STEP 3 — leg B: fan out original event to n8n for enrichment.
      if (!skipN8n) forwardToN8n(event, rawBody, sig, ts, topic, meetingId);

      return json(200, {
        received: event,
        meeting_id: meetingId,
        minimal_row: minimal.ok,
        leg_a: 'queued',
        n8n_fanout: skipN8n ? 'suppressed' : 'queued'
      });
    }

    if (event === 'meeting.summary_completed') {
      const obj = body?.payload?.object || {};
      const meetingId = String(obj.meeting_id || '');
      // Summary events key the occurrence on meeting_uuid (same instance UUID
      // as the recording.completed event, so both merge onto one row).
      const meetingUuid = String(obj.meeting_uuid || '');
      const topic = obj.meeting_topic || obj.topic || '';

      if (meetingId) {
        const minimal = await upsertMinimalRow({
          zoomMeetingId: meetingId,
          zoomMeetingUuid: meetingUuid,
          topic,
          startTime: obj.meeting_start_time || obj.start_time,
          durationMinutes: obj.duration
        });
        if (!minimal.ok) {
          await reportFailure({
            leg: 'minimal-upsert', event, topic, zoomMeetingId: meetingId,
            status: 'db-error', detail: minimal.error
          });
        }
        background(runLegASummary(obj, meetingId, meetingUuid, event));
      }
      if (!skipN8n) forwardToN8n(event, rawBody, sig, ts, topic, meetingId);

      return json(200, {
        received: event,
        meeting_id: meetingId,
        leg_a: meetingId ? 'queued' : 'skipped (no meeting_id)',
        n8n_fanout: skipN8n ? 'suppressed' : 'queued'
      });
    }

    return json(200, { received: event, handled: false });
  } catch (error) {
    console.error(`zoom-webhook error handling ${event}:`, error);
    await reportFailure({
      leg: 'handler', event,
      zoomMeetingId: String(body?.payload?.object?.id || body?.payload?.object?.meeting_id || ''),
      topic: body?.payload?.object?.topic || body?.payload?.object?.meeting_topic || '',
      status: 'exception', detail: String(error?.message || error)
    });
    // Always 200 to Zoom — we never want Zoom to mark the endpoint unhealthy.
    return json(200, { received: event, error: String(error?.message || error) });
  }
});
