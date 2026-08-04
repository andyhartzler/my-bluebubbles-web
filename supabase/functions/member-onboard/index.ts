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
//                       invites (only if they are already in Slack).
// A real member is only ever emailed/invited when mode === "live".
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
  committeeChannels, firstNameOf, slackLookupByEmail, slackInvite,
  slackWorkspaceInvite, EMAIL_RE, DEFAULT_CHANNELS, WORKSPACE_TEAM_ID,
  groupTargets, addMemberToGroup,
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
    .select("id, name, email, date_of_birth, birth_year, in_school, school_name, desire_to_lead, committee, slack_user_id")
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
  if (branchErr) console.warn(`member ${memberId}: moyd_age_branch rpc failed (${branchErr.message}), treating as eligible`);
  const branch: string = (branchErr || !branchData) ? "eligible" : String(branchData);
  if (age === null) {
    console.warn(`member ${memberId}: birth date/year missing, treating as eligible`);
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
  let slackUserId: string | null = m.slack_user_id;
  if (mode === "live") {
    if (!SLACK_BOT_TOKEN) {
      actions.push("LIVE: SLACK_BOT_TOKEN missing, skipped Slack workspace invite and channel adds");
    } else {
      if (!slackUserId) {
        const look = await slackLookupByEmail(realEmail, SLACK_BOT_TOKEN);
        if (look.found) slackUserId = look.userId!;
      }
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
        for (const ch of targets) {
          const r = await slackInvite(ch, slackUserId, SLACK_BOT_TOKEN);
          actions.push(`LIVE: conversations.invite ${ch} <- ${slackUserId}: ${r.success ? "ok" : r.error}`);
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
    }
  } else {
    actions.push(`${mode.toUpperCase()}: Slack writes SKIPPED. Would add ${slackUserId ? slackUserId : "member (once joined)"} to channels: ${targets.join(", ")}`);
    if (groupAdds.length) actions.push(`${mode.toUpperCase()}: Google Group writes SKIPPED. Would add ${realEmail} to groups: ${groupAdds.map((x) => x.group).join(", ")}`);
  }

  // --- 3. Enqueue follow-up tasks (spec §5 / §8) ---------------------------
  // Idempotent: skip if this member already has open tasks. We always enqueue
  // (even in dry_run) so the queue reflects the real plan; the followup
  // processor is itself gated and will not send/write in dry_run.
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

  const { data: existingTasks } = await supabase
    .from("onboarding_tasks")
    .select("id, task_type")
    .eq("member_id", memberId)
    .eq("done", false);

  const have = new Set((existingTasks || []).map((t) => (t as { task_type: string }).task_type));
  const toInsert: Record<string, unknown>[] = [];

  // slack_channel_sync: poll for the member joining Slack, then auto-add to all
  // target channels. Students first checked at +30m (spec §3.3), general at +24h.
  if (!have.has("slack_channel_sync")) {
    const firstCheckMin = variant === "general" ? 24 * 60 : 30;
    toInsert.push({
      member_id: memberId,
      task_type: "slack_channel_sync",
      run_after: new Date(nowMs + firstCheckMin * 60_000).toISOString(),
      meta: metaBase,
    });
  }
  // slack_join_reminder: at +24h, if still not in Slack, send the variant
  // reminder email (spec §5). Applies to everyone in this branch (spec §8 fix).
  if (!have.has("slack_join_reminder")) {
    toInsert.push({
      member_id: memberId,
      task_type: "slack_join_reminder",
      run_after: new Date(nowMs + 24 * 60 * 60_000).toISOString(),
      meta: metaBase,
    });
  }

  if (toInsert.length) {
    const { error: insErr } = await supabase.from("onboarding_tasks").insert(toInsert);
    if (insErr) actions.push(`WARN: onboarding_tasks insert failed: ${insErr.message}`);
    else actions.push(`enqueued ${toInsert.length} follow-up task(s): ${toInsert.map((t) => t.task_type).join(", ")}`);
  } else {
    actions.push("follow-up tasks already present (idempotent skip)");
  }

  return json({ ok: true, plan, actions, email_msg_id: emailResult?.id ?? null });
});
