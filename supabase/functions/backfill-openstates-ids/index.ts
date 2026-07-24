import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPEN_STATES_API_KEY = Deno.env.get("OPEN_STATES_API_KEY")!;
const OPEN_STATES_BASE_URL = "https://v3.openstates.org";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Normalize district numbers for comparison (remove leading zeros)
function normalizeDistrict(district: string): string {
  return String(parseInt(district, 10));
}

// Normalize name for comparison (lowercase, remove extra spaces)
function normalizeName(name: string): string {
  return name.toLowerCase().trim().replace(/\s+/g, ' ');
}

// Calculate name similarity score (0-1)
function nameSimilarity(name1: string, name2: string): number {
  const n1 = normalizeName(name1);
  const n2 = normalizeName(name2);
  
  // Exact match
  if (n1 === n2) return 1.0;
  
  // Check if one contains the other (for nickname variations)
  if (n1.includes(n2) || n2.includes(n1)) return 0.9;
  
  // Split into parts and compare
  const parts1 = n1.split(' ');
  const parts2 = n2.split(' ');
  
  // Compare last names (usually more reliable)
  const lastName1 = parts1[parts1.length - 1];
  const lastName2 = parts2[parts2.length - 1];
  
  if (lastName1 !== lastName2) return 0.0;
  
  // Last names match, check first names
  const firstName1 = parts1[0];
  const firstName2 = parts2[0];
  
  if (firstName1 === firstName2) return 0.95;
  
  // Check if first name is initial or nickname
  if (firstName1[0] === firstName2[0]) return 0.7;
  
  return 0.5; // Last name match only
}

// Fetch all legislators from Open States for a given chamber
async function fetchOpenStatesLegislators(chamber: string): Promise<any[]> {
  const allLegislators: any[] = [];
  let page = 1;
  let hasMore = true;
  
  while (hasMore) {
    const queryParams = new URLSearchParams({
      jurisdiction: "mo",
      org_classification: chamber,
      per_page: "50",
      page: String(page),
    });
    
    const url = `${OPEN_STATES_BASE_URL}/people?${queryParams.toString()}`;
    console.log(`Fetching Open States page ${page} for ${chamber}:`, url);
    
    const response = await fetch(url, {
      headers: {
        "X-API-KEY": OPEN_STATES_API_KEY,
        "Accept": "application/json",
      },
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      console.error(`Open States API error: ${response.status}`, errorText);
      throw new Error(`Open States API error: ${response.status}`);
    }
    
    const data = await response.json();
    const results = data.results || [];
    
    allLegislators.push(...results);
    
    // Check pagination
    const pagination = data.pagination;
    if (pagination && pagination.page < pagination.max_page) {
      page++;
      // Rate limiting - 1 request per second
      await new Promise(resolve => setTimeout(resolve, 1100));
    } else {
      hasMore = false;
    }
  }
  
  return allLegislators;
}

// Find best match for a legislator in Open States data
function findBestMatch(
  legislator: { name: string; chamber: string; district: string; first_name?: string; last_name?: string },
  openStatesLegislators: any[]
): { match: any | null; score: number; matchType: string } {
  const normalizedDistrict = normalizeDistrict(legislator.district);
  
  let bestMatch: any = null;
  let bestScore = 0;
  let matchType = "none";
  
  for (const osl of openStatesLegislators) {
    const oslDistrict = osl.current_role?.district;
    if (!oslDistrict) continue;
    
    const normalizedOslDistrict = normalizeDistrict(oslDistrict);
    
    // District must match
    if (normalizedDistrict !== normalizedOslDistrict) continue;
    
    // Calculate name similarity
    const fullNameScore = nameSimilarity(legislator.name, osl.name);
    
    // Also try matching by first + last name if available
    let componentScore = 0;
    if (legislator.first_name && legislator.last_name && osl.given_name && osl.family_name) {
      const firstMatch = normalizeName(legislator.first_name) === normalizeName(osl.given_name);
      const lastMatch = normalizeName(legislator.last_name) === normalizeName(osl.family_name);
      
      if (firstMatch && lastMatch) componentScore = 1.0;
      else if (lastMatch) componentScore = 0.7;
    }
    
    const score = Math.max(fullNameScore, componentScore);
    
    if (score > bestScore) {
      bestScore = score;
      bestMatch = osl;
      
      if (score >= 0.95) matchType = "exact";
      else if (score >= 0.7) matchType = "high_confidence";
      else if (score >= 0.5) matchType = "last_name_only";
      else matchType = "low_confidence";
    }
  }
  
  return { match: bestMatch, score: bestScore, matchType };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const { 
      dryRun = false,           // If true, don't update database, just return matches
      chamber = null,           // Filter to specific chamber ('upper' or 'lower')
      minConfidence = 0.7,      // Minimum match score to auto-update
      limit = null,             // Limit number of legislators to process
    } = body;

    console.log("Starting backfill with options:", { dryRun, chamber, minConfidence, limit });

    // Step 1: Fetch legislators missing openstates_person_id
    let query = supabase
      .from("legislation_legislators")
      .select("id, name, first_name, last_name, chamber, district, party")
      .is("openstates_person_id", null)
      .eq("is_current", true);
    
    if (chamber) {
      query = query.eq("chamber", chamber);
    }
    
    if (limit) {
      query = query.limit(limit);
    }

    const { data: missingLegislators, error: fetchError } = await query;

    if (fetchError) {
      throw new Error(`Failed to fetch legislators: ${fetchError.message}`);
    }

    if (!missingLegislators || missingLegislators.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "No legislators missing openstates_person_id",
          processed: 0,
          matched: 0,
          unmatched: 0,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Found ${missingLegislators.length} legislators missing openstates_person_id`);

    // Step 2: Fetch Open States legislators for each chamber needed
    const chambersNeeded = new Set(missingLegislators.map(l => l.chamber));
    const openStatesData: Record<string, any[]> = {};

    for (const c of chambersNeeded) {
      console.log(`Fetching Open States data for ${c} chamber...`);
      openStatesData[c] = await fetchOpenStatesLegislators(c);
      console.log(`Fetched ${openStatesData[c].length} legislators from Open States for ${c}`);
      
      // Rate limiting between chamber fetches
      if (chambersNeeded.size > 1) {
        await new Promise(resolve => setTimeout(resolve, 1100));
      }
    }

    // Step 3: Match each legislator
    const results = {
      matched: [] as any[],
      unmatched: [] as any[],
      lowConfidence: [] as any[],
      updated: [] as any[],
      errors: [] as any[],
    };

    for (const legislator of missingLegislators) {
      const { match, score, matchType } = findBestMatch(
        legislator,
        openStatesData[legislator.chamber] || []
      );

      const result = {
        id: legislator.id,
        name: legislator.name,
        chamber: legislator.chamber,
        district: legislator.district,
        matchedTo: match?.name || null,
        openstatesId: match?.id || null,
        score,
        matchType,
      };

      if (!match || score < 0.5) {
        results.unmatched.push(result);
      } else if (score < minConfidence) {
        results.lowConfidence.push(result);
      } else {
        results.matched.push(result);

        // Update database if not dry run
        if (!dryRun) {
          const { error: updateError } = await supabase
            .from("legislation_legislators")
            .update({
              openstates_person_id: match.id,
              updated_at: new Date().toISOString(),
            })
            .eq("id", legislator.id);

          if (updateError) {
            results.errors.push({
              ...result,
              error: updateError.message,
            });
          } else {
            results.updated.push(result);
          }
        }
      }
    }

    // Step 4: Return results
    const response = {
      success: true,
      dryRun,
      minConfidence,
      summary: {
        processed: missingLegislators.length,
        matched: results.matched.length,
        updated: results.updated.length,
        lowConfidence: results.lowConfidence.length,
        unmatched: results.unmatched.length,
        errors: results.errors.length,
      },
      details: {
        matched: results.matched,
        updated: dryRun ? [] : results.updated,
        lowConfidence: results.lowConfidence,
        unmatched: results.unmatched,
        errors: results.errors,
      },
    };

    console.log("Backfill complete:", response.summary);

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("Backfill error:", err);
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});