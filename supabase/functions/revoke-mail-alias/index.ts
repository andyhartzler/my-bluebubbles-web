// Phase 3: superadmin-only inverse of provision-mail-alias.
// Removes a per-exec mail alias from the shared crm@ Workspace seat
// and marks the audit row as revoked (preserves history; does NOT
// delete the mail_aliases row).
//
// Flow:
//   1. Auth: caller must be authenticated AND current_user_is_superadmin().
//   2. Look up active alias for user_id (revoked_at IS NULL).
//   3. Delete Gmail send-as on crm@ (impersonates crm@).
//   4. Delete Workspace user-alias on crm@ via Admin SDK (impersonates andrew@).
//   5. UPDATE mail_aliases SET revoked_at = now() WHERE user_id = $1.
//
// Idempotent: a 404 from either Gmail or Admin SDK is treated as
// success — the resource is already gone, so we still proceed to
// flip the audit-trail flag.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SHARED_MAILBOX = "crm@moyoungdemocrats.org";
const ADMIN_IMPERSONATE = "andrew@moyoungdemocrats.org";

interface RevokeBody {
  userId: string;
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

  const body = (await req.json().catch(() => ({}))) as Partial<RevokeBody>;
  const targetUserId = body.userId;
  if (!targetUserId) {
    return new Response(JSON.stringify({ error: "missing_userId" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // 1. Look up the active alias.
  const { data: existing, error: lookupErr } = await sb
    .from("mail_aliases")
    .select("alias_email, mailbox_kind")
    .eq("user_id", targetUserId)
    .is("revoked_at", null)
    .maybeSingle();
  if (lookupErr) {
    return new Response(
      JSON.stringify({ error: "db_lookup_failed", detail: lookupErr.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
  if (!existing?.alias_email) {
    return new Response(JSON.stringify({ error: "no_active_alias" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }
  const aliasEmail = existing.alias_email as string;
  const mailboxKind = (existing.mailbox_kind as string) ?? "shared_alias";

  if (mailboxKind === "shared_alias") {
    // 2a. Delete Gmail send-as on crm@. Idempotent: 404 = already gone.
    const gmailTok = await getGoogleAccessToken({
      subject: SHARED_MAILBOX,
      scopes: ["https://www.googleapis.com/auth/gmail.settings.sharing"],
    });
    const sendAsRes = await gapi(
      `https://gmail.googleapis.com/gmail/v1/users/me/settings/sendAs/${
        encodeURIComponent(aliasEmail)
      }`,
      gmailTok,
      { method: "DELETE" },
    );
    if (!sendAsRes.ok && sendAsRes.status !== 404) {
      const detail = await sendAsRes.text();
      return new Response(
        JSON.stringify({ error: "send_as_delete_failed", detail }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }

    // 3a. Delete Workspace user-alias on crm@. Idempotent: 404 = already gone.
    const adminTok = await getGoogleAccessToken({
      subject: ADMIN_IMPERSONATE,
      scopes: ["https://www.googleapis.com/auth/admin.directory.user.alias"],
    });
    const aliasRes = await gapi(
      `https://admin.googleapis.com/admin/directory/v1/users/${SHARED_MAILBOX}/aliases/${
        encodeURIComponent(aliasEmail)
      }`,
      adminTok,
      { method: "DELETE" },
    );
    if (!aliasRes.ok && aliasRes.status !== 404) {
      const detail = await aliasRes.text();
      return new Response(
        JSON.stringify({ error: "admin_alias_delete_failed", detail }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }
  } else {
    // self_owned — there's no alias on crm@ and no sendAs to remove.
    // Stop the Gmail watch on the user's mailbox so we stop receiving
    // pushes for it, and remove the mail_pubsub_state row.
    try {
      const watchTok = await getGoogleAccessToken({
        subject: aliasEmail,
        scopes: ["https://www.googleapis.com/auth/gmail.modify"],
      });
      await fetch("https://gmail.googleapis.com/gmail/v1/users/me/stop", {
        method: "POST",
        headers: { Authorization: `Bearer ${watchTok}` },
      });
    } catch (e) {
      console.warn(
        `revoke-mail-alias: users.stop failed for ${aliasEmail}: ${
          String(e)
        }`,
      );
    }
    await sb
      .from("mail_pubsub_state")
      .delete()
      .eq("mailbox_email", aliasEmail);
  }

  // 4. Flip the audit-trail flag (do NOT delete the row).
  const { error: dbErr } = await sb
    .from("mail_aliases")
    .update({ revoked_at: new Date().toISOString() })
    .eq("user_id", targetUserId);
  if (dbErr) {
    return new Response(
      JSON.stringify({ error: "db_update_failed", detail: dbErr.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  return new Response(
    JSON.stringify({ ok: true, revoked: aliasEmail }),
    { headers: { "Content-Type": "application/json" } },
  );
});
