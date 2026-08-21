// archive-meeting-recording
//
// Copies a Zoom cloud recording MP4 into the MOYD shared Drive and points the
// CRM's meetings row at the Drive copy.
//
// WHY THIS EXISTS
// The CRM plays whatever `meetings.recording_embed_url` holds, in an iframe.
// Until 2026-06 the Zapier zap "Meeting Minutes - Google Doc & Supabase"
// downloaded the Zoom MP4 and uploaded it to the shared drive (its step 10),
// and the row ended up holding a drive.google.com link. Since that zap was
// retired the row has held the raw zoom.us share/play URL, which zoom.us
// refuses to be framed in and which is passcode- and expiry-gated, so recent
// meetings do not play. Restoring the Drive copy is the fix.
//
// WHY A SEPARATE FUNCTION rather than a branch inside meetings-zap
// Moving 200-300 MB is slow and can fail. meetings-zap produces the minutes,
// the recap and the attendance, and none of that may be held hostage to a
// large file transfer. A failed archive here loses the video copy and nothing
// else. It is also re-runnable by meeting id, which is what makes backfill and
// retry one call rather than a script.
//
// IDEMPOTENT: a row whose recording_url is already a drive.google.com link is
// left alone unless `force` is set.
//
// Auth: service-role bearer (verify_jwt stays on). zoom-webhook calls it with
// the service key, exactly as it calls meetings-zap.
//
// Body: { meeting_id?: uuid, zoom_uuid?: string, zoom_meeting_id?: string,
//         force?: boolean }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Shared drive + folder the Zapier step wrote to. Same destination.
// Shared drive that FOLDER_ID lives in, recorded for the next reader; the
// upload itself addresses the folder and does not send this.
const DRIVE_ID = "0APy6MYyQuhruUk9PVA";
void DRIVE_ID;
const FOLDER_ID = '1uVuJacybJuPB31Idcf5F6YSRZMjnx7Ff';

// Domain-wide-delegation subject. The service account has no Drive of its own;
// it acts as Andrew, who is an organizer on the shared drive.
const DRIVE_SUBJECT = 'andrew@moyoungdemocrats.org';
const DRIVE_SCOPE = 'https://www.googleapis.com/auth/drive';

// Google requires resumable chunks to be a multiple of 256 KiB. 32 MiB keeps
// the request count low without approaching the function's memory ceiling.
const CHUNK = 32 * 1024 * 1024;

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// ==================== Zoom ====================

async function zoomToken(): Promise<string> {
  const clientId = Deno.env.get('ZOOM_RECORDINGS_CLIENT_ID') || Deno.env.get('ZOOM_CLIENT_ID');
  const clientSecret = Deno.env.get('ZOOM_RECORDINGS_CLIENT_SECRET') || Deno.env.get('ZOOM_CLIENT_SECRET');
  const accountId = Deno.env.get('ZOOM_RECORDINGS_ACCOUNT_ID') || Deno.env.get('ZOOM_ACCOUNT_ID');
  if (!clientId || !clientSecret || !accountId) throw new Error('Missing Zoom credentials in env');
  const res = await fetch('https://zoom.us/oauth/token', {
    method: 'POST',
    headers: {
      Authorization: `Basic ${btoa(`${clientId}:${clientSecret}`)}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: `grant_type=account_credentials&account_id=${accountId}`,
  });
  if (!res.ok) throw new Error(`Zoom OAuth ${res.status}: ${await res.text()}`);
  return (await res.json()).access_token;
}

// A meeting UUID may contain '/' or '=' and Zoom's gateway decodes once before
// routing, so a UUID must be percent-encoded TWICE. Numeric meeting ids are
// unaffected by the double encode, but a numeric id addresses the LATEST
// occurrence of a recurring meeting, which is why the caller should pass the
// UUID whenever it has one.
function zoomKey(idOrUuid: string): string {
  return encodeURIComponent(encodeURIComponent(idOrUuid));
}

async function zoomRecordings(idOrUuid: string, token: string): Promise<any> {
  const res = await fetch(
    `https://api.zoom.us/v2/meetings/${zoomKey(idOrUuid)}/recordings`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  if (!res.ok) throw new Error(`Zoom recordings ${res.status}: ${(await res.text()).slice(0, 300)}`);
  return await res.json();
}

// Prefer the gallery-view render: it is the one with faces in it and the one a
// person opening the archive expects. Speaker view is the fallback, then any
// MP4 at all.
function pickVideo(files: any[]): any | null {
  const mp4s = (files || []).filter((f) => String(f.file_type || '').toUpperCase() === 'MP4');
  if (mp4s.length === 0) return null;
  const byType = (t: string) => mp4s.find((f) => String(f.recording_type || '') === t);
  return byType('shared_screen_with_gallery_view') ||
    byType('shared_screen_with_speaker_view') ||
    byType('active_speaker') ||
    mp4s[0];
}

// ==================== Google ====================

function b64url(s: string): string {
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function driveToken(): Promise<string> {
  const raw = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON');
  if (!raw) throw new Error('GOOGLE_SERVICE_ACCOUNT_JSON is not set');
  const sa = JSON.parse(raw);
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT', kid: sa.private_key_id }));
  const claim = b64url(JSON.stringify({
    iss: sa.client_email,
    sub: DRIVE_SUBJECT,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: DRIVE_SCOPE,
  }));
  const der = String(sa.private_key)
    .replace(/-----BEGIN [^-]+-----/, '')
    .replace(/-----END [^-]+-----/, '')
    .replace(/\s+/g, '');
  const key = await crypto.subtle.importKey(
    'pkcs8',
    Uint8Array.from(atob(der), (c) => c.charCodeAt(0)),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signingInput = `${header}.${claim}`;
  const sigBuf = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    key,
    new TextEncoder().encode(signingInput),
  );
  let bin = '';
  const bytes = new Uint8Array(sigBuf);
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  const jwt = `${signingInput}.${b64url(bin)}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`Google token ${res.status}: ${await res.text()}`);
  return (await res.json()).access_token;
}

// Streams a Zoom MP4 straight into Drive without ever holding the whole file:
// one 32 MiB window at a time, uploaded with Content-Range.
async function uploadToDrive(
  body: ReadableStream<Uint8Array>,
  name: string,
  token: string,
): Promise<{ id: string; size: number }> {
  const init = await fetch(
    'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&supportsAllDrives=true',
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': 'video/mp4',
      },
      // `parents` plus supportsAllDrives is all a shared drive needs. driveId
      // is output-only on files.create and sending it is rejected.
      body: JSON.stringify({
        name,
        parents: [FOLDER_ID],
        mimeType: 'video/mp4',
      }),
    },
  );
  if (!init.ok) throw new Error(`Drive resumable init ${init.status}: ${(await init.text()).slice(0, 300)}`);
  const session = init.headers.get('location');
  if (!session) throw new Error('Drive resumable init returned no Location');

  const reader = body.getReader();
  const buf = new Uint8Array(CHUNK);
  let leftover: Uint8Array | null = null;
  let offset = 0;
  let fileId = '';

  for (;;) {
    let filled = 0;
    let streamDone = false;

    if (leftover) {
      const take = Math.min(leftover.length, CHUNK);
      buf.set(leftover.subarray(0, take), 0);
      filled = take;
      leftover = leftover.length > take ? leftover.subarray(take) : null;
    }
    while (filled < CHUNK && !leftover) {
      const { value, done } = await reader.read();
      if (done) { streamDone = true; break; }
      if (!value || value.length === 0) continue;
      const space = CHUNK - filled;
      if (value.length <= space) {
        buf.set(value, filled);
        filled += value.length;
      } else {
        buf.set(value.subarray(0, space), filled);
        filled = CHUNK;
        leftover = value.subarray(space);
      }
    }

    const isLast = streamDone;
    if (filled === 0 && !isLast) continue;
    if (filled === 0 && isLast && offset === 0) throw new Error('Zoom returned an empty body');

    const total = isLast ? String(offset + filled) : '*';
    const range = filled === 0
      // Zero-length final chunk: the file size is already known and confirmed.
      ? `bytes */${offset}`
      : `bytes ${offset}-${offset + filled - 1}/${total}`;

    const put = await fetch(session, {
      method: 'PUT',
      headers: { 'Content-Range': range },
      body: filled === 0 ? undefined : buf.subarray(0, filled),
    });

    if (put.status === 308) {
      // Resume Incomplete: Google has the bytes so far, keep going.
      offset += filled;
      if (isLast) throw new Error('Drive reported 308 on the final chunk');
      continue;
    }
    if (put.status === 200 || put.status === 201) {
      const meta = await put.json();
      fileId = meta.id;
      offset += filled;
      break;
    }
    throw new Error(`Drive chunk PUT ${put.status} at ${range}: ${(await put.text()).slice(0, 300)}`);
  }

  if (!fileId) throw new Error('Drive upload finished without a file id');
  return { id: fileId, size: offset };
}

// ==================== naming ====================

// "{topic} {date}". The date is rendered in America/Chicago because that is the
// evening the meeting actually happened and the day the CRM shows: an 01:00 UTC
// start is the previous evening in Missouri.
function fileName(topic: string, startTime: string | null): string {
  const clean = (topic || 'Meeting').replace(/[\\/]+/g, '-').trim();
  const d = startTime ? new Date(startTime) : new Date();
  const date = Number.isNaN(d.getTime())
    ? ''
    : new Intl.DateTimeFormat('en-CA', {
      timeZone: 'America/Chicago',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(d);
  return date ? `${clean} ${date}.mp4` : `${clean}.mp4`;
}

// ==================== handler ====================

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...cors, 'Content-Type': 'application/json' },
    });

  try {
    const input = await req.json().catch(() => ({}));
    const { meeting_id, zoom_uuid, zoom_meeting_id, force } = input as Record<string, unknown>;

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    let query = supabase
      .from('meetings')
      .select('id, meeting_title, meeting_date, zoom_meeting_id, zoom_meeting_uuid, recording_url')
      .limit(1);
    if (meeting_id) query = query.eq('id', meeting_id);
    else if (zoom_uuid) query = query.eq('zoom_meeting_uuid', zoom_uuid);
    else if (zoom_meeting_id) {
      query = query.eq('zoom_meeting_id', String(zoom_meeting_id))
        .order('meeting_date', { ascending: false });
    } else return json({ error: 'one of meeting_id, zoom_uuid, zoom_meeting_id is required' }, 400);

    const { data: rows, error: selErr } = await query;
    if (selErr) return json({ error: `meetings lookup failed: ${selErr.message}` }, 500);
    const meeting = rows?.[0];
    if (!meeting) return json({ error: 'meeting not found' }, 404);

    if (!force && String(meeting.recording_url || '').includes('drive.google.com')) {
      return json({ ok: true, skipped: 'already archived', meeting_id: meeting.id });
    }

    // Address the OCCURRENCE by UUID when we have one. A numeric id resolves to
    // the newest occurrence of a recurring meeting, which for the Executive
    // Committee series is almost never the row being archived.
    const key = String(meeting.zoom_meeting_uuid || zoom_uuid || meeting.zoom_meeting_id || zoom_meeting_id || '');
    if (!key) return json({ error: 'row carries no zoom uuid or meeting id' }, 422);

    const zTok = await zoomToken();
    const rec = await zoomRecordings(key, zTok);
    const video = pickVideo(rec.recording_files || []);
    if (!video?.download_url) {
      return json({
        error: 'no MP4 in this Zoom recording',
        meeting_id: meeting.id,
        file_types: (rec.recording_files || []).map((f: any) => f.file_type),
      }, 422);
    }

    // Zoom accepts the OAuth token as a query parameter on a download URL, and
    // that survives the redirect to the CDN host. An Authorization header does
    // not: fetch drops it when the redirect crosses origins.
    const dl = await fetch(`${video.download_url}?access_token=${encodeURIComponent(zTok)}`);
    if (!dl.ok || !dl.body) {
      throw new Error(`Zoom download ${dl.status}: ${(await dl.text()).slice(0, 200)}`);
    }

    const name = fileName(meeting.meeting_title || rec.topic || '', rec.start_time || meeting.meeting_date);
    const gTok = await driveToken();
    const uploaded = await uploadToDrive(dl.body, name, gTok);

    const viewUrl = `https://drive.google.com/file/d/${uploaded.id}/view?usp=drivesdk`;
    const previewUrl = `https://drive.google.com/file/d/${uploaded.id}/preview`;

    const { error: updErr } = await supabase
      .from('meetings')
      .update({ recording_url: viewUrl, recording_embed_url: previewUrl })
      .eq('id', meeting.id);
    if (updErr) {
      return json({
        error: `uploaded but row update failed: ${updErr.message}`,
        drive_file_id: uploaded.id,
      }, 500);
    }

    return json({
      ok: true,
      meeting_id: meeting.id,
      drive_file_id: uploaded.id,
      drive_file_name: name,
      bytes: uploaded.size,
      zoom_recording_type: video.recording_type,
      recording_url: viewUrl,
      recording_embed_url: previewUrl,
    });
  } catch (e) {
    console.error('[archive-meeting-recording]', String((e as Error)?.message || e));
    return json({ error: String((e as Error)?.message || e) }, 500);
  }
});
