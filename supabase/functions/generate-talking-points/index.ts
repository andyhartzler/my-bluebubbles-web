// ============================================================
// EDGE FUNCTION: generate-talking-points
// Individual bill talking points generation using Claude API
// ============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { callGemini } from "../_shared/gemini.ts";
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};
// Wave 2 access-audit 2026-04-24: gate on authenticated user.
async function requireAuthenticatedUser(req) {
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer /i, "").trim();
  if (!jwt) {
    return {
      error: new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } }
  });
  const { data: userData, error: authErr } = await userClient.auth.getUser(jwt);
  if (authErr || !userData?.user) {
    return {
      error: new Response(JSON.stringify({ error: "Invalid or expired JWT" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  return { userId: userData.user.id };
}
// ============================================================
// MOYD VOICE GUIDELINES
// ============================================================
const MOYD_VOICE_GUIDELINES = `
# Missouri Young Democrats Voice & Values

## Our Core Identity
We are young Missourians fighting for a more just, equitable, and progressive future. We believe in:
- Economic justice and workers' rights
- Civil rights and equality for all
- Environmental protection and climate action
- Quality healthcare and education as rights, not privileges
- Criminal justice reform and police accountability
- Voting rights and democratic participation

## Our Tone
- **Passionate but professional** - We care deeply but communicate clearly
- **Hopeful but realistic** - We acknowledge challenges while inspiring action
- **Inclusive** - We speak to all Missourians, not just Democrats
- **Youth-focused** - We emphasize how issues affect young people
- **Action-oriented** - We always provide a path forward

## Language Guidelines
- Use "we" and "our" to build community
- Lead with values, follow with facts
- Connect policy to real people's lives
- Avoid jargon - be accessible to everyone
- Be bold but not inflammatory
- Emphasize Missouri-specific impacts when possible

## Key Phrases We Use
- "Working families"
- "Every Missourian deserves..."
- "Our generation's future"
- "Common-sense solutions"
- "Putting people over politics"
- "Building a Missouri that works for everyone"

## What We Avoid
- Personal attacks on individuals
- Partisan attacks that alienate potential allies
- Doom and gloom without hope
- Policy wonk language
- National talking points without Missouri context
`;
// ============================================================
// BUILD TALKING POINTS PROMPT
// ============================================================
function buildTalkingPointsPrompt(bill) {
  const position = bill.position || bill.ai_position_recommendation || 'watching';
  const positionLabel = position === 'support' ? 'SUPPORT' : position === 'oppose' ? 'OPPOSE' : 'WATCHING';
  const billText = bill.current_bill_text || bill.ai_summary || bill.primary_abstract || bill.title;
  const hasDetailedInfo = bill.current_bill_text || bill.ai_summary;
  return `You are a communications strategist for the Missouri Young Democrats (MOYD), a progressive Democratic youth organization. Your task is to generate compelling talking points for advocacy on a Missouri state bill.

${MOYD_VOICE_GUIDELINES}

## BILL INFORMATION
**Bill:** ${bill.bill_identifier}
**Title:** ${bill.title}
**Session:** ${bill.session}
**Our Position:** ${positionLabel}
**Primary Sponsor:** ${bill.primary_sponsor_name || 'Unknown'} (${bill.primary_sponsor_party || 'Unknown'})
**Chamber:** ${bill.from_organization_classification === 'lower' ? 'House' : 'Senate'}
**Latest Action:** ${bill.latest_action_description || 'None'}

**AI Analysis Summary:**
${bill.ai_summary || 'No detailed summary available.'}

**AI Rationale for Position:**
${bill.ai_rationale || 'No rationale available.'}

**Key Provisions Identified:**
${bill.ai_key_provisions ? JSON.stringify(bill.ai_key_provisions, null, 2) : 'None identified.'}

**Potential Impact:**
${bill.ai_potential_impact || 'No impact assessment available.'}

**Bill Text/Details:**
${hasDetailedInfo ? billText.substring(0, 8000) : `[Limited information - using title]\n${bill.title}`}

## YOUR TASK

Generate comprehensive talking points and advocacy materials. Your response must be valid JSON matching this exact structure:

\`\`\`json
{
  "talking_points": [
    {
      "type": "values",
      "point": "Lead talking point connecting to MOYD values (1-2 sentences)",
      "supporting_detail": "Brief supporting fact or example (1 sentence)"
    },
    {
      "type": "impact",
      "point": "How this affects young Missourians specifically (1-2 sentences)",
      "supporting_detail": "Concrete example or statistic"
    },
    {
      "type": "factual",
      "point": "Key factual point about the bill (1-2 sentences)",
      "supporting_detail": "Source or context"
    },
    {
      "type": "emotional",
      "point": "Human impact story framing (1-2 sentences)",
      "supporting_detail": "Who is affected and how"
    },
    {
      "type": "counter",
      "point": "Response to likely opposition arguments (1-2 sentences)",
      "supporting_detail": "Why our position is stronger"
    }
  ],
  "call_to_action": "Specific action members should take (contact legislator, attend hearing, share on social media, etc.) - 2-3 sentences",
  "twitter_posts": [
    {
      "text": "Tweet 1 (under 280 chars) - informative about what the bill does",
      "hashtags": ["MoLeg", "RelevantHashtag"]
    },
    {
      "text": "Tweet 2 (under 280 chars) - call to action for engagement",
      "hashtags": ["MoLeg", "RelevantHashtag"]
    },
    {
      "text": "Tweet 3 (under 280 chars) - values-based emotional appeal",
      "hashtags": ["MoLeg", "RelevantHashtag"]
    }
  ],
  "email_snippet": "2-3 paragraph snippet for member email alerts explaining the bill, our position, and what members can do. Should be ready to copy-paste into an email newsletter.",
  "testimony_outline": "Structured outline for 2-minute committee testimony including: 1) Opening hook (who you are, why you care), 2) Main point 1, 3) Main point 2, 4) Personal connection prompt (space for member to add their story), 5) Closing ask to committee members",
  "target_audience_points": {
    "general_public": [
      "Accessible point for average Missourian who doesn't follow politics closely",
      "Another point using everyday language"
    ],
    "legislators": [
      "Point emphasizing constituent impact and electoral implications",
      "Point about practical policy outcomes and implementation"
    ],
    "students": [
      "Point relevant to college students and young adults",
      "Point about long-term future impact on their generation"
    ],
    "working_families": [
      "Point about economic impact on household budgets",
      "Point about family wellbeing and quality of life"
    ],
    "rural_missouri": [
      "Point relevant to rural communities and small towns",
      "Point connecting to rural values and way of life"
    ]
  }
}
\`\`\`

## GUIDELINES FOR ${positionLabel} POSITION

${position === 'support' ? `
**For SUPPORT positions:**
- Lead with why this bill helps Missourians
- Emphasize alignment with MOYD values and progressive goals
- Thank the sponsor if they're a Democrat (acknowledge bipartisan support if applicable)
- Encourage members to voice support to their legislators
- Frame as common-sense, bipartisan when possible to broaden appeal
- Highlight what Missouri gains if this passes
` : position === 'oppose' ? `
**For OPPOSE positions:**
- Lead with the harm this bill would cause to Missourians
- Be firm but not personal toward sponsors - attack the policy, not the person
- Provide alternative solutions when possible
- Encourage members to voice opposition to their legislators
- Frame opposition around protecting Missourians, not partisan politics
- Highlight what Missouri loses or risks if this passes
` : `
**For WATCHING positions:**
- Present balanced information about the bill
- Note specifically what we're monitoring for (amendments, committee changes)
- Ask members to stay informed and engaged
- Highlight both potential concerns and potential benefits
- Be ready to shift to support or oppose as bill evolves
`}

## IMPORTANT REQUIREMENTS
- All content should be Missouri-specific when possible
- Include ${bill.bill_identifier} in social media posts for searchability
- Make testimony outline easy for members to personalize with their own story
- Email snippet should be ready to copy-paste into an email blast
- Keep language accessible - avoid policy jargon and legislative terminology
- Be persuasive but factually accurate - never exaggerate or mislead
- Twitter posts must be under 280 characters INCLUDING hashtags
- Each talking point should be distinct - no repetition

Respond ONLY with the JSON object, no additional text or explanation.`;
}
// ============================================================
// CALL THE MODEL — Gemini 3.6 Flash on Vertex, via _shared/gemini.ts
// ============================================================
async function generateWithModel(prompt) {
  const startTime = Date.now();
  const modelResult = await callGemini({
    prompt,
    maxTokens: 4000
  });
  const content = modelResult.text;
  const duration = Date.now() - startTime;
  // Parse JSON from response
  let result;
  try {
    const jsonMatch = content.match(/```json\s*([\s\S]*?)\s*```/) || content.match(/```\s*([\s\S]*?)\s*```/);
    const jsonStr = jsonMatch ? jsonMatch[1] : content;
    result = JSON.parse(jsonStr.trim());
  } catch (e) {
    throw new Error(`Failed to parse model response as JSON: ${e.message}\nRaw response: ${content.substring(0, 500)}`);
  }
  return {
    result,
    tokensUsed: modelResult.totalTokens,
    durationMs: duration,
    modelVersion: modelResult.modelVersion
  };
}
// ============================================================
// VALIDATE TALKING POINTS STRUCTURE
// ============================================================
function validateTalkingPoints(data) {
  const errors = [];
  if (!data) {
    errors.push("Response is empty");
    return {
      valid: false,
      errors
    };
  }
  if (!Array.isArray(data.talking_points) || data.talking_points.length === 0) {
    errors.push("Missing or empty talking_points array");
  }
  if (!data.call_to_action) {
    errors.push("Missing call_to_action");
  }
  if (!Array.isArray(data.twitter_posts) || data.twitter_posts.length === 0) {
    errors.push("Missing or empty twitter_posts array");
  }
  if (!data.email_snippet) {
    errors.push("Missing email_snippet");
  }
  if (!data.testimony_outline) {
    errors.push("Missing testimony_outline");
  }
  if (!data.target_audience_points) {
    errors.push("Missing target_audience_points");
  }
  return {
    valid: errors.length === 0,
    errors
  };
}
// ============================================================
// MAIN HANDLER
// ============================================================
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders
    });
  }
  if (req.method !== "POST") {
    return new Response("Method not allowed", {
      status: 405,
      headers: corsHeaders
    });
  }
  const gate = await requireAuthenticatedUser(req);
  if ("error" in gate) return gate.error;
  const actorId = gate.userId;
  try {
    const { billId, regenerate = false } = await req.json();
    // Audit log (non-blocking)
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: "authenticated",
      schema_name: "public",
      table_name: "edge_fn:generate-talking-points",
      row_id: billId ?? null,
      context: { event: "generate-talking-points", bill_id: billId, regenerate }
    }).then(() => {}).catch((e) => console.error("[generate-talking-points] audit_log insert failed:", e));
    if (!billId) {
      return new Response(JSON.stringify({
        error: "Missing billId parameter"
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Get bill with AI analysis
    const { data: bill, error: billError } = await supabase.from("legislation_tracked_bills").select("*").eq("id", billId).single();
    if (billError || !bill) {
      return new Response(JSON.stringify({
        error: "Bill not found",
        details: billError?.message
      }), {
        status: 404,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Check if already has talking points (unless regenerating)
    if (!regenerate && bill.ai_talking_points) {
      return new Response(JSON.stringify({
        success: true,
        alreadyGenerated: true,
        generatedAt: bill.ai_talking_points_generated_at,
        talkingPoints: {
          talking_points: bill.ai_talking_points,
          call_to_action: bill.ai_call_to_action,
          twitter_posts: bill.ai_twitter_posts,
          email_snippet: bill.ai_email_snippet,
          testimony_outline: bill.ai_testimony_outline,
          target_audience_points: bill.ai_target_audience_points
        }
      }), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Check if bill has been analyzed - talking points need position context
    if (!bill.position && !bill.ai_position_recommendation) {
      return new Response(JSON.stringify({
        error: "Bill must be analyzed first before generating talking points",
        needsAnalysis: true,
        hint: "Call /analyze-bill-ai first with this billId"
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Mark as pending
    await supabase.from("legislation_tracked_bills").update({
      ai_talking_points_pending: true,
      ai_talking_points_error: null
    }).eq("id", billId);
    // Generate talking points
    const prompt = buildTalkingPointsPrompt(bill);
    const { result, tokensUsed, durationMs, modelVersion } = await generateWithModel(prompt);
    // Validate structure
    const validation = validateTalkingPoints(result);
    if (!validation.valid) {
      throw new Error(`Invalid talking points structure: ${validation.errors.join(", ")}`);
    }
    // Update bill record
    const { error: updateError } = await supabase.from("legislation_tracked_bills").update({
      ai_talking_points: result.talking_points,
      ai_call_to_action: result.call_to_action,
      ai_twitter_posts: result.twitter_posts,
      ai_email_snippet: result.email_snippet,
      ai_testimony_outline: result.testimony_outline,
      ai_target_audience_points: result.target_audience_points,
      ai_talking_points_generated_at: new Date().toISOString(),
      ai_talking_points_pending: false,
      ai_talking_points_error: null
    }).eq("id", billId);
    if (updateError) {
      throw new Error(`Failed to save talking points: ${updateError.message}`);
    }
    // Store in history
    await supabase.from("legislation_talking_points_history").insert({
      bill_id: billId,
      talking_points: result.talking_points,
      call_to_action: result.call_to_action,
      twitter_posts: result.twitter_posts,
      email_snippet: result.email_snippet,
      testimony_outline: result.testimony_outline,
      target_audience_points: result.target_audience_points,
      model_version: modelVersion,
      prompt_version: "v1-talking-points",
      position: bill.position || bill.ai_position_recommendation,
      tokens_used: tokensUsed,
      generation_duration_ms: durationMs
    });
    return new Response(JSON.stringify({
      success: true,
      billId,
      billIdentifier: bill.bill_identifier,
      position: bill.position || bill.ai_position_recommendation,
      talkingPoints: result,
      tokensUsed,
      durationMs
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    console.error("Talking points generation failed:", err);
    // Try to mark error on bill if we have the ID
    try {
      const body = await req.clone().json();
      if (body.billId) {
        await supabase.from("legislation_tracked_bills").update({
          ai_talking_points_pending: false,
          ai_talking_points_error: err.message
        }).eq("id", body.billId);
      }
    } catch  {}
    return new Response(JSON.stringify({
      error: err.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
