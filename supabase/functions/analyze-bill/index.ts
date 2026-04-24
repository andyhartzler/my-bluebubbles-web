// Wave 4 access-audit 2026-04-24: user-JWT + is_staff() gate OR x-cron-secret + audit_log.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const anthropicApiKey = Deno.env.get("ANTHROPIC_API_KEY");
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

async function requireAuthorized(req) {
  const cronSecret = Deno.env.get("CRON_SECRET");
  const presented = req.headers.get("x-cron-secret") ?? "";
  if (cronSecret && presented && presented === cronSecret) {
    return { actorId: null, actorRole: "service_role" };
  }
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer /i, "").trim();
  if (!jwt) {
    return {
      error: new Response(JSON.stringify({ error: "Missing Authorization header or x-cron-secret" }), {
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
  const { data: staffCheck, error: staffErr } = await userClient.rpc("is_staff");
  if (staffErr || staffCheck !== true) {
    return {
      error: new Response(JSON.stringify({ error: "Forbidden — staff access required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  return { actorId: userData.user.id, actorRole: "authenticated" };
}
// MOYD Policy Platform Summary for Claude
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
// Available categories with descriptions
const CATEGORIES = [
  {
    name: "climate",
    display: "Climate & Environment",
    keywords: "climate, environment, clean energy, pollution, conservation, renewable, emissions"
  },
  {
    name: "healthcare",
    display: "Healthcare",
    keywords: "healthcare, medicaid, ACA, hospitals, doctors, reproductive rights, abortion, medical"
  },
  {
    name: "education",
    display: "Education",
    keywords: "education, schools, teachers, students, college, university, k-12, curriculum"
  },
  {
    name: "voting_rights",
    display: "Voting Rights",
    keywords: "voting, elections, redistricting, registration, ballots, polling, campaigns"
  },
  {
    name: "labor",
    display: "Labor & Workers",
    keywords: "labor, workers, unions, wages, minimum wage, workplace, employment, jobs"
  },
  {
    name: "housing",
    display: "Housing",
    keywords: "housing, rent, tenants, landlords, homeless, affordable housing, zoning"
  },
  {
    name: "criminal_justice",
    display: "Criminal Justice",
    keywords: "criminal justice, police, prisons, sentencing, courts, incarceration, bail"
  },
  {
    name: "lgbtq",
    display: "LGBTQ+ Rights",
    keywords: "lgbtq, transgender, gay, lesbian, discrimination, gender identity, marriage equality"
  },
  {
    name: "immigration",
    display: "Immigration",
    keywords: "immigration, immigrants, deportation, asylum, border, citizenship, DACA"
  },
  {
    name: "guns",
    display: "Gun Safety",
    keywords: "guns, firearms, weapons, ammunition, background checks, second amendment"
  },
  {
    name: "taxes_budget",
    display: "Taxes & Budget",
    keywords: "taxes, budget, fiscal, revenue, spending, appropriations, tax credits"
  },
  {
    name: "transportation",
    display: "Transportation",
    keywords: "transportation, roads, highways, transit, public transportation, infrastructure"
  },
  {
    name: "other",
    display: "Other",
    keywords: "other"
  }
];
// Build the analysis prompt
function buildAnalysisPrompt(bill) {
  const billText = bill.current_bill_text || bill.primary_abstract || bill.title;
  const hasFullText = !!bill.current_bill_text;
  return `You are a policy analyst for the Missouri Young Democrats (MOYD), a progressive Democratic youth organization. Your task is to analyze a Missouri state bill against MOYD's official policy platform and provide recommendations.

${POLICY_PLATFORM}

## AVAILABLE CATEGORIES
${CATEGORIES.map((c)=>`- ${c.name}: ${c.display} (${c.keywords})`).join('\n')}

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
  "categories": ["category1", "category2"],
  "rationale": "2-3 paragraphs explaining WHY you recommend this position/priority based on specific MOYD platform positions",
  "key_provisions": [
    {"provision": "Brief description of key provision 1", "alignment": "aligns|conflicts|neutral"},
    {"provision": "Brief description of key provision 2", "alignment": "aligns|conflicts|neutral"}
  ],
  "potential_impact": "1-2 paragraphs on how this bill would impact Missourians if passed"
}
\`\`\`

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
- Choose 1-3 most relevant categories (can include "other" if none fit well)

Respond ONLY with the JSON object, no additional text.`;
}
// Call Claude API
async function analyzeWithClaude(prompt) {
  const startTime = Date.now();
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": anthropicApiKey,
      "anthropic-version": "2023-06-01"
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-20250514",
      max_tokens: 4000,
      messages: [
        {
          role: "user",
          content: prompt
        }
      ]
    })
  });
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Claude API error: ${response.status} - ${errorText}`);
  }
  const data = await response.json();
  const duration = Date.now() - startTime;
  // Extract JSON from response
  const content = data.content[0].text;
  // Try to parse JSON from the response
  let analysis;
  try {
    // Handle case where Claude wraps in markdown code blocks
    const jsonMatch = content.match(/```json\s*([\s\S]*?)\s*```/) || content.match(/```\s*([\s\S]*?)\s*```/);
    const jsonStr = jsonMatch ? jsonMatch[1] : content;
    analysis = JSON.parse(jsonStr.trim());
  } catch (e) {
    throw new Error(`Failed to parse Claude response as JSON: ${e.message}`);
  }
  return {
    analysis,
    tokensUsed: data.usage?.input_tokens + data.usage?.output_tokens,
    durationMs: duration,
    modelVersion: "claude-sonnet-4-20250514"
  };
}
// Main handler
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
  const gate = await requireAuthorized(req);
  if ("error" in gate) return gate.error;
  const { actorId, actorRole } = gate;
  try {
    const { billId, forceReanalyze = false } = await req.json();
    // Audit log (non-blocking)
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: actorRole,
      schema_name: "public",
      table_name: "edge_fn:analyze-bill",
      row_id: null,
      context: {
        event: "analyze-bill",
        bill_id: billId,
        force_reanalyze: forceReanalyze
      }
    }).then(() => {}).catch((e) => console.error("[analyze-bill] audit_log insert failed:", e));
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
    // Get bill data
    const { data: bill, error: billError } = await supabase.from("legislation_tracked_bills").select("*").eq("id", billId).single();
    if (billError || !bill) {
      return new Response(JSON.stringify({
        error: "Bill not found",
        details: billError
      }), {
        status: 404,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Check if already analyzed (unless forcing reanalysis)
    if (!forceReanalyze && bill.ai_analyzed_at) {
      return new Response(JSON.stringify({
        success: true,
        message: "Bill already analyzed",
        alreadyAnalyzed: true,
        analyzedAt: bill.ai_analyzed_at
      }), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Mark as pending
    await supabase.from("legislation_tracked_bills").update({
      ai_analysis_pending: true,
      ai_analysis_error: null
    }).eq("id", billId);
    // Build prompt and analyze
    const prompt = buildAnalysisPrompt(bill);
    const { analysis, tokensUsed, durationMs, modelVersion } = await analyzeWithClaude(prompt);
    // Validate categories
    const validCategories = CATEGORIES.map((c)=>c.name);
    const filteredCategories = (analysis.categories || []).filter((c)=>validCategories.includes(c));
    // Update bill with analysis
    const { error: updateError } = await supabase.from("legislation_tracked_bills").update({
      ai_summary: analysis.summary,
      ai_summary_short: analysis.summary_short,
      ai_position_recommendation: analysis.position_recommendation,
      ai_priority_recommendation: analysis.priority_recommendation,
      ai_categories_recommendation: filteredCategories,
      ai_rationale: analysis.rationale,
      ai_key_provisions: analysis.key_provisions,
      ai_potential_impact: analysis.potential_impact,
      ai_analyzed_at: new Date().toISOString(),
      ai_analysis_version: `${modelVersion}-v1`,
      ai_analysis_pending: false,
      ai_analysis_error: null
    }).eq("id", billId);
    if (updateError) {
      throw new Error(`Failed to save analysis: ${updateError.message}`);
    }
    // Store in history (optional)
    await supabase.from("legislation_ai_analysis_history").insert({
      bill_id: billId,
      summary: analysis.summary,
      summary_short: analysis.summary_short,
      position_recommendation: analysis.position_recommendation,
      priority_recommendation: analysis.priority_recommendation,
      categories_recommendation: filteredCategories,
      rationale: analysis.rationale,
      key_provisions: analysis.key_provisions,
      potential_impact: analysis.potential_impact,
      model_version: modelVersion,
      prompt_version: "v1",
      bill_text_hash: bill.current_bill_text_hash,
      tokens_used: tokensUsed,
      analysis_duration_ms: durationMs
    });
    return new Response(JSON.stringify({
      success: true,
      billId,
      analysis,
      tokensUsed,
      durationMs
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    console.error("Analysis failed:", err);
    // Try to mark error on bill if we have the ID
    try {
      const { billId } = await req.clone().json();
      if (billId) {
        await supabase.from("legislation_tracked_bills").update({
          ai_analysis_pending: false,
          ai_analysis_error: err.message
        }).eq("id", billId);
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
