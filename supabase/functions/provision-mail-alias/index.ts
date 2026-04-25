// Phase 3: superadmin-only endpoint that provisions a per-exec mail
// alias on the shared crm@ Workspace seat. Replaces the throwaway
// bulk-provision script — call this once per new exec.
//
// Flow:
//   1. Auth: caller must be authenticated AND current_user_is_superadmin().
//   2. Insert Workspace user alias on crm@ via Admin SDK (impersonates an
//      admin like andrew@).
//   3. Wait briefly + retry sendAs.create on Gmail API (impersonates crm@)
//      because Workspace alias propagation has a 30-90s lag.
//   4. Insert/upsert mail_aliases row keyed on user_id.
//
// Idempotent: re-running for the same user_id no-ops in the DB and skips
// the API calls if alias / send-as already exist.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SHARED_MAILBOX = "crm@moyoungdemocrats.org";
const ADMIN_IMPERSONATE = "andrew@moyoungdemocrats.org";
const DOMAIN = "moyoungdemocrats.org";
const ALIAS_REGEX = /^[a-z0-9._-]+@moyoungdemocrats\.org$/;

interface ProvisionBody {
  userId: string;
  firstName: string;
  displayName?: string;
}

function slug(name: string): string {
  return name
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9._-]/g, "")
    .trim();
}

async function gapi(
  baseUrl: string,
  token: string,
  init?: RequestInit,
): Promise<Response> {
  return fetch(baseUrl, {
    ...init,
    headers: {
      ...(init?.headers ?? {}),
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Use POST", { status: 405 });
  }

  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "missing_auth" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const sbAuth = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { global: { headers: { Authorization: auth } } },
  );

  const { data: userResp, error: userErr } = await sb.auth.getUser(
    auth.slice(7),
  );
  if (userErr || !userResp?.user) {
    return new Response(JSON.stringify({ error: "invalid_token" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }
  const { data: isSuper } = await sbAuth.rpc("current_user_is_superadmin");
  if (isSuper !== true) {
    return new Response(JSON.stringify({ error: "not_superadmin" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  const body = (await req.json().catch(() => ({}))) as Partial<ProvisionBody>;
  const targetUserId = body.userId;
  const firstNameRaw = body.firstName ?? "";
  const displayName = body.displayName ?? "";
  if (!targetUserId || !firstNameRaw) {
    return new Response(
      JSON.stringify({ error: "missing_userId_or_firstName" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const localPart = slug(firstNameRaw);
  if (!localPart) {
    return new Response(JSON.stringify({ error: "invalid_first_name" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
  const aliasEmail = `${localPart}@${DOMAIN}`;
  if (!ALIAS_REGEX.test(aliasEmail)) {
    return new Response(JSON.stringify({ error: "alias_invalid" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Verify target user exists in auth.users (FK requirement).
  const { data: targetAuth } = await sb.auth.admin.getUserById(targetUserId);
  if (!targetAuth?.user) {
    return new Response(JSON.stringify({ error: "target_user_not_found" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  // 1. Workspace user-alias on crm@ (Admin SDK).
  const adminTok = await getGoogleAccessToken({
    subject: ADMIN_IMPERSONATE,
    scopes: ["https://www.googleapis.com/auth/admin.directory.user.alias"],
  });
  const aliasRes = await gapi(
    `https://admin.googleapis.com/admin/directory/v1/users/${SHARED_MAILBOX}/aliases`,
    adminTok,
    { method: "POST", body: JSON.stringify({ alias: aliasEmail }) },
  );
  if (!aliasRes.ok && aliasRes.status !== 409) {
    const detail = await aliasRes.text();
    if (
      !detail.toLowerCase().includes("entity already exists") &&
      !detail.toLowerCase().includes("duplicate")
    ) {
      return new Response(
        JSON.stringify({ error: "alias_insert_failed", detail }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }
  }

  // 2. Gmail send-as on crm@. Workspace alias propagation has a 30-90s
  //    lag — retry up to 6 times with 15s spacing. (See memory note
  //    workspace_alias_propagation_lag.md from 2026-04-25.)
  const gmailTok = await getGoogleAccessToken({
    subject: SHARED_MAILBOX,
    scopes: ["https://www.googleapis.com/auth/gmail.settings.sharing"],
  });
  let sendAsOk = false;
  let lastDetail = "";
  for (let attempt = 0; attempt < 6 && !sendAsOk; attempt++) {
    if (attempt > 0) {
      await new Promise((r) => setTimeout(r, 15000));
    }
    const sendAsRes = await gapi(
      `https://gmail.googleapis.com/gmail/v1/users/me/settings/sendAs`,
      gmailTok,
      {
        method: "POST",
        body: JSON.stringify({
          sendAsEmail: aliasEmail,
          displayName: displayName || firstNameRaw,
          treatAsAlias: true,
          isDefault: false,
        }),
      },
    );
    if (sendAsRes.ok) {
      sendAsOk = true;
      break;
    }
    lastDetail = await sendAsRes.text();
    if (
      lastDetail.toLowerCase().includes("duplicate") ||
      lastDetail.toLowerCase().includes("already exists")
    ) {
      sendAsOk = true; // already configured — treat as success
      break;
    }
    // Otherwise it's likely the alias-propagation race; retry.
  }
  if (!sendAsOk) {
    return new Response(
      JSON.stringify({ error: "send_as_failed", detail: lastDetail }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }

  // 3. mail_aliases row.
  const { data: row, error: dbErr } = await sb
    .from("mail_aliases")
    .upsert(
      {
        user_id: targetUserId,
        alias_email: aliasEmail,
        display_name: displayName || firstNameRaw,
        gmail_send_as_verified: true,
        revoked_at: null,
      },
      { onConflict: "user_id" },
    )
    .select()
    .single();
  if (dbErr) {
    return new Response(
      JSON.stringify({ error: "db_failed", detail: dbErr.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  return new Response(
    JSON.stringify({ ok: true, alias: row }),
    { headers: { "Content-Type": "application/json" } },
  );
});
