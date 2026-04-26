// Enumerates the set of Gmail mailboxes the mail client must watch / poll /
// renew. There are two kinds:
//
//   - shared_alias: N mail_aliases rows all rolled up under one mailbox
//     (currently crm@moyoungdemocrats.org). One Gmail users.watch covers
//     all of them; messages are classified into the right alias by walking
//     headers via messageMatchesAlias.
//
//   - self_owned: one mailbox per row (Andrew/Dustin/Landon). Each has its
//     own users.watch + history watermark; every message in the mailbox is
//     the owning alias's by definition.
//
// This helper centralizes the enumeration so mail-watch-renew, mail-poll,
// mail-pubsub-receiver, mail-watch-health, and mail-reconcile-nightly all
// agree on what set of mailboxes exists and how to address each one.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export const SHARED_MAILBOX = "crm@moyoungdemocrats.org";

export type MailboxKind = "shared_alias" | "self_owned";

export interface MailboxAlias {
  userId: string;
  aliasEmail: string;
  displayName: string;
}

export interface WatchedMailbox {
  /** Address used as the Gmail DWD subject + key into mail_pubsub_state. */
  mailboxEmail: string;
  mailboxKind: MailboxKind;
  /** Aliases this mailbox owns. shared_alias has many, self_owned has one. */
  aliases: MailboxAlias[];
}

/**
 * Reads mail_aliases (active rows only) and returns the deduplicated set of
 * mailboxes the system should watch. shared_alias rows collapse under
 * SHARED_MAILBOX; self_owned rows each become their own mailbox.
 */
export async function enumerateWatchedMailboxes(
  sb: SupabaseClient,
): Promise<WatchedMailbox[]> {
  const { data, error } = await sb
    .from("mail_aliases")
    .select("user_id, alias_email, display_name, mailbox_kind")
    .is("revoked_at", null)
    .eq("gmail_send_as_verified", true);
  if (error) throw new Error(`alias_query_failed: ${error.message}`);

  const rows = (data ?? []) as Array<{
    user_id: string;
    alias_email: string;
    display_name: string;
    mailbox_kind: MailboxKind;
  }>;

  const sharedAliases: MailboxAlias[] = [];
  const selfOwned: WatchedMailbox[] = [];

  for (const r of rows) {
    const a: MailboxAlias = {
      userId: r.user_id,
      aliasEmail: r.alias_email.toLowerCase(),
      displayName: r.display_name ?? "",
    };
    if (r.mailbox_kind === "self_owned") {
      selfOwned.push({
        mailboxEmail: a.aliasEmail,
        mailboxKind: "self_owned",
        aliases: [a],
      });
    } else {
      sharedAliases.push(a);
    }
  }

  const out: WatchedMailbox[] = [];
  if (sharedAliases.length > 0) {
    out.push({
      mailboxEmail: SHARED_MAILBOX,
      mailboxKind: "shared_alias",
      aliases: sharedAliases,
    });
  }
  out.push(...selfOwned);
  return out;
}
