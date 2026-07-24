// ============================================================
// EDGE FUNCTION: analyze-bills-batch-submit
// Submits bills for AI analysis using Claude Batch API (50% cost savings)
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
// MOYD POLICY PLATFORM
// ============================================================
const POLICY_PLATFORM = `
# Missouri Young Democrats Policy Platform (Adopted November 2025)

## ECONOMY & STATE BUDGET - We Support:
- Expansion of workers' rights and union formation
- Raising minimum wage to living wage with COLA tied to inflation
- Guaranteed paid family leave
- Progressive state income tax, higher capital gains tax
- Tax cuts for lowest earners, abolish sales tax on groceries/medicine
- Land value tax, closing corporate tax loopholes
- Affordable college tuition, limiting student debt
- Support for small businesses in rural and minority communities
- Reform of Hancock Amendment for inflation-adjusted revenue

## HUMAN & CIVIL RIGHTS - We Support:
- Healthcare as a human right
- Separation of church and state
- Study of slavery's effects and reparations
- LGBTQ+ protection from discrimination, marriage equality
- Employment/housing non-discrimination (Missouri Nondiscrimination Act)
- Gender equality in STEM, government, trades
- Disability rights, ADA enforcement, assistive technology funding
- Native American sovereignty, treaty rights, MMIW resources
- Removal of Confederate monuments from public spaces
- Transgender rights including public accommodations and military service
- Immigration reform: pathway to citizenship, DACA support, demilitarized enforcement
- Abolition of ICE detention centers, sanctuary city rights
- Increased immigration quotas, humane treatment of asylum seekers
- Two-state solution for Israel/Palestine with even-handed US approach
- Reproductive rights and bodily autonomy, oppose limits on reproductive healthcare

## HOUSING & COMMUNITY INVESTMENT - We Support:
- Section 8 and rent control initiatives
- Housing as a human right, subsidies based on need
- Tenant protections: just cause eviction, right to counsel, right to repair
- Housing First policies, permanent solutions for homeless
- Transit-oriented, walkable communities
- Removing restrictive zoning, supporting ADUs and multi-family housing
- Increased HUD funding
- Expanded food stamps, WIC, TANF programs
- Fighting food deserts, free school meals
- Expanded EITC and Child Care Tax Credit
- Free pre-K, full-day kindergarten, Head Start
- Non-discriminatory adoption/foster laws (LGBTQ+ inclusive)

## HEALTHCARE - We Support:
- Sustaining and expanding ACA
- Expanding Medicaid to bring tax dollars back to Missouri
- Medicare for All / Missouri Universal Health Care
- Full restoration of Missouri RX program
- Price transparency for pharmaceuticals
- Gender-affirming care access and funding
- HIV prophylaxis coverage
- Crisis Pregnancy Centers must provide medically accurate info

## EDUCATION - We Support:
- Fully funding public schools over charter schools and vouchers
- Five-day school week restoration
- Expanding community college access
- Supporting teachers' unions
- In-state tuition for Dreamers

## ENVIRONMENT - We Support:
- Acknowledging climate change is real and human-caused
- Just transition to 100% clean energy
- Investment in solar, wind, geothermal
- Modernizing energy grid for clean energy
- Energy efficiency policies
- Green-collar workforce training
- Strict emissions regulations on fossil fuel industries
- Protecting Missouri's water from contamination
- Increased water infrastructure funding
- Nature-based flood resilience solutions
- Science-based conservation of biodiversity
- Equitable access to public lands and green spaces
- Cleanup of contaminated sites (radioactive waste, lead)
- Holding corporations accountable for pollution
- Environmental justice for disproportionately impacted communities
- Protecting DNR enforcement powers
- No state funds for fossil fuel subsidies

## ELECTIONS & GOVERNMENT - We Support:
- Fair and free elections
- Early voting, same-day registration, no-fault absentee, vote by mail
- Independent non-partisan redistricting commissions
- Campaign finance reform (ideas over money)
- Automatic voter registration with opt-out
- DC and territory statehood/representation
- Fair compensation for poll workers, accessible polling locations
- Election Day federal holiday
- Abolition of Electoral College for popular vote
- Ranked choice voting, approval voting, proportional representation
- Open primaries
- Term limits on executive and judiciary positions
- Supreme Court reform (expand to 15, fixed terms, ethics code, end partisan elections)
- Protecting initiative petition and referendum processes

## CRIMINAL JUSTICE - We Support:
- Increased police training (mental health, de-escalation, non-lethal action)
- Least intrusive investigation methods
- Dignity and safety during incarceration
- Medical care for incarcerated (including menstrual products)
- Eliminating mandatory minimums
- Rehabilitative system emphasizing treatment and education
- Decriminalization of poverty
- Legalization of marijuana, expunging cannabis records
- Background checks, waiting periods, firearm safety training
- Mandatory arrest of abusers, victim support programs
- Restoring voting rights for those who completed sentences
- Community policing
- Mandatory body cameras for police
- Programs preventing police brutality and corruption
- Limiting qualified immunity
- Acknowledging systemic racism in policing
- Abolishing capital punishment
- Abolishing solitary confinement
- Deprivatization of prisons
- Robust public defense system
- Diverting police funding to social services
- Removing arrest quotas
- Reparations for law enforcement violence victims
- Eliminating cash bail
- Minimum wage for incarcerated labor
`;

// ============================================================
// CATEGORIES
// ============================================================
const CATEGORIES = [
  { name: "climate", display: "Climate & Environment" },
  { name: "healthcare", display: "Healthcare" },
  { name: "education", display: "Education" },
  { name: "voting_rights", display: "Voting Rights" },
  { name: "labor", display: "Labor & Workers" },
  { name: "housing", display: "Housing" },
  { name: "criminal_justice", display: "Criminal Justice" },
  { name: "lgbtq", display: "LGBTQ+ Rights" },
  { name: "immigration", display: "Immigration" },
  { name: "guns", display: "Gun Safety" },
  { name: "taxes_budget", display: "Taxes & Budget" },
  { name: "transportation", display: "Transportation" },
  { name: "other", display: "Other" },
];

// ============================================================
// BUILD ANALYSIS PROMPT
// ============================================================
function buildAnalysisPrompt(bill: any): string {
  const billText = bill.current_bill_text || bill.primary_abstract || bill.title;
  const hasFullText = !!bill.current_bill_text;
  
  return `You are a policy analyst for the Missouri Young Democrats (MOYD), a progressive Democratic youth organization. Your task is to analyze a Missouri state bill against MOYD's official policy platform and provide recommendations.

${POLICY_PLATFORM}

## AVAILABLE CATEGORIES
${CATEGORIES.map(c => `- ${c.name}: ${c.display}`).join('\n')}

## BILL TO ANALYZE
**Bill Identifier:** ${bill.bill_identifier}
**Session:** ${bill.session}
**Official Title:** ${bill.title}
**Primary Sponsor:** ${bill.primary_sponsor_name || 'Unknown'} (${bill.primary_sponsor_party || 'Unknown'})
**Chamber:** ${bill.from_organization_classification === 'lower' ? 'House' : 'Senate'}
**Latest Action:** ${bill.latest_action_description || 'None'}
**Subjects:** ${(bill.subjects || []).join(', ') || 'None listed'}

**Bill Text/Summary:**
${hasFullText ? billText.substring(0, 15000) : `[Full text not available - using abstract/title]\n${billText}`}

## YOUR ANALYSIS TASK

Analyze this bill against MOYD's policy platform and provide your analysis in the following JSON format. Be specific and cite relevant platform positions.

\`\`\`json
{
  "summary_short": "One sentence (max 150 chars) plain-language summary of what this bill does",
  "summary": "2-3 paragraph detailed summary explaining the bill's purpose, key provisions, and implications for Missourians",
  "position_recommendation": "support|oppose|watching|neutral",
  "priority_recommendation": "critical|high|medium|low",
  "category": "single_category_name",
  "rationale": "2-3 paragraphs explaining WHY you recommend this position/priority based on specific MOYD platform positions",
  "key_provisions": [
    {"provision": "Brief description of key provision 1", "alignment": "aligns|conflicts|neutral"},
    {"provision": "Brief description of key provision 2", "alignment": "aligns|conflicts|neutral"}
  ],
  "potential_impact": "1-2 paragraphs on how this bill would impact Missourians if passed"
}
\`\`\`

## CATEGORY SELECTION - CRITICAL
You MUST select exactly ONE category that best fits this bill. Choose the SINGLE most relevant category from the list above. Do NOT select multiple categories. If the bill touches multiple areas, choose the PRIMARY focus.

## POSITION GUIDELINES
- **support**: Bill clearly advances MOYD platform positions (progressive goals)
- **oppose**: Bill clearly conflicts with MOYD platform positions (harmful or regressive)
- **watching**: Bill is relevant to MOYD issues but needs more information or has mixed implications
- **neutral**: Bill doesn't significantly relate to MOYD's platform priorities

## PRIORITY GUIDELINES
- **critical**: Major legislation on core MOYD issues with high chance of passage or significant impact
- **high**: Important legislation on MOYD priorities
- **medium**: Relevant legislation worth monitoring
- **low**: Tangentially related or unlikely to advance

## IMPORTANT NOTES
- Be objective but remember you're analyzing from MOYD's progressive Democratic perspective
- If the bill text is limited, note this and be appropriately cautious in your analysis
- Consider both direct effects and downstream implications
- Cite specific platform positions when explaining your rationale
- Select exactly ONE category (the most relevant one)

Respond ONLY with the JSON object, no additional text.`;
}

// ============================================================
// CREATE BATCH REQUEST
// ============================================================
function createBatchRequest(bill: any): { custom_id: string; params: any } {
  const prompt = buildAnalysisPrompt(bill);
  
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
      forceReanalyze = false, 
      limit = null,
      batchSize = 1000,
      dryRun = false,
      session = null // Optional: filter by session
    } = await req.json();

    // Build query for bills that need analysis
    let query = supabase
      .from("legislation_tracked_bills")
      .select("*")
      .order("created_at", { ascending: true });

    // Filter by session if specified
    if (session) {
      query = query.eq("session", session);
    }

    // Unless forcing reanalysis, only get unanalyzed bills
    if (!forceReanalyze) {
      query = query.is("ai_analyzed_at", null);
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
          message: "No bills need analysis",
          billCount: 0,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Found ${bills.length} bills to analyze`);

    // Estimate costs
    const estimatedInputTokens = bills.length * 3000; // ~3k tokens per bill prompt
    const estimatedOutputTokens = bills.length * 1500; // ~1.5k tokens per response
    const estimatedCost = (estimatedInputTokens * 0.00075 / 1000) + (estimatedOutputTokens * 0.00375 / 1000);

    // Dry run - just return stats
    if (dryRun) {
      return new Response(
        JSON.stringify({
          success: true,
          dryRun: true,
          billCount: bills.length,
          estimatedBatches: Math.ceil(bills.length / batchSize),
          estimatedInputTokens,
          estimatedOutputTokens,
          estimatedCostUSD: estimatedCost.toFixed(2),
          sampleBillIds: bills.slice(0, 5).map((b: any) => ({ 
            id: b.id, 
            identifier: b.bill_identifier,
            title: b.title?.substring(0, 100)
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
          batch_type: "analysis",
          status: "pending",
          total_requests: batchBills.length,
          bill_ids: billIds,
          model_version: "claude-sonnet-4-20250514",
          prompt_version: "v2-single-category",
          notes: `Analysis Batch ${batchIndex + 1} of ${batches.length} (${batchBills.length} bills)`,
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
      console.log(`Analysis Batch ${batchIndex + 1} submitted:`, batchResponse.id);

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
          ai_batch_id: batchRecord.id,
          ai_analysis_pending: true,
          ai_analysis_error: null,
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
        message: `Submitted ${batches.length} analysis batch(es) for processing`,
        totalBills: bills.length,
        estimatedCostUSD: estimatedCost.toFixed(2),
        batches: submittedBatches,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("Analysis batch submission failed:", err);

    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});