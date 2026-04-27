// Returns the caller's verified Gmail send-as identities, used by the
// composer's "From:" picker.
//
// shared_alias mailboxes (15 execs sharing crm@): only their single
// alias_email is returned. The shared mailbox has many sendAs entries
// (one per provisioned exec), but exposing the full list to one exec
// would let them spoof any other exec's From: address — the trust
// boundary keeps each exec pinned to their own alias.
//
// self_owned mailboxes (Andrew/Dustin/Landon): the entire Gmail
// settings.sendAs list is returned, filtered to verificationStatus=
// "accepted". The mailbox owner is allowed to send AS any verified
// identity on their own seat.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { handleCors, corsHeaders } from "../_shared/cors.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";

interface Identity {
  email: string;
  displayName: string;
  isDefault: boolean;
  /** Gmail returns 'accepted' | 'pending' | undefined. We only return
   *  'accepted' or the primary (which has no verificationStatus). */
  verified: boolean;
}

interface GmailSendAsEntry {
  sendAsEmail?: string;
  displayName?: string;
  isDefault?: boolean;
  treatAsAlias?: boolean;
  verificationStatus?: "accepted" | "pending";
  isPrimary?: boolean;
}

Deno.serve(async (req) => {
  const _cors = handleCors(req);
  if (_cors) return _cors;
  if (req.method !== "POST") return new Response("Use POST", { status: 405 });

  const caller = await resolveCaller(req);
  if (caller instanceof Response) return caller;

  // shared_alias: short-circuit. The only identity this caller is
  // authorized to send as is their own alias_email.
  if (caller.mailboxKind !== "self_owned") {
    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: row } = await sb
      .from("mail_aliases")
      .select("display_name")
      .eq("alias_email", caller.aliasEmail)
      .maybeSingle();
    const identities: Identity[] = [
      {
        email: caller.aliasEmail,
        displayName: (row?.display_name as string | undefined) ??
          caller.aliasEmail,
        isDefault: true,
        verified: true,
      },
    ];
    return new Response(
      JSON.stringify({ identities, primary: caller.aliasEmail }),
      { headers: { ...corsHeaders(), "Content-Type": "application/json" } },
    );
  }

  // self_owned: pull the full sendAs list from Gmail.
  const tok = await getGoogleAccessToken({
    subject: caller.impersonationSubject,
    scopes: ["https://www.googleapis.com/auth/gmail.settings.basic"],
  });
  const r = await fetch(`${GMAIL_API}/settings/sendAs`, {
    headers: { Authorization: `Bearer ${tok}` },
  });
  if (!r.ok) {
    const detail = (await r.text()).slice(0, 500);
    return new Response(
      JSON.stringify({ error: "sendas_list_failed", detail }),
      { status: 502, headers: { ...corsHeaders(), "Content-Type": "application/json" } },
    );
  }
  const body = await r.json();
  const entries: GmailSendAsEntry[] = Array.isArray(body.sendAs)
    ? body.sendAs
    : [];

  // Primary identity has no verificationStatus (it's the user's own
  // mailbox). Aliases have verificationStatus === "accepted" once
  // confirmed. Filter unverified aliases out — sending as an unverified
  // address would 400 from Gmail and we don't want it in the picker.
  const identities: Identity[] = entries
    .filter((e) => {
      if (!e.sendAsEmail) return false;
      // Primary mailbox has no verificationStatus and isPrimary=true (or
      // isDefault=true with the same email as the impersonation subject).
      const isPrimary = e.isPrimary === true ||
        e.sendAsEmail.toLowerCase() === caller.impersonationSubject.toLowerCase();
      return isPrimary || e.verificationStatus === "accepted";
    })
    .map((e) => ({
      email: e.sendAsEmail!.toLowerCase(),
      displayName: (e.displayName ?? "").trim() || e.sendAsEmail!,
      isDefault: e.isDefault === true,
      verified: true,
    }));

  // If somehow the primary isn't in the list, add it as a fallback so
  // the composer always has at least one entry.
  const primaryEmail = caller.impersonationSubject.toLowerCase();
  if (!identities.some((i) => i.email === primaryEmail)) {
    identities.unshift({
      email: primaryEmail,
      displayName: primaryEmail,
      isDefault: true,
      verified: true,
    });
  }

  return new Response(
    JSON.stringify({ identities, primary: primaryEmail }),
    { headers: { ...corsHeaders(), "Content-Type": "application/json" } },
  );
});
