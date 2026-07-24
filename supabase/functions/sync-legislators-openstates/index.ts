import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface OpenStatesPerson {
  id: string;
  name: string;
  given_name: string;
  family_name: string;
  image: string;
  email: string;
  party: string;
  current_role: {
    title: string;
    org_classification: string;
    district: string;
    division_id: string;
  };
  offices: Array<{
    name: string;
    address: string;
    voice: string;
    email: string;
  }>;
  links: Array<{
    url: string;
    note: string;
  }>;
  sources: Array<{
    url: string;
    note: string;
  }>;
  extras: Record<string, any>;
}

// Fetch all legislators from Open States API
async function fetchOpenStatesLegislators(
  apiKey: string,
  chamber: "upper" | "lower", 
  page: number = 1
): Promise<{
  results: OpenStatesPerson[];
  hasMore: boolean;
}> {
  const orgClassification = chamber === "upper" ? "upper" : "lower";
  
  const url = new URL("https://v3.openstates.org/people");
  url.searchParams.set("jurisdiction", "mo");
  url.searchParams.set("org_classification", orgClassification);
  url.searchParams.set("include", "offices,links,sources");
  url.searchParams.set("page", String(page));
  url.searchParams.set("per_page", "50");
  
  console.log(`Fetching from Open States: ${url.toString()}`);
  
  const response = await fetch(url.toString(), {
    headers: {
      "X-API-Key": apiKey,
      "Accept": "application/json",
    },
  });
  
  if (!response.ok) {
    const errorText = await response.text();
    console.error(`Open States API error: ${response.status} - ${errorText}`);
    throw new Error(`Open States API error: ${response.status}`);
  }
  
  const data = await response.json();
  
  return {
    results: data.results || [],
    hasMore: data.pagination?.max_page > page,
  };
}

// Download and store photo
async function downloadAndStorePhoto(
  photoUrl: string,
  chamber: string,
  district: string
): Promise<string | null> {
  if (!photoUrl) return null;
  
  try {
    const response = await fetch(photoUrl, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      },
    });
    
    if (!response.ok) {
      console.log(`Photo not found (${response.status}): ${photoUrl}`);
      return null;
    }
    
    const contentType = response.headers.get("content-type") || "image/jpeg";
    const extension = contentType.includes("png") ? "png" : "jpg";
    const blob = await response.blob();
    const arrayBuffer = await blob.arrayBuffer();
    
    const storagePath = `${chamber}/${district}.${extension}`;
    
    const { error } = await supabase.storage
      .from("legislator-photos")
      .upload(storagePath, arrayBuffer, {
        contentType,
        upsert: true,
      });
    
    if (error) {
      console.error(`Failed to upload photo:`, error);
      return null;
    }
    
    console.log(`Uploaded photo: ${storagePath}`);
    return storagePath;
  } catch (err) {
    console.error(`Failed to download photo from ${photoUrl}:`, err);
    return null;
  }
}

// Process a single legislator from Open States data
function processLegislator(person: OpenStatesPerson): {
  chamber: "upper" | "lower";
  district: string;
  name: string;
  firstName: string;
  lastName: string;
  party: string;
  title: string;
  photoUrl: string | null;
  capitolPhone: string | null;
  capitolEmail: string | null;
  capitolAddress: string | null;
  districtPhone: string | null;
  districtAddress: string | null;
  websiteUrl: string | null;
  legislatureUrl: string | null;
  openstatesPersonId: string;
  divisionId: string | null;
} {
  const chamber = person.current_role.org_classification === "upper" ? "upper" : "lower";
  
  // Extract office info
  let capitolPhone: string | null = null;
  let capitolEmail: string | null = null;
  let capitolAddress: string | null = null;
  let districtPhone: string | null = null;
  let districtAddress: string | null = null;
  
  if (person.offices) {
    for (const office of person.offices) {
      const isCapitol = office.name?.toLowerCase().includes("capitol") || 
                        office.address?.toLowerCase().includes("capitol") ||
                        office.address?.toLowerCase().includes("jefferson city");
      
      if (isCapitol) {
        capitolPhone = office.voice || capitolPhone;
        capitolEmail = office.email || capitolEmail;
        capitolAddress = office.address || capitolAddress;
      } else {
        districtPhone = office.voice || districtPhone;
        districtAddress = office.address || districtAddress;
      }
    }
  }
  
  // Fall back to top-level email
  if (!capitolEmail && person.email) {
    capitolEmail = person.email;
  }
  
  // Extract website and legislature URLs
  let websiteUrl: string | null = null;
  let legislatureUrl: string | null = null;
  
  if (person.links) {
    for (const link of person.links) {
      if (link.url) {
        if (link.url.includes("house.mo.gov") || link.url.includes("senate.mo.gov")) {
          legislatureUrl = link.url;
        } else {
          websiteUrl = link.url;
        }
      }
    }
  }
  
  // Also check sources for legislature URL
  if (!legislatureUrl && person.sources) {
    for (const source of person.sources) {
      if (source.url?.includes("house.mo.gov") || source.url?.includes("senate.mo.gov")) {
        legislatureUrl = source.url;
        break;
      }
    }
  }
  
  // Default addresses
  if (!capitolAddress) {
    capitolAddress = chamber === "lower" 
      ? "MO House of Representatives, 201 West Capitol Avenue, Jefferson City MO 65101"
      : "Missouri State Capitol, 201 W Capitol Ave, Jefferson City, MO 65101";
  }
  
  return {
    chamber: chamber as "upper" | "lower",
    district: person.current_role.district,
    name: person.name,
    firstName: person.given_name || person.name.split(" ")[0] || "",
    lastName: person.family_name || person.name.split(" ").pop() || "",
    party: person.party === "Republican" ? "Republican" : 
           person.party === "Democratic" ? "Democratic" : person.party,
    title: chamber === "lower" ? "Representative" : "Senator",
    photoUrl: person.image || null,
    capitolPhone,
    capitolEmail,
    capitolAddress,
    districtPhone,
    districtAddress,
    websiteUrl,
    legislatureUrl,
    openstatesPersonId: person.id,
    divisionId: person.current_role.division_id || null,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  const startTime = Date.now();

  try {
    const params = await req.json().catch(() => ({}));
    
    // API key from params or env
    const apiKey = params.api_key || Deno.env.get("OPENSTATES_API_KEY");
    
    if (!apiKey) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing api_key parameter" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    
    // Parameters
    const chamber = params.chamber || "lower";
    const downloadPhotos = params.download_photos !== false;
    const maxPages = params.max_pages || 10;
    
    const results = {
      house: { fetched: 0, created: 0, updated: 0, photosSaved: 0, errors: [] as any[] },
      senate: { fetched: 0, created: 0, updated: 0, photosSaved: 0, errors: [] as any[] },
    };
    
    const chambersToProcess: ("lower" | "upper")[] = 
      chamber === "both" ? ["lower", "upper"] : 
      chamber === "lower" ? ["lower"] : ["upper"];
    
    for (const currentChamber of chambersToProcess) {
      const resultKey = currentChamber === "lower" ? "house" : "senate";
      console.log(`\n=== Processing ${resultKey.toUpperCase()} ===`);
      
      let page = 1;
      let hasMore = true;
      
      while (hasMore && page <= maxPages) {
        console.log(`Fetching page ${page}...`);
        
        try {
          const { results: legislators, hasMore: more } = await fetchOpenStatesLegislators(apiKey, currentChamber, page);
          hasMore = more;
          
          console.log(`Got ${legislators.length} legislators on page ${page}`);
          
          for (const person of legislators) {
            results[resultKey].fetched++;
            
            try {
              const data = processLegislator(person);
              
              console.log(`Processing: ${data.name} (District ${data.district})`);
              
              // Download photo if enabled
              let photoStoragePath: string | null = null;
              if (downloadPhotos && data.photoUrl) {
                photoStoragePath = await downloadAndStorePhoto(
                  data.photoUrl, 
                  currentChamber === "lower" ? "house" : "senate",
                  data.district
                );
                if (photoStoragePath) {
                  results[resultKey].photosSaved++;
                }
              }
              
              // Upsert to database
              const { data: existing } = await supabase
                .from("legislation_legislators")
                .select("id")
                .eq("chamber", data.chamber)
                .eq("district", data.district)
                .single();
              
              const { error } = await supabase
                .from("legislation_legislators")
                .upsert({
                  chamber: data.chamber,
                  district: data.district,
                  name: data.name,
                  first_name: data.firstName,
                  last_name: data.lastName,
                  party: data.party,
                  title: data.title,
                  photo_url: data.photoUrl,
                  photo_storage_path: photoStoragePath,
                  capitol_phone: data.capitolPhone,
                  capitol_email: data.capitolEmail,
                  capitol_address: data.capitolAddress,
                  district_phone: data.districtPhone,
                  district_address: data.districtAddress,
                  website_url: data.websiteUrl,
                  legislature_url: data.legislatureUrl,
                  openstates_person_id: data.openstatesPersonId,
                  division_id: data.divisionId,
                  last_scraped_at: new Date().toISOString(),
                  is_current: true,
                }, {
                  onConflict: "chamber,district",
                });
              
              if (error) {
                console.error(`DB error for ${data.name}:`, error);
                results[resultKey].errors.push({ 
                  name: data.name, 
                  district: data.district, 
                  error: error.message 
                });
              } else {
                if (existing) {
                  results[resultKey].updated++;
                } else {
                  results[resultKey].created++;
                }
              }
              
              // Small delay
              await new Promise(r => setTimeout(r, 100));
              
            } catch (err) {
              console.error(`Error processing ${person.name}:`, err);
              results[resultKey].errors.push({ 
                name: person.name, 
                error: err.message 
              });
            }
          }
          
          page++;
          
          // Rate limit between pages
          if (hasMore) {
            console.log("Waiting before next page...");
            await new Promise(r => setTimeout(r, 1000));
          }
          
        } catch (err) {
          console.error(`Error fetching page ${page}:`, err);
          results[resultKey].errors.push({ page, error: err.message });
          break;
        }
      }
    }
    
    const duration = Date.now() - startTime;
    
    console.log("\n=== SUMMARY ===");
    console.log(`House: ${results.house.fetched} fetched, ${results.house.created} created, ${results.house.updated} updated, ${results.house.photosSaved} photos`);
    console.log(`Senate: ${results.senate.fetched} fetched, ${results.senate.created} created, ${results.senate.updated} updated, ${results.senate.photosSaved} photos`);
    console.log(`Duration: ${duration}ms`);
    
    return new Response(
      JSON.stringify({
        success: true,
        results,
        duration_ms: duration,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
    
  } catch (err) {
    console.error("Fatal error:", err);
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});