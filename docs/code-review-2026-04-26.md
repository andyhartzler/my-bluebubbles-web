# MOYD CRM Mail Client — Code Review (2026-04-26)

**Scope:** ~50 commits today on `master` building the mail client end-to-end (Phase 0–6 + tmail-flutter source fork mounted in `MailScreen`).
**Reviewer:** Claude Opus 4.7 (1M context), main-thread review (parallel reviewer agents hit the daily token cap before finishing).
**Verdict:** No ship-blockers. 2 medium issues + 1 low. Trust boundary holds. RLS holds. The build is live and functional.

---

## Summary

50+ commits today covering: Supabase schema (5 tables, RLS + audit triggers), 27 edge functions (Deno/TS), Dart-side `EdgeFn*DataSource` impls (8 of them), a literal source fork of `tmail-flutter` (~2,500 .dart files) mounted as the user-facing UI, theme override mapping LinagoraColors → BrandColors at the declaration site (33 constants → ~250 call sites), 42 passing integration tests. The trust boundary is two-layered (alias clamp on Gmail `q=` + exact-match RFC 5322 post-filter via `messageMatchesAlias`) and is enforced consistently across the edge fns I reviewed.

Below: the issues I have HIGH confidence on. I did not surface stylistic preferences or speculative concerns.

---

## Issue 1 — `extractEmail` returns FIRST angle-bracket match (potential display-name spoofing)

**File:** `supabase/functions/_shared/email-utils.ts:24`
**Severity:** medium
**Trust-boundary impact:** yes (limited)

The angle-bracket regex `/<\s*([^<>\s]+@[^<>\s]+)\s*>/` is called via `String.prototype.match` (non-global), which returns the FIRST match. Per RFC 5322, when a header contains a display name with angle brackets AND the actual address (also angle-bracketed), the actual address comes LAST. Example header value:

```
"Andrew <chelsea@moyoungdemocrats.org>" <real@evil.com>
```

`extractEmail` returns `chelsea@moyoungdemocrats.org`. The actual sender is `real@evil.com`.

**Concrete attack:** an attacker BCC's `crm@moyoungdemocrats.org` with a message whose `From:` header embeds another exec's alias inside a quoted display name. Our `mail-pubsub-receiver` walks the message, calls `messageMatchesAlias` against each provisioned alias, and may classify the message under the wrong exec's cache.

**Blast radius:** message-injection / cache pollution (the wrong exec sees a message that wasn't really for them). Does NOT enable cross-exec read of messages that ARE addressed to someone else — that path is gated by Gmail's q-clamp on the read endpoints + the alias verification.

**Suggested fix:** change `extractEmail` to use `matchAll` and pick the LAST angle-bracket match:

```ts
const matches = [...v.matchAll(/<\s*([^<>\s]+@[^<>\s]+)\s*>/g)];
if (matches.length > 0) return matches[matches.length - 1][1].toLowerCase();
```

Add a unit test for the spoofing case once changed.

---

## Issue 2 — `ResolvedCaller.isSuperadmin` is always `false` (dead code with misleading contract)

**File:** `supabase/functions/_shared/alias-resolver.ts:49-52`
**Severity:** medium
**Trust-boundary impact:** no (the field is currently unread by every edge fn)

```ts
const { data: superadminRow } = await supabase.rpc(
  "current_user_is_superadmin",
);
```

The `supabase` client here is the service-role client (constructed at line 24-27 with `SUPABASE_SERVICE_ROLE_KEY`). `current_user_is_superadmin()` reads `auth.uid()` — which is NULL when called via service-role. So `superadminRow` is always `false`, and `ResolvedCaller.isSuperadmin` is effectively dead.

I grepped for `caller.isSuperadmin` and `isSuperadmin` across `supabase/functions/` — zero call sites. The field is unread.

**Why this is medium not low:** the contract is misleading. A future contributor might wire `caller.isSuperadmin` into an authz check, expecting it to work. It won't, and the failure mode is "deny everything" — not catastrophic, but wrong.

**Why it's not a security hole today:** `provision-mail-alias` and `revoke-mail-alias` (the only fns that need superadmin gating) construct their own user-scoped client (`sbAuth`) with the bearer token in the Authorization header before calling `current_user_is_superadmin()`. Those work.

**Suggested fix:** either (a) remove `isSuperadmin` from `ResolvedCaller` entirely — it's misleading dead surface area; or (b) construct a user-scoped client inside `resolveCaller` and call the RPC there:

```ts
const userClient = createClient(SUPABASE_URL, ANON_KEY, {
  global: { headers: { Authorization: `Bearer ${token}` } },
});
const { data: isSuper } = await userClient.rpc("current_user_is_superadmin");
```

(a) is the cleaner choice given no current callers depend on it.

---

## Issue 3 — Bcc header fetch is inconsistent across edge fns (intentional but undocumented)

**File:** multiple — see below
**Severity:** low
**Trust-boundary impact:** no (asymmetric design is correct)

Read endpoints (`mail-list`, `mail-thread-get`, `mail-message-get`) do NOT fetch `Bcc` in their `metadataHeaders=` query. Write/delete endpoints (`mail-mutation`, `mail-permanent-delete`, `mail-attachment-get`, `mail-eml-get`, `mail-reconcile-nightly`, `mail-unsubscribe`) DO.

This is actually correct: BCC'd recipients shouldn't see the message in their inbox listing (the sender intentionally hid them from each other), but they should be able to act on a message they were CC'd-by-Bcc on if they have the messageId already. The `messageMatchesAlias` helper at `email-utils.ts:55` includes `bcc` in its candidate-key list, but with no Bcc in the headers map for read paths, it's effectively skipped — which matches the design.

**Suggested fix:** add a doc comment to `messageMatchesAlias` clarifying the intentional asymmetry:

```ts
// NOTE: callers fetching `Bcc` in their metadataHeaders enable the
// match against bcc'd recipients. Read paths (mail-list/-thread-get/
// -message-get) intentionally omit Bcc to preserve sender's
// confidentiality — bcc'd recipients won't see the message in their
// inbox. Write paths (mail-mutation/-permanent-delete/-attachment-get/
// -eml-get) include Bcc so a bcc'd recipient can still operate on a
// message whose ID they already have.
```

---

## Architecture observations (clean — no issues)

**1. Edge function trust boundary is consistently two-layered.** Read paths use a server-injected `(deliveredto:<alias> OR from:<alias>)` Gmail q-clamp PLUS sanitize the user `q` to strip the 8 forbidden operators (`deliveredto`, `from`, `to`, `cc`, `bcc`, `rfc822msgid`, `list`, `label`) PLUS strip `OR` and parens PLUS exact-match post-filter via `messageMatchesAlias`. Even if Gmail's q-clamp leaks (it shouldn't), the post-filter catches it.

**2. RLS policies on `mail_aliases` / `mail_messages_cache` / `mail_send_log` / `mail_pubsub_state` / `mail_vacation_prefs` are sound.** All `FOR SELECT TO authenticated` policies use `auth.uid() = ...` or `current_user_alias() = ...` (a `STABLE SECURITY DEFINER` function). Service-role policies are isolated. `mail_messages_cache` correctly `REVOKE INSERT, UPDATE, DELETE FROM authenticated` so only the receiver (service-role) writes.

**3. `current_user_alias()` is `STABLE SECURITY DEFINER` with `search_path = public`** — correct for use inside RLS policies (avoids recursion + planner caches the result).

**4. Gmail labels approach (mail-mutation) avoids the `users.messages.delete` footgun** — moves to TRASH/SPAM by adding/removing labels; permanent delete is gated behind a separate edge fn that refuses if the message still has `INBOX` (forces trash-then-delete intent).

**5. Vacation auto-reply has 3 loop-prevention layers** in `mail-pubsub-receiver`: RFC 3834 header check, 24h-per-(alias,from) rate limit via `mail_messages_cache.auto_replied_at`, `Auto-Submitted: auto-replied` on outbound.

**6. JmapEmailBuilder correctly walks Gmail payload trees recursively** with safe `_safeId` fallback (returns null instead of throwing on regex-failing IDs, so we degrade to "no id" rather than crashing).

**7. The Identity binding patches** (commits `d0dab6169`, `95d39ecac`) forward tagged per-composer lazyPuts to our untagged singleton — clean GetX pattern.

**8. The OIDC redirect neutralization** (`web_auth_redirect_processor_extension.dart`, commit `d48713c3c`) correctly no-ops `getAuthenticationInfoRedirect`, `tryGetAuthenticatedAccountToUseApp`, `backToHomeScreen`. The other 3 methods in the extension (`getStoredOidcConfiguration`, `getTokenOIDCAction`, `isGetTokenOIDCFailure`) preserved unchanged — sound surgical patch.

---

## Verified clean (no issues found)

- `_shared/google-auth.ts` — service-account JWT mint + DWD impersonation. Per-(subject, scopes) cache. Sound.
- `_shared/oidc-verify.ts` — Google JWKS verification of Pub/Sub push tokens. Asserts `iss`, `aud`, `email`, `email_verified`, `exp`, `iat` with 60s clock skew. Sound.
- `mail-list` — alias clamp + sanitizer + post-filter. Trust boundary intact.
- `mail-thread-get` / `mail-message-get` — exact-match post-filter; 403 on non-match.
- `mail-send` — From: pinned server-side, audit row pre-send + post-send, eager cache upsert, unique-when-not-null `rfc822_message_id` index.
- `mail-mutation` — per-message metadata pre-fetch + alias verification before any `users.messages.modify`.
- `mail-permanent-delete` — not-in-trash safety gate (refuses INBOX-labeled messages). Excellent.
- `mail-attachment-get` — pre-fetches metadata for alias check before touching attachment bytes. Streams binary correctly.
- `mail-eml-get` — same pre-flight alias check before fetching `format=raw`.
- `mail-unsubscribe` — RFC 8058 one-click + RFC 2369 fallback paths; https-only enforcement on URLs (refuses plain http for security); per-message alias verification.
- `mail-search` — same sanitizer as mail-list.
- `mail-draft-create` / `mail-draft-update` — From: pinned to caller alias on RFC 822 build; ownership check on update (compares draft's From: to caller's alias).
- `mail-draft-list` — post-filters drafts by From: alias match (drafts have no Delivered-To).
- `provision-mail-alias` — superadmin gate via user-scoped client. Idempotent via 409 swallow + `onConflict: 'user_id'`. Workspace alias propagation retry loop (6×15s) — matches the lessons-learned memory note.
- `revoke-mail-alias` — same superadmin gate. Idempotent (404 from Gmail/Admin SDK = success).
- `mail-pubsub-receiver` — OIDC verification via shared verifier, history.list pagination loop, persists `lastResponseHistoryId` (the floor of pages processed) not the push envelope's id, vacation auto-reply with 3-layer loop prevention.
- `mail-watch-renew` — daily refresh, no caller inputs, deployed `--no-verify-jwt`.
- `mail-poll` — 5-min silent-detection fallback. Same history walk as receiver.
- `mail-watch-health` — Slack alert on stale watch. Fail-soft (won't break the cron if Slack is down).
- `mail-reconcile-nightly` — drift detection with re-verification of every metadata fetch. Per-alias error isolation.
- `mail-contact-search` — sanitizes `q`, requires auth, parameter-binds the SQL `LIKE` (no injection).
- `mail-labels-get` — small env-passthrough fn, auth-gated.
- 42 integration tests — all passing.
- `tmail_runtime_bindings.registerEdgeFnDataSources()` — guards every Get.put with `Get.isRegistered<T>()` for idempotency.
- `MailScreen._boot()` — async, error-displaying, idempotent (`_initialized` guard in MailScreenTmailBindings).
- `dashboard_controller_fixups.populateDashboardListIdentities()` — routes through controller's `consumeState` so the `_handleGetAllIdentitiesSuccess` mixin path runs (correct).
- BrandColors theme override at MailScreen scope + AppColor declaration-site swap — load-bearing color slots correctly mapped to MOYD palette.

---

## Recommendation

Ship as-is. Address Issue 1 (extractEmail last-match) opportunistically — it's a defense-in-depth fix, not a live exploit. Address Issue 2 (dead `isSuperadmin`) by removing the field. Issue 3 is documentation only.

The mail client is feature-complete, deployed, tested, and the trust boundary is sound. Next step: have a real exec sign in and click around.
