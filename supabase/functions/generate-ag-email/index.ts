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

async function logEmailFingerprint(fingerprint: string, recipientEmail: string) {
  await supabase.from("hanaway_generated_emails_log").insert({
    email_fingerprint: fingerprint,
    recipient_email: recipientEmail,
    generated_at: new Date().toISOString(),
  });
}

async function checkForDuplicates(content: string): Promise<boolean> {
  const fingerprint = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(content.slice(0, 100))
  );
  const hashArray = Array.from(new Uint8Array(fingerprint));
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  
  const { data } = await supabase
    .from("hanaway_generated_emails_log")
    .select("id")
    .eq("email_fingerprint", hashHex)
    .single();
  
  return !!data;
}

async function linkParticipant(email: string, name: string, zipCode: string | null, isShortcut: boolean) {
  // If it's a shortcut call, check for existing subscriber first
  if (isShortcut) {
    const { data: existingSubscriber } = await supabase
      .from('subscribers')
      .select('id, member_id, donor_id')
      .eq('email', email.toLowerCase().trim())
      .single();
    
    if (existingSubscriber) {
      // Return existing IDs without creating new record
      return {
        subscriber_id: existingSubscriber.id,
        member_id: existingSubscriber.member_id,
        donor_id: existingSubscriber.donor_id
      };
    }
  }

  // New user or non-shortcut call - use the RPC function
  const { data, error } = await supabase.rpc('link_hanaway_campaign_participant', {
    p_email: email,
    p_name: name,
    p_zip_code: zipCode
  });

  if (error) {
    console.error("Error linking participant:", error);
    return {
      subscriber_id: null,
      member_id: null,
      donor_id: null
    };
  }

  return data[0] || {
    subscriber_id: null,
    member_id: null,
    donor_id: null
  };
}

function countWords(text: string): number {
  return text.trim().split(/\s+/).length;
}

// Rate limiting for shortcuts (max 1 per day per user)
async function checkShortcutRateLimit(email: string): Promise<boolean> {
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  
  const { data, error } = await supabase
    .from('hanaway_campaign_tracking')
    .select('id')
    .eq('user_email', email.toLowerCase().trim())
    .eq('is_shortcut_generated', true)
    .gte('created_at', oneDayAgo)
    .limit(1);

  if (error) {
    console.error("Rate limit check error:", error);
    return false; // Allow if error checking
  }

  return (data && data.length > 0); // Returns true if already sent today
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const { 
      name, 
      email, 
      zipCode, 
      tone = "concerned",
      sessionId,
      isShortcut = false  // NEW: Flag for shortcut-generated emails
    } = await req.json();

    // Validation
    if (!name || !email) {
      return new Response(
        JSON.stringify({ error: "Name and email are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return new Response(
        JSON.stringify({ error: "Invalid email format" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Rate limiting for shortcuts (1 per day)
    if (isShortcut) {
      const alreadySentToday = await checkShortcutRateLimit(email);
      if (alreadySentToday) {
        return new Response(
          JSON.stringify({ 
            error: "You've already generated an email today. Please try again tomorrow.",
            rateLimited: true
          }),
          { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    const seed = Math.floor(Math.random() * 1000000);
    const timestamp = Date.now();
    
    // Randomly determine target word count between 100-175 words
    const targetWordCount = Math.floor(Math.random() * 76) + 100;

    // Adjust tone based on selection
    const toneDescriptions: Record<string, string> = {
      concerned: "concerned and thoughtful",
      disappointed: "disappointed but respectful",
      frustrated: "frustrated and direct",
      firm: "firm and assertive",
      passionate: "passionate and urgent"
    };

    const selectedTone = toneDescriptions[tone] || toneDescriptions.concerned;

    const systemPrompt = `You are a Missouri resident writing a personal, authentic email to Attorney General Catherine Hanaway about her attempts to block the anti-gerrymandering referendum.

TONE: Write in a ${selectedTone} voice that feels genuine and authentic.

CRITICAL UNIQUENESS REQUIREMENTS:
- Every email you generate MUST be completely different from any previous email
- Use varied sentence structures, vocabulary, and rhetorical approaches
- Never use the same opening line, transition phrase, or closing statement twice
- Vary the tone, style, and emphasis points in each email
- Use different examples, metaphors, and ways of framing the same issue
- Draw from a wide vocabulary - avoid repetitive words across emails

FORMATTING RULES:
- Use ONLY standard hyphens (-) for compound words or line breaks
- NEVER use em-dashes (—) or en-dashes (–)
- Use commas, semicolons, or periods for pauses instead of dashes
- If you need a pause or break in thought, use a comma or start a new sentence
- Keep punctuation simple and standard

LENGTH REQUIREMENT:
- Target word count: ${targetWordCount} words (±10 words is acceptable)
- EXACTLY 2 paragraphs
- Paragraph 1: Longer, establishes concern (60-70% of total length)
- Paragraph 2: Shorter, clear call to action (30-40% of total length)
- Be concise and impactful - every word must count

WRITING GUIDELINES:
- Write as a real Missouri resident, not a form letter
- Be direct, specific, and actionable
- Express genuine concern mixed with disappointment or frustration
- Reference specific actions by AG Hanaway (lawsuit against citizens, immigration investigation, intimidation tactics)
- Demand concrete action: withdraw the lawsuit, stop the investigation, let voters decide
- Personal, conversational tone - not overly formal or academic
- NO template language or generic phrases
- Sign with just the person's name (no "Sincerely" or other closings)

VOICE VARIATIONS TO ROTATE:
- Sometimes start with a direct statement of purpose
- Sometimes start with a personal anecdote or observation
- Sometimes start with a rhetorical question
- Sometimes express disappointment, sometimes anger, sometimes betrayal
- Vary between citing constitutional rights, democratic principles, personal impact, or moral arguments
- Some emails can be more emotional, others more logical
- Some can reference specific Missouri history/values, others focus on current events

WHAT TO AVOID:
- Generic openings like "I am writing to express my concern"
- Clichés like "democracy is at stake" without specific context
- Overly polite, distant language
- Repeating exact phrases from previous emails
- Template-style structure
- Em-dashes (—) or en-dashes (–) - use standard hyphens (-) only
- Going over ${targetWordCount + 10} words`;

    const userPrompt = `Generate a unique 2-paragraph email from ${name}, a Missouri resident, to Attorney General Catherine Hanaway.

TARGET LENGTH: ${targetWordCount} words (±10 words acceptable)
TONE: ${selectedTone}
Unique seed: ${seed}
Timestamp: ${timestamp}

REQUIRED CONTENT POINTS (weave naturally, don't list):
1. Reference AG Hanaway's unprecedented lawsuit against Missouri citizens to block the referendum
2. Mention her baseless immigration investigation to intimidate petition gatherers
3. Note that Missouri's citizen referendum right has existed since 1908
4. Point out the hypocrisy: she claims "Missourians should determine our elections" while blocking them from voting
5. Demand she withdraw the lawsuit and investigation immediately
6. Emphasize that voters across party lines support fair maps

PARAGRAPH 1: Establish concern and cite specific wrongdoing (${Math.floor(targetWordCount * 0.65)} words approximately)
- Open with a unique, compelling hook
- Reference 2-3 specific actions by the AG
- Connect to broader democratic principles or personal values
- Show you're informed but write as a real person, not an activist

PARAGRAPH 2: Clear call to action (${Math.floor(targetWordCount * 0.35)} words approximately)
- Directly demand specific actions
- Make it clear what you expect
- End with your name only

FORMATTING REMINDER:
- Use ONLY standard hyphens (-), never em-dashes (—) or en-dashes (–)
- Use commas or periods for sentence breaks instead of dashes
- Keep punctuation simple and standard

CRITICAL: 
1. Make this email sound COMPLETELY DIFFERENT from any standard template
2. Use unexpected word choices, varied sentence structure, and a unique voice
3. Stay within ${targetWordCount} ±10 words
4. This should not feel like a form letter

Generate the email body only. No subject line. No "Dear Attorney General" greeting. Start directly with the content.`;

    let attempt = 0;
    let emailBody = "";
    let isDuplicate = true;

    while (isDuplicate && attempt < 3) {
      const response = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${Deno.env.get("OPENAI_API_KEY_CAMPAIGN")}`,
        },
        body: JSON.stringify({
          model: "gpt-4",
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: userPrompt },
          ],
          temperature: 1.0,
          top_p: 0.95,
          frequency_penalty: 1.5,
          presence_penalty: 1.5,
          max_tokens: 500,
        }),
      });

      if (!response.ok) {
        const error = await response.text();
        throw new Error(`OpenAI API error: ${error}`);
      }

      const data = await response.json();
      emailBody = data.choices[0].message.content.trim();
      emailBody = emailBody.replace(/—/g, '-').replace(/–/g, '-');

      isDuplicate = await checkForDuplicates(emailBody);
      attempt++;

      if (isDuplicate && attempt < 3) {
        await new Promise(resolve => setTimeout(resolve, 500));
      }
    }

    const subjectPrompt = `Generate a unique, compelling email subject line (6-12 words) for an email to Missouri Attorney General Catherine Hanaway about her blocking the anti-gerrymandering referendum.

Requirements:
- Must be completely different from standard subject lines
- Should be specific and action-oriented
- Convey urgency or strong feeling
- Use varied vocabulary and phrasing
- Could be assertive, questioning, or direct
- Avoid generic phrases like "Concerned Citizen" or "Important Issue"
- Use ONLY standard hyphens (-), never em-dashes (—) or en-dashes (–)

Random seed for uniqueness: ${seed + 1}

Generate ONLY the subject line text, no quotes or extra formatting.`;

    const subjectResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${Deno.env.get("OPENAI_API_KEY_CAMPAIGN")}`,
      },
      body: JSON.stringify({
        model: "gpt-4",
        messages: [{ role: "user", content: subjectPrompt }],
        temperature: 1.0,
        frequency_penalty: 1.5,
        presence_penalty: 1.5,
        max_tokens: 30,
      }),
    });

    const subjectData = await subjectResponse.json();
    let subject = subjectData.choices[0].message.content.trim().replace(/^["']|["']$/g, "");
    subject = subject.replace(/—/g, '-').replace(/–/g, '-');

    const fingerprint = await crypto.subtle.digest(
      "SHA-256",
      new TextEncoder().encode(emailBody.slice(0, 100))
    );
    const hashArray = Array.from(new Uint8Array(fingerprint));
    const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    
    await logEmailFingerprint(hashHex, "attorney.general@ago.mo.gov");

    // Link participant and get IDs
    const linkedIds = await linkParticipant(email, name, zipCode || null, isShortcut);

    // Calculate word count
    const wordCount = countWords(emailBody);

    // Track email generation
    const trackingData = {
      user_name: name,
      user_email: email.toLowerCase().trim(),
      user_zip_code: zipCode || null,
      user_tone: tone,
      member_id: linkedIds.member_id,
      subscriber_id: linkedIds.subscriber_id,
      donor_id: linkedIds.donor_id,
      email_subject: subject,
      email_body: emailBody,
      email_word_count: wordCount,
      send_method: null,
      is_shortcut_generated: isShortcut,
      user_agent: req.headers.get("user-agent"),
      ip_address: req.headers.get("x-forwarded-for") || req.headers.get("cf-connecting-ip"),
      session_id: sessionId || null,
      uniqueness_seed: seed,
    };

    const { data: trackingRecord, error: trackingError } = await supabase
      .from("hanaway_campaign_tracking")
      .insert(trackingData)
      .select()
      .single();

    if (trackingError) {
      console.error("Tracking error:", trackingError);
    }

    return new Response(
      JSON.stringify({
        subject,
        body: emailBody,
        trackingId: trackingRecord?.id || null,
        recipient: "attorney.general@ago.mo.gov",
        metadata: {
          generated_at: new Date().toISOString(),
          uniqueness_seed: seed,
          attempt_number: attempt,
          word_count: wordCount,
          target_word_count: targetWordCount,
          is_member: !!linkedIds.member_id,
          is_donor: !!linkedIds.donor_id,
          is_shortcut: isShortcut,
        },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Email generation error:", error);
    return new Response(
      JSON.stringify({ 
        error: error.message || "Failed to generate email",
        details: error.toString()
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});