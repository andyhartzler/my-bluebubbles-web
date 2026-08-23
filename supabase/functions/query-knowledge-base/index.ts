// Wave 4 access-audit 2026-04-24: user-JWT + is_staff() gate + audit_log.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { callGemini } from "../_shared/gemini.ts";
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
// STILL OPENAI, ON PURPOSE, AND ONLY FOR EMBEDDINGS.
//
// Every CHAT call in this file has moved to Gemini on Vertex. The embedding call
// below has not, and must not, until somebody re-embeds the corpus.
//
// public.knowledge_documents.embedding is vector(1536) holding 78,717 rows, all
// of them produced by text-embedding-3-small. A query embedding is only
// meaningful against document embeddings from the SAME model: similarity is an
// angle inside one model's space, and two models that happen to agree on 1536
// dimensions still put "chapter chartering" in unrelated directions. Swapping
// the query side alone does not error, does not warn, and does not fail a test.
// It returns confident nonsense, and the only symptom is that search quietly
// stops working.
//
// So this is a corpus migration and not a code change. Re-embedding 78,717 rows
// is its own project with its own cost, and it is not this one.
const openaiKey = Deno.env.get("OPENAI_API_KEY");
const supabase = createClient(supabaseUrl, supabaseServiceKey);
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};

async function requireStaffUser(req) {
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
  const { data: staffCheck, error: staffErr } = await userClient.rpc("is_staff");
  if (staffErr || staffCheck !== true) {
    return {
      error: new Response(JSON.stringify({ error: "Forbidden — staff access required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  return { userId: userData.user.id };
}
// =============================================================================
// MOYD CORE FACTS - VERIFIED FROM CONSTITUTION
// These are HARDCODED to ensure accuracy - the AI cannot get these wrong
// =============================================================================
const MOYD_CORE_FACTS = {
  founding_date: "July 27, 2025",
  age_range: {
    min: 14,
    max: 36
  },
  // IMPORTANT: NOT "official youth arm" - we are affiliated
  affiliation: "Chartered state federation of Young Democrats of America (YDA) that works closely with the Missouri Democratic Party",
  standing_committees: [
    "Fundraising Committee",
    "College Democrats Committee",
    "High School Democrats Committee",
    "Communications Committee",
    "Membership & Outreach Committee",
    "Political Affairs Committee",
    "Policy & Advocacy Committee"
  ],
  organizing_arms: [
    {
      name: "Missouri College Democrats (MOCD)",
      affiliation: "College Democrats of America (CDA)"
    },
    {
      name: "Missouri High School Democrats (MOHSD)",
      affiliation: "High School Democrats of America (HSDA)"
    },
    {
      name: "County Young Democrats",
      affiliation: null
    }
  ],
  statewide_officers: [
    "President",
    "Vice President",
    "Secretary",
    "Treasurer"
  ],
  digital_presence: {
    main_website: "moyoungdemocrats.org",
    crm: "moyd.app",
    member_portal: "moyoungdemocrats.org/members",
    forms: "moyoungdemocrats.org/forms",
    jobs: "moyoungdemocrats.org/jobs"
  }
};
// =============================================================================
// DYNAMIC DATE CONTEXT
// =============================================================================
function getCurrentDateContext() {
  const now = new Date();
  const foundingDate = new Date('2025-07-27');
  const monthsSinceFounding = Math.floor((now.getTime() - foundingDate.getTime()) / (1000 * 60 * 60 * 24 * 30));
  return `
TODAY'S DATE: ${now.toLocaleDateString('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  })}
CURRENT YEAR: ${now.getFullYear()}
MOYD FOUNDING DATE: ${MOYD_CORE_FACTS.founding_date}
TIME SINCE FOUNDING: Approximately ${monthsSinceFounding} months
`;
}
// =============================================================================
// COMPREHENSIVE SYSTEM PROMPT (WITH CORRECT FACTS)
// =============================================================================
function buildSystemPrompt() {
  return `You are **MOYD AI**, the intelligent assistant for Missouri Young Democrats (MOYD). You have deep knowledge of the organization and access to comprehensive search results from multiple data sources. You also have memory of past conversations with this user.

## CURRENT DATE CONTEXT
${getCurrentDateContext()}

## MOYD VERIFIED CORE FACTS - USE THESE EXACTLY

**Founded:** ${MOYD_CORE_FACTS.founding_date}

**Mission:** To engage young Missourians in the political process, cultivate Democratic leadership, and help elect Democratic candidates who reflect the values and priorities of young people.

**Age Eligibility:** ${MOYD_CORE_FACTS.age_range.min} to ${MOYD_CORE_FACTS.age_range.max} years old
⚠️ IMPORTANT: The age range is 14-36, NOT 14-40

**Affiliation:** ${MOYD_CORE_FACTS.affiliation}
⚠️ IMPORTANT: We are NOT the "official youth arm of the Missouri Democratic Party" - we are an AFFILIATED organization (chartered state federation of YDA) that works closely with MDP

**Leadership Structure:**
- Statewide Officers: ${MOYD_CORE_FACTS.statewide_officers.join(', ')}
- ${MOYD_CORE_FACTS.standing_committees.length} Standing Committee Chairs
- Congressional District Representatives (one per Missouri district)
- Together these form the Executive Committee

**Seven Standing Committees:**
${MOYD_CORE_FACTS.standing_committees.map((c, i)=>`${i + 1}. ${c}`).join('\n')}
⚠️ IMPORTANT: There are SEVEN standing committees, not six

**Three Organizing Arms:**
${MOYD_CORE_FACTS.organizing_arms.map((a)=>`- ${a.name}${a.affiliation ? ` (affiliated with ${a.affiliation})` : ''}`).join('\n')}

**Digital Infrastructure:**
- Main website: ${MOYD_CORE_FACTS.digital_presence.main_website}
- Member CRM: ${MOYD_CORE_FACTS.digital_presence.crm}
- Member portal: ${MOYD_CORE_FACTS.digital_presence.member_portal}
- Forms: ${MOYD_CORE_FACTS.digital_presence.forms}
- Jobs board: ${MOYD_CORE_FACTS.digital_presence.jobs}
- Active Slack workspace with 300+ members

## YOUR DATA SOURCES

You receive search results from multiple retrieval methods:
- **Semantic Search**: Finds conceptually similar documents
- **Structured Queries**: Direct database lookups for specific data (members by name, recent meetings, etc.)
- **Keyword Search**: Text matching for specific terms
- **Aggregated Statistics**: Real-time counts and totals from the database
- **Memory**: Your memories of this user's preferences and past conversations

**Available Data**:
📋 Members (~380) | 📧 Subscribers (~1,500) | 📜 Legislation (~1,600 bills)
💬 Slack Messages (~900) | 📅 Events & Meetings | 📁 Documents | 💰 Donations

## RESPONSE GUIDELINES

1. **Use the data provided** - Your responses should draw from the search results and memories
2. **Be specific** - Include names, emails, dates, and details when available
3. **Format clearly** - Use markdown, headers, bullet points, and tables appropriately
4. **Be helpful** - If data is incomplete, suggest alternatives or ask clarifying questions
5. **Be accurate** - Only state facts from the provided context or the VERIFIED CORE FACTS above
6. **Leverage memory** - Use relevant memories to personalize responses
7. **Learn from context** - When you see patterns, mention them naturally
8. **Use current date** - Always calculate time periods correctly using today's date

## THINGS TO NEVER SAY (THESE ARE FACTUALLY WRONG)
- ❌ "official youth arm of Missouri Democratic Party" → ✅ "chartered state federation of YDA that works closely with MDP"
- ❌ "14-40" → ✅ "14-36"  
- ❌ "six standing committees" → ✅ "seven standing committees"
- ❌ Any year other than 2025 for founding → ✅ "founded July 27, 2025"
- ❌ "2024" when referring to current year → ✅ "${new Date().getFullYear()}"

## FORMATTING

- **Bold** for names and key terms
- Bullet points for lists
- Tables for comparing data
- Include contact info when showing members
- Use headers (##) to organize longer responses`;
}
// For backward compatibility
const SYSTEM_PROMPT = buildSystemPrompt();
// =============================================================================
// TASK CLASSIFICATION - Determines retrieval scope
// =============================================================================
function classifyTask(query) {
  const q = query.toLowerCase();
  // Patterns that indicate COMPREHENSIVE/EXHAUSTIVE retrieval needed
  const comprehensivePatterns = [
    /year[- ]?(in[- ]?)?review/i,
    /end[- ]?of[- ]?(the[- ]?)?year/i,
    /everything we('ve| have) (done|accomplished)/i,
    /comprehensive (overview|summary|report|email)/i,
    /all (of )?(our )?(events|meetings|activities|accomplishments)/i,
    /since (our )?founding/i,
    /full (history|timeline|report|overview)/i,
    /summarize.*(year|everything|all|since|accomplishments)/i,
    /accomplishments/i,
    /what have we (done|accomplished|achieved)/i,
    /newsletter.*(comprehensive|all|everything|year|review)/i,
    /recap/i,
    /highlight(s)?.*(year|accomplishments|achievements)/i,
    /annual report/i,
    /state of (the )?(organization|moyd)/i
  ];
  // Patterns that indicate content generation
  const contentGenPatterns = [
    /write (a |an |me )?(email|newsletter|report|summary|post|article|message)/i,
    /draft (a |an )?(email|newsletter|report|communication|message)/i,
    /create (a |an )?(email|newsletter|report)/i,
    /compose/i
  ];
  // Check for comprehensive research first
  const isComprehensive = comprehensivePatterns.some((p)=>p.test(q));
  const isContentGen = contentGenPatterns.some((p)=>p.test(q));
  if (isComprehensive || isContentGen && comprehensivePatterns.some((p)=>p.test(q))) {
    return {
      type: isContentGen ? 'content_generation' : 'comprehensive_research',
      scope: 'exhaustive',
      dataNeeds: [
        'organization',
        'meetings',
        'events',
        'members_stats',
        'chapters',
        'donations_stats',
        'subscribers_stats',
        'committees',
        'slack_highlights'
      ],
      timeframe: detectTimeframe(q),
      confidence: 0.9
    };
  }
  if (isContentGen) {
    return {
      type: 'content_generation',
      scope: 'moderate',
      dataNeeds: [
        'organization',
        'semantic_search'
      ],
      timeframe: detectTimeframe(q),
      confidence: 0.8
    };
  }
  // Entity lookups
  const entityPatterns = {
    members: /\b(member|who is|find person|contact|person named)\b/i,
    meetings: /\b(meeting|minutes|transcript)\b/i,
    events: /\b(event|happening|activities)\b/i,
    chapters: /\b(chapter|college democrats|high school democrats|county)\b/i,
    committees: /\b(committee|fundraising|policy|communications|political affairs)\b/i
  };
  for (const [entity, pattern] of Object.entries(entityPatterns)){
    if (pattern.test(q)) {
      return {
        type: 'entity_search',
        scope: 'narrow',
        dataNeeds: [
          entity,
          'organization'
        ],
        confidence: 0.7
      };
    }
  }
  // Default to simple lookup with semantic search
  return {
    type: 'simple_lookup',
    scope: 'narrow',
    dataNeeds: [
      'semantic_search',
      'organization'
    ],
    confidence: 0.5
  };
}
function detectTimeframe(query) {
  const q = query.toLowerCase();
  const now = new Date();
  const foundingDate = new Date('2025-07-27');
  if (/since (our )?founding/i.test(q) || /year[- ]?(in[- ]?)?review/i.test(q) || /end[- ]?of[- ]?(the[- ]?)?year/i.test(q)) {
    return {
      start: foundingDate,
      end: now
    };
  }
  if (/this year/i.test(q)) {
    return {
      start: new Date(now.getFullYear(), 0, 1),
      end: now
    };
  }
  if (/last month/i.test(q)) {
    const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const endLastMonth = new Date(now.getFullYear(), now.getMonth(), 0);
    return {
      start: lastMonth,
      end: endLastMonth
    };
  }
  // Default for comprehensive queries: since founding
  return {
    start: foundingDate,
    end: now
  };
}
// =============================================================================
// EMBEDDING UTILITIES
// =============================================================================
async function embedQuery(query) {
  const response = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${openaiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: "text-embedding-3-small",
      input: query,
      dimensions: 1536
    })
  });
  if (!response.ok) throw new Error(`OpenAI error: ${await response.text()}`);
  const data = await response.json();
  return data.data[0].embedding;
}
function formatEmbeddingForPgvector(embedding) {
  return `[${embedding.join(",")}]`;
}
// =============================================================================
// AGGREGATION FUNCTIONS - Get real statistics from database
// Column names match actual MOYD schema
// =============================================================================
async function getMemberStatistics() {
  try {
    const { count: totalMembers } = await supabase.from('members').select('*', {
      count: 'exact',
      head: true
    });
    const { count: activeMembers } = await supabase.from('members').select('*', {
      count: 'exact',
      head: true
    }).eq('current_chapter_member', 'Yes');
    const { count: execMembers } = await supabase.from('members').select('*', {
      count: 'exact',
      head: true
    }).eq('executive_committee', true);
    // Get county distribution
    const { data: countyData } = await supabase.from('members').select('county').not('county', 'is', null);
    const countyDistribution = {};
    if (countyData) {
      for (const m of countyData){
        if (m.county) {
          countyDistribution[m.county] = (countyDistribution[m.county] || 0) + 1;
        }
      }
    }
    const topCounties = Object.entries(countyDistribution).sort((a, b)=>b[1] - a[1]).slice(0, 10);
    return `
MEMBERSHIP STATISTICS (as of ${new Date().toLocaleDateString()}):
- Total Members in Database: ${totalMembers || 0}
- Active Chapter Members: ${activeMembers || 0}
- Executive Committee Members: ${execMembers || 0}

TOP COUNTIES BY MEMBERSHIP:
${topCounties.length > 0 ? topCounties.map(([county, count])=>`- ${county}: ${count} members`).join('\n') : '- No county data available'}
`;
  } catch (err) {
    console.error('Error getting member stats:', err);
    return 'Member statistics unavailable.';
  }
}
async function getSubscriberStatistics() {
  try {
    const { count: totalSubs } = await supabase.from('subscribers').select('*', {
      count: 'exact',
      head: true
    });
    // FIXED: Use 'subscribed' boolean column instead of 'subscription_status'
    const { count: activeSubs } = await supabase.from('subscribers').select('*', {
      count: 'exact',
      head: true
    }).eq('subscribed', true);
    // Get subscribers since founding
    const { count: subsSinceFounding } = await supabase.from('subscribers').select('*', {
      count: 'exact',
      head: true
    }).gte('created_at', '2025-07-27').eq('subscribed', true);
    return `
SUBSCRIBER STATISTICS (as of ${new Date().toLocaleDateString()}):
- Total Subscribers: ${totalSubs || 0}
- Active Subscribers: ${activeSubs || 0}
- Active Subscribers Since Founding (July 2025): ${subsSinceFounding || 0}
`;
  } catch (err) {
    console.error('Error getting subscriber stats:', err);
    return 'Subscriber statistics unavailable.';
  }
}
async function getDonationStatistics() {
  try {
    // Using correct columns: amount, donation_date, donor_id
    const { data: donations } = await supabase.from('donations').select('amount, donation_date, created_at, donor_id');
    if (!donations || donations.length === 0) {
      return 'No donation data available in the system.';
    }
    const totalAmount = donations.reduce((sum, d)=>sum + (parseFloat(d.amount) || 0), 0);
    const uniqueDonors = new Set(donations.map((d)=>d.donor_id).filter(Boolean)).size;
    // Since founding - use donation_date if available, fall back to created_at
    const sinceFoundingDonations = donations.filter((d)=>{
      const donationDate = new Date(d.donation_date || d.created_at);
      return donationDate >= new Date('2025-07-27');
    });
    const sinceFoundingAmount = sinceFoundingDonations.reduce((sum, d)=>sum + (parseFloat(d.amount) || 0), 0);
    return `
DONATION STATISTICS (as of ${new Date().toLocaleDateString()}):
- Total Donations: $${totalAmount.toFixed(2)}
- Unique Donors: ${uniqueDonors}
- Total Donation Count: ${donations.length}
- Since Founding (July 2025): $${sinceFoundingAmount.toFixed(2)} from ${sinceFoundingDonations.length} donations
`;
  } catch (err) {
    console.error('Error getting donation stats:', err);
    return 'Donation statistics unavailable.';
  }
}
async function getEventStatistics() {
  try {
    // Using correct columns: title, event_date
    const { data: events, count: totalEvents } = await supabase.from('events').select('*', {
      count: 'exact'
    });
    const now = new Date();
    let eventsSinceFounding = 0;
    let upcomingEvents = 0;
    const eventList = [];
    if (events) {
      for (const e of events){
        const eventDate = new Date(e.event_date || e.created_at);
        if (eventDate >= new Date('2025-07-27')) {
          eventsSinceFounding++;
          if (e.title) {
            eventList.push(`- ${e.title} (${eventDate.toLocaleDateString()})`);
          }
        }
        if (eventDate > now) {
          upcomingEvents++;
        }
      }
    }
    return `
EVENT STATISTICS (as of ${new Date().toLocaleDateString()}):
- Total Events: ${totalEvents || 0}
- Events Since Founding (July 2025): ${eventsSinceFounding}
- Upcoming Events: ${upcomingEvents}

EVENTS LIST:
${eventList.length > 0 ? eventList.slice(0, 20).join('\n') : '- No event details available'}
${eventList.length > 20 ? `\n...and ${eventList.length - 20} more events` : ''}
`;
  } catch (err) {
    console.error('Error getting event stats:', err);
    return 'Event statistics unavailable.';
  }
}
async function getChapterStatistics() {
  try {
    // Using correct columns: chapter_name, chapter_type, status, is_chartered
    const { data: chapters, count: totalChapters } = await supabase.from('chapters').select('*', {
      count: 'exact'
    });
    if (!chapters || chapters.length === 0) {
      return `
CHAPTER STATISTICS:
- Total Chapters: ${totalChapters || 0}
- Details: No chapter records found in database
`;
    }
    // Group by chapter_type
    const collegeChapters = chapters.filter((c)=>c.chapter_type === 'college' || c.chapter_type === 'College' || c.chapter_name?.toLowerCase().includes('college') || c.chapter_name?.toLowerCase().includes('university'));
    const hsChapters = chapters.filter((c)=>c.chapter_type === 'high_school' || c.chapter_type === 'High School' || c.chapter_name?.toLowerCase().includes('high school'));
    const countyChapters = chapters.filter((c)=>c.chapter_type === 'county' || c.chapter_type === 'County' || c.chapter_name?.toLowerCase().includes('county'));
    return `
CHAPTER STATISTICS (as of ${new Date().toLocaleDateString()}):
- Total Chapters: ${totalChapters || 0}
- College Chapters (MOCD): ${collegeChapters.length}
- High School Chapters (MOHSD): ${hsChapters.length}
- County Chapters: ${countyChapters.length}

CHAPTER LIST:
${chapters.map((c)=>`- ${c.chapter_name}${c.status ? ` (${c.status})` : ''}${c.is_chartered ? ' [Chartered]' : ''}`).join('\n')}
`;
  } catch (err) {
    console.error('Error getting chapter stats:', err);
    return 'Chapter statistics unavailable.';
  }
}
async function getMeetingStatistics() {
  try {
    // Using correct columns: meeting_title, meeting_date, committee
    const { data: meetings, count: totalMeetings } = await supabase.from('meetings').select('*', {
      count: 'exact'
    }).order('meeting_date', {
      ascending: false
    });
    let meetingsSinceFounding = 0;
    const meetingList = [];
    if (meetings) {
      for (const m of meetings){
        const meetingDate = new Date(m.meeting_date || m.created_at);
        if (meetingDate >= new Date('2025-07-27')) {
          meetingsSinceFounding++;
          if (m.meeting_title) {
            meetingList.push(`- ${m.meeting_title} (${meetingDate.toLocaleDateString()})${m.committee ? ` [${m.committee}]` : ''}`);
          }
        }
      }
    }
    return `
MEETING STATISTICS (as of ${new Date().toLocaleDateString()}):
- Total Meetings Recorded: ${totalMeetings || 0}
- Meetings Since Founding (July 2025): ${meetingsSinceFounding}

RECENT MEETINGS:
${meetingList.length > 0 ? meetingList.slice(0, 15).join('\n') : '- No meeting records found'}
${meetingList.length > 15 ? `\n...and ${meetingList.length - 15} more meetings` : ''}
`;
  } catch (err) {
    console.error('Error getting meeting stats:', err);
    return 'Meeting statistics unavailable.';
  }
}
async function getSlackStatistics() {
  try {
    const { count: totalMessages } = await supabase.from('slack_messages').select('*', {
      count: 'exact',
      head: true
    });
    // Get unique channels
    const { data: channels } = await supabase.from('slack_messages').select('channel_name').not('channel_name', 'is', null);
    const uniqueChannels = new Set(channels?.map((c)=>c.channel_name)).size;
    return `
SLACK STATISTICS (as of ${new Date().toLocaleDateString()}):
- Total Messages Indexed: ${totalMessages || 0}
- Active Channels: ${uniqueChannels}
- Slack Workspace: 300+ members
`;
  } catch (err) {
    console.error('Error getting Slack stats:', err);
    return 'Slack statistics unavailable.';
  }
}
// =============================================================================
// MEMORY SYSTEM - Retrieval
// =============================================================================
async function retrieveSessionMemory(sessionId) {
  if (!sessionId) return [];
  try {
    const { data, error } = await supabase.from('ai_session_memory').select('id, memory_type, content').eq('session_id', sessionId).gt('expires_at', new Date().toISOString()).order('created_at', {
      ascending: false
    }).limit(10);
    if (error) {
      console.error('Session memory retrieval error:', error);
      return [];
    }
    return data || [];
  } catch (err) {
    console.error('Session memory error:', err);
    return [];
  }
}
async function retrieveUserMemory(userId, queryEmbedding) {
  if (!userId) return [];
  try {
    const { data, error } = await supabase.rpc('search_user_memory', {
      query_embedding: queryEmbedding,
      p_user_id: userId,
      match_count: 5,
      match_threshold: 0.4
    });
    if (error) {
      console.error('User memory retrieval error:', error);
      return [];
    }
    return data || [];
  } catch (err) {
    console.error('User memory error:', err);
    return [];
  }
}
async function retrieveOrgMemory(queryEmbedding) {
  try {
    const { data, error } = await supabase.rpc('search_org_memory', {
      query_embedding: queryEmbedding,
      match_count: 5,
      match_threshold: 0.4
    });
    if (error) {
      console.error('Org memory retrieval error:', error);
      return [];
    }
    return data || [];
  } catch (err) {
    console.error('Org memory error:', err);
    return [];
  }
}
async function retrieveAllMemories(query, sessionId, userId, embeddingString) {
  let finalEmbeddingString = embeddingString;
  if (!finalEmbeddingString) {
    const embedding = await embedQuery(query);
    finalEmbeddingString = formatEmbeddingForPgvector(embedding);
  }
  const [sessionMemories, userMemories, orgMemories] = await Promise.all([
    sessionId ? retrieveSessionMemory(sessionId) : Promise.resolve([]),
    userId ? retrieveUserMemory(userId, finalEmbeddingString) : Promise.resolve([]),
    retrieveOrgMemory(finalEmbeddingString)
  ]);
  return {
    session: sessionMemories,
    user: userMemories,
    org: orgMemories
  };
}
// =============================================================================
// MEMORY SYSTEM - Extraction & Storage
// =============================================================================
async function extractAndStoreMemories(query, response, sessionId, userId) {
  if (!sessionId && !userId) return;
  try {
    const extractionPrompt = `Analyze this conversation and extract memories to store. Be very selective - only extract genuinely useful information.

USER QUERY: ${query}

AI RESPONSE: ${response.substring(0, 2000)}

Extract the following (return valid JSON only, no markdown):
{
  "session_memories": [
    // Context that should be remembered for THIS conversation only
    // e.g., "User is asking about executive committee members"
    // Only include if there's a clear topic or context being established
  ],
  "user_memories": [
    // Long-term facts about this user's preferences/needs that would help future conversations
    // e.g., "User prefers detailed contact information in responses"
    // e.g., "User is interested in policy committee activities"
    // Only include clear preferences or patterns
  ],
  "org_memories": [
    // General organizational knowledge learned that could help ANY user
    // e.g., "Executive committee meets monthly on the first Tuesday"
    // Only include if this is a reusable fact not already in the knowledge base
  ]
}

Return ONLY valid JSON. Return empty arrays if nothing notable to extract.`;
    let extractedText;
    try {
      // json:true rather than relying on the fence stripping below. That
      // stripping stays as a second line of defence; it is cheap and it costs
      // nothing if the reply is already clean.
      extractedText = (await callGemini({
        prompt: extractionPrompt,
        json: true,
        maxTokens: 1024
      })).text;
    } catch (apiErr) {
      // Unchanged in effect: this runs detached from the response via
      // .catch() at the call site, so a failure here must never surface to the
      // user. No memories are stored and the answer they already have stands.
      console.error('Memory extraction API error:', apiErr instanceof Error ? apiErr.message : String(apiErr));
      return;
    }
    let memories;
    try {
      const cleanedText = extractedText.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
      memories = JSON.parse(cleanedText);
    } catch (parseErr) {
      console.error('Failed to parse memory extraction:', parseErr);
      return;
    }
    // Store session memories
    if (sessionId && memories.session_memories?.length > 0) {
      for (const mem of memories.session_memories.slice(0, 3)){
        await supabase.from('ai_session_memory').insert({
          session_id: sessionId,
          memory_type: 'context',
          content: mem,
          expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
        }).catch((err)=>console.error('Session memory insert error:', err));
      }
    }
    // Store user memories
    if (userId && memories.user_memories?.length > 0) {
      for (const mem of memories.user_memories.slice(0, 2)){
        try {
          const memEmbedding = await embedQuery(mem);
          const memEmbeddingString = formatEmbeddingForPgvector(memEmbedding);
          await supabase.from('ai_user_memory').upsert({
            user_id: userId,
            memory_type: 'preference',
            content: mem,
            embedding: memEmbeddingString,
            importance_score: 0.5,
            updated_at: new Date().toISOString()
          }, {
            onConflict: 'user_id,content',
            ignoreDuplicates: true
          });
        } catch (err) {
          console.error('User memory insert error:', err);
        }
      }
    }
    // Store org memories
    if (memories.org_memories?.length > 0) {
      for (const mem of memories.org_memories.slice(0, 1)){
        try {
          const memEmbedding = await embedQuery(mem);
          const memEmbeddingString = formatEmbeddingForPgvector(memEmbedding);
          await supabase.from('ai_org_memory').upsert({
            memory_type: 'fact',
            content: mem,
            embedding: memEmbeddingString,
            confidence_score: 0.5,
            updated_at: new Date().toISOString()
          }, {
            onConflict: 'content',
            ignoreDuplicates: true
          });
        } catch (err) {
          console.error('Org memory insert error:', err);
        }
      }
    }
    console.log(`Extracted memories: session=${memories.session_memories?.length || 0}, user=${memories.user_memories?.length || 0}, org=${memories.org_memories?.length || 0}`);
  } catch (err) {
    console.error('Memory extraction error:', err);
  }
}
// =============================================================================
// FEEDBACK LEARNING - Apply Learned Patterns
// =============================================================================
async function getLearnedPatterns(queryEmbedding) {
  try {
    const { data: patterns } = await supabase.from('ai_learned_patterns').select('pattern_type, action, confidence_score').gte('confidence_score', 0.6).order('confidence_score', {
      ascending: false
    }).limit(5);
    const { data: successfulQueries } = await supabase.from('ai_successful_queries').select('original_query, successful_sources, feedback_score').gte('feedback_score', 0.7).order('feedback_score', {
      ascending: false
    }).limit(3);
    return {
      patterns: patterns || [],
      successfulQueries: successfulQueries || []
    };
  } catch (err) {
    console.error('Learned patterns error:', err);
    return {
      patterns: [],
      successfulQueries: []
    };
  }
}
// =============================================================================
// INTENT DETECTION
// =============================================================================
function detectIntent(query) {
  const q = query.toLowerCase();
  const recentPatterns = /\b(recent|latest|last|newest|most recent|current)\b/i;
  const upcomingPatterns = /\b(upcoming|next|future|scheduled|coming up)\b/i;
  const pastPatterns = /\b(past|previous|earlier|old|history|historical)\b/i;
  const meetingPatterns = /\b(meeting|meetings|exec committee meeting|executive committee meeting)\b/i;
  const memberPatterns = /\b(member|members|who is|find person|contact for|person named)\b/i;
  const eventPatterns = /\b(event|events|happening|activities)\b/i;
  const billPatterns = /\b(bill|bills|legislation|hb|sb|law|laws)\b/i;
  const committeePatterns = /\b(committee|committees|fundraising committee|policy committee|communications)\b/i;
  const executivePatterns = /\b(executive|exec|leadership|officers|president|vice president|secretary|treasurer)\b/i;
  const chapterPatterns = /\b(chapter|chapters|college democrats|high school democrats|county chapter)\b/i;
  const relationshipPatterns = /\b(reports to|works with|member of|in charge of|leads|manages|part of|belongs to)\b/i;
  const countPatterns = /\b(how many|count|total|number of)\b/i;
  const listPatterns = /\b(list|all|show me|find all|get all|give me)\b/i;
  const countyPatterns = /\b(jackson county|clay county|st\.? louis|kansas city|columbia|springfield|boone county|greene county|[a-z]+ county)\b/i;
  const countyMatch = q.match(countyPatterns);
  const namePatterns = /\b(named?|called)\s+([A-Z][a-z]+ ?[A-Z]?[a-z]*)/i;
  const nameMatch = query.match(namePatterns);
  let intent = {
    type: 'semantic',
    confidence: 0.5
  };
  if (recentPatterns.test(q)) {
    intent.temporal = 'recent';
    intent.confidence += 0.2;
  } else if (upcomingPatterns.test(q)) {
    intent.temporal = 'upcoming';
    intent.confidence += 0.2;
  } else if (pastPatterns.test(q)) {
    intent.temporal = 'past';
    intent.confidence += 0.1;
  }
  if (relationshipPatterns.test(q)) {
    intent.type = 'relationship';
    intent.confidence += 0.3;
  }
  if (meetingPatterns.test(q)) {
    intent.entity = 'meetings';
    intent.type = intent.temporal ? 'temporal' : 'entity_lookup';
    intent.confidence += 0.3;
  } else if (memberPatterns.test(q) || nameMatch || countyMatch) {
    intent.entity = 'members';
    intent.type = 'entity_lookup';
    intent.confidence += 0.3;
    intent.filters = {};
    if (countyMatch) {
      intent.filters.county = countyMatch[0];
    }
    if (nameMatch) {
      intent.filters.name = nameMatch[2];
    }
  } else if (eventPatterns.test(q)) {
    intent.entity = 'events';
    intent.type = intent.temporal ? 'temporal' : 'entity_lookup';
    intent.confidence += 0.3;
  } else if (billPatterns.test(q)) {
    intent.entity = 'legislation_tracked_bills';
    intent.type = 'entity_lookup';
    intent.confidence += 0.3;
  } else if (executivePatterns.test(q)) {
    intent.entity = 'members';
    intent.type = 'entity_lookup';
    intent.filters = {
      executive_committee: true
    };
    intent.confidence += 0.3;
  } else if (chapterPatterns.test(q)) {
    intent.entity = 'chapters';
    intent.type = 'entity_lookup';
    intent.confidence += 0.3;
  } else if (committeePatterns.test(q)) {
    intent.entity = 'members';
    intent.type = 'list';
    const commMatch = q.match(/\b(fundraising|policy|communications|political affairs|events|creators)\b/i);
    if (commMatch) {
      intent.filters = {
        committee: commMatch[1]
      };
    }
    intent.confidence += 0.2;
  }
  if (countPatterns.test(q)) {
    intent.type = 'aggregate';
    intent.confidence += 0.2;
  } else if (listPatterns.test(q) && !intent.temporal) {
    intent.type = 'list';
    intent.confidence += 0.1;
  }
  intent.keywords = extractKeywords(query);
  intent.confidence = Math.min(intent.confidence, 1.0);
  return intent;
}
function extractKeywords(query) {
  const stopWords = new Set([
    'the',
    'a',
    'an',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'being',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'will',
    'would',
    'could',
    'should',
    'may',
    'might',
    'what',
    'who',
    'where',
    'when',
    'why',
    'how',
    'which',
    'this',
    'that',
    'these',
    'those',
    'i',
    'me',
    'my',
    'we',
    'our',
    'you',
    'your',
    'it',
    'its',
    'they',
    'them',
    'their',
    'tell',
    'show',
    'find',
    'get',
    'give',
    'about',
    'from',
    'with',
    'for',
    'and',
    'or',
    'but',
    'in',
    'on',
    'at',
    'to',
    'of',
    'by',
    'as',
    'if',
    'than',
    'so',
    'just',
    'also',
    'very',
    'can',
    'please',
    'know',
    'want',
    'need',
    'like',
    'moyd',
    'missouri',
    'young',
    'democrats'
  ]);
  return query.toLowerCase().replace(/[^\w\s]/g, '').split(/\s+/).filter((word)=>word.length > 2 && !stopWords.has(word));
}
// =============================================================================
// STRUCTURED QUERIES - Direct Database Lookups
// =============================================================================
async function structuredQuery(intent) {
  const results = [];
  try {
    if (intent.entity === 'meetings') {
      let query = supabase.from('knowledge_documents').select('*').eq('source_table', 'meetings').not('content', 'is', null);
      if (intent.temporal === 'recent') {
        query = query.order('created_at', {
          ascending: false
        }).limit(5);
      } else if (intent.temporal === 'upcoming') {
        query = query.gte('created_at', new Date().toISOString()).order('created_at', {
          ascending: true
        }).limit(5);
      } else {
        query = query.order('created_at', {
          ascending: false
        }).limit(5);
      }
      const { data, error } = await query;
      if (data && !error) {
        results.push(...data.map((d)=>({
            ...d,
            retrieval_method: 'structured',
            priority: 1
          })));
      }
    }
    if (intent.entity === 'events') {
      let query = supabase.from('knowledge_documents').select('*').eq('source_table', 'events');
      if (intent.temporal === 'recent' || intent.temporal === 'past') {
        query = query.order('created_at', {
          ascending: false
        }).limit(10);
      } else if (intent.temporal === 'upcoming') {
        query = query.order('created_at', {
          ascending: true
        }).limit(10);
      } else {
        query = query.limit(10);
      }
      const { data, error } = await query;
      if (data && !error) {
        results.push(...data.map((d)=>({
            ...d,
            retrieval_method: 'structured',
            priority: 1
          })));
      }
    }
    if (intent.entity === 'members') {
      let query = supabase.from('knowledge_documents').select('*').eq('source_table', 'members');
      if (intent.filters?.executive_committee) {
        query = query.ilike('content', '%Executive Committee: true%');
      }
      if (intent.filters?.county) {
        query = query.ilike('content', `%County: ${intent.filters.county}%`);
      }
      if (intent.filters?.committee) {
        query = query.ilike('content', `%${intent.filters.committee}%`);
      }
      if (intent.filters?.name) {
        query = query.ilike('content', `%${intent.filters.name}%`);
      }
      query = query.limit(20);
      const { data, error } = await query;
      if (data && !error) {
        results.push(...data.map((d)=>({
            ...d,
            retrieval_method: 'structured',
            priority: 1
          })));
      }
    }
    if (intent.entity === 'chapters') {
      const { data, error } = await supabase.from('knowledge_documents').select('*').eq('source_table', 'chapters').limit(20);
      if (data && !error) {
        results.push(...data.map((d)=>({
            ...d,
            retrieval_method: 'structured',
            priority: 1
          })));
      }
    }
    if (intent.entity === 'legislation_tracked_bills') {
      const { data, error } = await supabase.from('knowledge_documents').select('*').eq('source_table', 'legislation_tracked_bills').limit(15);
      if (data && !error) {
        results.push(...data.map((d)=>({
            ...d,
            retrieval_method: 'structured',
            priority: 1
          })));
      }
    }
  } catch (err) {
    console.error('Structured query error:', err);
  }
  return results;
}
// =============================================================================
// SEMANTIC SEARCH - Vector Similarity
// =============================================================================
async function semanticSearch(query, count = 20, threshold = 0.25) {
  try {
    const embedding = await embedQuery(query);
    const embeddingString = formatEmbeddingForPgvector(embedding);
    const { data, error } = await supabase.rpc("search_knowledge_base", {
      query_embedding: embeddingString,
      match_count: count,
      match_threshold: threshold
    });
    if (error) {
      console.error('Semantic search error:', error);
      return [];
    }
    const boostedResults = (data || []).map((doc)=>{
      let boost = doc.retrieval_boost || 1.0;
      if (doc.source_type === 'manual' || doc.source_table === 'organization') {
        boost = Math.max(boost, 1.5);
      }
      const boostedSimilarity = (doc.similarity || 0) * boost;
      return {
        ...doc,
        similarity: doc.similarity,
        boosted_similarity: boostedSimilarity,
        retrieval_method: 'semantic',
        priority: 2
      };
    });
    return boostedResults.sort((a, b)=>b.boosted_similarity - a.boosted_similarity);
  } catch (err) {
    console.error('Semantic search error:', err);
    return [];
  }
}
// =============================================================================
// KEYWORD SEARCH
// =============================================================================
async function keywordSearch(keywords, limit = 10) {
  if (!keywords.length) return [];
  try {
    let query = supabase.from('knowledge_documents').select('*').not('content', 'is', null);
    const conditions = keywords.map((kw)=>`content.ilike.%${kw}%`).join(',');
    query = query.or(conditions);
    query = query.limit(limit);
    const { data, error } = await query;
    if (error) {
      console.error('Keyword search error:', error);
      return [];
    }
    return (data || []).map((d)=>({
        ...d,
        retrieval_method: 'keyword',
        priority: 3
      }));
  } catch (err) {
    console.error('Keyword search error:', err);
    return [];
  }
}
// =============================================================================
// CRAG - Self-Corrective RAG
// =============================================================================
async function evaluateRetrieval(query, documents) {
  if (documents.length === 0) {
    return {
      action: 'incorrect',
      documents: [],
      reason: 'No documents retrieved'
    };
  }
  const semanticDocs = documents.filter((d)=>d.retrieval_method === 'semantic' && d.similarity);
  const avgSimilarity = semanticDocs.length > 0 ? semanticDocs.reduce((sum, d)=>sum + (d.similarity || 0), 0) / semanticDocs.length : 0;
  const hasStructuredResults = documents.some((d)=>d.retrieval_method === 'structured');
  if (hasStructuredResults && documents.length >= 3) {
    return {
      action: 'correct',
      documents,
      reason: 'Structured query matched'
    };
  }
  if (avgSimilarity >= 0.5) {
    return {
      action: 'correct',
      documents,
      reason: 'High semantic similarity'
    };
  }
  if (avgSimilarity >= 0.3 && documents.length >= 5) {
    return {
      action: 'ambiguous',
      documents,
      reason: 'Moderate similarity - refining'
    };
  }
  if (avgSimilarity < 0.3 && !hasStructuredResults) {
    return {
      action: 'incorrect',
      documents,
      reason: 'Low relevance scores'
    };
  }
  return {
    action: 'correct',
    documents,
    reason: 'Default pass'
  };
}
async function fallbackRetrieval(query, originalIntent) {
  console.log('Executing fallback retrieval...');
  const broadSemanticResults = await semanticSearch(query, 30, 0.15);
  if (broadSemanticResults.length < 5 && originalIntent.keywords) {
    const keywordResults = await keywordSearch(originalIntent.keywords, 20);
    return [
      ...broadSemanticResults,
      ...keywordResults
    ];
  }
  return broadSemanticResults;
}
async function refineDocuments(query, documents) {
  try {
    const docSummaries = documents.slice(0, 15).map((d, i)=>`[${i}] ${d.title || 'Untitled'}: ${(d.content || '').substring(0, 200)}...`).join('\n');
    const refinementPrompt = `Given this query: "${query}"

Rate each document's relevance (0-10) and return ONLY a JSON array of indices to keep (relevance >= 5):

${docSummaries}

Return format: [0, 2, 5, ...] (indices of relevant documents)`;
    // 512 rather than the 256 the Anthropic call used. The reply is a short
    // index array either way, but a reply truncated by the cap fails the regex
    // below and silently falls through to returning EVERY document unrefined,
    // which is the failure this function exists to prevent. Headroom is cheaper
    // than that.
    const { text } = await callGemini({
      prompt: refinementPrompt,
      json: true,
      maxTokens: 512
    });
    const match = text.match(/\[[\d,\s]+\]/);
    if (match) {
      const indices = JSON.parse(match[0]);
      return indices.filter((i)=>i < documents.length).map((i)=>documents[i]);
    }
  } catch (err) {
    console.error('Document refinement error:', err);
  }
  return documents;
}
// =============================================================================
// COMPREHENSIVE RETRIEVAL - For exhaustive queries
// =============================================================================
// Estimate tokens (rough: 1 token ≈ 4 chars)
function estimateTokens(text) {
  return Math.ceil(text.length / 4);
}
// Maximum tokens for context (leave room for system prompt + response)
const MAX_CONTEXT_TOKENS = 150000;
async function comprehensiveRetrieval(query, classification) {
  const allResults = [];
  let estimatedTokens = 0;
  console.log(`COMPREHENSIVE RETRIEVAL MODE`);
  console.log(`Data needs: ${classification.dataNeeds.join(', ')}`);
  // Helper to add docs while tracking token budget
  const addDocsWithBudget = (docs, method, priority, maxDocs = 50)=>{
    const limited = docs.slice(0, maxDocs);
    for (const d of limited){
      const docTokens = estimateTokens(d.content || '');
      if (estimatedTokens + docTokens > MAX_CONTEXT_TOKENS) {
        console.log(`Token budget reached, stopping at ${allResults.length} docs`);
        return false; // Budget exhausted
      }
      estimatedTokens += docTokens;
      allResults.push({
        ...d,
        retrieval_method: method,
        priority
      });
    }
    return true; // Can continue
  };
  // 1. Get foundational/organizational documents (HIGH PRIORITY - always include)
  const { data: orgDocs } = await supabase.from('knowledge_documents').select('*').or('source_table.eq.organization,source_type.eq.manual').limit(20);
  if (orgDocs) {
    console.log(`Retrieved ${orgDocs.length} organizational documents`);
    addDocsWithBudget(orgDocs, 'foundational', 0, 20);
  }
  // 2. Get data for each needed source WITH LIMITS
  for (const dataSource of classification.dataNeeds){
    if (estimatedTokens > MAX_CONTEXT_TOKENS * 0.9) {
      console.log(`Near token budget, skipping remaining data sources`);
      break;
    }
    switch(dataSource){
      case 'meetings':
        const { data: meetingDocs } = await supabase.from('knowledge_documents').select('*').eq('source_table', 'meetings').order('created_at', {
          ascending: false
        }).limit(30); // LIMIT added
        if (meetingDocs) {
          console.log(`Retrieved ${meetingDocs.length} meeting documents`);
          addDocsWithBudget(meetingDocs, 'structured_exhaustive', 1, 30);
        }
        break;
      case 'events':
        const { data: eventDocs } = await supabase.from('knowledge_documents').select('*').eq('source_table', 'events').order('created_at', {
          ascending: false
        }).limit(25); // LIMIT added
        if (eventDocs) {
          console.log(`Retrieved ${eventDocs.length} event documents`);
          addDocsWithBudget(eventDocs, 'structured_exhaustive', 1, 25);
        }
        break;
      case 'chapters':
        const { data: chapterDocs } = await supabase.from('knowledge_documents').select('*').eq('source_table', 'chapters').limit(20); // LIMIT added
        if (chapterDocs) {
          console.log(`Retrieved ${chapterDocs.length} chapter documents`);
          addDocsWithBudget(chapterDocs, 'structured_exhaustive', 1, 20);
        }
        break;
      case 'members_stats':
        const memberStats = await getMemberStatistics();
        allResults.push({
          id: 'member_stats_aggregated',
          title: 'Membership Statistics (Aggregated)',
          content: memberStats,
          source_type: 'aggregated',
          source_table: 'members',
          retrieval_method: 'aggregation',
          priority: 0
        });
        estimatedTokens += estimateTokens(memberStats);
        break;
      case 'subscribers_stats':
        const subStats = await getSubscriberStatistics();
        allResults.push({
          id: 'subscriber_stats_aggregated',
          title: 'Subscriber Statistics (Aggregated)',
          content: subStats,
          source_type: 'aggregated',
          source_table: 'subscribers',
          retrieval_method: 'aggregation',
          priority: 0
        });
        estimatedTokens += estimateTokens(subStats);
        break;
      case 'donations_stats':
        const donationStats = await getDonationStatistics();
        allResults.push({
          id: 'donation_stats_aggregated',
          title: 'Donation Statistics (Aggregated)',
          content: donationStats,
          source_type: 'aggregated',
          source_table: 'donations',
          retrieval_method: 'aggregation',
          priority: 0
        });
        estimatedTokens += estimateTokens(donationStats);
        break;
      case 'committees':
        const { data: committeeDocs } = await supabase.from('knowledge_documents').select('*').or('source_table.eq.committees,content.ilike.%committee%').limit(20); // LIMIT added
        if (committeeDocs) {
          console.log(`Retrieved ${committeeDocs.length} committee documents`);
          addDocsWithBudget(committeeDocs, 'structured_exhaustive', 1, 20);
        }
        // Add aggregated stats
        const eventStats = await getEventStatistics();
        allResults.push({
          id: 'event_stats_aggregated',
          title: 'Event Statistics (Aggregated)',
          content: eventStats,
          source_type: 'aggregated',
          source_table: 'events',
          retrieval_method: 'aggregation',
          priority: 0
        });
        estimatedTokens += estimateTokens(eventStats);
        const meetingStats = await getMeetingStatistics();
        allResults.push({
          id: 'meeting_stats_aggregated',
          title: 'Meeting Statistics (Aggregated)',
          content: meetingStats,
          source_type: 'aggregated',
          source_table: 'meetings',
          retrieval_method: 'aggregation',
          priority: 0
        });
        estimatedTokens += estimateTokens(meetingStats);
        const chapterStats = await getChapterStatistics();
        allResults.push({
          id: 'chapter_stats_aggregated',
          title: 'Chapter Statistics (Aggregated)',
          content: chapterStats,
          source_type: 'aggregated',
          source_table: 'chapters',
          retrieval_method: 'aggregation',
          priority: 0
        });
        estimatedTokens += estimateTokens(chapterStats);
        break;
      case 'slack_highlights':
        const slackStats = await getSlackStatistics();
        allResults.push({
          id: 'slack_stats_aggregated',
          title: 'Slack Statistics (Aggregated)',
          content: slackStats,
          source_type: 'aggregated',
          source_table: 'slack_messages',
          retrieval_method: 'aggregation',
          priority: 0
        });
        estimatedTokens += estimateTokens(slackStats);
        const { data: slackDocs } = await supabase.from('knowledge_documents').select('*').eq('source_table', 'slack_messages').order('created_at', {
          ascending: false
        }).limit(15); // LIMIT reduced
        if (slackDocs) {
          console.log(`Retrieved ${slackDocs.length} Slack documents`);
          addDocsWithBudget(slackDocs, 'structured_exhaustive', 2, 15);
        }
        break;
    }
  }
  // 3. Only do semantic search if we have token budget left
  if (estimatedTokens < MAX_CONTEXT_TOKENS * 0.8) {
    const semanticResults = await semanticSearch(query, 20, 0.3); // Reduced count & raised threshold
    for (const doc of semanticResults){
      if (estimatedTokens > MAX_CONTEXT_TOKENS * 0.9) break;
      if (!allResults.some((r)=>r.id === doc.id)) {
        const docTokens = estimateTokens(doc.content || '');
        if (estimatedTokens + docTokens <= MAX_CONTEXT_TOKENS) {
          allResults.push(doc);
          estimatedTokens += docTokens;
        }
      }
    }
  }
  console.log(`TOTAL DOCUMENTS RETRIEVED: ${allResults.length}`);
  console.log(`ESTIMATED TOKENS: ${estimatedTokens}`);
  return allResults;
}
// =============================================================================
// HYBRID RETRIEVAL - Standard mode
// =============================================================================
async function hybridRetrieval(query, intent, applyCorrection = true) {
  const allResults = new Map();
  const { data: orgDocs } = await supabase.from('knowledge_documents').select('*').eq('source_type', 'manual').eq('source_table', 'organization').limit(5);
  if (orgDocs) {
    for (const doc of orgDocs){
      allResults.set(doc.id, {
        ...doc,
        retrieval_method: 'foundational',
        priority: 0,
        retrieval_boost: 2.0
      });
    }
  }
  if (intent.type === 'temporal' || intent.type === 'entity_lookup' || intent.type === 'list') {
    const structuredResults = await structuredQuery(intent);
    for (const doc of structuredResults){
      if (!allResults.has(doc.id)) {
        allResults.set(doc.id, doc);
      }
    }
  }
  const semanticResults = await semanticSearch(query, 20, 0.25);
  for (const doc of semanticResults){
    if (!allResults.has(doc.id)) {
      allResults.set(doc.id, doc);
    }
  }
  if (intent.keywords && intent.keywords.length > 0) {
    const keywordResults = await keywordSearch(intent.keywords, 10);
    for (const doc of keywordResults){
      if (!allResults.has(doc.id)) {
        allResults.set(doc.id, doc);
      }
    }
  }
  let sorted = Array.from(allResults.values()).sort((a, b)=>{
    if (a.priority !== b.priority) return a.priority - b.priority;
    const aSim = a.boosted_similarity || a.similarity || 0;
    const bSim = b.boosted_similarity || b.similarity || 0;
    return bSim - aSim;
  });
  if (applyCorrection) {
    const cragResult = await evaluateRetrieval(query, sorted);
    console.log(`CRAG evaluation: ${cragResult.action} - ${cragResult.reason}`);
    if (cragResult.action === 'incorrect') {
      sorted = await fallbackRetrieval(query, intent);
    } else if (cragResult.action === 'ambiguous') {
      sorted = await refineDocuments(query, cragResult.documents);
    }
  }
  return sorted.slice(0, 30);
}
// =============================================================================
// CONTEXT FORMATTING
// =============================================================================
function formatMemoriesContext(memories) {
  const parts = [];
  if (memories.session.length > 0) {
    parts.push('**Session Context:**');
    for (const mem of memories.session){
      parts.push(`- ${mem.content}`);
    }
    parts.push('');
  }
  if (memories.user.length > 0) {
    parts.push('**User Preferences & History:**');
    for (const mem of memories.user){
      parts.push(`- ${mem.content}`);
    }
    parts.push('');
  }
  if (memories.org.length > 0) {
    parts.push('**Organizational Knowledge:**');
    for (const mem of memories.org){
      parts.push(`- ${mem.content}`);
    }
    parts.push('');
  }
  return parts.length > 0 ? parts.join('\n') : '';
}
function organizeContext(docs, intent, memories, isComprehensive = false) {
  let context = '';
  let tokenCount = 0;
  const maxContextTokens = 140000; // Leave room for system prompt + response
  // Helper to check token budget
  const addWithBudget = (text)=>{
    const tokens = Math.ceil(text.length / 4);
    if (tokenCount + tokens > maxContextTokens) {
      return false;
    }
    tokenCount += tokens;
    context += text;
    return true;
  };
  if (isComprehensive) {
    const dateContext = `## CURRENT DATE CONTEXT\n${getCurrentDateContext()}\n---\n\n`;
    addWithBudget(dateContext);
  }
  const memoriesContext = formatMemoriesContext(memories);
  if (memoriesContext) {
    addWithBudget(`## Relevant Memories\n${memoriesContext}\n---\n\n`);
  }
  if (!docs || docs.length === 0) {
    addWithBudget("No documents found. Use your general knowledge about MOYD from the VERIFIED CORE FACTS to help.");
    return context;
  }
  const grouped = {};
  for (const doc of docs){
    const key = doc.source_table || doc.source_type || 'other';
    if (!grouped[key]) grouped[key] = [];
    grouped[key].push(doc);
  }
  const retrievalMethods = new Set(docs.map((d)=>d.retrieval_method));
  addWithBudget(`**Retrieved ${docs.length} documents using ${retrievalMethods.size} retrieval methods: ${Array.from(retrievalMethods).join(', ')}**\n\n`);
  // For comprehensive queries, prioritize aggregated stats
  if (isComprehensive) {
    const aggregatedDocs = docs.filter((d)=>d.retrieval_method === 'aggregation');
    if (aggregatedDocs.length > 0) {
      let statsSection = `## AGGREGATED STATISTICS\n\n`;
      for (const doc of aggregatedDocs){
        statsSection += `### ${doc.title}\n${doc.content}\n\n`;
      }
      statsSection += `---\n\n`;
      addWithBudget(statsSection);
    }
  }
  const priority = [
    'organization',
    intent.entity,
    'manual',
    'members',
    'meetings',
    'chapters',
    'events',
    'legislation_tracked_bills',
    'subscribers',
    'slack_messages',
    'donations',
    'donors',
    'storage_file'
  ].filter(Boolean);
  const seen = new Set();
  for (const sourceType of priority){
    if (!sourceType || seen.has(sourceType)) continue;
    if (tokenCount > maxContextTokens * 0.95) {
      context += `\n*[Context truncated to stay within token limits]*\n`;
      break;
    }
    seen.add(sourceType);
    if (grouped[sourceType] && grouped[sourceType].length > 0) {
      const filteredDocs = isComprehensive ? grouped[sourceType].filter((d)=>d.retrieval_method !== 'aggregation') : grouped[sourceType];
      if (filteredDocs.length === 0) continue;
      const label = sourceType.replace(/_/g, ' ').replace(/\b\w/g, (c)=>c.toUpperCase());
      const headerAdded = addWithBudget(`\n### ${label} (${filteredDocs.length} results)\n\n`);
      if (!headerAdded) break;
      // Reduce limits for comprehensive to fit more variety
      const limit = isComprehensive ? 15 : 10;
      let addedCount = 0;
      for (const doc of filteredDocs.slice(0, limit)){
        const method = doc.retrieval_method ? ` [${doc.retrieval_method}]` : '';
        const sim = doc.similarity ? ` (${Math.round(doc.similarity * 100)}% match)` : '';
        const docText = `**${doc.title || 'Untitled'}**${method}${sim}\n${doc.content}\n\n---\n\n`;
        if (!addWithBudget(docText)) {
          context += `\n*[Additional ${filteredDocs.length - addedCount} ${label.toLowerCase()} documents truncated]*\n`;
          break;
        }
        addedCount++;
      }
      if (filteredDocs.length > limit && addedCount === limit) {
        addWithBudget(`*...and ${filteredDocs.length - limit} more ${label.toLowerCase()} documents*\n\n`);
      }
    }
  }
  // Only add remaining sources if we have budget
  for (const [sourceType, sourceDocs] of Object.entries(grouped)){
    if (tokenCount > maxContextTokens * 0.95) break;
    if (!seen.has(sourceType)) {
      const filteredDocs = isComprehensive ? sourceDocs.filter((d)=>d.retrieval_method !== 'aggregation') : sourceDocs;
      if (filteredDocs.length === 0) continue;
      const label = sourceType.replace(/_/g, ' ').replace(/\b\w/g, (c)=>c.toUpperCase());
      if (!addWithBudget(`\n### ${label} (${filteredDocs.length} results)\n\n`)) break;
      for (const doc of filteredDocs.slice(0, 5)){
        const docText = `**${doc.title || 'Untitled'}**\n${doc.content}\n\n---\n\n`;
        if (!addWithBudget(docText)) break;
      }
    }
  }
  console.log(`Context organized: ~${tokenCount} tokens`);
  return context;
}
// =============================================================================
// RESPONSE GENERATION
// =============================================================================
async function generateResponse(query, context, intent, classification, history = [], learnedPatterns) {
  const messages = [];
  for (const msg of history.slice(-10)){
    messages.push({
      role: msg.role,
      content: msg.content
    });
  }
  const intentInfo = `
**Detected Intent**: ${intent.type} (confidence: ${Math.round(intent.confidence * 100)}%)
**Entity Type**: ${intent.entity || 'general'}
**Temporal**: ${intent.temporal || 'none'}
**Filters**: ${JSON.stringify(intent.filters || {})}
`;
  const classificationInfo = classification.scope === 'exhaustive' ? `
**Task Classification**: ${classification.type}
**Retrieval Scope**: ${classification.scope.toUpperCase()}
**Data Sources**: ${classification.dataNeeds.join(', ')}
` : '';
  let patternsInfo = '';
  if (learnedPatterns.patterns.length > 0) {
    patternsInfo = `\n**Learned Patterns to Apply:**\n${learnedPatterns.patterns.map((p)=>`- ${p.action}`).join('\n')}\n`;
  }
  let specialInstructions = '';
  if (classification.scope === 'exhaustive') {
    specialInstructions = `
## IMPORTANT INSTRUCTIONS FOR THIS COMPREHENSIVE REQUEST

You have been provided with EXTENSIVE data from the MOYD knowledge base. This is a comprehensive request that requires a thorough response.

1. **Use ALL the data provided** - Don't just skim; synthesize information from all sources
2. **Include specific numbers, dates, and names** from the data
3. **Reference actual events, meetings, and accomplishments** from the records
4. **Calculate time periods correctly** using TODAY'S DATE: ${new Date().toLocaleDateString()}
5. **Use the VERIFIED CORE FACTS** from your system prompt for organizational details
6. **DO NOT make up or estimate facts** - only use what's in the data

CRITICAL REMINDERS:
- Age range is 14-36 (NOT 14-40)
- There are 7 standing committees (NOT 6)
- MOYD was founded July 27, 2025 (current year is ${new Date().getFullYear()})
- We are a "chartered state federation of YDA" that works closely with MDP (NOT "official youth arm")
`;
  }
  const userMessage = `## Query Analysis
${intentInfo}
${classificationInfo}
${patternsInfo}
${specialInstructions}

## Search Results from MOYD Database
${context}

---

## User Question
${query}

---

Provide a comprehensive, helpful response based on the search results above. The results include data from multiple retrieval methods including structured queries, semantic search, and keyword matching. Prioritize the most relevant results for the user's specific question.

If you notice patterns in the user's questions or preferences from the memories, incorporate that naturally into your response.`;
  const maxTokens = classification.scope === 'exhaustive' ? 8192 : 4096;
  // `messages` holds up to the last ten turns and is passed through as history
  // rather than flattened into one string. The turn structure is what lets the
  // model resolve "them", "that one" and "the second one" against the right
  // earlier answer, and a transcript pasted into a single prompt loses it.
  const result = await callGemini({
    system: buildSystemPrompt(),
    history: messages,
    prompt: userMessage,
    maxTokens
  });
  return {
    response: result.text,
    inputTokens: result.promptTokens,
    outputTokens: result.outputTokens,
    totalTokens: result.totalTokens,
    modelVersion: result.modelVersion
  };
}
// =============================================================================
// MAIN HANDLER
// =============================================================================
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: corsHeaders
    });
  }
  if (req.method !== "POST") {
    return new Response("Method not allowed", {
      status: 405,
      headers: corsHeaders
    });
  }
  const gate = await requireStaffUser(req);
  if ("error" in gate) return gate.error;
  const actorId = gate.userId;
  try {
    const { query, sessionId, userId } = await req.json();
    // Audit log (non-blocking) — fire at request arrival for attribution
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: "authenticated",
      schema_name: "public",
      table_name: "edge_fn:query-knowledge-base",
      row_id: null,
      context: {
        event: "query-knowledge-base",
        session_id: sessionId ?? null,
        query_length: query?.length ?? 0
      }
    }).then(() => {}).catch((e) => console.error("[query-knowledge-base] audit_log insert failed:", e));
    if (!query) {
      return new Response(JSON.stringify({
        error: "Query required"
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    console.log(`\n=== NEW QUERY ===`);
    console.log(`Query: "${query}"`);
    console.log(`Session: ${sessionId} | User: ${userId}`);
    console.log(`Current Date: ${new Date().toISOString()}`);
    const startTime = Date.now();
    // Step 1: Classify the task
    const classification = classifyTask(query);
    console.log(`Task Classification: ${classification.type} | Scope: ${classification.scope}`);
    // Step 2: Detect intent
    const intent = detectIntent(query);
    console.log(`Intent: ${intent.type} | Entity: ${intent.entity} | Confidence: ${intent.confidence}`);
    // Step 3: Get embedding
    const embedding = await embedQuery(query);
    const embeddingString = formatEmbeddingForPgvector(embedding);
    // Step 4: Retrieve memories
    const memoriesPromise = retrieveAllMemories(query, sessionId, userId, embeddingString);
    // Step 5: Get learned patterns
    const learnedPatterns = await getLearnedPatterns(embeddingString);
    const memories = await memoriesPromise;
    console.log(`Memories: session=${memories.session.length}, user=${memories.user.length}, org=${memories.org.length}`);
    // Step 6: Retrieve documents based on classification
    let docs;
    if (classification.scope === 'exhaustive') {
      console.log(`Using COMPREHENSIVE retrieval mode`);
      docs = await comprehensiveRetrieval(query, classification);
    } else {
      console.log(`Using STANDARD retrieval mode`);
      docs = await hybridRetrieval(query, intent, true);
    }
    console.log(`Retrieved ${docs.length} documents`);
    // Step 7: Organize context
    const isComprehensive = classification.scope === 'exhaustive';
    const context = organizeContext(docs, intent, memories, isComprehensive);
    // Step 8: Get conversation history
    let history = [];
    if (sessionId) {
      const { data } = await supabase.from("knowledge_chat_messages").select("role, content").eq("session_id", sessionId).order("created_at", {
        ascending: true
      }).limit(20);
      history = data || [];
    }
    // Step 9: Generate response
    const { response, inputTokens, outputTokens, totalTokens, modelVersion } = await generateResponse(query, context, intent, classification, history, learnedPatterns);
    const processingTime = Date.now() - startTime;
    console.log(`Response generated in ${processingTime}ms`);
    console.log(`Tokens: ${inputTokens} in / ${outputTokens} out`);
    // Step 10: Save session messages
    if (sessionId) {
      try {
        await supabase.from("knowledge_chat_messages").insert([
          {
            session_id: sessionId,
            role: "user",
            content: query
          },
          {
            session_id: sessionId,
            role: "assistant",
            content: response,
            source_documents: docs.slice(0, 10).map((d)=>({
                id: d.id,
                source_type: d.source_type,
                source_table: d.source_table,
                title: d.title,
                retrieval_method: d.retrieval_method,
                similarity: d.similarity
              })),
            tokens_used: {
              input: inputTokens,
              output: outputTokens
            }
          }
        ]);
        const { count } = await supabase.from("knowledge_chat_messages").select("*", {
          count: "exact",
          head: true
        }).eq("session_id", sessionId);
        if (count === 2) {
          const title = query.length > 50 ? query.slice(0, 47) + '...' : query;
          await supabase.from("knowledge_chat_sessions").update({
            title,
            updated_at: new Date().toISOString()
          }).eq("id", sessionId);
        }
      } catch (sessionError) {
        console.error("Session save error:", sessionError);
      }
    }
    // Step 11: Extract and store memories (async)
    extractAndStoreMemories(query, response, sessionId, userId).catch((err)=>console.error('Background memory extraction error:', err));
    // Step 12: Log usage
    try {
      await supabase.from("knowledge_usage_log").insert({
        service: "gemini_generation",
        operation: classification.scope === 'exhaustive' ? "query_comprehensive" : "query_enhanced",
        user_id: userId,
        input_tokens: inputTokens,
        output_tokens: outputTokens,
        // Vertex reports a total that INCLUDES thought tokens, so it is not
        // input + output and must not be recomputed as if it were. It is also
        // the figure the bill is actually against.
        total_tokens: totalTokens,
        // NULL, deliberately, and not zero.
        //
        // The number that used to sit here was Anthropic Sonnet's published
        // per-million rate hardcoded as 300 and 1500 hundredths of a cent. Those
        // rates are now wrong, and writing a Gemini figure in their place would
        // mean inventing one: nothing in this container can read Vertex pricing,
        // and a fabricated rate in a column named estimated_cost_cents reads as
        // a measurement rather than a guess.
        //
        // The whole point of this migration is that the spend lands on the GCP
        // project, so GCP billing is the source of record for it. The token
        // counts above are real and are what a rate would be applied to.
        estimated_cost_cents: null,
        request_metadata: {
          query_length: query.length,
          intent: intent,
          classification: classification,
          docs_retrieved: docs.length,
          retrieval_methods: [
            ...new Set(docs.map((d)=>d.retrieval_method))
          ],
          memories_used: {
            session: memories.session.length,
            user: memories.user.length,
            org: memories.org.length
          },
          processing_time_ms: processingTime,
          // As REPORTED BY Vertex for this call, not the alias that was asked
          // for. A pinned point release answering under a floating alias is the
          // thing worth having in the log.
          model: modelVersion
        }
      });
    } catch  {
    // Ignore logging errors
    }
    return new Response(JSON.stringify({
      success: true,
      response,
      intent,
      classification,
      memories_used: {
        session: memories.session.length,
        user: memories.user.length,
        org: memories.org.length
      },
      sources: docs.slice(0, 15).map((d)=>({
          id: d.id,
          source_type: d.source_type,
          source_table: d.source_table,
          title: d.title,
          retrieval_method: d.retrieval_method,
          similarity: d.similarity ? Math.round(d.similarity * 100) / 100 : null
        })),
      usage: {
        input_tokens: inputTokens,
        output_tokens: outputTokens,
        total_tokens: totalTokens,
        model: modelVersion,
        processing_time_ms: processingTime
      }
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    console.error("Error:", err);
    return new Response(JSON.stringify({
      error: err.message,
      success: false
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
