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
const ALLOWED_HEADERS =
  "authorization, x-client-info, apikey, content-type, x-supabase-api-version";
const MAX_AGE = "86400";

export function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
    "Access-Control-Allow-Methods": ALLOWED_METHODS,
    "Access-Control-Allow-Headers": ALLOWED_HEADERS,
    "Access-Control-Max-Age": MAX_AGE,
  };
}

export function handleCors(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders() });
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
