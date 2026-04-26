// RFC 5322 address extraction + exact-match alias check.
//
// THIS IS A TRUST BOUNDARY. The mail-list, mail-thread-get, mail-message-get,
// and mail-pubsub-receiver functions all use messageMatchesAlias() to confirm
// a caller is authorized to see a message. Substring matching (e.g.,
// `header.includes("sam@")`) is unsafe — `sam@...` would match `samantha@...`.
// Always use exact equality on the parsed email portion.

/**
 * Extracts the email-address portion from an RFC 5322 header value.
 * Handles all of:
 *   "Andrew Hartzler" <andrew@example.com>   ->  andrew@example.com
 *   andrew@example.com                       ->  andrew@example.com
 *   <andrew@example.com>                     ->  andrew@example.com
 * Returns lowercase email, or null if the value is unparseable.
 */
export function extractEmail(
  headerValue: string | undefined | null,
): string | null {
  if (!headerValue) return null;
  const v = headerValue.trim();
  // Prefer angle-bracket form — display names may contain emails too;
  // per RFC 5322 the actual address is in the LAST angle-bracket pair.
  // (A display name like `"Andrew <chelsea@example.com>"` followed by
  //  `<real@evil.com>` would otherwise spoof a different alias if we
  //  picked the FIRST match.)
  const angMatches = [...v.matchAll(/<\s*([^<>\s]+@[^<>\s]+)\s*>/g)];
  if (angMatches.length > 0) {
    return angMatches[angMatches.length - 1][1].toLowerCase();
  }
  // Bare email — entire value is just an address with no display name.
  if (/^[^\s<>"]+@[^\s<>"]+$/.test(v)) return v.toLowerCase();
  // Last-resort: scan for the LAST email-shaped substring (same intent
  // as the angle-bracket case — the actual address is at the end).
  const bareMatches = [
    ...v.matchAll(/([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})/g),
  ];
  if (bareMatches.length > 0) {
    return bareMatches[bareMatches.length - 1][1].toLowerCase();
  }
  return null;
}

/** Like extractEmail but for a comma-separated header (To:, Cc:, Bcc:). */
export function extractEmailList(
  headerValue: string | undefined | null,
): string[] {
  if (!headerValue) return [];
  return headerValue
    .split(",")
    .map(extractEmail)
    .filter((s): s is string => s != null);
}

/**
 * Returns true iff `alias` matches one of the addresses in the message
 * headers (Delivered-To, To, Cc, Bcc, From). Case-insensitive, exact-match
 * on the extracted email — NOT substring containment.
 *
 * NOTE: callers fetching `Bcc` in their `metadataHeaders=` query enable
 * the match against Bcc'd recipients. Read paths (mail-list /
 * mail-thread-get / mail-message-get) intentionally OMIT Bcc so the
 * recipient list stays confidential — bcc'd recipients won't see the
 * message in their inbox. Write/delete paths (mail-mutation /
 * mail-permanent-delete / mail-attachment-get / mail-eml-get /
 * mail-reconcile-nightly / mail-unsubscribe) include Bcc so a bcc'd
 * recipient can still operate on a message whose ID they already have.
 */
export function messageMatchesAlias(
  headers: Record<string, string>,
  alias: string,
): boolean {
  const target = alias.toLowerCase();
  const candidates: string[] = [];
  for (const key of ["delivered-to", "to", "cc", "bcc", "from"]) {
    const v = headers[key];
    if (v) candidates.push(...extractEmailList(v));
  }
  return candidates.includes(target);
}
