// ============================================================================
// Google Group membership sync (Admin SDK Directory API).
//
// Replaces the 8 legacy Zapier "<Committee>: Slack Channel to Google Groups"
// zaps. When someone is in a committee's Slack channel they belong in that
// committee's Google Group email list; when they leave, they are removed.
//
// Auth: reuses _shared/google-auth.ts (service-account JWT + domain-wide
// delegation) impersonating a Workspace admin. Scope:
//   https://www.googleapis.com/auth/admin.directory.group.member
// Verified authorized for client-id 114261141581576499255 (subject andrew@)
// on 2026-07-14 via a live add/remove round-trip.
//
// Idempotent by design:
//   add    -> 200/201 created, 409 "already a member" both => ok
//   remove -> 204 removed, 404 "not a member" both => ok
// The memberKey (email) MUST be URL-encoded in the path.
//
// SOURCE OF TRUTH for the channel->group map: the 8 zaps in
// /Users/moyd/Desktop/MOYD/zapfile.json (cross-checked against spec §7). This
// constant is authoritative in code; public.slack_channel_committee_mapping
// .google_group_email mirrors it for auditability.
// ============================================================================
import { getGoogleAccessToken } from "./google-auth.ts";

export const GROUP_MEMBER_SCOPE =
  "https://www.googleapis.com/auth/admin.directory.group.member";

// Workspace admin the SA impersonates for Directory writes.
const DIRECTORY_SUBJECT =
  Deno.env.get("GOOGLE_DWD_SUBJECT") || "andrew@moyoungdemocrats.org";

// Authoritative Slack channel id -> Google Group email (8 entries, from the zaps).
export const CHANNEL_TO_GROUP: Record<string, string> = {
  "C0927V0858T": "members@moyoungdemocrats.org",            // #general
  "C093HE643J7": "collegedems@moyoungdemocrats.org",        // #college-democrats
  "C093K8GTVP0": "highschool@moyoungdemocrats.org",         // #high-school-democrats
  "C093K895RTQ": "political-affairs@moyoungdemocrats.org",  // Political Affairs Committee
  "C094CGNE56C": "policy@moyoungdemocrats.org",             // Policy & Advocacy Committee
  "C093AED6415": "comms@moyoungdemocrats.org",              // Communications Committee
  "C094R094XEW": "fundraising@moyoungdemocrats.org",        // Fundraising Committee
  "C093RMQKXRA": "membership@moyoungdemocrats.org",         // Membership & Outreach Committee
};

export function groupForChannel(channelId: string | null | undefined): string | null {
  if (!channelId) return null;
  return CHANNEL_TO_GROUP[channelId] ?? null;
}

export interface GroupSyncResult {
  ok: boolean;         // true when the desired end-state is achieved (incl. idempotent no-ops)
  status: number;      // HTTP status from Directory API (0 = pre-flight failure)
  action: "added" | "already_member" | "removed" | "not_member" | "error";
  scopeError?: boolean; // true when a 401/403 indicates the DWD scope is not authorized
  error?: string;
}

async function directoryToken(): Promise<string> {
  return await getGoogleAccessToken({
    subject: DIRECTORY_SUBJECT,
    scopes: [GROUP_MEMBER_SCOPE],
  });
}

// Add `email` to `groupKey` as MEMBER / ALL_MAIL. Idempotent (409 => ok).
export async function addMemberToGroup(
  email: string,
  groupKey: string,
): Promise<GroupSyncResult> {
  let token: string;
  try {
    token = await directoryToken();
  } catch (e) {
    return { ok: false, status: 0, action: "error", scopeError: true, error: `token mint failed: ${String(e)}` };
  }
  const url = `https://admin.googleapis.com/admin/directory/v1/groups/${encodeURIComponent(groupKey)}/members`;
  const res = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ email, role: "MEMBER", delivery_settings: "ALL_MAIL" }),
  });
  if (res.status === 200 || res.status === 201) { await res.body?.cancel(); return { ok: true, status: res.status, action: "added" }; }
  if (res.status === 409) { await res.body?.cancel(); return { ok: true, status: 409, action: "already_member" }; }
  const body = await res.text();
  const scopeError = res.status === 401 || res.status === 403;
  return { ok: false, status: res.status, action: "error", scopeError, error: body.slice(0, 500) };
}

// Remove `email` from `groupKey`. Idempotent (404 => ok / not a member).
export async function removeMemberFromGroup(
  email: string,
  groupKey: string,
): Promise<GroupSyncResult> {
  let token: string;
  try {
    token = await directoryToken();
  } catch (e) {
    return { ok: false, status: 0, action: "error", scopeError: true, error: `token mint failed: ${String(e)}` };
  }
  const url = `https://admin.googleapis.com/admin/directory/v1/groups/${encodeURIComponent(groupKey)}/members/${encodeURIComponent(email)}`;
  const res = await fetch(url, {
    method: "DELETE",
    headers: { Authorization: `Bearer ${token}` },
  });
  if (res.status === 204 || res.status === 200) { await res.body?.cancel(); return { ok: true, status: res.status, action: "removed" }; }
  if (res.status === 404) { await res.body?.cancel(); return { ok: true, status: 404, action: "not_member" }; }
  const body = await res.text();
  const scopeError = res.status === 401 || res.status === 403;
  return { ok: false, status: res.status, action: "error", scopeError, error: body.slice(0, 500) };
}
