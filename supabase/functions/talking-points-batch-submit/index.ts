// ============================================================
// EDGE FUNCTION: talking-points-batch-submit
// Submits analyzed bills for talking points generation via Claude Batch API
// ============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anthropicApiKey = Deno.env.get("ANTHROPIC_API_KEY")!;

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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
function buildTalkingPointsPrompt(bill: any): string {
  const position = bill.position || bill.ai_position_recommendation || 'watching';
  const positionLabel = position === 'support' ? 'SUPPORT' : 
                        position === 'oppose' ? 'OPPOSE' : 'WATCHING';
  
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
// CREATE BATCH REQUEST
// ============================================================
function createBatchRequest(bill: any): { custom_id: string; params: any } {
  const prompt = buildTalkingPointsPrompt(bill);
  
  return {
    custom_id: bill.id,
    params: {
      model: "claude-sonnet-4-20250514",
      max_tokens: 4000,
      messages: [
        {
          role: "user",
          content: prompt,
        },
      ],
    },
  };
}

// ============================================================
// MAIN HANDLER
// ============================================================
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const { 
      forceRegenerate = false, 
      limit = null,
      batchSize = 1000,
      dryRun = false,
      session = null,
      positionFilter = null, // Optional: 'support', 'oppose', 'watching', 'neutral'
      priorityFilter = null  // Optional: 'critical', 'high', 'medium', 'low'
    } = await req.json();

    // Build query for bills that need talking points
    // IMPORTANT: Only bills that have been analyzed can get talking points
    let query = supabase
      .from("legislation_tracked_bills")
      .select("*")
      .not("ai_analyzed_at", "is", null) // Must be analyzed first
      .order("ai_priority_recommendation", { ascending: true }) // Critical first
      .order("created_at", { ascending: true });

    // Filter by session if specified
    if (session) {
      query = query.eq("session", session);
    }

    // Filter by position if specified
    if (positionFilter) {
      query = query.or(`position.eq.${positionFilter},ai_position_recommendation.eq.${positionFilter}`);
    }

    // Filter by priority if specified
    if (priorityFilter) {
      query = query.eq("ai_priority_recommendation", priorityFilter);
    }

    // Unless forcing regeneration, only get bills without talking points
    if (!forceRegenerate) {
      query = query.is("ai_talking_points", null);
    }

    // Apply limit if specified
    if (limit) {
      query = query.limit(limit);
    }

    const { data: bills, error: billsError } = await query;

    if (billsError) {
      throw new Error(`Failed to fetch bills: ${billsError.message}`);
    }

    if (!bills || bills.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "No analyzed bills need talking points",
          billCount: 0,
          hint: "Bills must be analyzed before talking points can be generated. Run analysis batch first.",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Found ${bills.length} bills for talking points generation`);

    // Estimate costs
    const estimatedInputTokens = bills.length * 2500; // ~2.5k tokens per prompt
    const estimatedOutputTokens = bills.length * 2000; // ~2k tokens per response (talking points are detailed)
    const estimatedCost = (estimatedInputTokens * 0.00075 / 1000) + (estimatedOutputTokens * 0.00375 / 1000);

    // Dry run - just return stats
    if (dryRun) {
      // Count by position
      const positionCounts: Record<string, number> = {};
      const priorityCounts: Record<string, number> = {};
      
      bills.forEach((b: any) => {
        const pos = b.position || b.ai_position_recommendation || 'unknown';
        const pri = b.ai_priority_recommendation || 'unknown';
        positionCounts[pos] = (positionCounts[pos] || 0) + 1;
        priorityCounts[pri] = (priorityCounts[pri] || 0) + 1;
      });

      return new Response(
        JSON.stringify({
          success: true,
          dryRun: true,
          billCount: bills.length,
          estimatedBatches: Math.ceil(bills.length / batchSize),
          estimatedInputTokens,
          estimatedOutputTokens,
          estimatedCostUSD: estimatedCost.toFixed(2),
          byPosition: positionCounts,
          byPriority: priorityCounts,
          sampleBillIds: bills.slice(0, 5).map((b: any) => ({ 
            id: b.id, 
            identifier: b.bill_identifier,
            position: b.position || b.ai_position_recommendation,
            priority: b.ai_priority_recommendation,
          })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Split bills into batches
    const batches: any[][] = [];
    for (let i = 0; i < bills.length; i += batchSize) {
      batches.push(bills.slice(i, i + batchSize));
    }

    const submittedBatches: any[] = [];

    for (let batchIndex = 0; batchIndex < batches.length; batchIndex++) {
      const batchBills = batches[batchIndex];
      const billIds = batchBills.map((b: any) => b.id);

      // Create batch record in our database first
      const { data: batchRecord, error: batchError } = await supabase
        .from("legislation_ai_batches")
        .insert({
          batch_type: "talking_points",
          status: "pending",
          total_requests: batchBills.length,
          bill_ids: billIds,
          model_version: "claude-sonnet-4-20250514",
          prompt_version: "v1-talking-points",
          notes: `Talking Points Batch ${batchIndex + 1} of ${batches.length} (${batchBills.length} bills)`,
        })
        .select()
        .single();

      if (batchError) {
        throw new Error(`Failed to create batch record: ${batchError.message}`);
      }

      // Create batch requests
      const requests = batchBills.map((bill: any) => createBatchRequest(bill));

      // Submit to Anthropic Batch API
      const response = await fetch("https://api.anthropic.com/v1/messages/batches", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": anthropicApiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({ requests }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        
        // Update batch record with error
        await supabase
          .from("legislation_ai_batches")
          .update({
            status: "failed",
            error_message: `Anthropic API error: ${response.status} - ${errorText}`,
          })
          .eq("id", batchRecord.id);
          
        throw new Error(`Anthropic Batch API error: ${response.status} - ${errorText}`);
      }

      const batchResponse = await response.json();
      console.log(`Talking Points Batch ${batchIndex + 1} submitted:`, batchResponse.id);

      // Update batch record with Anthropic response
      await supabase
        .from("legislation_ai_batches")
        .update({
          anthropic_batch_id: batchResponse.id,
          status: "submitted",
          processing_status: batchResponse.processing_status,
          submitted_at: new Date().toISOString(),
          expires_at: batchResponse.expires_at,
        })
        .eq("id", batchRecord.id);

      // Update bills to reference this batch
      await supabase
        .from("legislation_tracked_bills")
        .update({
          ai_talking_points_batch_id: batchRecord.id,
          ai_talking_points_pending: true,
          ai_talking_points_error: null,
        })
        .in("id", billIds);

      submittedBatches.push({
        internalBatchId: batchRecord.id,
        anthropicBatchId: batchResponse.id,
        billCount: batchBills.length,
        status: batchResponse.processing_status,
        expiresAt: batchResponse.expires_at,
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Submitted ${batches.length} talking points batch(es) for processing`,
        totalBills: bills.length,
        estimatedCostUSD: estimatedCost.toFixed(2),
        batches: submittedBatches,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("Talking points batch submission failed:", err);

    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});