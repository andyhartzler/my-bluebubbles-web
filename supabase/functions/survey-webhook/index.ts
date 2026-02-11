import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── Word lists for parsing ──────────────────────────────────────────────────

const YES_WORDS = new Set([
  "yes", "y", "ya", "yea", "yeah", "yep", "yup", "sure", "ok", "okay",
  "absolutely", "definitely", "of course",
]);
const NO_WORDS = new Set([
  "no", "n", "nah", "naw", "nope", "never", "not really",
]);
const STOP_WORDS = new Set(["stop", "unsubscribe", "quit", "cancel"]);
const SKIP_WORDS = new Set(["skip", "pass", "next"]);

// ── Helpers ─────────────────────────────────────────────────────────────────

function normalizePhone(raw: string): string {
  const digits = raw.replace(/\D/g, "");
  if (digits.length === 10) return `+1${digits}`;
  if (digits.length === 11 && digits.startsWith("1")) return `+${digits}`;
  if (raw.startsWith("+")) return raw;
  return `+${digits}`;
}

interface ParseResult {
  parsed: string | null;
  hint: string | null;
}

function parseResponse(
  text: string,
  questionType: string,
  options: string[] | null
): ParseResult {
  const lower = text.toLowerCase().trim();

  switch (questionType) {
    case "yes_no": {
      if (YES_WORDS.has(lower)) return { parsed: "yes", hint: null };
      if (NO_WORDS.has(lower)) return { parsed: "no", hint: null };
      return { parsed: null, hint: 'Please reply YES or NO.' };
    }

    case "rating": {
      const num = parseInt(text.trim(), 10);
      if (!isNaN(num) && num >= 1 && num <= 5) {
        return { parsed: String(num), hint: null };
      }
      return { parsed: null, hint: "Please reply with a number 1-5." };
    }

    case "multiple_choice": {
      if (!options || options.length === 0) {
        return { parsed: text.trim(), hint: null };
      }
      // Match by number
      const num = parseInt(text.trim(), 10);
      if (!isNaN(num) && num >= 1 && num <= options.length) {
        return { parsed: options[num - 1], hint: null };
      }
      // Match by exact text (case-insensitive)
      const exact = options.find((o) => o.toLowerCase() === lower);
      if (exact) return { parsed: exact, hint: null };
      // Match by first letter if unambiguous
      if (lower.length === 1) {
        const matches = options.filter(
          (o) => o.toLowerCase().startsWith(lower)
        );
        if (matches.length === 1) return { parsed: matches[0], hint: null };
      }
      const optionsList = options
        .map((o, i) => `${i + 1}. ${o}`)
        .join(", ");
      return {
        parsed: null,
        hint: `Please reply with a number: ${optionsList}`,
      };
    }

    case "short_answer":
      return { parsed: text.trim(), hint: null };

    default:
      return { parsed: text.trim(), hint: null };
  }
}

async function sendBBMessage(phone: string, message: string): Promise<void> {
  const bbUrl = Deno.env.get("BLUEBUBBLES_URL");
  const bbPassword = Deno.env.get("BLUEBUBBLES_PASSWORD");
  if (!bbUrl || !bbPassword) {
    console.error("BlueBubbles not configured");
    return;
  }

  const resp = await fetch(
    `${bbUrl}/api/v1/chat/new?password=${encodeURIComponent(bbPassword)}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        addresses: [phone],
        message,
        service: "iMessage",
      }),
    }
  );

  if (!resp.ok) {
    const body = await resp.text();
    console.error(`BB send failed (${resp.status}): ${body}`);
  }
}

// ── Main handler ────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const payload = await req.json();

    // Extract sender phone from BB webhook payload
    // BB sends: { data: { handle: { address: "+1..." }, text: "..." } }
    // or various other shapes depending on BB version
    const data = payload.data ?? payload;
    const senderRaw =
      data?.handle?.address ??
      data?.chats?.[0]?.participants?.[0]?.address ??
      data?.address ??
      "";
    const messageText: string = (data?.text ?? data?.message ?? "").trim();

    if (!senderRaw || !messageText) {
      return new Response(JSON.stringify({ ok: true, skipped: "no_data" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const phone = normalizePhone(senderRaw);

    // ── Fast exit: check for active survey session ──
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { data: session, error: sessError } = await supabase
      .from("survey_sessions")
      .select(
        `
        id, survey_id, current_question_order, status, phone_e164,
        survey:surveys!inner(id, title),
        current_question:survey_questions!inner(
          id, question_text, question_type, options, question_order
        )
        `
      )
      .eq("phone_e164", phone)
      .eq("status", "active")
      .limit(1)
      .maybeSingle();

    if (sessError) {
      console.error("Session lookup error:", sessError.message);
      // Don't block BB webhook — return 200
      return new Response(JSON.stringify({ ok: true, error: sessError.message }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // No active session → fast exit (99% of messages)
    if (!session) {
      return new Response(JSON.stringify({ ok: true, skipped: "no_session" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── Active session found — process the response ──

    const lower = messageText.toLowerCase().trim();

    // Check STOP
    if (STOP_WORDS.has(lower)) {
      await supabase
        .from("survey_sessions")
        .update({ status: "opted_out", completed_at: new Date().toISOString() })
        .eq("id", session.id);

      await sendBBMessage(
        phone,
        "You've been opted out of this survey. Reply START to any future survey to re-subscribe."
      );

      return new Response(JSON.stringify({ ok: true, action: "opted_out" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Fetch the current question properly (the join above may not match correctly)
    const { data: currentQ } = await supabase
      .from("survey_questions")
      .select("id, question_text, question_type, options, question_order")
      .eq("survey_id", session.survey_id)
      .eq("question_order", session.current_question_order)
      .single();

    if (!currentQ) {
      console.error("No question found for order", session.current_question_order);
      return new Response(JSON.stringify({ ok: true, error: "no_question" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check SKIP
    if (SKIP_WORDS.has(lower)) {
      // Advance to next question without recording response
      await advanceToNextQuestion(supabase, session, currentQ, phone);
      return new Response(JSON.stringify({ ok: true, action: "skipped" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Parse the response
    const { parsed, hint } = parseResponse(
      messageText,
      currentQ.question_type,
      currentQ.options
    );

    if (parsed === null && hint) {
      // Unparseable — send retry hint
      await sendBBMessage(phone, hint);
      return new Response(JSON.stringify({ ok: true, action: "retry_hint" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Record the response
    await supabase.from("survey_responses").insert({
      session_id: session.id,
      question_id: currentQ.id,
      raw_response: messageText,
      parsed_response: parsed,
    });

    // Advance to next question
    await advanceToNextQuestion(supabase, session, currentQ, phone);

    return new Response(JSON.stringify({ ok: true, action: "recorded" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("survey-webhook error:", err);
    // Always return 200 to BB so it doesn't retry
    return new Response(
      JSON.stringify({ ok: true, error: (err as Error).message }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

async function advanceToNextQuestion(
  supabase: ReturnType<typeof createClient>,
  session: any,
  currentQuestion: any,
  phone: string
): Promise<void> {
  const nextOrder = session.current_question_order + 1;

  // Check if there's a next question
  const { data: nextQ } = await supabase
    .from("survey_questions")
    .select("id, question_text, question_type, options, question_order")
    .eq("survey_id", session.survey_id)
    .eq("question_order", nextOrder)
    .maybeSingle();

  if (nextQ) {
    // Update session to next question
    await supabase
      .from("survey_sessions")
      .update({
        current_question_order: nextOrder,
        last_message_at: new Date().toISOString(),
      })
      .eq("id", session.id);

    // Get total question count for formatting
    const { count } = await supabase
      .from("survey_questions")
      .select("id", { count: "exact", head: true })
      .eq("survey_id", session.survey_id);

    const total = count ?? nextOrder;
    const surveyTitle = session.survey?.title ?? "Survey";
    const msg = formatQuestion(surveyTitle, nextQ, nextOrder, total);
    await sendBBMessage(phone, msg);
  } else {
    // No more questions — mark complete
    await supabase
      .from("survey_sessions")
      .update({
        status: "completed",
        completed_at: new Date().toISOString(),
        last_message_at: new Date().toISOString(),
      })
      .eq("id", session.id);

    await sendBBMessage(
      phone,
      "Thank you for completing the survey! Your responses have been recorded."
    );

    // Check if all sessions for this survey are complete
    const { count: activeCount } = await supabase
      .from("survey_sessions")
      .select("id", { count: "exact", head: true })
      .eq("survey_id", session.survey_id)
      .eq("status", "active");

    if (activeCount === 0) {
      await supabase
        .from("surveys")
        .update({ status: "completed", completed_at: new Date().toISOString() })
        .eq("id", session.survey_id);
    }
  }
}

function formatQuestion(
  surveyTitle: string,
  question: any,
  order: number,
  total: number
): string {
  const lines: string[] = [];
  lines.push(`Q${order} of ${total}: ${question.question_text}`);
  lines.push("");

  switch (question.question_type) {
    case "yes_no":
      lines.push("Reply YES or NO");
      break;
    case "rating":
      lines.push("Reply 1-5 (1=Poor, 5=Excellent)");
      break;
    case "multiple_choice":
      if (question.options && Array.isArray(question.options)) {
        question.options.forEach((opt: string, i: number) => {
          lines.push(`${i + 1}. ${opt}`);
        });
        lines.push("");
        lines.push("Reply with the number");
      }
      break;
    case "short_answer":
      lines.push("Reply with your answer");
      break;
  }

  lines.push("");
  lines.push("Reply SKIP to skip \u00B7 STOP to opt out");
  return lines.join("\n");
}
