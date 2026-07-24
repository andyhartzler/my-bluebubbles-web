// Sends the "we received your application" thank-you email to an endorsement
// questionnaire submitter. From info@moyoungdemocrats.org (a Google Group) via
// andrew@'s verified send-as alias — Gmail token is minted for andrew@, the From
// header is info@. Called by the AFTER INSERT trigger on form_submissions
// (pg_net) for the endorsement form; also callable directly for tests.
import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { handleCors, corsHeaders } from "../_shared/cors.ts";

const IMPERSONATE = "andrew@moyoungdemocrats.org"; // real user we mint a token for
const FROM = "info@moyoungdemocrats.org"; // verified send-as alias on andrew@
const FROM_NAME = "Missouri Young Democrats";
const SUBJECT = "Thank you for applying for MOYD's 2026 endorsement";

function rfc2047(s: string): string {
  return "=?UTF-8?B?" + btoa(unescape(encodeURIComponent(s))) + "?=";
}

function b64urlMime(mime: string): string {
  // base64url of a UTF-8 string
  const bytes = new TextEncoder().encode(mime);
  let bin = "";
  bytes.forEach((b) => (bin += String.fromCharCode(b)));
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// Escape HTML special chars so a submitter-supplied name can't inject markup
// into the email body.
function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// Strict email check that also rejects header-injection (CR/LF and RFC5322
// specials). The recipient goes straight into a `To:` header.
const EMAIL_RE = /^[^\s<>"',;:\r\n]+@[^\s<>"',;:\r\n]+\.[^\s<>"',;:\r\n]+$/;

function html(firstName: string): string {
  const cleaned = (firstName || "").replace(/[\r\n]+/g, " ").trim().slice(0, 80);
  const name = cleaned ? escapeHtml(cleaned) : "there";
  return `<!DOCTYPE html><html lang="en" xmlns:v="urn:schemas-microsoft-com:vml"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><meta name="x-apple-disable-message-reformatting"><style>body{margin:0!important;padding:0!important;width:100%!important}table{border-collapse:collapse}img{border:0;line-height:100%;outline:none;text-decoration:none}a{text-decoration:none}@media only screen and (max-width:600px){.container{width:100%!important}.px{padding-left:24px!important;padding-right:24px!important}}</style></head>
<body style="margin:0;padding:0;background-color:#eef2f7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;">
<div style="display:none;max-height:0;overflow:hidden;mso-hide:all;font-size:1px;line-height:1px;color:#eef2f7;">We received your MOYD endorsement application. Endorsements will be announced soon.</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color:#eef2f7;"><tr><td align="center" style="padding:28px 16px;">
<table role="presentation" class="container" width="600" cellspacing="0" cellpadding="0" border="0" style="width:600px;max-width:600px;background-color:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 1px 4px rgba(38,51,81,0.12);">
<tr><td style="font-size:0;line-height:0;"><a href="https://moyoungdemocrats.org" target="_blank"><img src="https://email.moyd.app/media/images/cover-banner.png" width="600" alt="Missouri Young Democrats" style="display:block;width:100%;max-width:600px;height:auto;"></a></td></tr>
<tr><td class="px" style="padding:36px 44px 30px 44px;">
<div style="color:#2f7fc1;font-size:12px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;margin:0 0 12px 0;">2026 Endorsement &middot; Application received</div>
<p style="color:#263351;font-size:20px;line-height:1.5;margin:0 0 20px 0;font-weight:700;">Thank you, ${name}.</p>
<p style="color:#333333;font-size:16px;line-height:1.65;margin:0 0 18px 0;">We've received your application for the Missouri Young Democrats 2026 endorsement. Thank you for stepping up to run, and for taking the time to share where you stand.</p>
<p style="color:#333333;font-size:16px;line-height:1.65;margin:0 0 24px 0;">We will review every application closely. There's nothing more you need to do right now, we'll be in touch if we have any questions.</p>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:0 0 28px 0;"><tr><td style="background-color:#f3f6fb;border-left:4px solid #263351;border-radius:6px;padding:18px 22px;"><div style="color:#263351;font-size:18px;font-weight:700;line-height:1.4;">Endorsements will be announced soon.</div></td></tr></table>
<p style="color:#333333;font-size:16px;line-height:1.65;margin:0 0 8px 0;">Whatever the outcome, we're grateful you're in this fight for a Missouri that works for everyone. Keep going.</p>
<p style="color:#333333;font-size:15px;line-height:1.6;margin:8px 0 0 0;padding-top:22px;border-top:1px solid #e5e9f0;">In solidarity,<br><strong style="color:#263351;">The Missouri Young Democrats</strong></p>
</td></tr>
<tr><td style="padding:6px 40px 26px 40px;text-align:center;">
<a href="https://www.facebook.com/MOyoungdemocrats" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/facebook-circle-256.png" width="32" height="32" alt="Facebook" style="width:32px;height:32px;"></a>
<a href="https://www.instagram.com/moyoungdemocrats" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/instagram-circle-256_2.png" width="32" height="32" alt="Instagram" style="width:32px;height:32px;"></a>
<a href="https://threads.net/moyoungdemocrats" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/threadsss-circle-256.png" width="32" height="32" alt="Threads" style="width:32px;height:32px;"></a>
<a href="https://x.com/moyoungdems" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/twitter-circle-256_2.png" width="32" height="32" alt="X" style="width:32px;height:32px;"></a>
<a href="https://bsky.app/profile/moyoungdemocrats.bsky.social" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/bluesky-circle-256_3.png" width="32" height="32" alt="Bluesky" style="width:32px;height:32px;"></a>
<a href="https://www.reddit.com/user/moyoungdemocrats" style="display:inline-block;margin:0 5px;"><img src="https://email.moyd.app/media/images/reddit-circle-256_1.png" width="32" height="32" alt="Reddit" style="width:32px;height:32px;"></a>
</td></tr>
<tr><td style="padding:0 40px 30px 40px;text-align:center;font-size:0;line-height:0;"><img src="https://email.moyd.app/media/images/paid-for-banner.png" width="300" alt="Paid for by Missouri Young Democrats" style="display:inline-block;width:300px;max-width:80%;height:auto;"></td></tr>
</table></td></tr></table></body></html>`;
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;
  // Shared-secret gate: only the DB trigger (which sets x-webhook-secret) may
  // send. Without this the function is an unauthenticated relay that would send
  // MOYD-branded mail from info@ to any address. Constant-time-ish compare.
  const expected = Deno.env.get("TRIGGER_SECRET") || "";
  const provided = req.headers.get("x-webhook-secret") || "";
  if (!expected || provided.length !== expected.length || provided !== expected) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders(), "Content-Type": "application/json" },
    });
  }
  try {
    const { email, first_name } = await req.json();
    // Reject anything that isn't a clean single email address — CR/LF or header
    // specials here would let a submitter inject extra headers (BCC, etc.).
    if (typeof email !== "string" || email.length > 254 || !EMAIL_RE.test(email)) {
      return new Response(JSON.stringify({ error: "valid email required" }), {
        status: 400,
        headers: { ...corsHeaders(), "Content-Type": "application/json" },
      });
    }
    const safeFirst = typeof first_name === "string" ? first_name.replace(/[\r\n]+/g, " ") : "";
    const token = await getGoogleAccessToken({
      subject: IMPERSONATE,
      scopes: ["https://www.googleapis.com/auth/gmail.send"],
    });
    const text =
      "Thank you for applying for the Missouri Young Democrats 2026 endorsement. " +
      "We received your application. Endorsements will be announced soon.";
    const b = "mixbound";
    const mime = [
      `From: ${FROM_NAME} <${FROM}>`,
      `To: ${email}`,
      `Subject: ${rfc2047(SUBJECT)}`,
      "MIME-Version: 1.0",
      `Content-Type: multipart/alternative; boundary="${b}"`,
      "",
      `--${b}`,
      'Content-Type: text/plain; charset="UTF-8"',
      "Content-Transfer-Encoding: 8bit",
      "",
      text,
      "",
      `--${b}`,
      'Content-Type: text/html; charset="UTF-8"',
      "Content-Transfer-Encoding: 8bit",
      "",
      html(safeFirst),
      "",
      `--${b}--`,
      "",
    ].join("\r\n");
    const res = await fetch(
      "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ raw: b64urlMime(mime) }),
      },
    );
    const out = await res.json();
    if (!res.ok) {
      return new Response(JSON.stringify({ error: "gmail send failed", detail: out }), {
        status: 502,
        headers: { ...corsHeaders(), "Content-Type": "application/json" },
      });
    }
    return new Response(JSON.stringify({ ok: true, id: out.id }), {
      status: 200,
      headers: { ...corsHeaders(), "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders(), "Content-Type": "application/json" },
    });
  }
});
