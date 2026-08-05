// ============================================================================
// member-onboard  (Member Poloooza rebuild, entry point)
// ============================================================================
// Input: { member_id }  (POST JSON)
// Loads the member, determines the welcome variant (General / College /
// High School), sends the correct welcome email, computes Slack actions, and
// enqueues follow-up tasks in public.onboarding_tasks.
//
// HARD GATING (ONBOARDING_MODE):
//   dry_run (DEFAULT), build email + compute Slack actions, send NOTHING, write
//                       NO Slack. Returns a full plan of what WOULD happen.
//   test             , send the welcome email to ONBOARDING_TEST_EMAIL only,
//                       skip ALL Slack writes.
//   live             , real welcome email to the member + real Slack channel
//                       invites (only if they are already in Slack), and the two
//                       follow-up tasks are enqueued.
// A real member is only ever emailed/invited when mode === "live". Follow-up
// tasks are created in LIVE MODE ONLY: they are drained up to 24h later by
// onboarding-followups, which reads the mode at drain time, so a task minted in
// dry_run or test would start sending the moment the mode is flipped to live.
//
// SEND IDEMPOTENCY: the two follow-up tasks are the record that a member has
// been welcomed. If this member has ANY onboarding_tasks row, the function
// returns a no-op plan and sends nothing. The website form upserts members on
// email and calls this unconditionally, so without that probe a returning member
// receives a second welcome.
//
// Age gate (calendar-year): eligible = the age you turn this year is 13 through
// 35 (13 through under 36); age out the year you turn 36. Authoritative logic is
// public.moyd_age_branch(date_of_birth, birth_year), which this function calls by
// RPC (single source of truth, also drives members.membership_eligible). Everyone
// is still LOGGED as a member upstream regardless of age; this only picks the
// email variant and whether Slack/committee/follow-ups run. Too-young/aged-out
// branches send their own email only.
//
// Auth: shared-secret. Requires header x-onboard-secret == ONBOARDING_TRIGGER_SECRET.
// Deployed --no-verify-jwt. WIRED: the website form (/api/membership/process)
// calls this fire-and-forget after saving a member. Live sends are still gated by
// ONBOARDING_MODE (dry_run default), so nothing reaches a real person until mode
// is flipped to "live".
// ============================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleCors, corsHeaders } from "../_shared/cors.ts";
import {
  getMode, testEmail, buildWelcomeEmail, buildTooYoungEmail, buildAgedOutEmail,
  sendGmail, computeVariant, targetChannels, caucusChannel,
  committeeChannels, firstNameOf, slackInvite,
  slackWorkspaceInvite, EMAIL_RE, DEFAULT_CHANNELS, WORKSPACE_TEAM_ID,
  groupTargets, addMemberToGroup,
  confirmSlackUserId, ensureSlackUserMapping, recordChannelInvite,
  slackPostMessage, slackDmByEmail, chairsForVariant, buildInternalNotice,
  NOTIFY_CHANNEL,
  type MemberRow, type Variant, type BuiltEmail,
} from "../_shared/onboarding.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SLACK_BOT_TOKEN = Deno.env.get("SLACK_BOT_TOKEN") || "";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  // --- Auth: shared-secret gate (prevents open relay) ----------------------
  const expected = Deno.env.get("ONBOARDING_TRIGGER_SECRET") || "";
  const provided = req.headers.get("x-onboard-secret") || "";
  if (!expected || provided.length !== expected.length || provided !== expected) {
    return json({ error: "unauthorized" }, 401);
  }

  const mode = getMode();

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "invalid JSON body" }, 400); }
  const memberId = typeof body.member_id === "string" ? body.member_id.trim() : "";
  if (!memberId) return json({ error: "member_id required" }, 400);

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

  // --- Load member ---------------------------------------------------------
  const { data: member, error: memErr } = await supabase
    .from("members")
    .select("id, name, email, date_of_birth, birth_year, in_school, school_name, education_level, desire_to_lead, committee, slack_user_id")
    .eq("id", memberId)
    .maybeSingle();
  if (memErr) return json({ error: "member lookup failed", detail: memErr.message }, 500);
  if (!member) return json({ error: "member not found", member_id: memberId }, 404);

  const m = member as MemberRow;
  const realEmail = (m.email || "").trim();
  if (!realEmail || !EMAIL_RE.test(realEmail)) {
    return json({ error: "member has no valid email", member_id: memberId }, 422);
  }

  const first = firstNameOf(m.name);

  // --- AGE GATE. The ONLY age rule is public.moyd_age_branch in the database,
  // called here by RPC. It also drives the members.membership_eligible trigger.
  // There is deliberately no second implementation in TypeScript: duplicating
  // this rule in a second language is exactly what silently broke the n8n
  // cascade. `age` below is a LOG/DISPLAY value only and decides nothing.
  // Everyone is already LOGGED as a member upstream; this branch only decides
  // which email is sent and whether Slack/committee/follow-up actions run.
  const birthYr = m.date_of_birth
    ? new Date(m.date_of_birth).getUTCFullYear()
    : (m.birth_year ?? null);
  const age = birthYr && !Number.isNaN(birthYr)
    ? new Date().getUTCFullYear() - birthYr // the age they turn this calendar year
    : null;
  const { data: branchData, error: branchErr } = await supabase.rpc("moyd_age_branch", {
    p_dob: m.date_of_birth ?? null,
    p_birth_year: m.birth_year ?? null,
  });
  // FAIL CLOSED. This used to fall back to "eligible" when the RPC errored,
  // which threw away the single source of truth at the one moment it could not
  // be consulted: a transient PostgREST error would have sent "Welcome Aboard!"
  // to a 55 year old, pushed them into the Slack workspace and added them to the
  // mapped Google Groups, none of which the member can undo. Stop instead. The
  // website form calls this fire-and-forget and the member is already saved, so
  // a hard stop costs nothing but a retry. A missing DOB is NOT this case: the
  // DB function answers 'eligible' for NULL/NULL by design, which is an answer.
  if (branchErr || !branchData) {
    return json({
      error: "age branch unavailable, nothing sent",
      detail: branchErr?.message ?? "moyd_age_branch returned no value",
      member_id: memberId,
      age_rule: "public.moyd_age_branch (DB, single source of truth)",
    }, 502);
  }
  const branch: string = String(branchData);

  // --- ALREADY ONBOARDED? --------------------------------------------------
  // This probe used to sit further down, inside the eligible path, which meant
  // the duplicate-send guard protected the welcome and ONLY the welcome. The
  // caller (the website's membership route) fires this function unconditionally
  // after every submission, including the existing-member update path, so a
  // too-young or aged-out member who resubmitted the form was told they were
  // too young or too old again, every single time, with nothing recorded
  // anywhere to say it had already been said. It sits above the branch now so
  // that every email this function can send is covered by one guard.
  //
  // A row is written only when an email really reached the MEMBER, which means
  // live mode: in test mode the mail goes to ONBOARDING_TEST_EMAIL, so the
  // member has not been told anything and must not be marked as though they
  // had. Rows are marked done and never deleted, so the probe covers the whole
  // history rather than the open tasks.
  const { data: priorTasks, error: priorErr } = await supabase
    .from("onboarding_tasks")
    .select("id")
    .eq("member_id", memberId)
    .limit(1);
  if (priorErr) {
    // Fail closed for the same reason as the age gate: unable to tell is not a
    // licence to send a duplicate.
    return json({ error: "onboarding history probe failed, nothing sent", detail: priorErr.message, member_id: memberId }, 502);
  }
  const alreadyOnboarded = Boolean(priorTasks && priorTasks.length);

  if (alreadyOnboarded) {
    return json({
      ok: true,
      plan: { mode, member_id: memberId, age_branch: branch, email_actually_to: null },
      actions: ["already onboarded (onboarding_tasks rows exist for this member): no email, no Slack writes, no new tasks"],
      email_msg_id: null,
    });
  }

  if (branch !== "eligible") {
    // Too young or aged out: send the branch email only. No Slack, no committee
    // adds, no follow-up tasks.
    const ageEmail: BuiltEmail = branch === "too_young"
      ? buildTooYoungEmail(first)
      : buildAgedOutEmail(first);
    const recipient = mode === "test" ? testEmail() : realEmail;
    const ccList = mode === "test" ? [] : ageEmail.cc; // don't CC info@ during a test
    const plan = {
      mode, member_id: memberId, age, age_branch: branch,
      age_rule: "public.moyd_age_branch (DB, single source of truth)",
      variant: null, first_name: first,
      email_subject: ageEmail.subject,
      email_from: ageEmail.from,
      email_intended_to: realEmail,
      email_actually_to: mode === "dry_run" ? null : recipient,
      email_cc: ccList,
      slack: "SKIPPED (age-gated: no workspace/committee/caucus adds)",
      followups: "NONE (age-gated)",
    };
    const actions: string[] = [];
    let emailResult: { id: string; threadId: string } | null = null;
    if (mode === "dry_run") {
      actions.push(`DRY_RUN: would send "${ageEmail.subject}" (${branch}, age ${age}) from ${ageEmail.from} to ${realEmail}`);
    } else {
      if (mode === "test" && (!recipient || !EMAIL_RE.test(recipient))) {
        return json({ error: "ONBOARDING_TEST_EMAIL missing/invalid in test mode" }, 500);
      }
      try {
        emailResult = await sendGmail({
          to: recipient, cc: ccList, subject: ageEmail.subject,
          html: ageEmail.html, text: ageEmail.text,
          from: ageEmail.from, replyTo: ageEmail.replyTo,
        });
        actions.push(`${mode.toUpperCase()}: sent "${ageEmail.subject}" (${branch}, age ${age}) to ${recipient} [msg ${emailResult.id}]`);
      } catch (e) {
        return json({ error: "age-branch email send failed", detail: String(e), plan }, 502);
      }
    }
    actions.push("Slack SKIPPED and no follow-up tasks enqueued (age-gated)");

    // Record that this member has now been told, so a resubmission does not
    // tell them again. done=true and no run_after, so the followups drainer
    // (done=false AND run_after <= now) can never pick it up: it is a receipt,
    // not a scheduled send. Live only, for the reason given at the probe above.
    if (mode === "live" && emailResult) {
      const { error: receiptErr } = await supabase.from("onboarding_tasks").insert({
        member_id: memberId,
        task_type: "age_branch_notified",
        done: true,
        meta: { branch, email: realEmail, subject: ageEmail.subject, message_id: emailResult.id },
      });
      if (receiptErr) {
        // Loud, not fatal: the member has had their email, and swallowing this
        // is how a second copy gets sent tomorrow with nobody the wiser.
        console.error("failed to record age-branch receipt for", memberId, receiptErr.message);
        actions.push(`WARNING: age-branch receipt not recorded (${receiptErr.message}); a resubmission could send this again`);
      }
    }

    return json({ ok: true, plan, actions, email_msg_id: emailResult?.id ?? null });
  }

  // --- ELIGIBLE PATH (14 <= age <= 36, or unknown DOB) ------------------------
  const variant: Variant = computeVariant(m);
  const built = buildWelcomeEmail(variant, first);
  const targets = targetChannels(m, variant);
  const caucus = caucusChannel(variant);
  const committees = committeeChannels(m);
  // Google Groups implied by the target channels (Slack -> Group parity, spec §6.7).
  const groupAdds = groupTargets(targets);

  // Where email actually goes, per mode.
  const recipient = mode === "test" ? testEmail() : realEmail;
  const ccList = mode === "test" ? [] : built.cc; // don't CC real leaders during a test

  const plan = {
    mode,
    member_id: memberId,
    age,
    age_branch: branch,
    age_rule: "public.moyd_age_branch (DB, single source of truth)",
    variant,
    first_name: first,
    email_subject: built.subject,
    email_intended_to: realEmail,
    email_actually_to: mode === "dry_run" ? null : recipient,
    email_cc: ccList,
    slack_workspace: "T0927V02T35 (join link delivered in email; shared-invite model)",
    slack_default_channels: DEFAULT_CHANNELS,
    slack_caucus_channel: caucus,
    slack_committee_channels: committees,
    slack_all_targets: targets,
    google_group_adds: groupAdds, // {channel, group} the member will be added to (mirrors Slack channel adds)
  };

  const actions: string[] = [];
  let emailResult: { id: string; threadId: string } | null = null;

  // The "already onboarded?" probe that used to sit here now runs above the age
  // branch, so it covers the too-young and aged-out emails as well as this one.
  // Reaching this line means it found no task history for this member.

  // --- 1. Welcome email ----------------------------------------------------
  if (mode === "dry_run") {
    actions.push(`DRY_RUN: would send "${built.subject}" (${variant}) to ${realEmail}`);
  } else {
    if (mode === "test" && (!recipient || !EMAIL_RE.test(recipient))) {
      return json({ error: "ONBOARDING_TEST_EMAIL missing/invalid in test mode" }, 500);
    }
    try {
      emailResult = await sendGmail({
        to: recipient, cc: ccList, subject: built.subject, html: built.html, text: built.text,
        from: built.from, replyTo: built.replyTo,
      });
      actions.push(`${mode.toUpperCase()}: sent "${built.subject}" (${variant}) to ${recipient} [msg ${emailResult.id}]`);
    } catch (e) {
      return json({ error: "welcome email send failed", detail: String(e), plan }, 502);
    }
  }

  // --- 2. Slack: workspace invite + channel adds ---------------------------
  // Two mechanisms, both of which n8n had:
  //   a) a programmatic workspace invite (admin.users.invite) seeded with the
  //      three default channels, which pushes the member in rather than waiting
  //      for them to self-serve. Non-fatal if the token lacks admin scope.
  //   b) channel adds, which need the member to already be in Slack (user id).
  // The shared join link is in the email either way, and the followup poller
  // adds them to channels once they appear.
  let slackUserId: string | null = null;
  if (mode === "live") {
    if (!SLACK_BOT_TOKEN) {
      actions.push("LIVE: SLACK_BOT_TOKEN missing, skipped Slack workspace invite and channel adds");
    } else {
      // ALWAYS confirm by fresh lookup, exactly as the zap did. The stored
      // members.slack_user_id is used only when the lookup fails for a reason
      // other than "not in Slack". See confirmSlackUserId.
      const confirmed = await confirmSlackUserId(realEmail, m.slack_user_id, SLACK_BOT_TOKEN);
      slackUserId = confirmed.userId;
      actions.push(`LIVE: slack id for ${realEmail} = ${slackUserId ?? "none"} (${confirmed.via})`);
      if (!slackUserId) {
        const inv = await slackWorkspaceInvite(realEmail, DEFAULT_CHANNELS, SLACK_BOT_TOKEN);
        actions.push(
          `LIVE: admin.users.invite ${WORKSPACE_TEAM_ID} <- ${realEmail}: ${inv.ok ? (inv.error || "ok") : inv.error}`,
        );
        if (!inv.ok) {
          actions.push("LIVE: workspace invite failed (non-fatal). Shared join link is in the email; followup poller will still add channels.");
        }
      }
      if (slackUserId) {
        // Link the Slack account to the member row BEFORE logging anything:
        // slack_channel_membership_log.slack_user_id has a foreign key to
        // slack_user_mapping, so the log row cannot exist without it. This is
        // also the only point at signup where that linkage gets made at all.
        const map = await ensureSlackUserMapping(supabase, memberId, slackUserId, realEmail);
        if (!map.ok) actions.push(`LIVE: slack_user_mapping upsert failed (${map.error}); channel invites will not be logged`);
        for (const ch of targets) {
          const r = await slackInvite(ch, slackUserId, SLACK_BOT_TOKEN);
          actions.push(`LIVE: conversations.invite ${ch} <- ${slackUserId}: ${r.success ? "ok" : r.error}`);
          if (map.ok) {
            await recordChannelInvite(supabase, {
              memberId, slackUserId, channelId: ch,
              success: r.success, error: r.error ?? null,
              metadata: { stage: "member-onboard", variant },
            });
          }
        }
        // Google Group parity: add the member email to each mapped group.
        // Idempotent (already-a-member is a no-op).
        for (const { channel, group } of groupAdds) {
          const g = await addMemberToGroup(realEmail, group);
          actions.push(`LIVE: group add ${group} (<- ${channel}): ${g.action}${g.scopeError ? " SCOPE_ERROR" : ""}${g.error ? " err=" + g.error : ""}`);
          if (g.scopeError) actions.push("LIVE: DWD scope 'admin.directory.group.member' NOT authorized for client 114261141581576499255, Andrew must add it in admin.google.com");
        }
      } else {
        actions.push("LIVE: member not yet in Slack, channel adds + group adds deferred to followup");
      }

      // --- Tell the organisation. Nothing else does. ------------------------
      const notice = buildInternalNotice({
        name: m.name || realEmail, email: realEmail, variant,
        committees: m.committee || [], channels: targets,
      });
      const posted = await slackPostMessage(NOTIFY_CHANNEL, notice, SLACK_BOT_TOKEN);
      actions.push(`LIVE: chat.postMessage ${NOTIFY_CHANNEL}: ${posted.ok ? "ok" : posted.error}`);
      for (const chair of chairsForVariant(variant)) {
        const dm = await slackDmByEmail(chair, notice, SLACK_BOT_TOKEN);
        actions.push(`LIVE: chair DM ${chair}: ${dm.ok ? "ok" : dm.error}`);
      }
    }
  } else {
    actions.push(`${mode.toUpperCase()}: Slack writes SKIPPED. Would confirm the member's Slack id by users.lookupByEmail (stored id ${m.slack_user_id ?? "none"} is not trusted) and add them to channels: ${targets.join(", ")}`);
    if (groupAdds.length) actions.push(`${mode.toUpperCase()}: Google Group writes SKIPPED. Would add ${realEmail} to groups: ${groupAdds.map((x) => x.group).join(", ")}`);
  }

  // --- 3. Enqueue follow-up tasks (spec §5 / §8), LIVE ONLY ----------------
  // A task is created only when a real welcome has really been sent. It used to
  // be enqueued in every mode, on the reasoning that the followup processor is
  // itself gated, but that gate is read up to 24 hours LATER, at drain time: a
  // task minted while the system was deliberately silent becomes sendable the
  // moment the mode is flipped to live, and the member gets "Don't forget to
  // join us on Slack!" as their first ever contact from MOYD, unthreaded because
  // no welcome thread exists. dry_run and test report the plan in the response
  // instead, which is exactly what those modes are for.
  // Nothing here needs a duplicate check: the probe above returned early if this
  // member had any task history at all, so reaching this point means zero rows.
  if (mode !== "live") {
    actions.push(`${mode.toUpperCase()}: no follow-up tasks enqueued (tasks are created in live mode only, so a reminder can never fire for a member whose welcome was never sent)`);
  } else {
    const nowMs = Date.now();
    const metaBase = {
      variant,
      email: realEmail,
      first_name: first,
      targets,
      caucus,
      committees,
      thread_id: emailResult?.threadId ?? null,
    };
    // slack_channel_sync: poll for the member joining Slack, then auto-add to
    // all target channels. Students first checked at +30m (spec §3.3), general
    // at +24h. slack_join_reminder: at +24h, if still not in Slack, send the
    // variant reminder email (spec §5), threaded onto the welcome.
    const firstCheckMin = variant === "general" ? 24 * 60 : 30;
    const toInsert = [
      {
        member_id: memberId,
        task_type: "slack_channel_sync",
        run_after: new Date(nowMs + firstCheckMin * 60_000).toISOString(),
        meta: metaBase,
      },
      {
        member_id: memberId,
        task_type: "slack_join_reminder",
        run_after: new Date(nowMs + 24 * 60 * 60_000).toISOString(),
        meta: metaBase,
      },
    ];
    const { error: insErr } = await supabase.from("onboarding_tasks").insert(toInsert);
    if (insErr) actions.push(`WARN: onboarding_tasks insert failed: ${insErr.message}`);
    else actions.push(`enqueued ${toInsert.length} follow-up task(s): ${toInsert.map((t) => t.task_type).join(", ")}`);
  }

  return json({ ok: true, plan, actions, email_msg_id: emailResult?.id ?? null });
});
