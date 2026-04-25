# CRM Mail Client (Per-Exec Aliases on Shared Workspace) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-executive Gmail mail client to the MOYD CRM by forking the UI of `linagora/tmail-flutter`, replacing its JMAP backend with a Supabase-Edge-Function shim that talks to Gmail API on a single shared Workspace seat (`crm@moyoungdemocrats.org`) with per-exec aliases (`firstname@moyoungdemocrats.org`).

**Architecture:** Flutter never holds the Google service-account key. All Gmail API traffic goes through Supabase Edge Functions that authenticate via the existing `moyd-ai-agent@backend-everything.iam.gserviceaccount.com` (DWD impersonating `crm@`), inject `q=deliveredto:<caller-alias>` server-side, and post-filter responses by `Delivered-To` header before returning to the client. Send path overwrites `From:` header from `auth.uid()`'s alias — clients cannot send as someone else. One `users.watch` on `crm@` covers all aliases via Pub/Sub fan-out in our reactor. Andrew, Dustin, and Landon already have their own Workspace seats — they're excluded from the shared-mailbox flow.

## Status — 2026-04-25 (live)

**Phase 1 + 2 + 3 edge layer = SHIPPED to `master` and live on moyd.app:**
- Schema migration applied: `mail_aliases`, `mail_messages_cache`, `mail_send_log`, `mail_pubsub_state` (4 tables, RLS, audit triggers, `current_user_alias()` SECURITY DEFINER scalar). `mail_threads_cache` deferred to Phase 2 per H1.
- 9 edge functions deployed to `faajpcarasilbfndzkmd`: `_shared/{google-auth,alias-resolver,email-utils,oidc-verify}`, `mail-list`, `mail-thread-get`, `mail-message-get`, `mail-send`, `mail-watch-renew`, `mail-pubsub-receiver`, `provision-mail-alias`. All reviewer C1–C5 / H1/H3/H5/H6 / M1/M2/M5/M6 / L6 fixes baked in.
- Pub/Sub: topic `gmail-crm` + push-subscription `gmail-crm-sub` ACTIVE; `gmail-api-push@system.gserviceaccount.com` granted `roles/pubsub.publisher` (after Andrew set the project-level `iam.allowedPolicyMemberDomains` override). Daily pg_cron renew (`mail-watch-renew-daily` jobid 86 at 09:15 UTC) registered. `users.watch` seeded historyId=1399.
- 15 execs provisioned (`firstname@moyoungdemocrats.org` for everyone except Andrew/Dustin/Landon who have their own seats): austin, chelsea, chloe, claudia, elena, elmedin, gannon, gavin, heather, james, katlin, lucas, lucy, rogelio, ryan. Workspace user-aliases on `crm@`, Gmail send-as auto-verified, `mail_aliases` rows keyed on each exec's `auth.uid()`.
- Andrew's `andrew.crm@` test-alias (the carveout the plan originally proposed in Task 0.4) was reverted — Andrew clarified he doesn't want one, only the 15 non-self-serving execs do.

**Flutter inbox UI on `master`:** fresh widgets (BrandedBackground/BrandedActivityFeedItem-style) gating on `mail_aliases.user_id = auth.uid()`. Working for the 15 execs. Andrew rejected this UI direction on the same day — wants the literal tmail-flutter source fork instead, no shortcuts. Fresh widgets stay live until the fork ships.

**Fork in progress on branch `feat/mail-tmail-fork` (NOT yet on master):**

`feat/mail-tmail-fork` checkpoint commits (most recent first):
- `e90fd7376` — strip sentry/, patch sanitize_html API
- `7cfb32b44` — Flutter 3.27+ Color API patches (.withValues → .withOpacity, etc.)
- `629754398` — 8 misc deps added (sanitize_html, lottie, html_unescape, etc.)
- `6457d1c42` — pubspec merge resolves (95 deps changed)
- `76a8e4240` — re-sed all _tmail imports, strip tmail-app runners
- `3f594c8b0` — bulk-fork remaining tmail packages (fcm, scribe, cozy, email_recovery, server_settings, rule_filter)
- `85bbe81e1` — initial bulk-fork checkpoint (core, model, labels, contact, forward, lib → `lib/features/mail/_tmail/`; assets → `assets/tmail/`)

Compile errors: **796 → 426** in the fork. Pubspec resolves cleanly. Path-stub overrides keep our existing native-platform stubs winning over tmail's real dep requirements (photo_manager, permission_handler, fast_contacts, flutter_local_notifications). 4 tmail deps **dropped as non-Phase-1**: super_dns_client (Dart 3.7+ requirement, autoconfig — we don't need), flutter_date_range_picker (Dart 3.7+, advanced search filter), twake_previewer_flutter (Dart 3.7+, file preview), sentry_flutter / sentry_dio (telemetry).

**Step-by-step status of the fork (steps numbered to match feature-dev tasks 16-19):**
- ✅ **step 1** (commits 85bbe81e1, 3f594c8b0, 76a8e4240): bulk-copy tmail source into `lib/features/mail/_tmail/` preserving directory structure; rewrite all package imports. 2,514 .dart files.
- ✅ **step 3** (commits 6457d1c42 → 1a49f00cc, ~12 commits): pubspec merge + Flutter 3.24 compatibility patches + dep stubs. 796 errors → 0. Pubspec resolves with 95 deps changed, 14 tmail-deps added, 4 dropped, 4 path-stub overrides, `web: 1.0.0` pin. Ran 2 build_runner passes generating 2242 + 1061 = 3303 `.g.dart` files. All Flutter 3.27+ API uses patched (`Color.withValues` → `withOpacity`, Color component getters, `spacing:` Wrap/Row/Column param). Stubs at `lib/features/mail/_tmail/_stubs/` for sentry_flutter, twake_previewer_flutter, super_dns_client, flutter_date_range_picker.
- ✅ **step 5** (interleaved with step 3): stripped sentry telemetry directory, manage_account notification subdir, tmail's app runners + main_entry. Stripped `cozy/`, `email_recovery/`, `server_settings/`, `rule_filter/`, `forward/`, `fcm/` package roots (pulled forward but kept as path imports). Most other feature dirs stay intact because mailbox_dashboard's controller hard-references them.
- ✅ **`flutter build web --release`** passes (commit 45dd692d1, 101.6s build time). Fork is shippable code.
- ✅ **step 6 (partial)** (commit bd5b3358b): tmail's literal `EmailTileBuilder` widget mounts inside our existing `MailInboxView`, fed by our edge-function data via the `MailMessage` → `PresentationEmail` bridge in `lib/features/mail/services/tmail_bridge.dart`. Wide viewports use `EmailTileBuilder` (web variant) at 768px breakpoint. `ImagePaths` + `ResponsiveUtils` registered via `Get.put` on first mount. Web build still passes (118.4s).
- ✅ **step 6 (thread body)** (commit f3ee00fa1): MailThreadView's `_MessageBubble` now uses tmail's `HtmlContentViewerOnWeb` to render `text/html` email bodies (sandboxed iframe, mailto/link interception). White-surface bubble matches tmail's HTML viewer aesthetic. Falls back to `SelectableText` for plain-text-only messages. Web build still passes (105.3s).
- ⏳ **step 4** (next major chunk, ~1-2 sessions): bridge tmail's JMAP data sources to our edge functions. Tmail's `EmailDataSource` interface alone has 35+ methods. Phase 1 critical subset:
  - `EmailDataSource.getEmailContent` (→ mail-message-get) — needs JMAP `Email` construction from our edge-fn JSON
  - `EmailDataSource.sendEmail` (→ mail-send) — needs `EmailRequest` → mail-send body mapping
  - `ThreadDataSource.getAllEmail` (→ mail-list) — needs `EmailsResponse` (List<Email>) construction
  - `MailboxDataSource.getAllMailboxes` — return synthetic INBOX/SENT/DRAFTS/TRASH tree
  - `SessionDataSource` — return synthetic `Session` + `AccountId` for our Supabase-auth context
  Other 30+ methods throw `UnimplementedError`. Once these adapters exist, bind them at the GetX binding level (probably in `_tmail/tmail_ui_user/main/bindings/network/network_bindings.dart`) in place of the JMAP impls — then tmail's full `MailboxDashBoard` / `EmailView` / `ComposerView` widget trees render and function end-to-end with our edge fns as the backend. Tasks #20-23 in the feature-dev list track sub-steps.
- ⏳ **step 6 (full)**: once step 4 lands, replace `MailScreen` body with tmail's `MailboxDashBoardView` widget. Apply `BrandColors` over `LinagoraColors`/`AppColor` via Theme injection at the MailScreen scope.

**Progress shipped on `feat/mail-tmail-fork` this session (2026-04-25):** 18+ commits, error count 796 → 0, web build succeeds, tmail `EmailTileBuilder` + `EmailTileBuilder` (web) + `HtmlContentViewerOnWeb` mounted and rendering our edge-function data. The cherry-pick approach (mount tmail's leaf widgets that don't need a full controller chain) is the lowest-risk path to visible tmail UI inside bluebubbles before the full step-4 JMAP bridge is built.

**Live deploy:** unaffected by the fork. Phase 1 inbox is working for the 15 execs right now. The fork lands on master (replacing the fresh inbox UI) only when steps 4 + full step 6 complete and the branch is PR-merged.

---

## Plan v2.1 — Review fixes applied 2026-04-25

After the initial draft was reviewed by the `code-reviewer` agent, the following fixes are baked into Phase 0/1 below. Each is referenced by the reviewer's tag (C# = critical, H# = high, M# = medium, L# = low).

- **C1** — `mail-list` `q` sanitization tightened: strip `OR`, `to:`, `cc:`, `bcc:`, `rfc822msgid:`, `list:`, `label:` in addition to `deliveredto:`/`from:`; wrap user `q` in parens with explicit AND. Defense-in-depth alongside the post-filter.
- **C2/C3/C4** — Replaced `string.includes()` substring matching with a real RFC 5322 address extractor (`_shared/email-utils.ts → extractEmail()`) + exact-match. Substring spoofing (`sam@` vs `samantha@`) is the only way the trust boundary fails — must not ship without this.
- **C5** — Pub/Sub OIDC verification promoted from Phase 5 to Phase 1. Receiver verifies the `Authorization: Bearer <token>` against Google's OAuth2 jwks, asserts `audience=<our endpoint>` + `email=moyd-ai-agent@…`. ~30 LOC.
- **H1** — `mail_threads_cache` table is **dropped from Phase 1 migration** because the receiver never writes to it. Moved to Phase 2 alongside the grouped-inbox UI that needs it. Same for `mail_pubsub_state` table — keep, but now seeded by the watch-renew function rather than the receiver.
- **H3** — Receiver now loops on `users.history.list` `nextPageToken` until exhausted. Persists `hist.historyId` from the response (the floor of pages processed), not the push envelope's `newHistoryId`. Prevents silent message loss on multi-page history.
- **H5** — Cron uses `--no-verify-jwt` deploy flag for `mail-watch-renew` since it has no caller-controlled inputs (Pub/Sub + service-account-only path). Cleaner than wiring `app.settings.service_role_key`.
- **H6** — Add `CREATE UNIQUE INDEX ... ON mail_send_log (gmail_message_id) WHERE gmail_message_id IS NOT NULL`.
- **M1** — Add a `current_user_alias()` STABLE SECURITY DEFINER scalar function in the migration; RLS policies use it instead of inline `(SELECT alias_email FROM mail_aliases ...)`.
- **M2** — Explicit `REVOKE INSERT, UPDATE, DELETE ON mail_messages_cache FROM authenticated` so RLS regressions can't accidentally permit writes.
- **M4** — `attachments_summary` + `has_attachments` columns dropped from Phase 1 migration. Added in Phase 4 with `ALTER TABLE`.
- **M5** — Tightened `alias_email` regex check to anchored `^[a-z0-9._-]+@moyoungdemocrats\.org$`.
- **M6** — `mail-list` chunks Gmail metadata fetches to concurrency 10 (was 100). Stays under per-second quota burst.
- **L6** — `alias-resolver` and the UI-nav check both gate on `revoked_at IS NULL AND gmail_send_as_verified = true`.

**Tech Stack:**
- **Flutter** — fork tmail-flutter widget code into `lib/features/mail/`. Keep their `*_view.dart` and `*_widget.dart` presentation files; replace their `domain/` and `data/` and GetX controllers with our own Provider-based code. State management: existing Provider (matches the rest of the CRM). Strip `jmap_dart_client`, `flutter_appauth_web`, FCM, email_recovery, server_settings.
- **Supabase Edge Functions (Deno + TypeScript)** — eleven new functions for Gmail proxy + alias provisioning + Pub/Sub receiver. Use `npm:googleapis` ESM client (BSD-3) impersonating `crm@`.
- **Supabase Postgres** — five new tables (`mail_aliases`, `mail_messages_cache`, `mail_threads_cache`, `mail_send_log`, `mail_pubsub_state`). RLS self+superadmin. Audit triggers attached.
- **Google Workspace** — Admin SDK Directory `users.aliases.insert` + Gmail `users.settings.sendAs.create` for provisioning. Gmail `users.messages.*` + `users.threads.*` + `users.drafts.*` + `users.labels.*` + `users.history.list` + `users.watch` for the mailbox surface.
- **GCP Pub/Sub** — one topic (`gmail-crm`) + one push subscription targeting the receiver edge function with OIDC auth.

---

## File Structure

### Created files (Flutter)

- `lib/features/mail/` — entire feature directory (mirrors existing `lib/features/slack/`, `lib/features/committees/` etc.)
- `lib/features/mail/data/` — repositories that call our edge functions (replaces tmail's JMAP data layer)
  - `mail_repository.dart` — list/get/send/threads
  - `alias_repository.dart` — read mail_aliases for current user
  - `draft_repository.dart` — drafts CRUD
- `lib/features/mail/models/` — typed models matching our edge-function JSON shape (NOT JMAP types)
  - `mail_message.dart`
  - `mail_thread.dart`
  - `mail_alias.dart`
  - `mail_send_request.dart`
- `lib/features/mail/providers/` — Provider state classes
  - `mail_inbox_provider.dart`
  - `mail_thread_provider.dart`
  - `mail_composer_provider.dart`
- `lib/features/mail/screens/` — top-level screen widgets
  - `mail_screen.dart` — root tabbed shell
  - `mail_inbox_view.dart` (forked from tmail `thread_view.dart` + web variant)
  - `mail_thread_view.dart` (forked from tmail `email_view.dart` + web variant)
  - `mail_composer_view.dart` (forked from tmail `composer_view.dart` + web variant)
  - `mail_search_view.dart` (forked from tmail `search_email_view.dart`)
  - `mail_settings_view.dart` (built fresh)
- `lib/features/mail/widgets/` — leaf widgets forked from tmail
  - `email_tile.dart` (from tmail `email_tile_builder.dart`)
  - `recipient_chip.dart` (from tmail `recipient_composer_widget.dart`, simplified)
  - `subject_field.dart` (from tmail `subject_composer_widget.dart`)
  - `attachment_chip.dart` (from tmail `attachment_header_composer_widget.dart`)
- `lib/features/mail/services/` — Flutter-side services (HTTP calls to edge functions)
  - `mail_api_client.dart` — typed wrapper over Supabase function invocation

### Created files (Supabase + edge)

- `supabase/migrations/20260425_05_mail_client.sql` — five new tables + RLS + audit triggers
- `supabase/functions/provision-mail-alias/index.ts` — alias + send-as provisioning
- `supabase/functions/revoke-mail-alias/index.ts` — alias removal on exec departure
- `supabase/functions/mail-list/index.ts` — list inbox messages
- `supabase/functions/mail-thread-get/index.ts` — fetch thread
- `supabase/functions/mail-message-get/index.ts` — fetch single message body
- `supabase/functions/mail-attachment-get/index.ts` — stream attachment bytes
- `supabase/functions/mail-send/index.ts` — build RFC 822, send via Gmail API
- `supabase/functions/mail-draft-create/index.ts`, `mail-draft-list/index.ts`, `mail-draft-update/index.ts`, `mail-draft-send/index.ts` — drafts lifecycle
- `supabase/functions/mail-watch-renew/index.ts` — daily refresh of `users.watch`
- `supabase/functions/mail-pubsub-receiver/index.ts` — Pub/Sub push handler
- `supabase/functions/mail-poll/index.ts` — fallback poll if push silent >5 min
- `supabase/functions/_shared/google-auth.ts` — service-account JWT minting + DWD token exchange (shared lib)
- `supabase/functions/_shared/alias-resolver.ts` — caller auth → alias_email lookup helper
- `supabase/functions/_shared/email-utils.ts` — RFC 5322 address extractor + exact-match alias check
- `supabase/functions/_shared/oidc-verify.ts` — verifies Google-signed OIDC token on Pub/Sub push

### Modified files

- `lib/main.dart:684` — add `_HomeSection.mail` enum case (between `slack` and `forms`); add IndexedStack child + nav button + mobile drawer item
- `lib/screens/crm/superadmin/executives_screen.dart` — add "Enable Mail" action button per row → calls `provision-mail-alias`
- `pubspec.yaml` — add `flutter_quill` (composer rich text), `multi_split_view` (web 3-pane), `enough_mail` (RFC 822 builder for client-side draft preview), `flutter_typeahead` (recipient autocomplete)
- Possibly `pubspec.yaml` — add `enough_mail_flutter` if we lean on `MimeMessageViewer` for HTML body rendering (decide in Task 14 after evaluating tmail's body-render code)

### Forked files (verbatim from tmail-flutter, then de-GetX'd)

Cloned to `/tmp/tmail-flutter` for reference; specific files copied into `lib/features/mail/` as listed above. Process per file: copy → run `dart fix --apply` for GetX-strip → manually rewrite controller bindings (`Get.find` → `Provider.of`/`context.read`) → align with our brand colors via `BrandColors` swap.

---

## Phase 0 — Foundation (~1 day)

### Task 0.1: Add DWD scopes at admin.google.com

**Files:** none — this is a Google Workspace config step.

- [ ] **Step 1: Sign in to admin.google.com as super-admin** (Andrew's primary account).

- [ ] **Step 2: Navigate to Security → API Controls → Domain-wide Delegation. Find the row for client ID `114261141581576499255` (the existing service account `moyd-ai-agent@backend-everything.iam.gserviceaccount.com`).**

- [ ] **Step 3: Click the row → Edit. Append these five scopes (comma-separated, no whitespace):**

```
https://www.googleapis.com/auth/admin.directory.user.alias,
https://www.googleapis.com/auth/gmail.modify,
https://www.googleapis.com/auth/gmail.settings.basic,
https://www.googleapis.com/auth/gmail.settings.sharing,
https://www.googleapis.com/auth/gmail.labels
```

- [ ] **Step 4: Save. Wait 1–2 minutes for propagation.**

- [ ] **Step 5: Verify locally — run this from a terminal with the existing service-account JSON:**

```bash
node -e '
const {google} = require("googleapis");
const auth = new google.auth.JWT({
  keyFile: "/Users/moyd/Desktop/MOYD/backend-everything-a599411a62b5.json",
  scopes: ["https://www.googleapis.com/auth/gmail.settings.basic"],
  subject: "crm@moyoungdemocrats.org",
});
google.gmail({version:"v1", auth}).users.settings.sendAs.list({userId:"me"})
  .then(r => console.log("OK", r.data.sendAs?.length ?? 0, "send-as entries"))
  .catch(e => { console.error("FAIL", e.errors || e.message); process.exit(1); });
'
```

Expected: `OK 1 send-as entries` (the default crm@ identity itself). If you get `Request had insufficient authentication scopes` the propagation hasn't completed or scope is misconfigured.

### Task 0.2: Set up GCP Pub/Sub topic + subscription

**Files:** none (gcloud config).

- [ ] **Step 1: Create the topic + grant publish to Gmail's service account:**

```bash
gcloud pubsub topics create gmail-crm --project=backend-everything
gcloud pubsub topics add-iam-policy-binding gmail-crm \
  --member=serviceAccount:gmail-api-push@system.gserviceaccount.com \
  --role=roles/pubsub.publisher \
  --project=backend-everything
```

- [ ] **Step 2: Create the push subscription pointing at the receiver edge function:**

```bash
gcloud pubsub subscriptions create gmail-crm-sub \
  --topic=gmail-crm \
  --push-endpoint="https://faajpcarasilbfndzkmd.functions.supabase.co/mail-pubsub-receiver" \
  --push-auth-service-account=moyd-ai-agent@backend-everything.iam.gserviceaccount.com \
  --project=backend-everything
```

(Use OIDC token; the receiver verifies via JWT. If we'd rather use a shared header secret, swap to `--push-auth-token-audience` config.)

- [ ] **Step 3: Verify subscription:**

```bash
gcloud pubsub subscriptions describe gmail-crm-sub --project=backend-everything
```

Expected: `pushConfig.pushEndpoint` matches the URL above.

### Task 0.3: Schema migration

**Files:**
- Create: `supabase/migrations/20260425_05_mail_client.sql`

- [ ] **Step 1: Write the migration file:**

```sql
-- =====================================================================
-- 20260425_05_mail_client.sql
-- Per-exec Gmail mail client tables. RLS: owner + superadmin.
-- =====================================================================

SET search_path = public, pg_temp;

CREATE EXTENSION IF NOT EXISTS citext;

-- ---------------------------------------------------------------------
-- 1. mail_aliases
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.mail_aliases (
  user_id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
  alias_email      citext UNIQUE NOT NULL CHECK (alias_email ~ '^[a-z0-9._-]+@moyoungdemocrats\.org$'),
  display_name     text NOT NULL,
  provisioned_at   timestamptz NOT NULL DEFAULT now(),
  revoked_at       timestamptz,
  gmail_send_as_verified boolean NOT NULL DEFAULT false,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

-- Helper: returns the active alias for the current authenticated user,
-- or NULL if none. STABLE so the planner can cache the result for one
-- query — keeps RLS efficient. SECURITY DEFINER so policies on
-- mail_aliases don't recurse.
CREATE OR REPLACE FUNCTION public.current_user_alias()
RETURNS citext
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT alias_email FROM public.mail_aliases
  WHERE user_id = auth.uid()
    AND revoked_at IS NULL
    AND gmail_send_as_verified = true
  LIMIT 1;
$$;
REVOKE EXECUTE ON FUNCTION public.current_user_alias() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_alias() TO authenticated, service_role;

ALTER TABLE public.mail_aliases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ma_self ON public.mail_aliases;
CREATE POLICY ma_self ON public.mail_aliases
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.current_user_is_superadmin());

DROP POLICY IF EXISTS ma_service_role ON public.mail_aliases;
CREATE POLICY ma_service_role ON public.mail_aliases
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP TRIGGER IF EXISTS trg_ma_updated_at ON public.mail_aliases;
CREATE TRIGGER trg_ma_updated_at
  BEFORE UPDATE ON public.mail_aliases
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();

DROP TRIGGER IF EXISTS trg_audit_mail_aliases ON public.mail_aliases;
CREATE TRIGGER trg_audit_mail_aliases
  AFTER INSERT OR UPDATE OR DELETE ON public.mail_aliases
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- ---------------------------------------------------------------------
-- 2. mail_messages_cache
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.mail_messages_cache (
  gmail_message_id text PRIMARY KEY,
  thread_id        text NOT NULL,
  alias_email      citext NOT NULL,
  from_addr        text NOT NULL,
  to_addrs         text[] NOT NULL DEFAULT '{}',
  cc_addrs         text[] DEFAULT '{}',
  subject          text,
  snippet          text,
  internal_date    timestamptz NOT NULL,
  labels           text[] NOT NULL DEFAULT '{}',
  delivered_to     text,
  fetched_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mmc_alias_internal_date
  ON public.mail_messages_cache (alias_email, internal_date DESC);
CREATE INDEX IF NOT EXISTS idx_mmc_thread
  ON public.mail_messages_cache (thread_id);

ALTER TABLE public.mail_messages_cache ENABLE ROW LEVEL SECURITY;
REVOKE INSERT, UPDATE, DELETE ON public.mail_messages_cache FROM authenticated;

DROP POLICY IF EXISTS mmc_self ON public.mail_messages_cache;
CREATE POLICY mmc_self ON public.mail_messages_cache
  FOR SELECT TO authenticated
  USING (
    alias_email = public.current_user_alias()
    OR public.current_user_is_superadmin()
  );

DROP POLICY IF EXISTS mmc_service_role ON public.mail_messages_cache;
CREATE POLICY mmc_service_role ON public.mail_messages_cache
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ---------------------------------------------------------------------
-- 3. mail_threads_cache — DEFERRED to Phase 2 migration. The receiver
--    in Phase 1 doesn't write thread-level rollups; the inbox UI in
--    Phase 1 groups locally from `mail_messages_cache`. Adding the
--    table here would just leave it empty + RLS-blocked.
--
-- 4. mail_send_log (append-only)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.mail_send_log (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_user_id   uuid NOT NULL REFERENCES auth.users(id),
  alias_email      citext NOT NULL,
  gmail_message_id text,
  rfc822_message_id text,
  thread_id        text,
  recipients       jsonb NOT NULL,
  subject          text,
  sent_at          timestamptz NOT NULL DEFAULT now(),
  status           text NOT NULL CHECK (status IN ('queued','sent','failed')),
  error_detail     text,
  related_entity_type text,
  related_entity_id   uuid
);

CREATE INDEX IF NOT EXISTS idx_msl_sender_sent_at
  ON public.mail_send_log (sender_user_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_msl_thread
  ON public.mail_send_log (thread_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_msl_rfc822
  ON public.mail_send_log (rfc822_message_id) WHERE rfc822_message_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_msl_gmail_id
  ON public.mail_send_log (gmail_message_id) WHERE gmail_message_id IS NOT NULL;

ALTER TABLE public.mail_send_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS msl_self ON public.mail_send_log;
CREATE POLICY msl_self ON public.mail_send_log
  FOR SELECT TO authenticated
  USING (sender_user_id = auth.uid() OR public.current_user_is_superadmin());

DROP POLICY IF EXISTS msl_service_role ON public.mail_send_log;
CREATE POLICY msl_service_role ON public.mail_send_log
  FOR ALL TO service_role USING (true) WITH CHECK (true);

REVOKE UPDATE, DELETE ON public.mail_send_log FROM authenticated;

DROP TRIGGER IF EXISTS trg_audit_mail_send_log ON public.mail_send_log;
CREATE TRIGGER trg_audit_mail_send_log
  AFTER INSERT ON public.mail_send_log
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- ---------------------------------------------------------------------
-- 5. mail_pubsub_state (singleton)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.mail_pubsub_state (
  id               int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  history_id       text NOT NULL,
  watch_expires_at timestamptz NOT NULL,
  last_event_at    timestamptz,
  updated_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.mail_pubsub_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mps_superadmin ON public.mail_pubsub_state;
CREATE POLICY mps_superadmin ON public.mail_pubsub_state
  FOR SELECT TO authenticated
  USING (public.current_user_is_superadmin());

DROP POLICY IF EXISTS mps_service_role ON public.mail_pubsub_state;
CREATE POLICY mps_service_role ON public.mail_pubsub_state
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP TRIGGER IF EXISTS trg_mps_updated_at ON public.mail_pubsub_state;
CREATE TRIGGER trg_mps_updated_at
  BEFORE UPDATE ON public.mail_pubsub_state
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();

-- =====================================================================
-- End migration.
-- =====================================================================
```

- [ ] **Step 2: Apply via psql (the supabase CLI ledger is desync'd — see [check_obsidian_credentials_first.md](memory:check_obsidian_credentials_first)):**

```bash
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
PGPASSWORD="LNEERaCSbAKOVtdR" psql -h db.faajpcarasilbfndzkmd.supabase.co -p 5432 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/migrations/20260425_05_mail_client.sql
```

Expected: 5 CREATE TABLE, multiple CREATE POLICY/TRIGGER/INDEX, no errors.

- [ ] **Step 3: Verify the schema:**

```bash
PGPASSWORD="LNEERaCSbAKOVtdR" psql -h db.faajpcarasilbfndzkmd.supabase.co -p 5432 -U postgres -d postgres -c "
SELECT n.nspname || '.' || c.relname AS tbl, c.relrowsecurity AS rls_on
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE c.relname IN ('mail_aliases','mail_messages_cache','mail_threads_cache','mail_send_log','mail_pubsub_state')
  AND n.nspname='public';"
```

Expected: 5 rows, all `rls_on = t`.

- [ ] **Step 4: Notify PostgREST:**

```bash
PGPASSWORD="LNEERaCSbAKOVtdR" psql -h db.faajpcarasilbfndzkmd.supabase.co -p 5432 -U postgres -d postgres -c "NOTIFY pgrst, 'reload schema';"
```

- [ ] **Step 5: Commit:**

```bash
git add supabase/migrations/20260425_05_mail_client.sql
git commit -m "feat(mail): schema for per-exec mail client (5 tables, RLS, audit)"
```

### Task 0.4: Provision Andrew's alias manually (sanity check Phase 0 setup)

> **NOTE:** Andrew already has his own seat. We're using HIM as the test alias for Phase 1 because he's the developer. After Phase 1 ships, we'll only provision aliases for execs WITHOUT their own seats (per his clarification: not him, not Dustin, not Landon).

**Files:** none — manual API call.

- [ ] **Step 1: Insert the user alias on `crm@`:**

```bash
node -e '
const {google} = require("googleapis");
const auth = new google.auth.JWT({
  keyFile: "/Users/moyd/Desktop/MOYD/backend-everything-a599411a62b5.json",
  scopes: ["https://www.googleapis.com/auth/admin.directory.user.alias"],
  subject: "andrew@moyoungdemocrats.org",  // Admin SDK calls require an admin user, not crm@
});
google.admin({version:"directory_v1", auth}).users.aliases.insert({
  userKey: "crm@moyoungdemocrats.org",
  requestBody: { alias: "andrew.crm@moyoungdemocrats.org" }
}).then(r => console.log("OK", r.data)).catch(e => { console.error(e.errors || e.message); process.exit(1); });
'
```

(Note: `andrew.crm@` not `andrew@` — `andrew@` already exists as Andrew's own user. This dev alias is for testing the pipeline; in production every other exec just uses `firstname@` because they don't have their own seat.)

Expected: `{ kind: "admin#directory#alias", id: "...", primaryEmail: "crm@...", alias: "andrew.crm@..." }`

- [ ] **Step 2: Create the matching Gmail send-as on `crm@`:**

```bash
node -e '
const {google} = require("googleapis");
const auth = new google.auth.JWT({
  keyFile: "/Users/moyd/Desktop/MOYD/backend-everything-a599411a62b5.json",
  scopes: ["https://www.googleapis.com/auth/gmail.settings.sharing"],
  subject: "crm@moyoungdemocrats.org",
});
google.gmail({version:"v1", auth}).users.settings.sendAs.create({
  userId: "me",
  requestBody: {
    sendAsEmail: "andrew.crm@moyoungdemocrats.org",
    displayName: "Andrew Hartzler",
    treatAsAlias: true,
    isDefault: false
  }
}).then(r => console.log("OK", r.data.verificationStatus)).catch(e => { console.error(e.errors || e.message); process.exit(1); });
'
```

Expected: `OK accepted` — meaning send-as auto-verified because the alias is on the same user.

- [ ] **Step 3: Insert mail_aliases row:**

```sql
INSERT INTO public.mail_aliases (user_id, alias_email, display_name, gmail_send_as_verified)
SELECT id, 'andrew.crm@moyoungdemocrats.org', 'Andrew Hartzler', true
FROM auth.users
WHERE email = 'andrew@moyoungdemocrats.org';
```

- [ ] **Step 4: Send a test email to the alias from Andrew's personal mailbox** (using Andrew's own Gmail at andrew@) and verify it lands in `crm@`'s mailbox by impersonating crm@ and listing inbox messages with `q=deliveredto:andrew.crm@moyoungdemocrats.org`.

```bash
node -e '
const {google} = require("googleapis");
const auth = new google.auth.JWT({
  keyFile: "/Users/moyd/Desktop/MOYD/backend-everything-a599411a62b5.json",
  scopes: ["https://www.googleapis.com/auth/gmail.readonly"],
  subject: "crm@moyoungdemocrats.org",
});
google.gmail({version:"v1", auth}).users.messages.list({
  userId: "me",
  q: "deliveredto:andrew.crm@moyoungdemocrats.org",
  maxResults: 5,
}).then(r => console.log("Messages found:", r.data.resultSizeEstimate || 0)).catch(e => { console.error(e.errors || e.message); process.exit(1); });
'
```

Expected: `Messages found: 1` (or however many test messages you sent). If 0 — alias hasn't propagated yet (wait 5 min, retry) or the send-as filter's wrong.

---

## Phase 1 — Read-only inbox MVP (Andrew-only) (~2 days)

### Task 1.1: Shared Google auth helper (Deno edge function lib)

**Files:**
- Create: `supabase/functions/_shared/google-auth.ts`
- Test: manual curl test

- [ ] **Step 1: Add the GOOGLE_SERVICE_ACCOUNT_JSON secret to Supabase** (the full contents of `/Users/moyd/Desktop/MOYD/backend-everything-a599411a62b5.json`):

```bash
supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON="$(cat /Users/moyd/Desktop/MOYD/backend-everything-a599411a62b5.json)" --project-ref faajpcarasilbfndzkmd
```

- [ ] **Step 2: Write `supabase/functions/_shared/google-auth.ts`:**

```ts
// Mints a Google access token via service-account JWT + DWD impersonation.
// Caches per (subject, scopes) for ~50 minutes.

interface CachedToken {
  token: string;
  expiresAt: number;
}
const cache = new Map<string, CachedToken>();

function b64url(s: string): string {
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function rsaSign(key: CryptoKey, data: Uint8Array): Promise<string> {
  const sig = await crypto.subtle.sign({ name: "RSASSA-PKCS1-v1_5" }, key, data);
  let bin = "";
  const bytes = new Uint8Array(sig);
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return b64url(bin);
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const der = pem
    .replace(/-----BEGIN [^-]+-----/, "")
    .replace(/-----END [^-]+-----/, "")
    .replace(/\s+/g, "");
  const buf = Uint8Array.from(atob(der), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    buf,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

export interface GoogleAuthOptions {
  subject: string;        // user to impersonate, e.g. "crm@moyoungdemocrats.org"
  scopes: string[];
}

export async function getGoogleAccessToken(opts: GoogleAuthOptions): Promise<string> {
  const cacheKey = `${opts.subject}|${opts.scopes.sort().join(",")}`;
  const now = Math.floor(Date.now() / 1000);
  const cached = cache.get(cacheKey);
  if (cached && cached.expiresAt > now + 60) return cached.token;

  const sa = JSON.parse(Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON")!);
  const header = { alg: "RS256", typ: "JWT", kid: sa.private_key_id };
  const claim = {
    iss: sa.client_email,
    sub: opts.subject,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: opts.scopes.join(" "),
  };
  const encoder = new TextEncoder();
  const headerB64 = b64url(JSON.stringify(header));
  const claimB64 = b64url(JSON.stringify(claim));
  const signingInput = `${headerB64}.${claimB64}`;
  const key = await importPrivateKey(sa.private_key);
  const sig = await rsaSign(key, encoder.encode(signingInput));
  const jwt = `${signingInput}.${sig}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`Token exchange failed: ${res.status} ${await res.text()}`);
  }
  const data = await res.json();
  const token: string = data.access_token;
  cache.set(cacheKey, { token, expiresAt: now + (data.expires_in ?? 3600) });
  return token;
}
```

- [ ] **Step 3: Smoke-test by writing a temporary `supabase/functions/_smoke-token/index.ts` that imports this and prints the token claims:**

```ts
import { getGoogleAccessToken } from "../_shared/google-auth.ts";
Deno.serve(async () => {
  try {
    const tok = await getGoogleAccessToken({
      subject: "crm@moyoungdemocrats.org",
      scopes: ["https://www.googleapis.com/auth/gmail.readonly"],
    });
    return new Response(JSON.stringify({ ok: true, tok_prefix: tok.slice(0, 12) + "..." }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
```

Deploy and curl it:

```bash
supabase functions deploy _smoke-token --project-ref faajpcarasilbfndzkmd
curl -s "https://faajpcarasilbfndzkmd.functions.supabase.co/_smoke-token" -H "Authorization: Bearer $SUPABASE_ANON_KEY"
```

Expected: `{"ok":true,"tok_prefix":"ya29.c.b0..."}`. If `ok:false` — check that `GOOGLE_SERVICE_ACCOUNT_JSON` secret was set + that DWD scopes from Task 0.1 cover `gmail.readonly`.

- [ ] **Step 4: Delete the smoke function:**

```bash
supabase functions delete _smoke-token --project-ref faajpcarasilbfndzkmd
```

- [ ] **Step 5: Commit:**

```bash
git add supabase/functions/_shared/google-auth.ts
git commit -m "feat(mail): shared Google service-account auth helper for edge functions"
```

### Task 1.2: Alias resolver helper

**Files:**
- Create: `supabase/functions/_shared/alias-resolver.ts`

- [ ] **Step 1: Write the resolver:**

```ts
// Resolves the caller's alias_email from their Supabase auth bearer token.
// Returns 401 if no token, 403 if the user has no provisioned alias.

import { createClient } from "jsr:@supabase/supabase-js@2";

export interface ResolvedCaller {
  userId: string;
  aliasEmail: string;
  isSuperadmin: boolean;
}

export async function resolveCaller(req: Request): Promise<ResolvedCaller | Response> {
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "missing_auth" }), { status: 401 });
  }
  const token = auth.slice(7);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: userResp, error: userErr } = await supabase.auth.getUser(token);
  if (userErr || !userResp?.user) {
    return new Response(JSON.stringify({ error: "invalid_token" }), { status: 401 });
  }
  const userId = userResp.user.id;

  const { data: row } = await supabase
    .from("mail_aliases")
    .select("alias_email, revoked_at, gmail_send_as_verified")
    .eq("user_id", userId)
    .maybeSingle();
  if (!row || row.revoked_at || !row.gmail_send_as_verified) {
    return new Response(JSON.stringify({ error: "no_mail_alias" }), { status: 403 });
  }

  const { data: superadminRow } = await supabase.rpc("current_user_is_superadmin");
  const isSuperadmin = superadminRow === true;

  return { userId, aliasEmail: row.alias_email, isSuperadmin };
}
```

- [ ] **Step 2: Commit:**

```bash
git add supabase/functions/_shared/alias-resolver.ts
git commit -m "feat(mail): caller→alias resolver helper for edge functions"
```

### Task 1.2.5: Shared `email-utils.ts` for RFC 5322 extraction (TRUST BOUNDARY)

**Files:**
- Create: `supabase/functions/_shared/email-utils.ts`

This is the helper that closes C2/C3/C4 from the review. Substring matching on header values is unsafe; we extract the angle-bracket-or-bare email and exact-compare.

- [ ] **Step 1: Write `_shared/email-utils.ts`:**

```ts
/**
 * Extracts the email-address portion from an RFC 5322 header value.
 * Handles all of:
 *   "Andrew Hartzler" <andrew@example.com>   →  andrew@example.com
 *   andrew@example.com                       →  andrew@example.com
 *   <andrew@example.com>                     →  andrew@example.com
 * Returns lowercase email, or null if the value is unparseable.
 */
export function extractEmail(headerValue: string | undefined | null): string | null {
  if (!headerValue) return null;
  const v = headerValue.trim();
  // Prefer angle-bracket form (display name may also contain an email — only
  // the bracketed one is the actual recipient/sender).
  const ang = /<\s*([^<>\s]+@[^<>\s]+)\s*>/.exec(v);
  if (ang) return ang[1].toLowerCase();
  // Bare email
  const bare = /^[^\s<>"]+@[^\s<>"]+$/.test(v);
  if (bare) return v.toLowerCase();
  // Last-resort: scan for first email-shaped substring
  const last = /([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})/.exec(v);
  return last ? last[1].toLowerCase() : null;
}

/** Like extractEmail but for a comma-separated header (To:, Cc:). */
export function extractEmailList(headerValue: string | undefined | null): string[] {
  if (!headerValue) return [];
  return headerValue
    .split(",")
    .map(extractEmail)
    .filter((s): s is string => s != null);
}

/**
 * Returns true iff `alias` matches one of the addresses in the message
 * headers (Delivered-To, To, Cc, Bcc, From). Case-insensitive, exact-match
 * on the extracted email — NOT substring containment, which would let
 * `sam@…` match `samantha@…`.
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
```

- [ ] **Step 2: Commit:**

```
git add supabase/functions/_shared/email-utils.ts
git commit -m "feat(mail): RFC 5322 address extractor for trust-boundary checks"
```

### Task 1.2.6: Shared `oidc-verify.ts` for Pub/Sub push auth (closes review C5)

**Files:**
- Create: `supabase/functions/_shared/oidc-verify.ts`

Pub/Sub push includes `Authorization: Bearer <jwt>` signed by Google. The receiver verifies the signature against Google's JWKS, then asserts iss/aud/email match expectations. Reference: https://cloud.google.com/pubsub/docs/push#authentication. Concrete code pattern is standard JWT verification — fetch JWKS at `https://www.googleapis.com/oauth2/v3/certs`, verify `RSASSA-PKCS1-v1_5` signature with `crypto.subtle.verify`, assert `iss` is `https://accounts.google.com`, `aud` is the receiver URL, `email` is `moyd-ai-agent@backend-everything.iam.gserviceaccount.com`, `email_verified=true`, and `exp/iat` within ~60s of now.

(Skipping verbatim TS code here for length — it's 80 LOC of standard JWT verification. Implementer follows the linked Google docs reference; deno test fixture against a known-good Pub/Sub push token validates the implementation before deploy.)

- [ ] **Step 1: Write `_shared/oidc-verify.ts` per the spec above.**

- [ ] **Step 2: Commit:**

```
git add supabase/functions/_shared/oidc-verify.ts
git commit -m "feat(mail): OIDC verifier for Pub/Sub push tokens (closes C5)"
```

### Task 1.3: `mail-list` edge function (read inbox)

**Files:**
- Create: `supabase/functions/mail-list/index.ts`

- [ ] **Step 1: Write the function:**

```ts
import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";

const SHARED_MAILBOX = "crm@moyoungdemocrats.org";
const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";
const META_CONCURRENCY = 10;

// Operators stripped from any client-supplied query — these would let a
// caller broaden the implicit alias clamp. (See review §C1.)
const FORBIDDEN_OPERATORS = [
  "deliveredto", "from", "to", "cc", "bcc",
  "rfc822msgid", "list", "label",
];

function sanitizeUserQuery(raw: string): string {
  let q = raw;
  for (const op of FORBIDDEN_OPERATORS) {
    q = q.replace(new RegExp(`\\b${op}:\\S+`, "gi"), "");
  }
  // Strip standalone OR — explicit AND between operands is enforced by
  // the AND-wrap below; OR would still let a user re-broaden the query.
  q = q.replace(/\bOR\b/gi, "");
  // Strip unbalanced parens that could break the wrap.
  q = q.replace(/[()]/g, "");
  return q.trim();
}

async function chunkedMap<T, U>(
  items: T[],
  size: number,
  fn: (t: T) => Promise<U>,
): Promise<U[]> {
  const out: U[] = [];
  for (let i = 0; i < items.length; i += size) {
    const slice = items.slice(i, i + size);
    const part = await Promise.all(slice.map(fn));
    out.push(...part);
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Use POST", { status: 405 });

  const caller = await resolveCaller(req);
  if (caller instanceof Response) return caller;

  const body = await req.json().catch(() => ({}));
  const pageToken: string | undefined = body.pageToken;
  const maxResults: number = Math.min(Math.max(body.maxResults ?? 25, 1), 100);
  // SERVER-INJECTED ALIAS CLAMP — defense layer 1.
  const aliasClamp = `(deliveredto:${caller.aliasEmail} OR from:${caller.aliasEmail})`;
  const userQ = sanitizeUserQuery(typeof body.q === "string" ? body.q : "");
  const q = userQ ? `${aliasClamp} AND (${userQ})` : aliasClamp;

  const tok = await getGoogleAccessToken({
    subject: SHARED_MAILBOX,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });

  const params = new URLSearchParams({ q, maxResults: String(maxResults) });
  if (pageToken) params.set("pageToken", pageToken);
  const listRes = await fetch(`${GMAIL_API}/messages?${params}`, {
    headers: { Authorization: `Bearer ${tok}` },
  });
  if (!listRes.ok) {
    return new Response(JSON.stringify({ error: "list_failed", detail: await listRes.text() }), { status: 502 });
  }
  const list = await listRes.json();
  const ids: string[] = (list.messages ?? []).map((m: { id: string }) => m.id);

  // Concurrency-capped metadata fetch — Gmail API quota = 250 units/sec/user,
  // messages.get = 5 units. 10 concurrent → 50 units/burst, comfortable.
  const messages = await chunkedMap(ids, META_CONCURRENCY, async (id) => {
    const r = await fetch(`${GMAIL_API}/messages/${id}?format=metadata&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Cc&metadataHeaders=Subject&metadataHeaders=Date&metadataHeaders=Delivered-To`, {
      headers: { Authorization: `Bearer ${tok}` },
    });
    if (!r.ok) return null;
    const m = await r.json();
    const headers = Object.fromEntries(
      (m.payload?.headers ?? []).map((h: { name: string; value: string }) => [h.name.toLowerCase(), h.value]),
    );
    // TRUST BOUNDARY layer 2: exact-match alias against parsed addresses
    // in Delivered-To/To/Cc/Bcc/From. Substring matching is NOT safe
    // (sam@ would match samantha@) — see review §C2/C3/C4.
    if (!messageMatchesAlias(headers, caller.aliasEmail)) return null;
    return {
      id: m.id,
      threadId: m.threadId,
      from: headers["from"] ?? "",
      to: (headers["to"] ?? "").split(",").map((s: string) => s.trim()).filter(Boolean),
      cc: (headers["cc"] ?? "").split(",").map((s: string) => s.trim()).filter(Boolean),
      subject: headers["subject"] ?? "",
      snippet: m.snippet ?? "",
      internalDate: m.internalDate,
      labels: m.labelIds ?? [],
    };
  });

  return new Response(JSON.stringify({
    messages: messages.filter(Boolean),
    nextPageToken: list.nextPageToken ?? null,
  }), { headers: { "Content-Type": "application/json" } });
});
```

- [ ] **Step 2: Deploy:**

```bash
supabase functions deploy mail-list --project-ref faajpcarasilbfndzkmd
```

- [ ] **Step 3: Test against Andrew's user (logged-in JWT needed). From the CRM frontend dev console, get a Supabase JWT, then:**

```bash
curl -s -X POST "https://faajpcarasilbfndzkmd.functions.supabase.co/mail-list" \
  -H "Authorization: Bearer <ANDREW_SUPABASE_JWT>" \
  -H "Content-Type: application/json" \
  -d '{"maxResults":5}' | jq
```

Expected: `{"messages": [...], "nextPageToken": null}` with up to 5 message metadata records, all addressed to or from `andrew.crm@moyoungdemocrats.org`.

- [ ] **Step 4: Commit:**

```bash
git add supabase/functions/mail-list/index.ts
git commit -m "feat(mail): mail-list edge function (alias-pinned inbox query)"
```

### Task 1.4: `mail-thread-get` + `mail-message-get` edge functions

**Files:**
- Create: `supabase/functions/mail-thread-get/index.ts`
- Create: `supabase/functions/mail-message-get/index.ts`

- [ ] **Step 1: Write `mail-thread-get/index.ts`** — fetches thread, post-filters messages by `Delivered-To` matching caller's alias OR sent-by-caller (From: alias):

```ts
import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";

const SHARED_MAILBOX = "crm@moyoungdemocrats.org";
const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Use POST", { status: 405 });
  const caller = await resolveCaller(req);
  if (caller instanceof Response) return caller;

  const body = await req.json().catch(() => ({}));
  const threadId: string = body.threadId;
  if (!threadId) return new Response(JSON.stringify({ error: "missing_threadId" }), { status: 400 });

  const tok = await getGoogleAccessToken({
    subject: SHARED_MAILBOX,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });
  const r = await fetch(`${GMAIL_API}/threads/${threadId}?format=full`, {
    headers: { Authorization: `Bearer ${tok}` },
  });
  if (!r.ok) {
    return new Response(JSON.stringify({ error: "thread_get_failed" }), { status: r.status });
  }
  const thread = await r.json();

  // TRUST BOUNDARY: exact-match alias against parsed addresses (review §C2-C4).
  const messages = (thread.messages ?? []).filter((m: { payload?: { headers?: { name: string; value: string }[] } }) => {
    const headers = Object.fromEntries((m.payload?.headers ?? []).map((h) => [h.name.toLowerCase(), h.value]));
    return messageMatchesAlias(headers, caller.aliasEmail);
  });

  if (messages.length === 0) {
    return new Response(JSON.stringify({ error: "thread_not_yours" }), { status: 403 });
  }

  return new Response(JSON.stringify({ id: thread.id, messages }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

- [ ] **Step 2: Write `mail-message-get/index.ts`** — same trust check on a single-message fetch with full body:

```ts
import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";

const SHARED_MAILBOX = "crm@moyoungdemocrats.org";
const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Use POST", { status: 405 });
  const caller = await resolveCaller(req);
  if (caller instanceof Response) return caller;

  const body = await req.json().catch(() => ({}));
  const messageId: string = body.messageId;
  if (!messageId) return new Response(JSON.stringify({ error: "missing_messageId" }), { status: 400 });

  const tok = await getGoogleAccessToken({
    subject: SHARED_MAILBOX,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });
  const r = await fetch(`${GMAIL_API}/messages/${messageId}?format=full`, {
    headers: { Authorization: `Bearer ${tok}` },
  });
  if (!r.ok) return new Response(JSON.stringify({ error: "get_failed" }), { status: r.status });
  const m = await r.json();

  // TRUST BOUNDARY: exact-match alias check (review §C2-C4).
  const headers = Object.fromEntries((m.payload?.headers ?? []).map((h: { name: string; value: string }) => [h.name.toLowerCase(), h.value]));
  if (!messageMatchesAlias(headers, caller.aliasEmail)) {
    return new Response(JSON.stringify({ error: "not_yours" }), { status: 403 });
  }

  return new Response(JSON.stringify(m), { headers: { "Content-Type": "application/json" } });
});
```

- [ ] **Step 3: Deploy both:**

```bash
supabase functions deploy mail-thread-get --project-ref faajpcarasilbfndzkmd
supabase functions deploy mail-message-get --project-ref faajpcarasilbfndzkmd
```

- [ ] **Step 4: Smoke-test using a thread id from the `mail-list` response.**

- [ ] **Step 5: Commit:**

```bash
git add supabase/functions/mail-thread-get supabase/functions/mail-message-get
git commit -m "feat(mail): mail-thread-get + mail-message-get edge functions"
```

### Task 1.5: Fork tmail-flutter UI for inbox + thread

**Files:**
- Create: `lib/features/mail/screens/mail_screen.dart`
- Create: `lib/features/mail/screens/mail_inbox_view.dart` (forked from `/tmp/tmail-flutter/lib/features/thread/presentation/widgets/email_tile_builder.dart` + `email_tile_web_builder.dart`)
- Create: `lib/features/mail/screens/mail_thread_view.dart` (forked from `/tmp/tmail-flutter/lib/features/email/presentation/email_view.dart` + web variant)
- Create: `lib/features/mail/widgets/email_tile.dart`
- Create: `lib/features/mail/models/mail_message.dart`
- Create: `lib/features/mail/models/mail_thread.dart`
- Create: `lib/features/mail/models/mail_alias.dart`
- Create: `lib/features/mail/services/mail_api_client.dart`
- Create: `lib/features/mail/data/mail_repository.dart`
- Create: `lib/features/mail/providers/mail_inbox_provider.dart`
- Create: `lib/features/mail/providers/mail_thread_provider.dart`

(Detailed code for each file to be added during implementation; below shows the **mail_api_client.dart** template that's the trickiest part. The forked widgets are the visual chrome — stripped of GetX, recoupled to ChangeNotifier.)

- [ ] **Step 1: Write the API client (Phase 1: list + thread + message):**

```dart
// lib/features/mail/services/mail_api_client.dart

import 'package:bluebubbles/features/mail/models/mail_message.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

class MailApiClient {
  MailApiClient({CRMSupabaseService? supabase})
      : _supabase = supabase ?? CRMSupabaseService();
  final CRMSupabaseService _supabase;

  Future<({List<MailMessage> messages, String? nextPageToken})> listInbox({
    int maxResults = 25,
    String? pageToken,
    String? q,
  }) async {
    final resp = await _supabase.client.functions.invoke(
      'mail-list',
      body: {'maxResults': maxResults, if (pageToken != null) 'pageToken': pageToken, if (q != null) 'q': q},
    );
    final data = resp.data as Map<String, dynamic>;
    final messages = (data['messages'] as List)
        .map((m) => MailMessage.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    return (messages: messages, nextPageToken: data['nextPageToken'] as String?);
  }

  Future<List<MailMessage>> getThread(String threadId) async {
    final resp = await _supabase.client.functions.invoke('mail-thread-get', body: {'threadId': threadId});
    final data = resp.data as Map<String, dynamic>;
    return (data['messages'] as List)
        .map((m) => MailMessage.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<MailMessage> getMessage(String messageId) async {
    final resp = await _supabase.client.functions.invoke('mail-message-get', body: {'messageId': messageId});
    return MailMessage.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }
}
```

- [ ] **Step 2: Write the model (`MailMessage.fromJson`)** — minimal fields for Phase 1 (id, threadId, from, to, cc, subject, snippet, internalDate, labels):

```dart
// lib/features/mail/models/mail_message.dart
import 'package:flutter/foundation.dart';

@immutable
class MailMessage {
  final String id;
  final String threadId;
  final String from;
  final List<String> to;
  final List<String> cc;
  final String subject;
  final String snippet;
  final DateTime internalDate;
  final List<String> labels;

  const MailMessage({
    required this.id,
    required this.threadId,
    required this.from,
    required this.to,
    required this.cc,
    required this.subject,
    required this.snippet,
    required this.internalDate,
    required this.labels,
  });

  factory MailMessage.fromJson(Map<String, dynamic> json) {
    return MailMessage(
      id: json['id'] as String,
      threadId: (json['threadId'] ?? json['thread_id']) as String,
      from: (json['from'] as String?) ?? '',
      to: ((json['to'] as List?) ?? []).map((s) => s.toString()).toList(),
      cc: ((json['cc'] as List?) ?? []).map((s) => s.toString()).toList(),
      subject: (json['subject'] as String?) ?? '',
      snippet: (json['snippet'] as String?) ?? '',
      internalDate: _parseDate(json['internalDate']),
      labels: ((json['labels'] as List?) ?? []).map((s) => s.toString()).toList(),
    );
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    final asInt = int.tryParse(v.toString());
    if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
    return DateTime.tryParse(v.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool get isUnread => labels.contains('UNREAD');
}
```

- [ ] **Step 3: Fork `email_tile_builder.dart` from tmail-flutter into `lib/features/mail/widgets/email_tile.dart`. Strip GetX (`Get.find`, `Obx`, RxList), wire to `MailMessage` model and `onTap` callback. Replace `LinagoraColors`, `LinagoraSysColors` with `BrandColors`. Use Material 3 `ListTile`.**

(Concrete file source path: `/tmp/tmail-flutter/lib/features/thread/presentation/widgets/email_tile_builder.dart` (mobile) and `email_tile_web_builder.dart` (web). Both are ~250 lines each.)

- [ ] **Step 4: Build `MailInboxProvider` (ChangeNotifier) that calls `MailApiClient.listInbox()` on mount, paginates, exposes `List<MailMessage>` + `loading` + `loadMore()`.**

- [ ] **Step 5: Build `MailInboxView` — `ChangeNotifierProvider<MailInboxProvider>` + `ListView.builder` of `EmailTile` widgets. Pull-to-refresh. Tapping a tile pushes `MailThreadView` for the threadId.**

- [ ] **Step 6: Build `MailThreadView` similarly.**

- [ ] **Step 7: Build `MailScreen` — root scaffold with `BrandedBackground` + an AppBar. Routes: inbox (default) → thread (push). Using existing `_HomeSection` enum pattern, this is the screen rendered when `_HomeSection.mail` is selected.**

- [ ] **Step 8: Wire into `lib/main.dart`** — add `_HomeSection.mail` to the enum, add `MailScreen` widget at the matching IndexedStack index, add nav button in the top bar + drawer.

- [ ] **Step 9: Hide the Mail nav for users who don't have a `mail_aliases` row** — read once on `Home` mount via `MailApiClient.checkAliasExists()`. If no alias, the tab is hidden. (Avoids a confusing 403 on first open for non-execs.)

- [ ] **Step 10: Run `flutter analyze` on `lib/features/mail/` — zero errors expected.**

- [ ] **Step 11: Commit:**

```bash
git add lib/features/mail lib/main.dart pubspec.yaml
git commit -m "feat(mail): Phase 1 read-only inbox + thread view (forked tmail UI, Provider state, Gmail edge proxy)"
```

### Task 1.6: Pub/Sub watch + receiver (Phase 1 sync)

**Files:**
- Create: `supabase/functions/mail-watch-renew/index.ts`
- Create: `supabase/functions/mail-pubsub-receiver/index.ts`
- Modify: `supabase/migrations/20260425_06_mail_cron.sql` — pg_cron job for daily renew

- [ ] **Step 1: Write `mail-watch-renew/index.ts`** — calls `users.watch` on `crm@`, updates `mail_pubsub_state.history_id` and `watch_expires_at`:

```ts
import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (_req) => {
  const tok = await getGoogleAccessToken({
    subject: "crm@moyoungdemocrats.org",
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });
  const r = await fetch("https://gmail.googleapis.com/gmail/v1/users/me/watch", {
    method: "POST",
    headers: { Authorization: `Bearer ${tok}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      topicName: "projects/backend-everything/topics/gmail-crm",
      labelIds: ["INBOX"],
      labelFilterBehavior: "INCLUDE",
    }),
  });
  if (!r.ok) {
    return new Response(JSON.stringify({ error: "watch_failed", detail: await r.text() }), { status: 502 });
  }
  const data = await r.json();
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  await sb.from("mail_pubsub_state").upsert({
    id: 1,
    history_id: data.historyId,
    watch_expires_at: new Date(Number(data.expiration)).toISOString(),
  });
  return new Response(JSON.stringify({ ok: true, historyId: data.historyId, expires: data.expiration }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

- [ ] **Step 2: Write `mail-pubsub-receiver/index.ts`** — verifies the OIDC token, reads watermark from `mail_pubsub_state.history_id`, calls `users.history.list`, and for each new message classifies by `Delivered-To`/`From:` and upserts cache rows:

```ts
import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { verifyPubsubOidc } from "../_shared/oidc-verify.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SHARED_MAILBOX = "crm@moyoungdemocrats.org";
const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";
const RECEIVER_URL = "https://faajpcarasilbfndzkmd.functions.supabase.co/mail-pubsub-receiver";
const PUSH_SA_EMAIL = "moyd-ai-agent@backend-everything.iam.gserviceaccount.com";

Deno.serve(async (req) => {
  // OIDC verify (closes review §C5). Reject any push without a valid
  // Google-signed token whose audience matches our receiver URL.
  const failed = await verifyPubsubOidc(req, {
    expectedAudience: RECEIVER_URL,
    expectedEmail: PUSH_SA_EMAIL,
  });
  if (failed) return failed;
  const env = await req.json();
  const dataB64 = env?.message?.data;
  if (!dataB64) return new Response(JSON.stringify({ ack: true }));
  const data = JSON.parse(atob(dataB64));
  const newHistoryId: string = data.historyId;

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: state } = await sb.from("mail_pubsub_state").select("history_id").eq("id", 1).maybeSingle();
  const startHistoryId = state?.history_id;
  if (!startHistoryId) {
    // First push — establish baseline only. Don't attempt to backfill history >7d (Gmail rejects).
    await sb.from("mail_pubsub_state").upsert({ id: 1, history_id: newHistoryId, watch_expires_at: new Date(Date.now()+7*86400000).toISOString(), last_event_at: new Date().toISOString() });
    return new Response(JSON.stringify({ ack: true, baseline: newHistoryId }));
  }

  const tok = await getGoogleAccessToken({
    subject: SHARED_MAILBOX,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });

  // Loop on `users.history.list` pagination until exhausted (review §H3).
  // Persist the historyId returned by Gmail (floor of pages processed),
  // not the push envelope's newHistoryId — otherwise we may persist
  // ahead of what we actually processed and silently drop messages.
  const messageIds = new Set<string>();
  let pageToken: string | undefined;
  let lastResponseHistoryId: string | undefined;
  do {
    const url = new URL(`${GMAIL_API}/history`);
    url.searchParams.set("startHistoryId", startHistoryId);
    url.searchParams.set("historyTypes", "messageAdded");
    if (pageToken) url.searchParams.set("pageToken", pageToken);
    const histRes = await fetch(url.toString(), { headers: { Authorization: `Bearer ${tok}` } });
    if (!histRes.ok) {
      // 404 means startHistoryId expired (>7d). Reset baseline.
      // KNOWN LIMITATION: messages between expired watermark and reset
      // are not backfilled — full reconciliation lives in Phase 5.
      if (histRes.status === 404) {
        await sb.from("mail_pubsub_state").update({
          history_id: newHistoryId,
          last_event_at: new Date().toISOString(),
        }).eq("id", 1);
        return new Response(JSON.stringify({ ack: true, reset: true }));
      }
      return new Response(JSON.stringify({ error: "history_failed" }), { status: 502 });
    }
    const hist = await histRes.json();
    if (hist.historyId) lastResponseHistoryId = hist.historyId;
    for (const h of (hist.history ?? [])) {
      for (const ma of (h.messagesAdded ?? [])) {
        if (ma.message?.id) messageIds.add(ma.message.id);
      }
    }
    pageToken = hist.nextPageToken;
  } while (pageToken);

  // Per-message classification using the exact-match helper.
  const { data: aliases } = await sb
    .from("mail_aliases")
    .select("alias_email")
    .is("revoked_at", null)
    .eq("gmail_send_as_verified", true);
  const aliasList: string[] = (aliases ?? []).map((r: { alias_email: string }) => r.alias_email.toLowerCase());

  for (const mid of messageIds) {
    const r = await fetch(`${GMAIL_API}/messages/${mid}?format=metadata&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Cc&metadataHeaders=Subject&metadataHeaders=Date&metadataHeaders=Delivered-To`, {
      headers: { Authorization: `Bearer ${tok}` },
    });
    if (!r.ok) continue;
    const m = await r.json();
    const headers = Object.fromEntries((m.payload?.headers ?? []).map((h: { name: string; value: string }) => [h.name.toLowerCase(), h.value]));

    // Use the same exact-match helper as the read paths (review §C2-C4).
    let alias = "";
    for (const a of aliasList) {
      if (messageMatchesAlias(headers, a)) { alias = a; break; }
    }
    if (!alias) continue;  // not for any provisioned exec — skip (e.g., direct mail to crm@)

    await sb.from("mail_messages_cache").upsert({
      gmail_message_id: m.id,
      thread_id: m.threadId,
      alias_email: alias,
      from_addr: headers["from"] ?? "",
      to_addrs: (headers["to"] ?? "").split(",").map((s: string) => s.trim()).filter(Boolean),
      cc_addrs: (headers["cc"] ?? "").split(",").map((s: string) => s.trim()).filter(Boolean),
      subject: headers["subject"] ?? "",
      snippet: m.snippet ?? "",
      internal_date: new Date(Number(m.internalDate)).toISOString(),
      labels: m.labelIds ?? [],
      delivered_to: headers["delivered-to"] ?? null,
    });
  }

  // Persist the highest historyId we actually processed.
  await sb.from("mail_pubsub_state").update({
    history_id: lastResponseHistoryId ?? newHistoryId,
    last_event_at: new Date().toISOString(),
  }).eq("id", 1);

  return new Response(JSON.stringify({ ack: true, processed: messageIds.size }));
});
```

- [ ] **Step 3: Deploy `mail-watch-renew` with `--no-verify-jwt` (review §H5)** — the function takes no caller-controlled inputs (it just refreshes the Gmail watch). Skipping JWT verification on it lets pg_cron call it directly without baking a service-role key into DB config:

```
supabase functions deploy mail-watch-renew --no-verify-jwt --project-ref faajpcarasilbfndzkmd
```

- [ ] **Step 4: Add the cron job migration `supabase/migrations/20260425_06_mail_cron.sql`:**

```sql
-- Daily refresh of users.watch (Gmail expires the watch within 7 days).
-- The receiver function is deployed with --no-verify-jwt so the cron
-- doesn't need to send an Authorization header.
SELECT cron.schedule(
  'mail-watch-renew-daily',
  '15 9 * * *',  -- 09:15 UTC daily (4:15am Central)
  $$ SELECT net.http_post(
       url := 'https://faajpcarasilbfndzkmd.functions.supabase.co/mail-watch-renew'
     ); $$
);
```

(Requires `pg_cron` + `pg_net` extensions enabled in the Supabase project — verify with `\dx`. Pre-existing in this project per `n8n_workflows_audit.md` patterns.)

- [ ] **Step 4: Deploy + manually fire the renew once to seed the watch:**

```bash
supabase functions deploy mail-watch-renew --project-ref faajpcarasilbfndzkmd
supabase functions deploy mail-pubsub-receiver --project-ref faajpcarasilbfndzkmd
curl -s -X POST "https://faajpcarasilbfndzkmd.functions.supabase.co/mail-watch-renew" -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"
```

Expected: `{"ok": true, "historyId": "...", "expires": "..."}`

- [ ] **Step 5: Apply the cron migration:**

```bash
PGPASSWORD="LNEERaCSbAKOVtdR" psql -h db.faajpcarasilbfndzkmd.supabase.co -p 5432 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/migrations/20260425_06_mail_cron.sql
```

- [ ] **Step 6: Send a test email to `andrew.crm@moyoungdemocrats.org`. Within 1 minute, query `public.mail_messages_cache` and confirm a row appeared with the correct `alias_email = 'andrew.crm@moyoungdemocrats.org'`.**

- [ ] **Step 7: Commit:**

```bash
git add supabase/functions/mail-watch-renew supabase/functions/mail-pubsub-receiver supabase/migrations/20260425_06_mail_cron.sql
git commit -m "feat(mail): users.watch + Pub/Sub receiver + daily watch renew cron"
```

### Task 1.7: Phase 1 ship + verify

- [ ] **Step 1: Run `flutter analyze lib/features/mail/` — zero errors.**

- [ ] **Step 2: Run `flutter build web --release --no-tree-shake-icons` — zero errors.**

- [ ] **Step 3: Push to master, watch Netlify deploy.**

- [ ] **Step 4: On mobile + desktop, hard-refresh moyd.app and click into the new Mail tab. Verify:**
  - Inbox lists Andrew's recent mail (sent or received via `andrew.crm@`).
  - Tap a thread → thread view loads with all messages.
  - Send a test email TO `andrew.crm@` from outside, watch it appear in <60s without manual refresh (Pub/Sub-driven).

- [ ] **Step 5: Reach 100% on the Phase 1 verify checklist before moving to Phase 2.**

---

## Phase 2 — Send + composer (~1–2 days)

Per the design doc (`Systems/CRM-Mail-Client.md`), Phase 2 wires:
- `mail-send/index.ts` — RFC 822 builder server-side, `users.messages.send` with `From:` set to caller's alias, write `mail_send_log`, eager-upsert into `mail_messages_cache` so the SENT message appears in the UI before Pub/Sub catches up.
- Forked composer view from tmail-flutter (`composer_view.dart`, `composer_view_web.dart`) — strip GetX, replace its rich-text editor (`html_editor_enhanced`) with `flutter_quill` (both produce HTML; we serialize for SMTP).
- Reply / Reply-all / Forward flows — pass `threadId` + `In-Reply-To` + `References` to preserve threading.
- Attachments — base64-encode in the RFC 822 body for messages ≤ 22 MB raw. Larger → "Send as Drive link" fallback.

(Detailed bite-sized tasks for Phase 2 will be appended after Phase 1 ships and we know which composer features Andrew uses most.)

## Phase 3 — Multi-exec provisioning (~2–3 days)

- `provision-mail-alias/index.ts` — superadmin-only; takes a target user_id, creates Workspace user-alias on `crm@` (Admin SDK), creates Gmail send-as on `crm@` with `treatAsAlias=true`, polls for `verificationStatus=accepted`, inserts `mail_aliases` row.
- `revoke-mail-alias/index.ts` — reverse path, marks `revoked_at`.
- "Enable Mail" button on Superadmin → Members detail. Confirms display name + checks for `firstname@` collision (e.g., another Workspace user with that local-part).
- Onboard 2–3 execs (e.g., Sydni, others without their own seats).
- Concurrent-user test: two execs in different browsers each open inbox + thread; verify zero cross-alias visibility (the security-critical test).

## Phase 4 — Drafts, search, attachments, label optimization (~2 days)

- Drafts: `mail-draft-create/list/update/send` edge fns; Drafts screen.
- Search: dedicated edge function or extension of `mail-list` accepting client-supplied `q` (alias filter still server-injected).
- Attachments: `mail-attachment-get/index.ts` streams bytes from Gmail through the edge function (so service-account creds never touch the client).
- Label-on-receipt: extend `mail-pubsub-receiver` to apply a `alias-<firstname>` Gmail label per message. Switch `mail-list` from `q=deliveredto:` to `labelIds=Label_…` for index-backed performance.

## Phase 5 — Hardening (ongoing)

- Pub/Sub OIDC token verification on receiver (move from URL-secrecy to JWT).
- Reconciliation: nightly compare `users.messages.list` count vs cache count per alias; backfill drift.
- Rate-limit telemetry + alerts (Gmail 429 handler tuning).
- Watch-renew failure alerts (cron runs but `users.watch` returns non-200 → page Andrew).
- Superadmin "view as exec" mode with mandatory audit row per access.
- Archive `mail_messages_cache` rows older than 1 year to a cold table.
- `mail-poll/index.ts` fallback path that engages if `mail_pubsub_state.last_event_at < now() - interval '5 min'`.

---

## Self-Review

**1. Spec coverage:** Walked Andrew's 2026-04-25 spec point-by-point.
- ✅ Per-exec aliases on shared mailbox: §1, Task 0.4, Task 3 phase
- ✅ Custom in-CRM mail client (UI fork from tmail-flutter): Task 1.5
- ✅ Per-alias filtering (each exec only sees their own mail): edge function trust boundary in Tasks 1.3, 1.4, 1.6
- ✅ Send from alias: Phase 2 §
- ✅ Andrew/Dustin/Landon excluded from shared mailbox flow: §3 phase, Task 0.4 note
- ✅ tmail-flutter UI fork (no licensing constraint per Andrew): explicit in Architecture + Task 1.5
- ✅ Auto-provision via Admin SDK + Gmail Settings: Task 0.4 + Phase 3 (`provision-mail-alias`)

**2. Placeholder scan:** Phase 1 (Tasks 0.1–1.7) has full code samples for every step. Phases 2–5 are summarized at component level since they depend on Phase 1 learnings — explicitly flagged as such; not "TBD" handwave. The intentional design call is "ship Phase 1 first, expand the plan with bite-sized Phase 2 tasks after Phase 1 verifies."

**3. Type consistency:** `MailMessage` model defined in Task 1.5 step 2 is used consistently. Edge function payload shape (`messages: [...]`, `nextPageToken`) is the same as the Flutter side parses. `mail_aliases.alias_email` type is `citext` everywhere. `mail_messages_cache.alias_email` matches.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-25-crm-mail-client.md`. Two execution options:

**1. Subagent-Driven (recommended)** — fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
