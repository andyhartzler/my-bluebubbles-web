// ============================================================
// EDGE FUNCTION: analyze-bills-batch-submit — RETIRED 2026-08-23
// ============================================================
//
// This function submitted bill analysis to the ANTHROPIC MESSAGE BATCHES API
// (POST https://api.anthropic.com/v1/messages/batches) and recorded the returned
// batch id in public.legislation_ai_batches for analyze-bills-batch-check to poll.
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
// 2. THE SYNCHRONOUS PATH ALREADY EXISTS AND IS THE ONE IN USE. analyze-bills-batch
//    selects the same bill set and calls analyze-bill per bill with a 2s pace,
//    behind the standard gate (x-cron-secret, or a user JWT that passes is_staff()).
//    The CRM calls that one, from ai_analysis_service.dart. Rebuilding a second
//    synchronous fan-out here would be duplication, not migration.
//
// 3. NOTHING CALLED THIS. No cron job, no edge function and no Flutter call site
//    references it. public.legislation_ai_batches holds 8 rows, all completed,
//    newest 2026-01-19, so nothing has been submitted through here in seven months.
//
// It also closes a hole. This function shipped with verify_jwt=false and NO gate
// of its own, so any anonymous caller could make it spend money. That is the same
// shape as the mail-poll 401 recorded in AGENTS.md: the fix is a gate on the
// caller, never a wider door. Retiring it removes the door.
//
// IF BULK ANALYSIS IS EVER WANTED AGAIN, use analyze-bills-batch. If bulk talking
// points is wanted, copy analyze-bills-batch and point it at generate-talking-points;
// keep its gate.
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
      error: "analyze-bills-batch-submit is retired",
      retired_on: "2026-08-23",
      reason:
        "The Anthropic Message Batches API is no longer used and the Vertex AI Express credential has no batch equivalent.",
      use_instead: "analyze-bills-batch",
    }),
    { status: 410, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
