// Resolves the caller's alias_email + mailbox_kind from their Supabase auth
// bearer token. Returns 401 if no token, 403 if the user has no provisioned
// alias.
//
// `isSuperadmin` is fetched via a USER-SCOPED client so `auth.uid()` resolves
// inside the SECURITY DEFINER function. Calling the RPC against the
// service-role client (as we used to) returns false unconditionally because
// auth.uid() is null in service-role context.
//
// `mailboxKind` distinguishes:
//   - 'shared_alias' — exec shares crm@moyoungdemocrats.org. Gmail calls
//     impersonate crm@; reads need the q-clamp + post-filter; writes pin
//     From: to the alias.
//   - 'self_owned' — exec has their own Workspace seat (Andrew/Dustin/Landon).
//     Gmail calls impersonate their own mailbox; no q-clamp, no post-filter,
//     and From: is the mailbox itself by definition.
//
// `impersonationSubject` is the email to pass to getGoogleAccessToken({subject})
// so callers don't have to re-derive the branch logic. Always trust this from
// the DB row — never accept a client-supplied subject.

import { createClient } from "jsr:@supabase/supabase-js@2";

export const SHARED_MAILBOX = "crm@moyoungdemocrats.org";

export type MailboxKind = "shared_alias" | "self_owned";

export interface ResolvedCaller {
  userId: string;
  aliasEmail: string;
  isSuperadmin: boolean;
  mailboxKind: MailboxKind;
  impersonationSubject: string;
}

export async function resolveCaller(
  req: Request,
): Promise<ResolvedCaller | Response> {
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "missing_auth" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }
  const token = auth.slice(7);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: userResp, error: userErr } = await supabase.auth.getUser(token);
  if (userErr || !userResp?.user) {
    return new Response(JSON.stringify({ error: "invalid_token" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }
  const userId = userResp.user.id;

  const { data: row } = await supabase
    .from("mail_aliases")
    .select("alias_email, revoked_at, gmail_send_as_verified, mailbox_kind")
    .eq("user_id", userId)
    .maybeSingle();
  if (!row || row.revoked_at || !row.gmail_send_as_verified) {
    return new Response(JSON.stringify({ error: "no_mail_alias" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  // User-scoped client so the RPC's auth.uid() resolves to the caller.
  // SUPABASE_ANON_KEY is the public client key; combined with the bearer
  // token in the Authorization header, the RPC runs in the user's RLS
  // context.
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: `Bearer ${token}` } } },
  );
  const { data: superadminRow } = await userClient.rpc(
    "current_user_is_superadmin",
  );
  const isSuperadmin = superadminRow === true;

  const aliasEmail = (row.alias_email as string).toLowerCase();
  const mailboxKind = (row.mailbox_kind as MailboxKind) ?? "shared_alias";
  const impersonationSubject = mailboxKind === "self_owned"
    ? aliasEmail
    : SHARED_MAILBOX;

  return {
    userId,
    aliasEmail,
    isSuperadmin,
    mailboxKind,
    impersonationSubject,
  };
}
