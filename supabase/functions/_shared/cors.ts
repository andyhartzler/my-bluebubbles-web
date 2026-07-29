// CORS helper for mail-* edge functions.
//
// Browsers fire an OPTIONS preflight before any cross-origin POST that
// carries Authorization or non-simple headers. Our edge fns previously
// returned 405 on anything non-POST, including the preflight, which
// caused the browser to block the actual POST with:
//   "No 'Access-Control-Allow-Origin' header is present on the
//    requested resource"
//
// Use this from each handler:
//   const cors = handleCors(req);
//   if (cors) return cors;
//   ...
//   return jsonWithCors({ ok: true });
//
// `handleCors` returns a 204 with the right headers when the request is
// an OPTIONS preflight; otherwise null (caller continues normally).
// `corsHeaders` always returns the headers, so handlers can spread them
// into their own Response objects.

const ALLOWED_ORIGIN = "*";
const ALLOWED_METHODS = "POST, OPTIONS";

// Fallback only, for the case where the browser did not tell us which headers
// it intends to send. A hand-maintained allow-list here is a trap.
//
// The CRM wraps its whole Supabase client in SentryHttpClient
// (lib/services/crm/supabase_service.dart) and tracesSampleRate is 0.2
// (lib/main.dart). On a sampled session Sentry attaches `sentry-trace` and
// `baggage` to every outgoing request, so the browser asked permission for two
// headers this list did not grant, failed the preflight, and never sent the
// POST at all. Dart surfaces that as "ClientException: Failed to fetch", which
// is Sentry FLUTTER-5 on mail-identities-get. It looked intermittent because it
// tracks trace sampling, not the caller and not the function.
//
// The same hardcoded list on verify-phone, phone-signin and
// lookup-email-by-phone locked execs out of phone sign-in on 2026-07-28 and was
// fixed there the same way. Reflecting the request means a future SDK or
// instrumentation header cannot reopen this.
const ALLOWED_HEADERS =
  "authorization, x-client-info, apikey, content-type, " +
  "x-supabase-api-version, x-supabase-client-platform, " +
  "x-supabase-client-platform-version, x-region, sentry-trace, baggage";
const MAX_AGE = "86400";

// `req` is optional so the ~29 handlers that spread corsHeaders() into their
// own responses keep working unchanged. Access-Control-Allow-Headers is only
// read by the browser on the preflight response, so reflecting it in
// handleCors is what actually fixes the block.
export function corsHeaders(req?: Request): Record<string, string> {
  const requested = req?.headers.get("access-control-request-headers");
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
    "Access-Control-Allow-Methods": ALLOWED_METHODS,
    "Access-Control-Allow-Headers": requested && requested.trim().length > 0
      ? requested
      : ALLOWED_HEADERS,
    "Access-Control-Max-Age": MAX_AGE,
  };
}

export function handleCors(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }
  return null;
}

export function withCors(headers: HeadersInit = {}): Headers {
  const h = new Headers(headers);
  for (const [k, v] of Object.entries(corsHeaders())) {
    h.set(k, v);
  }
  return h;
}
