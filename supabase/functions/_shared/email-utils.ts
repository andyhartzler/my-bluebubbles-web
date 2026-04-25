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
  // only the bracketed one is the actual recipient/sender.
  const ang = v.match(/<\s*([^<>\s]+@[^<>\s]+)\s*>/);
  if (ang) return ang[1].toLowerCase();
  // Bare email — entire value is just an address with no display name.
  if (/^[^\s<>"]+@[^\s<>"]+$/.test(v)) return v.toLowerCase();
  // Last-resort: scan for the first email-shaped substring.
  const last = v.match(/([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})/);
  return last ? last[1].toLowerCase() : null;
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
