// ============================================================
// EDGE FUNCTION: talking-points-batch-submit — RETIRED 2026-08-23
// ============================================================
//
// This function submitted talking-points generation to the ANTHROPIC MESSAGE BATCHES API
// (POST https://api.anthropic.com/v1/messages/batches) and recorded the batch id in
// public.legislation_ai_batches for talking-points-batch-check to poll.
//
// It is retired rather than migrated, for three reasons, in order of weight.
//
// 1. THERE IS NO EQUIVALENT ON THE CREDENTIAL WE NOW USE. The rest of this
//    project's AI calls now go to Gemini 3.6 Flash through _shared/gemini.ts,
//    which authenticates with a Vertex AI Express API key against
//    https://aiplatform.googleapis.com/v1/publishers/google/models. Vertex batch
//    prediction is a different product: it needs a project- and region-scoped
//    endpoint plus GCS or BigQuery input and output, none of which the Express
//    key can reach. There is no submit-now / poll-later shape to swap in, and
//    faking one would be a lie in the function name.
//
// 2. ITS OTHER HALF IS GONE. talking-points-batch-check is retired in the same change,
//    so there is nothing left to hand work to or to collect work from.
//
// 3. NOTHING CALLED THIS. No edge function and no Flutter call site references it.
//    There is no synchronous bulk twin for talking points the way analyze-bills-batch
//    is the twin for analysis, so this retirement does drop a capability. That is
//    deliberate: it has generated nothing since 2026-01-15, has no CRM call site
//    (talking_points_service.dart calls generate-talking-points one bill at a time)
//    and no active cron. Building a bulk endpoint nobody calls would be speculative.
//    The pattern to copy if one is ever wanted is analyze-bills-batch, gate included.
//
// It also closes a hole. This function shipped with verify_jwt=false and NO gate
// of its own, so any anonymous caller could make it spend money. That is the same
// shape as the mail-poll 401 recorded in AGENTS.md: the fix is a gate on the
// caller, never a wider door. Retiring it removes the door.
//
// THE SUPPORTED PATH IS generate-talking-points.
//
// Do not restore the Anthropic body. It bills a per-token card that this migration
// exists to get off.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve((req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  return new Response(
    JSON.stringify({
      error: "talking-points-batch-submit is retired",
      retired_on: "2026-08-23",
      reason:
        "The Anthropic Message Batches API is no longer used and the Vertex AI Express credential has no batch equivalent.",
      use_instead: "generate-talking-points",
    }),
    { status: 410, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
