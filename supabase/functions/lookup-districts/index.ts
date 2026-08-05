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

// Missouri county names for pattern matching
const MISSOURI_COUNTY_NAMES = [
  "Adair", "Andrew", "Atchison", "Audrain", "Barry", "Barton", "Bates", "Benton",
  "Bollinger", "Boone", "Buchanan", "Butler", "Caldwell", "Callaway", "Camden",
  "Cape Girardeau", "Carroll", "Carter", "Cass", "Cedar", "Chariton", "Christian",
  "Clark", "Clay", "Clinton", "Cole", "Cooper", "Crawford", "Dade", "Dallas",
  "Daviess", "DeKalb", "Dent", "Douglas", "Dunklin", "Franklin", "Gasconade",
  "Gentry", "Greene", "Grundy", "Harrison", "Henry", "Hickory", "Holt", "Howard",
  "Howell", "Iron", "Jackson", "Jasper", "Jefferson", "Johnson", "Knox", "Laclede",
  "Lafayette", "Lawrence", "Lewis", "Lincoln", "Linn", "Livingston", "Macon",
  "Madison", "Maries", "Marion", "McDonald", "Mercer", "Miller", "Mississippi",
  "Moniteau", "Monroe", "Montgomery", "Morgan", "New Madrid", "Newton", "Nodaway",
  "Oregon", "Osage", "Ozark", "Pemiscot", "Perry", "Pettis", "Phelps", "Pike",
  "Platte", "Polk", "Pulaski", "Putnam", "Ralls", "Randolph", "Ray", "Reynolds",
  "Ripley", "Saline", "Schuyler", "Scotland", "Scott", "Shannon", "Shelby",
  "St. Charles", "St. Clair", "St. Francois", "St. Louis", "St. Louis city",
  "Ste. Genevieve", "Stoddard", "Stone", "Sullivan", "Taney", "Texas", "Vernon",
  "Warren", "Washington", "Wayne", "Webster", "Worth", "Wright"
];

// Comprehensive city to county mapping (300+ Missouri cities)
const CITY_TO_COUNTY: Record<string, string> = {
  // Multi-word cities
  "kansas city": "Jackson", "st. louis": "St. Louis City", "saint louis": "St. Louis City",
  "north kansas city": "Clay", "lee's summit": "Jackson", "lees summit": "Jackson",
  "o'fallon": "St. Charles", "st. charles": "St. Charles", "saint charles": "St. Charles",
  "st. peters": "St. Charles", "saint peters": "St. Charles", "st. joseph": "Buchanan",
  "saint joseph": "Buchanan", "blue springs": "Jackson", "jefferson city": "Cole",
  "maryland heights": "St. Louis", "webster groves": "St. Louis", "cape girardeau": "Cape Girardeau",
  "poplar bluff": "Butler", "west plains": "Howell", "east prairie": "Mississippi",
  "holts summit": "Callaway", "wright city": "Warren", "lake ozark": "Camden",
  "osage beach": "Camden", "fort leonard wood": "Pulaski", "park hills": "St. Francois",
  "crystal city": "Jefferson", "de soto": "Jefferson", "el dorado springs": "Cedar",
  "mount vernon": "Lawrence", "bowling green": "Pike", "new madrid": "New Madrid",
  "van buren": "Carter", "ste. genevieve": "Ste. Genevieve", "la grange": "Lewis",
  "monroe city": "Monroe", "new london": "Ralls", "grant city": "Worth",
  "mountain grove": "Wright", "branson west": "Stone", "rich hill": "Bates",
  "cole camp": "Benton", "willow springs": "Howell", "lake st. louis": "St. Charles",
  "dardenne prairie": "St. Charles", "weldon spring": "St. Charles",
  "town and country": "St. Louis", "rock hill": "St. Louis", "sunset hills": "St. Louis",
  "richmond heights": "St. Louis", "cool valley": "St. Louis", "black jack": "St. Louis",
  "spanish lake": "St. Louis", "warson woods": "St. Louis", "pleasant hill": "Cass",
  "oak grove": "Jackson", "grain valley": "Jackson", "webb city": "Jasper",
  "knob noster": "Johnson", "university city": "St. Louis", "creve coeur": "St. Louis",
  "des peres": "St. Louis", "excelsior springs": "Clay", "st. robert": "Pulaski",
  "st. james": "Phelps",
  // Single word cities
  "springfield": "Greene", "columbia": "Boone", "independence": "Jackson",
  "joplin": "Jasper", "wentzville": "St. Charles", "ballwin": "St. Louis",
  "raytown": "Jackson", "liberty": "Clay", "kirkwood": "St. Louis",
  "gladstone": "Clay", "grandview": "Jackson", "belton": "Cass",
  "raymore": "Cass", "nixa": "Christian", "ozark": "Christian",
  "republic": "Greene", "sikeston": "Scott", "dexter": "Stoddard",
  "higginsville": "Lafayette", "washington": "Franklin", "fenton": "St. Louis",
  "olivette": "St. Louis", "ladue": "St. Louis", "chesterfield": "St. Louis",
  "hallsville": "Boone", "centralia": "Boone", "hollister": "Taney",
  "jackson": "Cape Girardeau", "foristell": "St. Charles", "stewartsville": "DeKalb",
  "farmington": "St. Francois", "rolla": "Phelps", "sedalia": "Pettis",
  "hannibal": "Marion", "clayton": "St. Louis", "branson": "Taney",
  "troy": "Lincoln", "carthage": "Jasper", "neosho": "Newton",
  "moberly": "Randolph", "fulton": "Callaway", "mexico": "Audrain",
  "marshall": "Saline", "harrisonville": "Cass", "kennett": "Dunklin",
  "camdenton": "Camden", "lebanon": "Laclede", "waynesville": "Pulaski",
  "festus": "Jefferson", "hillsboro": "Jefferson", "perryville": "Perry",
  "boonville": "Cooper", "chillicothe": "Livingston", "maryville": "Nodaway",
  "kirksville": "Adair", "trenton": "Grundy", "bethany": "Harrison",
  "cameron": "Clinton", "warrensburg": "Johnson", "bolivar": "Polk",
  "aurora": "Lawrence", "monett": "Barry", "cassville": "Barry",
  "nevada": "Vernon", "clinton": "Henry", "butler": "Bates",
  "lamar": "Barton", "richmond": "Ray", "lawson": "Ray",
  "savannah": "Andrew", "albany": "Gentry", "princeton": "Mercer",
  "gallatin": "Daviess", "hamilton": "Caldwell", "carrollton": "Carroll",
  "brookfield": "Linn", "marceline": "Linn", "macon": "Macon",
  "ashland": "Boone", "fayette": "Howard", "glasgow": "Howard",
  "california": "Moniteau", "tipton": "Moniteau", "versailles": "Morgan",
  "eldon": "Miller", "tuscumbia": "Miller", "linn": "Osage",
  "westphalia": "Osage", "hermann": "Gasconade", "owensville": "Gasconade",
  "cuba": "Crawford", "steelville": "Crawford", "salem": "Dent",
  "potosi": "Washington", "ironton": "Iron", "arcadia": "Iron",
  "fredericktown": "Madison", "doniphan": "Ripley", "greenville": "Wayne",
  "piedmont": "Wayne", "alton": "Oregon", "thayer": "Oregon",
  "ava": "Douglas", "gainesville": "Ozark", "forsyth": "Taney",
  "galena": "Stone", "clever": "Christian", "marshfield": "Webster",
  "rogersville": "Webster", "buffalo": "Dallas", "caruthersville": "Pemiscot",
  "hayti": "Pemiscot", "portageville": "New Madrid", "charleston": "Mississippi",
  "bloomfield": "Stoddard", "advance": "Stoddard", "benton": "Scott",
  "pineville": "McDonald", "anderson": "McDonald", "noel": "McDonald",
  "seneca": "Newton", "granby": "Newton", "brentwood": "St. Louis",
  "maplewood": "St. Louis", "shrewsbury": "St. Louis", "glendale": "St. Louis",
  "huntleigh": "St. Louis", "cottleville": "St. Charles", "warrenton": "Warren",
  "elsberry": "Lincoln", "louisiana": "Pike", "palmyra": "Marion",
  "canton": "Lewis", "kahoka": "Clark", "edina": "Knox",
  "shelbyville": "Shelby", "shelbina": "Shelby", "paris": "Monroe",
  "huntsville": "Randolph", "salisbury": "Chariton", "keytesville": "Chariton",
  "maysville": "DeKalb", "plattsburg": "Clinton", "lathrop": "Clinton",
  "weston": "Platte", "smithville": "Clay", "kearney": "Clay",
  "parkville": "Platte", "riverside": "Platte", "peculiar": "Cass",
  "arnold": "Jefferson", "florissant": "St. Louis", "hazelwood": "St. Louis",
  "ferguson": "St. Louis", "bridgeton": "St. Louis", "overland": "St. Louis",
  "jennings": "St. Louis", "berkeley": "St. Louis", "dellwood": "St. Louis",
  "normandy": "St. Louis", "pagedale": "St. Louis", "eureka": "St. Louis",
  "wildwood": "St. Louis", "manchester": "St. Louis", "frontenac": "St. Louis",
  "lexington": "Lafayette", "odessa": "Lafayette",
  // Abbreviations
  "kc": "Jackson", "stl": "St. Louis City", "jc": "Jefferson City",
  "jeff city": "Jefferson City", "ofallon": "St. Charles",
};

// Proper capitalization
const CITY_PROPER_NAMES: Record<string, string> = {
  "kansas city": "Kansas City", "st. louis": "St. Louis", "saint louis": "St. Louis",
  "north kansas city": "North Kansas City", "lee's summit": "Lee's Summit",
  "lees summit": "Lee's Summit", "o'fallon": "O'Fallon", "ofallon": "O'Fallon",
  "st. charles": "St. Charles", "saint charles": "St. Charles",
  "st. peters": "St. Peters", "saint peters": "St. Peters",
  "st. joseph": "St. Joseph", "saint joseph": "St. Joseph",
  "blue springs": "Blue Springs", "jefferson city": "Jefferson City",
  "maryland heights": "Maryland Heights", "webster groves": "Webster Groves",
  "cape girardeau": "Cape Girardeau", "poplar bluff": "Poplar Bluff",
  "west plains": "West Plains", "east prairie": "East Prairie",
  "holts summit": "Holts Summit", "wright city": "Wright City",
  "lake ozark": "Lake Ozark", "osage beach": "Osage Beach",
  "fort leonard wood": "Fort Leonard Wood", "park hills": "Park Hills",
  "crystal city": "Crystal City", "de soto": "De Soto",
  "el dorado springs": "El Dorado Springs", "mount vernon": "Mount Vernon",
  "bowling green": "Bowling Green", "new madrid": "New Madrid",
  "van buren": "Van Buren", "ste. genevieve": "Ste. Genevieve",
  "la grange": "La Grange", "monroe city": "Monroe City",
  "new london": "New London", "grant city": "Grant City",
  "mountain grove": "Mountain Grove", "branson west": "Branson West",
  "rich hill": "Rich Hill", "cole camp": "Cole Camp",
  "willow springs": "Willow Springs", "lake st. louis": "Lake St. Louis",
  "dardenne prairie": "Dardenne Prairie", "weldon spring": "Weldon Spring",
  "town and country": "Town and Country", "rock hill": "Rock Hill",
  "sunset hills": "Sunset Hills", "richmond heights": "Richmond Heights",
  "cool valley": "Cool Valley", "black jack": "Black Jack",
  "spanish lake": "Spanish Lake", "warson woods": "Warson Woods",
  "pleasant hill": "Pleasant Hill", "oak grove": "Oak Grove",
  "grain valley": "Grain Valley", "webb city": "Webb City",
  "knob noster": "Knob Noster", "university city": "University City",
  "creve coeur": "Creve Coeur", "des peres": "Des Peres",
  "excelsior springs": "Excelsior Springs", "st. robert": "St. Robert",
  "st. james": "St. James", "kc": "Kansas City", "stl": "St. Louis",
  "jc": "Jefferson City", "jeff city": "Jefferson City",
};

// County seats for fallback
const COUNTY_SEATS: Record<string, string> = {
  "Adair": "Kirksville", "Andrew": "Savannah", "Atchison": "Rock Port",
  "Audrain": "Mexico", "Barry": "Cassville", "Barton": "Lamar",
  "Bates": "Butler", "Benton": "Warsaw", "Bollinger": "Marble Hill",
  "Boone": "Columbia", "Buchanan": "St. Joseph", "Butler": "Poplar Bluff",
  "Caldwell": "Kingston", "Callaway": "Fulton", "Camden": "Camdenton",
  "Cape Girardeau": "Jackson", "Carroll": "Carrollton", "Carter": "Van Buren",
  "Cass": "Harrisonville", "Cedar": "Stockton", "Chariton": "Keytesville",
  "Christian": "Ozark", "Clark": "Kahoka", "Clay": "Liberty",
  "Clinton": "Plattsburg", "Cole": "Jefferson City", "Cooper": "Boonville",
  "Crawford": "Steelville", "Dade": "Greenfield", "Dallas": "Buffalo",
  "Daviess": "Gallatin", "DeKalb": "Maysville", "Dent": "Salem",
  "Douglas": "Ava", "Dunklin": "Kennett", "Franklin": "Union",
  "Gasconade": "Hermann", "Gentry": "Albany", "Greene": "Springfield",
  "Grundy": "Trenton", "Harrison": "Bethany", "Henry": "Clinton",
  "Hickory": "Hermitage", "Holt": "Oregon", "Howard": "Fayette",
  "Howell": "West Plains", "Iron": "Ironton", "Jackson": "Independence",
  "Jasper": "Carthage", "Jefferson": "Hillsboro", "Johnson": "Warrensburg",
  "Knox": "Edina", "Laclede": "Lebanon", "Lafayette": "Lexington",
  "Lawrence": "Mount Vernon", "Lewis": "Monticello", "Lincoln": "Troy",
  "Linn": "Linneus", "Livingston": "Chillicothe", "Macon": "Macon",
  "Madison": "Fredericktown", "Maries": "Vienna", "Marion": "Palmyra",
  "McDonald": "Pineville", "Mercer": "Princeton", "Miller": "Tuscumbia",
  "Mississippi": "Charleston", "Moniteau": "California", "Monroe": "Paris",
  "Montgomery": "Montgomery City", "Morgan": "Versailles", "New Madrid": "New Madrid",
  "Newton": "Neosho", "Nodaway": "Maryville", "Oregon": "Alton",
  "Osage": "Linn", "Ozark": "Gainesville", "Pemiscot": "Caruthersville",
  "Perry": "Perryville", "Pettis": "Sedalia", "Phelps": "Rolla",
  "Pike": "Bowling Green", "Platte": "Platte City", "Polk": "Bolivar",
  "Pulaski": "Waynesville", "Putnam": "Unionville", "Ralls": "New London",
  "Randolph": "Huntsville", "Ray": "Richmond", "Reynolds": "Centerville",
  "Ripley": "Doniphan", "Saline": "Marshall", "Schuyler": "Lancaster",
  "Scotland": "Memphis", "Scott": "Benton", "Shannon": "Eminence",
  "Shelby": "Shelbyville", "St. Charles": "St. Charles", "St. Clair": "Osceola",
  "St. Francois": "Farmington", "St. Louis": "Clayton", "St. Louis City": "St. Louis",
  "Ste. Genevieve": "Ste. Genevieve", "Stoddard": "Bloomfield", "Stone": "Galena",
  "Sullivan": "Milan", "Taney": "Forsyth", "Texas": "Houston",
  "Vernon": "Nevada", "Warren": "Warrenton", "Washington": "Potosi",
  "Wayne": "Greenville", "Webster": "Marshfield", "Worth": "Grant City",
  "Wright": "Hartville",
};

interface ParsedAddress {
  street: string | null;
  city: string | null;
  state: string;
  zip: string | null;
}

interface CityMatch {
  city: string;
  county: string;
  start: number;
  end: number;
}

function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function findCity(text: string): CityMatch | null {
  const lower = text.toLowerCase();
  const sortedCities = Object.keys(CITY_TO_COUNTY).sort((a, b) => b.length - a.length);

  for (const cityKey of sortedCities) {
    const patternStr = cityKey.replace(/'/g, "['\']?").replace(/\./g, "\\.?");
    const pattern = new RegExp(`\\b${patternStr}\\b`, "i");
    const match = lower.match(pattern);
    if (match && match.index !== undefined) {
      const county = CITY_TO_COUNTY[cityKey];
      const proper = CITY_PROPER_NAMES[cityKey] || cityKey.split(" ").map(w =>
        w.charAt(0).toUpperCase() + w.slice(1)
      ).join(" ");
      return { city: proper, county, start: match.index, end: match.index + match[0].length };
    }
  }
  return null;
}

function parseAddress(address: string | null, county: string | null): ParsedAddress {
  const countySeat = county && COUNTY_SEATS[county] ? COUNTY_SEATS[county] : null;

  if (!address || !address.trim()) {
    return { street: null, city: countySeat, state: "MO", zip: null };
  }

  let original = address.trim();

  // Step 1: Handle "CityName CountyName County - Missouri" pattern
  const countyNamesPattern = MISSOURI_COUNTY_NAMES.map(c => escapeRegex(c)).sort((a, b) => b.length - a.length).join("|");
  const countySuffixPattern = new RegExp(`\\s+(${countyNamesPattern})\\s*County\\s*-?\\s*Missouri\\s*$`, "i");
  const countySuffix = original.match(countySuffixPattern);

  if (countySuffix && countySuffix.index !== undefined) {
    const cleanForCity = original.substring(0, countySuffix.index).trim();
    const cityMatch = findCity(cleanForCity);
    if (cityMatch) {
      return { street: null, city: cityMatch.city, state: "MO", zip: null };
    }
  }

  // Step 2: Remove county/Missouri suffixes
  let clean = original;
  clean = clean.replace(new RegExp(`\\s+(${countyNamesPattern})\\s*County\\s*-?\\s*Missouri\\s*$`, "i"), "");
  clean = clean.replace(/\s+County\s*-?\s*Missouri\s*$/i, "");
  clean = clean.replace(/\s+Missouri\s*$/i, "");

  // Step 3: Extract ZIP
  let zip: string | null = null;
  const endZipMatch = clean.match(/[,\s](\d{5})(?:-\d{4})?\s*$/);
  if (endZipMatch) {
    zip = endZipMatch[1];
    clean = clean.substring(0, endZipMatch.index).trim();
  } else {
    const attachedZipMatch = clean.match(/([A-Za-z])(\d{5})(?:\s|$)/);
    if (attachedZipMatch && attachedZipMatch.index !== undefined) {
      zip = attachedZipMatch[2];
      clean = clean.substring(0, attachedZipMatch.index + 1) + clean.substring(attachedZipMatch.index + attachedZipMatch[0].length);
    }
  }

  // Step 4: Normalize
  clean = clean.replace(/\bMissouri\b/gi, "");
  clean = clean.replace(/(?<![A-Za-z])MO(?![a-z])/g, "");
  clean = clean.replace(/\s+/g, " ").trim();
  clean = clean.replace(/^[,\s]+|[,\s]+$/g, "");

  // Step 5: Find city
  const cityMatch = findCity(clean);
  let city: string | null = null;
  let street: string | null = null;

  if (cityMatch) {
    city = cityMatch.city;
    if (cityMatch.start > 0) {
      street = clean.substring(0, cityMatch.start).trim();
    }
  } else if (countySeat) {
    city = countySeat;
    street = clean;
  }

  // Step 6: Clean street
  if (street) {
    if (city) {
      const cityPattern = escapeRegex(city).replace(/\\ /g, "\\s+");
      street = street.replace(new RegExp(cityPattern, "gi"), "");
    }
    street = street.replace(/\s+/g, " ").trim().replace(/^[,\s]+|[,\s]+$/g, "");
    if (!/^\d/.test(street) || street.length < 5) {
      street = null;
    }
  }

  return { street, city, state: "MO", zip };
}

interface DistrictResult {
  senate: string | null;
  house: string | null;
  congressional: string | null;
  error?: string;
  matchedAddress?: string;
}

// The congressional layer was missing, so congressional_district was never
// written by this function at all: a member created through the membership form
// had it NULL permanently, even on a lookup that otherwise succeeded. The two
// state legislative layers were being requested and parsed and the federal one
// simply was not asked for.
const CENSUS_LAYERS =
  "2024 State Legislative Districts - Upper,2024 State Legislative Districts - Lower,119th Congressional Districts";

async function lookupDistricts(parsed: ParsedAddress): Promise<DistrictResult> {
  if (!parsed.city && !parsed.zip) {
    return { senate: null, house: null, congressional: null, error: "Insufficient address information" };
  }

  let url: string;

  if (parsed.street && (parsed.city || parsed.zip)) {
    const params = new URLSearchParams({
      benchmark: "Public_AR_Current",
      vintage: "Current_Current",
      layers: CENSUS_LAYERS,
      format: "json",
      state: parsed.state,
    });
    if (parsed.street) params.set("street", parsed.street);
    if (parsed.city) params.set("city", parsed.city);
    if (parsed.zip) params.set("zip", parsed.zip);
    url = `https://geocoding.geo.census.gov/geocoder/geographies/address?${params.toString()}`;
  } else {
    const address = `${parsed.city}, ${parsed.state}${parsed.zip ? " " + parsed.zip : ""}`;
    const params = new URLSearchParams({
      address: address,
      benchmark: "Public_AR_Current",
      vintage: "Current_Current",
      layers: CENSUS_LAYERS,
      format: "json",
    });
    url = `https://geocoding.geo.census.gov/geocoder/geographies/onelineaddress?${params.toString()}`;
  }

  try {
    const response = await fetch(url);
    if (!response.ok) {
      return { senate: null, house: null, congressional: null, error: `API error: ${response.status}` };
    }

    const data = await response.json();
    const matches = data?.result?.addressMatches;
    if (!matches || matches.length === 0) {
      return { senate: null, house: null, congressional: null, error: "No address match found" };
    }

    const geographies = matches[0]?.geographies;
    if (!geographies) {
      return { senate: null, house: null, congressional: null, error: "No geography data returned" };
    }

    let senate: string | null = null;
    let house: string | null = null;
    let congressional: string | null = null;

    const upperDistricts = geographies["2024 State Legislative Districts - Upper"];
    if (upperDistricts && upperDistricts.length > 0) {
      const raw = upperDistricts[0].SLDU;
      senate = raw ? raw.replace(/^0+/, "") : null;
    }

    const lowerDistricts = geographies["2024 State Legislative Districts - Lower"];
    if (lowerDistricts && lowerDistricts.length > 0) {
      const raw = lowerDistricts[0].SLDL;
      house = raw ? raw.replace(/^0+/, "") : null;
    }

    // Stored as "CD-5" to match the 379 existing rows, which came from
    // imports rather than from this function.
    const cdDistricts = geographies["119th Congressional Districts"];
    if (cdDistricts && cdDistricts.length > 0) {
      const raw = cdDistricts[0].CD119;
      const num = raw ? String(raw).replace(/^0+/, "") : null;
      congressional = num ? `CD-${num}` : null;
    }

    const matchedAddress = matches[0]?.matchedAddress || null;
    return { senate, house, congressional, matchedAddress };
  } catch (err: any) {
    return { senate: null, house: null, congressional: null, error: `Fetch error: ${err.message}` };
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const {
      memberId,
      memberIds,
      dryRun = false,
      batchSize = 50,
      overwrite = false,
    } = body;

    let targetMemberIds: string[] = [];

    if (memberId) {
      targetMemberIds = [memberId];
    } else if (memberIds && Array.isArray(memberIds)) {
      targetMemberIds = memberIds;
    } else {
      let query = supabase.from("members").select("id").not("address", "is", null);
      if (!overwrite) {
        query = query.or("senate_district.is.null,house_district.is.null,congressional_district.is.null");
      }
      const { data: members, error } = await query.limit(batchSize);
      if (error) throw new Error(`Failed to fetch members: ${error.message}`);
      targetMemberIds = members?.map(m => m.id) || [];
    }

    if (targetMemberIds.length === 0) {
      return new Response(
        JSON.stringify({ success: true, processed: 0, message: "No members to process" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: members, error: fetchError } = await supabase
      .from("members")
      .select("id, name, address, county, senate_district, house_district, congressional_district")
      .in("id", targetMemberIds);

    if (fetchError) throw new Error(`Failed to fetch member details: ${fetchError.message}`);

    interface ProcessResult {
      memberId: string;
      name: string | null;
      originalAddress: string | null;
      county: string | null;
      parsed: ParsedAddress;
      lookup: DistrictResult;
      updated: boolean;
      previousDistricts: { senate: string | null; house: string | null; congressional: string | null };
    }

    const results: ProcessResult[] = [];

    for (const member of members || []) {
      const parsed = parseAddress(member.address, member.county);

      if (!parsed.city && !parsed.zip) {
        results.push({
          memberId: member.id,
          name: member.name,
          originalAddress: member.address,
          county: member.county,
          parsed,
          lookup: { senate: null, house: null, congressional: null, error: "Could not parse address" },
          updated: false,
          previousDistricts: {
            senate: member.senate_district,
            house: member.house_district,
            congressional: member.congressional_district,
          },
        });
        continue;
      }

      const lookup = await lookupDistricts(parsed);

      let updated = false;
      if (!dryRun && (lookup.senate || lookup.house || lookup.congressional)) {
        const updates: Record<string, string> = {};
        if (lookup.senate && (overwrite || !member.senate_district)) {
          updates.senate_district = lookup.senate;
        }
        if (lookup.house && (overwrite || !member.house_district)) {
          updates.house_district = lookup.house;
        }
        if (lookup.congressional && (overwrite || !member.congressional_district)) {
          updates.congressional_district = lookup.congressional;
        }

        if (Object.keys(updates).length > 0) {
          const { error: updateError } = await supabase
            .from("members")
            .update(updates)
            .eq("id", member.id);
          updated = !updateError;
        }
      }

      results.push({
        memberId: member.id,
        name: member.name,
        originalAddress: member.address,
        county: member.county,
        parsed,
        lookup,
        updated,
        previousDistricts: {
          senate: member.senate_district,
          house: member.house_district,
          congressional: member.congressional_district,
        },
      });

      await new Promise(resolve => setTimeout(resolve, 100));
    }

    const summary = {
      total: results.length,
      successful: results.filter(r => r.lookup.senate || r.lookup.house).length,
      updated: results.filter(r => r.updated).length,
      parseErrors: results.filter(r => r.lookup.error === "Could not parse address").length,
      lookupErrors: results.filter(r => r.lookup.error && r.lookup.error !== "Could not parse address").length,
    };

    return new Response(
      JSON.stringify({ success: true, dryRun, overwrite, summary, results }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("District lookup failed:", err);
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});