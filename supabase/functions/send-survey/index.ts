import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://moyd.app",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── This edge function ONLY prepares survey sessions. ─────────────────────
// Message sending is handled client-side via CRMMessageService for:
//   - Real-time progress callbacks
//   - iMessage/SMS detection using local BB connection (fast, cached)
//   - No edge function timeout issues

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
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
      phones = phone_list;
    } else if (survey.event_id) {
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

    // Check for existing active/completed sessions for THIS survey to avoid double-sending
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
          phones: [],
          firstMessage: "",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Close any stale active sessions for these phones from OTHER surveys
    // so the webhook doesn't pick the wrong session
    await supabase
      .from("survey_sessions")
      .update({ status: "expired", completed_at: new Date().toISOString() })
      .in("phone_e164", phones)
      .eq("status", "active")
      .neq("survey_id", survey_id);

    // Format the first question (returned to client for sending)
    const firstQ = questions[0];
    const firstMessage = formatFirstMessage(survey.title, firstQ, questions.length);

    // Create sessions (NO message sending — client handles that)
    const sessions: Array<{ phone: string; sessionId: string }> = [];

    for (const phone of phones) {
      try {
        const { data: member } = await supabase
          .from("members")
          .select("id")
          .eq("phone_e164", phone)
          .maybeSingle();

        const { data: session } = await supabase
          .from("survey_sessions")
          .insert({
            survey_id,
            phone_e164: phone,
            member_id: member?.id ?? null,
            current_question_order: 1,
            status: "active",
            started_at: new Date().toISOString(),
            last_message_at: new Date().toISOString(),
          })
          .select("id")
          .single();

        if (session) {
          sessions.push({ phone, sessionId: session.id });
        }
      } catch (err) {
        console.error(`Failed to create session for ${phone}: ${(err as Error).message}`);
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
        phones: sessions.map((s) => s.phone),
        sessions,
        firstMessage,
        total: sessions.length,
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
