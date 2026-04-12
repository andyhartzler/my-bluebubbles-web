import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://moyd.app",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── Word lists for parsing ──────────────────────────────────────────────────

const YES_WORDS = new Set([
  "yes", "y", "ya", "yea", "yeah", "yep", "yup", "yah", "ye", "yee",
  "sure", "ok", "okay", "k", "kk",
  "absolutely", "definitely", "of course", "for sure", "totally",
  "affirmative", "si", "yess", "yesss", "yea!", "yes!",
]);
const NO_WORDS = new Set([
  "no", "n", "nah", "naw", "nope", "never", "not really", "nah",
  "negative", "noo", "nooo", "no!", "nope!",
]);
const STOP_WORDS = new Set(["stop", "unsubscribe", "quit", "cancel", "end"]);
const SKIP_WORDS = new Set(["skip", "pass", "next", "n/a", "na"]);
const TRUE_WORDS = new Set([
  "true", "t", "yes", "y", "correct", "right", "yep", "yup",
]);
const FALSE_WORDS = new Set([
  "false", "f", "no", "n", "incorrect", "wrong", "nope", "nah",
]);

// Word-to-number map for rating questions
const WORD_NUMBERS: Record<string, number> = {
  one: 1, two: 2, three: 3, four: 4, five: 5,
  six: 6, seven: 7, eight: 8, nine: 9, ten: 10,
};

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
  options: any
): ParseResult {
  const lower = text.toLowerCase().trim();

  switch (questionType) {
    case "yes_no": {
      if (YES_WORDS.has(lower)) return { parsed: "yes", hint: null };
      if (NO_WORDS.has(lower)) return { parsed: "no", hint: null };
      // Fuzzy: starts with y or n
      if (lower.startsWith("y")) return { parsed: "yes", hint: null };
      if (lower.startsWith("n")) return { parsed: "no", hint: null };
      return { parsed: null, hint: "Please reply YES or NO." };
    }

    case "true_false": {
      if (TRUE_WORDS.has(lower)) return { parsed: "true", hint: null };
      if (FALSE_WORDS.has(lower)) return { parsed: "false", hint: null };
      // Fuzzy: starts with t or f
      if (lower.startsWith("t") || lower.startsWith("y")) return { parsed: "true", hint: null };
      if (lower.startsWith("f") || lower.startsWith("n")) return { parsed: "false", hint: null };
      return { parsed: null, hint: "Please reply TRUE or FALSE." };
    }

    case "rating": {
      let min = 1;
      let max = 5;
      if (options && !Array.isArray(options) && typeof options === "object") {
        if (options.min != null) min = Number(options.min);
        if (options.max != null) max = Number(options.max);
      }
      // Try numeric
      const num = parseInt(text.trim(), 10);
      if (!isNaN(num) && num >= min && num <= max) {
        return { parsed: String(num), hint: null };
      }
      // Try word numbers ("five", "three")
      const wordNum = WORD_NUMBERS[lower];
      if (wordNum !== undefined && wordNum >= min && wordNum <= max) {
        return { parsed: String(wordNum), hint: null };
      }
      return { parsed: null, hint: `Please reply with a number ${min}-${max}.` };
    }

    case "multiple_choice": {
      const opts = _extractOptions(options);
      if (!opts || opts.length === 0) {
        return { parsed: text.trim(), hint: null };
      }
      // Try numeric
      const num = parseInt(text.trim(), 10);
      if (!isNaN(num) && num >= 1 && num <= opts.length) {
        return { parsed: opts[num - 1], hint: null };
      }
      // Try exact match (case-insensitive)
      const exact = opts.find((o) => o.toLowerCase() === lower);
      if (exact) return { parsed: exact, hint: null };
      // Try starts-with (single char or partial)
      const startsMatches = opts.filter((o) => o.toLowerCase().startsWith(lower));
      if (startsMatches.length === 1) return { parsed: startsMatches[0], hint: null };
      // Try contains
      const containsMatches = opts.filter((o) => o.toLowerCase().includes(lower));
      if (containsMatches.length === 1) return { parsed: containsMatches[0], hint: null };
      // Try if input contains an option
      const reverseMatch = opts.find((o) => lower.includes(o.toLowerCase()));
      if (reverseMatch) return { parsed: reverseMatch, hint: null };
      // Try word number
      const wordNum = WORD_NUMBERS[lower];
      if (wordNum !== undefined && wordNum >= 1 && wordNum <= opts.length) {
        return { parsed: opts[wordNum - 1], hint: null };
      }
      const optionsList = opts.map((o, i) => `${i + 1}. ${o}`).join(", ");
      return { parsed: null, hint: `Please reply with a number: ${optionsList}` };
    }

    case "multi_select": {
      const opts = _extractOptions(options);
      if (!opts || opts.length === 0) {
        return { parsed: text.trim(), hint: null };
      }

      const selected: string[] = [];

      // Strategy 1: Try matching option text in the input
      for (const opt of opts) {
        if (lower.includes(opt.toLowerCase())) {
          if (!selected.includes(opt)) selected.push(opt);
        }
      }
      if (selected.length > 0) {
        return { parsed: JSON.stringify(selected), hint: null };
      }

      // Strategy 2: Extract numbers intelligently
      // Strip filler words: "and", "&", "plus", punctuation
      const cleaned = lower
        .replace(/\band\b/gi, " ")
        .replace(/[&+]/g, " ")
        .replace(/[^0-9\s]/g, " ");

      if (opts.length <= 9) {
        // ≤9 options: each digit is a separate pick
        // "13" → [1, 3], "41" → [4, 1], "1 and 3" → [1, 3]
        const allDigits = cleaned.replace(/\s/g, "");
        for (const ch of allDigits) {
          const num = parseInt(ch, 10);
          if (num >= 1 && num <= opts.length) {
            const opt = opts[num - 1];
            if (!selected.includes(opt)) selected.push(opt);
          }
        }
      } else {
        // >9 options: parse multi-digit numbers
        const parts = cleaned.match(/\d+/g) ?? [];
        for (const part of parts) {
          const num = parseInt(part, 10);
          if (num >= 1 && num <= opts.length) {
            const opt = opts[num - 1];
            if (!selected.includes(opt)) selected.push(opt);
          }
        }
      }

      if (selected.length > 0) {
        return { parsed: JSON.stringify(selected), hint: null };
      }

      // Nothing matched
      const optionsList = opts.map((o, i) => `${i + 1}. ${o}`).join(", ");
      return {
        parsed: null,
        hint: `I didn't catch that. Which ones? ${optionsList}`,
      };
    }

    case "short_answer":
      return { parsed: text.trim(), hint: null };

    default:
      return { parsed: text.trim(), hint: null };
  }
}

function _extractOptions(options: any): string[] | null {
  if (!options) return null;
  if (Array.isArray(options)) return options.map(String);
  if (options.choices && Array.isArray(options.choices)) return options.choices.map(String);
  return null;
}

// Send a message via BlueBubbles using the known service type.
// No iMessage availability check needed — the service is determined from the
// incoming chat identifier or passed explicitly by the caller.
async function sendBBMessage(phone: string, message: string, service: string = "iMessage"): Promise<void> {
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
        service,
      }),
    }
  );

  if (!resp.ok) {
    const body = await resp.text();
    console.error(`BB send failed for ${phone} via ${service} (${resp.status}): ${body}`);
  }
}

// ── Main handler ────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const payload = await req.json();

    const data = payload.data ?? payload;

    const isFromMe = data?.isFromMe ?? data?.is_from_me ?? false;
    if (isFromMe) {
      return new Response(JSON.stringify({ ok: true, skipped: "from_me" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

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

    // Determine service: check handle.service, then chat guid prefix, then default SMS
    // BB chatIdentifier is just the phone number — the service is on handle or chat guid
    const handleService: string = data?.handle?.service ?? "";
    const chatGuid: string = data?.chats?.[0]?.guid ?? "";
    const incomingService =
      handleService === "SMS" ? "SMS"
      : handleService === "iMessage" ? "iMessage"
      : chatGuid.startsWith("SMS;") ? "SMS"
      : chatGuid.startsWith("iMessage;") ? "iMessage"
      : "SMS"; // default to SMS — safer than failing silently with iMessage

    const phone = normalizePhone(senderRaw);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Order by started_at DESC to always pick the MOST RECENT active session
    const { data: session, error: sessError } = await supabase
      .from("survey_sessions")
      .select(
        `
        id, survey_id, current_question_order, status, phone_e164,
        last_message_at,
        survey:surveys(id, title)
        `
      )
      .eq("phone_e164", phone)
      .eq("status", "active")
      .order("started_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (sessError) {
      console.error("Session lookup error:", sessError.message);
      return new Response(JSON.stringify({ ok: true, error: sessError.message }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!session) {
      return new Response(JSON.stringify({ ok: true, skipped: "no_session" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Rate limit — ignore messages within 5s of last sent
    if (session.last_message_at) {
      const lastMsg = new Date(session.last_message_at).getTime();
      if (Date.now() - lastMsg < 5000) {
        return new Response(JSON.stringify({ ok: true, skipped: "rate_limited" }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    const lower = messageText.toLowerCase().trim();

    // Check STOP
    if (STOP_WORDS.has(lower)) {
      await supabase
        .from("survey_sessions")
        .update({ status: "opted_out", completed_at: new Date().toISOString() })
        .eq("id", session.id);

      await sendBBMessage(
        phone,
        "You've opted out of this survey. You'll still receive future surveys.",
        incomingService
      );

      return new Response(JSON.stringify({ ok: true, action: "opted_out" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

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
      await advanceToNextQuestion(supabase, session, currentQ, phone, incomingService);
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
      await supabase
        .from("survey_sessions")
        .update({ last_message_at: new Date().toISOString() })
        .eq("id", session.id);
      await sendBBMessage(phone, hint, incomingService);
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
    await advanceToNextQuestion(supabase, session, currentQ, phone, incomingService);

    return new Response(JSON.stringify({ ok: true, action: "recorded" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("survey-webhook error:", err);
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
  phone: string,
  service: string = "iMessage"
): Promise<void> {
  const nextOrder = session.current_question_order + 1;

  const { data: nextQ } = await supabase
    .from("survey_questions")
    .select("id, question_text, question_type, options, question_order")
    .eq("survey_id", session.survey_id)
    .eq("question_order", nextOrder)
    .maybeSingle();

  if (nextQ) {
    await supabase
      .from("survey_sessions")
      .update({
        current_question_order: nextOrder,
        last_message_at: new Date().toISOString(),
      })
      .eq("id", session.id);

    const { count } = await supabase
      .from("survey_questions")
      .select("id", { count: "exact", head: true })
      .eq("survey_id", session.survey_id);

    const total = count ?? nextOrder;
    const surveyTitle = session.survey?.title ?? "Survey";
    const msg = formatQuestion(surveyTitle, nextQ, nextOrder, total);
    await sendBBMessage(phone, msg, service);
  } else {
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
      "Thank you for completing the survey! Your responses have been recorded.",
      service
    );

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
  lines.push(`Q${order}: ${question.question_text}`);
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
    case "multiple_choice": {
      const opts = question.options;
      if (opts && Array.isArray(opts)) {
        opts.forEach((opt: string, i: number) => {
          lines.push(`${i + 1}. ${opt}`);
        });
      }
      break;
    }
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
