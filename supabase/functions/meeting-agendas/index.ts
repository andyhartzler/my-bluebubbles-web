// meeting-agendas
//
// Lists the meeting agendas kept in Google Drive, and returns one agenda's
// text, for the Meetings page.
//
// WHY LIVE FROM DRIVE, with no table
// Agendas are written and edited in Google Docs, before and sometimes during
// the meeting. A copy in Postgres would need a sync job and would go stale the
// moment someone edits the doc. Reading Drive on demand keeps Drive the only
// source of truth, and the page is opened rarely enough that the cost is
// nothing.
//
// WHICH DOCS
// Google Docs whose title contains "Agenda" and a date ("Executive Committee
// Agenda 09/01/26", "Agenda - All-Member Meeting 10/22"), created on or after
// AGENDA_CUTOFF. The date in the title is the meeting date. A doc without a
// date in its title is not listed and cannot be read through this function:
// that keeps unrelated docs that happen to say "agenda" (convention packets,
// brainstorms) out of the CRM.
//
// ACCESS
// Staff only, same gate as the meetings table (is_staff()). Drive is read as
// Andrew through the service account's domain-wide delegation, the same
// identity archive-meeting-recording uses. GET requests only. Nothing here
// changes any file or its sharing.
//
// Body: { action: "list" }                    -> { agendas: Agenda[] }
//       { action: "content", file_id: "..." } -> { file_id, text }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getGoogleAccessToken } from "../_shared/google-auth.ts";

const DRIVE_SUBJECT = "andrew@moyoungdemocrats.org";
// The full drive scope, because that is the scope domain-wide delegation
// grants this service account (archive-meeting-recording requests the same
// string). A narrower scope that is not on the delegation list is refused at
// the token exchange. This function only ever issues GETs.
const DRIVE_SCOPE = "https://www.googleapis.com/auth/drive";
const DRIVE_API = "https://www.googleapis.com/drive/v3";
const DOC_MIME = "application/vnd.google-apps.document";
// The CRM's meeting records start in June 2025. Older agendas belong to
// earlier boards and earlier accounts.
const AGENDA_CUTOFF = "2025-06-01T00:00:00Z";
const MAX_TEXT_BYTES = 200_000;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

interface DriveFile {
  id: string;
  name: string;
  mimeType: string;
  createdTime: string;
  modifiedTime: string;
  webViewLink?: string;
  trashed?: boolean;
}

export interface Agenda {
  file_id: string;
  title: string;
  meeting_date: string; // YYYY-MM-DD, the date written in the title
  kind: "executive" | "all_member" | "other";
  url: string;
  modified_time: string;
}

async function requireStaff(req: Request): Promise<Response | null> {
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer /i, "").trim();
  if (!jwt) return json({ error: "Missing Authorization header" }, 401);
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: `Bearer ${jwt}` } } },
  );
  const { data: userData, error: authErr } = await userClient.auth.getUser(jwt);
  if (authErr || !userData?.user) return json({ error: "Invalid or expired JWT" }, 401);
  const { data: staff, error: staffErr } = await userClient.rpc("is_staff");
  if (staffErr || staff !== true) return json({ error: "Forbidden: staff access required" }, 403);
  return null;
}

const pad = (n: number) => String(n).padStart(2, "0");

// The LAST date-shaped run in the title is the meeting date. Accepts
// 09/01/26, 9/1/2026, 01-14-26 and a bare 10/22 (year from the doc's
// creation, rolled forward when the doc was written ahead of a January
// meeting). Exported for the test.
export function meetingDateFromTitle(title: string, createdTime: string): string | null {
  const matches = [...title.matchAll(/(?<!\d)(\d{1,2})[\/\-.](\d{1,2})(?:[\/\-.](\d{2}|\d{4}))?(?!\d)/g)];
  const m = matches.at(-1);
  if (!m) return null;
  const month = Number(m[1]);
  const day = Number(m[2]);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  const created = new Date(createdTime);
  let year: number;
  if (m[3]) {
    year = Number(m[3]);
    if (year < 100) year += 2000;
  } else {
    year = created.getUTCFullYear();
    const guess = Date.UTC(year, month - 1, day);
    if (created.getTime() - guess > 180 * 24 * 3600 * 1000) year += 1;
  }
  const check = new Date(Date.UTC(year, month - 1, day));
  if (check.getUTCMonth() !== month - 1) return null; // 02/31 and the like
  return `${year}-${pad(month)}-${pad(day)}`;
}

export function agendaKind(title: string): Agenda["kind"] {
  if (/exec/i.test(title)) return "executive";
  if (/all[\s_-]*members?/i.test(title)) return "all_member";
  return "other";
}

function toAgenda(f: DriveFile): Agenda | null {
  if (f.mimeType !== DOC_MIME || f.trashed) return null;
  if (!/agenda/i.test(f.name)) return null;
  if (new Date(f.createdTime).getTime() < new Date(AGENDA_CUTOFF).getTime()) return null;
  const date = meetingDateFromTitle(f.name, f.createdTime);
  if (!date) return null;
  return {
    file_id: f.id,
    title: f.name.trim(),
    meeting_date: date,
    kind: agendaKind(f.name),
    url: f.webViewLink ?? `https://docs.google.com/document/d/${f.id}/edit`,
    modified_time: f.modifiedTime,
  };
}

async function driveGet(path: string, params: Record<string, string>, token: string): Promise<Response> {
  const url = `${DRIVE_API}${path}?${new URLSearchParams(params)}`;
  return await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
}

async function listAgendas(token: string): Promise<Agenda[]> {
  const q = `name contains 'Agenda' and mimeType = '${DOC_MIME}' and trashed = false and createdTime >= '${AGENDA_CUTOFF}'`;
  const files: DriveFile[] = [];
  let pageToken = "";
  do {
    const res = await driveGet("/files", {
      q,
      corpora: "allDrives",
      includeItemsFromAllDrives: "true",
      supportsAllDrives: "true",
      pageSize: "200",
      fields: "nextPageToken, files(id, name, mimeType, createdTime, modifiedTime, webViewLink, trashed)",
      ...(pageToken ? { pageToken } : {}),
    }, token);
    if (!res.ok) throw new Error(`Drive list ${res.status}: ${(await res.text()).slice(0, 300)}`);
    const page = await res.json();
    files.push(...(page.files ?? []));
    pageToken = page.nextPageToken ?? "";
  } while (pageToken);

  return files
    .map(toAgenda)
    .filter((a): a is Agenda => a !== null)
    .sort((a, b) => b.meeting_date.localeCompare(a.meeting_date));
}

async function agendaText(fileId: string, token: string): Promise<Response> {
  // Re-check the file against the list rules before exporting it, so a caller
  // cannot read an arbitrary doc by passing its id.
  const meta = await driveGet(`/files/${encodeURIComponent(fileId)}`, {
    supportsAllDrives: "true",
    fields: "id, name, mimeType, createdTime, modifiedTime, webViewLink, trashed",
  }, token);
  if (meta.status === 404) return json({ error: "agenda not found" }, 404);
  if (!meta.ok) throw new Error(`Drive get ${meta.status}: ${(await meta.text()).slice(0, 300)}`);
  const file: DriveFile = await meta.json();
  if (!toAgenda(file)) return json({ error: "not an agenda" }, 404);

  const res = await driveGet(`/files/${encodeURIComponent(fileId)}/export`, { mimeType: "text/plain" }, token);
  if (!res.ok) throw new Error(`Drive export ${res.status}: ${(await res.text()).slice(0, 300)}`);
  let text = (await res.text()).replace(/^﻿/, "").replace(/\r\n/g, "\n").trim();
  if (text.length > MAX_TEXT_BYTES) text = text.slice(0, MAX_TEXT_BYTES);
  return json({ file_id: file.id, text });
}

if (import.meta.main) {
  Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
    if (req.method !== "POST") return json({ error: "POST only" }, 405);

    const denied = await requireStaff(req);
    if (denied) return denied;

    try {
      const body = await req.json().catch(() => ({}));
      const token = await getGoogleAccessToken({ subject: DRIVE_SUBJECT, scopes: [DRIVE_SCOPE] });
      if (body.action === "list") {
        return json({ agendas: await listAgendas(token) });
      }
      if (body.action === "content") {
        const fileId = typeof body.file_id === "string" ? body.file_id.trim() : "";
        if (!/^[A-Za-z0-9_-]{10,}$/.test(fileId)) return json({ error: "file_id is required" }, 400);
        return await agendaText(fileId, token);
      }
      return json({ error: 'action must be "list" or "content"' }, 400);
    } catch (e) {
      const msg = String((e as Error)?.message || e);
      console.error("[meeting-agendas]", msg);
      return json({ error: msg }, 500);
    }
  });
}
