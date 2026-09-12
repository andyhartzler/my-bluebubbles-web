// ============================================================================
// onboarding-followups  (Member Poloooza rebuild, cron processor)
// ============================================================================
// Invoked every 10 min by pg_cron. Selects due onboarding_tasks
// (done=false AND run_after <= now()) and processes each:
//
//   slack_channel_sync  , look the member up in Slack (users.lookupByEmail).
//                          If present, invite to all target channels and mark
//                          done. If not present yet, reschedule (poll again
//                          later) until an attempt cap, then give up.
//   slack_join_reminder , if the member is NOT in Slack, send the variant
//                          reminder email (verbatim, spec §5), threaded onto
//                          the welcome email. Mark done. If already in Slack,
//                          mark done with no send.
//
// Idempotent: each task is claimed by flipping a marker; already-done tasks are
// never reprocessed. Safe to run repeatedly.
//
// HARD GATING (ONBOARDING_MODE): same as member-onboard.
//   dry_run (DEFAULT), no email, no Slack writes.
//   test             , reminder emails routed to ONBOARDING_TEST_EMAIL; no Slack.
//   live             , real reminders + real Slack channel invites.
//
// MODE MATCHING. Every task carries the mode it was minted under, and this
// function only ever sees tasks stamped with the mode it is itself running in.
// That is what makes it safe for member-onboard to enqueue outside live: the
// mode is read here, up to 24h after the task was created, so without the match
// a test task would become a real send the instant the mode was flipped. It cuts
// the other way too, which is the less obvious half: a drain running in dry_run
// used to close out pending LIVE reminders as "would have sent", destroying
// them. Tasks minted in another mode are now simply not due.
//
// Auth: x-cron-secret == CRON_SECRET (pattern copied from slack-sync-to-slack).
// Deployed --no-verify-jwt.
// ============================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleCors, corsHeaders } from "../_shared/cors.ts";
import {
  getMode, testEmail, buildReminderEmail, sendGmail,
  slackLookupByEmail, slackInvite, EMAIL_RE, groupTargets, addMemberToGroup,
  ensureSlackUserMapping, recordChannelInvite,
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

// ---------------------------------------------------------------------------
// writeTask: the only way this function is allowed to touch onboarding_tasks.
//
// supabase-js resolves with { data, error } and never throws, so every bare
// `await supabase.from("onboarding_tasks").update(...)` in here used to throw
// its failure away and let the loop report the task as handled. There is a
// second, quieter half: an UPDATE filtered by id that matches ZERO rows is not
// an error either, so checking `error` alone still cannot see a row that was
// deleted or an id that no longer exists. { count: "exact" } is what makes the
// rowcount observable.
//
// This matters more here than almost anywhere else, because these writes are
// the only thing that marks work as finished. If one is lost after a reminder
// email has already gone out, the next cron run (10 minutes later) sends that
// same member the same email, and so does every run after that, forever. So the
// log line for that case names the member and says what will repeat.
// ---------------------------------------------------------------------------
async function writeTask(
  supabase: ReturnType<typeof createClient>,
  taskId: string,
  patch: Record<string, unknown>,
  ctx: { taskType: string; memberId: string | null; email: string; alreadyDid: string | null },
): Promise<{ ok: true } | { ok: false; detail: string }> {
  const { error, count } = await supabase
    .from("onboarding_tasks")
    .update(patch, { count: "exact" })
    .eq("id", taskId);
  const who = `task=${taskId} type=${ctx.taskType} member=${ctx.memberId ?? "none"} email=${ctx.email || "none"}`;
  if (error || count === 0) {
    const reason = error ? error.message : "id filter matched 0 rows";
    if (ctx.alreadyDid) {
      // Loud on purpose: the side effect has already happened and the next run
      // will repeat it. A human has to see this line and stop it.
      console.error(
        `[onboarding-followups] REPEAT-SEND RISK: already ${ctx.alreadyDid}, but could not mark the task done, so the next run WILL do it again. ${who} reason=${reason}`,
      );
    } else {
      console.error(`[onboarding-followups] task write failed ${JSON.stringify(patch)}. ${who} reason=${reason}`);
    }
    return { ok: false, detail: `write ${JSON.stringify(patch)} failed: ${reason}` };
  }
  if (count == null) {
    // Not a failure: the write reported no error. Logged anyway, because it
    // means the rowcount assertion above could not be evaluated on this deploy,
    // and that assertion is the only thing watching a zero-row write.
    console.warn(`[onboarding-followups] rowcount unavailable, could not assert the write landed. ${who}`);
  }
  return { ok: true };
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

  // dry_run sends nothing, so member-onboard mints no task in it and there is
  // nothing stamped dry_run to ever drain. Say that, rather than run a query
  // guaranteed to return nothing and then reason about a queue that cannot
  // exist. This is also the safe answer if ONBOARDING_MODE is ever unset or
  // mistyped: getMode() degrades to dry_run, and this function stops dead
  // instead of quietly deciding a live queue is not due.
  if (mode === "dry_run") {
    return json({
      ok: true, mode, processed: 0, results: [],
      note: "dry_run: no task is ever minted in this mode, so nothing is ever due",
    });
  }

  // --- Claim due tasks -----------------------------------------------------
  // Due means: not done, scheduled for now or earlier, AND minted under the mode
  // this run is operating in. See MODE MATCHING in the header.
  const nowIso = new Date().toISOString();
  const { data: due, error: dueErr } = await supabase
    .from("onboarding_tasks")
    .select("id, member_id, task_type, attempts, meta")
    .eq("mode", mode)
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
      const bkNoEmail = await writeTask(supabase, t.id, { done: true, attempts }, { taskType: t.task_type, memberId: t.member_id, email, alreadyDid: null });
      if (!bkNoEmail.ok) log.bookkeeping = bkNoEmail.detail;
      log.result = "no valid email, closed";
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
        // Link the Slack account to the member row first: the membership log's
        // slack_user_id is a foreign key to slack_user_mapping, so nothing can
        // be recorded without it. This is the same write member-onboard makes;
        // it is repeated here because this path reaches members who were not in
        // Slack when they were welcomed, which is most of them.
        const map = t.member_id
          ? await ensureSlackUserMapping(supabase, t.member_id, slackUserId, email)
          : { ok: false, error: "task has no member_id" };
        if (!map.ok) log.mapping = `slack_user_mapping not written: ${map.error}`;
        const invited: string[] = [];
        for (const ch of targets) {
          const r = await slackInvite(ch, slackUserId, SLACK_BOT_TOKEN);
          invited.push(`${ch}:${r.success ? "ok" : r.error}`);
          if (map.ok && t.member_id) {
            await recordChannelInvite(supabase, {
              memberId: t.member_id, slackUserId, channelId: ch,
              success: r.success, error: r.error ?? null,
              metadata: { stage: "onboarding-followups", variant, task_id: t.id },
            });
          }
        }
        // Google Group parity: add member email to each mapped group (idempotent).
        const groupAdds = groupTargets(targets);
        const groups: string[] = [];
        for (const { group } of groupAdds) {
          const g = await addMemberToGroup(email, group);
          groups.push(`${group}:${g.action}${g.scopeError ? "(SCOPE_ERROR client-114261141581576499255)" : ""}`);
        }
        // The Slack invites and Google Group adds above have already been made.
        // A lost "done" here replays all of them on the next run.
        const bkSynced = await writeTask(supabase, t.id, { done: true, attempts }, { taskType: t.task_type, memberId: t.member_id, email, alreadyDid: "invited this member to the Slack channels" });
        if (!bkSynced.ok) log.bookkeeping = bkSynced.detail;
        log.result = "in Slack, invited + done";
        log.invites = invited;
        if (groups.length) log.group_adds = groups;
      } else if (attempts >= MAX_SYNC_ATTEMPTS) {
        const bkGaveUp = await writeTask(supabase, t.id, { done: true, attempts }, { taskType: t.task_type, memberId: t.member_id, email, alreadyDid: null });
        if (!bkGaveUp.ok) log.bookkeeping = bkGaveUp.detail;
        log.result = `not joined after ${attempts} polls, gave up`;
      } else {
        const next = new Date(Date.now() + SYNC_RETRY_MINUTES * 60_000).toISOString();
        const bkReschedule = await writeTask(supabase, t.id, { attempts, run_after: next }, { taskType: t.task_type, memberId: t.member_id, email, alreadyDid: null });
        if (!bkReschedule.ok) log.bookkeeping = bkReschedule.detail;
        log.result = mode === "live" ? "not joined yet, reschedule" : `${mode}: no Slack write, reschedule`;
      }
      results.push(log);
      continue;
    }

    if (t.task_type === "slack_join_reminder") {
      if (mode === "live" && inSlack) {
        const bkAlreadyIn = await writeTask(supabase, t.id, { done: true, attempts }, { taskType: t.task_type, memberId: t.member_id, email, alreadyDid: null });
        if (!bkAlreadyIn.ok) log.bookkeeping = bkAlreadyIn.detail;
        log.result = "already in Slack, no reminder needed";
        results.push(log);
        continue;
      }
      // Not in Slack (or non-live): send the reminder (subject to mode).
      const built = buildReminderEmail(variant, first);
      const recipient = mode === "test" ? testEmail() : email;
      const ccList = mode === "test" ? [] : built.cc;
      if (mode === "test" && (!recipient || !EMAIL_RE.test(recipient))) {
        log.result = "ONBOARDING_TEST_EMAIL missing, left pending";
        results.push(log);
        continue;
      }
      try {
        const sent = await sendGmail({
          to: recipient, cc: ccList, subject: built.subject,
          html: built.html, text: built.text, threadId: meta.thread_id ?? null,
          from: built.from, replyTo: built.replyTo,
        });
        // THE SPAM GUARD. The reminder is in the member's inbox by this line.
        // This write is the only thing standing between them and the same
        // email again in 10 minutes, and again after that. It is also the one
        // write in this file whose failure cannot be undone by a later run.
        const bkSent = await writeTask(supabase, t.id, { done: true, attempts }, { taskType: t.task_type, memberId: t.member_id, email, alreadyDid: `sent the ${variant} reminder email to ${recipient}` });
        if (!bkSent.ok) log.bookkeeping = bkSent.detail;
        log.result = `${mode.toUpperCase()}: sent ${variant} reminder to ${recipient} [msg ${sent.id}]`;
      } catch (e) {
        const bkRetry = await writeTask(supabase, t.id, { attempts }, { taskType: t.task_type, memberId: t.member_id, email, alreadyDid: null });
        if (!bkRetry.ok) log.bookkeeping = bkRetry.detail;
        log.result = `send failed (will retry): ${String(e)}`;
      }
      results.push(log);
      continue;
    }

    // Unknown task type, close it so it doesn't loop forever.
    const bkUnknown = await writeTask(supabase, t.id, { done: true, attempts }, { taskType: t.task_type, memberId: t.member_id, email, alreadyDid: null });
    if (!bkUnknown.ok) log.bookkeeping = bkUnknown.detail;
    log.result = `unknown task_type '${t.task_type}', closed`;
    results.push(log);
  }

  // A cron run is normally read as its summary line, so surface the count of
  // failed bookkeeping writes there too. Each one is a task that will be
  // redone on the next run, email and all.
  const bookkeepingFailures = results.filter((r) => r.bookkeeping).length;
  return json({ ok: true, mode, processed: results.length, bookkeeping_failures: bookkeepingFailures, results });
});
