// Phase 3: superadmin-only endpoint that provisions a per-exec mail
// alias.
//
// Two mailbox kinds (per Systems/CRM-Mail-Client.md §13):
//
//   - shared_alias (default): the exec shares crm@moyoungdemocrats.org.
//     Provision flow:
//       1. Auth: caller must be superadmin.
//       2. Insert Workspace user-alias on crm@ via Admin SDK
//          (impersonates andrew@).
//       3. Wait + retry sendAs.create on Gmail (impersonates crm@) —
//          Workspace alias propagation has a 30-90s lag.
//       4. Insert mail_aliases row with mailbox_kind='shared_alias'.
//
//   - self_owned: the exec has their own Workspace seat
//     (Andrew/Dustin/Landon — andrew@/dustin@/landon@). Provision flow:
//       1. Auth: caller must be superadmin.
//       2. Verify the mailbox exists in Workspace (Admin SDK users.get).
//       3. Skip Admin SDK aliases.insert (nothing to alias — they own it).
//       4. Skip Gmail sendAs.create (they ARE the From: address).
//       5. Insert mail_aliases row with mailbox_kind='self_owned'.
//       6. Trigger users.watch on their mailbox so the receiver picks up
//          their inbound mail.
//
// Idempotent: re-running for the same user_id no-ops in the DB and skips
// the API calls if alias / send-as already exist.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { handleCors, corsHeaders } from "../_shared/cors.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SHARED_MAILBOX = "crm@moyoungdemocrats.org";
const ADMIN_IMPERSONATE = "andrew@moyoungdemocrats.org";
const DOMAIN = "moyoungdemocrats.org";
const ALIAS_REGEX = /^[a-z0-9._-]+@moyoungdemocrats\.org$/;
const PUBSUB_TOPIC = "projects/backend-everything/topics/gmail-crm";

type MailboxKind = "shared_alias" | "self_owned";

interface ProvisionBody {
  userId: string;
  firstName?: string;
  displayName?: string;
  mailboxKind?: MailboxKind;
  /** Required for self_owned. Must be the user's actual Workspace primary
   *  email (e.g. andrew@moyoungdemocrats.org). Ignored for shared_alias. */
  aliasEmail?: string;
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
  const _cors = handleCors(req);
  if (_cors) return _cors;
  if (req.method !== "POST") {
    return new Response("Use POST", { status: 405 });
  }

  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "missing_auth" }), {
      status: 401,
      headers: { ...corsHeaders(), "Content-Type": "application/json" },
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
      headers: { ...corsHeaders(), "Content-Type": "application/json" },
    });
  }
  const { data: isSuper } = await sbAuth.rpc("current_user_is_superadmin");
  if (isSuper !== true) {
    return new Response(JSON.stringify({ error: "not_superadmin" }), {
      status: 403,
      headers: { ...corsHeaders(), "Content-Type": "application/json" },
    });
  }

  const body = (await req.json().catch(() => ({}))) as Partial<ProvisionBody>;
  const targetUserId = body.userId;
  const mailboxKind: MailboxKind = body.mailboxKind === "self_owned"
    ? "self_owned"
    : "shared_alias";
  const displayName = body.displayName ?? "";
  if (!targetUserId) {
    return new Response(JSON.stringify({ error: "missing_userId" }), {
      status: 400,
      headers: { ...corsHeaders(), "Content-Type": "application/json" },
    });
  }

  // Resolve the alias email — derived from firstName for shared_alias,
  // explicit for self_owned.
  let aliasEmail: string;
  let firstNameRaw = body.firstName ?? "";
  if (mailboxKind === "self_owned") {
    const explicit = (body.aliasEmail ?? "").toLowerCase().trim();
    if (!explicit) {
      return new Response(
        JSON.stringify({ error: "missing_aliasEmail_for_self_owned" }),
        { status: 400, headers: { ...corsHeaders(), "Content-Type": "application/json" } },
      );
    }
    if (!ALIAS_REGEX.test(explicit)) {
      return new Response(JSON.stringify({ error: "alias_invalid" }), {
        status: 400,
        headers: { ...corsHeaders(), "Content-Type": "application/json" },
      });
    }
    aliasEmail = explicit;
    if (!firstNameRaw) firstNameRaw = explicit.split("@")[0];
  } else {
    if (!firstNameRaw) {
      return new Response(
        JSON.stringify({ error: "missing_firstName" }),
        { status: 400, headers: { ...corsHeaders(), "Content-Type": "application/json" } },
      );
    }
    const localPart = slug(firstNameRaw);
    if (!localPart) {
      return new Response(JSON.stringify({ error: "invalid_first_name" }), {
        status: 400,
        headers: { ...corsHeaders(), "Content-Type": "application/json" },
      });
    }
    aliasEmail = `${localPart}@${DOMAIN}`;
    if (!ALIAS_REGEX.test(aliasEmail)) {
      return new Response(JSON.stringify({ error: "alias_invalid" }), {
        status: 400,
        headers: { ...corsHeaders(), "Content-Type": "application/json" },
      });
    }
  }

  // Verify target user exists in auth.users (FK requirement).
  const { data: targetAuth } = await sb.auth.admin.getUserById(targetUserId);
  if (!targetAuth?.user) {
    return new Response(JSON.stringify({ error: "target_user_not_found" }), {
      status: 404,
      headers: { ...corsHeaders(), "Content-Type": "application/json" },
    });
  }

  if (mailboxKind === "self_owned") {
    // 1. Verify the mailbox exists as a real Workspace seat.
    const adminTok = await getGoogleAccessToken({
      subject: ADMIN_IMPERSONATE,
      scopes: [
        "https://www.googleapis.com/auth/admin.directory.user.readonly",
      ],
    });
    const userGetRes = await gapi(
      `https://admin.googleapis.com/admin/directory/v1/users/${
        encodeURIComponent(aliasEmail)
      }`,
      adminTok,
      { method: "GET" },
    );
    if (!userGetRes.ok) {
      const detail = await userGetRes.text();
      return new Response(
        JSON.stringify({
          error: "workspace_user_not_found",
          detail,
        }),
        { status: 404, headers: { ...corsHeaders(), "Content-Type": "application/json" } },
      );
    }

    // 2. Insert the mail_aliases row.
    const { data: row, error: dbErr } = await sb
      .from("mail_aliases")
      .upsert(
        {
          user_id: targetUserId,
          alias_email: aliasEmail,
          display_name: displayName || firstNameRaw,
          gmail_send_as_verified: true,
          mailbox_kind: "self_owned",
          revoked_at: null,
        },
        { onConflict: "user_id" },
      )
      .select()
      .single();
    if (dbErr) {
      return new Response(
        JSON.stringify({ error: "db_failed", detail: dbErr.message }),
        { status: 500, headers: { ...corsHeaders(), "Content-Type": "application/json" } },
      );
    }

    // 3. Trigger users.watch on this mailbox so the receiver starts seeing
    //    pushes. Idempotent — Gmail allows refreshing an existing watch.
    let watchResult: unknown = null;
    try {
      const watchTok = await getGoogleAccessToken({
        subject: aliasEmail,
        scopes: ["https://www.googleapis.com/auth/gmail.modify"],
      });
      const watchRes = await fetch(
        "https://gmail.googleapis.com/gmail/v1/users/me/watch",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${watchTok}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            topicName: PUBSUB_TOPIC,
            labelIds: ["INBOX"],
            labelFilterBehavior: "INCLUDE",
          }),
        },
      );
      if (watchRes.ok) {
        const wd = await watchRes.json();
        await sb.from("mail_pubsub_state").upsert(
          {
            mailbox_email: aliasEmail,
            history_id: wd.historyId,
            watch_expires_at: new Date(Number(wd.expiration)).toISOString(),
          },
          { onConflict: "mailbox_email" },
        );
        watchResult = {
          ok: true,
          historyId: wd.historyId,
          expires: wd.expiration,
        };
      } else {
        watchResult = {
          ok: false,
          status: watchRes.status,
          detail: (await watchRes.text()).slice(0, 500),
        };
      }
    } catch (e) {
      watchResult = { ok: false, error: String(e) };
    }

    return new Response(
      JSON.stringify({ ok: true, alias: row, watch: watchResult }),
      { headers: { ...corsHeaders(), "Content-Type": "application/json" } },
    );
  }

  // ---- shared_alias path (existing behavior, unchanged) ----

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
        { status: 502, headers: { ...corsHeaders(), "Content-Type": "application/json" } },
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
      sendAsOk = true;
      break;
    }
  }
  if (!sendAsOk) {
    return new Response(
      JSON.stringify({ error: "send_as_failed", detail: lastDetail }),
      { status: 502, headers: { ...corsHeaders(), "Content-Type": "application/json" } },
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
        mailbox_kind: "shared_alias",
        revoked_at: null,
      },
      { onConflict: "user_id" },
    )
    .select()
    .single();
  if (dbErr) {
    return new Response(
      JSON.stringify({ error: "db_failed", detail: dbErr.message }),
      { status: 500, headers: { ...corsHeaders(), "Content-Type": "application/json" } },
    );
  }

  return new Response(
    JSON.stringify({ ok: true, alias: row }),
    { headers: { ...corsHeaders(), "Content-Type": "application/json" } },
  );
});
