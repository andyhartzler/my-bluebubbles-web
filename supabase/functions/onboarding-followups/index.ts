// ============================================================================
// onboarding-followups  (Member Poloooza rebuild — cron processor)
// ============================================================================
// Invoked every 10 min by pg_cron. Selects due onboarding_tasks
// (done=false AND run_after <= now()) and processes each:
//
//   slack_channel_sync   — look the member up in Slack (users.lookupByEmail).
//                          If present, invite to all target channels and mark
//                          done. If not present yet, reschedule (poll again
//                          later) until an attempt cap, then give up.
//   slack_join_reminder  — if the member is NOT in Slack, send the variant
//                          reminder email (verbatim, spec §5), threaded onto
//                          the welcome email. Mark done. If already in Slack,
//                          mark done with no send.
//
// Idempotent: each task is claimed by flipping a marker; already-done tasks are
// never reprocessed. Safe to run repeatedly.
//
// HARD GATING (ONBOARDING_MODE): same as member-onboard.
//   dry_run (DEFAULT) — no email, no Slack writes; logs what WOULD happen and
//                       still advances/rechedules tasks so the queue drains.
//   test              — reminder emails routed to ONBOARDING_TEST_EMAIL; no Slack.
//   live              — real reminders + real Slack channel invites.
//
// Auth: x-cron-secret == CRON_SECRET (pattern copied from slack-sync-to-slack).
// Deployed --no-verify-jwt.
// ============================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleCors, corsHeaders } from "../_shared/cors.ts";
import {
  getMode, testEmail, buildReminderEmail, sendGmail,
  slackLookupByEmail, slackInvite, EMAIL_RE, groupTargets, addMemberToGroup,
  type Variant,
} from "../_shared/onboarding.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SLACK_BOT_TOKEN = Deno.env.get("SLACK_BOT_TOKEN") || "";

const MAX_SYNC_ATTEMPTS = 12;   // ~ poll a joining member for up to several days
const SYNC_RETRY_MINUTES = 6 * 60;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}

interface TaskRow {
  id: string;
  member_id: string | null;
  task_type: string;
  attempts: number;
  meta: {
    variant?: Variant;
    email?: string;
    first_name?: string;
    targets?: string[];
    thread_id?: string | null;
  } | null;
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  // --- Auth: cron gate -----------------------------------------------------
  // Dedicated shared secret sent by the pg_cron job in the x-cron-secret header.
  // Falls back to the project-wide CRON_SECRET if that is what an operator sends.
  const onboardCron = Deno.env.get("ONBOARDING_CRON_SECRET") || "";
  const cronSecret = Deno.env.get("CRON_SECRET") || "";
  const presented = req.headers.get("x-cron-secret") || "";
  const ok =
    (onboardCron.length > 0 && presented === onboardCron) ||
    (cronSecret.length > 0 && presented === cronSecret);
  if (!ok) {
    return json({ error: "unauthorized" }, 401);
  }

  const mode = getMode();
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

  // --- Claim due tasks -----------------------------------------------------
  const nowIso = new Date().toISOString();
  const { data: due, error: dueErr } = await supabase
    .from("onboarding_tasks")
    .select("id, member_id, task_type, attempts, meta")
    .eq("done", false)
    .lte("run_after", nowIso)
    .order("run_after", { ascending: true })
    .limit(50);
  if (dueErr) return json({ error: "due query failed", detail: dueErr.message }, 500);

  const results: Record<string, unknown>[] = [];

  for (const t of (due || []) as TaskRow[]) {
    const meta = t.meta || {};
    const email = (meta.email || "").trim();
    const variant = (meta.variant || "general") as Variant;
    const first = meta.first_name || "there";
    const targets = meta.targets || [];
    const attempts = t.attempts + 1;
    const log: Record<string, unknown> = { task: t.id, type: t.task_type, member: t.member_id, mode };

    if (!email || !EMAIL_RE.test(email)) {
      await supabase.from("onboarding_tasks").update({ done: true, attempts }).eq("id", t.id);
      log.result = "no valid email — closed";
      results.push(log);
      continue;
    }

    // Determine Slack presence (only actually queried in live; test/dry treat
    // as "unknown/not joined" and never write to Slack).
    let inSlack = false;
    let slackUserId: string | undefined;
    if (mode === "live" && SLACK_BOT_TOKEN) {
      const look = await slackLookupByEmail(email, SLACK_BOT_TOKEN);
      inSlack = look.found;
      slackUserId = look.userId;
      log.slack_lookup = look.found ? `found ${look.userId}` : (look.error || "not found");
    } else {
      log.slack_lookup = `${mode}: skipped (assume not joined)`;
    }

    if (t.task_type === "slack_channel_sync") {
      if (mode === "live" && inSlack && slackUserId && SLACK_BOT_TOKEN) {
        const invited: string[] = [];
        for (const ch of targets) {
          const r = await slackInvite(ch, slackUserId, SLACK_BOT_TOKEN);
          invited.push(`${ch}:${r.success ? "ok" : r.error}`);
        }
        // Google Group parity: add member email to each mapped group (idempotent).
        const groupAdds = groupTargets(targets);
        const groups: string[] = [];
        for (const { group } of groupAdds) {
          const g = await addMemberToGroup(email, group);
          groups.push(`${group}:${g.action}${g.scopeError ? "(SCOPE_ERROR client-114261141581576499255)" : ""}`);
        }
        await supabase.from("onboarding_tasks").update({ done: true, attempts }).eq("id", t.id);
        log.result = "in Slack — invited + done";
        log.invites = invited;
        if (groups.length) log.group_adds = groups;
      } else if (attempts >= MAX_SYNC_ATTEMPTS) {
        await supabase.from("onboarding_tasks").update({ done: true, attempts }).eq("id", t.id);
        log.result = `not joined after ${attempts} polls — gave up`;
      } else {
        const next = new Date(Date.now() + SYNC_RETRY_MINUTES * 60_000).toISOString();
        await supabase.from("onboarding_tasks").update({ attempts, run_after: next }).eq("id", t.id);
        log.result = mode === "live" ? "not joined yet — reschedule" : `${mode}: no Slack write — reschedule`;
      }
      results.push(log);
      continue;
    }

    if (t.task_type === "slack_join_reminder") {
      if (mode === "live" && inSlack) {
        await supabase.from("onboarding_tasks").update({ done: true, attempts }).eq("id", t.id);
        log.result = "already in Slack — no reminder needed";
        results.push(log);
        continue;
      }
      // Not in Slack (or non-live): send the reminder (subject to mode).
      const built = buildReminderEmail(variant, first);
      const recipient = mode === "test" ? testEmail() : email;
      const ccList = mode === "test" ? [] : built.cc;
      if (mode === "dry_run") {
        await supabase.from("onboarding_tasks").update({ done: true, attempts }).eq("id", t.id);
        log.result = `DRY_RUN: would send ${variant} reminder to ${email}`;
      } else {
        if (mode === "test" && (!recipient || !EMAIL_RE.test(recipient))) {
          log.result = "ONBOARDING_TEST_EMAIL missing — left pending";
          results.push(log);
          continue;
        }
        try {
          const sent = await sendGmail({
            to: recipient, cc: ccList, subject: built.subject,
            html: built.html, text: built.text, threadId: meta.thread_id ?? null,
          });
          await supabase.from("onboarding_tasks").update({ done: true, attempts }).eq("id", t.id);
          log.result = `${mode.toUpperCase()}: sent ${variant} reminder to ${recipient} [msg ${sent.id}]`;
        } catch (e) {
          await supabase.from("onboarding_tasks").update({ attempts }).eq("id", t.id);
          log.result = `send failed (will retry): ${String(e)}`;
        }
      }
      results.push(log);
      continue;
    }

    // Unknown task type — close it so it doesn't loop forever.
    await supabase.from("onboarding_tasks").update({ done: true, attempts }).eq("id", t.id);
    log.result = `unknown task_type '${t.task_type}' — closed`;
    results.push(log);
  }

  return json({ ok: true, mode, processed: results.length, results });
});
