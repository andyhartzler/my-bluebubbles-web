// ============================================================================
// Shared logic for the member-onboarding cascade (the Supabase replacement for
// the n8n "Welcome Email Poolooza"). Used by member-onboard and
// onboarding-followups.
//
// SAFETY: this module never sends or writes anything on its own. Callers read
// getMode() and decide. Modes:
//   dry_run (DEFAULT / unset / unrecognized) compute + log only, no email, no
//           Slack writes.
//   test    route ALL email to ONBOARDING_TEST_EMAIL, skip ALL Slack writes.
//   live    real sends + real Slack writes.
// A real member is only ever contacted when mode === "live".
//
// AGE RULE: there is exactly ONE, and it is public.moyd_age_branch(dob,
// birth_year) in the database. It also drives the members.membership_eligible
// trigger. member-onboard calls it by RPC. This module deliberately contains NO
// age arithmetic: duplicating it in a second language is precisely the defect
// that silently broke the n8n cascade (its date nodes started subtracting
// SECONDS instead of YEARS and every person fell out of the switch with no
// branch taken). Do not reintroduce a TypeScript age gate here.
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

// --- Gmail identity ----------------------------------------------------------
const IMPERSONATE = "andrew@moyoungdemocrats.org"; // token is always minted for andrew@
export const INFO_FROM = "info@moyoungdemocrats.org";   // verified send-as alias on andrew@

// EVERY email from this cascade sends as info@moyoungdemocrats.org with the
// display name "Missouri Young Democrats". Andrew asked for that explicitly on
// 2026-08-05. It is a change from n8n, which sent the two age-branch mails as
// Andrew personally; that is why an ANDREW_FROM constant used to exist here and
// why it is now gone. Do not reintroduce a second sender identity.
const SENDER_NAMES: Record<string, string> = {
  [INFO_FROM]: "Missouri Young Democrats",
};

// --- Links referenced in the copy --------------------------------------------
const SLACK_JOIN =
  "https://join.slack.com/t/moyoungdemocrats/shared_invite/zt-37w5tg3s5-Ds2_SyOxiBRdP71_HxnXtw";
const PORTAL = "https://moyoungdemocrats.org/members";
const HOME = "https://moyoungdemocrats.org";
const INSTAGRAM = "https://www.instagram.com/moyoungdemocrats";
const TIKTOK = "https://www.tiktok.com/@moyoungdemocrats";
const DONATE = "https://secure.actblue.com/donate/moyd";
const MDP = "https://www.missouridemocrats.org";                       // Missouri Democratic Party
const COUNTY_PARTY = "https://www.missouridemocrats.org/county-parties"; // local county committee locator

// Member-facing age wording. These mirror public.moyd_age_branch, which is the
// authority: it branches too_young below 13 and aged_out above 35, on the age
// you turn in the current calendar year. The n8n copy said "14 and up", which
// disagreed with the gate by a year, so a 13 year old was onboarded as eligible
// and never saw the too-young mail. The sentence is corrected to match the rule;
// the rule was NOT changed to match the sentence.
const AGE_SENTENCE = "ages 13 and up, under the age of 36";
const AGE_MIN_WORD = "13";

// --- Slack map ---------------------------------------------------------------
export const WORKSPACE_TEAM_ID = "T0927V02T35";
// Default channels every workspace member is auto-added to.
export const DEFAULT_CHANNELS = ["C0927V0858T", "C0927V0BZMH", "C092GKFC75G"];
export const HS_CHANNEL = "C093K8GTVP0";       // #high-school-democrats
export const COLLEGE_CHANNEL = "C093HE643J7";  // #college-democrats

// Committee interest (members.committee[] values, normalized) -> channel id.
export const COMMITTEE_CHANNELS: { test: RegExp; channel: string; label: string }[] = [
  { test: /political\s*affairs/i, channel: "C093K895RTQ", label: "Political Affairs Committee" },
  { test: /policy|advocacy/i,     channel: "C094CGNE56C", label: "Policy & Advocacy Committee" },
  { test: /communications/i,      channel: "C093AED6415", label: "Communications Committee" },
  { test: /fundraising/i,         channel: "C094R094XEW", label: "Fundraising Committee" },
  { test: /membership|outreach/i, channel: "C093RMQKXRA", label: "Membership & Outreach Committee" },
];

// CC recipients. Hardcoded personal Gmails in the legacy zaps; config here.
export const COLLEGE_CC = ["jaelynwoodley@gmail.com"]; // Elena Wierich removed from exec 2026-07-14
export const HS_CC = ["korra.ravenclaw@gmail.com", "irvindwayne04@gmail.com"];

export type Variant = "general" | "college" | "high_school";

export interface MemberRow {
  id: string;
  name: string | null;
  email: string | null;
  date_of_birth: string | null;
  birth_year: number | null;
  in_school: string | null;
  school_name: string | null;
  education_level: string | null;
  desire_to_lead: string | null;
  committee: string[] | null;
  slack_user_id: string | null;
}

export function firstNameOf(name: string | null): string {
  const n = (name || "").replace(/[\r\n]+/g, " ").trim();
  const first = n.split(/\s+/)[0] || "";
  return first || "there";
}

// Variant determination. The age branch is handled separately by the
// moyd_age_branch RPC; this only picks General / College / High School.
export function computeVariant(m: MemberRow): Variant {
  const inSchool = (m.in_school || "").trim().toLowerCase();
  if (inSchool === "yes") {
    // ASK THE ANSWER BEFORE GUESSING AT IT. The membership form has a
    // dedicated education_level question whose first option is literally
    // "I'm currently in high school", and it was being ignored in favour of a
    // regex over the free-text school name. That regex is confidently wrong on
    // ordinary inputs: "Grain Valley High" has no "School" so it does not match
    // \bhigh\s*school\b, and "Warrensburg Middle School" matches nothing at
    // all, so a 16 year old and a 14 year old were both branded college
    // students. In live mode that is not cosmetic, it sends them the College
    // welcome and files them into the College Democrats Slack channel and the
    // mapped Google Group. Two real members, one of them a middle schooler,
    // are wrong under the old rule today.
    const education = (m.education_level || "").toLowerCase();
    if (education.includes("currently in high school")) return "high_school";

    const school = m.school_name || "";
    const committees = (m.committee || []).join(" ");
    // "High" without "School" is the common case in Missouri school names, and
    // "Middle"/"Junior" schools are unambiguously not college.
    if (/\b(high|hs|academy|middle|junior\s*high|prep(aratory)?)\b/i.test(school)) return "high_school";
    // Fallbacks when the school name is blank or ambiguous.
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

// Committee channels the member indicated interest in. Applies to members whose
// desire_to_lead is Yes or Maybe.
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
//
// The visual template is the candidate endorsement invitation
// (moyd-endorsement-campaign/endorsement_email_template.html), reproduced as
// table-and-inline-style email HTML: cover banner, navy greeting, body,
// navy pill CTA with a VML fallback for Outlook, hairline sign-off, social row,
// paid-for banner.
//
// NO DARK MODE. THIS WAS SETTLED BY THE OWNER LOOKING AT THE RENDERED EMAIL,
// so do not re-derive it from first principles and re-add the block. It has now
// been added, removed, re-added and removed again, which is the actual cost of
// treating this as an open engineering question.
//
// The history, because the argument FOR dark mode is genuinely reasonable and
// will occur to the next person too. A prefers-color-scheme block was added on
// the grounds that a hardcoded white card gets force-inverted by algorithm in a
// dark client, and that the block changes nothing in a light client so the
// likeness to the endorsement invitation survives either way. Both halves of
// that are true. It still produced the wrong result: Andrew opened the samples
// in a dark-mode client, saw a #0f1420 page behind a #1a2130 card, and rejected
// it. The brief was "make it look like the candidate endorsement email", and
// that email is #eef2f7 behind a white card in every client, with no
// colour-scheme rules at all.
//
// So the emails now declare "light only" and carry no dark rules. That asks the
// client not to invert rather than shipping a second, darker design.
//
// One supporting fact worth keeping, because it argues the same way: the footer
// band holds paid-for-banner.png, which is a TRANSPARENT png whose ink is dark
// (mean luminance 107 of 255). On any dark card the filed compliance disclaimer
// is unreadable. Staying light everywhere is what keeps that asset legible,
// which is a compliance reason and not only an aesthetic one.
//
// The one thing kept from the dark-mode pass is MID_BLUE. It was darkened from
// the reference's #2f7fc1 to #2b73b0. That is not cosmetic: on the white card
// the reference blue measures 4.26:1 and FAILS the 4.5:1 floor for the 12px
// body links, while #2b73b0 measures 5.02:1 and passes. The
// hues are indistinguishable side by side. Contrast wins over exact likeness on
// that one value, deliberately.
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

// --- Brand tokens (light) ----------------------------------------------------
const NAVY = "#263351";
const BODY_TX = "#333333";
// 5.02:1 on the white card. The endorsement reference uses #2f7fc1, which
// measures 4.26:1 and misses the 4.5:1 floor, and it carries the body
// and every 16px body link, and body links are new here (the reference has
// none), so the darker blue is used throughout. Visually near-identical.
const MID_BLUE = "#2b73b0";
const MUTED = "#6b7280";
const HAIRLINE = "#e5e9f0";
const PAGE_BG = "#eef2f7";

const A = (href: string, text: string) =>
  `<a class="lnk" href="${href}" style="color:${MID_BLUE};font-weight:600;text-decoration:underline;">${text}</a>`;

const P = (html: string) =>
  `<p class="tx" style="margin:0 0 18px 0;color:${BODY_TX};font-size:16px;line-height:1.65;">${html}</p>`;

const H = (emoji: string, title: string) =>
  `<p class="hd" style="margin:24px 0 8px 0;color:${NAVY};font-size:16px;line-height:1.4;font-weight:700;">${emoji} ${title}</p>`;

interface Rendered {
  preheader: string;
  // "Hi Andrew!", RAW. Escaping happens once, inside shell(), on the HTML path
  // only. Escaping it here instead leaked "Hi D&#39;Angelo!" verbatim into the
  // text/plain part, which plainOf() emits without decoding.
  greeting: string;
  body: string;      // paragraphs + headings
  ctaText: string;
  ctaHref: string;
  signoff: string;   // "Sincerely,"
}

function shell(r: Rendered): string {
  return `<!DOCTYPE html><html lang="en" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta name="x-apple-disable-message-reformatting">
<meta name="color-scheme" content="light only">
<meta name="supported-color-schemes" content="light only">
<title>Missouri Young Democrats</title>
<!--[if mso]><noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript><![endif]-->
<style>
body{margin:0!important;padding:0!important;width:100%!important}
table{border-collapse:collapse}
img{border:0;line-height:100%;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic}
a{text-decoration:none}
@media only screen and (max-width:600px){
.container{width:100%!important}
.px{padding-left:24px!important;padding-right:24px!important}
.btn a{display:block!important}
}
</style></head>
<body style="margin:0;padding:0;background-color:${PAGE_BG};font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;">
<div style="display:none;max-height:0;overflow:hidden;mso-hide:all;font-size:1px;line-height:1px;color:${PAGE_BG};">${escapeHtml(r.preheader)}</div>
<table role="presentation" class="page" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color:${PAGE_BG};"><tr><td align="center" style="padding:28px 16px;">
<!--[if mso]><table role="presentation" width="600" cellspacing="0" cellpadding="0" border="0"><tr><td><![endif]-->
<table role="presentation" class="container card" width="600" cellspacing="0" cellpadding="0" border="0" style="width:600px;max-width:600px;background-color:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 1px 4px rgba(38,51,81,0.12);">

<tr><td style="font-size:0;line-height:0;">
<a href="${HOME}" target="_blank"><img src="https://email.moyd.app/media/images/cover-banner.png" width="600" alt="Missouri Young Democrats" style="display:block;width:100%;max-width:600px;height:auto;font-size:15px;line-height:1.4;font-weight:700;color:${NAVY};"></a>
</td></tr>

<tr><td class="px" style="padding:36px 44px 30px 44px;">


<p class="hd" style="color:${NAVY};font-size:20px;line-height:1.5;margin:0 0 20px 0;font-weight:700;">${escapeHtml(r.greeting)}</p>

${r.body}

<table role="presentation" class="btn" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:26px 0 30px 0;"><tr><td align="center">
<!--[if mso]>
<v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w="urn:schemas-microsoft-com:office:word" href="${r.ctaHref}" style="height:52px;v-text-anchor:middle;width:320px;" arcsize="14%" fillcolor="${NAVY}" stroke="f">
<w:anchorlock/>
<center style="color:#ffffff;font-family:Arial,sans-serif;font-size:17px;font-weight:bold;">${r.ctaText}</center>
</v:roundrect>
<![endif]-->
<!--[if !mso]><!-- -->
<a class="cta" href="${r.ctaHref}" target="_blank" style="display:inline-block;background-color:${NAVY};color:#ffffff;font-size:17px;font-weight:700;line-height:1;text-decoration:none;padding:18px 40px;border-radius:8px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;">${r.ctaText}</a>
<!--<![endif]-->
</td></tr></table>

<p class="tx rule" style="color:${BODY_TX};font-size:15px;line-height:1.6;margin:8px 0 0 0;padding-top:22px;border-top:1px solid ${HAIRLINE};">
${r.signoff}<br>
<strong class="hd" style="color:${NAVY};">Andrew Hartzler</strong><br>
<span class="mut" style="color:${MUTED};font-size:13px;">President, Missouri Young Democrats</span>
</p>

</td></tr>

<tr><td class="plate" style="background-color:#ffffff;padding:6px 40px 26px 40px;text-align:center;">
<a href="https://www.facebook.com/MOyoungdemocrats" target="_blank" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/facebook-circle-256.png" width="32" height="32" alt="Facebook" style="display:inline-block;width:32px;height:32px;"></a>
<a href="${INSTAGRAM}" target="_blank" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/instagram-circle-256_2.png" width="32" height="32" alt="Instagram" style="display:inline-block;width:32px;height:32px;"></a>
<a href="https://threads.net/moyoungdemocrats" target="_blank" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/threadsss-circle-256.png" width="32" height="32" alt="Threads" style="display:inline-block;width:32px;height:32px;"></a>
<a href="https://x.com/moyoungdems" target="_blank" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/twitter-circle-256_2.png" width="32" height="32" alt="X" style="display:inline-block;width:32px;height:32px;"></a>
<a href="https://bsky.app/profile/moyoungdemocrats.bsky.social" target="_blank" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/bluesky-circle-256_3.png" width="32" height="32" alt="Bluesky" style="display:inline-block;width:32px;height:32px;"></a>
<a href="https://www.reddit.com/user/moyoungdemocrats" target="_blank" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/reddit-circle-256_1.png" width="32" height="32" alt="Reddit" style="display:inline-block;width:32px;height:32px;"></a>
</td></tr>

<tr><td class="plate" style="background-color:#ffffff;padding:0 40px 30px 40px;text-align:center;font-size:0;line-height:0;">
<img src="https://email.moyd.app/media/images/paid-for-banner.png" width="300" alt="Paid for by Missouri Young Democrats" style="display:inline-block;width:300px;max-width:80%;height:auto;font-size:13px;line-height:1.4;color:#4b5563;">
</td></tr>

</table>
<!--[if mso]></td></tr></table><![endif]-->
</td></tr></table></body></html>`;
}

// ============================================================================
// text/plain twin. Derived FROM the rendered HTML body rather than written
// separately, so the two parts can never drift and no second copy of the
// member-facing wording exists. (The previous implementation ignored its own
// `kind` argument and sent welcome text inside every reminder.)
// ============================================================================
const NAMED_ENTITIES: Record<string, string> = {
  amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ",
  middot: "·", mdash: "-", ndash: "-",
};

function decodeEntities(s: string): string {
  return s
    .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(Number(d)))
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&([a-z]+);/gi, (m, n) => NAMED_ENTITIES[n.toLowerCase()] ?? m);
}

function htmlToText(html: string): string {
  return decodeEntities(
    html
      .replace(/<a\b[^>]*href="([^"]*)"[^>]*>([\s\S]*?)<\/a>/gi, (_, href, text) =>
        `${text.replace(/<[^>]+>/g, "").trim()} (${href})`)
      .replace(/<br\s*\/?>/gi, "\n")
      .replace(/<\/p>/gi, "\n\n")
      .replace(/<[^>]+>/g, ""),
  )
    .replace(/[ \t]+/g, " ")
    .replace(/ *\n */g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function plainOf(r: Rendered): string {
  return [
    r.greeting,
    "",
    htmlToText(r.body),
    "",
    `${r.ctaText}: ${r.ctaHref}`,
    "",
    r.signoff,
    "Andrew Hartzler",
    "President, Missouri Young Democrats",
    "moyoungdemocrats.org",
  ].join("\n");
}

// --- GENERAL welcome ---------------------------------------------------------
function generalBody(): string {
  return [
    P(`Thanks for completing the interest form and welcome to Missouri Young Democrats! We're so glad you're here.`),
    P(`We are a member-driven organization, so you shape what we work on, how we show up, and the direction this movement takes. You are the leaders of your communities, and together we'll lead Missouri into a more just, inclusive, and hopeful future.`),
    P(`How to get plugged in:`),
    H("&#128172;", "Join the Slack"),
    P(`We use Slack as our digital organizing HQ. You can ${A(SLACK_JOIN, "click here to join our Slack workspace")} and start connecting with other members across Missouri. If you've already received an invite, check your inbox and accept it. Once you're in, say hi in #general!`),
    H("&#10024;", "Introduce yourself"),
    P(`We want to get to know you! If you feel comfortable, upload a profile picture to your Slack profile and drop a short intro in the #general channel. Let us know where you're from in Missouri and what brought you to this movement. It's a great way to meet other folks across the state who care about the same things you do.`),
    H("&#128241;", "Visit the Members Portal"),
    P(`${A(PORTAL, "Head here")} to access your Missouri Young Democrats member hub. You can add your membership card to Apple or Google Wallet, review meeting minutes, see opportunities to volunteer and get involved, and view resources and governing documents.`),
    H("&#128276;", "Stay in the loop"),
    P(`Be sure to download the Slack app and turn on notifications so you don't miss out. We'll be sharing updates about statewide actions, training opportunities, and ways to get involved. We'll also post a poll soon to pick the best time for our recurring monthly meeting.`),
    H("&#128153;", "Get more involved"),
    P(`To get more involved in our statewide organization, the best route is to join a committee via their Slack channel and introduce yourself to the chair and co-chair. We have committees focused on communications, fundraising, policy advocacy, political affairs, membership outreach, and more. Find the one that matches your interests and jump in!`),
    P(`Together, we are building something powerful and I can't wait to see what we'll do with this momentum. Whether you want to lead, learn, or just get involved, we're glad you're with us.`),
    P(`If you ever have questions or want to hop on a call, DM me in Slack, call or text 816-898-3612, or reply to this email.`),
    P(`Let's get to work!`),
  ].join("\n");
}

// --- COLLEGE welcome ---------------------------------------------------------
function collegeBody(): string {
  return [
    P(`Thanks for completing the interest form and welcome to Missouri Young Democrats! We're so glad you're here.`),
    P(`We are a member-driven organization, so you shape what we work on, how we show up, and the direction this movement takes. You are the leaders of your campuses, and together we'll lead Missouri into a more just, inclusive, and hopeful future.`),
    P(`How to get plugged in:`),
    H("&#128172;", "Join the Slack"),
    P(`We use Slack as our digital organizing HQ. You can ${A(SLACK_JOIN, "click here to join our Slack workspace")} and start connecting with other members across Missouri. If you've already received an invite, check your inbox and accept it. Once you're in, say hi in #general and join the #college-democrats channel to connect with other college chapter members statewide!`),
    // NO "Meet your leadership" section. Andrew removed it from both the college
    // and high school variants on 2026-08-04. It named serving officers in
    // evergreen copy, which is a maintenance trap: the previous version still
    // introduced a co-chair who had been off the exec since 2026-07-14, so the
    // email was introducing new members to someone who had left. The officers
    // are still CC'd (COLLEGE_CC / HS_CC), which is how they learn about a new
    // member, and the caucus channel below is where people actually meet them.
    H("&#10024;", "Introduce yourself"),
    P(`We want to get to know you! If you feel comfortable, upload a profile picture to your Slack profile and drop a short intro in the #college-democrats channel. Let us know what school you're at, your graduation year, and what brought you to this movement. It's a great way to meet other student organizers across the state who care about the same things you do.`),
    H("&#128241;", "Visit the Members Portal"),
    P(`${A(PORTAL, "Head here")} to access your Missouri Young Democrats member hub. You can add your membership card to Apple or Google Wallet, review meeting minutes, see opportunities to volunteer and get involved, and view resources and governing documents.`),
    H("&#128276;", "Stay in the loop"),
    P(`Be sure to download the Slack app and turn on notifications so you don't miss out. We'll be sharing updates about statewide actions, training opportunities, and ways to get involved. We'll also post a poll soon to pick the best time for our recurring college caucus call.`),
    H("&#128153;", "Get more involved"),
    P(`To get more involved in our statewide organization, the best route is to join a committee via their Slack channel and introduce yourself to the chair and co-chair. We have committees focused on communications, fundraising, policy advocacy, political affairs, membership outreach, and more. Find the one that matches your interests and jump in!`),
    P(`Together, we are building something powerful and I can't wait to see what we'll do with this momentum. Whether you want to lead, learn, or just get involved, we're glad you're with us.`),
    P(`If you ever have questions or want to hop on a call, DM me in Slack, call or text 816-898-3612, or reply to this email.`),
    P(`Let's get to work!`),
  ].join("\n");
}

// --- HIGH SCHOOL welcome -----------------------------------------------------
function highSchoolBody(): string {
  return [
    P(`Thanks for completing the interest form and welcome to Missouri Young Democrats! We're so glad you're here.`),
    P(`We are a member-driven organization, so you shape what we work on, how we show up, and the direction this movement takes. You are the leaders of your schools, and together we'll lead Missouri into a more just, inclusive, and hopeful future.`),
    P(`How to get plugged in:`),
    H("&#128172;", "Join the Slack"),
    P(`We use Slack as our digital organizing HQ. You can ${A(SLACK_JOIN, "click here to join our Slack workspace")} and start connecting with other members across Missouri. If you've already received an invite, check your inbox and accept it. Once you're in, say hi in #general and join the #high-school-democrats channel to connect with other high school members statewide!`),
    // NO "Meet your leadership" section here either. Same reason as the college
    // variant above: named officers in evergreen copy go stale silently.
    H("&#10024;", "Introduce yourself"),
    P(`We want to get to know you! If you feel comfortable, upload a profile picture to your Slack profile and drop a short intro in the #high-school-democrats channel. Let us know what school you're at, your graduation year, and what brought you to this movement. It's a great way to meet other student organizers across the state who care about the same things you do.`),
    H("&#128241;", "Visit the Members Portal"),
    P(`${A(PORTAL, "Head here")} to access your Missouri Young Democrats member hub. You can add your membership card to Apple or Google Wallet, review meeting minutes, see opportunities to volunteer and get involved, and view resources and governing documents.`),
    H("&#128276;", "Stay in the loop"),
    P(`Be sure to download the Slack app and turn on notifications so you don't miss out. We'll be sharing updates about statewide actions, training opportunities, and ways to get involved. We'll also post a poll soon to pick the best time for our recurring high school caucus call.`),
    H("&#128153;", "Get more involved"),
    P(`To get more involved in our statewide organization, the best route is to join a committee via their Slack channel and introduce yourself to the chair and co-chair. We have committees focused on communications, fundraising, policy advocacy, political affairs, membership outreach, and more. Find the one that matches your interests and jump in!`),
    P(`Together, we are building something powerful and I can't wait to see what we'll do with this momentum. Whether you want to lead, learn, or just get involved, we're glad you're with us.`),
    P(`If you ever have questions or want to hop on a call, DM me in Slack, call or text 816-898-3612, or reply to this email.`),
    P(`Let's get to work!`),
  ].join("\n");
}

// --- Reminder bodies ---------------------------------------------------------
function generalReminderBody(): string {
  return [
    P(`Just checking in. We noticed you haven't joined our Slack workspace yet. Slack is where all Missouri Young Democrats coordination happens, so membership isn't fully active until you're in.`),
    P(`Please take a moment to ${A(SLACK_JOIN, "click here and join the workspace")}. Once you're in, say hello in #general so we can officially welcome you.`),
    P(`If you need help or the link gives you trouble, reply to this email or text me at 816-898-3612 and I'll get you sorted.`),
    P(`Looking forward to organizing with you!`),
  ].join("\n");
}

function collegeReminderBody(): string {
  return [
    P(`Just checking in. We noticed you haven't joined our Slack workspace yet, and that's where all of our organizing happens.`),
    P(`&#128279; Quick join link: ${A(SLACK_JOIN, "Click here to hop into Slack")}. After you join, head over to #college-democrats to connect with other student organizers.`),
    P(`Slack is the easiest way to stay in the loop, vote on meeting times, and collaborate on projects. If you've already joined, thanks, and you can ignore this reminder.`),
    P(`If you run into any issues, reply here or send me a DM once you are in Slack.`),
    P(`Let's get to work!`),
  ].join("\n");
}

function highSchoolReminderBody(): string {
  return [
    P(`Just checking in. We noticed you haven't joined our Slack workspace yet, and that's where all of our organizing happens.`),
    P(`&#128279; Quick join link: ${A(SLACK_JOIN, "Click here to hop into Slack")}. After you join, head over to #high-school-democrats to meet other students.`),
    P(`Slack is the easiest way to stay in the loop, vote on meeting times, and collaborate on projects. If you have already joined, thanks, and you can ignore this reminder.`),
    P(`If you run into any issues, reply here or send me a DM once you are in Slack.`),
    P(`Let's get to work!`),
  ].join("\n");
}

// --- TOO YOUNG ---------------------------------------------------------------
function tooYoungBody(): string {
  return [
    P(`Thank you for completing our interest form. We love seeing young people excited about getting involved in politics! &#127775;`),
    P(`Missouri Young Democrats membership is open to Democrats ${AGE_SENTENCE}. Based on the birthdate you provided, it looks like you're not quite there yet, but you will be soon!`),
    P(`In the meantime, here are some ways to stay engaged and build your skills as a future leader:`),
    H("&#128241;", "Follow us on social media"),
    P(`Stay up to date on what Young Democrats are doing across Missouri. Follow us on ${A(INSTAGRAM, "Instagram")}, ${A(TIKTOK, "TikTok")}, or any of our other platforms linked below. You'll get to see the kind of work you'll be part of when you join!`),
    H("&#127979;", "Start a civic engagement club at your school"),
    P(`Talk to a teacher or counselor about starting a club focused on government, politics, or community service. It's a great way to get your classmates involved too.`),
    H("&#128499;&#65039;", "Learn about the issues"),
    P(`Start following local and state news. Understanding what's happening in your community now will make you an even more effective advocate when you're ready to join.`),
    H("&#128104;&#8205;&#128105;&#8205;&#128103;", "Get your family involved"),
    P(`Encourage the adults in your life to vote, volunteer, and stay engaged. They can get involved with the ${A(MDP, "Missouri Democratic Party")} or ${A(COUNTY_PARTY, "find their local county party")}. You can make a difference right now by helping others participate in democracy.`),
    P(`We can't wait to officially welcome you as a member when you turn ${AGE_MIN_WORD}. Until then, keep that energy and passion alive. Missouri needs young leaders like you!`),
    P(`If you believe this email was sent in error, please reply and let us know. We're happy to take another look.`),
    P(`See you soon!`),
  ].join("\n");
}

// --- AGED OUT ----------------------------------------------------------------
function agedOutBody(): string {
  return [
    P(`Thank you for connecting with Missouri Young Democrats and filling out our membership form. We truly appreciate you reaching out, and it's clear you're committed to electing Democrats in Missouri!`),
    P(`I do want to be transparent about our organization's structure. Missouri Young Democrats serves Missourians ${AGE_SENTENCE}, and based on the birthdate you provided, it looks like you've graduated from our age range, or will be soon. We keep our membership and Slack workspace limited to those within that age range to ensure the space remains representative of our membership base.`),
    P(`That said, your experience and passion are incredibly valuable to the broader Democratic movement, and there are many ways to stay involved:`),
    H("&#128052;", "Missouri Democratic Party"),
    P(`Get involved with the ${A(MDP, "Missouri Democratic Party")} and support candidates up and down the ballot.`),
    H("&#127963;&#65039;", "Your Local County Democratic Committee"),
    P(`County committees are always looking for dedicated Democrats to help with local organizing, voter outreach, and party building. ${A(COUNTY_PARTY, "Find your county party here")}.`),
    H("&#129309;", "Support Young Democrats"),
    P(`Even though you can't be a member, you can still support the next generation of Democratic leaders! Consider ${A(DONATE, "making a donation")} or mentoring young activists in your community.`),
    P(`If you ever have specific ideas for partnership or collaboration between MOYD and organizations you're involved with, please don't hesitate to reach out. Our inbox is always open!`),
    P(`If you believe this email was sent in error, please reply and let us know. We're happy to take another look.`),
    P(`Thank you again for reaching out.`),
  ].join("\n");
}

export interface BuiltEmail {
  subject: string;
  html: string;
  text: string;
  cc: string[];
  from: string;
  replyTo?: string;
}

function build(r: Rendered): { html: string; text: string } {
  return { html: shell(r), text: plainOf(r) };
}

export function buildTooYoungEmail(first: string): BuiltEmail {
  const r: Rendered = {
    preheader: `Missouri Young Democrats membership opens at ${AGE_MIN_WORD}. Here is how to stay engaged until then.`,
    greeting: `Hi ${first}!`,
    body: tooYoungBody(),
    ctaText: "Follow us on Instagram",
    ctaHref: INSTAGRAM,
    signoff: "Sincerely,",
  };
  return {
    subject: "We can't wait to welcome you to Missouri Young Democrats!",
    ...build(r),
    // The zap CC'd info@ on both age-branch emails, so somebody inside MOYD
    // learns that an applicant was turned away. Kept, and kept deliberately:
    // now that From is info@ too this reads like a copy to itself, and it is
    // not one. Gmail files the one message under SENT and INBOX both, so it
    // lands unread in the mailbox. That was checked against real mail rather
    // than assumed, including the 2026-07-26 MEC filing confirmations, which
    // carry From info@, Cc info@ and the labels UNREAD, SENT and INBOX.
    //
    // It is also not the only record, so do not bolt a second notification on
    // top of it. The applicant is written to public.members before this
    // function runs, and 20260714_03's BEFORE INSERT trigger stamps
    // membership_eligible false for BOTH branches, which is the "Ineligible
    // Members" section of the CRM members list. A live send additionally
    // leaves an age_branch_notified row in onboarding_tasks carrying the
    // branch. Three channels already answer "did a 12 year old apply".
    cc: [INFO_FROM],
    from: INFO_FROM,
    replyTo: INFO_FROM,
  };
}

export function buildAgedOutEmail(first: string): BuiltEmail {
  const r: Rendered = {
    preheader: `Missouri Young Democrats serves ${AGE_SENTENCE}. Here are ways to stay involved.`,
    greeting: `Hi ${first}!`,
    body: agedOutBody(),
    ctaText: "Support Young Democrats",
    ctaHref: DONATE,
    signoff: "Sincerely,",
  };
  return {
    subject: "Thank you for your interest in Missouri Young Democrats!",
    ...build(r),
    cc: [INFO_FROM], // see buildTooYoungEmail
    from: INFO_FROM,
    replyTo: INFO_FROM,
  };
}



const WELCOME_BODY: Record<Variant, () => string> = {
  general: generalBody, college: collegeBody, high_school: highSchoolBody,
};

const REMINDER_BODY: Record<Variant, () => string> = {
  general: generalReminderBody, college: collegeReminderBody, high_school: highSchoolReminderBody,
};

const CC_FOR: Record<Variant, string[]> = {
  general: [], college: COLLEGE_CC, high_school: HS_CC,
};

export function buildWelcomeEmail(variant: Variant, first: string): BuiltEmail {
  const r: Rendered = {
    preheader: "Welcome to Missouri Young Democrats. Here is how to get plugged in.",
    greeting: `Hi ${first}!`,
    body: WELCOME_BODY[variant](),
    ctaText: "Join our Slack workspace",
    ctaHref: SLACK_JOIN,
    signoff: "Sincerely,",
  };
  return {
    subject: "Welcome Aboard!",
    ...build(r),
    cc: CC_FOR[variant],
    from: INFO_FROM,
    replyTo: INFO_FROM, // all six n8n welcome/reminder nodes set replyTo info@
  };
}

export function buildReminderEmail(variant: Variant, first: string): BuiltEmail {
  const r: Rendered = {
    preheader: "You haven't joined our Slack workspace yet.",
    greeting: `Hi ${first}!`,
    body: REMINDER_BODY[variant](),
    ctaText: "Join our Slack workspace",
    ctaHref: SLACK_JOIN,
    signoff: "Sincerely,",
  };
  return {
    // n8n's reminders used their own subject. Reusing "Welcome Aboard!" made a
    // reminder indistinguishable from the original welcome in the inbox.
    subject: "Don't forget to join us on Slack!",
    ...build(r),
    // The zap CC'd the college / high school officers on their reminders. This
    // key used to be followed immediately by `cc: []`, and the second one won,
    // so every reminder shipped with an empty CC.
    cc: CC_FOR[variant],
    from: INFO_FROM,
    replyTo: INFO_FROM,
  };
}

// ============================================================================
// Gmail send (real). Callers must have already applied mode routing to to/cc
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
  from?: string;
  replyTo?: string;
}): Promise<{ id: string; threadId: string }> {
  // Token is always minted for andrew@ (the impersonated user). From: may be
  // andrew@ itself (age emails) or the info@ send-as alias (welcomes/reminders).
  const token = await getGoogleAccessToken({
    subject: IMPERSONATE,
    scopes: ["https://www.googleapis.com/auth/gmail.send"],
  });
  const b = "mixbound";
  const fromAddr = opts.from || INFO_FROM;
  const fromName = SENDER_NAMES[fromAddr] || "Missouri Young Democrats";
  const headers = [
    `From: ${fromName} <${fromAddr}>`,
    `To: ${opts.to}`,
  ];
  if (opts.cc.length) headers.push(`Cc: ${opts.cc.join(", ")}`);
  if (opts.replyTo) headers.push(`Reply-To: ${opts.replyTo}`);
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

// Programmatic workspace invite. This is the one capability the n8n cascade had
// that the first Supabase build dropped: n8n called Slack user:invite with the
// team id and the three default channels, which actually pushes the person into
// the workspace instead of waiting for them to self-serve the shared join link.
// Requires an admin-scoped token (admin.users:write). Failure is non-fatal: the
// shared join link is still in the email and the followup poller still runs.
export async function slackWorkspaceInvite(
  email: string,
  channels: string[],
  token: string,
): Promise<{ ok: boolean; error?: string }> {
  const res = await fetch("https://slack.com/api/admin.users.invite", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json; charset=utf-8" },
    body: JSON.stringify({
      email,
      team_id: WORKSPACE_TEAM_ID,
      channel_ids: channels.join(","),
      // Do not resend. member-onboard is idempotent everywhere else, and a
      // retried call must not put a second invite in the member's inbox.
      // Slack answers already_invited instead, which is treated as success.
      resend: false,
    }),
  });
  const data = await res.json();
  if (data.ok) return { ok: true };
  // Already present or already invited is success, not an error.
  if (data.error === "already_in_team" || data.error === "already_invited" ||
      data.error === "already_in_team_invited_user") {
    return { ok: true, error: data.error };
  }
  return { ok: false, error: data.error };
}

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

// ============================================================================
// Confirm the Slack user id before inviting.
//
// The zap did a fresh users.lookupByEmail before EVERY invite and trusted no
// stored id. This build seeded from members.slack_user_id and only looked up
// when that was null, which sends a stale id straight to conversations.invite:
// 241 members carry a stored id and 12 mapping rows are already flagged deleted
// in Slack. One API call restores the zap's own guard.
//
// The stored id is used only when the lookup fails for a reason that is not
// "this person is not in Slack" (a network error, a rate limit, a bad token).
// users_not_found is an ANSWER, and the answer is no.
// ============================================================================
export async function confirmSlackUserId(
  email: string,
  storedId: string | null,
  token: string,
): Promise<{ userId: string | null; via: string }> {
  const look = await slackLookupByEmail(email, token);
  if (look.found && look.userId) {
    return { userId: look.userId, via: storedId && storedId !== look.userId ? "lookup (stored id was stale)" : "lookup" };
  }
  if (look.error === "users_not_found") return { userId: null, via: "lookup: not in Slack" };
  if (storedId) return { userId: storedId, via: `stored id (lookup errored: ${look.error})` };
  return { userId: null, via: `lookup failed: ${look.error}` };
}

// ============================================================================
// Recording what the cascade did.
//
// public.slack_channel_membership_log is what the CRM Slack page renders, and
// the onboarding cascade wrote nothing to it, so a whole live onboarding run
// would leave that page silent. The row shape is EXACTLY the shape the trigger
// and Slack's own events already write; only `source` is new, so the three
// foreign-key hint embeds the CRM depends on are untouched.
//
// HARD CONSTRAINT: slack_channel_membership_log.slack_user_id has a foreign key
// to slack_user_mapping, so a log row cannot exist for a Slack user with no
// mapping row. ensureSlackUserMapping runs first. That also closes the separate
// gap that nothing linked a new member's Slack account to their member row at
// signup: linkage previously only happened later, if Slack delivered an event.
//
// Both functions FAIL SOFT. Neither may break an onboarding that has already
// emailed a real person.
// ============================================================================
export const LOG_SOURCE_ONBOARDING = "onboarding";

export async function ensureSlackUserMapping(
  supabase: { from: (t: string) => any },
  memberId: string,
  slackUserId: string,
  email: string | null,
): Promise<{ ok: boolean; error?: string }> {
  const { error } = await supabase
    .from("slack_user_mapping")
    .upsert({
      member_id: memberId,
      slack_user_id: slackUserId,
      slack_email: email,
      matched_by: "onboarding_email_lookup",
      match_confidence: 1.0,
      last_synced_at: new Date().toISOString(),
    }, { onConflict: "slack_user_id" });
  if (error) {
    console.error("[onboarding] slack_user_mapping upsert failed:", error.message);
    return { ok: false, error: error.message };
  }
  return { ok: true };
}

export async function recordChannelInvite(
  supabase: { from: (t: string) => any },
  row: {
    memberId: string;
    slackUserId: string;
    channelId: string;
    success: boolean;
    error?: string | null;
    metadata?: Record<string, unknown>;
  },
): Promise<void> {
  const { error } = await supabase.from("slack_channel_membership_log").insert({
    member_id: row.memberId,
    slack_user_id: row.slackUserId,
    slack_channel_id: row.channelId,
    action: "invited",
    source: LOG_SOURCE_ONBOARDING,
    success: row.success,
    // 'executed' because the Slack call has already been made by the time this
    // is written. The dispatch gate exists to stop UNSENT rows being sent; a
    // row recorded after the fact is history, not a queue entry, and must never
    // be picked up by the slack-sync-to-slack drain.
    dispatch: "executed",
    error_message: row.error ?? null,
    metadata: { recorded_at: new Date().toISOString(), ...(row.metadata || {}) },
  });
  if (error) console.error("[onboarding] membership log insert failed:", error.message);
}
