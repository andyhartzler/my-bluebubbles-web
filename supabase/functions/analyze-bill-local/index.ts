// analyze-bill-local — Bill analysis using local gemma4 AI
// Replaces the Anthropic Claude batch pipeline with local Ollama inference
// Endpoint: ai.hartzler.app (gemma4 via Ollama)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const AI_ENDPOINT = "https://ai.hartzler.app/v1/chat/completions";
const AI_API_KEY = Deno.env.get("AI_API_KEY") ?? "";
const AI_MODEL = "gemma4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

// Wave 2 access-audit 2026-04-24: gate on authenticated user (any member).
// Bill analysis is expensive (AI calls) but reads-only on the bills table.
//
// 2026-08-20: added the x-cron-secret path. The gate below calls
// auth.getUser(), which by design only accepts a *user* JWT: a service_role
// key has no `sub`, so GoTrue rejects it and this function answered its own
// 401 {"error":"Invalid or expired JWT"} to every pg_cron tick. Job 78
// (analyze-bills-local, */5) had therefore never once processed the queue.
// Same two-path shape as openstates-sync-tracked-bills.
async function requireAuthorized(req: Request): Promise<
  | { userId: string | null; actorRole: string }
  | { error: Response }
> {
  // Path A: cron shared secret
  const cronSecret = Deno.env.get("CRON_SECRET");
  const presented = req.headers.get("x-cron-secret") ?? "";
  if (cronSecret && presented && presented === cronSecret) {
    return { userId: null, actorRole: "service_role" };
  }

  // Path B: authenticated user JWT
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer /i, "").trim();
  if (!jwt) {
    return {
      error: new Response(JSON.stringify({ error: "Missing Authorization header or x-cron-secret" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }),
    };
  }
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data: userData, error: authErr } = await userClient.auth.getUser(jwt);
  if (authErr || !userData?.user) {
    return {
      error: new Response(JSON.stringify({ error: "Invalid or expired JWT" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }),
    };
  }
  return { userId: userData.user.id, actorRole: "authenticated" };
}

const ANALYSIS_SYSTEM_PROMPT = `You are a legislative analyst for Missouri Young Democrats (MOYD), a progressive Democratic youth organization focused on empowering young Missourians (ages 14-36) in politics.

MOYD's core policy priorities:
- Education: Affordable higher ed, student debt relief, K-12 funding
- Healthcare: Medicaid expansion, reproductive rights, mental health access
- Climate: Clean energy, environmental justice, sustainability
- Voting Rights: Voter access, redistricting reform, election security
- Labor: Fair wages, worker protections, union rights
- Housing: Affordable housing, tenant protections, homelessness prevention
- Criminal Justice: Police reform, sentencing reform, reentry programs
- LGBTQ+ Rights: Discrimination protections, transgender rights
- Gun Safety: Background checks, red flag laws, assault weapons

When analyzing bills, consider:
1. Does this bill advance or hinder progressive values?
2. How does it affect young Missourians specifically?
3. What is the partisan context (who sponsors it, which party benefits)?
4. Is this a priority fight or a minor administrative change?

Respond ONLY with valid JSON. No markdown, no code blocks, no other text.`;

function buildAnalysisPrompt(bill: {
  identifier: string;
  title: string;
  text: string;
  sponsor: string;
  sponsorParty: string;
  actions: string;
}): string {
  const truncatedText = bill.text.slice(0, 6000); // gemma4 context window management
  
  return `Analyze this Missouri bill:

Bill: ${bill.identifier}
Title: ${bill.title}
Primary Sponsor: ${bill.sponsor} (${bill.sponsorParty})
Recent Actions: ${bill.actions}

Bill Text (first 6000 chars):
${truncatedText}

Respond with this exact JSON structure:
{
  "summary": "2-3 sentence summary of what the bill does",
  "summary_short": "1 sentence summary",
  "position_recommendation": "support|oppose|watch|neutral",
  "priority_recommendation": "critical|high|medium|low",
  "categories": ["array of categories from: education, healthcare, climate, voting_rights, labor, housing, criminal_justice, lgbtq, immigration, guns, taxes_budget, transportation, other"],
  "rationale": "2-3 sentences explaining why MOYD should take this position",
  "key_provisions": ["array of 3-5 key provisions in the bill"],
  "potential_impact": "2-3 sentences on how this bill would affect young Missourians and progressive priorities",
  "call_to_action": "1-2 sentences suggesting what MOYD members should do about this bill",
  "email_snippet": "2-3 sentence email paragraph MOYD could send to members about this bill"
}`;
}

async function analyzeWithGemma4(prompt: string): Promise<Record<string, unknown> | null> {
  const resp = await fetch(AI_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${AI_API_KEY}`,
    },
    body: JSON.stringify({
      model: AI_MODEL,
      messages: [
        { role: "system", content: ANALYSIS_SYSTEM_PROMPT },
        { role: "user", content: prompt },
      ],
      temperature: 0.2,
      max_tokens: 2000,
    }),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(`AI API error ${resp.status}: ${errText}`);
  }

  const data = await resp.json();
  const content = data.choices?.[0]?.message?.content ?? "";
  
  // Extract JSON from response (handle markdown code blocks)
  const jsonMatch = content.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    throw new Error(`No JSON in AI response: ${content.slice(0, 200)}`);
  }
  
  return JSON.parse(jsonMatch[0]);
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const gate = await requireAuthorized(req);
  if ("error" in gate) return gate.error;
  const actorId = gate.userId;
  const actorRole = gate.actorRole;

  try {
    const body = await req.json();
    const { billId, batchSize, processQueue } = body;

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Audit log (non-blocking)
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: actorRole,
      schema_name: "public",
      table_name: "edge_fn:analyze-bill-local",
      row_id: billId ?? null,
      context: {
        event: "analyze-bill-local",
        bill_id: billId ?? null,
        batch_size: batchSize ?? null,
        process_queue: !!processQueue,
      },
    }).then(() => {}).catch((e: unknown) => console.error("[analyze-bill-local] audit_log insert failed:", e));

    // Mode 1: Process a single bill by ID
    if (billId) {
      const { data: bill, error } = await supabase
        .from("legislation_tracked_bills")
        .select("id, bill_identifier, title, current_bill_text, primary_sponsor_name, primary_sponsor_party, latest_action_description")
        .eq("id", billId)
        .single();

      if (error || !bill) {
        return new Response(JSON.stringify({ error: "Bill not found" }), {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      if (!bill.current_bill_text || bill.current_bill_text.length < 50) {
        return new Response(JSON.stringify({ error: "Bill has no text to analyze" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const prompt = buildAnalysisPrompt({
        identifier: bill.bill_identifier,
        title: bill.title,
        text: bill.current_bill_text,
        sponsor: bill.primary_sponsor_name || "Unknown",
        sponsorParty: bill.primary_sponsor_party || "Unknown",
        actions: bill.latest_action_description || "None",
      });

      const analysis = await analyzeWithGemma4(prompt);
      if (!analysis) {
        throw new Error("AI returned empty analysis");
      }

      // Save to database
      const { error: updateError } = await supabase
        .from("legislation_tracked_bills")
        .update({
          ai_summary: analysis.summary,
          ai_summary_short: analysis.summary_short,
          ai_position_recommendation: analysis.position_recommendation,
          ai_priority_recommendation: analysis.priority_recommendation,
          ai_categories_recommendation: analysis.categories,
          ai_rationale: analysis.rationale,
          ai_key_provisions: analysis.key_provisions,
          ai_potential_impact: analysis.potential_impact,
          ai_call_to_action: analysis.call_to_action,
          ai_email_snippet: analysis.email_snippet,
          ai_analyzed_at: new Date().toISOString(),
          ai_analysis_version: `gemma4-local-v1`,
          ai_analysis_pending: false,
          ai_analysis_error: null,
        })
        .eq("id", billId);

      if (updateError) {
        throw new Error(`DB update failed: ${updateError.message}`);
      }

      return new Response(JSON.stringify({ success: true, billId, analysis }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Mode 2: Process queue of pending bills
    if (processQueue) {
      const limit = batchSize || 5;
      
      const { data: bills, error } = await supabase
        .from("legislation_tracked_bills")
        .select("id, bill_identifier, title, current_bill_text, primary_sponsor_name, primary_sponsor_party, latest_action_description")
        .eq("ai_analysis_pending", true)
        .not("current_bill_text", "is", null)
        .order("latest_action_date", { ascending: false, nullsFirst: false })
        .limit(limit);

      if (error) {
        throw new Error(`Query failed: ${error.message}`);
      }

      if (!bills || bills.length === 0) {
        return new Response(JSON.stringify({ success: true, message: "No bills pending analysis", processed: 0 }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      let processed = 0;
      let errors = 0;
      const results: Array<{ id: string; identifier: string; status: string; error?: string }> = [];

      for (const bill of bills) {
        try {
          if (!bill.current_bill_text || bill.current_bill_text.length < 50) {
            await supabase
              .from("legislation_tracked_bills")
              .update({ ai_analysis_pending: false, ai_analysis_error: "No bill text available" })
              .eq("id", bill.id);
            results.push({ id: bill.id, identifier: bill.bill_identifier, status: "skipped", error: "No text" });
            continue;
          }

          const prompt = buildAnalysisPrompt({
            identifier: bill.bill_identifier,
            title: bill.title,
            text: bill.current_bill_text,
            sponsor: bill.primary_sponsor_name || "Unknown",
            sponsorParty: bill.primary_sponsor_party || "Unknown",
            actions: bill.latest_action_description || "None",
          });

          const analysis = await analyzeWithGemma4(prompt);
          if (!analysis) {
            throw new Error("Empty AI response");
          }

          await supabase
            .from("legislation_tracked_bills")
            .update({
              ai_summary: analysis.summary,
              ai_summary_short: analysis.summary_short,
              ai_position_recommendation: analysis.position_recommendation,
              ai_priority_recommendation: analysis.priority_recommendation,
              ai_categories_recommendation: analysis.categories,
              ai_rationale: analysis.rationale,
              ai_key_provisions: analysis.key_provisions,
              ai_potential_impact: analysis.potential_impact,
              ai_call_to_action: analysis.call_to_action,
              ai_email_snippet: analysis.email_snippet,
              ai_analyzed_at: new Date().toISOString(),
              ai_analysis_version: `gemma4-local-v1`,
              ai_analysis_pending: false,
              ai_analysis_error: null,
            })
            .eq("id", bill.id);

          processed++;
          results.push({ id: bill.id, identifier: bill.bill_identifier, status: "success" });

          // Small delay between requests to not overwhelm the local AI
          await new Promise(resolve => setTimeout(resolve, 2000));
        } catch (e) {
          errors++;
          const errMsg = e instanceof Error ? e.message : String(e);
          await supabase
            .from("legislation_tracked_bills")
            .update({ ai_analysis_error: errMsg, ai_analysis_pending: false })
            .eq("id", bill.id);
          results.push({ id: bill.id, identifier: bill.bill_identifier, status: "error", error: errMsg });
        }
      }

      return new Response(JSON.stringify({ success: true, processed, errors, total: bills.length, results }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: "Provide billId or processQueue:true" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    const errMsg = e instanceof Error ? e.message : String(e);
    return new Response(JSON.stringify({ error: errMsg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
