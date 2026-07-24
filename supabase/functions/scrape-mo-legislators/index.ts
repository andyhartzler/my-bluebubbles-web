import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { DOMParser } from "https://deno.land/x/deno_dom@v0.1.38/deno-dom-wasm.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const browserHeaders = {
  "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
  "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
  "Accept-Language": "en-US,en;q=0.9",
  "Connection": "keep-alive",
  "Upgrade-Insecure-Requests": "1",
  "Sec-Fetch-Dest": "document",
  "Sec-Fetch-Mode": "navigate",
  "Sec-Fetch-Site": "none",
  "Sec-Fetch-User": "?1",
  "Cache-Control": "max-age=0",
};

interface LegislatorData {
  name: string;
  firstName: string;
  lastName: string;
  chamber: "upper" | "lower";
  district: string;
  party: string;
  title: string;
  photoUrl: string | null;
  capitolAddress: string | null;
  capitolPhone: string | null;
  capitolEmail: string | null;
  officeHours: string | null;
  biography: string | null;
  legislatureUrl: string;
  legislatureMemberId: string | null;
}

// Scrape a single House member
async function scrapeHouseMember(district: number, year: number = 2026): Promise<LegislatorData | null> {
  const districtPadded = String(district).padStart(3, "0");
  
  for (const code of ["R", "D"]) {
    const url = `https://house.mo.gov/MemberDetails.aspx?year=${year}&code=${code}&district=${districtPadded}`;
    
    try {
      const response = await fetch(url, { headers: browserHeaders });
      
      console.log(`House district ${district} (${code}): ${response.status}`);
      
      if (!response.ok) {
        console.log(`HTTP ${response.status} for ${url}`);
        continue;
      }
      
      const html = await response.text();
      
      if (html.includes("Member not found") || html.includes("No member")) {
        console.log(`No member found for district ${district} with code ${code}`);
        continue;
      }
      
      // More lenient check
      if (!html.includes("Representative") && !html.includes("MemberPhoto") && !html.includes("district")) {
        console.log(`Page doesn't appear to have member content for district ${district}`);
        continue;
      }
      
      const doc = new DOMParser().parseFromString(html, "text/html");
      if (!doc) continue;
      
      // Extract name - try multiple patterns
      let fullName = "";
      
      const titleMatch = html.match(/Representative\s+([^,<\n]+)/i);
      if (titleMatch) {
        fullName = titleMatch[1].trim();
      }
      
      if (!fullName) {
        const titleEl = doc.querySelector("title");
        if (titleEl) {
          const titleText = titleEl.textContent || "";
          const nameMatch = titleText.match(/Representative\s+([^-|]+)/i) || 
                           titleText.match(/Rep\.\s+([^-|]+)/i);
          if (nameMatch) {
            fullName = nameMatch[1].trim();
          }
        }
      }
      
      if (!fullName) {
        const h1 = doc.querySelector("h1, h2, .member-name, #member-name");
        if (h1) {
          fullName = h1.textContent?.replace(/Representative\s*/i, "").replace(/Rep\.\s*/i, "").trim() || "";
        }
      }
      
      if (!fullName) {
        console.log(`Could not extract name for district ${district}`);
        continue;
      }
      
      console.log(`Found: ${fullName}`);
      
      const nameParts = fullName.split(" ").filter(p => p.length > 0);
      const firstName = nameParts[0] || "";
      const lastName = nameParts[nameParts.length - 1] || "";
      
      // Extract photo URL
      let photoUrl: string | null = null;
      let memberId: string | null = null;
      
      const imgMatch = html.match(/https:\/\/images\.house\.mo\.gov\/MemberPhoto\.aspx\?id=(\d+)/i);
      if (imgMatch) {
        photoUrl = imgMatch[0];
        memberId = imgMatch[1];
      }
      
      if (!photoUrl) {
        const relMatch = html.match(/MemberPhoto\.aspx\?id=(\d+)/i);
        if (relMatch) {
          photoUrl = `https://images.house.mo.gov/MemberPhoto.aspx?id=${relMatch[1]}`;
          memberId = relMatch[1];
        }
      }
      
      if (!photoUrl) {
        const imgSrcMatch = html.match(/<img[^>]+src=["']([^"']*MemberPhoto[^"']*)["']/i);
        if (imgSrcMatch) {
          photoUrl = imgSrcMatch[1];
          if (!photoUrl.startsWith("http")) {
            photoUrl = `https://images.house.mo.gov/${photoUrl}`;
          }
          const idMatch = photoUrl.match(/id=(\d+)/i);
          if (idMatch) memberId = idMatch[1];
        }
      }
      
      // Extract contact info
      const phoneMatch = html.match(/Phone[:\s]*(?:<[^>]*>)*\s*(\d{3}[-.\s]?\d{3}[-.\s]?\d{4})/i) ||
                        html.match(/(\(\d{3}\)\s*\d{3}[-.\s]?\d{4})/) ||
                        html.match(/(\d{3}-\d{3}-\d{4})/);
      const emailMatch = html.match(/([a-zA-Z0-9._%+-]+@house\.mo\.gov)/i);
      const hoursMatch = html.match(/Office Hours[:\s]*(?:<[^>]*>)*\s*([^<]+)/i);
      
      // Extract biography
      let biography: string | null = null;
      const bioParagraphs: string[] = [];
      const paragraphs = doc.querySelectorAll("p");
      
      const stopPatterns = [
        /^Prior Legislative Service/i,
        /^Statewide Committees/i,
        /^Legislative Committees/i,
        /^Committee Assignments/i,
        /^End of Session Report/i,
        /^\d{4}\s+End of Session/i,
        /^Sponsored Bills/i,
        /^Bills Sponsored/i,
        /^Contact/i,
      ];
      
      for (const p of paragraphs) {
        const text = p.textContent?.trim() || "";
        
        if (text.length < 50) continue;
        
        let shouldStop = false;
        for (const pattern of stopPatterns) {
          if (pattern.test(text)) {
            shouldStop = true;
            break;
          }
        }
        if (shouldStop) break;
        
        if (text.includes("End of Session Report") || /^\d{4}\s*-\s*\d{4}$/.test(text)) {
          continue;
        }
        
        const isBioParagraph = (
          text.includes("Representative") || 
          text.includes("District") || 
          text.includes("elected") ||
          text.includes("serves") ||
          text.includes("graduated") ||
          text.includes("resides") ||
          text.includes("degree") ||
          text.includes("wife") ||
          text.includes("husband") ||
          text.includes("children") ||
          text.includes("family") ||
          text.includes("born") ||
          text.includes("raised") ||
          text.includes("earned") ||
          text.includes("enjoys") ||
          text.includes("married") ||
          text.includes("University") ||
          text.includes("College") ||
          text.includes("School") ||
          text.includes("worked") ||
          text.includes("career") ||
          text.includes("community") ||
          text.includes("church") ||
          text.includes("member of") ||
          bioParagraphs.length > 0
        );
        
        if (isBioParagraph) {
          const hasProseIndicators = text.includes(". ") || text.includes(", ");
          if (hasProseIndicators) {
            bioParagraphs.push(text);
          }
        }
      }
      
      if (bioParagraphs.length > 0) {
        biography = bioParagraphs.join("\n\n");
      }
      
      return {
        name: fullName,
        firstName,
        lastName,
        chamber: "lower",
        district: String(district),
        party: code === "R" ? "Republican" : "Democratic",
        title: "Representative",
        photoUrl,
        capitolAddress: "MO House of Representatives, 201 West Capitol Avenue, Jefferson City MO 65101",
        capitolPhone: phoneMatch?.[1]?.trim() || null,
        capitolEmail: emailMatch?.[1]?.trim() || null,
        officeHours: hoursMatch?.[1]?.trim() || null,
        biography,
        legislatureUrl: url,
        legislatureMemberId: memberId,
      };
    } catch (err) {
      console.error(`Error scraping House district ${district}:`, err);
    }
  }
  
  return null;
}

// Scrape a single Senate member
async function scrapeSenateMember(district: number): Promise<LegislatorData | null> {
  const url = `https://www.senate.mo.gov/Senators/Member/${district}`;
  
  try {
    const response = await fetch(url, { headers: browserHeaders });
    
    if (!response.ok) return null;
    
    const html = await response.text();
    
    if (html.includes("Page not found") || html.includes("404")) {
      return null;
    }
    
    const doc = new DOMParser().parseFromString(html, "text/html");
    if (!doc) return null;
    
    // Extract name from title or h1
    let fullName = "";
    const titleEl = doc.querySelector("title");
    if (titleEl) {
      fullName = titleEl.textContent?.replace(/Senator\s*/i, "").replace(/\s*-.*$/, "").trim() || "";
    }
    
    if (!fullName) {
      const h1 = doc.querySelector("h1");
      if (h1) {
        fullName = h1.textContent?.replace(/Senator\s*/i, "").trim() || "";
      }
    }
    
    if (!fullName) {
      const nameMatch = html.match(/Senator\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)/);
      if (nameMatch) {
        fullName = nameMatch[1].trim();
      }
    }
    
    if (!fullName) return null;
    
    const nameParts = fullName.split(" ");
    const firstName = nameParts[0] || "";
    const lastName = nameParts[nameParts.length - 1] || "";
    
    let party = "Unknown";
    if (html.includes("Republican") || html.includes("(R)") || html.includes("-R")) {
      party = "Republican";
    } else if (html.includes("Democrat") || html.includes("(D)") || html.includes("-D")) {
      party = "Democratic";
    }
    
    const districtPadded = String(district).padStart(2, "0");
    const photoUrl = `https://www.senate.mo.gov/WebPhotos/SenatorPortraits/${lastName}${districtPadded}.jpg`;
    
    const phoneMatch = html.match(/(\d{3}[-.\s]?\d{3}[-.\s]?\d{4})/);
    const emailMatch = html.match(/([a-zA-Z0-9._%+-]+@senate\.mo\.gov)/i);
    
    let biography: string | null = null;
    const bioParagraphs: string[] = [];
    const paragraphs = doc.querySelectorAll("p");
    
    const stopPatterns = [
      /^Prior Legislative Service/i,
      /^Statewide Committees/i,
      /^Legislative Committees/i,
      /^Committee Assignments/i,
      /^End of Session Report/i,
      /^\d{4}\s+End of Session/i,
      /^House of Representatives:/i,
      /^Senate:/i,
      /^Sponsored Bills/i,
      /^Bills Sponsored/i,
      /^Contact/i,
    ];
    
    for (const p of paragraphs) {
      const text = p.textContent?.trim() || "";
      
      if (text.length < 50) continue;
      
      let shouldStop = false;
      for (const pattern of stopPatterns) {
        if (pattern.test(text)) {
          shouldStop = true;
          break;
        }
      }
      if (shouldStop) break;
      
      if (text.includes("End of Session Report") || 
          text.includes("Commission") && text.length < 100 ||
          text.includes("Council") && text.length < 100 ||
          /^\d{4}\s*-\s*\d{4}$/.test(text) ||
          /^House of Representatives:/.test(text) ||
          /^Senate:/.test(text)) {
        continue;
      }
      
      const isBioParagraph = (
        text.includes("Senator") || 
        text.includes("District") || 
        text.includes("elected") ||
        text.includes("serves") ||
        text.includes("graduated") ||
        text.includes("resides") ||
        text.includes("attorney") ||
        text.includes("degree") ||
        text.includes("wife") ||
        text.includes("husband") ||
        text.includes("children") ||
        text.includes("family") ||
        text.includes("born") ||
        text.includes("raised") ||
        text.includes("earned") ||
        text.includes("enjoys") ||
        text.includes("married") ||
        text.includes("University") ||
        text.includes("College") ||
        text.includes("School") ||
        text.includes("law school") ||
        text.includes("worked") ||
        text.includes("career") ||
        text.includes("community") ||
        text.includes("church") ||
        text.includes("member of") ||
        bioParagraphs.length > 0
      );
      
      if (isBioParagraph) {
        const hasProseIndicators = text.includes(". ") || text.includes(", ");
        if (hasProseIndicators) {
          bioParagraphs.push(text);
        }
      }
    }
    
    if (bioParagraphs.length > 0) {
      biography = bioParagraphs.join("\n\n");
    }
    
    return {
      name: fullName,
      firstName,
      lastName,
      chamber: "upper",
      district: String(district),
      party,
      title: "Senator",
      photoUrl,
      capitolAddress: "Missouri State Capitol, 201 W Capitol Ave, Jefferson City, MO 65101",
      capitolPhone: phoneMatch?.[1]?.trim() || null,
      capitolEmail: emailMatch?.[1]?.trim() || null,
      officeHours: null,
      biography,
      legislatureUrl: url,
      legislatureMemberId: null,
    };
  } catch (err) {
    console.error(`Error scraping Senate district ${district}:`, err);
    return null;
  }
}

// Download and store photo
async function downloadAndStorePhoto(
  photoUrl: string,
  chamber: string,
  district: string
): Promise<string | null> {
  try {
    const response = await fetch(photoUrl, { headers: browserHeaders });
    
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
    
    return storagePath;
  } catch (err) {
    console.error(`Failed to download photo:`, err);
    return null;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  const startTime = Date.now();

  try {
    const params = await req.json().catch(() => ({}));
    
    const chamber = params.chamber || "both";
    const startDistrict = params.start_district || 1;
    const maxDistricts = params.max_districts || 5;
    const downloadPhotos = params.download_photos !== false;
    const year = params.year || 2026;
    
    const results = {
      house: { processed: 0, created: 0, errors: [] as any[] },
      senate: { processed: 0, created: 0, errors: [] as any[] },
    };
    
    // Scrape House (163 districts)
    if (chamber === "lower" || chamber === "both") {
      const endDistrict = Math.min(startDistrict + maxDistricts - 1, 163);
      
      for (let district = startDistrict; district <= endDistrict; district++) {
        console.log(`Scraping House district ${district}...`);
        results.house.processed++;
        
        try {
          const data = await scrapeHouseMember(district, year);
          
          if (data) {
            let photoStoragePath: string | null = null;
            if (downloadPhotos && data.photoUrl) {
              photoStoragePath = await downloadAndStorePhoto(data.photoUrl, "house", data.district);
            }
            
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
                capitol_address: data.capitolAddress,
                capitol_phone: data.capitolPhone,
                capitol_email: data.capitolEmail,
                office_hours: data.officeHours,
                biography: data.biography,
                legislature_url: data.legislatureUrl,
                legislature_member_id: data.legislatureMemberId,
                last_scraped_at: new Date().toISOString(),
                is_current: true,
              }, {
                onConflict: "chamber,district",
              });
            
            if (error) {
              results.house.errors.push({ district, error: error.message });
            } else {
              results.house.created++;
            }
          } else {
            console.log(`No data returned for House district ${district}`);
          }
          
          await new Promise((r) => setTimeout(r, 2000));
        } catch (err) {
          results.house.errors.push({ district, error: err.message });
        }
      }
    }
    
    // Scrape Senate (34 districts)
    if (chamber === "upper" || chamber === "both") {
      const endDistrict = Math.min(startDistrict + maxDistricts - 1, 34);
      
      for (let district = startDistrict; district <= endDistrict; district++) {
        console.log(`Scraping Senate district ${district}...`);
        results.senate.processed++;
        
        try {
          const data = await scrapeSenateMember(district);
          
          if (data) {
            let photoStoragePath: string | null = null;
            if (downloadPhotos && data.photoUrl) {
              photoStoragePath = await downloadAndStorePhoto(data.photoUrl, "senate", data.district);
            }
            
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
                capitol_address: data.capitolAddress,
                capitol_phone: data.capitolPhone,
                capitol_email: data.capitolEmail,
                office_hours: data.officeHours,
                biography: data.biography,
                legislature_url: data.legislatureUrl,
                legislature_member_id: data.legislatureMemberId,
                last_scraped_at: new Date().toISOString(),
                is_current: true,
              }, {
                onConflict: "chamber,district",
              });
            
            if (error) {
              results.senate.errors.push({ district, error: error.message });
            } else {
              results.senate.created++;
            }
          }
          
          await new Promise((r) => setTimeout(r, 2000));
        } catch (err) {
          results.senate.errors.push({ district, error: err.message });
        }
      }
    }
    
    const duration = Date.now() - startTime;
    
    return new Response(
      JSON.stringify({
        success: true,
        results,
        duration_ms: duration,
        next_district: startDistrict + maxDistricts,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Scrape failed:", err);
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});