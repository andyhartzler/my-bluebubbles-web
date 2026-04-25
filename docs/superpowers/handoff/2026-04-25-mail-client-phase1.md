# Handoff brief — CRM Mail Client, Phase 1 entry

**For:** a fresh Claude Code session in `/Users/moyd/my-bluebubbles-web` picking this up cold.
**Goal:** execute Phase 1 of the per-exec Gmail mail client (read-only inbox for Andrew only, validates the trust boundary + sync pipeline) per the plan at `docs/superpowers/plans/2026-04-25-crm-mail-client.md`.

## What's already done

- Plan v2.1 written + reviewed by `code-reviewer` agent + patched. Read it end-to-end before writing any code: `/Users/moyd/my-bluebubbles-web/docs/superpowers/plans/2026-04-25-crm-mail-client.md`. The "Plan v2.1 — Review fixes applied 2026-04-25" section near the top enumerates every CRITICAL/HIGH/MEDIUM/LOW finding that was patched. Verify each is actually applied in the code blocks before deploying.
- Design doc lives in Obsidian at `Systems/CRM-Mail-Client.md` (`/Users/moyd/Desktop/MOYD/MOYD Obsidian/Systems/CRM-Mail-Client.md`).
- **Task 0.1 (DWD scopes) is DONE** — Andrew confirmed on 2026-04-25 13:15 CDT. The five scopes added at admin.google.com on service-account client `114261141581576499255` are: `admin.directory.user.alias`, `gmail.modify`, `gmail.settings.basic`, `gmail.settings.sharing`, `gmail.labels`. Verify by impersonating `crm@moyoungdemocrats.org` and calling `users.settings.sendAs.list` per the plan's verification snippet.

## Start here

Phase 1 task 0.2 — set up GCP Pub/Sub topic + push subscription. Then 0.3 (schema migration), 0.4 (manually provision Andrew's `andrew.crm@` test alias), 1.1 → 1.7 (edge functions + forked Flutter UI + ship).

## Critical context

### Repo + deploy
- Repo: `/Users/moyd/my-bluebubbles-web` (Flutter web/mobile, branch = `master`). Pushes to master auto-deploy to moyd.app via Netlify (~5 min builds; flag is `--release --no-tree-shake-icons` per `netlify-build.sh:174`).
- Backend: Supabase project `faajpcarasilbfndzkmd`. Edge Functions are Deno + TypeScript.

### Secrets — ALWAYS check Obsidian first
Master plaintext secrets file: `/Users/moyd/Desktop/MOYD/MOYD Obsidian/Credentials-and-Secrets.md`. Has:
- Supabase DB password (you'll need it: `LNEERaCSbAKOVtdR`, host `db.faajpcarasilbfndzkmd.supabase.co:5432`, user `postgres`)
- Supabase CLI access token (`SUPABASE_ACCESS_TOKEN=sbp_...`)
- Service account key path: `/Users/moyd/Desktop/MOYD/backend-everything-a599411a62b5.json` — its full contents are what you'll set as `GOOGLE_SERVICE_ACCOUNT_JSON` Supabase secret in Task 1.1
- The shared workspace mailbox: `crm@moyoungdemocrats.org` / `qoqxyn-cubgaw-zIzko5` (only needed for manual Gmail-side debugging; the code never touches the password)

If a credential isn't in that file, ASK Andrew once and add it to the file as part of the response.

### Andrew's standing rules (from `/Users/moyd/.claude/projects/-Users-moyd/memory/MEMORY.md`)
1. **Reply on Telegram, not terminal.** He pairs from Telegram (chat_id `8527233756`). Terminal text doesn't reach him. Use `mcp__plugin_telegram_telegram__reply` (load via ToolSearch if not in initial schema).
2. **He has commit/push autonomy on MOYD repos** — don't ask permission for obvious next steps. Just commit and push.
3. **Autonomous execution preference.** Don't pause to confirm between obvious steps; just do the work.
4. **CONTRAST PET PEEVE.** Never ship a UI surface where text is hard to see. Verify contrast BEFORE picking colors. Specifically: never use `Theme.of(context).cardColor` on a branded surface (resolves to ~black on dark theme). For text on the navy/momentum gradient, use `Colors.white` for primary + `Colors.white.withOpacity(0.85)` for secondary.
5. **Supabase migrations:** the migration ledger is desynced (80+ remote migrations have no local files). Do NOT use `supabase db push --linked` — it'll be blocked. Apply migrations directly via psql: `PGPASSWORD="LNEERaCSbAKOVtdR" psql -h db.faajpcarasilbfndzkmd.supabase.co -p 5432 -U postgres -d postgres -v ON_ERROR_STOP=1 -f <migration.sql>`. Make sure `export PATH="/opt/homebrew/opt/libpq/bin:$PATH"` first.
6. **Schema search_path.** Default is `listmonk, extensions, public` — always prefix DDL with `public.`. NEVER drop the `listmonk` schema (PGRST002 cascade).

### License posture
Andrew explicitly waived AGPL concerns for tmail-flutter ("i dont give a fuck about lisnceing bull shit"). The plan forks tmail-flutter widget code into `lib/features/mail/`. This is internal-only org software for ~10 users; the FSF's stated interpretation protects internal use. Do not bring up licensing again.

### Naming convention
- Production aliases: `firstname@moyoungdemocrats.org` for every exec who doesn't have their own Workspace seat.
- **Andrew, Dustin, and Landon already have their own seats** — they're excluded from the shared-mailbox flow.
- For Phase 1 dev/testing, Andrew's alias is `andrew.crm@moyoungdemocrats.org` (avoids the conflict with his existing `andrew@` user account). This is documented in plan Task 0.4 as a one-off; the production provisioning flow in Phase 3 uses `firstname@` for everyone else.

### Reviewer findings already patched in plan v2.1
The `code-reviewer` agent found 5 CRITICAL + 6 HIGH issues. All baked into the plan; verify before deploying:
- C1: `mail-list` `q` sanitization strips `OR`/`to:`/`cc:`/`bcc:`/`rfc822msgid:`/`list:`/`label:` + wraps user `q` in parens with explicit AND.
- C2/C3/C4: New `_shared/email-utils.ts` with `extractEmail()` + `messageMatchesAlias()` exact-match. Used in mail-list, mail-thread-get, mail-message-get, and the receiver. Substring matching is gone.
- C5: New `_shared/oidc-verify.ts`. Receiver verifies Google-signed Pub/Sub OIDC token before processing.
- H1: `mail_threads_cache` deferred to Phase 2 (was being created but never written). Same for `attachments_summary`/`has_attachments` columns (deferred to Phase 4).
- H3: Receiver loops on `users.history.list` `nextPageToken`, persists `hist.historyId` from response not push envelope.
- H5: `mail-watch-renew` deployed with `--no-verify-jwt`; cron just hits the URL.
- M1: `current_user_alias()` STABLE SECURITY DEFINER scalar in migration; RLS policies use it.
- M5: Anchored regex on `mail_aliases.alias_email` CHECK.
- M6: `mail-list` chunks Gmail metadata fetches at concurrency 10.
- L6: `alias-resolver` requires `revoked_at IS NULL AND gmail_send_as_verified = true`. UI nav check should match.

### Recent context (today, 2026-04-25)
This is on top of two earlier ships today on the same branch:
- Commit `0465083d3` — Slack-style branded panel overhaul + brand-colored bodies + responsive 2-col + click-to-open everywhere + Activity panel (Meetings + Events) + Calendar tile + approve-button bug fix. Personalized Home Screen is now navy gradient surfaces with white text, shows on login at default `_HomeSection.home`.
- Commit `76896bd7e` (earlier) — first overhaul to navy header + white panel bodies (which Andrew rejected as "not the right vibe" — replaced by `0465083d3`).
- Commit `1ab36854c` (earlier still) — initial Slack-style overhaul + bug fixes (tab clickability, CST timezone, member name+photo on profile-changes auto items).

The mail client adds `_HomeSection.mail` as a NEW nav entry alongside the existing `home`/`dashboard`/`members`/`donors`/etc. — see plan File Structure for `lib/main.dart` patch.

### Existing infra hooks the plan reuses
- `auth.users.id == members.id` (verified 2026-04-24 audit)
- `current_user_is_superadmin()` SECURITY DEFINER function (shipped 2026-04-25, migration `20260424_01_audit_foundations.sql`)
- `is_staff()` SECURITY DEFINER function
- `fn_audit_log_trigger()` for audit trail
- `tg_set_updated_at()` BEFORE-UPDATE trigger pattern
- `BrandedBackground` + `BrandColors.tileGradient` + `BrandColors.sunriseGold` from `lib/features/committees/theme/brand_colors.dart`
- `BrandedPanel` + `BrandedHeaderTabBar` + `BrandedHeaderPillButton` from `lib/screens/crm/personalized_home/widgets/branded_panel.dart` (these wrap section cards in the brand language; the mail client's screens should reuse them)
- Service account `moyd-ai-agent@backend-everything.iam.gserviceaccount.com` with DWD; service account JSON at `/Users/moyd/Desktop/MOYD/backend-everything-a599411a62b5.json`

### Pattern conventions
- Edge functions: Deno + TS, use `import { createClient } from "jsr:@supabase/supabase-js@2";` for service-role calls. `_shared/` directory convention is supported (leading underscore = not deployable).
- Flutter state: Provider (matching the rest of the CRM). Do NOT introduce GetX even though tmail-flutter ships with it — strip it during the fork.
- Routing: native `MaterialPageRoute(builder: ...)` everywhere; no named routes in this codebase. Detail screens take typed objects (`MemberDetailScreen(member: Member)`, `MeetingDetailScreen(initialMeeting: Meeting)` etc.). Pattern is "fetch row by id then push" — see `activity_screen.dart:434-479` for the canonical example.

## What you should do FIRST when you start

1. Read this brief and the plan: `cat docs/superpowers/handoff/2026-04-25-mail-client-phase1.md docs/superpowers/plans/2026-04-25-crm-mail-client.md`.
2. Verify the DWD scopes are live by running the test snippet in plan Task 0.1 Step 5 from a terminal with the service-account JSON. Should return `OK 1 send-as entries`.
3. Reply to Andrew on Telegram acknowledging the handoff, restating the next concrete step, and confirming you've read the plan.
4. Start Phase 1 at Task 0.2 (gcloud Pub/Sub setup).

## Open questions / decisions deferred

None for Phase 1 — Andrew has signed off on the plan as patched. After Phase 1 ships and verifies, surface to him: which non-self-serving execs to onboard in Phase 3 (Sydni Jackson is currently the only `mail_aliases` candidate based on activity).
