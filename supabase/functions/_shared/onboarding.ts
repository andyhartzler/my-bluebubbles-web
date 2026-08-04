// ============================================================================
// Shared logic for the member-onboarding cascade ("Member Poloooza" rebuild).
// Used by member-onboard and onboarding-followups.
//
// Source of truth for copy + mappings: /Users/moyd/Desktop/MOYD/member-poloooza-spec.md
//
// SAFETY: this module never sends or writes anything on its own. Callers read
// getMode() and decide. Modes:
//   dry_run (DEFAULT / unset / unrecognized) — compute + log only, no email, no Slack writes.
//   test    — route ALL email to ONBOARDING_TEST_EMAIL, skip ALL Slack writes.
//   live    — real sends + real Slack writes.
// A real member is only ever contacted when mode === "live".
//
// Age gate: CALENDAR-YEAR, authoritative in the DB (public.moyd_age_branch +
// members.membership_eligible trigger); member-onboard calls it by RPC. Eligible
// = the age you turn this year is 13 through 35 (13 through under 36); age out the
// year you turn 36. Everyone is still LOGGED as a member regardless; the gate only
// picks the email variant + whether Slack/committee/follow-ups run. Too-young and
// aged-out emails (spec 4.4 / 4.5) ARE built (buildTooYoungEmail / buildAgedOutEmail).
// ============================================================================
import { getGoogleAccessToken } from "./google-auth.ts";
import { groupForChannel, addMemberToGroup, removeMemberFromGroup, CHANNEL_TO_GROUP } from "./google-groups.ts";

// Re-export the Google Group sync surface so onboarding callers import from one
// module. Slack channel membership -> Google Group mirrors the 8 legacy zaps.
export { groupForChannel, addMemberToGroup, removeMemberFromGroup, CHANNEL_TO_GROUP };

// The distinct Google Groups implied by a set of target Slack channels.
// Deduped by group email. Used to add an onboarded member to the committee /
// caucus / members email lists once they are added to the matching channels.
export function groupTargets(channels: string[]): { channel: string; group: string }[] {
  const out: { channel: string; group: string }[] = [];
  const seen = new Set<string>();
  for (const ch of channels) {
    const g = groupForChannel(ch);
    if (g && !seen.has(g)) { seen.add(g); out.push({ channel: ch, group: g }); }
  }
  return out;
}

export type OnboardingMode = "dry_run" | "test" | "live";

export function getMode(): OnboardingMode {
  const raw = (Deno.env.get("ONBOARDING_MODE") || "").trim().toLowerCase();
  if (raw === "live") return "live";
  if (raw === "test") return "test";
  return "dry_run"; // unset or unrecognized => safest mode
}

export function testEmail(): string {
  return (Deno.env.get("ONBOARDING_TEST_EMAIL") || "").trim();
}

// --- Gmail identity (copied from send-endorsement-thankyou) ------------------
const IMPERSONATE = "andrew@moyoungdemocrats.org"; // token minted for andrew@
const FROM = "info@moyoungdemocrats.org";          // verified send-as alias on andrew@
const FROM_NAME = "Missouri Young Democrats";

// --- Links referenced in the verbatim copy -----------------------------------
const SLACK_JOIN =
  "https://join.slack.com/t/moyoungdemocrats/shared_invite/zt-37w5tg3s5-Ds2_SyOxiBRdP71_HxnXtw";
const PORTAL = "https://moyoungdemocrats.org/members";
const INSTAGRAM = "https://www.instagram.com/moyoungdemocrats";
const TIKTOK = "https://www.tiktok.com/@moyoungdemocrats";
const DONATE = "https://secure.actblue.com/donate/moyd";
const MDP = "https://www.missouridemocrats.org";                       // Missouri Democratic Party
const COUNTY_PARTY = "https://www.missouridemocrats.org/county-parties"; // local county committee locator (best-guess URL; see report)

// --- Age gate. Unambiguous INTEGER-age logic (completed years) to avoid any
// off-by-one from date math. Eligible = 13 through 35 inclusive (13 and up,
// UNDER 36). 36 and older ages out. Andrew's clarification: "it's technically
// those under the age of 36." Everyone is still LOGGED as a member upstream in
// /process regardless of age; this gate only affects which email is sent and
// whether Slack/committee/follow-up actions run.
export const MIN_AGE_YEARS = 13; // youngest eligible completed-years age (inclusive)
export const MAX_AGE_YEARS = 35; // oldest eligible completed-years age (inclusive; 36+ ages out)

// --- Slack map (spec §7) -----------------------------------------------------
export const WORKSPACE_TEAM_ID = "T0927V02T35";
// Default channels every workspace member is auto-added to.
export const DEFAULT_CHANNELS = ["C0927V0858T", "C0927V0BZMH", "C092GKFC75G"];
export const HS_CHANNEL = "C093K8GTVP0";       // #high-school-democrats
export const COLLEGE_CHANNEL = "C093HE643J7";  // #college-democrats

// Committee interest (members.committee[] values, normalized) -> channel id.
// members.committee stores short names ("Political Affairs", "Policy & Advocacy",
// etc.); the spec uses long names ("... Committee"). Match on keyword.
export const COMMITTEE_CHANNELS: { test: RegExp; channel: string; label: string }[] = [
  { test: /political\s*affairs/i, channel: "C093K895RTQ", label: "Political Affairs Committee" },
  { test: /policy|advocacy/i,     channel: "C094CGNE56C", label: "Policy & Advocacy Committee" },
  { test: /communications/i,      channel: "C093AED6415", label: "Communications Committee" },
  { test: /fundraising/i,         channel: "C094R094XEW", label: "Fundraising Committee" },
  { test: /membership|outreach/i, channel: "C093RMQKXRA", label: "Membership & Outreach Committee" },
];

// CC recipients (spec §4.2 / §4.3). Hardcoded personal Gmails in the legacy
// zaps; kept as config here.
export const COLLEGE_CC = ["jaelynwoodley@gmail.com"]; // Elena Wierich removed from exec 2026-07-14
export const HS_CC = ["korra.ravenclaw@gmail.com", "irvindwayne04@gmail.com"];

export type Variant = "general" | "college" | "high_school";

export interface MemberRow {
  id: string;
  name: string | null;
  email: string | null;
  date_of_birth: string | null;
  in_school: string | null;
  school_name: string | null;
  desire_to_lead: string | null;
  committee: string[] | null;
  slack_user_id: string | null;
}

export function firstNameOf(name: string | null): string {
  const n = (name || "").replace(/[\r\n]+/g, " ").trim();
  const first = n.split(/\s+/)[0] || "";
  return first || "there";
}

// Completed-years age as of today (UTC). Returns null when DOB missing/unparseable.
// This is the single source of truth for both the plan display AND the gate.
export function computeAge(dob: string | null, now: Date = new Date()): number | null {
  if (!dob) return null;
  const d = new Date(dob);
  if (isNaN(d.getTime())) return null;
  let age = now.getUTCFullYear() - d.getUTCFullYear();
  const m = now.getUTCMonth() - d.getUTCMonth();
  if (m < 0 || (m === 0 && now.getUTCDate() < d.getUTCDate())) age--;
  return age;
}

export type AgeBranch = "too_young" | "eligible" | "aged_out";

// Unambiguous integer-age gate. Eligible = 13 through 35 inclusive (13 and up,
// under 36). 36+ ages out. Missing/unparseable DOB => eligible (never hard-block
// on bad data; caller logs a warning).
export function ageBranchFromDob(dob: string | null, now: Date = new Date()): AgeBranch {
  const age = computeAge(dob, now);
  if (age === null) return "eligible";
  if (age < MIN_AGE_YEARS) return "too_young";   // under 13
  if (age > MAX_AGE_YEARS) return "aged_out";     // 36 and older
  return "eligible";                              // 13..35 inclusive
}

// Variant determination (spec §3.2 / §3.3). The age gate is handled separately
// via moyd_age_branch (see member-onboard); this only picks General/College/HS.
export function computeVariant(m: MemberRow): Variant {
  const inSchool = (m.in_school || "").trim().toLowerCase();
  if (inSchool === "yes") {
    const school = m.school_name || "";
    const committees = (m.committee || []).join(" ");
    // Primary signal: school-name regex (spec §3.3 step 2).
    if (/\b(high\s*school|hs|academy)\b/i.test(school)) return "high_school";
    // Fallbacks when the school name is blank/ambiguous.
    if (/high\s*school/i.test(committees)) return "high_school";
    return "college";
  }
  return "general";
}

// The caucus channel implied by the variant (students only).
export function caucusChannel(variant: Variant): string | null {
  if (variant === "high_school") return HS_CHANNEL;
  if (variant === "college") return COLLEGE_CHANNEL;
  return null;
}

// Committee channels the member indicated interest in. Per spec §3.4, committee
// routing applies to members whose desire_to_lead is Yes/Maybe.
export function committeeChannels(m: MemberRow): { channel: string; label: string }[] {
  const lead = (m.desire_to_lead || "").trim().toLowerCase();
  if (lead !== "yes" && lead !== "maybe") return [];
  const out: { channel: string; label: string }[] = [];
  for (const c of m.committee || []) {
    for (const cc of COMMITTEE_CHANNELS) {
      if (cc.test.test(c) && !out.find((o) => o.channel === cc.channel)) {
        out.push({ channel: cc.channel, label: cc.label });
      }
    }
  }
  return out;
}

// All channels this member should end up in once they are in Slack.
export function targetChannels(m: MemberRow, variant: Variant): string[] {
  const set = new Set<string>(DEFAULT_CHANNELS);
  const caucus = caucusChannel(variant);
  if (caucus) set.add(caucus);
  for (const cc of committeeChannels(m)) set.add(cc.channel);
  return [...set];
}

// ============================================================================
// Email rendering
// ============================================================================
function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

export function rfc2047(s: string): string {
  return "=?UTF-8?B?" + btoa(unescape(encodeURIComponent(s))) + "?=";
}

export function b64urlMime(mime: string): string {
  const bytes = new TextEncoder().encode(mime);
  let bin = "";
  bytes.forEach((b) => (bin += String.fromCharCode(b)));
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// Strict single-address check that also rejects header injection (CR/LF etc.).
export const EMAIL_RE = /^[^\s<>"',;:\r\n]+@[^\s<>"',;:\r\n]+\.[^\s<>"',;:\r\n]+$/;

const A = (href: string, text: string) =>
  `<a href="${href}" style="color:#2f7fc1;font-weight:600;text-decoration:underline;">${text}</a>`;

// Shared branded shell: cover banner + body + Andrew Hartzler / President
// signature (navy #263351) + social row + ActBlue support banner (spec §4).
function shell(bodyHtml: string, preheader: string): string {
  return `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><meta name="x-apple-disable-message-reformatting"><style>body{margin:0!important;padding:0!important;width:100%!important}table{border-collapse:collapse}img{border:0;line-height:100%;outline:none;text-decoration:none}a{text-decoration:none}@media only screen and (max-width:600px){.container{width:100%!important}.px{padding-left:24px!important;padding-right:24px!important}}</style></head>
<body style="margin:0;padding:0;background-color:#eef2f7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;">
<div style="display:none;max-height:0;overflow:hidden;mso-hide:all;font-size:1px;line-height:1px;color:#eef2f7;">${escapeHtml(preheader)}</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color:#eef2f7;"><tr><td align="center" style="padding:28px 16px;">
<table role="presentation" class="container" width="600" cellspacing="0" cellpadding="0" border="0" style="width:600px;max-width:600px;background-color:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 1px 4px rgba(38,51,81,0.12);">
<tr><td style="font-size:0;line-height:0;"><a href="https://moyoungdemocrats.org" target="_blank"><img src="https://email.moyd.app/media/images/cover-banner.png" width="600" alt="Missouri Young Democrats" style="display:block;width:100%;max-width:600px;height:auto;"></a></td></tr>
<tr><td class="px" style="padding:34px 44px 12px 44px;color:#333333;font-size:16px;line-height:1.65;">
${bodyHtml}
</td></tr>
<tr><td class="px" style="padding:6px 44px 8px 44px;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="border-top:1px solid #e5e9f0;"><tr><td style="padding-top:18px;">
<div style="color:#263351;font-size:16px;font-weight:700;line-height:1.35;">Andrew Hartzler</div>
<div style="color:#263351;font-size:14px;line-height:1.35;">President&nbsp;|&nbsp;Missouri Young Democrats</div>
</td></tr></table></td></tr>
<tr><td style="padding:14px 40px 18px 40px;text-align:center;">
<a href="https://www.facebook.com/MOyoungdemocrats" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/facebook-circle-256.png" width="30" height="30" alt="Facebook" style="width:30px;height:30px;"></a>
<a href="https://www.instagram.com/moyoungdemocrats" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/instagram-circle-256_2.png" width="30" height="30" alt="Instagram" style="width:30px;height:30px;"></a>
<a href="https://threads.net/moyoungdemocrats" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/threadsss-circle-256.png" width="30" height="30" alt="Threads" style="width:30px;height:30px;"></a>
<a href="https://x.com/moyoungdems" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/twitter-circle-256_2.png" width="30" height="30" alt="X" style="width:30px;height:30px;"></a>
<a href="https://bsky.app/profile/moyoungdemocrats.bsky.social" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/bluesky-circle-256_3.png" width="30" height="30" alt="Bluesky" style="width:30px;height:30px;"></a>
<a href="https://www.reddit.com/user/moyoungdemocrats" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/reddit-circle-256_1.png" width="30" height="30" alt="Reddit" style="width:30px;height:30px;"></a>
</td></tr>
<tr><td style="padding:0 40px 22px 40px;text-align:center;"><a href="${DONATE}" target="_blank"><img src="https://email.moyd.app/media/images/paid-for-banner.png" width="300" alt="Support Young Democrats" style="display:inline-block;width:300px;max-width:80%;height:auto;"></a></td></tr>
</table></td></tr></table></body></html>`;
}

const P = (html: string) => `<p style="margin:0 0 18px 0;">${html}</p>`;
const H = (emoji: string, title: string) =>
  `<p style="margin:22px 0 6px 0;font-size:16px;font-weight:700;color:#263351;">${emoji} ${title}</p>`;

// --- 4.1 GENERAL welcome (verbatim, spec §4.1) -------------------------------
function generalBody(first: string): string {
  const n = escapeHtml(first);
  return [
    P(`Hi ${n}!`),
    P(`Thanks for completing the interest form and welcome to Missouri Young Democrats! We're so glad you're here.`),
    P(`If there's a project or issue you're passionate about, whether it's climate justice, abortion rights, affordable housing, or something happening in your hometown, we want to help you take action. As a member-driven organization, you shape what we work on, how we show up, and the direction this movement takes. You are the leaders of your communities, and together we'll lead Missouri into a more just, inclusive, and hopeful future.`),
    P(`How to get plugged in:`),
    H("&#128172;", "Join the Slack"),
    P(`We use Slack as our digital organizing HQ. You can ${A(SLACK_JOIN, "click here to join our Slack workspace")} and start connecting with other members across Missouri. If you've already received an invite, check your inbox and accept it. Once you're in, say hi in #general!`),
    H("&#10024;", "Introduce yourself"),
    P(`We want to get to know you! If you feel comfortable, upload a profile picture to your Slack profile and drop a short intro in the #general channel. Let us know where you're from in Missouri and what brought you to this movement. It's a great way to meet other folks across the state who care about the same things you do.`),
    H("&#128241;", "Visit the Members Portal"),
    P(`${A(PORTAL, "Head here")} to access your Missouri Young Democrats member hub. You can add your membership card to Apple or Google Wallet, review meeting minutes, see opportunities to volunteer and get involved, and view resources and governing documents.`),
    H("&#128276;", "Stay in the loop"),
    P(`Be sure to download the Slack app and turn on notifications so you don't miss out. We'll be sharing updates about statewide actions, training opportunities, and ways to get involved. We'll also post a poll soon to pick the best time for our recurring monthly meeting.`),
    H("&#128577;", "Get more involved"),
    P(`To get more involved in our statewide organization, the best route is to join a committee via their Slack channel and introduce yourself to the chair and co-chair. We have committees focused on communications, fundraising, policy advocacy, political affairs, membership outreach, and more. Find the one that matches your interests and jump in!`),
    P(`Together, we are building something powerful and I can't wait to see what we'll do with this momentum. Whether you want to lead, learn, or just get involved, we're glad you're with us.`),
    P(`If you ever have questions or want to hop on a call, DM me in Slack, call or text 816-898-3612, or reply to this email.`),
    P(`Let's get to work!`),
    P(`Sincerely,`),
  ].join("\n");
}

// --- 4.2 COLLEGE welcome (verbatim, spec §4.2) -------------------------------
function collegeBody(first: string): string {
  const n = escapeHtml(first);
  return [
    P(`Hi ${n}!`),
    P(`Thanks for completing the interest form and welcome to Missouri Young Democrats! We're so glad you're here.`),
    P(`If there's a project or issue you're passionate about, whether it's climate justice, abortion rights, affordable housing, or something happening on your campus or in your hometown, we want to help you take action. As a member-driven organization, you shape what we work on, how we show up, and the direction this movement takes. You are the leaders of your campuses, and together we'll lead Missouri into a more just, inclusive, and hopeful future.`),
    P(`How to get plugged in:`),
    H("&#128172;", "Join the Slack"),
    P(`We use Slack as our digital organizing HQ. You can ${A(SLACK_JOIN, "click here to join our Slack workspace")} and start connecting with other members across Missouri. If you've already received an invite, check your inbox and accept it. Once you're in, say hi in #general and join the #college-democrats channel to connect with other college chapter members statewide!`),
    H("&#128075;", "Meet your Missouri College Democrats leadership"),
    P(`We want to introduce you to the Co-Chairs of Missouri College Democrats, Jaelyn Woodley and Elena Wierich. They're here to support you and help you plug into organizing opportunities on campus and beyond. You'll see them active in the #college-democrats channel&mdash;don't hesitate to reach out!`),
    H("&#10024;", "Introduce yourself"),
    P(`We want to get to know you! If you feel comfortable, upload a profile picture to your Slack profile and drop a short intro in the #college-democrats channel. Let us know what school you're at, your graduation year, and what brought you to this movement. It's a great way to meet other student organizers across the state who care about the same things you do.`),
    H("&#128241;", "Visit the Members Portal"),
    P(`${A(PORTAL, "Head here")} to access your Missouri Young Democrats member hub. You can add your membership card to Apple or Google Wallet, review meeting minutes, see opportunities to volunteer and get involved, and view resources and governing documents.`),
    H("&#128276;", "Stay in the loop"),
    P(`Be sure to download the Slack app and turn on notifications so you don't miss out. We'll be sharing updates about statewide actions, training opportunities, and ways to get involved. We'll also post a poll soon to pick the best time for our recurring college caucus call.`),
    H("&#128577;", "Get more involved"),
    P(`To get more involved in our statewide organization, the best route is to join a committee via their Slack channel and introduce yourself to the chair and co-chair. We have committees focused on communications, fundraising, policy advocacy, political affairs, membership outreach, and more. Find the one that matches your interests and jump in!`),
    P(`Together, we are building something powerful and I can't wait to see what we'll do with this momentum. Whether you want to lead, learn, or just get involved, we're glad you're with us.`),
    P(`If you ever have questions or want to hop on a call, DM me in Slack, call or text 816-898-3612, or reply to this email.`),
    P(`Let's get to work!`),
    P(`Sincerely,`),
  ].join("\n");
}

// --- 4.3 HIGH SCHOOL welcome (verbatim, spec §4.3) ---------------------------
function highSchoolBody(first: string): string {
  const n = escapeHtml(first);
  return [
    P(`Hi ${n}!`),
    P(`Thanks for completing the interest form and welcome to Missouri Young Democrats! We're so glad you're here.`),
    P(`If there's a project or issue you're passionate about, whether it's climate justice, abortion rights, affordable housing, or something happening at your school or in your hometown, we want to help you take action. As a member-driven organization, you shape what we work on, how we show up, and the direction this movement takes. You are the leaders of your schools, and together we'll lead Missouri into a more just, inclusive, and hopeful future.`),
    P(`How to get plugged in:`),
    H("&#128172;", "Join the Slack"),
    P(`We use Slack as our digital organizing HQ. You can ${A(SLACK_JOIN, "click here to join our Slack workspace")} and start connecting with other members across Missouri. If you've already received an invite, check your inbox and accept it. Once you're in, say hi in #general and join the #high-school-democrats channel to connect with other high school members statewide!`),
    H("&#128075;", "Meet your Missouri High School Democrats leadership"),
    P(`We want to introduce you to the Chair of Missouri High School Democrats, Dwayne Irvin, and Co-Chair Chelsea Schuette. They're here to support you and help you plug into organizing opportunities at your school and beyond. You'll see them active in the #high-school-democrats channel&mdash;don't hesitate to reach out!`),
    H("&#10024;", "Introduce yourself"),
    P(`We want to get to know you! If you feel comfortable, upload a profile picture to your Slack profile and drop a short intro in the #high-school-democrats channel. Let us know what school you're at, your graduation year, and what brought you to this movement. It's a great way to meet other student organizers across the state who care about the same things you do.`),
    H("&#128241;", "Visit the Members Portal"),
    P(`${A(PORTAL, "Head here")} to access your Missouri Young Democrats member hub. You can add your membership card to Apple or Google Wallet, review meeting minutes, see opportunities to volunteer and get involved, and view resources and governing documents.`),
    H("&#128276;", "Stay in the loop"),
    P(`Be sure to download the Slack app and turn on notifications so you don't miss out. We'll be sharing updates about statewide actions, training opportunities, and ways to get involved. We'll also post a poll soon to pick the best time for our recurring high school caucus call.`),
    H("&#128577;", "Get more involved"),
    P(`To get more involved in our statewide organization, the best route is to join a committee via their Slack channel and introduce yourself to the chair and co-chair. We have committees focused on communications, fundraising, policy advocacy, political affairs, membership outreach, and more. Find the one that matches your interests and jump in!`),
    P(`Together, we are building something powerful and I can't wait to see what we'll do with this momentum. Whether you want to lead, learn, or just get involved, we're glad you're with us.`),
    P(`If you ever have questions or want to hop on a call, DM me in Slack, call or text 816-898-3612, or reply to this email.`),
    P(`Let's get to work!`),
    P(`Sincerely,`),
  ].join("\n");
}

// --- 5.1 GENERAL reminder (verbatim, spec §5.1) ------------------------------
function generalReminderBody(first: string): string {
  const n = escapeHtml(first);
  return [
    P(`Hi ${n},`),
    P(`Just checking in. We noticed you haven't joined our Slack workspace yet. Slack is where all Missouri Young Democrats coordination happens, so membership isn't fully active until you're in.`),
    P(`Please take a moment to ${A(SLACK_JOIN, "click here and join the workspace")}. Once you're in, say hello in #general so we can officially welcome you.`),
    P(`If you need help or the link gives you trouble, reply to this email or text me at 816-898-3612 and I'll get you sorted.`),
    P(`Looking forward to organizing with you!`),
    P(`Sincerely,`),
  ].join("\n");
}

// --- 5.2 COLLEGE reminder (verbatim, spec §5.2) ------------------------------
function collegeReminderBody(first: string): string {
  const n = escapeHtml(first);
  return [
    P(`Hi ${n}!`),
    P(`Just checking in. We noticed you haven't joined our Slack workspace yet, and that's where all of our organizing happens.`),
    P(`&#128279; Quick join link: ${A(SLACK_JOIN, "Click here to hop into Slack")}. After you join, head over to #college-democrats to connect with other student organizers.`),
    P(`Slack is the easiest way to stay in the loop, vote on meeting times, and collaborate on projects. If you've already joined, thanks, and you can ignore this reminder.`),
    P(`If you run into any issues, reply here or send me a DM once you are in Slack.`),
    P(`Let's get to work!`),
    P(`Sincerely,`),
  ].join("\n");
}

// --- 5.3 HIGH SCHOOL reminder (verbatim, spec §5.3) --------------------------
function highSchoolReminderBody(first: string): string {
  const n = escapeHtml(first);
  return [
    P(`Hi ${n}!`),
    P(`Just checking in. We noticed you haven't joined our Slack workspace yet, and that's where all of our organizing happens.`),
    P(`&#128279; Quick join link: ${A(SLACK_JOIN, "Click here to hop into Slack")}. After you join, head over to #high-school-democrats to meet other students.`),
    P(`Slack is the easiest way to stay in the loop, vote on meeting times, and collaborate on projects. If you have already joined, thanks, and you can ignore this reminder.`),
    P(`If you run into any issues, reply here or send me a DM once you are in Slack.`),
    P(`Let's get to work!`),
    P(`Sincerely,`),
  ].join("\n");
}

export interface BuiltEmail {
  subject: string;
  html: string;
  text: string;
  cc: string[];
  from?: string; // override sender (age emails send from andrew@); defaults to info@
}

// --- 4.4 TOO YOUNG (verbatim, spec §4.4). En-dashes "–" preserved as written. ---
function tooYoungBody(first: string): string {
  const n = escapeHtml(first);
  return [
    P(`Hi ${n}!`),
    P(`Thank you for completing our interest form &#8211; we love seeing young people excited about getting involved in politics! &#127775;`),
    P(`Missouri Young Democrats membership is open to Democrats ages 14 and up, under the age of 36. Based on the birthdate you provided, it looks like you're not quite there yet &#8211; but you will be soon!`),
    P(`In the meantime, here are some ways to stay engaged and build your skills as a future leader:`),
    H("&#128241;", "Follow us on social media"),
    P(`Stay up to date on what Young Democrats are doing across Missouri. Follow us on ${A(INSTAGRAM, "Instagram")}, ${A(TIKTOK, "TikTok")}, or any of our other platforms linked below. You'll get to see the kind of work you'll be part of when you join!`),
    H("&#127979;", "Start a civic engagement club at your school"),
    P(`Talk to a teacher or counselor about starting a club focused on government, politics, or community service. It's a great way to get your classmates involved too.`),
    H("&#128499;&#65039;", "Learn about the issues"),
    P(`Start following local and state news. Understanding what's happening in your community now will make you an even more effective advocate when you're ready to join.`),
    H("&#128104;&#8205;&#128105;&#8205;&#128103;", "Get your family involved"),
    P(`Encourage the adults in your life to vote, volunteer, and stay engaged. They can get involved with the ${A(MDP, "Missouri Democratic Party")} or ${A(COUNTY_PARTY, "find their local county party")}. You can make a difference right now by helping others participate in democracy.`),
    P(`We can't wait to officially welcome you as a member when you turn 14. Until then, keep that energy and passion alive &#8211; Missouri needs young leaders like you!`),
    P(`If you believe this email was sent in error, please reply and let us know &#8211; we're happy to take another look.`),
    P(`See you soon!`),
    P(`Sincerely,`),
  ].join("\n");
}

// --- 4.5 AGED OUT (verbatim, spec §4.5). En-dashes "–" preserved as written. ----
function agedOutBody(first: string): string {
  const n = escapeHtml(first);
  return [
    P(`Hi ${n}!`),
    P(`Thank you for connecting with Missouri Young Democrats and filling out our membership form. We truly appreciate you reaching out, and it's clear you're committed to electing Democrats in Missouri!`),
    P(`I do want to be transparent about our organization's structure. Missouri Young Democrats serves Missourians ages 14 and up, under the age of 36, and based on the birthdate you provided, it looks like you've graduated from our age range, or will be soon. We keep our membership and Slack workspace limited to those within that age range to ensure the space remains representative of our membership base.`),
    P(`That said, your experience and passion are incredibly valuable to the broader Democratic movement, and there are many ways to stay involved:`),
    H("&#128052;", "Missouri Democratic Party"),
    P(`Get involved with the ${A(MDP, "Missouri Democratic Party")} and support candidates up and down the ballot.`),
    H("&#127963;&#65039;", "Your Local County Democratic Committee"),
    P(`County committees are always looking for dedicated Democrats to help with local organizing, voter outreach, and party building. ${A(COUNTY_PARTY, "Find your county party here")}.`),
    H("&#129309;", "Support Young Democrats"),
    P(`Even though you can't be a member, you can still support the next generation of Democratic leaders! Consider ${A(DONATE, "making a donation")} or mentoring young activists in your community.`),
    P(`If you ever have specific ideas for partnership or collaboration between MOYD and organizations you're involved with, please don't hesitate to reach out. Our inbox is always open!`),
    P(`If you believe this email was sent in error, please reply and let us know &#8211; we're happy to take another look.`),
    P(`Thank you again for reaching out.`),
    P(`Sincerely,`),
  ].join("\n");
}

const ANDREW_FROM = "andrew@moyoungdemocrats.org";
const INFO_CC = "info@moyoungdemocrats.org";

export function buildTooYoungEmail(first: string): BuiltEmail {
  return {
    subject: "We can't wait to welcome you to Missouri Young Democrats!",
    html: shell(tooYoungBody(first), "Missouri Young Democrats membership opens at 14. Here is how to stay engaged until then."),
    text: `Hi ${first}! Thank you for your interest in Missouri Young Democrats. Membership is open to ages 14 and up, under the age of 36; you're not quite there yet, but you will be soon. Follow us: ${INSTAGRAM}`,
    cc: [INFO_CC],
    from: ANDREW_FROM,
  };
}

export function buildAgedOutEmail(first: string): BuiltEmail {
  return {
    subject: "Thank you for your interest in Missouri Young Democrats!",
    html: shell(agedOutBody(first), "Missouri Young Democrats serves ages 14 and up, under the age of 36. Here are ways to stay involved."),
    text: `Hi ${first}! Thank you for your interest in Missouri Young Democrats. We serve Missourians ages 14 and up, under the age of 36. Ways to stay involved: Missouri Democratic Party ${MDP}, or support us ${DONATE}.`,
    cc: [INFO_CC],
    from: ANDREW_FROM,
  };
}

function plain(variant: Variant, kind: "welcome" | "reminder", first: string): string {
  // Minimal text/plain fallback (Gmail multipart). Copy carried in HTML part.
  return `Hi ${first}! Welcome to Missouri Young Democrats. Join our Slack workspace: ${SLACK_JOIN} — Members portal: ${PORTAL}`;
}

export function buildWelcomeEmail(variant: Variant, first: string): BuiltEmail {
  if (variant === "college") {
    return { subject: "Welcome Aboard!", html: shell(collegeBody(first), "Welcome to Missouri Young Democrats. Here is how to get plugged in."), text: plain(variant, "welcome", first), cc: COLLEGE_CC };
  }
  if (variant === "high_school") {
    return { subject: "Welcome Aboard!", html: shell(highSchoolBody(first), "Welcome to Missouri Young Democrats. Here is how to get plugged in."), text: plain(variant, "welcome", first), cc: HS_CC };
  }
  return { subject: "Welcome Aboard!", html: shell(generalBody(first), "Welcome to Missouri Young Democrats. Here is how to get plugged in."), text: plain(variant, "welcome", first), cc: [] };
}

export function buildReminderEmail(variant: Variant, first: string): BuiltEmail {
  if (variant === "college") {
    return { subject: "Welcome Aboard!", html: shell(collegeReminderBody(first), "You haven't joined our Slack workspace yet."), text: plain(variant, "reminder", first), cc: COLLEGE_CC };
  }
  if (variant === "high_school") {
    return { subject: "Welcome Aboard!", html: shell(highSchoolReminderBody(first), "You haven't joined our Slack workspace yet."), text: plain(variant, "reminder", first), cc: HS_CC };
  }
  return { subject: "Welcome Aboard!", html: shell(generalReminderBody(first), "You haven't joined our Slack workspace yet."), text: plain(variant, "reminder", first), cc: [] };
}

// ============================================================================
// Gmail send (real). Callers must have already applied mode routing to `to`/`cc`
// and must NOT call this in dry_run.
// Returns { id, threadId } so reminders can be threaded onto the welcome email.
// ============================================================================
export async function sendGmail(opts: {
  to: string;
  cc: string[];
  subject: string;
  html: string;
  text: string;
  threadId?: string | null;
  from?: string; // sender address; defaults to info@ (send-as alias on andrew@)
}): Promise<{ id: string; threadId: string }> {
  // Token is always minted for andrew@ (the impersonated user). From: may be
  // andrew@ itself (age emails) or the info@ send-as alias (welcomes/reminders).
  const token = await getGoogleAccessToken({
    subject: IMPERSONATE,
    scopes: ["https://www.googleapis.com/auth/gmail.send"],
  });
  const b = "mixbound";
  const fromAddr = opts.from || FROM;
  const headers = [
    `From: ${FROM_NAME} <${fromAddr}>`,
    `To: ${opts.to}`,
  ];
  if (opts.cc.length) headers.push(`Cc: ${opts.cc.join(", ")}`);
  headers.push(
    `Subject: ${rfc2047(opts.subject)}`,
    "MIME-Version: 1.0",
    `Content-Type: multipart/alternative; boundary="${b}"`,
  );
  const mime = [
    ...headers,
    "",
    `--${b}`,
    'Content-Type: text/plain; charset="UTF-8"',
    "Content-Transfer-Encoding: 8bit",
    "",
    opts.text,
    "",
    `--${b}`,
    'Content-Type: text/html; charset="UTF-8"',
    "Content-Transfer-Encoding: 8bit",
    "",
    opts.html,
    "",
    `--${b}--`,
    "",
  ].join("\r\n");
  const payload: Record<string, unknown> = { raw: b64urlMime(mime) };
  if (opts.threadId) payload.threadId = opts.threadId;
  const res = await fetch(
    "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
    { method: "POST", headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" }, body: JSON.stringify(payload) },
  );
  const out = await res.json();
  if (!res.ok) throw new Error(`gmail send failed: ${JSON.stringify(out)}`);
  return { id: out.id, threadId: out.threadId };
}

// ============================================================================
// Slack (real). Callers must NOT call these in dry_run or test mode.
// ============================================================================
export async function slackLookupByEmail(
  email: string,
  token: string,
): Promise<{ found: boolean; userId?: string; error?: string }> {
  const res = await fetch(
    `https://slack.com/api/users.lookupByEmail?email=${encodeURIComponent(email)}`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  const data = await res.json();
  if (data.ok && data.user?.id) return { found: true, userId: data.user.id };
  // users_not_found is the normal "hasn't joined yet" case.
  return { found: false, error: data.error };
}

export async function slackInvite(
  channel: string,
  userId: string,
  token: string,
): Promise<{ success: boolean; error?: string }> {
  const res = await fetch("https://slack.com/api/conversations.invite", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ channel, users: userId }),
  });
  const data = await res.json();
  if (data.ok) return { success: true };
  if (data.error === "already_in_channel") return { success: true };
  return { success: false, error: data.error };
}
