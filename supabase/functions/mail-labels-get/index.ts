// mail-labels-get: returns the user-defined Gmail label IDs (Answered,
// Forwarded) the dart side stamps on messages when the composer fires
// reply / forward. Tiny — env lookup + caller resolution only.
import { resolveCaller } from "../_shared/alias-resolver.ts";

import { handleCors, corsHeaders } from "../_shared/cors.ts";
Deno.serve(async (req) => {
  const _cors = handleCors(req);
  if (_cors) return _cors;
  if (req.method !== "POST") return new Response("Use POST", { status: 405 });
  const caller = await resolveCaller(req);
  if (caller instanceof Response) return caller;

  const answered = Deno.env.get("GMAIL_LABEL_ANSWERED_ID") ?? "";
  const forwarded = Deno.env.get("GMAIL_LABEL_FORWARDED_ID") ?? "";
  if (!answered || !forwarded) {
    return new Response(
      JSON.stringify({ error: "labels_not_configured" }),
      { status: 500, headers: { ...corsHeaders(), "Content-Type": "application/json" } },
    );
  }
  return new Response(
    JSON.stringify({ answeredLabelId: answered, forwardedLabelId: forwarded }),
    { headers: { ...corsHeaders(), "Content-Type": "application/json" } },
  );
});
