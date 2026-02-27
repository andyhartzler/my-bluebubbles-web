import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

// Check iMessage availability for a phone number, fall back to SMS
async function determineService(
  phone: string,
  bbUrl: string,
  bbPassword: string,
): Promise<string> {
  // Email addresses are always iMessage
  if (phone.includes("@")) return "iMessage";

  try {
    const resp = await fetch(
      `${bbUrl}/api/v1/handle/availability/imessage?address=${encodeURIComponent(phone)}&password=${encodeURIComponent(bbPassword)}`,
      { method: "GET" }
    );
    if (resp.ok) {
      const json = await resp.json();
      const available = json?.data?.available === true;
      return available ? "iMessage" : "SMS";
    }
  } catch (err) {
    console.warn(`iMessage check failed for ${phone}: ${(err as Error).message}`);
  }
  // Default to SMS if we can't determine
  return "SMS";
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const bbUrl = Deno.env.get("BLUEBUBBLES_URL");
    const bbPassword = Deno.env.get("BLUEBUBBLES_PASSWORD");

    if (!bbUrl || !bbPassword) {
      return new Response(
        JSON.stringify({
          error: "BlueBubbles not configured. Set BLUEBUBBLES_URL and BLUEBUBBLES_PASSWORD secrets.",
        }),
        {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const { survey_id, phone_list } = await req.json();

    if (!survey_id) {
      return new Response(
        JSON.stringify({ error: "survey_id is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Fetch survey with questions
    const { data: survey, error: surveyErr } = await supabase
      .from("surveys")
      .select("*, survey_questions(*)")
      .eq("id", survey_id)
      .single();

    if (surveyErr || !survey) {
      return new Response(
        JSON.stringify({ error: "Survey not found", detail: surveyErr?.message }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const questions = (survey.survey_questions || []).sort(
      (a: any, b: any) => a.question_order - b.question_order
    );

    if (questions.length === 0) {
      return new Response(
        JSON.stringify({ error: "Survey has no questions" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Determine recipients
    let phones: string[] = [];

    if (phone_list && Array.isArray(phone_list) && phone_list.length > 0) {
      // Custom phone list
      phones = phone_list;
    } else if (survey.event_id) {
      // Event-linked survey — get attendees
      let query = supabase
        .from("event_attendees")
        .select("phone_e164, member_id, members!left(phone_e164, opt_out)")
        .eq("event_id", survey.event_id);

      if (survey.target_audience === "checked_in_only") {
        query = query.eq("checked_in", true);
      }

      const { data: attendees } = await query;

      if (attendees) {
        for (const a of attendees) {
          // Use attendee phone or member phone
          const phone = a.phone_e164 || (a.members as any)?.phone_e164;
          const optOut = (a.members as any)?.opt_out;
          if (phone && !optOut) {
            phones.push(phone);
          }
        }
      }
    }

    if (phones.length === 0) {
      return new Response(
        JSON.stringify({ error: "No recipients found" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // De-duplicate
    phones = [...new Set(phones)];

    // Check for existing active sessions to avoid double-sending
    const { data: existing } = await supabase
      .from("survey_sessions")
      .select("phone_e164")
      .eq("survey_id", survey_id)
      .in("status", ["active", "completed"]);

    const alreadySent = new Set(
      (existing || []).map((s: any) => s.phone_e164)
    );
    phones = phones.filter((p) => !alreadySent.has(p));

    if (phones.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "All recipients already have sessions",
          sent: 0,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Format the first question
    const firstQ = questions[0];
    const totalQ = questions.length;
    const firstMessage = formatFirstMessage(
      survey.title,
      firstQ,
      totalQ
    );

    // Determine transport service (iMessage vs SMS) for each recipient.
    // Do this in parallel for speed, then send messages serially.
    const serviceMap: Record<string, string> = {};
    await Promise.all(
      phones.map(async (phone) => {
        serviceMap[phone] = await determineService(phone, bbUrl, bbPassword);
      })
    );

    const iMessageCount = Object.values(serviceMap).filter((s) => s === "iMessage").length;
    const smsCount = Object.values(serviceMap).filter((s) => s === "SMS").length;
    console.log(`Transport breakdown: ${iMessageCount} iMessage, ${smsCount} SMS out of ${phones.length} total`);

    // Create sessions and send first question
    let sent = 0;
    const errors: string[] = [];
    const smsFailed: string[] = [];

    for (const phone of phones) {
      try {
        // Look up member_id if available
        const { data: member } = await supabase
          .from("members")
          .select("id")
          .eq("phone_e164", phone)
          .maybeSingle();

        const service = serviceMap[phone] || "SMS";

        // Create session
        await supabase.from("survey_sessions").insert({
          survey_id,
          phone_e164: phone,
          member_id: member?.id ?? null,
          current_question_order: 1,
          status: "active",
          started_at: new Date().toISOString(),
          last_message_at: new Date().toISOString(),
        });

        // Send first question via BlueBubbles
        const resp = await fetch(
          `${bbUrl}/api/v1/chat/new?password=${encodeURIComponent(bbPassword)}`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              addresses: [phone],
              message: firstMessage,
              service,
            }),
          }
        );

        if (!resp.ok) {
          const body = await resp.text();
          errors.push(`${phone} (${service}): BB error ${resp.status} - ${body}`);
          if (service === "SMS") smsFailed.push(phone);
        } else {
          sent++;
        }

        // Rate limit: 1 msg/sec
        await sleep(1000);
      } catch (err) {
        errors.push(`${phone}: ${(err as Error).message}`);
      }
    }

    // Update survey status to active
    await supabase
      .from("surveys")
      .update({ status: "active" })
      .eq("id", survey_id);

    return new Response(
      JSON.stringify({
        success: true,
        sent,
        total: phones.length,
        iMessageCount,
        smsCount,
        errors: errors.length > 0 ? errors : undefined,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("send-survey error:", err);
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

function formatFirstMessage(
  surveyTitle: string,
  question: any,
  totalQuestions: number
): string {
  const lines: string[] = [];
  // First question: just the question text, no survey name, no Q1 prefix
  lines.push(question.question_text);
  lines.push("");

  switch (question.question_type) {
    case "yes_no":
      lines.push("Reply YES or NO");
      break;
    case "true_false":
      lines.push("Reply TRUE or FALSE");
      break;
    case "rating": {
      let min = 1;
      let max = 5;
      const opts = question.options;
      if (opts && !Array.isArray(opts) && typeof opts === "object") {
        if (opts.min != null) min = Number(opts.min);
        if (opts.max != null) max = Number(opts.max);
      }
      const minLabel = opts?.labels?.[String(min)] ?? "Poor";
      const maxLabel = opts?.labels?.[String(max)] ?? "Excellent";
      lines.push(`Reply ${min}-${max} (${min}=${minLabel}, ${max}=${maxLabel})`);
      break;
    }
    case "multiple_choice":
      if (question.options && Array.isArray(question.options)) {
        question.options.forEach((opt: string, i: number) => {
          lines.push(`${i + 1}. ${opt}`);
        });
      }
      break;
    case "multi_select": {
      const opts = question.options;
      const choices = Array.isArray(opts) ? opts : opts?.choices ?? [];
      choices.forEach((opt: string, i: number) => {
        lines.push(`${i + 1}. ${opt}`);
      });
      break;
    }
    case "short_answer":
      lines.push("Reply with your answer");
      break;
  }

  lines.push("");
  lines.push("Reply SKIP to skip \u00B7 STOP to opt out");
  return lines.join("\n");
}
